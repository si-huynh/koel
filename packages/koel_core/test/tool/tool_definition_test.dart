import 'package:koel_core/src/tool/tool_definition.dart';
import 'package:test/test.dart';

void main() {
  group('ToolDefinition', () {
    test('const construction with parameters defaulting to {}', () {
      const t = ToolDefinition(name: 'lookup', description: 'looks up a value');
      expect(t.parameters, isEmpty);
      expect(
        identical(
          const ToolDefinition(name: 'a', description: 'b'),
          const ToolDefinition(name: 'a', description: 'b'),
        ),
        isTrue,
      );
    });

    test('deep equality including nested parameters map', () {
      final a = ToolDefinition(
        name: 'lookup',
        description: 'd',
        parameters: {
          'type': 'object',
          'properties': {
            'q': {'type': 'string'},
          },
        },
      );
      final b = ToolDefinition(
        name: 'lookup',
        description: 'd',
        parameters: {
          'type': 'object',
          'properties': {
            'q': {'type': 'string'},
          },
        },
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(b.copyWith(parameters: const {'type': 'array'}))));
    });

    test('fromJson(toJson()) round-trips structurally equal', () {
      final t = ToolDefinition(
        name: 'lookup',
        description: 'd',
        parameters: const {'type': 'object'},
      );
      expect(ToolDefinition.fromJson(t.toJson()), equals(t));
    });
  });
}
