import 'dart:convert';
import 'dart:typed_data';

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
  group('ReasoningStartEvent', () {
    test('const construction + type membership', () {
      const event = ReasoningStartEvent(messageId: 'r1');
      expect(event.messageId, 'r1');
      expect(event, isA<AgUiEvent>());
      expect(event, isA<ReasoningStartEvent>());
    });

    test('equality + copyWith', () {
      const event = ReasoningStartEvent(messageId: 'r1');
      expect(event, equals(const ReasoningStartEvent(messageId: 'r1')));
      expect(event, isNot(equals(event.copyWith(messageId: 'r2'))));
    });

    test('round-trips via fromJson/toJson and dispatcher', () {
      const event = ReasoningStartEvent(messageId: 'r1');
      expect(event.toJson(), {'type': 'REASONING_START', 'messageId': 'r1'});
      expect(ReasoningStartEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('missing messageId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ReasoningStartEvent.fromJson({'type': 'REASONING_START'}),
        _malformed,
      );
    });

    test('non-String messageId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ReasoningStartEvent.fromJson({
          'type': 'REASONING_START',
          'messageId': 7,
        }),
        _malformed,
      );
    });
  });

  group('ReasoningEndEvent', () {
    test('const construction + round-trip', () {
      const event = ReasoningEndEvent(messageId: 'r1');
      expect(event, isA<AgUiEvent>());
      expect(event.toJson(), {'type': 'REASONING_END', 'messageId': 'r1'});
      expect(ReasoningEndEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('copyWith + inequality', () {
      const event = ReasoningEndEvent(messageId: 'r1');
      expect(event, isNot(equals(event.copyWith(messageId: 'r2'))));
    });

    test('missing messageId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ReasoningEndEvent.fromJson({'type': 'REASONING_END'}),
        _malformed,
      );
    });
  });

  group('ReasoningMessageStartEvent', () {
    test('const construction + type membership', () {
      const event = ReasoningMessageStartEvent(
        messageId: 'r1',
        role: 'reasoning',
      );
      expect(event.messageId, 'r1');
      expect(event.role, 'reasoning');
      expect(event, isA<AgUiEvent>());
    });

    test('round-trips (role kept a permissive String)', () {
      const event = ReasoningMessageStartEvent(
        messageId: 'r1',
        role: 'reasoning',
      );
      expect(event.toJson(), {
        'type': 'REASONING_MESSAGE_START',
        'messageId': 'r1',
        'role': 'reasoning',
      });
      expect(
        ReasoningMessageStartEvent.fromJson(event.toJson()),
        equals(event),
      );
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('copyWith + inequality', () {
      const event = ReasoningMessageStartEvent(
        messageId: 'r1',
        role: 'reasoning',
      );
      expect(event, isNot(equals(event.copyWith(messageId: 'r2'))));
      expect(event, isNot(equals(event.copyWith(role: 'other'))));
    });

    test('missing messageId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ReasoningMessageStartEvent.fromJson({
          'type': 'REASONING_MESSAGE_START',
          'role': 'reasoning',
        }),
        _malformed,
      );
    });

    test('missing role throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ReasoningMessageStartEvent.fromJson({
          'type': 'REASONING_MESSAGE_START',
          'messageId': 'r1',
        }),
        _malformed,
      );
    });
  });

  group('ReasoningMessageContentEvent', () {
    test('const construction + round-trip', () {
      const event = ReasoningMessageContentEvent(
        messageId: 'r1',
        delta: 'thinking…',
      );
      expect(event.toJson(), {
        'type': 'REASONING_MESSAGE_CONTENT',
        'messageId': 'r1',
        'delta': 'thinking…',
      });
      expect(
        ReasoningMessageContentEvent.fromJson(event.toJson()),
        equals(event),
      );
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('copyWith + inequality', () {
      const event = ReasoningMessageContentEvent(messageId: 'r1', delta: 'a');
      expect(event, isNot(equals(event.copyWith(delta: 'b'))));
    });

    test('missing delta throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ReasoningMessageContentEvent.fromJson({
          'type': 'REASONING_MESSAGE_CONTENT',
          'messageId': 'r1',
        }),
        _malformed,
      );
    });
  });

  group('ReasoningMessageEndEvent', () {
    test('const construction + round-trip', () {
      const event = ReasoningMessageEndEvent(messageId: 'r1');
      expect(event.toJson(), {
        'type': 'REASONING_MESSAGE_END',
        'messageId': 'r1',
      });
      expect(ReasoningMessageEndEvent.fromJson(event.toJson()), equals(event));
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('copyWith + inequality', () {
      const event = ReasoningMessageEndEvent(messageId: 'r1');
      expect(event, isNot(equals(event.copyWith(messageId: 'r2'))));
    });

    test('missing messageId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ReasoningMessageEndEvent.fromJson({
          'type': 'REASONING_MESSAGE_END',
        }),
        _malformed,
      );
    });
  });

  group('ReasoningMessageChunkEvent', () {
    test('all-optional: empty chunk decodes to all-null without throwing', () {
      final event = ReasoningMessageChunkEvent.fromJson({
        'type': 'REASONING_MESSAGE_CHUNK',
      });
      expect(event.messageId, isNull);
      expect(event.delta, isNull);
      expect(event, isA<AgUiEvent>());
    });

    test('empty chunk round-trips (toJson omits absent optionals)', () {
      const event = ReasoningMessageChunkEvent();
      expect(event.toJson(), {'type': 'REASONING_MESSAGE_CHUNK'});
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('partial chunk round-trips, omitting the absent optional', () {
      const event = ReasoningMessageChunkEvent(messageId: 'r1');
      expect(event.toJson(), {
        'type': 'REASONING_MESSAGE_CHUNK',
        'messageId': 'r1',
      });
      expect(
        ReasoningMessageChunkEvent.fromJson(event.toJson()),
        equals(event),
      );
    });

    test('fully-populated chunk round-trips', () {
      const event = ReasoningMessageChunkEvent(messageId: 'r1', delta: 'd');
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('copyWith + inequality', () {
      const event = ReasoningMessageChunkEvent(messageId: 'r1', delta: 'a');
      expect(event, isNot(equals(event.copyWith(delta: 'b'))));
    });

    test('non-String optional throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ReasoningMessageChunkEvent.fromJson({
          'type': 'REASONING_MESSAGE_CHUNK',
          'delta': 7,
        }),
        _malformed,
      );
    });
  });

  group('ReasoningEncryptedValueEvent', () {
    // A fixed sample blob with full base64 padding (3 bytes → no `=`).
    final sampleBytes = Uint8List.fromList([0xDE, 0xAD, 0xBE]);
    final sampleB64 = base64Encode(sampleBytes);

    test('const construction + type membership', () {
      final event = ReasoningEncryptedValueEvent(
        entityId: 'e1',
        subtype: 'message',
        encryptedValue: sampleBytes,
        encryptedValueBase64: sampleB64,
      );
      expect(event.entityId, 'e1');
      expect(event.subtype, 'message');
      expect(event.encryptedValue, sampleBytes);
      expect(event.encryptedValueBase64, sampleB64);
      expect(event, isA<AgUiEvent>());
    });

    test('fromJson decodes base64 to bytes AND preserves the wire string', () {
      final event = ReasoningEncryptedValueEvent.fromJson({
        'type': 'REASONING_ENCRYPTED_VALUE',
        'subtype': 'tool-call',
        'entityId': 'e1',
        'encryptedValue': sampleB64,
      });
      expect(event.entityId, 'e1');
      expect(event.subtype, 'tool-call');
      expect(event.encryptedValue, sampleBytes);
      expect(event.encryptedValueBase64, sampleB64);
      // Exact wire shape: the base64 sibling is NOT emitted under its own key —
      // a stray `encryptedValueBase64` (or a re-encoded blob) would fail here.
      expect(event.toJson(), {
        'type': 'REASONING_ENCRYPTED_VALUE',
        'subtype': 'tool-call',
        'entityId': 'e1',
        'encryptedValue': sampleB64,
      });
    });

    test('wire round-trip echoes the original base64 string verbatim (toJson '
        'reads the preserved string, never re-encodes the bytes)', () {
      const wire = 'AAAA'; // decodes to 3 zero bytes
      final event = ReasoningEncryptedValueEvent.fromJson({
        'type': 'REASONING_ENCRYPTED_VALUE',
        'subtype': 'message',
        'entityId': 'e1',
        'encryptedValue': wire,
      });
      // The Uint8List is the decoded bytes; the wire echoes the stored string,
      // which is the byte-exact guarantee FR-A9 needs.
      expect(event.encryptedValue, base64Decode(wire));
      expect(event.toJson()['encryptedValue'], wire);
    });

    test('byte-deep equality: distinct Uint8List instances, same bytes', () {
      final a = ReasoningEncryptedValueEvent(
        entityId: 'e1',
        subtype: 'message',
        encryptedValue: Uint8List.fromList([1, 2, 3]),
        encryptedValueBase64: base64Encode(Uint8List.fromList([1, 2, 3])),
      );
      final b = ReasoningEncryptedValueEvent(
        entityId: 'e1',
        subtype: 'message',
        encryptedValue: Uint8List.fromList([1, 2, 3]),
        encryptedValueBase64: base64Encode(Uint8List.fromList([1, 2, 3])),
      );
      expect(identical(a.encryptedValue, b.encryptedValue), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('differing bytes → not equal', () {
      final a = ReasoningEncryptedValueEvent(
        entityId: 'e1',
        subtype: 'message',
        encryptedValue: Uint8List.fromList([1, 2, 3]),
        encryptedValueBase64: base64Encode(Uint8List.fromList([1, 2, 3])),
      );
      final c = ReasoningEncryptedValueEvent(
        entityId: 'e1',
        subtype: 'message',
        encryptedValue: Uint8List.fromList([1, 2, 4]),
        encryptedValueBase64: base64Encode(Uint8List.fromList([1, 2, 4])),
      );
      expect(a, isNot(equals(c)));
    });

    test('structural round-trip through the dispatcher', () {
      final event = ReasoningEncryptedValueEvent(
        entityId: 'e1',
        subtype: 'message',
        encryptedValue: sampleBytes,
        encryptedValueBase64: sampleB64,
      );
      expect(deserializeAgUiEvent(event.toJson()), equals(event));
    });

    test('bit-exact round-trip over 100 byte sequences (all padding cases + '
        'empty)', () {
      // Deterministic pseudo-random byte generator (no Math.random — keep the
      // test reproducible). Lengths sweep %3 ∈ {0,1,2} plus the empty blob.
      var seed = 0x2545F4914F6CDD1D;
      int nextByte() {
        seed = (seed * 6364136223846793005 + 1442695040888963407) & 0xFFFFFFFF;
        return (seed >> 16) & 0xFF;
      }

      for (var i = 0; i < 100; i++) {
        final length = i; // 0..99 covers every length % 3 and the empty case
        final bytes = Uint8List.fromList(
          List<int>.generate(length, (_) => nextByte()),
        );
        final b64 = base64Encode(bytes);

        // Build the event the way the wire does — through fromJson — so
        // `_decodeBase64` is the path actually under test for every padding
        // residue, not a direct construction that bypasses the decoder.
        final wireIn = {
          'type': 'REASONING_ENCRYPTED_VALUE',
          'subtype': i.isEven ? 'message' : 'tool-call',
          'entityId': 'e$i',
          'encryptedValue': b64,
        };
        final event = ReasoningEncryptedValueEvent.fromJson(wireIn);

        // fromJson decoded the wire string to the exact source bytes and kept
        // the string verbatim.
        expect(event.encryptedValue, bytes);
        expect(event.encryptedValueBase64, b64);

        final wireOut = event.toJson();
        // toJson echoes the preserved string …
        expect(wireOut['encryptedValue'], b64);
        // … which decodes back to the exact source bytes (byte-exact FR-A9).
        expect(base64Decode(wireOut['encryptedValue'] as String), bytes);

        // And the event re-dispatches to a structurally equal instance.
        expect(deserializeAgUiEvent(wireOut), equals(event));
      }
    });

    test('missing entityId throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ReasoningEncryptedValueEvent.fromJson({
          'type': 'REASONING_ENCRYPTED_VALUE',
          'subtype': 'message',
          'encryptedValue': sampleB64,
        }),
        _malformed,
      );
    });

    test('missing subtype throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ReasoningEncryptedValueEvent.fromJson({
          'type': 'REASONING_ENCRYPTED_VALUE',
          'entityId': 'e1',
          'encryptedValue': sampleB64,
        }),
        _malformed,
      );
    });

    test('missing encryptedValue throws ProtocolError(protocolMalformed)', () {
      expect(
        () => ReasoningEncryptedValueEvent.fromJson({
          'type': 'REASONING_ENCRYPTED_VALUE',
          'entityId': 'e1',
          'subtype': 'message',
        }),
        _malformed,
      );
    });

    test('non-base64 encryptedValue throws ProtocolError (no raw '
        'FormatException leaks)', () {
      expect(
        () => ReasoningEncryptedValueEvent.fromJson({
          'type': 'REASONING_ENCRYPTED_VALUE',
          'entityId': 'e1',
          'subtype': 'message',
          'encryptedValue': 'not valid base64!!!',
        }),
        _malformed,
      );
    });

    test(
      'non-String encryptedValue throws ProtocolError(protocolMalformed)',
      () {
        expect(
          () => ReasoningEncryptedValueEvent.fromJson({
            'type': 'REASONING_ENCRYPTED_VALUE',
            'entityId': 'e1',
            'subtype': 'message',
            'encryptedValue': 42,
          }),
          _malformed,
        );
      },
    );
  });
}
