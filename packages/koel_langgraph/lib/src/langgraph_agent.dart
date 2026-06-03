import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';

import 'conversion/message_conversion.dart';
import 'langgraph_auth_interceptor.dart';

/// `HttpAgent` targeting a LangGraph deployment's AG-UI route — one constructor
/// call connects a Flutter/Dart app to a LangGraph (`ag-ui-langgraph`) backend
/// (FR-C2, Addendum A.4).
///
/// LangGraph (via `ag-ui-langgraph==0.0.37`) is **native AG-UI** (SPIKE-LG-RESUME,
/// `../koel_backend/backends/langgraph/CONTRACT.md`): its single `POST` route
/// parses koel's camelCase `RunAgentInput` directly and streams canonical AG-UI
/// SSE back via the protocol `EventEncoder`. The LangGraph↔AG-UI translation
/// (channels, `thread_state`, checkpoints) is internal to that package — it never
/// crosses the koel wire. So the response path is pure inherited [HttpAgent]
/// behavior (no event reshaping), and the only request-side work is normalizing
/// koel's [Message] superset down to canonical AG-UI — done by overriding the
/// [HttpAgent.encodeBody] seam for `messages` alone (see [langGraphMessageToWire]).
///
/// The LangGraph error classifier and the surface-level
/// `resume(threadId, resumeValue)` interrupt flow are **not** part of this agent
/// yet — they arrive in Stories 5.6 and 5.5 respectively. Until then
/// `LangGraphAgent` inherits [HttpAgent]'s `DefaultErrorClassifier`.
class LangGraphAgent extends HttpAgent {
  /// Connects to the LangGraph deployment whose AG-UI route is [deploymentUrl].
  ///
  /// Unlike agno's `baseURL` (which gets a fixed `/agno-chat` route appended),
  /// [deploymentUrl] is the **full** AG-UI POST endpoint and is used verbatim —
  /// `ag-ui-langgraph`'s route path is caller-configured
  /// (`add_langgraph_fastapi_endpoint(..., path: …)`), so there is no canonical
  /// suffix koel can safely assume. The caller passes the exact endpoint their
  /// deployment exposes (e.g. `http://host:8003/agent`).
  ///
  /// [apiKey] wires a default-ON [LangGraphAuthInterceptor] (`x-api-key` header)
  /// prepended outermost to the chain, so a caller-supplied inner `AuthInterceptor`
  /// in [interceptors] wins the merge. [client] forwards straight to [HttpAgent].
  LangGraphAgent({
    required Uri deploymentUrl,
    this.apiKey,
    super.client,
    List<Interceptor>? interceptors,
  }) : super(
         url: _validateDeploymentUrl(deploymentUrl),
         interceptors: [
           LangGraphAuthInterceptor(apiKey: apiKey),
           ...?interceptors,
         ],
       );

  /// The `x-api-key` value injected by the default-ON [LangGraphAuthInterceptor]
  /// on every run. `null` (the default) or a blank value leaves the interceptor a
  /// no-op — the right default for the open local deployment.
  final String? apiKey;

  /// Validates [deploymentUrl] names an HTTP POST target — an absolute `http(s)`
  /// URL with an authority — and returns it **unchanged** (used verbatim as the
  /// AG-UI route; nothing is appended). Fails fast with an [ArgumentError] at
  /// construction on a non-`http(s)` scheme or a missing authority (relative URI,
  /// no host), rather than building a nonsense endpoint that fails opaquely at
  /// transport.
  static Uri _validateDeploymentUrl(Uri deploymentUrl) {
    if (!deploymentUrl.isScheme('http') && !deploymentUrl.isScheme('https')) {
      throw ArgumentError.value(
        deploymentUrl,
        'deploymentUrl',
        'must be an absolute http(s) URL (e.g. http://host:8003/agent)',
      );
    }
    if (!deploymentUrl.hasAuthority) {
      throw ArgumentError.value(
        deploymentUrl,
        'deploymentUrl',
        'must have an authority (host)',
      );
    }
    return deploymentUrl;
  }

  @override
  Map<String, dynamic> encodeBody(RunAgentInput input) => <String, dynamic>{
    ...super.encodeBody(input),
    'messages': [
      for (final message in input.messages) langGraphMessageToWire(message),
    ],
  };
}
