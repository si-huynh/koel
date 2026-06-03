import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';

/// Refines error classification for agno backends: maps the HTTP statuses an
/// agno deployment's (opt-in) auth/rate-limit middleware emits onto the business
/// [KoelErrorCode] vocabulary, and delegates everything else to the native
/// transport classifier (AR-20, FR-C1).
///
/// **Why it delegates to [transportErrorClassifier], not bare `super`.** A
/// non-2xx response is surfaced by `koel_http`'s transport as a typed
/// `TransportError(statusCode:)` *before* classification, so this class reads the
/// status off `raw` and remaps the agno-meaningful ones (401/403/429). Every
/// other failure — crucially a `package:http`-wrapped `SocketException` — must go
/// through `koel_http`'s [transportErrorClassifier], whose native `is` checks see
/// through the wrapper. A bare `super.classify` ([DefaultErrorClassifier]) matches
/// those types by runtime-type *name* and would slip a connection-refused to
/// [KoelErrorCode.unknown] — a regression versus a plain `HttpAgent`. Extending
/// [DefaultErrorClassifier] keeps the documented adapter-subclass shape; the
/// `_inner` delegate (defaulting to the platform classifier) is what keeps it
/// correct on the native path. Never throws, per [ErrorClassifier.classify].
///
/// **Deferred to Story 5.3.** Mapping agno's native *agent-error JSON envelope*
/// to `agentRefused`/`agentInternal` is not built here: the envelope shape is
/// uncharacterized (the backend spike ran text-only), so a parser now would be
/// speculative. It lands once a real error fixture is captured (Story 5.3).
final class AgnoErrorClassifier extends DefaultErrorClassifier {
  /// Creates a classifier that maps agno HTTP statuses and delegates the rest to
  /// [inner] — defaulting to the platform [transportErrorClassifier] so the
  /// native socket/TLS refinement is preserved.
  const AgnoErrorClassifier({ErrorClassifier? inner}) : _inner = inner;

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
        _ => null,
      };
      if (mapped != null) return mapped;
    }
    // Everything else → the native transport classifier (socket/TLS `is`
    // refinement), NOT bare super — see the class dartdoc.
    return (_inner ?? transportErrorClassifier()).classify(raw, stack, input);
  }
}
