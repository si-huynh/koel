import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';

/// Refines error classification for a CopilotKit v2 runtime: maps the transport
/// HTTP statuses the runtime (or a deployment's auth middleware) can surface onto
/// the business/agent [KoelErrorCode] vocabulary, and delegates everything else
/// to the native transport classifier (AR-20, FR-G4).
///
/// **Why it delegates to [transportErrorClassifier], not bare `super`.** D5 is
/// **reversed** (SCP-2026-06-05): `CopilotRuntimeAgent` now rides `koel_http`'s
/// `Transport`, so a non-2xx response is surfaced as a typed
/// `TransportError(statusCode:)` *before* classification (this class reads the
/// status off `raw` and remaps the v2-meaningful ones, 401/403/429/500), and
/// every other failure — crucially a `package:http`-wrapped `SocketException`/
/// `TlsException` from a pre-headers connection failure — must go through
/// `koel_http`'s [transportErrorClassifier], whose native `is` checks see through
/// the wrapper. A bare `super.classify` ([DefaultErrorClassifier]) matches those
/// types by runtime-type *name* and would slip a connection-refused to
/// [KoelErrorCode.unknown] — a regression versus a plain `HttpAgent`. Extending
/// [DefaultErrorClassifier] keeps the documented adapter-subclass shape; the
/// `_inner` delegate (defaulting to the platform classifier) is what keeps it
/// correct on the native path. Byte-parallel to `AgnoErrorClassifier`/
/// `LangGraphErrorClassifier`. Never throws, per [ErrorClassifier.classify].
///
/// **The mapped statuses.** A missing/invalid credential → **401 businessAuth**,
/// a forbidden resource → **403 businessForbidden**, an upstream rate-limiter →
/// **429 businessRateLimited**, the runtime's own internal fault → **500
/// agentInternal**. The v2 runtime ships no built-in auth, so 401/403/429 appear
/// only when a deployment fronts it with middleware; they are mapped for
/// forward-safety, byte-parallel to the agno/langgraph classifiers.
///
/// **This classifier handles transport/parser *throws* only — not wire
/// `RUN_ERROR`.** A v2 runtime is native AG-UI: it delivers an in-agent
/// `RUN_ERROR` **on the wire** as a parsed event the inherited `SseParser` yields
/// verbatim (the legacy GraphQL bridge's NFR-4 "swallows RUN_ERROR" divergence is
/// gone). So this classifier never sees a swallowed wire error — only the HTTP
/// statuses above and transport/parser throws (the latter routed to
/// [transportErrorClassifier]).
final class CopilotRuntimeErrorClassifier extends DefaultErrorClassifier {
  /// Creates a classifier that maps the v2 runtime's HTTP statuses and delegates
  /// the rest to [inner] — defaulting to the platform [transportErrorClassifier]
  /// so the native socket/TLS refinement is preserved (D5 reversed).
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
    // Everything else → the native transport classifier (socket/TLS `is`
    // refinement), NOT bare super — see the class dartdoc.
    return (_inner ?? transportErrorClassifier()).classify(raw, stack, input);
  }
}
