import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:koel_core/koel_core.dart';

import 'connection/reconnect_policy.dart';
import 'error/error_classifier.dart';
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
  /// The remaining parameters are part of the canonical (Addendum A.2)
  /// signature but are owned by later stories; they are accepted now so the
  /// constructor is a single one-way door, and consumed when their story lands:
  /// [retry]/[onReconnectAttempt] → Story 4.4 (retry/backoff),
  /// [synthesizeChunks] → Story 4.8 (CHUNK → START/CONTENT/END synthesis),
  /// [onConnect]/[onDisconnect] → Story 4.9 (connection lifecycle hooks).
  HttpAgent({
    required this.url,
    http.Client? client,
    List<Interceptor>? interceptors,
    this.connectTimeout = const Duration(seconds: 30),
    this.readTimeout = const Duration(minutes: 5),
    RetryPolicy? retry,
    bool synthesizeChunks = true,
    void Function()? onConnect,
    void Function(Object)? onDisconnect,
    void Function(int attempt, Duration delay)? onReconnectAttempt,
  }) : _client = client,
       _interceptors = interceptors ?? const <Interceptor>[];

  /// The AG-UI SSE endpoint each run POSTs to.
  final Uri url;

  /// Maximum time to await response headers; exceeding it → `transportTimeout`.
  final Duration connectTimeout;

  /// Maximum idle time between response bytes; exceeding it → `transportTimeout`.
  final Duration readTimeout;

  final http.Client? _client;
  final List<Interceptor> _interceptors;

  /// Runs [input] against [url]: POSTs it as JSON and yields the typed events
  /// the endpoint streams back, in wire order.
  ///
  /// Composed over `InterceptorChain` so [_interceptors] wrap the run and any
  /// transport/parser failure is classified into a terminal `RunErrorEvent`
  /// (the AC4 contract) — see the class dartdoc. Single-subscription, per the
  /// `AbstractAgent` contract.
  @override
  Stream<AgUiEvent> run(RunAgentInput input) => InterceptorChain(
    interceptors: _interceptors,
    agent: _TransportTerminal(this),
    errorClassifier: transportErrorClassifier(),
  ).proceed(input);
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
    final body = utf8.encode(jsonEncode(encodeRunAgentInput(input)));
    final response = await Transport().connect(
      _agent.url,
      body: body,
      headers: const {
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
      },
      connectTimeout: _agent.connectTimeout,
      readTimeout: _agent.readTimeout,
      client: _agent._client,
    );

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
      throw TransportError(
        message: 'AG-UI endpoint returned HTTP ${response.statusCode}',
        code: KoelErrorCode.transportClosed,
        statusCode: response.statusCode,
      );
    }

    yield* const SseParser().parse(response.body);
  }
}
