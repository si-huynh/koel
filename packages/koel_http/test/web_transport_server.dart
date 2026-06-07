import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:stream_channel/stream_channel.dart';

/// Hybrid-isolate mock SSE server for `web_transport_test.dart`.
///
/// A `@TestOn('browser')` suite cannot use `dart:io`, so its server runs on the
/// VM side via `spawnHybridUri` and talks to the browser test over [channel].
/// [message] selects the behavior:
///
/// - `echo` — answers the CORS preflight, then replays a small, complete run
///   (`RUN_STARTED` → … → `RUN_FINISHED`) and closes.
/// - `long` — replays the opening frames, then emits one `TEXT_MESSAGE_CONTENT`
///   every 100 ms and **never** finishes, until the client aborts.
/// - `error` — answers preflight, then returns HTTP 500 with no body.
///
/// Channel protocol (server → test, JSON-encodable maps):
/// - `{'type': 'ready', 'port': <int>}` once bound;
/// - `{'type': 'request', 'authorization': <String?>}` on the real (non-OPTIONS)
///   request, carrying the inbound `Authorization` header verbatim;
/// - `{'type': 'aborted'}` (long mode) when a flush fails — i.e. the browser's
///   `AbortController.abort()` tore the fetch's TCP connection down.
Future<void> hybridMain(StreamChannel<Object?> channel, Object message) async {
  final mode = message as String;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);

  server.listen((request) async {
    final response = request.response;
    // The test page and this loopback server are different origins (different
    // ports), and the custom `Authorization` header + JSON content-type make the
    // POST a non-simple request — so the browser sends an OPTIONS preflight
    // first. Answer it and allow the real request (and its `Authorization`)
    // through, or the `fetch` never reaches us.
    response.headers
      ..set('Access-Control-Allow-Origin', '*')
      ..set('Access-Control-Allow-Methods', 'POST, OPTIONS')
      ..set('Access-Control-Allow-Headers', 'authorization, content-type');

    if (request.method == 'OPTIONS') {
      response.statusCode = HttpStatus.noContent;
      await response.close();
      return;
    }

    await request.drain<void>();
    channel.sink.add({
      'type': 'request',
      'authorization': request.headers.value('authorization'),
    });

    if (mode == 'error') {
      response.statusCode = HttpStatus.internalServerError;
      await response.close();
      return;
    }

    response
      ..bufferOutput = false
      ..headers.contentType = ContentType('text', 'event-stream');

    if (mode == 'long') {
      // Detach the socket so the fetch teardown is observed via the socket's
      // read side closing (the browser's `AbortController.abort()` sends a FIN) —
      // reliable cross-platform. Waiting for a periodic write to *throw* after
      // the abort held on macOS but not on Linux/CI, where a FIN half-closes the
      // connection and the server's writes keep succeeding (Story 9.4).
      // Connection-close framing (NOT chunked) lets us write raw SSE bytes.
      response
        ..headers.chunkedTransferEncoding = false
        ..persistentConnection = false;
      final socket = await response.detachSocket();
      var aborted = false;
      void markAborted() {
        if (aborted) return;
        aborted = true;
        channel.sink.add({'type': 'aborted'});
      }

      socket.listen((_) {}, onDone: markAborted, onError: (_) => markAborted());

      socket.add(
        utf8.encode(
          'data: {"type":"RUN_STARTED","threadId":"t","runId":"r"}\n\n'
          'data: {"type":"TEXT_MESSAGE_START","messageId":"m",'
          '"role":"assistant"}\n\n',
        ),
      );
      await socket.flush();
      Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        if (aborted) {
          timer.cancel();
          socket.destroy();
          return;
        }
        try {
          socket.add(
            utf8.encode(
              'data: {"type":"TEXT_MESSAGE_CONTENT","messageId":"m",'
              '"delta":"tick"}\n\n',
            ),
          );
          await socket.flush();
        } on Object {
          // Backstop: the write into the torn-down socket threw first.
          timer.cancel();
          markAborted();
          socket.destroy();
        }
      });
      return;
    }

    // mode == 'echo': a small, complete run.
    response
      ..write('data: {"type":"RUN_STARTED","threadId":"t","runId":"r"}\n\n')
      ..write(
        'data: {"type":"TEXT_MESSAGE_START","messageId":"m",'
        '"role":"assistant"}\n\n',
      )
      ..write(
        'data: {"type":"TEXT_MESSAGE_CONTENT","messageId":"m",'
        '"delta":"hello"}\n\n',
      )
      ..write('data: {"type":"TEXT_MESSAGE_END","messageId":"m"}\n\n')
      ..write('data: {"type":"RUN_FINISHED","threadId":"t","runId":"r"}\n\n');
    await response.close();
  });

  channel.sink.add({'type': 'ready', 'port': server.port});

  // Stay bound until the test closes the channel (test teardown), then release
  // the socket.
  await channel.stream.drain<void>();
  await server.close(force: true);
}
