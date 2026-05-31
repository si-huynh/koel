import 'dart:async';

import 'package:http/http.dart' as http;

import 'transport.dart';

/// The native (`dart:io`) [Transport]: streams an AG-UI SSE response through
/// `package:http`'s `IOClient` — the default `http.Client()` on the VM, backed
/// by `dart:io HttpClient`. `IOClient.send()` returns a `StreamedResponse` whose
/// `.stream` is a **live, unbuffered** `Stream<List<int>>` delivered as bytes
/// arrive, which is exactly what `SseParser` needs.
///
/// This is the *only* native-coupled file in `koel_http/lib/`; the conditional
/// import in [Transport] guarantees it is never loaded on web.
final class IoTransport implements Transport {
  /// Const default constructor — the transport holds no per-call state.
  const IoTransport();

  @override
  Future<TransportResponse> connect(
    Uri url, {
    required List<int> body,
    required Map<String, String> headers,
    required Duration connectTimeout,
    required Duration readTimeout,
    http.Client? client,
  }) async {
    // An injected client is consumer-owned and reused across runs; a client we
    // create ourselves must be closed once its byte stream is done — but never
    // while it is still live, or the connection drops mid-stream.
    final owned = client == null;
    final effectiveClient = client ?? http.Client();

    try {
      final request = http.Request('POST', url)
        ..headers.addAll(headers)
        ..bodyBytes = body;
      final response = await effectiveClient
          .send(request)
          .timeout(connectTimeout);

      // `Stream.timeout` resets on every byte, so it is a true inter-byte idle
      // bound: a gap longer than [readTimeout] surfaces a `TimeoutException`
      // (→ transportTimeout) on the stream, after which cancel propagation tears
      // the connection (and any owned client) down.
      final bounded = response.stream.timeout(readTimeout);
      final stream = owned
          ? _closingOnTeardown(bounded, effectiveClient)
          : bounded;

      return TransportResponse(statusCode: response.statusCode, body: stream);
    } catch (_) {
      // The connection never opened (refused / TLS / connect-timeout): release a
      // client we created before the failure escapes to the classifier.
      if (owned) effectiveClient.close();
      rethrow;
    }
  }

  /// Wraps [source] so the self-created [client] is closed exactly once the byte
  /// stream terminates — drained, errored, or cancelled — and never while it is
  /// still delivering bytes. Single-subscription, preserving pause/resume so
  /// backpressure reaches the socket.
  Stream<List<int>> _closingOnTeardown(
    Stream<List<int>> source,
    http.Client client,
  ) {
    final controller = StreamController<List<int>>(sync: true);
    // Nullable, not `late`: if `source.listen` throws synchronously inside
    // `onListen`, the field stays unassigned and the `?.` guards below close the
    // client without a `LateInitializationError` masking the real failure.
    StreamSubscription<List<int>>? subscription;
    var closed = false;
    void closeClient() {
      if (closed) return;
      closed = true;
      client.close();
    }

    controller
      ..onListen = () {
        subscription = source.listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            closeClient();
            controller.close();
          },
        );
      }
      ..onPause = () {
        subscription?.pause();
      }
      ..onResume = () {
        subscription?.resume();
      }
      ..onCancel = () {
        closeClient();
        return subscription?.cancel();
      };
    return controller.stream;
  }
}

/// The native transport factory selected by `dart.library.io` (see
/// [Transport]'s conditional import).
Transport createTransport() => const IoTransport();
