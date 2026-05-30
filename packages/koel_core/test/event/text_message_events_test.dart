import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/event/event_deserializer.dart';
import 'package:test/test.dart';

void main() {
  group('TextMessageStartEvent', () {
    test('const construction + type membership', () {
      const event = TextMessageStartEvent(messageId: 'm1', role: 'assistant');
      expect(event.messageId, 'm1');
      expect(event.role, 'assistant');
      expect(event, isA<AgUiEvent>());
      expect(event, isA<TextMessageStartEvent>());
    });

    test('structural equality + copyWith', () {
      const a = TextMessageStartEvent(messageId: 'm1', role: 'assistant');
      expect(
        a,
        equals(const TextMessageStartEvent(messageId: 'm1', role: 'assistant')),
      );
      expect(
        a,
        isNot(
          equals(const TextMessageStartEvent(messageId: 'm1', role: 'user')),
        ),
      );
      expect(a.copyWith(role: 'user').role, 'user');
    });

    test('fromJson + dual round-trip', () {
      final event = TextMessageStartEvent.fromJson({
        'type': 'TEXT_MESSAGE_START',
        'messageId': 'm1',
        'role': 'assistant',
      });
      expect(
        event,
        const TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
      );
      expect(event.toJson(), {
        'type': 'TEXT_MESSAGE_START',
        'messageId': 'm1',
        'role': 'assistant',
      });
      expect(TextMessageStartEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('missing messageId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => TextMessageStartEvent.fromJson({
          'type': 'TEXT_MESSAGE_START',
          'role': 'assistant',
        }),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });

    test('non-String messageId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => TextMessageStartEvent.fromJson({
          'type': 'TEXT_MESSAGE_START',
          'messageId': 42,
          'role': 'assistant',
        }),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });
  });

  group('TextMessageContentEvent', () {
    test('fromJson + dual round-trip', () {
      final event = TextMessageContentEvent.fromJson({
        'type': 'TEXT_MESSAGE_CONTENT',
        'messageId': 'm1',
        'delta': 'hello',
      });
      expect(
        event,
        const TextMessageContentEvent(messageId: 'm1', delta: 'hello'),
      );
      expect(event.toJson(), {
        'type': 'TEXT_MESSAGE_CONTENT',
        'messageId': 'm1',
        'delta': 'hello',
      });
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('copyWith + equality', () {
      const a = TextMessageContentEvent(messageId: 'm1', delta: 'a');
      expect(a.copyWith(delta: 'b').delta, 'b');
      expect(
        a,
        isNot(
          equals(const TextMessageContentEvent(messageId: 'm1', delta: 'b')),
        ),
      );
    });

    test('missing delta throws ProtocolError(protocolMalformed)', () {
      expect(
        () => TextMessageContentEvent.fromJson({
          'type': 'TEXT_MESSAGE_CONTENT',
          'messageId': 'm1',
        }),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });
  });

  group('TextMessageEndEvent', () {
    test('fromJson + dual round-trip', () {
      final event = TextMessageEndEvent.fromJson({
        'type': 'TEXT_MESSAGE_END',
        'messageId': 'm1',
      });
      expect(event, const TextMessageEndEvent(messageId: 'm1'));
      expect(event.toJson(), {'type': 'TEXT_MESSAGE_END', 'messageId': 'm1'});
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('missing messageId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => TextMessageEndEvent.fromJson({'type': 'TEXT_MESSAGE_END'}),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });
  });

  group('TextMessageChunkEvent (all-optional)', () {
    test('fully-populated round-trip', () {
      const event = TextMessageChunkEvent(
        messageId: 'm1',
        role: 'assistant',
        delta: 'hi',
      );
      expect(event.toJson(), {
        'type': 'TEXT_MESSAGE_CHUNK',
        'messageId': 'm1',
        'role': 'assistant',
        'delta': 'hi',
      });
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('empty chunk decodes to all-null and round-trips, no throw', () {
      final event = TextMessageChunkEvent.fromJson({
        'type': 'TEXT_MESSAGE_CHUNK',
      });
      expect(event.messageId, isNull);
      expect(event.role, isNull);
      expect(event.delta, isNull);
      expect(event.toJson(), {'type': 'TEXT_MESSAGE_CHUNK'});
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('partial chunk omits absent optionals', () {
      const event = TextMessageChunkEvent(delta: 'hi');
      expect(event.toJson(), {'type': 'TEXT_MESSAGE_CHUNK', 'delta': 'hi'});
      expect(event, isA<AgUiEvent>());
    });

    test('non-String optional throws ProtocolError(protocolMalformed)', () {
      expect(
        () => TextMessageChunkEvent.fromJson({
          'type': 'TEXT_MESSAGE_CHUNK',
          'delta': 42,
        }),
        throwsA(
          isA<ProtocolError>().having(
            (e) => e.code,
            'code',
            KoelErrorCode.protocolMalformed,
          ),
        ),
      );
    });
  });
}
