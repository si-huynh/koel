import 'dart:async';

import '../input/run_agent_input.dart';
import 'koel_error.dart';
import 'koel_error_code.dart';

/// Maps a raw failure (a caught exception, a thrown `Object`, …) onto the typed
/// [KoelError] union — the pluggable classification seam (architecture §5).
///
/// This is the seam adapters extend: a backend bridge subclasses
/// [DefaultErrorClassifier] to recognize its own failure shapes (HTTP status
/// codes, provider error envelopes) on top of the base Dart-exception mapping.
/// Per-adapter classifiers arrive in Epic 5.
abstract class ErrorClassifier {
  /// Classifies [raw] (with its [stack] and the originating [input]) into a
  /// typed [KoelError]. Implementations **must not throw** — every input,
  /// however exotic, must return a non-null [KoelError].
  KoelError classify(Object raw, StackTrace? stack, RunAgentInput input);
}

/// The framework-free base classifier mapping common Dart exception *shapes* to
/// [KoelError] subtypes. Web-safe by design: it never imports `dart:io` or
/// `package:http` (koel_core is the six-platform kernel — web has no `dart:io`,
/// architecture §D4).
///
/// `dart:io`/`package:http` failures (`SocketException`, `HandshakeException`,
/// `HttpException`, `ClientException`) are matched by runtime type **name**
/// rather than by `is` against the imported type. The caveat: a future SDK
/// rename of one of those long-stable types would silently slip through to the
/// [KoelErrorCode.unknown] bucket. That tradeoff buys web-safety with zero
/// dependencies and is acceptable for these types.
///
/// Status-code-aware refinement (HTTP 429 → [KoelErrorCode.businessRateLimited],
/// 401 → [KoelErrorCode.businessAuth], 403 → [KoelErrorCode.businessForbidden])
/// is **not** this classifier's job — it belongs to `koel_http`/adapter
/// subclasses (Epic 4/5), which may import `dart:io` and inspect status codes.
/// The base maps raw exception shapes only.
class DefaultErrorClassifier implements ErrorClassifier {
  /// Const default constructor.
  const DefaultErrorClassifier();

  @override
  KoelError classify(Object raw, StackTrace? stack, RunAgentInput input) {
    // Idempotent for already-classified failures: an upstream throw of a typed
    // KoelError (e.g. JsonPatch.apply's ProtocolError, Story 2.4) re-fed here
    // must keep its code/subtype, not be re-wrapped into AgentError(unknown).
    if (raw is KoelError) {
      return raw;
    }

    // dart:async / dart:core — web-universal, so matched by real `is` checks.
    if (raw is TimeoutException) {
      return TransportError(
        message: 'Request timed out',
        code: KoelErrorCode.transportTimeout,
        cause: raw,
      );
    }
    if (raw is FormatException) {
      return ProtocolError(
        message: 'Malformed payload',
        code: KoelErrorCode.protocolMalformed,
        cause: raw,
      );
    }

    // dart:io / package:http — matched by NAME so koel_core stays web-safe and
    // dependency-free (see class dartdoc).
    switch (raw.runtimeType.toString()) {
      case 'SocketException':
        return TransportError(
          message: 'Connection failed',
          code: KoelErrorCode.transportRefused,
          cause: raw,
        );
      case 'HandshakeException':
        return TransportError(
          message: 'TLS handshake failed',
          code: KoelErrorCode.transportTlsFail,
          cause: raw,
        );
      case 'HttpException':
      case 'ClientException':
        return TransportError(
          message: 'Transport closed',
          code: KoelErrorCode.transportClosed,
          cause: raw,
        );
      default:
        // Anything the classifier cannot positively identify is, from the SDK's
        // vantage, an opaque failure at the agent-execution boundary.
        return AgentError(
          message: 'Unclassified failure',
          code: KoelErrorCode.unknown,
          cause: raw,
        );
    }
  }
}
