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

      test('holds END until @stream deltas complete — a mid-@stream @defer '
          'status with content after it reconstructs canonical '
          'START→…content…→END (AI-5.1)', () {
        final converter = GraphQLIncrementalConverter();
        // The live wire resolves status:Success after the FIRST content delta,
        // then streams the rest — emitting END at the status would produce
        // START→CONTENT→END→CONTENT…, violating AG-UI order.
        final events = converter.ingest(
          incrementalPart([
            textStart(0, 'm1'),
            contentDelta(0, 0, 'Hello'),
            messageSuccess(0), // mid-stream status — END held, not emitted
            contentDelta(0, 1, ', world'),
            contentDelta(0, 2, '!'),
          ]),
        );
        expect(events, const [
          TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
          TextMessageContentEvent(messageId: 'm1', delta: 'Hello'),
          TextMessageContentEvent(messageId: 'm1', delta: ', world'),
          TextMessageContentEvent(messageId: 'm1', delta: '!'),
        ]);
        // finish() flushes the held END at stream completion, in canonical order.
        expect(converter.finish(), const [
          TextMessageEndEvent(messageId: 'm1'),
        ]);
      });

      test('flushes a held END when the next message opens — per-message '
          'bracketing across two messages whose statuses resolve mid-@stream '
          '(AI-5.1)', () {
        final converter = GraphQLIncrementalConverter();
        final events = converter.ingest(
          incrementalPart([
            textStart(0, 'm1'),
            contentDelta(0, 0, 'A'),
            messageSuccess(0), // held
            contentDelta(0, 1, 'B'), // late content for m1
            textStart(1, 'm2'), // opens m2 → flush m1's END first
            contentDelta(1, 0, 'C'),
            messageSuccess(1), // held
          ]),
        );
        expect(
          [...events, ...converter.finish()],
          const [
            TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
            TextMessageContentEvent(messageId: 'm1', delta: 'A'),
            TextMessageContentEvent(messageId: 'm1', delta: 'B'),
            TextMessageEndEvent(messageId: 'm1'),
            TextMessageStartEvent(messageId: 'm2', role: 'assistant'),
            TextMessageContentEvent(messageId: 'm2', delta: 'C'),
            TextMessageEndEvent(messageId: 'm2'),
          ],
        );
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
