import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:test/test.dart';

void main() {
  group('UnknownAgUiEvent', () {
    test('const construction with required type and rawJson', () {
      const event = UnknownAgUiEvent(
        type: 'FUTURE_EVENT',
        rawJson: {'type': 'FUTURE_EVENT'},
      );
      expect(event.type, 'FUTURE_EVENT');
      expect(event.rawJson, {'type': 'FUTURE_EVENT'});
    });

    test('is a member of the AgUiEvent union', () {
      const event = UnknownAgUiEvent(type: 'X', rawJson: {});
      expect(event, isA<AgUiEvent>());
    });

    test(
      'deep structural equality over distinct but content-equal rawJson',
      () {
        UnknownAgUiEvent build() => UnknownAgUiEvent(
          type: 'FUTURE_EVENT',
          rawJson: {
            'type': 'FUTURE_EVENT',
            'nested': {
              'list': [1, 2, 3],
              'flag': true,
            },
          },
        );
        final a = build();
        final b = build();
        expect(identical(a.rawJson, b.rawJson), isFalse);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      },
    );

    test('differing type breaks equality', () {
      const a = UnknownAgUiEvent(type: 'A', rawJson: {'k': 1});
      const b = UnknownAgUiEvent(type: 'B', rawJson: {'k': 1});
      expect(a, isNot(equals(b)));
    });

    test('differing rawJson breaks equality', () {
      final a = UnknownAgUiEvent(type: 'A', rawJson: {'k': 1});
      final b = UnknownAgUiEvent(type: 'A', rawJson: {'k': 2});
      expect(a, isNot(equals(b)));
    });

    test('copyWith updates one field and leaves the other identical', () {
      const event = UnknownAgUiEvent(type: 'A', rawJson: {'k': 1});
      final updated = event.copyWith(type: 'B');
      expect(updated.type, 'B');
      expect(updated.rawJson, event.rawJson);
    });
  });
}
