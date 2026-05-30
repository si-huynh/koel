import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/event/event_deserializer.dart';
import 'package:test/test.dart';

void main() {
  group('deserializeAgUiEvent', () {
    test('registry maps exactly the seventeen Story-2.5 + 2.6 wire types', () {
      expect(
        eventTypeRegistry.keys,
        unorderedEquals(<String>{
          'RUN_STARTED',
          'RUN_FINISHED',
          'RUN_ERROR',
          'STEP_STARTED',
          'STEP_FINISHED',
          'TEXT_MESSAGE_START',
          'TEXT_MESSAGE_CONTENT',
          'TEXT_MESSAGE_END',
          'TEXT_MESSAGE_CHUNK',
          'TOOL_CALL_START',
          'TOOL_CALL_ARGS',
          'TOOL_CALL_END',
          'TOOL_CALL_RESULT',
          'TOOL_CALL_CHUNK',
          'STATE_SNAPSHOT',
          'STATE_DELTA',
          'MESSAGES_SNAPSHOT',
        }),
      );
    });

    test('dispatches each wire type to its concrete subtype', () {
      expect(
        deserializeAgUiEvent({
          'type': 'RUN_STARTED',
          'threadId': 't',
          'runId': 'r',
        }),
        isA<RunStartedEvent>(),
      );
      expect(
        deserializeAgUiEvent({
          'type': 'RUN_FINISHED',
          'threadId': 't',
          'runId': 'r',
        }),
        isA<RunFinishedEvent>(),
      );
      expect(
        deserializeAgUiEvent({'type': 'RUN_ERROR', 'message': 'boom'}),
        isA<RunErrorEvent>(),
      );
      expect(
        deserializeAgUiEvent({'type': 'STEP_STARTED', 'stepName': 's'}),
        isA<StepStartedEvent>(),
      );
      expect(
        deserializeAgUiEvent({'type': 'STEP_FINISHED', 'stepName': 's'}),
        isA<StepFinishedEvent>(),
      );
      expect(
        deserializeAgUiEvent({
          'type': 'TEXT_MESSAGE_START',
          'messageId': 'm',
          'role': 'assistant',
        }),
        isA<TextMessageStartEvent>(),
      );
      expect(
        deserializeAgUiEvent({
          'type': 'TEXT_MESSAGE_CONTENT',
          'messageId': 'm',
          'delta': 'd',
        }),
        isA<TextMessageContentEvent>(),
      );
      expect(
        deserializeAgUiEvent({'type': 'TEXT_MESSAGE_END', 'messageId': 'm'}),
        isA<TextMessageEndEvent>(),
      );
      expect(
        deserializeAgUiEvent({'type': 'TEXT_MESSAGE_CHUNK'}),
        isA<TextMessageChunkEvent>(),
      );
      expect(
        deserializeAgUiEvent({
          'type': 'TOOL_CALL_START',
          'toolCallId': 'tc1',
          'toolCallName': 'search',
        }),
        isA<ToolCallStartEvent>(),
      );
      expect(
        deserializeAgUiEvent({
          'type': 'TOOL_CALL_ARGS',
          'toolCallId': 'tc1',
          'delta': '{"q":',
        }),
        isA<ToolCallArgsEvent>(),
      );
      expect(
        deserializeAgUiEvent({'type': 'TOOL_CALL_END', 'toolCallId': 'tc1'}),
        isA<ToolCallEndEvent>(),
      );
      expect(
        deserializeAgUiEvent({
          'type': 'TOOL_CALL_RESULT',
          'messageId': 'm1',
          'toolCallId': 'tc1',
          'content': 'ok',
        }),
        isA<ToolCallResultEvent>(),
      );
      expect(
        deserializeAgUiEvent({'type': 'TOOL_CALL_CHUNK'}),
        isA<ToolCallChunkEvent>(),
      );
      expect(
        deserializeAgUiEvent({
          'type': 'STATE_SNAPSHOT',
          'snapshot': {'count': 1},
        }),
        isA<StateSnapshotEvent>(),
      );
      expect(
        deserializeAgUiEvent({'type': 'STATE_DELTA', 'delta': <dynamic>[]}),
        isA<StateDeltaEvent>(),
      );
      expect(
        deserializeAgUiEvent({
          'type': 'MESSAGES_SNAPSHOT',
          'messages': <dynamic>[],
        }),
        isA<MessagesSnapshotEvent>(),
      );
    });

    test(
      'unknown type string falls back to UnknownAgUiEvent without throwing',
      () {
        final json = {'type': 'SOME_FUTURE_EVENT', 'payload': 42};
        final event = deserializeAgUiEvent(json);
        expect(event, isA<UnknownAgUiEvent>());
        final unknown = event as UnknownAgUiEvent;
        expect(unknown.type, 'SOME_FUTURE_EVENT');
      },
    );

    test('rawJson holds the entire input map verbatim, not stripped of type', () {
      final json = {
        'type': 'SOME_FUTURE_EVENT',
        'payload': {
          'nested': [1, 2, 3],
        },
      };
      final unknown = deserializeAgUiEvent(json) as UnknownAgUiEvent;
      // Deep value-equal to the full input (the `type` key is retained, nothing
      // transformed). Not reference-identical: freezed wraps collection fields
      // in an unmodifiable view, which is the immutability we want.
      expect(unknown.rawJson, equals(json));
      expect(unknown.rawJson['type'], 'SOME_FUTURE_EVENT');
    });

    test('missing type key falls back to empty type, no throw', () {
      final json = {'payload': 'no type here'};
      final unknown = deserializeAgUiEvent(json) as UnknownAgUiEvent;
      expect(unknown.type, '');
      expect(unknown.rawJson, equals(json));
    });

    test('non-String type coerces to empty type, no throw', () {
      final json = {'type': 7, 'payload': 'numeric type'};
      final unknown = deserializeAgUiEvent(json) as UnknownAgUiEvent;
      expect(unknown.type, '');
      expect(unknown.rawJson, equals(json));
    });
  });
}
