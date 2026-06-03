import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:koel_core/koel_core.dart';
import 'package:meta/meta.dart';

import 'multipart_graphql_stream_parser.dart';

/// `AbstractAgent` over the CopilotKit Next.js runtime — one constructor call
/// connects a Flutter/Dart app to a `@copilotkit/runtime` deployment's
/// `generateCopilotResponse` GraphQL mutation (FR-C3, AR-20, Addendum A.5).
///
/// **Why `implements AbstractAgent`, not `extends HttpAgent` (the defining
/// constraint).** D5 makes `koel_runtime` independent of `koel_http`. `HttpAgent`
/// lives in `koel_http` and carries the SSE transport stack (`SseParser`,
/// `Transport`, the native/web seam, `abortOnCancel`, retry/auth interceptors) —
/// none of which apply to a GraphQL `multipart/mixed` bridge. So this agent
/// implements the bare `AbstractAgent` SPI **directly** and hand-rolls its own
/// POST + stream wiring over `package:http`. This is a deliberate contrast to
/// `AgnoAgent`/`LangGraphAgent`, which *do* `extends HttpAgent`. The shared
/// machinery this agent reuses — `InterceptorChain`, `DefaultErrorClassifier`,
/// the event types — all live in `koel_core`, so reuse stays D5-clean (no
/// `koel_http` edge, no GraphQL client).
///
/// **Request side.** [run] POSTs `{operationName, query, variables}` as JSON with
/// `Accept: multipart/mixed`, baking in the four request invariants the live
/// runtime requires (`metadata.requestType`, `messages`, `frontend.actions: []`,
/// `metaEvents: []`) plus `agentSession.agentName` to dispatch the registered
/// agent (SPIKE-CK-FRAMING). The verbatim selection set carries the load-bearing
/// `@defer`/`@stream` directives that drive Incremental Delivery — strip them and
/// the runtime returns a single non-streamed JSON body the parser cannot frame.
///
/// **Response side.** The `multipart/mixed` body streams through Story 5.7's
/// [MultipartGraphQLStreamParser] unchanged; this agent brackets that parser's
/// MESSAGE/TOOL/STATE output with the `RUN_STARTED`/`RUN_FINISHED` the parser
/// deliberately leaves to the agent (the initial wire part carries `runId:null`,
/// which `RunStartedEvent`/`RunFinishedEvent` forbid — the agent owns
/// `RunAgentInput.{threadId, runId}`, so it can synthesize them).
///
/// **Error contract (adapter-never-throw).** Every run-time failure — connection
/// refused, non-2xx status, malformed multipart body, mid-stream protocol error —
/// reaches the consumer as a single terminal `RunErrorEvent` carrying a typed
/// `KoelError`, never an uncaught throw. This is composed for free over
/// `koel_core`'s [InterceptorChain], exactly as `HttpAgent.run` does it. The
/// **only** permitted throw is a construction-time [ArgumentError] from invalid
/// configuration — never from [run].
///
/// **Divergence (documented, NFR-4).** The runtime *swallows* an AG-UI
/// `RUN_ERROR` raised inside the agent — it ends the stream with `status:Success`
/// and drops the remaining text. So this agent's `RUN_ERROR` path surfaces only
/// **transport/parser** failures (the sole observable error surface here);
/// copilotkit is a transport-conformance target, not an AG-UI-event-matrix source
/// (the AG-UI dojo covers all event types). Refinement of the error codes from a
/// GraphQL `extensions.code` envelope is Story 5.9's `CopilotRuntimeErrorClassifier`.
final class CopilotRuntimeAgent implements AbstractAgent {
  /// Connects to the CopilotKit runtime whose GraphQL endpoint is
  /// [graphqlEndpoint] — the **full** endpoint, used verbatim (e.g.
  /// `http://host:8004/api/copilotkit`); nothing is appended.
  ///
  /// [agentName] is the name of the registered runtime agent this run dispatches
  /// to (sent as `agentSession.agentName`). It is **required**: without it the
  /// runtime falls through to its service adapter and `ExperimentalEmptyAdapter`
  /// throws, and no safe default exists — a hard-coded name would silently
  /// mis-target every real deployment. It names *the consumer's* agent, knowable
  /// only at construction.
  ///
  /// [authToken] is optional — the 1.8.14 runtime is open by default, so a
  /// `Bearer` header is a harmless client convention sent only when set. [client]
  /// is the injectable transport seam (tests pass `MockClient`, backends a pooled
  /// client); when null a default client is created and owned per run. An injected
  /// client is **never** closed by the agent — the caller owns its lifecycle.
  ///
  /// Throws an [ArgumentError] at construction when [graphqlEndpoint] is not an
  /// absolute `http(s)` URL with an authority, or when [agentName] is blank —
  /// fail-fast on a misconfiguration rather than an opaque transport failure
  /// later.
  CopilotRuntimeAgent({
    required Uri graphqlEndpoint,
    required String agentName,
    this.authToken,
    http.Client? client,
  }) : graphqlEndpoint = _validateEndpoint(graphqlEndpoint),
       agentName = _validateAgentName(agentName),
       _client = client;

  /// The full GraphQL endpoint each run POSTs to, used verbatim.
  final Uri graphqlEndpoint;

  /// The registered runtime agent this agent drives, sent as
  /// `data.agentSession.agentName` on every run.
  final String agentName;

  /// The optional bearer token sent as `Authorization: Bearer <authToken>`;
  /// `null` (the default) sends no `Authorization` header — the right default for
  /// the open local runtime.
  final String? authToken;

  final http.Client? _client;

  /// Validates [endpoint] names an absolute `http(s)` POST target with an
  /// authority and returns it unchanged. Mirrors `LangGraphAgent`'s fail-fast
  /// validation idiom.
  static Uri _validateEndpoint(Uri endpoint) {
    if (!endpoint.isScheme('http') && !endpoint.isScheme('https')) {
      throw ArgumentError.value(
        endpoint,
        'graphqlEndpoint',
        'must be an absolute http(s) URL (e.g. http://host:8004/api/copilotkit)',
      );
    }
    if (!endpoint.hasAuthority) {
      throw ArgumentError.value(
        endpoint,
        'graphqlEndpoint',
        'must have an authority (host)',
      );
    }
    return endpoint;
  }

  /// Validates [agentName] is non-blank — a blank name dispatches to no
  /// registered agent — and returns it unchanged.
  static String _validateAgentName(String agentName) {
    if (agentName.trim().isEmpty) {
      throw ArgumentError.value(
        agentName,
        'agentName',
        'must name the registered runtime agent to dispatch the run to',
      );
    }
    return agentName;
  }

  /// Runs [input] against [graphqlEndpoint]: POSTs the GraphQL mutation and
  /// yields `RUN_STARTED → <parser's MESSAGE/TOOL/STATE events> → RUN_FINISHED`,
  /// in wire order.
  ///
  /// Composed over `InterceptorChain` (empty interceptor list = terminal + error
  /// classification) so any transport/parser failure is classified into a
  /// terminal `RunErrorEvent` — the adapter-never-throw contract for free, parity
  /// with `HttpAgent.run`. Single-subscription, per the `AbstractAgent` contract.
  @override
  Stream<AgUiEvent> run(RunAgentInput input) => InterceptorChain(
    interceptors: const [],
    agent: _CopilotRuntimeTerminal(this),
    errorClassifier: errorClassifier(),
  ).proceed(input);

  /// The [ErrorClassifier] each run's `InterceptorChain` routes failures through.
  ///
  /// The default is the framework-free [DefaultErrorClassifier], which passes a
  /// typed `KoelError` (this agent's non-2xx [TransportError], the parser's
  /// [ProtocolError]) through unchanged and buckets an unknown raw throw into
  /// `AgentError(unknown)`. Story 5.9 swaps in `CopilotRuntimeErrorClassifier`
  /// (the GraphQL `extensions.code` refinement) here without touching [run] —
  /// the seam mirrors `HttpAgent.errorClassifier()`.
  @protected
  ErrorClassifier errorClassifier() => const DefaultErrorClassifier();

  /// Builds the GraphQL `variables` map for [input]: `{data: …, properties: {}}`.
  ///
  /// `data` carries the four bake-in request invariants the live runtime requires
  /// — `metadata.requestType: 'Chat'`, `messages`, `frontend.actions: []`, and
  /// **`metaEvents: []`** (omitting it → the runtime reads `.length` on
  /// `undefined` and 500s) — plus `agentSession.agentName` to drive the registered
  /// agent, and `threadId`/`runId` from [input]. The empty lists are kept typed
  /// so JSON encodes them as `[]`.
  Map<String, dynamic> _buildVariables(RunAgentInput input) => {
    'data': {
      'metadata': {'requestType': 'Chat'},
      'threadId': input.threadId,
      'runId': input.runId,
      'messages': [
        for (final message in input.messages) _messageInput(message),
      ],
      'frontend': {'actions': <dynamic>[]},
      'metaEvents': <dynamic>[],
      'agentSession': {'agentName': agentName},
    },
    'properties': <String, dynamic>{},
  };

  /// Maps one koel [Message] to a CopilotKit `MessageInput`: the `{id, createdAt}`
  /// base plus exactly one role-shaped sub-object. A `tool`-role message becomes a
  /// `resultMessage` (a tool result linked back to its call); every other role
  /// becomes a `textMessage`.
  ///
  /// The `default` arm is required by koel_lints' `exhaustive_switch_must_have_default`
  /// even though `MessageRole` is exhausted — it is the role-to-`textMessage`
  /// mapping for `user`/`assistant`/`system` (and any future role).
  Map<String, dynamic> _messageInput(Message message) {
    final base = <String, dynamic>{
      'id': message.id,
      'createdAt': message.timestamp.toIso8601String(),
    };
    switch (message.role) {
      case MessageRole.tool:
        return {
          ...base,
          'resultMessage': {
            'actionExecutionId': message.toolCallId,
            'actionName': message.name,
            'result': message.content,
          },
        };
      default:
        return {
          ...base,
          'textMessage': {
            'content': message.content,
            'role': message.role.name,
          },
        };
    }
  }
}

/// The transport-level terminal `AbstractAgent` wrapped by [CopilotRuntimeAgent.run]'s
/// `InterceptorChain`. It synthesizes the run-lifecycle envelope and does the
/// actual POST + multipart parse, throwing raw transport failures; sitting behind
/// the chain turns those throws into the terminal `RunErrorEvent` the consumer
/// sees, without a hand-rolled try/catch adapter.
///
/// `RUN_STARTED` is yielded *before* the POST, so a pre-headers failure still
/// surfaces as `RUN_STARTED → RUN_ERROR` (the prefix already on the wire is
/// preserved; the chain appends the trailing error). `RUN_FINISHED` is appended
/// only after the parser completes cleanly.
final class _CopilotRuntimeTerminal implements AbstractAgent {
  _CopilotRuntimeTerminal(this._agent);

  final CopilotRuntimeAgent _agent;

  @override
  Stream<AgUiEvent> run(RunAgentInput input) async* {
    yield RunStartedEvent(threadId: input.threadId, runId: input.runId);

    // An injected client is the caller's to close; a default-created one is owned
    // and closed in the `finally` (covers normal completion, error, and a
    // consumer cancel — a cancelled `async*` runs its `finally`). There is no
    // `response.abort()` budget like `HttpAgent`'s: `package:http`'s
    // `StreamedResponse` has no `abort()`, so closing the client tears the socket
    // down. That is the correct D5 boundary — `koel_http`'s `abortOnCancel`/
    // `Transport` are off-limits here.
    final injected = _agent._client;
    final client = injected ?? http.Client();
    try {
      final authToken = _agent.authToken;
      final request = http.Request('POST', _agent.graphqlEndpoint)
        ..headers.addAll({
          'Content-Type': 'application/json',
          'Accept': 'multipart/mixed',
          if (authToken != null) 'Authorization': 'Bearer $authToken',
        })
        ..bodyBytes = utf8.encode(
          jsonEncode({
            'operationName': 'generateCopilotResponse',
            'query': _query,
            'variables': _agent._buildVariables(input),
          }),
        );

      final response = await client.send(request);

      // A non-2xx response is not a thrown exception — detect it and throw the
      // typed error the classifier passes through (idempotently) to
      // `RunErrorEvent`. Drain the body first so an owned client's socket is not
      // leaked; a drain error is irrelevant — the status is the failure we report.
      if (response.statusCode < 200 || response.statusCode >= 300) {
        try {
          await response.stream.drain<void>();
        } on Object {
          // Discarded deliberately: the throw below is the reported error path.
        }
        throw TransportError(
          message: 'CopilotKit runtime returned HTTP ${response.statusCode}',
          code: KoelErrorCode.transportClosed,
          statusCode: response.statusCode,
        );
      }

      yield* const MultipartGraphQLStreamParser().parse(response.stream);
      yield RunFinishedEvent(threadId: input.threadId, runId: input.runId);
    } finally {
      if (injected == null) client.close();
    }
  }
}

/// The verbatim `generateCopilotResponse` mutation document the runtime client
/// sends. The `@defer` (response/message `status`) and `@stream` (`messages`,
/// `TextMessageOutput.content`, `ActionExecutionMessageOutput.arguments`)
/// directives are load-bearing — they drive the `multipart/mixed` Incremental
/// Delivery the parser consumes; without them the runtime returns one
/// non-streamed JSON body the parser cannot frame.
///
/// This is the live-verified selection set that closed SPIKE-CK-FRAMING with a
/// 200 multipart response (`@copilotkit/runtime@1.8.14`, 2026-06-02) — the same
/// shape the 5.7 parser/converter were built against. The runtime-client's
/// `metaEvents @stream` block (a LangGraph-interrupt concern outside copilotkit's
/// text/tool/state scenarios) is intentionally not requested here; the request's
/// bake-in `metaEvents: []` *variable* — which prevents the runtime 500 — is
/// unrelated and is always sent (see `_buildVariables`). 5.9's live capture
/// characterizes the request/response shapes against the running backend.
const _query = '''
mutation generateCopilotResponse(\$data: GenerateCopilotResponseInput!, \$properties: JSONObject) {
  generateCopilotResponse(data: \$data, properties: \$properties) {
    threadId
    runId
    extensions { openaiAssistantAPI { runId threadId } }
    ... on CopilotResponse @defer {
      status {
        ... on BaseResponseStatus { code }
        ... on FailedResponseStatus { reason details }
      }
    }
    messages @stream {
      __typename
      ... on BaseMessageOutput { id createdAt }
      ... on BaseMessageOutput @defer {
        status {
          ... on SuccessMessageStatus { code }
          ... on FailedMessageStatus { code reason }
          ... on PendingMessageStatus { code }
        }
      }
      ... on TextMessageOutput { content @stream role parentMessageId }
      ... on ActionExecutionMessageOutput { name arguments @stream parentMessageId }
      ... on ResultMessageOutput { result actionExecutionId actionName }
      ... on AgentStateMessageOutput { threadId state running agentName nodeName runId active role }
    }
  }
}''';
