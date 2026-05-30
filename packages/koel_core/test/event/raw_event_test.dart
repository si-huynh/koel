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
  group('RawEvent', () {
    test('const construction + type membership', () {
      const event = RawEvent(payload: {'k': 1});
      expect(event.payload, {'k': 1});
      expect(event.source, isNull);
      expect(event, isA<AgUiEvent>());
      expect(event, isA<RawEvent>());
    });

    test('deep structural equality over nested payload', () {
      RawEvent build() => RawEvent(
        payload: {
          'metric': {
            'name': 'latency',
            'samples': [1, 2, 3],
          },
        },
        source: 'acme',
      );
      final a = build();
      final b = build();
      expect(identical(a.payload, b.payload), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith replaces one field, preserves the other', () {
      const event = RawEvent(payload: {'k': 1}, source: 'a');
      final updated = event.copyWith(source: 'b');
      expect(updated.source, 'b');
      expect(updated.payload, event.payload);
    });

    test('differing source breaks equality', () {
      const a = RawEvent(payload: {'k': 1}, source: 'a');
      const b = RawEvent(payload: {'k': 1}, source: 'b');
      expect(a, isNot(equals(b)));
    });

    test('fromJson reads wire key `event`; toJson writes it back', () {
      final event = RawEvent.fromJson({
        'type': 'RAW',
        'event': {'k': 1},
        'source': 'acme',
      });
      expect(event.payload, {'k': 1});
      expect(event.source, 'acme');
      expect(event.toJson(), {
        'type': 'RAW',
        'event': {'k': 1},
        'source': 'acme',
      });
    });

    test('round-trips via fromJson/toJson and dispatcher', () {
      const event = RawEvent(payload: {'k': 1}, source: 'acme');
      expect(RawEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('source omitted from toJson when null and round-trips to null', () {
      const event = RawEvent(payload: {'k': 1});
      expect(event.toJson(), {
        'type': 'RAW',
        'event': {'k': 1},
      });
      final round = RawEvent.fromJson(event.toJson());
      expect(round.source, isNull);
      expect(round, equals(event));
    });

    test('missing `event` throws ProtocolError(protocolMalformed)', () {
      expect(() => RawEvent.fromJson({'type': 'RAW'}), _malformed);
    });

    test('non-object `event` throws ProtocolError(protocolMalformed)', () {
      expect(
        () => RawEvent.fromJson({'type': 'RAW', 'event': 'not-an-object'}),
        _malformed,
      );
    });

    test('non-String `source` throws ProtocolError(protocolMalformed)', () {
      expect(
        () => RawEvent.fromJson({
          'type': 'RAW',
          'event': {'k': 1},
          'source': 7,
        }),
        _malformed,
      );
    });
  });
}
