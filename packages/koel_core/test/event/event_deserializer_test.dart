import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/event/event_deserializer.dart';
import 'package:test/test.dart';

void main() {
  group('deserializeAgUiEvent', () {
    test('the registry is empty in this story', () {
      expect(eventTypeRegistry, isEmpty);
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
