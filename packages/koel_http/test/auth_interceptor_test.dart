@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:test/test.dart';

/// A minimal run payload for tests that do not assert on the body.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

/// Reads the raw wire payloads of a synthesized fixture (skipping the `_session`
/// header) — the bytes a real SSE endpoint would emit. Mirrors the loader the
/// `HttpAgent` suite uses.
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

Uri _serverUri(HttpServer server) =>
    Uri.parse('http://${server.address.host}:${server.port}');

/// A terminal agent that emits a single pre-built event each run — the AC3
/// fixture that lets the chain run transport-free (resolution fails before the
/// agent is ever reached). Mirrors `retry_interceptor_test.dart`'s `_StubAgent`.
class _StubAgent implements AbstractAgent {
  _StubAgent(this._build);

  final AgUiEvent Function() _build;

  @override
  Stream<AgUiEvent> run(RunAgentInput input) =>
      Stream<AgUiEvent>.value(_build());
}

void main() {
  group('AuthInterceptor', () {
    test('public ctor matches Addendum A.2 surface (AC1)', () {
      expect(
        AuthInterceptor(headers: () async => const {}),
        isA<Interceptor>(),
      );
    });

    test('callback fires once per run with no retry (AC1)', () async {
      final payloads = await _fixturePayloads('text_only_run');
      final server = await _sseServer(_sseBody(payloads));
      var calls = 0;
      final agent = HttpAgent(
        url: _serverUri(server),
        interceptors: [
          AuthInterceptor(
            headers: () async {
              calls++;
              return const {};
            },
          ),
        ],
      );

      await agent.run(_input()).toList();

      expect(calls, 1);
    });

    test('outgoing request carries the header verbatim; token never on the wire '
        '(AC2)', () async {
      final payloads = await _fixturePayloads('text_only_run');
      String? authHeader;
      String? contentType;
      String? accept;
      late Map<String, dynamic> body;
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      server.listen((request) async {
        authHeader = request.headers.value('Authorization');
        contentType = request.headers.contentType?.mimeType;
        accept = request.headers.value('Accept');
        body =
            jsonDecode(await utf8.decodeStream(request))
                as Map<String, dynamic>;
        request.response.headers.contentType = ContentType(
          'text',
          'event-stream',
        );
        request.response.write(_sseBody(payloads));
        await request.response.close();
      });
      final agent = HttpAgent(
        url: _serverUri(server),
        interceptors: [
          AuthInterceptor(
            headers: () async => {'Authorization': 'Bearer abc123'},
          ),
        ],
      );

      await agent.run(_input()).toList();

      // The header rides verbatim; protocol headers are intact and unclobbered.
      expect(authHeader, 'Bearer abc123');
      expect(contentType, 'application/json');
      expect(accept, 'text/event-stream');
      // Security: the reserved transport key never leaks into the wire body.
      final forwardedProps = body['forwardedProps'] as Map<String, dynamic>;
      expect(
        forwardedProps.containsKey(AuthInterceptor.transportHeadersKey),
        isFalse,
      );
    });

    test(
      'a throwing callback surfaces RunErrorEvent(BusinessError(businessAuth)) '
      'with the original cause (AC3)',
      () async {
        final auth = AuthInterceptor(
          headers: () async => throw StateError('no token'),
        );
        final chain = InterceptorChain(
          interceptors: [auth],
          agent: _StubAgent(
            () => const RunFinishedEvent(threadId: 't', runId: 'r'),
          ),
        );

        final events = await chain.proceed(_input()).toList();

        expect(events, hasLength(1));
        final event = events.single;
        expect(event, isA<RunErrorEvent>());
        final error = (event as RunErrorEvent).error;
        expect(error, isA<BusinessError>());
        expect(error.code, KoelErrorCode.businessAuth);
        expect(error.cause, isA<StateError>());
      },
    );

    test(
      'token refresh on retry: the second attempt carries the fresh token and '
      'the run succeeds (AC4)',
      () async {
        final payloads = await _fixturePayloads('text_only_run');
        final authSeen = <String?>[];
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          await request.drain<void>();
          final auth = request.headers.value('Authorization');
          authSeen.add(auth);
          // 401 until the refreshed token arrives, then replay the fixture.
          if (auth != 'Bearer fresh') {
            request.response.statusCode = HttpStatus.unauthorized;
            await request.response.close();
            return;
          }
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(_sseBody(payloads));
          await request.response.close();
        });

        var calls = 0;
        Future<Map<String, String>> refreshing() async {
          calls++;
          return {
            'Authorization': calls == 1 ? 'Bearer stale' : 'Bearer fresh',
          };
        }

        final agent = HttpAgent(
          url: _serverUri(server),
          retry: const RetryPolicy(
            maxAttempts: 2,
            baseDelay: Duration(milliseconds: 2),
          ),
          interceptors: [AuthInterceptor(headers: refreshing)],
        );

        final events = await agent.run(_input()).toList();

        // The run recovers: no terminal error, ends with RUN_FINISHED.
        expect(events.whereType<RunErrorEvent>(), isEmpty);
        expect(events.last, isA<RunFinishedEvent>());
        // Per-attempt re-auth: stale first, fresh on the retry (also covers
        // AC1's per-attempt clause).
        expect(authSeen, ['Bearer stale', 'Bearer fresh']);
        expect(calls, 2);
      },
    );

    test(
      'stacked AuthInterceptors compose; the outer (later) wins on collision',
      () async {
        final payloads = await _fixturePayloads('text_only_run');
        String? authHeader;
        String? inner;
        String? outer;
        late Map<String, dynamic> body;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          authHeader = request.headers.value('Authorization');
          inner = request.headers.value('X-Inner');
          outer = request.headers.value('X-Outer');
          body =
              jsonDecode(await utf8.decodeStream(request))
                  as Map<String, dynamic>;
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(_sseBody(payloads));
          await request.response.close();
        });
        final agent = HttpAgent(
          url: _serverUri(server),
          // The LAST interceptor reaches the transport last, so its reserved-map
          // merge wins on key collision.
          interceptors: [
            AuthInterceptor(
              headers: () async => {
                'Authorization': 'Bearer inner',
                'X-Inner': '1',
              },
            ),
            AuthInterceptor(
              headers: () async => {
                'Authorization': 'Bearer outer',
                'X-Outer': '2',
              },
            ),
          ],
        );

        await agent.run(_input()).toList();

        // Collision resolves to the outer (later) interceptor; both unique
        // headers ride; the merged reserved key still never hits the wire body.
        expect(authHeader, 'Bearer outer');
        expect(inner, '1');
        expect(outer, '2');
        final forwardedProps = body['forwardedProps'] as Map<String, dynamic>;
        expect(
          forwardedProps.containsKey(AuthInterceptor.transportHeadersKey),
          isFalse,
        );
      },
    );

    test('a foreign non-Map value under the reserved key surfaces a typed '
        'AgentError(unknown), not a raw TypeError', () async {
      // No AuthInterceptor: a consumer mis-populates the documented-internal
      // reserved key directly. The transport guard must reject it with a
      // typed, precise failure (the classifier passes a KoelError through) —
      // never a raw `TypeError` bucketed as 'Unclassified failure'.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var hit = false;
      server.listen((_) => hit = true);
      final agent = HttpAgent(url: _serverUri(server));
      final input = RunAgentInput(
        threadId: 't',
        runId: 'r',
        forwardedProps: const {
          AuthInterceptor.transportHeadersKey: 'not-a-map',
        },
      );

      final events = await agent.run(input).toList();

      final error = events.whereType<RunErrorEvent>().single.error;
      expect(error, isA<AgentError>());
      expect(error.code, KoelErrorCode.unknown);
      expect(error.message, contains('non-Map'));
      // The guard fires before `connect`: no request reaches the server.
      expect(hit, isFalse);
    });

    test(
      'a callback header cannot clobber protocol headers, even lowercase',
      () async {
        final payloads = await _fixturePayloads('text_only_run');
        String? accept;
        String? contentType;
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        addTearDown(() => server.close(force: true));
        server.listen((request) async {
          accept = request.headers.value('Accept');
          contentType = request.headers.contentType?.mimeType;
          await request.drain<void>();
          request.response.headers.contentType = ContentType(
            'text',
            'event-stream',
          );
          request.response.write(_sseBody(payloads));
          await request.response.close();
        });
        final agent = HttpAgent(
          url: _serverUri(server),
          interceptors: [
            AuthInterceptor(
              // Lowercase keys — distinct Dart-map entries from the literal
              // protocol headers. They must NOT survive onto the wire (a
              // clobbered `Accept` breaks SSE content negotiation).
              headers: () async => {
                'accept': 'text/plain',
                'content-type': 'text/plain',
              },
            ),
          ],
        );

        await agent.run(_input()).toList();

        expect(accept, 'text/event-stream');
        expect(contentType, 'application/json');
      },
    );
  });
}

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
