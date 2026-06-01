import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:koel_core/koel_core.dart';

import 'connection/cancellation.dart';
import 'connection/lifecycle.dart';
import 'connection/reconnect_policy.dart';
import 'error/error_classifier.dart';
import 'interceptors/auth_interceptor.dart';
import 'interceptors/retry_interceptor.dart';
import 'sse_parser.dart';
import 'transport/transport.dart';
import 'wire/run_agent_input_codec.dart';

/// `AbstractAgent` over an AG-UI SSE endpoint — the first koel transport that
/// talks to a network (FR-B1, AR-7).
///
/// [run] POSTs a [RunAgentInput] as JSON, streams the `text/event-stream`
/// response through `SseParser`, and yields the typed `Stream<AgUiEvent>`.
/// Consumer code reads `HttpAgent(url: …)` and immediately has a streaming
/// agent — no setup, no per-request wiring.
///
/// **Native-only in this story.** The byte stream comes from the injectable
/// [http.Client] — the default `http.Client()` on the VM is an `IOClient` over
/// `dart:io HttpClient`, whose `send().stream` is the live, unbuffered stream
/// `SseParser` consumes. Web is a throwing stub until **Story 4.10** (`http`'s
/// `BrowserClient` buffers the whole body and cannot stream SSE), selected by a
/// conditional import in the transport seam — this file imports no platform
/// library.
///
/// **Error contract (AC4).** Every failure — connection refused, TLS handshake,
/// timeout, mid-stream close, non-2xx status, malformed wire payload — reaches
/// the consumer as a single terminal `RunErrorEvent(TransportError|ProtocolError)`
/// carrying the typed `KoelErrorCode`; nothing escapes as an uncaught exception.
/// This is satisfied by composing the run over `koel_core`'s `InterceptorChain`,
/// which classifies any thrown/stream-borne error through koel_http's
/// `TransportErrorClassifier` — a native refinement of `DefaultErrorClassifier`
/// that sees through `package:http`'s wrapped `SocketException`/`TlsException`
/// (the base matches by runtime-type name and would miss the wrapper).
///
/// **Open for subclassing.** `class … implements AbstractAgent` (deliberately
/// **not** `final`): Epic-5 backend bridges (`AgnoAgent`, `LangGraphAgent`)
/// extend it.
class HttpAgent implements AbstractAgent {
  /// Creates an agent that runs against the AG-UI SSE endpoint at [url].
  ///
  /// [client] is the injectable transport seam (tests pass `MockClient`,
  /// backends pass a pooled client); when null a default client is created and
  /// owned per run. [interceptors] wrap each run (auth/retry/logging in later
  /// stories). [connectTimeout] bounds the wait for response headers;
  /// [readTimeout] bounds idle time between response bytes — both exceed →
  /// `transportTimeout`.
  ///
  /// [retry] enables automatic reconnection: when non-null, [run] prepends a
  /// `RetryInterceptor` (outermost, so it re-runs every other interceptor on
  /// each reconnect) built from the policy, and [onReconnectAttempt] — when
  /// supplied — fires once per scheduled retry with the 1-based attempt index
  /// and the actual jittered delay. For per-failure control over *which* errors
  /// retry, pass an explicit `RetryInterceptor(shouldRetry: …)` in
  /// [interceptors] instead (both compose; passing both nests retry by choice).
  ///
  /// [synthesizeChunks] (default `true`) normalizes the streaming `*_CHUNK`
  /// convenience shapes (`TOOL_CALL_CHUNK`/`TEXT_MESSAGE_CHUNK`/
  /// `REASONING_MESSAGE_CHUNK`) into the canonical `START`/`CONTENT`/`END`
  /// triplets **at the transport**, by reusing `koel_core`'s `chunksStage`
  /// (Addendum F.2) — so a consumer reading this raw `AbstractAgent` stream and
  /// the Epic-5 backends see long form without a `KoelClient` pipeline. It
  /// governs **this agent's own output stream only**: a `KoelClient`/`ChatSession`
  /// consumer is normalized by the pipeline's own (unconditional) `chunksStage`
  /// regardless of this flag, and the double-application is idempotent
  /// (long-form events pass straight through). Set `false` to emit raw chunks
  /// unchanged from [run].
  ///
  /// [onConnect]/[onDisconnect]/[onReconnectAttempt] are transport-level
  /// lifecycle hooks (FR-B6) for DevTools (Epic 8) and custom observers. They
  /// fire **per physical connection**, so a run that reconnects fires them once
  /// per attempt: [onConnect] when the SSE response headers arrive (once,
  /// status-agnostic — a non-2xx response did connect; a pre-headers failure
  /// fires neither hook); [onDisconnect] exactly once when that connection's
  /// stream ends, with the cause if it ended on an error (`null` on a graceful
  /// close or a consumer cancel); [onReconnectAttempt] once per scheduled retry
  /// with the 1-based attempt index and the jittered delay (only when [retry] is
  /// set). All three are **fire-and-forget** — a throwing observer is swallowed
  /// and never aborts a recoverable run.
  HttpAgent({
    required this.url,
    http.Client? client,
    List<Interceptor>? interceptors,
    this.connectTimeout = const Duration(seconds: 30),
    this.readTimeout = const Duration(minutes: 5),
    RetryPolicy? retry,
    this.synthesizeChunks = true,
    void Function()? onConnect,
    void Function(Object? cause)? onDisconnect,
    void Function(int attempt, Duration delay)? onReconnectAttempt,
  }) : _client = client,
       _retry = retry,
       _lifecycle = ConnectionLifecycle(
         onConnect: onConnect,
         onDisconnect: onDisconnect,
         onReconnectAttempt: onReconnectAttempt,
       ),
       _interceptors = interceptors ?? const <Interceptor>[];

  /// The AG-UI SSE endpoint each run POSTs to.
  final Uri url;

  /// Maximum time to await response headers; exceeding it → `transportTimeout`.
  final Duration connectTimeout;

  /// Maximum idle time between response bytes; exceeding it → `transportTimeout`.
  final Duration readTimeout;

  /// When `true` (default), [run] normalizes the streaming `*_CHUNK` shapes into
  /// canonical `START`/`CONTENT`/`END` triplets at the transport (reusing
  /// `koel_core`'s `chunksStage`); when `false`, raw chunk events pass through
  /// unchanged. Governs this agent's output stream only — see the ctor dartdoc.
  final bool synthesizeChunks;

  final http.Client? _client;
  final List<Interceptor> _interceptors;
  final RetryPolicy? _retry;
  final ConnectionLifecycle _lifecycle;

  /// Runs [input] against [url]: POSTs it as JSON and yields the typed events
  /// the endpoint streams back, in wire order.
  ///
  /// Composed over `InterceptorChain` so [_interceptors] wrap the run and any
  /// transport/parser failure is classified into a terminal `RunErrorEvent`
  /// (the AC4 contract) — see the class dartdoc. Single-subscription, per the
  /// `AbstractAgent` contract.
  @override
  Stream<AgUiEvent> run(RunAgentInput input) {
    final retry = _retry;
    // Prepend the auto-built retry interceptor (outermost) so its reconnect
    // re-runs every user interceptor — including the Story 4.5 `AuthInterceptor`
    // — on each attempt. The bool `RetryPolicy.jitter` maps to the engine's
    // fraction (±20% on, 0 off).
    final interceptors = retry == null
        ? _interceptors
        : <Interceptor>[
            RetryInterceptor.forAgent(
              maxAttempts: retry.maxAttempts,
              baseDelay: retry.baseDelay,
              maxDelay: retry.maxDelay,
              jitter: retry.jitter ? 0.2 : 0.0,
              onReconnectAttempt: _lifecycle.onReconnectAttempt,
            ),
            ..._interceptors,
          ];
    return InterceptorChain(
      interceptors: interceptors,
      agent: _TransportTerminal(this),
      errorClassifier: transportErrorClassifier(),
    ).proceed(input);
  }
}

/// The transport-level terminal `AbstractAgent` wrapped by [HttpAgent.run]'s
/// `InterceptorChain`. It does the actual POST + SSE work and throws raw
/// transport failures; sitting behind the chain turns those throws into the
/// terminal `RunErrorEvent` the consumer sees (AC4) without a hand-rolled
/// try/catch adapter.
class _TransportTerminal implements AbstractAgent {
  _TransportTerminal(this._agent);

  final HttpAgent _agent;

  @override
  Stream<AgUiEvent> run(RunAgentInput input) async* {
    // An `AuthInterceptor` upstream parks its resolved headers on a reserved
    // `forwardedProps` key. Extract them, then encode a copy with that key
    // removed so the token never reaches the wire body (it rides the header
    // only). Protocol headers are merged LAST so auth can add `Authorization`
    // but can never clobber `Content-Type`/`Accept` (a clobbered `Accept`
    // breaks SSE).
    final injected = input.forwardedProps[AuthInterceptor.transportHeadersKey];
    // The reserved key is a transport-internal contract: only `AuthInterceptor`
    // writes it, always as a `Map<String, String>`. A foreign value here is a
    // misuse of the documented-internal key — surface it as a typed, precise
    // failure (the classifier passes a typed `KoelError` through) instead of
    // letting a raw `TypeError` from the cast fall through to the classifier's
    // `AgentError(unknown)` 'Unclassified failure' bucket. No `cause`: the value
    // could carry a token, and the message stays secret-free (architecture §5).
    if (injected != null && injected is! Map<String, String>) {
      throw const AgentError(
        message:
            'Reserved transport-headers key carried a non-Map<String, String> '
            'value',
        code: KoelErrorCode.unknown,
      );
    }
    final authHeaders = (injected as Map<String, String>?) ?? const {};
    final wireInput = injected == null
        ? input
        : input.copyWith(
            forwardedProps: {...input.forwardedProps}
              ..remove(AuthInterceptor.transportHeadersKey),
          );

    final body = utf8.encode(jsonEncode(encodeRunAgentInput(wireInput)));
    final response = await Transport().connect(
      _agent.url,
      body: body,
      headers: {
        ...authHeaders,
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      },
      connectTimeout: _agent.connectTimeout,
      readTimeout: _agent.readTimeout,
      client: _agent._client,
    );

    // Headers are in hand — the connection is established (FR-B6). Fire
    // `onConnect` and open the per-connection scope that fires `onDisconnect`
    // exactly once when this stream ends. This lives in the terminal (innermost,
    // beneath `RetryInterceptor`), so a reconnect re-runs it and the hooks fire
    // once per physical connection. Status-agnostic: a non-2xx still connected,
    // so `onConnect` fires before the status check (paired with the
    // `onDisconnect` on the throw path below); a pre-headers failure throws from
    // `connect()` above and fires neither hook.
    final connection = _agent._lifecycle.connected();

    // A non-2xx response is not a thrown exception — detect it and throw the
    // typed error the classifier passes through (idempotently) to `RunErrorEvent`.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      // The body is never `yield*`-ed past this throw, so nothing subscribes it.
      // Drain it to drive the transport's teardown (an owned `http.Client` is
      // closed on its byte stream's `onDone`/`onCancel`) — otherwise every error
      // response leaks the socket. A drain error is irrelevant here; the status
      // is the failure we surface via the throw below.
      try {
        await response.body.drain<void>();
      } on Object {
        // Discarded deliberately: the throw below is the reported error path.
      }
      final error = TransportError(
        message: 'AG-UI endpoint returned HTTP ${response.statusCode}',
        code: KoelErrorCode.transportClosed,
        statusCode: response.statusCode,
      );
      // This connection ended on an error before any stream was built — fire
      // `onDisconnect(cause)` directly (the scope's once-guard keeps it single).
      connection.disconnect(error);
      throw error;
    }

    // Synthesize `*_CHUNK` → START/CONTENT/END here, the innermost transform
    // (per-connection, beneath `RetryInterceptor`): each reconnect re-runs this
    // terminal and gets a fresh `chunksStage` with empty envelope state, so a
    // half-open envelope never leaks across a reconnect. Gated by the agent's
    // flag (default on); reuses koel_core's single F.2 synthesizer rather than
    // forking it. Placed *inside* `abortOnCancel` so the abort gate wraps the
    // synthesized stream: `chunksStage` is `buildStage`-backed and cancels
    // upstream without running its `onDone` flush, so no trailing `END` is
    // emitted after a cancel and no synthesized event escapes the gate.
    // `onConnect` has already fired; `track` below is what pairs it with
    // `onDisconnect`. The one-to-one pairing the lifecycle contract promises
    // rests on this band staying throw-free: `parse` (`async*`), `transform`,
    // and `track` all build lazily and subscribe only under `yield*`, so a
    // synchronous throw cannot land here and orphan the `onConnect`. Any *stream*
    // error surfaced during `yield*` routes through `track`'s `onError`, which
    // fires `onDisconnect(cause)`. Keep this band lazy if it ever grows.
    final parsed = const SseParser().parse(response.body);
    final events = _agent.synthesizeChunks
        ? parsed.transform(chunksStage)
        : parsed;
    // Wrap so a consumer cancel fires `response.abort()` immediately (prompt TCP
    // teardown, NFR-8) and no event escapes after cancel — see [abortOnCancel].
    // The parser's `async*` strands cancel, so the abort cannot rely on cancel
    // threading through it. `track` sits *inside* the abort gate so it fires
    // `onDisconnect` once on this stream's end (done → `null`, error → the cause,
    // consumer cancel → `null`) without extending the sub-50ms abort budget —
    // the abort still fires first and the disconnect callback is fire-and-forget.
    yield* abortOnCancel(connection.track(events), response.abort);
  }
}
