import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:koel_core/src/agent/abstract_agent.dart';
import 'package:koel_core/src/agent/agent_subscriber.dart';
import 'package:koel_core/src/agent/interceptor.dart';
import 'package:koel_core/src/client/koel_client.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/input/run_agent_input.dart';
import 'package:koel_core/src/json_patch/json_patch_op.dart';
import 'package:koel_core/src/message/message.dart';
import 'package:koel_core/src/session/in_memory_session_storage.dart';
import 'package:koel_core/src/state/chat_state.dart';
import 'package:koel_core/src/state/chat_state_reducer.dart';
import 'package:koel_core/src/state/composed_reducer.dart';
import 'package:koel_core/src/state/tool_call.dart';
import 'package:test/test.dart';

// MockAgent (Story 3.1) does not exist yet — yield the canonical sweep from a
// private inline AbstractAgent double, the established koel_core pattern.
class _SweepAgent implements AbstractAgent {
  @override
  Stream<AgUiEvent> run(RunAgentInput input) async* {
    final bytes = Uint8List.fromList([1, 2, 3, 250]);
    yield RunStartedEvent(threadId: input.threadId, runId: input.runId);
    yield const TextMessageStartEvent(messageId: 'm1', role: 'assistant');
    yield const TextMessageContentEvent(messageId: 'm1', delta: 'Hello');
    yield const TextMessageContentEvent(messageId: 'm1', delta: ' world');
    yield const TextMessageEndEvent(messageId: 'm1');
    yield const ToolCallStartEvent(toolCallId: 'c1', toolCallName: 'search');
    yield const ToolCallArgsEvent(toolCallId: 'c1', delta: '{}');
    yield const ToolCallEndEvent(toolCallId: 'c1');
    yield const ToolCallResultEvent(
      messageId: 'mr',
      toolCallId: 'c1',
      content: 'ok',
    );
    yield const StateSnapshotEvent(state: {'count': 1});
    yield const StateDeltaEvent(patches: [ReplaceOp(path: '/count', value: 2)]);
    yield ReasoningEncryptedValueEvent(
      entityId: 'e',
      subtype: 'message',
      encryptedValue: bytes,
      encryptedValueBase64: base64Encode(bytes),
    );
    yield RunFinishedEvent(threadId: input.threadId, runId: input.runId);
  }
}

// Records every RunAgentInput it is run with (proves what goes out on the
// wire) and streams one short assistant answer per run.
class _RecordingInputAgent implements AbstractAgent {
  _RecordingInputAgent(this.inputs);

  final List<RunAgentInput> inputs;
  int _answerSeq = 0;

  @override
  Stream<AgUiEvent> run(RunAgentInput input) async* {
    inputs.add(input);
    final id = 'a${_answerSeq++}';
    yield RunStartedEvent(threadId: input.threadId, runId: input.runId);
    yield TextMessageStartEvent(messageId: id, role: 'assistant');
    yield TextMessageContentEvent(messageId: id, delta: 'answer $id');
    yield TextMessageEndEvent(messageId: id);
    yield RunFinishedEvent(threadId: input.threadId, runId: input.runId);
  }
}

// Awaits between yields so a cancel can land mid-run.
class _SlowAgent implements AbstractAgent {
  @override
  Stream<AgUiEvent> run(RunAgentInput input) async* {
    yield RunStartedEvent(threadId: input.threadId, runId: input.runId);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    yield const TextMessageStartEvent(messageId: 'm1', role: 'assistant');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    yield RunFinishedEvent(threadId: input.threadId, runId: input.runId);
  }
}

// A non-total reducer member — proves the apply-stage guard degrades instead of
// hanging (deferred-work #3).
class _ThrowingReducer implements ChatStateReducer {
  const _ThrowingReducer();

  @override
  ChatState reduce(ChatState state, AgUiEvent event) =>
      throw StateError('reducer boom');
}

class _RecordingSubscriber extends AgentSubscriber {
  final List<String> calls = [];

  @override
  void onRunStart(RunStartedEvent e) => calls.add('onRunStart');
  @override
  void onRunFinish(RunFinishedEvent e) => calls.add('onRunFinish');
  @override
  void onTextChunk(TextMessageContentEvent e) => calls.add('onTextChunk');
  @override
  void onToolCall(ToolCallStartEvent start, ToolCallEndEvent? end) =>
      calls.add('onToolCall');
  @override
  void onToolResult(ToolCallResultEvent e) => calls.add('onToolResult');
  @override
  void onStateDelta(StateDeltaEvent e) => calls.add('onStateDelta');
}

class _RecordingInterceptor implements Interceptor {
  _RecordingInterceptor(this.label, this.log);

  final String label;
  final List<String> log;

  @override
  Stream<AgUiEvent> intercept(
    InterceptorChain chain,
    RunAgentInput input,
  ) async* {
    log.add('$label enter');
    yield* chain.proceed(input);
    log.add('$label exit');
  }
}

void main() {
  group('ChatSession — AC3 happy path (28-family sweep)', () {
    test('the final ChatState equals the independent reducer fold', () async {
      final recorder = _RecordingSubscriber();
      final orderLog = <String>[];
      final client = KoelClient(
        agent: _SweepAgent(),
        subscribers: [recorder],
        interceptors: [
          _RecordingInterceptor('A', orderLog),
          _RecordingInterceptor('B', orderLog),
        ],
      );
      addTearDown(client.dispose);

      final session = client.newSession(threadId: 'sweep');
      final states = <ChatState>[];
      final events = <AgUiEvent>[];
      // Listen BEFORE send: a broadcast stream does not replay.
      final stateSub = session.stream.listen(states.add);
      final eventSub = session.events.listen(events.add);

      await session.send('hello');
      await pumpEventQueue();

      // The optimistic user echo is the apply stage's seed; folding the
      // post-pipeline events over it must reproduce the session's final state.
      const reducer = DefaultChatStateReducer();
      final expected = events.fold<ChatState>(states.first, reducer.reduce);
      expect(session.state, expected);
      expect(session.state, states.last);

      // The assistant message accumulated; the user echo is present; state and
      // reasoningEcho folded; phase resolved to idle.
      expect(
        session.state.messages.any(
          (m) => m.role == MessageRole.assistant && m.content == 'Hello world',
        ),
        isTrue,
      );
      expect(
        session.state.messages.any(
          (m) => m.role == MessageRole.user && m.content == 'hello',
        ),
        isTrue,
      );
      expect(session.state.state, {'count': 2});
      expect(session.state.reasoningEcho.keys, contains('e'));
      expect(session.state.phase, RunPhase.idle);

      // Subscribers fired on every dispatched event, in stream order.
      expect(recorder.calls.first, 'onRunStart');
      expect(recorder.calls.last, 'onRunFinish');
      expect(recorder.calls, contains('onTextChunk'));
      expect(recorder.calls, contains('onToolCall'));
      expect(recorder.calls, contains('onStateDelta'));

      // Interceptors executed in registered order (forward in, reverse out).
      expect(orderLog, ['A enter', 'B enter', 'B exit', 'A exit']);

      // An early listener saw the running sequence.
      expect(states.map((s) => s.phase), contains(RunPhase.running));

      await stateSub.cancel();
      await eventSub.cancel();
    });

    test('a late reader sees the final fold via the state snapshot', () async {
      final client = KoelClient(agent: _SweepAgent());
      addTearDown(client.dispose);

      final session = client.newSession(threadId: 'late');
      await session.send('hello');

      // No listener was attached during the run; the state snapshot still holds
      // the final fold.
      expect(session.state.phase, RunPhase.idle);
      expect(session.state.state, {'count': 2});
    });
  });

  group('ChatSession — AC3 cancel', () {
    test(
      'cancel flips phase to cancelled immediately and completes send',
      () async {
        final client = KoelClient(agent: _SlowAgent());
        addTearDown(client.dispose);

        final session = client.newSession(threadId: 'cancel');
        final future = session.send('hi');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        session.cancel();
        // Synchronous after the cancel call — no awaiting transport.
        expect(session.state.phase, RunPhase.cancelled);

        // The gating future still completes (does not hang).
        await future.timeout(const Duration(seconds: 1));
      },
    );
  });

  group('ChatSession — AC2 surface + lifecycle', () {
    test('threadId/state getters and broadcast events stream', () {
      final client = KoelClient(agent: _SweepAgent());
      addTearDown(client.dispose);

      final session = client.newSession(
        threadId: 'surface',
        initial: const ChatState(phase: RunPhase.idle),
      );
      expect(session.threadId, 'surface');
      expect(session.state, const ChatState());
      expect(session.events.isBroadcast, isTrue);
      expect(session.stream.isBroadcast, isTrue);
    });

    test('clear resets to idle and deletes the persisted copy', () async {
      final storage = InMemorySessionStorage();
      final client = KoelClient(agent: _SweepAgent(), sessionStorage: storage);
      addTearDown(client.dispose);

      final session = client.newSession(threadId: 'clearme');
      await session.send('hello');
      await session.persist();
      expect(await storage.load('clearme'), isNotNull);

      await session.clear();
      expect(session.state, const ChatState());
      expect(await storage.load('clearme'), isNull);
    });

    test(
      'persist then resume round-trips the state via explicit load',
      () async {
        final storage = InMemorySessionStorage();
        final client = KoelClient(
          agent: _SweepAgent(),
          sessionStorage: storage,
        );
        addTearDown(client.dispose);

        final session = client.newSession(threadId: 'round');
        await session.send('hello');
        final saved = session.state;
        await session.persist();

        // newSession is synchronous → no auto-load; resume is explicit.
        final loaded = await storage.load('round');
        final resumed = client.newSession(threadId: 'round', initial: loaded);
        expect(resumed.state, saved);
      },
    );

    test('persist is a no-op when no storage is configured', () async {
      final client = KoelClient(agent: _SweepAgent());
      addTearDown(client.dispose);

      final session = client.newSession(threadId: 'nostore');
      await session.send('hello');
      await expectLater(session.persist(), completes);
    });

    test('updateState shallow-merges the patch, preserving other keys', () {
      final client = KoelClient(agent: _SweepAgent());
      addTearDown(client.dispose);

      final session = client.newSession(
        threadId: 'updatestate',
        initial: const ChatState(
          state: {
            'language': 'vi',
            'mode': 'beginner',
            'insight': {'ticker': 'FPT'},
          },
        ),
      );

      session.updateState({'mode': 'professional'});

      // The patched key is replaced...
      expect(session.state.state['mode'], 'professional');
      // ...and the untouched keys survive (merge, not replace).
      expect(session.state.state['language'], 'vi');
      expect(session.state.state['insight'], {'ticker': 'FPT'});
    });

    test('updateState re-emits the merged state on the stream', () async {
      final client = KoelClient(agent: _SweepAgent());
      addTearDown(client.dispose);

      final session = client.newSession(
        threadId: 'updatestate-emit',
        initial: const ChatState(state: {'mode': 'beginner'}),
      );

      final next = session.stream.first;
      session.updateState({'mode': 'professional'});
      final emitted = await next;
      expect(emitted.state['mode'], 'professional');
    });

    test('dispose closes both controllers', () async {
      final client = KoelClient(agent: _SweepAgent());
      addTearDown(client.dispose);

      final session = client.newSession(threadId: 'disposeme');
      session.dispose();

      await expectLater(session.stream, emitsDone);
      await expectLater(session.events, emitsDone);
      // Idempotent.
      expect(session.dispose, returnsNormally);
    });
  });

  group('ChatSession — regenerate (CopilotKit reloadMessages parity)', () {
    test('truncates to the last user turn and re-runs WITHOUT appending a new '
        'user message — the old answer is replaced, not duplicated', () async {
      final inputs = <RunAgentInput>[];
      final client = KoelClient(agent: _RecordingInputAgent(inputs));
      addTearDown(client.dispose);

      final session = client.newSession(threadId: 'regen');
      await session.send('hello');
      final userMsg = session.state.messages.firstWhere(
        (m) => m.role == MessageRole.user,
      );
      // One question, one committed answer.
      expect(session.state.messages, hasLength(2));

      await session.regenerate();

      // Still exactly one user turn (same message, same id — CopilotKit
      // keeps ids so server-side history merges dedupe) and exactly one
      // assistant answer — the regenerated one, not a second pair.
      final users = session.state.messages
          .where((m) => m.role == MessageRole.user)
          .toList();
      final assistants = session.state.messages
          .where((m) => m.role == MessageRole.assistant)
          .toList();
      expect(users, hasLength(1));
      expect(users.single.id, userMsg.id);
      expect(users.single.content, 'hello');
      expect(assistants, hasLength(1));
      expect(session.state.phase, RunPhase.idle);

      // The regenerate run went out over the TRUNCATED history: it ends at
      // the user message, with no assistant turn after it and no new user
      // message appended.
      expect(inputs, hasLength(2));
      final regenInput = inputs.last;
      expect(regenInput.messages.last.id, userMsg.id);
      expect(
        regenInput.messages.where((m) => m.role == MessageRole.user),
        hasLength(1),
      );
      expect(
        regenInput.messages.where((m) => m.role == MessageRole.assistant),
        isEmpty,
      );
      // A fresh run id (not a replay of the send's run).
      expect(regenInput.runId, isNot(inputs.first.runId));
    });

    test('only the turns AFTER the last user message are dropped', () async {
      final inputs = <RunAgentInput>[];
      final client = KoelClient(agent: _RecordingInputAgent(inputs));
      addTearDown(client.dispose);

      final session = client.newSession(threadId: 'regen-multi');
      await session.send('first');
      await session.send('second');
      expect(session.state.messages, hasLength(4)); // u,a,u,a

      await session.regenerate();

      // The first turn pair is untouched; only the second answer regenerated.
      final contents = session.state.messages.map((m) => m.content).toList();
      expect(contents[0], 'first');
      expect(contents[2], 'second');
      expect(session.state.messages, hasLength(4));
      expect(inputs.last.messages.map((m) => m.content), [
        'first',
        contents[1],
        'second',
      ]);
    });

    test('clears leftover pendingMessage and pendingToolCalls from a '
        'cancelled run', () async {
      final client = KoelClient(agent: _SlowAgent());
      addTearDown(client.dispose);

      final session = client.newSession(
        threadId: 'regen-pending',
        initial: ChatState(
          messages: [
            Message(
              id: 'u1',
              role: MessageRole.user,
              content: 'hi',
              timestamp: DateTime(2026),
            ),
          ],
          pendingMessage: Message(
            id: 'a-half',
            role: MessageRole.assistant,
            content: 'half an ans',
            timestamp: DateTime(2026),
          ),
          pendingToolCalls: const [ToolCall(id: 'c-half', name: 'search')],
          phase: RunPhase.cancelled,
        ),
      );

      final future = session.regenerate();
      // The truncation emit replaced the transcript — the stale half-answer
      // and half-open tool call are gone before the new run streams
      // (setMessages semantics).
      expect(session.state.pendingMessage, isNull);
      expect(session.state.pendingToolCalls, isEmpty);
      expect(session.state.phase, RunPhase.running);
      await future;
    });

    test('is a no-op when the transcript has no user message', () async {
      final client = KoelClient(agent: _SweepAgent());
      addTearDown(client.dispose);

      final session = client.newSession(threadId: 'regen-empty');
      final states = <ChatState>[];
      final sub = session.stream.listen(states.add);

      await session.regenerate();
      await pumpEventQueue();

      // No run, no emit — nothing to regenerate from.
      expect(states, isEmpty);
      expect(session.state.messages, isEmpty);
      expect(session.state.phase, RunPhase.idle);
      await sub.cancel();
    });

    test(
      'cancel during a regenerate run completes the gating future',
      () async {
        final client = KoelClient(agent: _SlowAgent());
        addTearDown(client.dispose);

        final session = client.newSession(
          threadId: 'regen-cancel',
          initial: ChatState(
            messages: [
              Message(
                id: 'u1',
                role: MessageRole.user,
                content: 'hi',
                timestamp: DateTime(2026),
              ),
            ],
          ),
        );

        final future = session.regenerate();
        await Future<void>.delayed(const Duration(milliseconds: 10));
        session.cancel();

        expect(session.state.phase, RunPhase.cancelled);
        await future.timeout(const Duration(seconds: 1));
      },
    );
  });

  group('ChatSession — reducer-throw resilience (deferred #3)', () {
    test(
      'a non-total reducer degrades to ChatState.error without hanging',
      () async {
        final client = KoelClient(
          agent: _SweepAgent(),
          reducer: const ComposedReducer([
            DefaultChatStateReducer(),
            _ThrowingReducer(),
          ]),
        );
        addTearDown(client.dispose);

        final session = client.newSession(threadId: 'throwing');

        // Completes (no hang) — the throw is caught in-band, not escaped.
        await session.send('hello').timeout(const Duration(seconds: 1));

        expect(session.state.error, isNotNull);
        expect(session.state.phase, RunPhase.error);
      },
    );
  });
}
