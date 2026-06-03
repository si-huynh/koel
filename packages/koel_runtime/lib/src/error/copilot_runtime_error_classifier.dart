import 'package:koel_core/koel_core.dart';

/// Refines error classification for the CopilotKit Next.js runtime: maps the
/// transport HTTP statuses the runtime (or a deployment's auth middleware) can
/// surface onto the business/agent [KoelErrorCode] vocabulary, and delegates
/// every other failure to an injected `inner` classifier — defaulting to the
/// framework-free [DefaultErrorClassifier] (AR-20, FR-G1).
///
/// **Why it delegates to [DefaultErrorClassifier], not `koel_http`'s
/// `transportErrorClassifier`.** `koel_runtime` is independent of `koel_http`
/// (D5/AR-10): the native socket-`is` refinement classifier lives in `koel_http`
/// and is off-limits here. `CopilotRuntimeAgent` hand-rolls its POST over
/// `package:http`, whose pre-headers failures arrive as a `ClientException`
/// (matched by name in [DefaultErrorClassifier]) and whose non-2xx responses the
/// agent's terminal raises as a typed `TransportError` — so the web-safe base is
/// the correct, D5-clean inner delegate. A bare `super.classify` would do the
/// same job, but the explicit `_inner` seam keeps the adapter-subclass shape
/// uniform with `AgnoErrorClassifier`/`LangGraphErrorClassifier` and lets a test
/// inject a stub. Never throws, per [ErrorClassifier.classify].
///
/// **The mapped statuses.** A non-2xx response is surfaced by the agent's
/// terminal as a typed `TransportError(statusCode:)` *before* classification, so
/// this class reads the status off `raw` and remaps the copilotkit-meaningful
/// ones: a missing/invalid credential → **401 businessAuth**, a forbidden
/// resource → **403 businessForbidden**, an upstream rate-limiter → **429
/// businessRateLimited**, and the runtime's own internal fault → **500
/// agentInternal** (the documented `metaEvents`-omission 500 is a runtime-side
/// `TypeError`, `SPIKE-CK-FRAMING` — an internal error of the runtime, not a
/// business status). The 1.8.14 runtime ships no built-in auth, so 401/403/429
/// appear only when a deployment fronts it with middleware; they are mapped for
/// forward-safety, byte-parallel to the agno/langgraph classifiers.
///
/// **No GraphQL `extensions.code` mapping (evidence-gated).** The runtime
/// *swallows* an in-agent `RUN_ERROR` — it ends the stream with `status:Success`
/// and emits no GraphQL `errors` (`SPIKE-CK-FRAMING`) — so the classifier never
/// sees a swallowed wire error, only transport/parser *throws*. The genuinely
/// observable error surfaces are the HTTP statuses above and a transport-level
/// GraphQL `errors[]` body; the latter has no captured shape to key off, so the
/// speculative `extensions.code` mapping is not built (no speculative parser,
/// per CLAUDE.md). See `deferred-work.md` for the deferral.
final class CopilotRuntimeErrorClassifier extends DefaultErrorClassifier {
  /// Creates a classifier that maps the copilotkit transport statuses and
  /// delegates the rest to [inner] — defaulting to the framework-free
  /// [DefaultErrorClassifier] (D5: no `koel_http` transport classifier).
  const CopilotRuntimeErrorClassifier({ErrorClassifier? inner})
    : _inner = inner;

  final ErrorClassifier? _inner;

  @override
  KoelError classify(Object raw, StackTrace? stack, RunAgentInput input) {
    if (raw is TransportError && raw.statusCode != null) {
      final mapped = switch (raw.statusCode!) {
        401 => BusinessError(
          message: 'Authentication required or invalid',
          code: KoelErrorCode.businessAuth,
          cause: raw,
        ),
        403 => BusinessError(
          message: 'Access forbidden',
          code: KoelErrorCode.businessForbidden,
          cause: raw,
        ),
        429 => BusinessError(
          message: 'Rate limited',
          code: KoelErrorCode.businessRateLimited,
          cause: raw,
        ),
        500 => AgentError(
          message: 'CopilotKit runtime internal error',
          code: KoelErrorCode.agentInternal,
          cause: raw,
        ),
        _ => null,
      };
      if (mapped != null) return mapped;
    }
    // Everything else → the injected inner, defaulting to the web-safe base
    // (NOT koel_http's transportErrorClassifier — forbidden under D5).
    return (_inner ?? const DefaultErrorClassifier()).classify(
      raw,
      stack,
      input,
    );
  }
}
