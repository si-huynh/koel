import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';

import 'conversion/message_conversion.dart';
import 'copilot_runtime_auth_interceptor.dart';
import 'error/copilot_runtime_error_classifier.dart';

/// `HttpAgent` targeting a CopilotKit ≥1.52 (v2) runtime's AG-UI route — one
/// constructor call connects a Flutter/Dart app to a `@copilotkit/runtime` v2
/// deployment (FR-G4, Addendum A.5 revised).
///
/// **Why `extends HttpAgent` now (D5 REVERSED, SCP-2026-06-05).** CopilotKit
/// dropped GraphQL (EOL ≤1.8.14); v2 (≥1.52) is **native AG-UI over SSE**
/// (`SPIKE-CK-V2`, `@copilotkit/runtime@1.59.4`) — the *same wire* agno/langgraph
/// emit, parsed by the *same* `koel_http` `SseParser`/`HttpAgent`. So this agent
/// joins `AgnoAgent`/`LangGraphAgent` as a thin `HttpAgent` subclass: no GraphQL
/// parser, no stateful converter, no run-lifecycle synthesis (the wire carries
/// `RUN_STARTED`/`RUN_FINISHED`), **no 7/28 partition**. The legacy
/// `implements AbstractAgent` GraphQL agent it replaces is gone (5.11 deletes the
/// orphaned parser). `LangGraphAgent` is the closest sibling — its structure is
/// cloned here verbatim-of-shape.
///
/// **Request side.** [run] POSTs the **complete** `RunAgentInput` to
/// `{endpoint}/agent/{agentName}/run`. The runtime is a transparent AG-UI
/// passthrough that parses the request into `@ag-ui/core` types — the body must
/// carry `{threadId, runId, state, messages, tools, context, forwardedProps}`
/// **all present** (its `parseRunRequest` 500s on a partial body). `HttpAgent`'s
/// inherited [encodeBody] already emits all of them, so the only request-side
/// work is normalizing koel's [Message] superset down to canonical AG-UI — done
/// by overriding [encodeBody] for `messages` alone (see
/// [copilotRuntimeMessageToWire]); every other field is the free win.
///
/// **Response side.** Pure inherited [HttpAgent] behavior (no event reshaping):
/// each `text/event-stream` frame is a canonical AG-UI event the inherited
/// `SseParser` yields verbatim — the full matrix (`STATE_DELTA`, `RUN_ERROR`,
/// `STEP_*`, `CUSTOM`, …), not the legacy GraphQL bridge's lossy 7/28 surface.
///
/// **Error contract (adapter-never-throw).** Every run-time failure — connection
/// refused, non-2xx status, malformed SSE, mid-stream protocol error — reaches
/// the consumer as a single terminal `RunErrorEvent` carrying a typed
/// `KoelError`, never an uncaught throw, for free via the inherited
/// `HttpAgent`/`InterceptorChain` composition (this agent writes no `run`
/// override, no transport terminal, no try/catch, no timeout plumbing). Transport/
/// parser throws are refined by [CopilotRuntimeErrorClassifier] (the
/// [errorClassifier] seam). The **only** permitted throw is a construction-time
/// [ArgumentError] from invalid configuration — never from [run].
class CopilotRuntimeAgent extends HttpAgent {
  /// Connects to the CopilotKit v2 runtime whose **base** path is [endpoint]
  /// (e.g. `http://host:8005/api/copilotkit`); runs POST to
  /// `{endpoint}/agent/{agentName}/run` (the join is trailing-slash-safe).
  ///
  /// [agentName] is the registered runtime agent this run dispatches to (the v2
  /// route is `/agent/{agentName}/run`). It is **required**: it names *the
  /// consumer's* agent (knowable only at construction), and no safe default
  /// exists — a hard-coded name would silently mis-target every real deployment
  /// (AR-15, "design for what users can't misuse").
  ///
  /// [authToken] wires a default-ON [CopilotRuntimeAuthInterceptor] (Bearer auth)
  /// prepended outermost to the chain, so a caller-supplied inner `AuthInterceptor`
  /// in [interceptors] wins the merge. The v2 runtime is open by default, so a
  /// Bearer is a harmless client convention — `null` (the default) or a blank
  /// token leaves the interceptor a no-op. [client] forwards straight to
  /// [HttpAgent].
  ///
  /// Throws an [ArgumentError] at construction when [endpoint] is not an absolute
  /// `http(s)` URL with an authority, or when [agentName] is blank — fail-fast on
  /// a misconfiguration rather than an opaque transport failure later.
  CopilotRuntimeAgent({
    required Uri endpoint,
    required String agentName,
    this.authToken,
    super.client,
    List<Interceptor>? interceptors,
  }) : agentName = agentName.trim(),
       super(
         url: _runEndpoint(endpoint, agentName),
         interceptors: [
           CopilotRuntimeAuthInterceptor(token: authToken),
           ...?interceptors,
         ],
       );

  /// The registered runtime agent this agent drives — the `{agentName}` segment
  /// of the `/agent/{agentName}/run` route (trimmed; a padded name is a caller
  /// typo, never a valid agent id).
  final String agentName;

  /// The bearer token injected by the default-ON [CopilotRuntimeAuthInterceptor]
  /// as an `Authorization: Bearer …` header on every run. `null` (the default) or
  /// a blank token leaves the interceptor a no-op — the right default for the open
  /// v2 runtime.
  final String? authToken;

  /// Builds the v2 run route `{endpoint}/agent/{agentName}/run`, trailing-slash-
  /// safe: both `http://host:8005/api/copilotkit` and `…/api/copilotkit/` resolve
  /// to `…/api/copilotkit/agent/{agentName}/run`. Rebuilding the path segments
  /// (vs raw concat or `Uri.resolve`, which mishandle a trailing slash or an
  /// empty base path) is the correct join; `Uri` percent-encodes the [agentName]
  /// segment automatically.
  ///
  /// Fails fast on an [endpoint] that cannot name an HTTP POST target — a
  /// non-`http(s)` scheme, or no authority (relative URI, no host) — or a blank
  /// [agentName] (it names no registered agent), with an [ArgumentError] at
  /// construction. Kept `static` so it runs before `super`. Any query/fragment on
  /// [endpoint] is preserved as-is (a fragment is never transmitted; a query may
  /// be a legitimate part of some deployments' base).
  static Uri _runEndpoint(Uri endpoint, String agentName) {
    if (!endpoint.isScheme('http') && !endpoint.isScheme('https')) {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'must be an absolute http(s) URL (e.g. http://host:8005/api/copilotkit)',
      );
    }
    if (!endpoint.hasAuthority) {
      throw ArgumentError.value(
        endpoint,
        'endpoint',
        'must have an authority (host)',
      );
    }
    final name = agentName.trim();
    if (name.isEmpty) {
      throw ArgumentError.value(
        agentName,
        'agentName',
        'must name the registered runtime agent to dispatch the run to',
      );
    }
    return endpoint.replace(
      pathSegments: [
        ...endpoint.pathSegments.where((segment) => segment.isNotEmpty),
        'agent',
        name,
        'run',
      ],
    );
  }

  @override
  Map<String, dynamic> encodeBody(RunAgentInput input) => <String, dynamic>{
    ...super.encodeBody(input),
    'messages': [
      for (final message in input.messages)
        copilotRuntimeMessageToWire(message),
    ],
  };

  @override
  ErrorClassifier errorClassifier() => const CopilotRuntimeErrorClassifier();
}
