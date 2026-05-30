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
  group('CustomEvent', () {
    test('const construction + type membership', () {
      const event = CustomEvent(name: 'predictive_state', value: 42);
      expect(event.name, 'predictive_state');
      expect(event.value, 42);
      expect(event, isA<AgUiEvent>());
      expect(event, isA<CustomEvent>());
    });

    test('scalar value compares by value', () {
      const a = CustomEvent(name: 'x', value: 'hello');
      const b = CustomEvent(name: 'x', value: 'hello');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing name or value breaks equality', () {
      const base = CustomEvent(name: 'x', value: 1);
      expect(base, isNot(equals(const CustomEvent(name: 'y', value: 1))));
      expect(base, isNot(equals(const CustomEvent(name: 'x', value: 2))));
    });

    test('copyWith replaces one field', () {
      const event = CustomEvent(name: 'x', value: 1);
      expect(event.copyWith(value: 2).value, 2);
      expect(event.copyWith(name: 'y').name, 'y');
    });

    test('fromJson/toJson round-trip and dispatcher — scalar value', () {
      const event = CustomEvent(name: 'x', value: 'v');
      expect(event.toJson(), {'type': 'CUSTOM', 'name': 'x', 'value': 'v'});
      expect(CustomEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test(
      'value carries any JSON shape and round-trips via toJson/fromJson',
      () {
        for (final v in <Object?>[
          {
            'nested': {'a': 1},
          },
          [1, 'two', false],
          'string',
          3.14,
          true,
          null,
        ]) {
          final event = CustomEvent(name: 'x', value: v);
          final round = CustomEvent.fromJson(event.toJson());
          expect(round, equals(event), reason: 'value=$v');
          expect(round.value, event.value);
        }
      },
    );

    test('explicit null value is emitted and round-trips', () {
      const event = CustomEvent(name: 'x', value: null);
      expect(event.toJson(), {'type': 'CUSTOM', 'name': 'x', 'value': null});
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('missing `name` throws ProtocolError(protocolMalformed)', () {
      expect(
        () => CustomEvent.fromJson({'type': 'CUSTOM', 'value': 1}),
        _malformed,
      );
    });

    test('non-String `name` throws ProtocolError(protocolMalformed)', () {
      expect(
        () => CustomEvent.fromJson({'type': 'CUSTOM', 'name': 7, 'value': 1}),
        _malformed,
      );
    });
  });
}
