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
      final connection = _Connection(bounded, effectiveClient, owned: owned);

      return TransportResponse(
        statusCode: response.statusCode,
        body: connection.body,
        abort: connection.abort,
      );
    } catch (_) {
      // The connection never opened (refused / TLS / connect-timeout): release a
      // client we created before the failure escapes to the classifier.
      if (owned) effectiveClient.close();
      rethrow;
    }
  }
}

/// Owns the live response byte stream of one [IoTransport] connection.
///
/// Wraps the raw response stream so the connection tears down **exactly once** —
/// on normal completion, error, consumer cancel, or an explicit [abort] —
/// closing a self-created client and never leaking a socket. Single-subscription;
/// `pause`/`resume` pass straight through so backpressure reaches the socket.
///
/// Story 4.2 wrapped only the *owned*-client path (to close the client on
/// teardown); Story 4.3 wraps **every** path because [abort] and the
/// silent-drop guarantee need a koel-owned subscription to cancel regardless of
/// who owns the `http.Client`.
final class _Connection {
  _Connection(this._source, this._client, {required this.owned});

  final Stream<List<int>> _source;
  final http.Client _client;

  /// Whether the `http.Client` was created by the transport (and so must be
  /// closed here) rather than injected (consumer-owned — never closed here).
  final bool owned;

  // Nullable, not `late`: if `source.listen` throws synchronously inside
  // `onListen`, the field stays unassigned and the `?.` guards close the client
  // without a `LateInitializationError` masking the real failure.
  StreamSubscription<List<int>>? _subscription;
  var _clientClosed = false;

  /// The consumer-facing byte stream — fed straight into `SseParser`.
  late final Stream<List<int>> body = _wrap();

  Stream<List<int>> _wrap() {
    final controller = StreamController<List<int>>(sync: true);
    controller
      ..onListen = () {
        _subscription = _source.listen(
          controller.add,
          onError: controller.addError,
          onDone: () {
            _closeClient();
            controller.close();
          },
        );
      }
      ..onPause = () {
        _subscription?.pause();
      }
      ..onResume = () {
        _subscription?.resume();
      }
      ..onCancel = () {
        _closeClient();
        return _subscription?.cancel();
      };
    return controller.stream;
  }

  /// Prompt, explicit teardown for sub-50ms cancellation (Story 4.3, NFR-8):
  /// cancels the live response subscription — which on `IOClient` destroys the
  /// socket (TCP close) — and closes a self-created client. Idempotent; the
  /// returned future settles when the cancel does, so the caller can detect a
  /// client that ignores it.
  Future<void> abort() async {
    _closeClient();
    await _subscription?.cancel();
  }

  /// Closes a self-created client exactly once; an injected client is
  /// consumer-owned and never closed here.
  void _closeClient() {
    if (_clientClosed) return;
    _clientClosed = true;
    if (owned) _client.close();
  }
}

/// The native transport factory selected by `dart.library.io` (see
/// [Transport]'s conditional import).
Transport createTransport() => const IoTransport();
