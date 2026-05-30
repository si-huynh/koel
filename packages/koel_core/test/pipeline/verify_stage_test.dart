import 'dart:convert';
import 'dart:typed_data';

import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/json_patch/json_patch_op.dart';
import 'package:koel_core/src/pipeline/verify_stage.dart';
import 'package:test/test.dart';

Future<List<AgUiEvent>> _verify(List<AgUiEvent> input) =>
    Stream<AgUiEvent>.fromIterable(input).transform(verifyStage).toList();

/// Asserts [event] is a `RunErrorEvent` carrying a `ProtocolError` with
/// `protocolMalformed` and the given wire [eventType].
void _expectMalformed(AgUiEvent event, String eventType) {
  expect(event, isA<RunErrorEvent>());
  final error = (event as RunErrorEvent).error;
  expect(error, isA<ProtocolError>());
  expect(error.code, KoelErrorCode.protocolMalformed);
  expect((error as ProtocolError).eventType, eventType);
}

void main() {
  group('verifyStage — tool-call envelope (F.1)', () {
    test(
      'a matched START/ARGS/END envelope passes through unchanged',
      () async {
        final out = await _verify([
          const ToolCallStartEvent(toolCallId: 'a', toolCallName: 'search'),
          const ToolCallArgsEvent(toolCallId: 'a', delta: '{}'),
          const ToolCallEndEvent(toolCallId: 'a'),
        ]);
        expect(out, [
          const ToolCallStartEvent(toolCallId: 'a', toolCallName: 'search'),
          const ToolCallArgsEvent(toolCallId: 'a', delta: '{}'),
          const ToolCallEndEvent(toolCallId: 'a'),
        ]);
      },
    );

    test(
      'an orphan END is dropped and replaced with a ProtocolError',
      () async {
        final out = await _verify([
          const ToolCallEndEvent(toolCallId: 'ghost'),
        ]);
        expect(out, hasLength(1));
        _expectMalformed(out.single, 'TOOL_CALL_END');
      },
    );

    test(
      'ARGS outside an envelope is dropped and replaced with a ProtocolError',
      () async {
        final out = await _verify([
          const ToolCallArgsEvent(toolCallId: 'x', delta: 'd'),
        ]);
        expect(out, hasLength(1));
        _expectMalformed(out.single, 'TOOL_CALL_ARGS');
      },
    );

    test('an END consumes its START, so a second END is an orphan', () async {
      final out = await _verify([
        const ToolCallStartEvent(toolCallId: 'a', toolCallName: 't'),
        const ToolCallEndEvent(toolCallId: 'a'),
        const ToolCallEndEvent(toolCallId: 'a'),
      ]);
      expect(out[0], isA<ToolCallStartEvent>());
      expect(out[1], isA<ToolCallEndEvent>());
      _expectMalformed(out[2], 'TOOL_CALL_END');
    });
  });

  group('verifyStage — state delta (F.1)', () {
    test(
      'an empty STATE_DELTA is dropped and replaced with a ProtocolError',
      () async {
        final out = await _verify([const StateDeltaEvent(patches: [])]);
        expect(out, hasLength(1));
        _expectMalformed(out.single, 'STATE_DELTA');
      },
    );

    test('a non-empty STATE_DELTA passes through', () async {
      const delta = StateDeltaEvent(patches: [AddOp(path: '/x', value: 1)]);
      expect(await _verify([delta]), [delta]);
    });
  });

  group('verifyStage — text message messageId (F.1)', () {
    test('an empty messageId on START/CONTENT/END is rejected', () async {
      final out = await _verify([
        const TextMessageStartEvent(messageId: '', role: 'assistant'),
        const TextMessageContentEvent(messageId: '', delta: 'd'),
        const TextMessageEndEvent(messageId: ''),
      ]);
      _expectMalformed(out[0], 'TEXT_MESSAGE_START');
      _expectMalformed(out[1], 'TEXT_MESSAGE_CONTENT');
      _expectMalformed(out[2], 'TEXT_MESSAGE_END');
    });

    test('a present messageId passes through', () async {
      const start = TextMessageStartEvent(messageId: 'm', role: 'assistant');
      expect(await _verify([start]), [start]);
    });
  });

  group('verifyStage — reasoning encrypted value (F.1)', () {
    test('bytes that decode from the base64 sibling pass through', () async {
      final bytes = Uint8List.fromList([0, 1, 2, 250]);
      final event = ReasoningEncryptedValueEvent(
        entityId: 'e',
        subtype: 'message',
        encryptedValue: bytes,
        encryptedValueBase64: base64Encode(bytes),
      );
      expect(await _verify([event]), [event]);
    });

    test('bytes that disagree with the base64 sibling are rejected', () async {
      final event = ReasoningEncryptedValueEvent(
        entityId: 'e',
        subtype: 'message',
        encryptedValue: Uint8List.fromList([9, 9, 9]),
        encryptedValueBase64: base64Encode(const [0, 1, 2]),
      );
      final out = await _verify([event]);
      expect(out, hasLength(1));
      _expectMalformed(out.single, 'REASONING_ENCRYPTED_VALUE');
    });

    test(
      'a non-base64 sibling string is rejected (off-wire adapter bug)',
      () async {
        final event = ReasoningEncryptedValueEvent(
          entityId: 'e',
          subtype: 'message',
          encryptedValue: Uint8List.fromList([1, 2, 3]),
          encryptedValueBase64: 'not valid base64!!!',
        );
        final out = await _verify([event]);
        expect(out, hasLength(1));
        _expectMalformed(out.single, 'REASONING_ENCRYPTED_VALUE');
      },
    );
  });

  group('verifyStage — passthrough', () {
    test('unrelated events flow through untouched', () async {
      final out = await _verify([
        const RunStartedEvent(threadId: 't', runId: 'r'),
        const StateSnapshotEvent(state: {'count': 1}),
        const RunFinishedEvent(threadId: 't', runId: 'r'),
      ]);
      expect(out, [
        const RunStartedEvent(threadId: 't', runId: 'r'),
        const StateSnapshotEvent(state: {'count': 1}),
        const RunFinishedEvent(threadId: 't', runId: 'r'),
      ]);
    });
  });
}
