import 'dart:io';

import 'package:koel_core/koel_core.dart';

/// The native transport [ErrorClassifier] factory, selected by `dart.library.io`
/// (see [error_classifier.dart]'s conditional import).
ErrorClassifier createErrorClassifier() => const TransportErrorClassifier();

/// koel_http's transport-aware [ErrorClassifier]: refines [DefaultErrorClassifier]
/// for the native (`dart:io` / `package:http`) failure shapes the web-safe base
/// classifier cannot see.
///
/// `koel_core`'s base matches `dart:io` exceptions by `runtimeType.toString()`
/// so it never imports `dart:io` (it is the six-platform kernel). That
/// name-matching has a blind spot: `package:http`'s `IOClient` **catches** a
/// `dart:io` `SocketException` and rethrows it **wrapped** in a private
/// `ClientException` subtype (`io_client.dart:226-227`, http 1.6.0). The
/// wrapper's concrete `runtimeType` is neither `SocketException` *nor*
/// `ClientException`, so a connection-refused slips through the base's `switch`
/// to `KoelErrorCode.unknown` — silently violating AC4 on the real native path
/// (an injected `MockClient` throwing a *raw* `SocketException` hides this).
///
/// koel_http *is allowed* to import `dart:io` (it is the native transport
/// package), so it classifies the transport families by real `is` checks, which
/// see through the wrapper (`_ClientSocketException implements SocketException`)
/// and the whole `TlsException` hierarchy (`HandshakeException`/
/// `CertificateException extends TlsException`, `secure_socket.dart:1482,1491`).
/// Everything else — `TimeoutException`, `FormatException`, already-typed
/// `KoelError`s, and the by-name `HttpException`/`ClientException` →
/// `transportClosed` arm — defers to [super].
///
/// This class is the koel_http extension point the koel_core seam dartdoc
/// anticipates ("backend bridge subclasses `DefaultErrorClassifier`"); Epic-5
/// status-code-aware classifiers refine it further.
final class TransportErrorClassifier extends DefaultErrorClassifier {
  /// Const default constructor.
  const TransportErrorClassifier();

  @override
  KoelError classify(Object raw, StackTrace? stack, RunAgentInput input) {
    // `is SocketException` sees through `package:http`'s `_ClientSocketException`
    // wrapper (it `implements SocketException`) — the connection-refused path the
    // by-name base classifier cannot catch.
    if (raw is SocketException) {
      return TransportError(
        message: 'Connection failed',
        code: KoelErrorCode.transportRefused,
        cause: raw,
      );
    }
    // The whole TLS failure family (handshake + certificate) → tlsFail.
    if (raw is TlsException) {
      return TransportError(
        message: 'TLS handshake failed',
        code: KoelErrorCode.transportTlsFail,
        cause: raw,
      );
    }
    return super.classify(raw, stack, input);
  }
}
