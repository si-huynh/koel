import 'package:http/http.dart' as http;

// The platform decision: `dart.library.io` (VM/native) selects the real
// `io_transport.dart`; `dart.library.js_interop` (web) selects the throwing
// `web_transport.dart` (real fetch+ReadableStream transport lands in Story 4.10);
// neither available → `transport_stub.dart`. Each provides `createTransport()`.
import 'transport_stub.dart'
    if (dart.library.io) 'io_transport.dart'
    if (dart.library.js_interop) 'web_transport.dart';

/// The package-private SSE-connection seam `HttpAgent` opens its run over,
/// realized per-platform behind a conditional import.
///
/// One method, [connect], POSTs the encoded body and exposes the response's
/// **live, unbuffered** byte stream — the `Stream<List<int>>` `SseParser`
/// consumes. The implementation is selected at compile time: native streams
/// through `package:http`'s `IOClient` ([io_transport.dart]); web is a throwing
/// stub until Story 4.10 (`package:http`'s `BrowserClient` buffers the whole
/// body and cannot stream SSE — the reason web needs a hand-rolled transport).
abstract interface class Transport {
  /// The platform-selected transport instance (`IoTransport` on native, a
  /// throwing stub on web/other), resolved by the conditional import. Cheap:
  /// native is `const`.
  factory Transport() => createTransport();

  /// Opens the SSE connection: POSTs [body] to [url] with [headers], awaits the
  /// response headers (bounded by [connectTimeout]), and returns the status code
  /// plus the live response byte stream (idle-bounded by [readTimeout]).
  ///
  /// [client] is the consumer-injected `http.Client` — the test (`MockClient`)
  /// and backend seam; when null the transport supplies and owns a default
  /// client for the connection's lifetime. Throws (→ classified `RunErrorEvent`
  /// upstream) on connection refusal, TLS failure, or timeout; a non-2xx status
  /// is **not** thrown here — `HttpAgent` inspects [TransportResponse.statusCode].
  Future<TransportResponse> connect(
    Uri url, {
    required List<int> body,
    required Map<String, String> headers,
    required Duration connectTimeout,
    required Duration readTimeout,
    http.Client? client,
  });
}

/// The headers + live byte stream of an opened SSE connection.
///
/// Deliberately minimal: a connection abort/close handle (for sub-50ms
/// cancellation) is Story 4.3's concern and is added when that story actually
/// uses it — 4.2 tears connections down via subscription-cancel propagation.
final class TransportResponse {
  /// Wraps the [statusCode] and live [body] byte stream of a response.
  const TransportResponse({required this.statusCode, required this.body});

  /// The HTTP status of the response (checked for non-2xx by `HttpAgent`).
  final int statusCode;

  /// The live, unbuffered response byte stream — fed straight into `SseParser`.
  final Stream<List<int>> body;
}
