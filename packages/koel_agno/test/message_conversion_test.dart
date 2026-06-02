@TestOn('vm')
library;

// Reaches the internal `agnoMessageToWire` directly — it is not part of the
// barrel's public surface (only `AgnoConversionOptions` is exported there).
import 'package:koel_agno/src/conversion/message_conversion.dart';
import 'package:koel_core/koel_core.dart';
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
  group('agnoMessageToWire', () {
    const options = AgnoConversionOptions();

    group('emits canonical AG-UI {id, role, content} per role', () {
      for (final role in MessageRole.values) {
        test('role ${role.name} maps to its identity string', () {
          final wire = agnoMessageToWire(
            _message(id: 'm-${role.name}', role: role, content: 'c'),
            options,
          );

          expect(wire, {
            'id': 'm-${role.name}',
            'role': role.name,
            'content': 'c',
          });
        });
      }
    });

    group('toolCallId / name appear only when non-null', () {
      test('both absent for a plain turn — keys are missing, not null', () {
        final wire = agnoMessageToWire(_message(), options);

        expect(wire, isNot(contains('toolCallId')));
        expect(wire, isNot(contains('name')));
      });

      test('a tool turn carries both populated keys', () {
        final wire = agnoMessageToWire(
          _message(
            role: MessageRole.tool,
            toolCallId: 'call-7',
            name: 'search',
          ),
          options,
        );

        expect(wire, containsPair('toolCallId', 'call-7'));
        expect(wire, containsPair('name', 'search'));
      });

      test('toolCallId alone is included; name stays absent', () {
        final wire = agnoMessageToWire(_message(toolCallId: 'call-7'), options);

        expect(wire, containsPair('toolCallId', 'call-7'));
        expect(wire, isNot(contains('name')));
      });
    });

    group('timestamp follows includeTimestamp', () {
      test('excluded by default (canonical AG-UI has no timestamp)', () {
        final wire = agnoMessageToWire(_message(), options);

        expect(wire, isNot(contains('timestamp')));
      });

      test('included as ISO-8601 when opted in', () {
        final wire = agnoMessageToWire(
          _message(timestamp: DateTime.utc(2026, 6, 2, 12, 30, 45)),
          const AgnoConversionOptions(includeTimestamp: true),
        );

        expect(wire, containsPair('timestamp', '2026-06-02T12:30:45.000Z'));
      });
    });

    test('never emits an explicit-null value on any axis', () {
      // Sweep the full cross-product of optional-field presence × timestamp flag;
      // a canonical AG-UI wire must never carry a `null` value (absent ≠ null).
      for (final toolCallId in const [null, 'call-1']) {
        for (final name in const [null, 'fn']) {
          for (final includeTimestamp in const [false, true]) {
            final wire = agnoMessageToWire(
              _message(toolCallId: toolCallId, name: name),
              AgnoConversionOptions(includeTimestamp: includeTimestamp),
            );

            expect(
              wire.values,
              isNot(contains(null)),
              reason: 'toolCallId=$toolCallId name=$name ts=$includeTimestamp',
            );
          }
        }
      }
    });
  });
}
