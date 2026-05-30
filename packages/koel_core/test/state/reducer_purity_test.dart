import 'dart:typed_data';

import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/message/message.dart';
import 'package:koel_core/src/state/chat_state.dart';
import 'package:koel_core/src/state/chat_state_reducer.dart';
import 'package:koel_core/src/state/tool_call.dart';
import 'package:test/test.dart';

void main() {
  const reducer = DefaultChatStateReducer();
  final ts = DateTime.utc(2026, 5, 29, 12);

  // A non-trivial seed: populated messages, nested state map, and a byte blob.
  ChatState seed() => ChatState(
    messages: [
      Message(id: 'm1', role: MessageRole.user, content: 'hi', timestamp: ts),
    ],
    state: {
      'count': 1,
      'nested': {'k': 'v'},
    },
    reasoningEcho: {
      'e1': Uint8List.fromList([1, 2, 3]),
    },
  );

  group('no-mutation', () {
    test('a mutating event leaves the input collections untouched', () {
      // Seed with an in-flight message so TEXT_MESSAGE_END commits it.
      final pending = Message(
        id: 'm2',
        role: MessageRole.assistant,
        content: 'streamed',
        timestamp: ts,
      );
      final s = seed().copyWith(pendingMessage: pending);
      final msgsBefore = List.of(s.messages);
      final stateBefore = Map.of(s.state);
      final echoBefore = Map.of(s.reasoningEcho);

      final result = reducer.reduce(
        s,
        const TextMessageEndEvent(messageId: 'm2'),
      );

      // The input the caller still holds was not mutated underneath them.
      expect(s.messages, equals(msgsBefore));
      expect(s.state, equals(stateBefore));
      expect(s.reasoningEcho, equals(echoBefore));
      // The result is a *fresh* messages list (commit happened).
      expect(result.messages.length, s.messages.length + 1);
      expect(identical(result.messages, s.messages), isFalse);
    });

    test(
      'REASONING_ENCRYPTED_VALUE rebuilds reasoningEcho, leaving input intact',
      () {
        final s = seed();
        final echoBefore = Map.of(s.reasoningEcho);

        final result = reducer.reduce(
          s,
          ReasoningEncryptedValueEvent(
            entityId: 'e2',
            subtype: 'message',
            encryptedValue: Uint8List.fromList([9, 9]),
            encryptedValueBase64: 'CQk=',
          ),
        );

        expect(s.reasoningEcho, equals(echoBefore));
        expect(result.reasoningEcho.keys, containsAll(['e1', 'e2']));
        expect(identical(result.reasoningEcho, s.reasoningEcho), isFalse);
      },
    );

    test('STATE_SNAPSHOT replaces state without mutating the input map', () {
      final s = seed();
      final stateBefore = Map.of(s.state);

      final result = reducer.reduce(
        s,
        const StateSnapshotEvent(state: {'count': 99}),
      );

      expect(s.state, equals(stateBefore));
      expect(result.state, equals({'count': 99}));
      expect(identical(result.state, s.state), isFalse);
    });

    test('the seed state is fully immutable — the reducer cannot mutate it', () {
      // freezed wraps every collection in an EqualUnmodifiable*View, so the
      // input the reducer holds rejects in-place mutation. This is the
      // structural guard against a future `state.messages.add(...)` regression
      // (AC3's "fully-immutable" path), independent of any copy semantics.
      final s = seed();
      expect(() => s.messages.add(s.messages.first), throwsUnsupportedError);
      expect(
        () => s.pendingToolCalls.add(const ToolCall(id: 'x', name: 'y')),
        throwsUnsupportedError,
      );
      expect(() => s.state['k'] = 0, throwsUnsupportedError);
      expect(() => s.reasoningEcho['k'] = Uint8List(0), throwsUnsupportedError);
    });

    test('a non-mutating event carries collections forward unchanged', () {
      final s = seed();
      // RUN_FINISHED only flips phase; messages/state/reasoningEcho carry over.
      final result = reducer.reduce(
        s,
        const RunFinishedEvent(threadId: 't', runId: 'r'),
      );

      expect(result.phase, RunPhase.idle);
      expect(result.messages, equals(s.messages));
      expect(result.state, equals(s.state));
      expect(result.reasoningEcho, equals(s.reasoningEcho));
    });

    test(
      'a default-arm no-op returns a state structurally equal to the input',
      () {
        final s = seed();
        final result = reducer.reduce(
          s,
          const UnknownAgUiEvent(
            type: 'FUTURE_EVENT',
            rawJson: {'type': 'FUTURE_EVENT'},
          ),
        );
        expect(result, equals(s));
      },
    );
  });

  group('idempotence (idempotent events only)', () {
    final cases = <String, AgUiEvent>{
      'STATE_SNAPSHOT': const StateSnapshotEvent(state: {'x': 1}),
      'MESSAGES_SNAPSHOT': MessagesSnapshotEvent(
        messages: [
          Message(
            id: 's1',
            role: MessageRole.assistant,
            content: 'done',
            timestamp: ts,
          ),
        ],
      ),
      'RUN_ERROR': const RunErrorEvent(
        error: AgentError(message: 'boom', code: KoelErrorCode.unknown),
      ),
      'REASONING_ENCRYPTED_VALUE (same blob)': ReasoningEncryptedValueEvent(
        entityId: 'e9',
        subtype: 'message',
        encryptedValue: Uint8List.fromList([7]),
        encryptedValueBase64: 'Bw==',
      ),
    };

    cases.forEach((name, event) {
      test('$name is idempotent: reduce(reduce(s,e),e) == reduce(s,e)', () {
        final s = seed();
        final once = reducer.reduce(s, event);
        final twice = reducer.reduce(once, event);
        expect(twice, equals(once));
      });
    });
  });

  group('determinism', () {
    test(
      'TEXT_MESSAGE_START synthesis is deterministic (no DateTime.now leak)',
      () {
        final s = seed();
        const event = TextMessageStartEvent(messageId: 'm9', role: 'assistant');
        final a = reducer.reduce(s, event);
        final b = reducer.reduce(s, event);
        expect(a, equals(b));
        // The synthesized timestamp is the epoch sentinel, not wall-clock.
        expect(
          a.pendingMessage!.timestamp,
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
      },
    );

    test(
      'an accumulating event reduces equally across two independent calls',
      () {
        final pending = Message(
          id: 'm2',
          role: MessageRole.assistant,
          content: 'a',
          timestamp: ts,
        );
        final s = seed().copyWith(pendingMessage: pending);
        const event = TextMessageContentEvent(messageId: 'm2', delta: 'b');
        expect(reducer.reduce(s, event), equals(reducer.reduce(s, event)));
      },
    );
  });
}
