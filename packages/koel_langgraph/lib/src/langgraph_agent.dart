import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';

import 'conversion/message_conversion.dart';
import 'error/langgraph_error_classifier.dart';
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
/// Surface-level interrupt-resume is supported via [resume]: the consumer
/// observes the `on_interrupt` `CUSTOM` event that rides a [run] stream and
/// reopens the run on the same thread, where LangGraph rebuilds state
/// server-side (no client-side reconstruction). Transport/parser failures are
/// refined by [LangGraphErrorClassifier] (the `x-api-key` 401/403/429 mappings);
/// an in-graph failure still reaches the consumer as a terminal `RunErrorEvent`,
/// never a throw.
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

  @override
  ErrorClassifier errorClassifier() => const LangGraphErrorClassifier();

  /// Reopens the run paused at a LangGraph `interrupt` on [threadId], delivering
  /// [resumeValue] to the waiting node and streaming the resumed run's events.
  ///
  /// Interrupt-resume is **surface-level** here (FR-C2, PRD §6.1): the consumer
  /// detects the pause itself — the interrupt rides the original [run] stream as
  /// a canonical `CUSTOM` event (`{name: "on_interrupt", value: …}`,
  /// [CustomEvent]); koel does **not** special-case it — then calls [resume]
  /// with the value the paused node awaits. koel reconstructs **no** state;
  /// LangGraph rebuilds it server-side from its checkpoint, keyed by [threadId]
  /// (SPIKE-LG-RESUME).
  ///
  /// [resumeValue] is typed `Object?` because the protocol resolves it to a
  /// server-side `Command(resume=<any JSON>)` — `ag-ui-langgraph` decodes a
  /// JSON-parseable string and otherwise forwards the raw value, so a bare
  /// string, number, bool, list, map, or `null` are all valid resume answers.
  /// This mirrors [CustomEvent.value] (`value: any`, the inbound half of the
  /// same interrupt cycle): whatever shape the `on_interrupt` carries out, the
  /// resume can answer with the same shape.
  ///
  /// The resume POSTs to the **same** `deploymentUrl` (there is no separate
  /// resume route) a `RunAgentInput` carrying the same [threadId] and
  /// `forwardedProps: {"command": {"resume": resumeValue}}` — the exact shape
  /// `ag-ui-langgraph` reads to build the server-side `Command(resume=…)`. The
  /// `runId` is per-request (the **thread**, not the run, is the checkpoint
  /// key), so a deterministic `resume-<threadId>` id is minted; the server keys
  /// resumption on [threadId], not `runId`. Delegating to [run] means the
  /// default-ON `x-api-key` auth, the canonical-AG-UI body encoding, and the
  /// inherited SSE parse all apply unchanged — including the error contract: a
  /// failed resume surfaces as a terminal `RunErrorEvent`, never a throw.
  ///
  /// Throws an [ArgumentError] when [threadId] is blank — a blank thread names
  /// no checkpoint to reload, so it is a programmer error caught before any run
  /// (the only throw; the resumed stream itself never throws). The thread is
  /// trimmed before use so a padded id resolves to the same checkpoint.
  ///
  /// Deep (stateful sub-tree) interrupt-resume defers to v2
  /// (OQ-LangGraph-Graduation).
  Stream<AgUiEvent> resume(String threadId, Object? resumeValue) {
    final thread = threadId.trim();
    if (thread.isEmpty) {
      throw ArgumentError.value(
        threadId,
        'threadId',
        'must name the interrupted thread to reload its checkpoint',
      );
    }
    return run(
      RunAgentInput(
        threadId: thread,
        runId: 'resume-$thread',
        forwardedProps: {
          'command': {'resume': resumeValue},
        },
      ),
    );
  }
}
