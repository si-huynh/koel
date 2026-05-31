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

/// The headers + live byte stream + abort handle of an opened SSE connection.
final class TransportResponse {
  /// Wraps the [statusCode], live [body] byte stream, and [abort] handle of a
  /// response.
  const TransportResponse({
    required this.statusCode,
    required this.body,
    required this.abort,
  });

  /// The HTTP status of the response (checked for non-2xx by `HttpAgent`).
  final int statusCode;

  /// The live, unbuffered response byte stream — fed straight into `SseParser`.
  final Stream<List<int>> body;

  /// Tears the connection down **promptly** for sub-50ms consumer cancellation
  /// (NFR-8, Story 4.3): on native it cancels the live response subscription —
  /// which on `IOClient` destroys the socket (TCP close) — and closes a
  /// self-created client; on web (Story 4.10) it fires `AbortController.abort()`.
  ///
  /// `HttpAgent` invokes this the instant the consumer cancels the run, rather
  /// than waiting for cancel to thread down through `SseParser`'s `async*`
  /// stream. **Idempotent** and safe to call after the stream is already done.
  /// The returned future settles when the underlying teardown does, so the
  /// caller can detect a client that ignores abort (→ silent-drop + one-shot
  /// warning).
  final Future<void> Function() abort;
}
