@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:koel_runtime/koel_runtime.dart';
import 'package:koel_test/koel_test.dart';
import 'package:test/test.dart';

import '_support.dart';

/// The CopilotKit v2 **base** path a configured agent appends `/agent/<name>/run`
/// to (used as the route root).
final _endpoint = Uri.parse('http://localhost:8005/api/copilotkit');

/// The registered runtime agent the tests drive (the glue's scripted agent).
const _agentName = 'koel_scripted';

RunAgentInput _input({List<Message> messages = const []}) =>
    RunAgentInput(threadId: 't1', runId: 'r1', messages: messages);

/// A request-capturing [MockClient]: records every [http.Request] the run issues
/// and replays [body] as a `text/event-stream` response (empty by default, so the
/// run completes with no events when only the request is under test).
({MockClient client, List<http.Request> captured}) _capturingClient([
  String body = '',
]) {
  final captured = <http.Request>[];
  final client = MockClient((request) async {
    captured.add(request);
    return http.Response(
      body,
      200,
      headers: const {'content-type': 'text/event-stream'},
    );
  });
  return (client: client, captured: captured);
}

/// Runs a configured agent over [client] and collects its full event stream.
Future<List<AgUiEvent>> _run(
  http.Client client, {
  List<Message> messages = const [],
}) => CopilotRuntimeAgent(
  endpoint: _endpoint,
  agentName: _agentName,
  client: client,
).run(_input(messages: messages)).toList();

void main() {
  group('CopilotRuntimeAgent', () {
    group('architecture (AC1) — extends HttpAgent, barrel surface', () {
      test('is an HttpAgent subclass (D5 reversed)', () {
        final agent = CopilotRuntimeAgent(
          endpoint: _endpoint,
          agentName: _agentName,
        );
        expect(agent, isA<HttpAgent>());
      });

      test('the barrel exports the agent, auth interceptor, and classifier', () {
        // Compile-time proof the v2 surface is exported (and the GraphQL parser is
        // no longer): all three names resolve through `package:koel_runtime`.
        expect(CopilotRuntimeAuthInterceptor(token: null), isA<Interceptor>());
        expect(const CopilotRuntimeErrorClassifier(), isA<ErrorClassifier>());
      });
    });

    group('request shape (AC2) — POST {endpoint}/agent/{name}/run', () {
      for (final base in const [
        'http://localhost:8005/api/copilotkit', // no trailing slash
        'http://localhost:8005/api/copilotkit/', // trailing slash
      ]) {
        test('"$base" → .../api/copilotkit/agent/$_agentName/run (join is '
            'trailing-slash-safe)', () async {
          final h = _capturingClient();

          await CopilotRuntimeAgent(
            endpoint: Uri.parse(base),
            agentName: _agentName,
            client: h.client,
          ).run(_input()).toList();

          expect(
            h.captured.single.url,
            Uri.parse(
              'http://localhost:8005/api/copilotkit/agent/$_agentName/run',
            ),
          );
          expect(h.captured.single.method, 'POST');
        });
      }

      test(
        'sends Accept: text/event-stream (inherited HttpAgent terminal)',
        () async {
          final h = _capturingClient();
          await CopilotRuntimeAgent(
            endpoint: _endpoint,
            agentName: _agentName,
            client: h.client,
          ).run(_input()).toList();
          expect(h.captured.single.headers['content-type'], 'application/json');
          expect(h.captured.single.headers['accept'], 'text/event-stream');
        },
      );

      test('POSTs the COMPLETE RunAgentInput — all 7 fields present (the v2 '
          '"free win"; a partial body 500s the runtime)', () async {
        final h = _capturingClient();
        await CopilotRuntimeAgent(
          endpoint: _endpoint,
          agentName: _agentName,
          client: h.client,
        ).run(_input()).toList();

        final body = jsonDecode(h.captured.single.body) as Map<String, dynamic>;
        for (final field in const [
          'threadId',
          'runId',
          'state',
          'messages',
          'tools',
          'context',
          'forwardedProps',
        ]) {
          expect(body.containsKey(field), isTrue, reason: 'missing $field');
        }
        expect(body['threadId'], 't1');
        expect(body['runId'], 'r1');
      });

      test(
        'messages are canonical AG-UI — no timestamp key; a tool message '
        'carries toolCallId/name; other body fields delegate to super',
        () async {
          final h = _capturingClient();
          await CopilotRuntimeAgent(
                endpoint: _endpoint,
                agentName: _agentName,
                client: h.client,
              )
              .run(
                _input(
                  messages: [
                    Message(
                      id: 'u1',
                      role: MessageRole.user,
                      content: 'hi',
                      timestamp: DateTime.utc(2026, 6, 5),
                    ),
                    Message(
                      id: 't-1',
                      role: MessageRole.tool,
                      content: '42',
                      timestamp: DateTime.utc(2026, 6, 5),
                      toolCallId: 'call-1',
                      name: 'get_weather',
                    ),
                  ],
                ),
              )
              .toList();

          final body =
              jsonDecode(h.captured.single.body) as Map<String, dynamic>;
          final messages = (body['messages'] as List)
              .cast<Map<String, dynamic>>();
          // The koel-only timestamp field is dropped — the wire stays canonical.
          expect(messages[0], {'id': 'u1', 'role': 'user', 'content': 'hi'});
          expect(messages[0].containsKey('timestamp'), isFalse);
          expect(messages[1], {
            'id': 't-1',
            'role': 'tool',
            'content': '42',
            'toolCallId': 'call-1',
            'name': 'get_weather',
          });
        },
      );

      test(
        'Authorization: Bearer rides the request only when authToken is set',
        () async {
          final withToken = _capturingClient();
          await CopilotRuntimeAgent(
            endpoint: _endpoint,
            agentName: _agentName,
            authToken: '  t0k3n  ', // padding is trimmed
            client: withToken.client,
          ).run(_input()).toList();
          expect(
            withToken.captured.single.headers['authorization'],
            'Bearer t0k3n',
          );
          // The token rides the header only — never the wire body.
          expect(withToken.captured.single.body, isNot(contains('t0k3n')));

          for (final blank in const [null, '', '   ']) {
            final h = _capturingClient();
            await CopilotRuntimeAgent(
              endpoint: _endpoint,
              agentName: _agentName,
              authToken: blank,
              client: h.client,
            ).run(_input()).toList();
            expect(
              h.captured.single.headers.keys.map((k) => k.toLowerCase()),
              isNot(contains('authorization')),
            );
          }
        },
      );

      test(
        'default-ON CopilotRuntimeAuthInterceptor emits the Bearer header '
        'without an explicit interceptor list (chain auto-prepend, AC4)',
        () async {
          final h = _capturingClient();
          await CopilotRuntimeAgent(
            endpoint: _endpoint,
            agentName: _agentName,
            authToken: 'auto',
            client: h.client,
          ).run(_input()).toList();
          expect(h.captured.single.headers['authorization'], 'Bearer auto');
        },
      );

      test('a caller-supplied inner AuthInterceptor wins (the default is '
          'prepended outermost; inner keys override, AC4)', () async {
        final h = _capturingClient();
        await CopilotRuntimeAgent(
          endpoint: _endpoint,
          agentName: _agentName,
          authToken: 'default',
          client: h.client,
          interceptors: [
            AuthInterceptor(
              headers: () async => {'Authorization': 'Bearer override'},
            ),
          ],
        ).run(_input()).toList();
        expect(h.captured.single.headers['authorization'], 'Bearer override');
      });
    });

    group('response passthrough (AC3) — inherited canonical AG-UI SSE parse', () {
      // The v2 runtime is native AG-UI; the agent overrides only encodeBody/
      // errorClassifier, never the response path. RUN_STARTED/RUN_FINISHED come
      // from the WIRE (not synthesized) and round-trip verbatim.
      for (final name in const ['text_only_run', 'tool_call_basic']) {
        test(
          'replays "$name" into the stored typed events (no reshaping)',
          () async {
            final client = sseClient(
              sseBody(await fixturePayloads('synthesized', name)),
            );

            final events = await _run(client);

            expect(events, await FixtureLoader.loadSynthesized(name));
          },
        );
      }
    });

    group('adapter-never-throw: terminal RunErrorEvent (AC4)', () {
      test(
        'a non-2xx 500 → RUN_ERROR classified to agentInternal by the wired '
        'CopilotRuntimeErrorClassifier, preserving the TransportError cause',
        () async {
          final client = MockClient((_) async => http.Response('boom', 500));
          final events = await _run(client);

          expect(events.last, isA<RunErrorEvent>());
          final error = (events.last as RunErrorEvent).error;
          expect(error, isA<AgentError>());
          expect(error.code, KoelErrorCode.agentInternal);
          final cause = (error as AgentError).cause;
          expect(cause, isA<TransportError>());
          expect((cause! as TransportError).statusCode, 500);
        },
      );

      test(
        'a 401 → businessAuth (the v2 classifier maps it end-to-end)',
        () async {
          final client = MockClient((_) async => http.Response('', 401));
          final events = await _run(client);

          final error = (events.last as RunErrorEvent).error;
          expect(error, isA<BusinessError>());
          expect(error.code, KoelErrorCode.businessAuth);
        },
      );

      test('a pre-headers ClientException → terminal RunErrorEvent', () async {
        final client = MockClient(
          (_) async => throw http.ClientException('connection refused'),
        );
        final events = await _run(client);
        expect(events.last, isA<RunErrorEvent>());
      });

      test(
        'a pre-headers SocketException → transportRefused via the native '
        'refinement (D5 reversed makes transportErrorClassifier reachable)',
        () async {
          final client = MockClient(
            (_) async => throw const SocketException('refused'),
          );
          final events = await _run(client);
          final error = (events.last as RunErrorEvent).error;
          expect(error, isA<TransportError>());
          expect(error.code, KoelErrorCode.transportRefused);
        },
      );
    });

    group('construction validation (AC1)', () {
      test('rejects a non-http(s) endpoint', () {
        expect(
          () => CopilotRuntimeAgent(
            endpoint: Uri.parse('ftp://host/api'),
            agentName: _agentName,
          ),
          throwsArgumentError,
        );
      });

      test('rejects an endpoint without an authority', () {
        expect(
          () => CopilotRuntimeAgent(
            endpoint: Uri.parse('http:no-authority'),
            agentName: _agentName,
          ),
          throwsArgumentError,
        );
      });

      test('rejects a blank/whitespace agentName', () {
        expect(
          () => CopilotRuntimeAgent(endpoint: _endpoint, agentName: '   '),
          throwsArgumentError,
        );
      });
    });
  });
}
