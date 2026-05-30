import 'dart:typed_data';

import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/json_patch/json_patch_op.dart';
import 'package:koel_core/src/message/message.dart';
import 'package:koel_core/src/state/chat_state.dart';
import 'package:koel_core/src/state/chat_state_reducer.dart';
import 'package:koel_core/src/state/composed_reducer.dart';
import 'package:koel_core/src/state/tool_call.dart';
import 'package:test/test.dart';

void main() {
  const reducer = DefaultChatStateReducer();
  final ts = DateTime.utc(2026, 5, 29, 12);
  final epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

  Message msg(String id) =>
      Message(id: id, role: MessageRole.user, content: 'c', timestamp: ts);

  group('run / step lifecycle → phase', () {
    test('RUN_STARTED → running and clears transients + error', () {
      final s = ChatState(
        messages: [msg('m1')],
        pendingMessage: msg('m2'),
        pendingToolCalls: const [ToolCall(id: 't', name: 'n')],
        error: const AgentError(message: 'old', code: KoelErrorCode.unknown),
        phase: RunPhase.error,
      );
      final r = reducer.reduce(
        s,
        const RunStartedEvent(threadId: 't', runId: 'r'),
      );
      expect(r.phase, RunPhase.running);
      expect(r.error, isNull);
      expect(r.pendingMessage, isNull);
      expect(r.pendingToolCalls, isEmpty);
      expect(r.messages, equals(s.messages)); // history persists
    });

    test('RUN_FINISHED → idle', () {
      final r = reducer.reduce(
        const ChatState(phase: RunPhase.running),
        const RunFinishedEvent(threadId: 't', runId: 'r'),
      );
      expect(r.phase, RunPhase.idle);
    });

    test('RUN_ERROR → error field + phase error', () {
      const err = AgentError(message: 'boom', code: KoelErrorCode.unknown);
      final r = reducer.reduce(
        const ChatState(),
        const RunErrorEvent(error: err),
      );
      expect(r.error, err);
      expect(r.phase, RunPhase.error);
    });

    test('STEP_STARTED → stepRunning, STEP_FINISHED → running', () {
      final started = reducer.reduce(
        const ChatState(phase: RunPhase.running),
        const StepStartedEvent(stepName: 's'),
      );
      expect(started.phase, RunPhase.stepRunning);
      final finished = reducer.reduce(
        started,
        const StepFinishedEvent(stepName: 's'),
      );
      expect(finished.phase, RunPhase.running);
    });
  });

  group('streamed text message → pendingMessage', () {
    test(
      'START synthesizes a pendingMessage with the epoch sentinel timestamp',
      () {
        final r = reducer.reduce(
          const ChatState(),
          const TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
        );
        expect(
          r.pendingMessage,
          Message(
            id: 'm1',
            role: MessageRole.assistant,
            content: '',
            timestamp: epoch,
          ),
        );
      },
    );

    test(
      'START maps every wire role onto MessageRole (unknown → assistant)',
      () {
        MessageRole roleOf(String wire) => reducer
            .reduce(
              const ChatState(),
              TextMessageStartEvent(messageId: 'm1', role: wire),
            )
            .pendingMessage!
            .role;
        expect(roleOf('user'), MessageRole.user);
        expect(roleOf('assistant'), MessageRole.assistant);
        expect(roleOf('system'), MessageRole.system);
        expect(roleOf('tool'), MessageRole.tool);
        expect(
          roleOf('developer'),
          MessageRole.assistant,
        ); // unrecognized → default
      },
    );

    test('CONTENT concatenates deltas in order', () {
      var s = reducer.reduce(
        const ChatState(),
        const TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
      );
      s = reducer.reduce(
        s,
        const TextMessageContentEvent(messageId: 'm1', delta: 'Hel'),
      );
      s = reducer.reduce(
        s,
        const TextMessageContentEvent(messageId: 'm1', delta: 'lo'),
      );
      expect(s.pendingMessage!.content, 'Hello');
    });

    test('CONTENT with no open pendingMessage is a no-op', () {
      final s = const ChatState();
      final r = reducer.reduce(
        s,
        const TextMessageContentEvent(messageId: 'm1', delta: 'x'),
      );
      expect(identical(r, s), isTrue);
    });

    test('END commits pendingMessage into messages and clears it', () {
      final pending = Message(
        id: 'm1',
        role: MessageRole.assistant,
        content: 'done',
        timestamp: epoch,
      );
      final s = ChatState(messages: [msg('m0')], pendingMessage: pending);
      final r = reducer.reduce(s, const TextMessageEndEvent(messageId: 'm1'));
      expect(r.messages, [msg('m0'), pending]);
      expect(r.pendingMessage, isNull);
    });

    test('END with no open pendingMessage is a no-op', () {
      final s = const ChatState();
      final r = reducer.reduce(s, const TextMessageEndEvent(messageId: 'm1'));
      expect(identical(r, s), isTrue);
    });
  });

  group('tool calls → pendingToolCalls lifecycle', () {
    test('START appends a pending ToolCall', () {
      final r = reducer.reduce(
        const ChatState(),
        const ToolCallStartEvent(
          toolCallId: 'tc1',
          toolCallName: 'search',
          parentMessageId: 'm1',
        ),
      );
      expect(r.pendingToolCalls, [
        const ToolCall(id: 'tc1', name: 'search', parentMessageId: 'm1'),
      ]);
    });

    test('ARGS appends deltas to the matching open call', () {
      var s = reducer.reduce(
        const ChatState(),
        const ToolCallStartEvent(toolCallId: 'tc1', toolCallName: 'search'),
      );
      s = reducer.reduce(
        s,
        const ToolCallArgsEvent(toolCallId: 'tc1', delta: '{"q":'),
      );
      s = reducer.reduce(
        s,
        const ToolCallArgsEvent(toolCallId: 'tc1', delta: '"x"}'),
      );
      expect(s.pendingToolCalls.single.arguments, '{"q":"x"}');
    });

    test('ARGS with no matching call is a no-op', () {
      final s = const ChatState();
      final r = reducer.reduce(
        s,
        const ToolCallArgsEvent(toolCallId: 'nope', delta: 'x'),
      );
      expect(identical(r, s), isTrue);
    });

    test('END leaves pendingToolCalls membership unchanged', () {
      final s = ChatState(
        pendingToolCalls: const [ToolCall(id: 'tc1', name: 'search')],
      );
      final r = reducer.reduce(s, const ToolCallEndEvent(toolCallId: 'tc1'));
      expect(identical(r, s), isTrue);
      expect(r.pendingToolCalls, s.pendingToolCalls);
    });

    test('RESULT removes the resolved call', () {
      final s = ChatState(
        pendingToolCalls: const [
          ToolCall(id: 'tc1', name: 'a'),
          ToolCall(id: 'tc2', name: 'b'),
        ],
      );
      final r = reducer.reduce(
        s,
        const ToolCallResultEvent(
          messageId: 'm1',
          toolCallId: 'tc1',
          content: 'ok',
        ),
      );
      expect(r.pendingToolCalls, [const ToolCall(id: 'tc2', name: 'b')]);
    });

    test('RESULT with no matching call is a no-op', () {
      final s = ChatState(
        pendingToolCalls: const [ToolCall(id: 'tc1', name: 'a')],
      );
      final r = reducer.reduce(
        s,
        const ToolCallResultEvent(
          messageId: 'm1',
          toolCallId: 'nope',
          content: 'ok',
        ),
      );
      expect(identical(r, s), isTrue);
    });
  });

  group('shared agent state', () {
    test('STATE_SNAPSHOT replaces state wholesale', () {
      final s = const ChatState(state: {'old': 1});
      final r = reducer.reduce(s, const StateSnapshotEvent(state: {'new': 2}));
      expect(r.state, {'new': 2});
    });

    test('STATE_DELTA applies a valid patch', () {
      final s = const ChatState(state: {'count': 1});
      final r = reducer.reduce(
        s,
        const StateDeltaEvent(patches: [ReplaceOp(path: '/count', value: 5)]),
      );
      expect(r.state, {'count': 5});
      expect(r.error, isNull);
    });

    test(
      'STATE_DELTA folds an inapplicable patch into error + phase error',
      () {
        final s = const ChatState(state: {'count': 1}, phase: RunPhase.running);
        final r = reducer.reduce(
          s,
          const StateDeltaEvent(patches: [RemoveOp(path: '/missing')]),
        );
        expect(r.error, isA<ProtocolError>());
        expect(r.error!.code, KoelErrorCode.protocolMalformed);
        expect(r.phase, RunPhase.error);
        expect(r.state, {'count': 1}); // unchanged — JsonPatch.apply is atomic
      },
    );

    test(
      'STATE_DELTA root-replace to a non-object folds to error, never throws',
      () {
        // RFC 6902 lets `path: ""` replace the whole document with any JSON
        // value, so JsonPatch.apply can return a non-Map. The reducer must stay
        // total — fold to error, not let the cast throw escape.
        final s = const ChatState(state: {'count': 1}, phase: RunPhase.running);
        final r = reducer.reduce(
          s,
          const StateDeltaEvent(
            patches: [
              ReplaceOp(path: '', value: [1, 2]),
            ],
          ),
        );
        expect(r.error, isA<ProtocolError>());
        expect(r.error!.code, KoelErrorCode.protocolMalformed);
        expect(r.phase, RunPhase.error);
        expect(r.state, {'count': 1}); // unchanged
      },
    );

    test('MESSAGES_SNAPSHOT replaces messages and clears pendingMessage', () {
      final s = ChatState(
        messages: [msg('old')],
        pendingMessage: msg('streaming'),
      );
      final snapshot = [msg('a'), msg('b')];
      final r = reducer.reduce(s, MessagesSnapshotEvent(messages: snapshot));
      expect(r.messages, snapshot);
      expect(r.pendingMessage, isNull);
    });
  });

  group('reasoning echo', () {
    test(
      'REASONING_ENCRYPTED_VALUE accumulates the blob keyed by entityId',
      () {
        final s = ChatState(
          reasoningEcho: {
            'e1': Uint8List.fromList([1]),
          },
        );
        final r = reducer.reduce(
          s,
          ReasoningEncryptedValueEvent(
            entityId: 'e2',
            subtype: 'message',
            encryptedValue: Uint8List.fromList([2, 3]),
            encryptedValueBase64: 'AgM=',
          ),
        );
        expect(r.reasoningEcho.keys, ['e1', 'e2']);
        expect(r.reasoningEcho['e2'], Uint8List.fromList([2, 3]));
      },
    );
  });

  group('default-arm no-op families', () {
    final noops = <String, AgUiEvent>{
      'RAW': const RawEvent(payload: {'a': 1}),
      'CUSTOM': const CustomEvent(name: 'x', value: 1),
      'ACTIVITY_SNAPSHOT': const ActivitySnapshotEvent(
        messageId: 'm',
        activityType: 'a',
        content: {},
      ),
      'REASONING_START': const ReasoningStartEvent(messageId: 'm'),
      'REASONING_MESSAGE_CHUNK': const ReasoningMessageChunkEvent(),
      'TEXT_MESSAGE_CHUNK': const TextMessageChunkEvent(),
      'UNKNOWN': const UnknownAgUiEvent(type: 'Z', rawJson: {'type': 'Z'}),
    };
    noops.forEach((name, event) {
      test('$name returns the same state instance', () {
        final s = ChatState(messages: [msg('m1')], phase: RunPhase.running);
        expect(identical(reducer.reduce(s, event), s), isTrue);
      });
    });
  });

  group('ComposedReducer', () {
    test('folds left-to-right — the last reducer wins on a shared field', () {
      const composed = ComposedReducer([
        _PhaseSetter(RunPhase.running),
        _PhaseSetter(RunPhase.cancelled),
      ]);
      final r = composed.reduce(
        const ChatState(),
        const RunFinishedEvent(threadId: 't', runId: 'r'),
      );
      expect(r.phase, RunPhase.cancelled);
    });

    test('order matters — reversing flips the outcome', () {
      const composed = ComposedReducer([
        _PhaseSetter(RunPhase.cancelled),
        _PhaseSetter(RunPhase.running),
      ]);
      final r = composed.reduce(
        const ChatState(),
        const RunFinishedEvent(threadId: 't', runId: 'r'),
      );
      expect(r.phase, RunPhase.running);
    });

    test('an empty reducer list is the identity', () {
      const composed = ComposedReducer([]);
      final s = ChatState(messages: [msg('m1')]);
      expect(
        identical(
          composed.reduce(s, const RunFinishedEvent(threadId: 't', runId: 'r')),
          s,
        ),
        isTrue,
      );
    });

    test('wrapping the default reducer matches calling it directly', () {
      const composed = ComposedReducer([DefaultChatStateReducer()]);
      const event = StateSnapshotEvent(state: {'k': 1});
      expect(
        composed.reduce(const ChatState(), event),
        equals(reducer.reduce(const ChatState(), event)),
      );
    });
  });

  group('ChatState value semantics', () {
    test('equal field values are == with the same hashCode', () {
      final a = ChatState(messages: [msg('m1')], state: const {'k': 1});
      final b = ChatState(messages: [msg('m1')], state: const {'k': 1});
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('copyWith updates one field and leaves others intact', () {
      final s = ChatState(messages: [msg('m1')], phase: RunPhase.idle);
      final updated = s.copyWith(phase: RunPhase.running);
      expect(updated.phase, RunPhase.running);
      expect(updated.messages, s.messages);
    });

    test('defaults are empty collections, null transients, idle phase', () {
      const s = ChatState();
      expect(s.messages, isEmpty);
      expect(s.pendingMessage, isNull);
      expect(s.pendingToolCalls, isEmpty);
      expect(s.state, isEmpty);
      expect(s.reasoningEcho, isEmpty);
      expect(s.error, isNull);
      expect(s.phase, RunPhase.idle);
    });
  });
}

/// A trivial reducer that overwrites [ChatState.phase] — used to prove
/// `ComposedReducer` order semantics.
class _PhaseSetter implements ChatStateReducer {
  const _PhaseSetter(this.phase);

  final RunPhase phase;

  @override
  ChatState reduce(ChatState state, AgUiEvent event) =>
      state.copyWith(phase: phase);
}
