@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:koel_agno/koel_agno.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:koel_test/koel_test.dart';
import 'package:test/test.dart';

/// A minimal run payload for tests that do not assert on the body.
RunAgentInput _input() => const RunAgentInput(threadId: 't', runId: 'r');

/// A request-capturing [MockClient]: records every [Request] the run issues and
/// replays [body] as a `text/event-stream` response (empty by default, so the
/// run completes with no events when only the request is under test).
({MockClient client, List<Request> captured}) _capturingClient([
  String body = '',
]) {
  final captured = <Request>[];
  final client = MockClient((request) async {
    captured.add(request);
    return Response(
      body,
      200,
      headers: const {'content-type': 'text/event-stream'},
    );
  });
  return (client: client, captured: captured);
}

/// Reads the raw wire `payload` of each event line in a synthesized fixture
/// (skipping the `_session` header) — the bytes a real agno endpoint emits.
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

/// Adversarial proof (Epic-4 retro A7) that the `@protected encodeBody` seam is
/// reachable and honored from a *different package* — the consumer it was built
/// for. Adds a marker key over `super.encodeBody`; if the seam were unreachable
/// or `_TransportTerminal` ignored it, the marker would never hit the wire.
class _ProbeAgent extends HttpAgent {
  _ProbeAgent(Uri url, {required Client client})
    : super(url: url, client: client);

  @override
  Map<String, dynamic> encodeBody(RunAgentInput input) => <String, dynamic>{
    ...super.encodeBody(input),
    'probe': true,
  };
}

void main() {
  group('AgnoAgent', () {
    group('POSTs to baseURL/agno-chat, trailing-slash-safe (AC1)', () {
      for (final base in const ['http://host:8002', 'http://host:8002/']) {
        test('base "$base" resolves to .../agno-chat', () async {
          final h = _capturingClient();

          await AgnoAgent(
            baseURL: Uri.parse(base),
            client: h.client,
          ).run(_input()).toList();

          expect(
            h.captured.single.url,
            Uri.parse('http://host:8002/agno-chat'),
          );
          expect(h.captured.single.method, 'POST');
        });
      }

      test('a base with an existing path segment appends agno-chat', () async {
        final h = _capturingClient();

        await AgnoAgent(
          baseURL: Uri.parse('http://host:8002/api/'),
          client: h.client,
        ).run(_input()).toList();

        expect(
          h.captured.single.url,
          Uri.parse('http://host:8002/api/agno-chat'),
        );
      });
    });

    group('rejects a baseURL that cannot name an HTTP POST target (AC1 '
        'fail-fast guard)', () {
      for (final bad in const [
        'agno-chat', // relative — no scheme, no authority
        'file:///srv/agno', // wrong scheme
        'ftp://host:8002', // wrong scheme
        'http:agno-chat', // http but no authority (host)
      ]) {
        test('"$bad" throws ArgumentError at construction', () {
          expect(() => AgnoAgent(baseURL: Uri.parse(bad)), throwsArgumentError);
        });
      }
    });

    test('messages are canonical AG-UI — no timestamp, no null keys; the other '
        'body fields delegate to super (AC3)', () async {
      final h = _capturingClient();

      await AgnoAgent(baseURL: Uri.parse('http://host:8002'), client: h.client)
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
                Message(
                  id: 'm-2',
                  role: MessageRole.tool,
                  content: 'result',
                  timestamp: DateTime.utc(2026),
                  toolCallId: 'call-1',
                  name: 'search',
                ),
              ],
            ),
          )
          .toList();

      final body = jsonDecode(h.captured.single.body) as Map<String, dynamic>;
      // The six non-message fields are super.encodeBody's canonical AG-UI output.
      expect(body['threadId'], 'thread-1');
      expect(body['runId'], 'run-1');
      final messages = (body['messages'] as List).cast<Map<String, dynamic>>();
      expect(messages[0], {'id': 'm-1', 'role': 'user', 'content': 'hi'});
      expect(messages[1], {
        'id': 'm-2',
        'role': 'tool',
        'content': 'result',
        'toolCallId': 'call-1',
        'name': 'search',
      });
    });

    group('parses the inherited canonical AG-UI SSE response, no reshaping '
        '(AC3)', () {
      for (final name in const ['text_only_run', 'tool_call_basic']) {
        test('replays "$name" into the stored typed events', () async {
          final h = _capturingClient(_sseBody(await _fixturePayloads(name)));

          final events = await AgnoAgent(
            baseURL: Uri.parse('http://host:8002'),
            client: h.client,
          ).run(_input()).toList();

          expect(events, await FixtureLoader.loadSynthesized(name));
        });
      }
    });

    group('default-ON AgnoAuthInterceptor (AC2)', () {
      test('a non-null token injects Authorization: Bearer <token> without an '
          'explicit interceptor list', () async {
        final h = _capturingClient();

        await AgnoAgent(
          baseURL: Uri.parse('http://host:8002'),
          token: 'secret-xyz',
          client: h.client,
        ).run(_input()).toList();

        final request = h.captured.single;
        expect(request.headers['authorization'], 'Bearer secret-xyz');
        // The token rides the header only — never the wire body.
        expect(request.body, isNot(contains('secret-xyz')));
      });

      test(
        'a null token leaves the chain a no-op (no Authorization header)',
        () async {
          final h = _capturingClient();

          await AgnoAgent(
            baseURL: Uri.parse('http://host:8002'),
            client: h.client,
          ).run(_input()).toList();

          expect(
            h.captured.single.headers.keys.map((k) => k.toLowerCase()),
            isNot(contains('authorization')),
          );
        },
      );

      test(
        'a caller-supplied inner AuthInterceptor overrides the default '
        'token (the default is prepended outermost; inner keys win)',
        () async {
          final h = _capturingClient();

          await AgnoAgent(
            baseURL: Uri.parse('http://host:8002'),
            token: 'default-token',
            client: h.client,
            interceptors: [
              AuthInterceptor(
                headers: () async => {'Authorization': 'Bearer override'},
              ),
            ],
          ).run(_input()).toList();

          // The default AgnoAuthInterceptor runs first; the caller's interceptor
          // runs last and its key wins the merge.
          expect(h.captured.single.headers['authorization'], 'Bearer override');
        },
      );
    });

    test('a 401 response classifies to BusinessError(businessAuth) end-to-end '
        '(AC3 + AC5 default registration of AgnoErrorClassifier)', () async {
      final client = MockClient((_) async => Response('', 401));

      final events = await AgnoAgent(
        baseURL: Uri.parse('http://host:8002'),
        client: client,
      ).run(_input()).toList();

      final error = (events.single as RunErrorEvent).error;
      expect(error, isA<BusinessError>());
      expect(error.code, KoelErrorCode.businessAuth);
    });

    test('HttpAgent.encodeBody is an override seam honored cross-package '
        '(AC4 reachability)', () async {
      final h = _capturingClient();

      await _ProbeAgent(
        Uri.parse('http://host:8002/agno-chat'),
        client: h.client,
      ).run(_input()).toList();

      final body = jsonDecode(h.captured.single.body) as Map<String, dynamic>;
      expect(body['probe'], isTrue);
      // The override composes with super.encodeBody — default fields survive.
      expect(body['threadId'], 't');
    });
  });
}
