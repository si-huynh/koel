@TestOn('vm')
library;

import 'dart:io';

import 'package:koel_core/koel_core.dart';
import 'package:koel_runtime/koel_runtime.dart';
import 'package:koel_runtime/src/conversion/graphql_event_conversion.dart';
import 'package:test/test.dart';

import '../_support.dart';

void main() {
  group('graphql_event_conversion', () {
    group('symmetry (reverse → bytes → parse == identity)', () {
      test('round-trips the CopilotKit-representable event subset', () async {
        const events = <AgUiEvent>[
          TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
          TextMessageContentEvent(messageId: 'm1', delta: 'Hello'),
          TextMessageContentEvent(messageId: 'm1', delta: ', world'),
          TextMessageEndEvent(messageId: 'm1'),
          ToolCallStartEvent(
            toolCallId: 't1',
            toolCallName: 'get_weather',
            parentMessageId: 'm1',
          ),
          ToolCallArgsEvent(toolCallId: 't1', delta: '{"city":'),
          ToolCallArgsEvent(toolCallId: 't1', delta: '"Hanoi"}'),
          ToolCallEndEvent(toolCallId: 't1'),
          StateSnapshotEvent(state: {'count': 2}),
        ];

        final parts = eventsToGraphQLParts(events);
        final roundTripped = await const MultipartGraphQLStreamParser()
            .parse(streamBytes(multipartBytes(parts)))
            .toList();

        expect(roundTripped, events);
      });

      test('reverse rejects an event outside the representable subset', () {
        expect(
          () => eventsToGraphQLParts(const [
            RunStartedEvent(threadId: 't', runId: 'r'),
          ]),
          throwsArgumentError,
        );
      });
    });

    group('forward converter arms', () {
      test(
        'ResultMessageOutput maps to TOOL_CALL_RESULT (typename-faithful)',
        () {
          final events = GraphQLIncrementalConverter().ingest(
            incrementalPart([
              {
                'items': [
                  {
                    '__typename': 'ResultMessageOutput',
                    'id': 'res-1',
                    'actionExecutionId': 'tool-1',
                    'result': '42',
                  },
                ],
                'path': msgPath(0),
              },
            ]),
          );
          expect(events, const [
            ToolCallResultEvent(
              messageId: 'res-1',
              toolCallId: 'tool-1',
              content: '42',
            ),
          ]);
        },
      );

      test('a ResultMessageOutput missing a required field is skipped (not '
          'emitted as a malformed event)', () {
        final events = GraphQLIncrementalConverter().ingest(
          incrementalPart([
            {
              'items': [
                // No `actionExecutionId` — would link to no call.
                {'__typename': 'ResultMessageOutput', 'id': 'res-1'},
              ],
              'path': msgPath(0),
            },
          ]),
        );
        expect(events, isEmpty);
      });

      test(
        'an unmodelled __typename is skipped, and so are its later deltas',
        () {
          final events = GraphQLIncrementalConverter().ingest(
            incrementalPart([
              {
                'items': [
                  {'__typename': 'ImageMessageOutput', 'id': 'img-1'},
                ],
                'path': msgPath(0),
              },
              {
                'items': ['ignored'],
                'path': [...msgPath(0), 'content', 0],
              },
            ]),
          );
          expect(events, isEmpty);
        },
      );

      test('a non-Success message status emits no end event', () {
        final events = GraphQLIncrementalConverter().ingest(
          incrementalPart([
            textStart(0, 'm1'),
            {
              'data': {
                'status': {'code': 'Pending'},
              },
              'path': msgPath(0),
            },
          ]),
        );
        expect(events, const [
          TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
        ]);
      });

      test('a content delta to an unopened message index is skipped', () {
        final events = GraphQLIncrementalConverter().ingest(
          incrementalPart([
            {
              'items': ['orphan'],
              'path': [...msgPath(5), 'content', 0],
            },
          ]),
        );
        expect(events, isEmpty);
      });

      test(
        'malformed AgentStateMessageOutput.state JSON surfaces ProtocolError',
        () {
          expect(
            () => GraphQLIncrementalConverter().ingest(
              incrementalPart([
                {
                  'items': [
                    {
                      '__typename': 'AgentStateMessageOutput',
                      'id': 's',
                      'state': '{not json',
                    },
                  ],
                  'path': msgPath(0),
                },
              ]),
            ),
            throwsA(
              isA<ProtocolError>().having(
                (e) => e.code,
                'code',
                KoelErrorCode.protocolMalformed,
              ),
            ),
          );
        },
      );

      test('a non-object state decodes to an empty state', () {
        final events = GraphQLIncrementalConverter().ingest(
          incrementalPart([
            {
              'items': [
                {
                  '__typename': 'AgentStateMessageOutput',
                  'id': 's',
                  'state': '123',
                },
              ],
              'path': msgPath(0),
            },
          ]),
        );
        expect(events, const [StateSnapshotEvent(state: {})]);
      });

      test('a missing required id on a text output is skipped (no throw)', () {
        final events = GraphQLIncrementalConverter().ingest(
          incrementalPart([
            {
              'items': [
                {'__typename': 'TextMessageOutput', 'role': 'assistant'},
              ],
              'path': msgPath(0),
            },
          ]),
        );
        expect(events, isEmpty);
      });

      test(
        'a missing required id/name on an action output is skipped, and so are '
        'its later argument deltas',
        () {
          final events = GraphQLIncrementalConverter().ingest(
            incrementalPart([
              {
                'items': [
                  // No `name` — an incomplete tool call cannot open.
                  {
                    '__typename': 'ActionExecutionMessageOutput',
                    'id': 'tool-1',
                  },
                ],
                'path': msgPath(0),
              },
              {
                'items': ['{"city":'],
                'path': [...msgPath(0), 'arguments', 0],
              },
            ]),
          );
          expect(events, isEmpty);
        },
      );
    });

    group('D5 — zero GraphQL dependency (AR-10)', () {
      test('pubspec declares no graphql/gql dependency', () {
        final lines = File('pubspec.yaml').readAsLinesSync();
        final dep = RegExp(r'^\s+(graphql|gql)\w*\s*:');
        expect(lines.where(dep.hasMatch), isEmpty);
      });

      test('no GraphQL package is imported anywhere in lib/', () {
        final offenders = Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where((f) => f.path.endsWith('.dart'))
            .where((f) {
              final src = f.readAsStringSync();
              return src.contains('package:graphql') ||
                  src.contains('package:gql');
            })
            .map((f) => f.path)
            .toList();
        expect(offenders, isEmpty);
      });
    });
  });
}
