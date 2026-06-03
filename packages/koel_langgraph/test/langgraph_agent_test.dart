@TestOn('vm')
library;

import 'dart:convert';

import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';
import 'package:koel_langgraph/koel_langgraph.dart';
import 'package:koel_test/koel_test.dart';
import 'package:test/test.dart';

import '_support.dart';

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

void main() {
  group('LangGraphAgent', () {
    group('POSTs to deploymentUrl verbatim — no suffix appended (AC1)', () {
      for (final url in const [
        'http://host:8003/agent', // the reference-backend route
        'http://host:8003', // a bare authority is used as-is, not /agent-ed
        'http://host:8003/v2/runs/stream', // an arbitrary deployment route
      ]) {
        test('"$url" is posted unchanged', () async {
          final h = _capturingClient();

          await LangGraphAgent(
            deploymentUrl: Uri.parse(url),
            client: h.client,
          ).run(_input()).toList();

          expect(h.captured.single.url, Uri.parse(url));
          expect(h.captured.single.method, 'POST');
        });
      }
    });

    group('rejects a deploymentUrl that cannot name an HTTP POST target (AC1 '
        'fail-fast guard)', () {
      for (final bad in const [
        'agent', // relative — no scheme, no authority
        'file:///srv/lg', // wrong scheme
        'ftp://host:8003', // wrong scheme
        'http:agent', // http but no authority (host)
      ]) {
        test('"$bad" throws ArgumentError at construction', () {
          expect(
            () => LangGraphAgent(deploymentUrl: Uri.parse(bad)),
            throwsArgumentError,
          );
        });
      }
    });

    test('messages are canonical AG-UI — no timestamp, no null keys; the other '
        'body fields delegate to super (AC3)', () async {
      final h = _capturingClient();

      await LangGraphAgent(
            deploymentUrl: Uri.parse('http://host:8003/agent'),
            client: h.client,
          )
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
      // The non-message fields are super.encodeBody's canonical AG-UI output.
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
        '(AC4)', () {
      // LangGraph is native AG-UI (SPIKE-LG-RESUME): LangGraphAgent overrides only
      // encodeBody, never the response path, so the inherited HttpAgent SSE parse
      // round-trips canonical events unreshaped. Replays the Epic-3 synthesized
      // fixtures (real langgraph captures + the formal ConformanceRunner lane land
      // in the Story 5.6 sealer).
      for (final name in const ['text_only_run', 'tool_call_basic']) {
        test('replays "$name" into the stored typed events', () async {
          final h = _capturingClient(
            sseBody(await fixturePayloads('synthesized', name)),
          );

          final events = await LangGraphAgent(
            deploymentUrl: Uri.parse('http://host:8003/agent'),
            client: h.client,
          ).run(_input()).toList();

          expect(events, await FixtureLoader.loadSynthesized(name));
        });
      }
    });

    group('default-ON LangGraphAuthInterceptor (AC2)', () {
      test('a non-null apiKey injects x-api-key: <apiKey> without an explicit '
          'interceptor list', () async {
        final h = _capturingClient();

        await LangGraphAgent(
          deploymentUrl: Uri.parse('http://host:8003/agent'),
          apiKey: 'secret-xyz',
          client: h.client,
        ).run(_input()).toList();

        final request = h.captured.single;
        expect(request.headers['x-api-key'], 'secret-xyz');
        // x-api-key, not Authorization: Bearer.
        expect(
          request.headers.keys.map((k) => k.toLowerCase()),
          isNot(contains('authorization')),
        );
        // The key rides the header only — never the wire body.
        expect(request.body, isNot(contains('secret-xyz')));
      });

      test(
        'a null apiKey leaves the chain a no-op (no x-api-key header)',
        () async {
          final h = _capturingClient();

          await LangGraphAgent(
            deploymentUrl: Uri.parse('http://host:8003/agent'),
            client: h.client,
          ).run(_input()).toList();

          expect(
            h.captured.single.headers.keys.map((k) => k.toLowerCase()),
            isNot(contains('x-api-key')),
          );
        },
      );

      test('a caller-supplied inner AuthInterceptor overrides the default key '
          '(the default is prepended outermost; inner keys win)', () async {
        final h = _capturingClient();

        await LangGraphAgent(
          deploymentUrl: Uri.parse('http://host:8003/agent'),
          apiKey: 'default-key',
          client: h.client,
          interceptors: [
            AuthInterceptor(headers: () async => {'x-api-key': 'override'}),
          ],
        ).run(_input()).toList();

        // The default LangGraphAuthInterceptor runs first; the caller's
        // interceptor runs last and its key wins the merge.
        expect(h.captured.single.headers['x-api-key'], 'override');
      });
    });

    test('inherits HttpAgent DefaultErrorClassifier — a 401 surfaces as a '
        'terminal RunErrorEvent, not a throw (AC1; classifier override is '
        'Story 5.6)', () async {
      final client = MockClient((_) async => Response('', 401));

      final events = await LangGraphAgent(
        deploymentUrl: Uri.parse('http://host:8003/agent'),
        client: client,
      ).run(_input()).toList();

      // Adapters never throw — every failure reaches the consumer as a terminal
      // RunErrorEvent. The langgraph-specific mapping (401 -> businessAuth) is
      // Story 5.6; here the inherited DefaultErrorClassifier produces a typed
      // transport error.
      expect(events.single, isA<RunErrorEvent>());
    });
  });
}
