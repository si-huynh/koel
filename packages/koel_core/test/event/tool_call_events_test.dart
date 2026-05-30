import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/event/event_deserializer.dart';
import 'package:test/test.dart';

/// Matches a [ProtocolError] carrying `KoelErrorCode.protocolMalformed`.
final _malformed = throwsA(
  isA<ProtocolError>().having(
    (e) => e.code,
    'code',
    KoelErrorCode.protocolMalformed,
  ),
);

void main() {
  group('ToolCallStartEvent', () {
    test('const construction + type membership', () {
      const event = ToolCallStartEvent(
        toolCallId: 'tc1',
        toolCallName: 'search',
      );
      expect(event.toolCallId, 'tc1');
      expect(event.toolCallName, 'search');
      expect(event.parentMessageId, isNull);
      expect(event, isA<AgUiEvent>());
      expect(event, isA<ToolCallStartEvent>());
    });

    test('structural equality + hashCode', () {
      const a = ToolCallStartEvent(
        toolCallId: 'tc1',
        toolCallName: 'search',
        parentMessageId: 'm1',
      );
      const b = ToolCallStartEvent(
        toolCallId: 'tc1',
        toolCallName: 'search',
        parentMessageId: 'm1',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(
        a,
        isNot(
          equals(
            const ToolCallStartEvent(toolCallId: 'tc1', toolCallName: 'other'),
          ),
        ),
      );
    });

    test('copyWith updates one field', () {
      const event = ToolCallStartEvent(
        toolCallId: 'tc1',
        toolCallName: 'search',
      );
      expect(event.copyWith(toolCallName: 'lookup').toolCallName, 'lookup');
      expect(event.copyWith(toolCallName: 'lookup').toolCallId, 'tc1');
    });

    test('fromJson decodes fields; parentMessageId optional', () {
      final event = ToolCallStartEvent.fromJson({
        'type': 'TOOL_CALL_START',
        'toolCallId': 'tc1',
        'toolCallName': 'search',
        'parentMessageId': 'm1',
      });
      expect(
        event,
        const ToolCallStartEvent(
          toolCallId: 'tc1',
          toolCallName: 'search',
          parentMessageId: 'm1',
        ),
      );
    });

    test('round-trips via fromJson(toJson()) and deserializeAgUiEvent', () {
      const event = ToolCallStartEvent(
        toolCallId: 'tc1',
        toolCallName: 'search',
        parentMessageId: 'm1',
      );
      expect(ToolCallStartEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('toJson omits absent parentMessageId', () {
      const event = ToolCallStartEvent(
        toolCallId: 'tc1',
        toolCallName: 'search',
      );
      expect(event.toJson(), {
        'type': 'TOOL_CALL_START',
        'toolCallId': 'tc1',
        'toolCallName': 'search',
      });
    });

    test('missing toolCallId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ToolCallStartEvent.fromJson({
          'type': 'TOOL_CALL_START',
          'toolCallName': 'search',
        }),
        _malformed,
      );
    });

    test('missing toolCallName throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ToolCallStartEvent.fromJson({
          'type': 'TOOL_CALL_START',
          'toolCallId': 'tc1',
        }),
        _malformed,
      );
    });

    test('non-String parentMessageId throws ProtocolError', () {
      expect(
        () => ToolCallStartEvent.fromJson({
          'type': 'TOOL_CALL_START',
          'toolCallId': 'tc1',
          'toolCallName': 'search',
          'parentMessageId': 42,
        }),
        _malformed,
      );
    });
  });

  group('ToolCallArgsEvent', () {
    test('const construction + type membership', () {
      const event = ToolCallArgsEvent(toolCallId: 'tc1', delta: '{"q":');
      expect(event.toolCallId, 'tc1');
      expect(event.delta, '{"q":');
      expect(event, isA<AgUiEvent>());
    });

    test('copyWith updates one field', () {
      const event = ToolCallArgsEvent(toolCallId: 'tc1', delta: '{');
      expect(event.copyWith(delta: '}').delta, '}');
      expect(event.copyWith(delta: '}').toolCallId, 'tc1');
    });

    test('round-trips + fromJson decodes fields', () {
      const event = ToolCallArgsEvent(toolCallId: 'tc1', delta: '"hi"}');
      expect(ToolCallArgsEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
      expect(event.toJson(), {
        'type': 'TOOL_CALL_ARGS',
        'toolCallId': 'tc1',
        'delta': '"hi"}',
      });
    });

    test('missing delta throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ToolCallArgsEvent.fromJson({
          'type': 'TOOL_CALL_ARGS',
          'toolCallId': 'tc1',
        }),
        _malformed,
      );
    });
  });

  group('ToolCallEndEvent', () {
    test('const construction + round-trip', () {
      const event = ToolCallEndEvent(toolCallId: 'tc1');
      expect(event, isA<AgUiEvent>());
      expect(ToolCallEndEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
      expect(event.toJson(), {'type': 'TOOL_CALL_END', 'toolCallId': 'tc1'});
    });

    test('copyWith updates toolCallId', () {
      const event = ToolCallEndEvent(toolCallId: 'tc1');
      expect(event.copyWith(toolCallId: 'tc2').toolCallId, 'tc2');
    });

    test('missing toolCallId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ToolCallEndEvent.fromJson({'type': 'TOOL_CALL_END'}),
        _malformed,
      );
    });
  });

  group('ToolCallResultEvent', () {
    test('const construction + type membership', () {
      const event = ToolCallResultEvent(
        messageId: 'm1',
        toolCallId: 'tc1',
        content: 'ok',
      );
      expect(event.messageId, 'm1');
      expect(event.toolCallId, 'tc1');
      expect(event.content, 'ok');
      expect(event.role, isNull);
      expect(event, isA<AgUiEvent>());
    });

    test('copyWith updates one field', () {
      const event = ToolCallResultEvent(
        messageId: 'm1',
        toolCallId: 'tc1',
        content: 'ok',
      );
      expect(event.copyWith(content: 'done').content, 'done');
      expect(event.copyWith(content: 'done').messageId, 'm1');
    });

    test('round-trips with optional role present', () {
      const event = ToolCallResultEvent(
        messageId: 'm1',
        toolCallId: 'tc1',
        content: 'ok',
        role: 'tool',
      );
      expect(ToolCallResultEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
      expect(event.toJson(), {
        'type': 'TOOL_CALL_RESULT',
        'messageId': 'm1',
        'toolCallId': 'tc1',
        'content': 'ok',
        'role': 'tool',
      });
    });

    test('round-trips with role absent; toJson omits it', () {
      const event = ToolCallResultEvent(
        messageId: 'm1',
        toolCallId: 'tc1',
        content: 'ok',
      );
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
      expect(event.toJson(), {
        'type': 'TOOL_CALL_RESULT',
        'messageId': 'm1',
        'toolCallId': 'tc1',
        'content': 'ok',
      });
    });

    test('missing content throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ToolCallResultEvent.fromJson({
          'type': 'TOOL_CALL_RESULT',
          'messageId': 'm1',
          'toolCallId': 'tc1',
        }),
        _malformed,
      );
    });

    test('non-String role throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ToolCallResultEvent.fromJson({
          'type': 'TOOL_CALL_RESULT',
          'messageId': 'm1',
          'toolCallId': 'tc1',
          'content': 'ok',
          'role': 7,
        }),
        _malformed,
      );
    });
  });

  group('ToolCallChunkEvent', () {
    test('empty chunk decodes to all-null and round-trips', () {
      final event = ToolCallChunkEvent.fromJson({'type': 'TOOL_CALL_CHUNK'});
      expect(event.toolCallId, isNull);
      expect(event.toolCallName, isNull);
      expect(event.parentMessageId, isNull);
      expect(event.delta, isNull);
      expect(event.toJson(), {'type': 'TOOL_CALL_CHUNK'});
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('partial chunk omits absent optionals on toJson', () {
      const event = ToolCallChunkEvent(toolCallId: 'tc1', delta: '{');
      expect(event.toJson(), {
        'type': 'TOOL_CALL_CHUNK',
        'toolCallId': 'tc1',
        'delta': '{',
      });
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('copyWith updates one field', () {
      const event = ToolCallChunkEvent(toolCallId: 'tc1');
      expect(event.copyWith(delta: '{').delta, '{');
      expect(event.copyWith(delta: '{').toolCallId, 'tc1');
    });

    test('fully-populated chunk round-trips', () {
      const event = ToolCallChunkEvent(
        toolCallId: 'tc1',
        toolCallName: 'search',
        parentMessageId: 'm1',
        delta: '{"q":1}',
      );
      expect(ToolCallChunkEvent.fromJson(event.toJson()), equals(event));
    });

    test('non-String optional member throws ProtocolError', () {
      expect(
        () => ToolCallChunkEvent.fromJson({
          'type': 'TOOL_CALL_CHUNK',
          'delta': 42,
        }),
        _malformed,
      );
    });
  });
}
