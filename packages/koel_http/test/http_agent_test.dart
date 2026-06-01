import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:koel_test/koel_test.dart';
import 'package:test/test.dart';

/// A minimal run payload for tests that do not assert on the body.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

/// Reads the raw wire `payload` of each event line in a synthesized fixture
/// (skipping the `_session` header) — the bytes a real SSE endpoint would emit.
/// Resolved through the `package:` asset URI so it reads from `koel_http`'s own
/// test CWD (the same mechanism `FixtureLoader` uses).
Future<List<Map<String, dynamic>>> _fixturePayloads(String name) async {
  final uri = Uri.parse(
    'package:koel_test/src/fixtures/synthesized/$name.jsonl',
  );
  final resolved = await Isolate.resolvePackageUri(uri);
  final lines = (await File.fromUri(
    resolved!,
  ).readAsLines()).where((line) => line.trim().isNotEmpty).toList();
  return [
    for (final line in lines.skip(1))
      (jsonDecode(line) as Map<String, dynamic>)['payload']
          as Map<String, dynamic>,
  ];
}

/// Frames wire payloads as a `text/event-stream` body (`data: <json>\n\n`).
String _sseBody(List<Map<String, dynamic>> payloads) =>
    payloads.map((p) => 'data: ${jsonEncode(p)}\n\n').join();

/// Binds an ephemeral loopback `HttpServer` that replays [body] as an SSE
/// response, draining each request first. Registers its own teardown.
Future<HttpServer> _sseServer(String body) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  addTearDown(() => server.close(force: true));
  server.listen((request) async {
    await request.drain<void>();
    request.response.headers.contentType = ContentType('text', 'event-stream');
    request.response.write(body);
    await request.response.close();
  });
  return server;
}

Uri _serverUri(HttpServer server) =>
    Uri.parse('http://${server.address.host}:${server.port}');

/// A pass-through interceptor that records that it ran, then delegates.
class _RecordingInterceptor implements Interceptor {
  _RecordingInterceptor(this._onIntercept);

  final void Function() _onIntercept;

  @override
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input) {
    _onIntercept();
    return chain.proceed(input);
  }
}

void main() {
  group('HttpAgent', () {
    group('streams typed events from an SSE endpoint (AC3)', () {
      for (final name in const [
        'text_only_run',
        'tool_call_basic',
        'all_event_types',
      ]) {
        test(
          'replays the "$name" fixture as the expected typed events',
          () async {
            final payloads = await _fixturePayloads(name);
            final server = await _sseServer(_sseBody(payloads));
            // This asserts the parser + transport faithfully reproduce the
            // stored fixture event-for-event — a concern orthogonal to chunk
            // synthesis. Story 4.8 made the default `synthesizeChunks: true`
            // real, which would drop the fixture's (all-null, un-addressable)
            // chunk lines and shift the list; pin synthesis off so the
            // round-trip stays exact. Synthesis itself is covered in
            // chunk_synthesis_test.dart.
            final agent = HttpAgent(
              url: _serverUri(server),
              synthesizeChunks: false,
            );

            final events = await agent.run(_input()).toList();

            expect(events, await FixtureLoader.loadSynthesized(name));
          },
        );
      }
    });

    test('POSTs the input as JSON with the AG-UI headers (AC1)', () async {
      String? method;
      String? contentType;
      String? accept;
      late String rawBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        method = request.method;
        contentType = request.headers.contentType?.mimeType;
        accept = request.headers.value(HttpHeaders.acceptHeader);
        rawBody = await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        await request.response.close();
      });

      final agent = HttpAgent(url: _serverUri(server));
      await agent
          .run(
            RunAgentInput(
              threadId: 'thread-1',
              runId: 'run-1',
              messages: [
                Message(
                  id: 'm-1',
                  role: MessageRole.user,
                  content: 'hi',
                  timestamp: DateTime.utc(2026),
                ),
              ],
              tools: const [
                ToolDefinition(name: 'search', description: 'find things'),
              ],
              reasoningEcho: {
                'r-1': Uint8List.fromList(const [1, 2, 3]),
              },
            ),
          )
          .toList();

      expect(method, 'POST');
      expect(contentType, 'application/json');
      expect(accept, 'text/event-stream');

      final body = jsonDecode(rawBody) as Map<String, dynamic>;
      expect(body['threadId'], 'thread-1');
      expect(body['runId'], 'run-1');
      expect(body['messages'], hasLength(1));
      expect((body['messages'] as List).single, containsPair('id', 'm-1'));
      expect(body['tools'], hasLength(1));
      // koel-extension blobs are base64-encoded under their reasoning id.
      expect(body['reasoningEcho'], {
        'r-1': base64Encode(const [1, 2, 3]),
      });
    });

    test('omits reasoningEcho from the body when null (AC1)', () async {
      late String rawBody;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        rawBody = await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        await request.response.close();
      });

      await HttpAgent(url: _serverUri(server)).run(_input()).toList();

      expect(
        jsonDecode(rawBody) as Map<String, dynamic>,
        isNot(contains('reasoningEcho')),
      );
    });

    group('surfaces failures as a terminal RunErrorEvent (AC4)', () {
      final endpoint = Uri.parse('http://agui.test/');

      test('connection refused (real IOClient socket) → '
          'TransportError(transportRefused)', () async {
        // Bind then immediately release a loopback port so connecting to it is
        // a real, deterministic ECONNREFUSED — and use the DEFAULT client so
        // the request goes through `package:http`'s `IOClient`, which catches
        // the `dart:io SocketException` and rethrows it WRAPPED. This is the
        // path a raw-exception `MockClient` cannot exercise: it proves
        // `TransportErrorClassifier` sees through the wrapper. (A `MockClient`
        // throwing a raw `SocketException` would classify via the base and
        // give false confidence — the exact gap this story's review caught.)
        final probe = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final port = probe.port;
        await probe.close();
        final agent = HttpAgent(url: Uri.parse('http://127.0.0.1:$port'));

        // .toList() completing (not throwing) proves nothing escapes uncaught.
        final events = await agent.run(_input()).toList();

        final error = (events.single as RunErrorEvent).error;
        expect(error, isA<TransportError>());
        expect(error.code, KoelErrorCode.transportRefused);
      });

      test(
        'TLS handshake failure → TransportError(transportTlsFail)',
        () async {
          final client = MockClient(
            (_) async => throw const HandshakeException('bad cert'),
          );
          final agent = HttpAgent(url: endpoint, client: client);

          final events = await agent.run(_input()).toList();

          expect(
            (events.single as RunErrorEvent).error.code,
            KoelErrorCode.transportTlsFail,
          );
        },
      );

      test(
        'non-2xx status → TransportError(transportClosed, statusCode)',
        () async {
          final client = MockClient(
            (_) async => Response('upstream boom', 500),
          );
          final agent = HttpAgent(url: endpoint, client: client);

          final events = await agent.run(_input()).toList();

          final error =
              (events.single as RunErrorEvent).error as TransportError;
          expect(error.code, KoelErrorCode.transportClosed);
          expect(error.statusCode, 500);
        },
      );

      test('connect timeout → TransportError(transportTimeout)', () async {
        // Stall past connectTimeout; release in teardown so no timer lingers.
        final gate = Completer<void>();
        addTearDown(() {
          if (!gate.isCompleted) gate.complete();
        });
        final client = MockClient((_) async {
          await gate.future;
          return Response('', 200);
        });
        final agent = HttpAgent(
          url: endpoint,
          client: client,
          connectTimeout: const Duration(milliseconds: 20),
        );

        final events = await agent.run(_input()).toList();

        expect(
          (events.single as RunErrorEvent).error.code,
          KoelErrorCode.transportTimeout,
        );
      });

      test(
        'idle gap beyond readTimeout → TransportError(transportTimeout)',
        () async {
          // Server flushes headers + an SSE keepalive comment (so `send()`
          // completes and the byte stream is subscribed), then stalls — never
          // another byte, never `close()`. The inter-byte gap must trip
          // `response.stream.timeout(readTimeout)`. The comment is ignored by
          // `SseParser`, so the terminal error is the only event. This exercises
          // the real `readTimeout` enforcement (the connect-timeout test above
          // only covers `connectTimeout`).
          final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
          addTearDown(() => server.close(force: true));
          server.listen((request) async {
            await request.drain<void>();
            request.response.headers.contentType = ContentType(
              'text',
              'event-stream',
            );
            request.response.write(': keep-alive\n\n');
            await request.response.flush();
            // Deliberately never close: hold the connection idle past readTimeout.
          });
          final agent = HttpAgent(
            url: _serverUri(server),
            readTimeout: const Duration(milliseconds: 100),
          );

          final events = await agent.run(_input()).toList();

          expect(
            (events.last as RunErrorEvent).error.code,
            KoelErrorCode.transportTimeout,
          );
        },
      );
    });

    test('invokes registered interceptors during a run', () async {
      var intercepted = false;
      final payloads = await _fixturePayloads('text_only_run');
      final server = await _sseServer(_sseBody(payloads));
      final agent = HttpAgent(
        url: _serverUri(server),
        interceptors: [_RecordingInterceptor(() => intercepted = true)],
      );

      final events = await agent.run(_input()).toList();

      expect(intercepted, isTrue);
      expect(events, isNotEmpty);
    });
  });
}
