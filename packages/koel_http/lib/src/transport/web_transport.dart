import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

import 'transport.dart';

/// The web (`dart.library.js_interop`) [Transport]: streams an AG-UI SSE
/// response through the browser's `window.fetch` + `ReadableStream`, with
/// `AbortController` for cancellation.
///
/// `package:http`'s `BrowserClient` uses XHR and **buffers the entire response
/// body** before completing — fatal for an infinite SSE stream — so web cannot
/// reuse the native `http.Client` path. `EventSource` is also rejected (D4): it
/// cannot set custom request headers, which would silently break
/// `AuthInterceptor`'s `Authorization` on web. Hence a hand-rolled `fetch`
/// transport: the `RequestInit.headers` it sends carry the same merged
/// `{...auth, Content-Type, Accept}` map `HttpAgent` builds, so `Authorization`
/// flows through with zero web-specific auth code.
///
/// The returned [TransportResponse] is **byte-for-byte the same shape** native
/// returns (`statusCode`/`body`/`abort`), so every layer above the transport
/// seam — auth, retry, chunk synthesis, the SSE parse, lifecycle hooks, the
/// non-2xx throw path, and the sub-50ms cancellation watchdog — works on web
/// with no platform-specific code. A non-2xx status is **not** thrown here
/// (`fetch` rejects only on a pre-headers network failure, exactly like native):
/// `HttpAgent` inspects [TransportResponse.statusCode].
///
/// This file is loaded **only on web** — the [Transport] conditional import
/// guarantees the VM never sees it, so its `package:web`/`dart:js_interop`
/// imports never pollute the native path.
final class WebTransport implements Transport {
  /// Const default constructor — the transport holds no per-call state.
  const WebTransport();

  @override
  Future<TransportResponse> connect(
    Uri url, {
    required List<int> body,
    required Map<String, String> headers,
    required Duration connectTimeout,
    required Duration readTimeout,
    http.Client? client,
  }) async {
    // `client` is the native `http.Client` injection seam; web has no such seam
    // (the request goes through the browser's `fetch`), so it is ignored here.
    //
    // `AbortController` is the web cancellation primitive (Gap G-1): its
    // `.abort()` tears the in-flight `fetch` + stream read down at the browser
    // level — the web analogue of native's socket destroy — and is what
    // `abortOnCancel` (Story 4.3) drives to hold the <50ms budget on web.
    final controller = web.AbortController();
    final init = web.RequestInit(
      method: 'POST',
      headers: _headersOf(headers),
      // Avoid a redundant copy when the caller already handed us a `Uint8List`
      // (the common case — `_TransportTerminal` builds the body bytes).
      body: (body is Uint8List ? body : Uint8List.fromList(body)).toJS,
      signal: controller.signal,
    );

    try {
      final response = await web.window
          .fetch(url.toString().toJS, init)
          .toDart
          .timeout(connectTimeout);

      // `Response.body` is null only for a genuinely body-less response (e.g. a
      // 204, or an empty error body); a `_WebConnection` with a null reader
      // yields an empty byte stream so the terminal still runs its status / EOF
      // path uniformly. `abort()` still tears the fetch down.
      final stream = response.body;
      final connection = _WebConnection(
        stream == null
            ? null
            : stream.getReader() as web.ReadableStreamDefaultReader,
        controller,
        readTimeout,
      );

      return TransportResponse(
        statusCode: response.status,
        body: connection.body,
        abort: connection.abort,
      );
    } on Object {
      // The connection never opened (refused / CORS / TLS / connect-timeout), or
      // building the reader threw after it did: abort the in-flight fetch before
      // the failure escapes to the classifier (mirrors `IoTransport` closing its
      // owned client). No `TransportResponse` is built, so — exactly like
      // native's refused path — neither lifecycle hook fires (Story 4.9).
      controller.abort();
      rethrow;
    }
  }

  /// Builds a JS `Headers` object from [headers] — the `RequestInit.headers`
  /// `fetch` sends, carrying `Authorization` + the AG-UI protocol headers.
  static web.Headers _headersOf(Map<String, String> headers) {
    final result = web.Headers();
    for (final entry in headers.entries) {
      result.append(entry.key, entry.value);
    }
    return result;
  }
}

/// Owns the `ReadableStream` reader + `AbortController` of one [WebTransport]
/// connection.
///
/// Pumps the response's `ReadableStream` into a `Stream<List<int>>` (idle-bounded
/// by `readTimeout`, mirroring native's `Stream.timeout`) and tears the
/// connection down **exactly once** — on normal completion, error, consumer
/// cancel, or an explicit [abort] — via `AbortController.abort()`, the browser's
/// fetch-cancel primitive (Gap G-1). [abort] is idempotent and safe to call
/// after the stream is already done, the same contract native's abort honors.
final class _WebConnection {
  _WebConnection(this._reader, this._abortController, this._readTimeout);

  final web.ReadableStreamDefaultReader? _reader;
  final web.AbortController _abortController;
  final Duration _readTimeout;

  var _torn = false;

  /// The consumer-facing byte stream — fed straight into `SseParser`. The
  /// `async*` generator gives backpressure and pause/resume for free, and its
  /// `finally` tears the connection down when the subscription is cancelled.
  late final Stream<List<int>> body = _read().timeout(_readTimeout);

  Stream<List<int>> _read() async* {
    final reader = _reader;
    if (reader == null) return; // body-less response (e.g. 204)
    try {
      while (!_torn) {
        final web.ReadableStreamReadResult result;
        try {
          result = await reader.read().toDart;
        } on Object {
          // `read()` rejects when we abort the controller (consumer cancel) —
          // that is teardown, not a failure to surface. A genuine mid-stream
          // network drop also rejects here; if we did not abort, it is a real
          // transport error and must propagate to the classifier.
          if (_torn) break;
          rethrow;
        }
        if (result.done) break;
        final value = result.value;
        if (value != null) yield (value as JSUint8Array).toDart;
      }
    } finally {
      await abort();
    }
  }

  /// Prompt, idempotent teardown for sub-50ms cancellation (Story 4.3, NFR-8):
  /// `AbortController.abort()` synchronously cancels the in-flight `fetch` and
  /// errors the `ReadableStream` at the browser level. The returned future is an
  /// `async` future (it settles on the next microtask, not synchronously), but
  /// `abortOnCancel` drives `abort` fire-and-forget without awaiting it — so the
  /// <50ms budget rides on the synchronous JS `abort()`, not on this future.
  Future<void> abort() async {
    if (_torn) return;
    _torn = true;
    _abortController.abort();
  }
}

/// The web transport factory selected by `dart.library.js_interop` (see
/// [Transport]'s conditional import).
Transport createTransport() => const WebTransport();
