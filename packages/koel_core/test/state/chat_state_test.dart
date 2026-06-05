import 'dart:typed_data';

import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/message/message.dart';
import 'package:koel_core/src/state/chat_state.dart';
import 'package:koel_core/src/state/tool_call.dart';
import 'package:test/test.dart';

/// A representative non-empty [ChatState] — one committed turn, one in-flight
/// pending turn, one pending tool call, a non-empty shared `state` map, and a
/// non-empty `reasoningEcho` blob.
ChatState _populated({RunPhase phase = RunPhase.running}) => ChatState(
  messages: [
    Message(
      id: 'u1',
      role: MessageRole.user,
      content: 'hi',
      timestamp: DateTime.utc(2026, 6, 5, 10, 30),
    ),
  ],
  pendingMessage: Message(
    id: 'a1',
    role: MessageRole.assistant,
    content: 'half-written',
    timestamp: DateTime.utc(2026, 6, 5, 10, 31),
  ),
  pendingToolCalls: const [
    ToolCall(id: 't1', name: 'lookup', arguments: '{"q":'),
  ],
  state: const {
    'counter': 3,
    'nested': {'a': true},
  },
  reasoningEcho: {
    'e1': Uint8List.fromList([0, 127, 255, 42]),
  },
  phase: phase,
);

void main() {
  group('ChatState JSON codec', () {
    test('empty state round-trips structurally equal (AC1)', () {
      const s = ChatState();
      expect(ChatState.fromJson(s.toJson()), equals(s));
    });

    test('fully-populated state round-trips structurally equal (AC1)', () {
      final s = _populated();
      expect(ChatState.fromJson(s.toJson()), equals(s));
    });

    test('every RunPhase value survives the round-trip (AC1)', () {
      for (final phase in RunPhase.values) {
        final s = _populated(phase: phase);
        expect(
          ChatState.fromJson(s.toJson()),
          equals(s),
          reason:
              'a populated state at phase $phase must round-trip '
              'structurally equal',
        );
      }
    });

    test('reasoningEcho bytes survive base64 round-trip byte-for-byte '
        '(AC2, D3)', () {
      final bytes = Uint8List.fromList([0, 1, 2, 250, 251, 255]);
      final s = ChatState(reasoningEcho: {'blob': bytes});
      final reloaded = ChatState.fromJson(s.toJson());
      expect(reloaded.reasoningEcho['blob'], equals(bytes));
      expect(reloaded, equals(s));
    });

    test('error is excluded from the codec — reloads as null with other '
        'fields intact (AC2, D2)', () {
      final s = _populated(phase: RunPhase.error).copyWith(
        error: const TransportError(
          message: 'connection refused',
          code: KoelErrorCode.transportRefused,
          cause: Object(), // deliberately non-serializable
        ),
      );
      expect(s.error, isNotNull);

      final reloaded = ChatState.fromJson(s.toJson());
      expect(reloaded.error, isNull);
      // phase persists (it is serialized) even though error does not.
      expect(reloaded.phase, equals(RunPhase.error));
      // Every other field is intact: the error-stripped reload equals the
      // error-stripped original.
      expect(reloaded, equals(s.copyWith(error: null)));
    });
  });
}
