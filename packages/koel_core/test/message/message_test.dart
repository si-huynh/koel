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
