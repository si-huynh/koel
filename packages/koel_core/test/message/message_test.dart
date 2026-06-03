import 'package:koel_core/src/message/message.dart';
import 'package:test/test.dart';

void main() {
  final ts = DateTime.utc(2026, 5, 29, 12, 30, 15);

  Message base() => Message(
    id: 'm1',
    role: MessageRole.user,
    content: 'hello',
    timestamp: ts,
  );

  group('Message', () {
    test(
      'equal field values (incl. equal timestamp) are == with same hashCode',
      () {
        // Distinct DateTime instances at the same instant must compare equal.
        final a = base();
        final b = Message(
          id: 'm1',
          role: MessageRole.user,
          content: 'hello',
          timestamp: DateTime.utc(2026, 5, 29, 12, 30, 15),
        );
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      },
    );

    test('differing in any single field is !=', () {
      expect(base(), isNot(equals(base().copyWith(id: 'm2'))));
      expect(
        base(),
        isNot(equals(base().copyWith(role: MessageRole.assistant))),
      );
      expect(base(), isNot(equals(base().copyWith(content: 'bye'))));
      expect(
        base(),
        isNot(
          equals(
            base().copyWith(timestamp: DateTime.utc(2026, 5, 29, 12, 30, 16)),
          ),
        ),
      );
      expect(base(), isNot(equals(base().copyWith(toolCallId: 'tc1'))));
      expect(base(), isNot(equals(base().copyWith(name: 'fn'))));
    });

    test('MessageRole has exactly {user, assistant, system, tool}', () {
      expect(MessageRole.values, [
        MessageRole.user,
        MessageRole.assistant,
        MessageRole.system,
        MessageRole.tool,
      ]);
    });

    test('optional toolCallId and name default to null', () {
      final m = base();
      expect(m.toolCallId, isNull);
      expect(m.name, isNull);
    });

    test('fromJson(toJson()) round-trips structurally equal', () {
      final m = base().copyWith(
        role: MessageRole.tool,
        toolCallId: 'tc1',
        name: 'lookup',
      );
      expect(Message.fromJson(m.toJson()), equals(m));
    });

    test('fromJson decodes a canonical AG-UI message that omits timestamp — '
        'a backend MESSAGES_SNAPSHOT replay — to the epoch sentinel, not a '
        'throw', () {
      // `timestamp` is a koel addition absent from the AG-UI `Message`, so a
      // native-AG-UI backend (e.g. LangGraph) re-emits inbound messages without
      // it. Decoding must tolerate that and stay deterministic.
      final decoded = Message.fromJson(const {
        'id': 'm-1',
        'role': 'user',
        'content': 'hello',
      });

      expect(decoded.id, 'm-1');
      expect(decoded.role, MessageRole.user);
      expect(decoded.content, 'hello');
      expect(
        decoded.timestamp,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      // An explicit null is treated identically to absence.
      expect(
        Message.fromJson(const {
          'id': 'm-2',
          'role': 'assistant',
          'content': 'hi',
          'timestamp': null,
        }).timestamp,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    });

    test('fromJson still parses a present ISO-8601 timestamp', () {
      expect(
        Message.fromJson({
          'id': 'm-1',
          'role': 'user',
          'content': 'hello',
          'timestamp': ts.toIso8601String(),
        }).timestamp,
        ts,
      );
    });

    test('fromJson decodes an assistant tool-call message that omits content — '
        'a dojo MESSAGES_SNAPSHOT turn — to the empty string, not a throw', () {
      // An assistant message carrying `toolCalls` has no textual `content` on
      // the AG-UI wire (Story 5.9 dojo `MESSAGES_SNAPSHOT`); decoding must
      // tolerate absence and preserve the non-nullable invariant.
      final decoded = Message.fromJson(const {
        'id': 'id-0',
        'role': 'assistant',
        'toolCalls': [
          {
            'id': 'id-1',
            'type': 'function',
            'function': {'name': 'get_weather', 'arguments': '{}'},
          },
        ],
      });

      expect(decoded.role, MessageRole.assistant);
      expect(decoded.content, '');
      // An explicit null is treated identically to absence.
      expect(
        Message.fromJson(const {
          'id': 'id-2',
          'role': 'assistant',
          'content': null,
        }).content,
        '',
      );
    });

    test('fromJson still parses a present content string', () {
      expect(
        Message.fromJson(const {
          'id': 'm-1',
          'role': 'user',
          'content': 'hello',
        }).content,
        'hello',
      );
    });

    test('copyWith updates one field and leaves others identical', () {
      final m = base();
      final updated = m.copyWith(content: 'world');
      expect(updated.content, 'world');
      expect(updated.id, m.id);
      expect(updated.role, m.role);
      expect(updated.timestamp, m.timestamp);
      expect(updated.toolCallId, m.toolCallId);
      expect(updated.name, m.name);
    });
  });
}
