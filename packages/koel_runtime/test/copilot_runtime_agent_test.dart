@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_runtime/koel_runtime.dart';
import 'package:koel_runtime/src/conversion/graphql_event_conversion.dart';
import 'package:test/test.dart';

import '_support.dart';

/// The full GraphQL endpoint a configured agent POSTs to (used verbatim).
final _endpoint = Uri.parse('http://localhost:8004/api/copilotkit');

/// The registered runtime agent the tests drive (the glue's scripted agent).
const _agentName = 'koel_scripted';

RunAgentInput _input({List<Message> messages = const []}) =>
    RunAgentInput(threadId: 't1', runId: 'r1', messages: messages);

/// A `MockClient` that replays [events] as the multipart response a successful
/// run would receive — authored via the 5.7 reverse path so the wire is an
/// independent oracle, not the agent's own output.
http.Client _replay(List<AgUiEvent> events) => MockClient(
  (request) async => http.Response.bytes(
    multipartBytes(eventsToGraphQLParts(events)),
    200,
    headers: {'content-type': 'multipart/mixed; boundary="-"'},
  ),
);

/// Runs a configured agent over [client] and collects its full event stream.
Future<List<AgUiEvent>> _run(
  http.Client client, {
  List<Message> messages = const [],
}) => CopilotRuntimeAgent(
  graphqlEndpoint: _endpoint,
  agentName: _agentName,
  client: client,
).run(_input(messages: messages)).toList();

void main() {
  group('CopilotRuntimeAgent', () {
    group('run-lifecycle envelope (AC3)', () {
      test('a text run is bracketed by RUN_STARTED/RUN_FINISHED', () async {
        const text = <AgUiEvent>[
          TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
          TextMessageContentEvent(messageId: 'm1', delta: 'Hello'),
          TextMessageContentEvent(messageId: 'm1', delta: ', '),
          TextMessageContentEvent(messageId: 'm1', delta: 'world'),
          TextMessageContentEvent(messageId: 'm1', delta: '.'),
          TextMessageEndEvent(messageId: 'm1'),
        ];
        expect(await _run(_replay(text)), const [
          RunStartedEvent(threadId: 't1', runId: 'r1'),
          ...text,
          RunFinishedEvent(threadId: 't1', runId: 'r1'),
        ]);
      });

      test('a tool run preserves the parser events in wire order', () async {
        const tool = <AgUiEvent>[
          ToolCallStartEvent(
            toolCallId: 'tc1',
            toolCallName: 'get_weather',
            parentMessageId: 'm1',
          ),
          ToolCallArgsEvent(toolCallId: 'tc1', delta: '{"city":'),
          ToolCallArgsEvent(toolCallId: 'tc1', delta: '"Hanoi"}'),
          ToolCallEndEvent(toolCallId: 'tc1'),
        ];
        expect(await _run(_replay(tool)), const [
          RunStartedEvent(threadId: 't1', runId: 'r1'),
          ...tool,
          RunFinishedEvent(threadId: 't1', runId: 'r1'),
        ]);
      });

      test('a state run is bracketed too', () async {
        const state = <AgUiEvent>[
          StateSnapshotEvent(state: {'count': 2}),
        ];
        expect(await _run(_replay(state)), const [
          RunStartedEvent(threadId: 't1', runId: 'r1'),
          ...state,
          RunFinishedEvent(threadId: 't1', runId: 'r1'),
        ]);
      });

      test('the lifecycle events carry the input thread/run, not the wire '
          'envelope (which has runId:null)', () async {
        final events = await CopilotRuntimeAgent(
          graphqlEndpoint: _endpoint,
          agentName: _agentName,
          client: _replay(const []),
        ).run(RunAgentInput(threadId: 'thread-x', runId: 'run-y')).toList();
        expect(events, const [
          RunStartedEvent(threadId: 'thread-x', runId: 'run-y'),
          RunFinishedEvent(threadId: 'thread-x', runId: 'run-y'),
        ]);
      });
    });

    group('GraphQL request shape (AC2)', () {
      late http.Request captured;

      Future<void> runCapturing({
        String? authToken,
        List<Message> messages = const [],
      }) async {
        final client = MockClient((request) async {
          captured = request;
          return http.Response.bytes(
            multipartBytes(eventsToGraphQLParts(const [])),
            200,
            headers: {'content-type': 'multipart/mixed; boundary="-"'},
          );
        });
        await CopilotRuntimeAgent(
          graphqlEndpoint: _endpoint,
          agentName: _agentName,
          authToken: authToken,
          client: client,
        ).run(_input(messages: messages)).toList();
      }

      test('POSTs the generateCopilotResponse mutation with the bake-in '
          'invariants', () async {
        await runCapturing(
          messages: [
            Message(
              id: 'u1',
              role: MessageRole.user,
              content: 'hi',
              timestamp: DateTime.utc(2026, 6, 2),
            ),
            Message(
              id: 'res1',
              role: MessageRole.tool,
              content: '42',
              timestamp: DateTime.utc(2026, 6, 2),
              toolCallId: 'call-1',
              name: 'get_weather',
            ),
          ],
        );

        final body = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(body['operationName'], 'generateCopilotResponse');
        expect(body['query'], allOf(contains('@defer'), contains('@stream')));

        final variables = body['variables'] as Map<String, dynamic>;
        expect(variables['properties'], <String, dynamic>{});

        final data = variables['data'] as Map<String, dynamic>;
        expect((data['metadata'] as Map)['requestType'], 'Chat');
        expect(data['metaEvents'], isEmpty);
        expect((data['frontend'] as Map)['actions'], isEmpty);
        expect((data['agentSession'] as Map)['agentName'], _agentName);
        expect(data['threadId'], 't1');
        expect(data['runId'], 'r1');

        final messages = data['messages'] as List;
        expect(messages, hasLength(2));
        final user = messages[0] as Map<String, dynamic>;
        expect(user['id'], 'u1');
        expect(user['createdAt'], '2026-06-02T00:00:00.000Z');
        expect(user['textMessage'], {'content': 'hi', 'role': 'user'});
        expect(user.containsKey('resultMessage'), isFalse);

        final tool = messages[1] as Map<String, dynamic>;
        expect(tool['resultMessage'], {
          'actionExecutionId': 'call-1',
          'actionName': 'get_weather',
          'result': '42',
        });
        expect(tool.containsKey('textMessage'), isFalse);
      });

      test('sends the GraphQL headers', () async {
        await runCapturing();
        expect(captured.headers['content-type'], 'application/json');
        expect(captured.headers['accept'], 'multipart/mixed');
      });

      test('sends Authorization only when authToken is set', () async {
        await runCapturing(authToken: 't0k3n');
        expect(captured.headers['authorization'], 'Bearer t0k3n');

        await runCapturing();
        expect(captured.headers.containsKey('authorization'), isFalse);
      });
    });

    group('adapter-never-throw: terminal RunErrorEvent (AC4)', () {
      test(
        'a non-2xx 500 yields RUN_STARTED → RUN_ERROR, classified to '
        'agentInternal by the wired CopilotRuntimeErrorClassifier (5.9 AC5)',
        () async {
          final client = MockClient(
            (request) async => http.Response.bytes(
              utf8.encode('boom'),
              500,
              headers: {'content-type': 'application/json'},
            ),
          );
          final events = await _run(client);
          expect(
            events.first,
            const RunStartedEvent(threadId: 't1', runId: 'r1'),
          );
          expect(events, hasLength(2));
          // The agent's terminal throws TransportError(statusCode:500); the
          // errorClassifier() seam (now CopilotRuntimeErrorClassifier, not the
          // 5.8 DefaultErrorClassifier placeholder) refines it to agentInternal,
          // preserving the transport failure as the cause. This pins the seam.
          final error = (events.last as RunErrorEvent).error;
          expect(error, isA<AgentError>());
          expect(error.code, KoelErrorCode.agentInternal);
          final cause = (error as AgentError).cause;
          expect(cause, isA<TransportError>());
          expect((cause! as TransportError).statusCode, 500);
        },
      );

      test(
        'a pre-headers transport throw still yields RUN_STARTED → RUN_ERROR',
        () async {
          final client = MockClient(
            (request) async => throw http.ClientException('connection refused'),
          );
          final events = await _run(client);
          expect(
            events.first,
            const RunStartedEvent(threadId: 't1', runId: 'r1'),
          );
          expect(events.last, isA<RunErrorEvent>());
        },
      );

      test(
        'a malformed multipart body yields RUN_ERROR(ProtocolError)',
        () async {
          final client = MockClient(
            (request) async => http.Response.bytes(
              utf8.encode(rawMultipart(['{not json'])),
              200,
              headers: {'content-type': 'multipart/mixed; boundary="-"'},
            ),
          );
          final events = await _run(client);
          expect(
            events.first,
            const RunStartedEvent(threadId: 't1', runId: 'r1'),
          );
          final error = (events.last as RunErrorEvent).error;
          expect(error, isA<ProtocolError>());
          expect(error.code, KoelErrorCode.protocolMalformed);
        },
      );
    });

    group('construction validation (AC1)', () {
      test('rejects a non-http(s) endpoint', () {
        expect(
          () => CopilotRuntimeAgent(
            graphqlEndpoint: Uri.parse('ftp://host/api'),
            agentName: _agentName,
          ),
          throwsArgumentError,
        );
      });

      test('rejects an endpoint without an authority', () {
        expect(
          () => CopilotRuntimeAgent(
            graphqlEndpoint: Uri.parse('http:no-authority'),
            agentName: _agentName,
          ),
          throwsArgumentError,
        );
      });

      test('rejects a blank agentName', () {
        expect(
          () =>
              CopilotRuntimeAgent(graphqlEndpoint: _endpoint, agentName: '   '),
          throwsArgumentError,
        );
      });
    });

    group('client ownership', () {
      test('an injected client is NOT closed by the agent', () async {
        final tracker = _CloseTrackingClient(_replay(const []));
        await CopilotRuntimeAgent(
          graphqlEndpoint: _endpoint,
          agentName: _agentName,
          client: tracker,
        ).run(_input()).toList();
        expect(tracker.closed, isFalse);
      });

      test('a default (owned) client run terminates cleanly, no hang', () async {
        // No injected client → the agent creates and owns one, POSTs to a
        // refused port, and closes it in the `finally`. The run terminates with
        // RUN_STARTED → RUN_ERROR rather than hanging or throwing.
        final events = await CopilotRuntimeAgent(
          graphqlEndpoint: Uri.parse('http://localhost:1/api/copilotkit'),
          agentName: _agentName,
        ).run(_input()).toList();
        expect(
          events.first,
          const RunStartedEvent(threadId: 't1', runId: 'r1'),
        );
        expect(events.last, isA<RunErrorEvent>());
      });
    });

    group('D5 — independent of koel_http + zero GraphQL client (AC5)', () {
      test('pubspec declares no koel_http or graphql/gql dependency', () {
        final lines = File('pubspec.yaml').readAsLinesSync();
        final forbidden = RegExp(r'^\s+(koel_http|graphql|gql)\w*\s*:');
        expect(lines.where(forbidden.hasMatch), isEmpty);
      });

      test('no koel_http or GraphQL package is imported anywhere in lib/', () {
        final offenders = Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) {
              final src = f.readAsStringSync();
              return src.contains('package:koel_http') ||
                  src.contains('package:graphql') ||
                  src.contains('package:gql');
            })
            .map((f) => f.path)
            .toList();
        expect(offenders, isEmpty);
      });
    });
  });
}

/// An `http.Client` decorator that records whether [close] was called, delegating
/// every request to [_inner]. Proves the agent does not close a client it does
/// not own.
class _CloseTrackingClient extends http.BaseClient {
  _CloseTrackingClient(this._inner);

  final http.Client _inner;
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request);

  @override
  void close() {
    closed = true;
    _inner.close();
  }
}
