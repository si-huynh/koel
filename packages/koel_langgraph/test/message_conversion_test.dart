@TestOn('vm')
library;

// Reaches the internal `langGraphMessageToWire` directly — it is not part of the
// barrel's public surface (the conversion file exports no public type).
import 'package:koel_core/koel_core.dart';
import 'package:koel_langgraph/src/conversion/message_conversion.dart';
import 'package:test/test.dart';

/// Builds a [Message]; defaults give a plain user turn with the optional fields
/// unset, so each test overrides only the axis it exercises.
Message _message({
  String id = 'm-1',
  MessageRole role = MessageRole.user,
  String content = 'hello',
  DateTime? timestamp,
  String? toolCallId,
  String? name,
}) => Message(
  id: id,
  role: role,
  content: content,
  timestamp: timestamp ?? DateTime.utc(2026, 6, 2, 12, 30, 45),
  toolCallId: toolCallId,
  name: name,
);

void main() {
  group('langGraphMessageToWire', () {
    group('emits canonical AG-UI {id, role, content} per role', () {
      for (final role in MessageRole.values) {
        test('role ${role.name} maps to its identity string', () {
          final wire = langGraphMessageToWire(
            _message(id: 'm-${role.name}', role: role, content: 'c'),
          );

          expect(wire, {
            'id': 'm-${role.name}',
            'role': role.name,
            'content': 'c',
          });
        });
      }

      test('empty content is emitted verbatim — the key is present, not '
          'dropped', () {
        final wire = langGraphMessageToWire(_message(content: ''));

        // canonical AG-UI keeps `content` always; an empty string is a valid
        // value (e.g. an assistant turn that is pure tool-calls), never omitted.
        expect(wire, containsPair('content', ''));
      });
    });

    group('toolCallId / name appear only when non-null', () {
      test('both absent for a plain turn — keys are missing, not null', () {
        final wire = langGraphMessageToWire(_message());

        expect(wire, isNot(contains('toolCallId')));
        expect(wire, isNot(contains('name')));
      });

      test('a tool turn carries both populated keys', () {
        final wire = langGraphMessageToWire(
          _message(
            role: MessageRole.tool,
            toolCallId: 'call-7',
            name: 'search',
          ),
        );

        expect(wire, containsPair('toolCallId', 'call-7'));
        expect(wire, containsPair('name', 'search'));
      });

      test('toolCallId alone is included; name stays absent', () {
        final wire = langGraphMessageToWire(_message(toolCallId: 'call-7'));

        expect(wire, containsPair('toolCallId', 'call-7'));
        expect(wire, isNot(contains('name')));
      });
    });

    test('koel-only timestamp is always dropped (canonical AG-UI has none)', () {
      // There is no opt-in knob (unlike agno): A.4 exposes no `conversion` param,
      // so the koel-internal timestamp never reaches the LangGraph wire.
      final wire = langGraphMessageToWire(
        _message(timestamp: DateTime.utc(2026, 6, 2, 12, 30, 45)),
      );

      expect(wire, isNot(contains('timestamp')));
    });

    test('never emits an explicit-null value on any axis', () {
      // Sweep the full cross-product of optional-field presence; a canonical
      // AG-UI wire must never carry a `null` value (absent != null).
      for (final toolCallId in const [null, 'call-1']) {
        for (final name in const [null, 'fn']) {
          final wire = langGraphMessageToWire(
            _message(toolCallId: toolCallId, name: name),
          );

          expect(
            wire.values,
            isNot(contains(null)),
            reason: 'toolCallId=$toolCallId name=$name',
          );
        }
      }
    });
  });
}
