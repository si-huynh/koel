import 'dart:async';

import 'package:koel_core/src/agent/abstract_agent.dart';
import 'package:koel_core/src/agent/agent_subscriber.dart';
import 'package:koel_core/src/agent/interceptor.dart';
import 'package:koel_core/src/client/koel_client.dart';
import 'package:koel_core/src/error/error_classifier.dart';
import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/input/run_agent_input.dart';
import 'package:koel_core/src/json_patch/json_patch_op.dart';
import 'package:koel_core/src/session/in_memory_session_storage.dart';
import 'package:koel_core/src/state/chat_state_reducer.dart';
import 'package:koel_core/src/state/state_conflict.dart';
import 'package:test/test.dart';

// MockAgent (Story 3.1) does not exist yet — the terminal agent is a private
// inline double, the established koel_core pattern (interceptor_test.dart).
class _FixtureAgent implements AbstractAgent {
  _FixtureAgent(this._events, {this.throwAfterEmit});

  final List<AgUiEvent> _events;
  final Object? throwAfterEmit;

  @override
  Stream<AgUiEvent> run(RunAgentInput input) async* {
    for (final event in _events) {
      yield event;
    }
    final toThrow = throwAfterEmit;
    if (toThrow != null) throw toThrow;
  }
}

// Counts every callback it receives across the curated subset.
class _RecordingSubscriber extends AgentSubscriber {
  final List<String> calls = [];
  final List<String> runStartThreads = [];

  @override
  void onRunStart(RunStartedEvent e) {
    calls.add('onRunStart');
    runStartThreads.add(e.threadId);
  }

  @override
  void onRunFinish(RunFinishedEvent e) => calls.add('onRunFinish');
  @override
  void onTextChunk(TextMessageContentEvent e) => calls.add('onTextChunk');
  @override
  void onToolCall(ToolCallStartEvent start, ToolCallEndEvent? end) =>
      calls.add('onToolCall');
  @override
  void onRunError(RunErrorEvent e) => calls.add('onRunError');
}

class _ThrowingSubscriber extends AgentSubscriber {
  @override
  void onRunStart(RunStartedEvent e) => throw StateError('subscriber boom');
}

// Records the name of every callback it receives — asserts the production
// event→callback routing map (the verbatim port of the 2.10 dispatcher).
class _AllRecordingSubscriber extends AgentSubscriber {
  final List<String> calls = [];

  @override
  void onRunStart(RunStartedEvent e) => calls.add('onRunStart');
  @override
  void onRunFinish(RunFinishedEvent e) => calls.add('onRunFinish');
  @override
  void onRunError(RunErrorEvent e) => calls.add('onRunError');
  @override
  void onStepStart(StepStartedEvent e) => calls.add('onStepStart');
  @override
  void onStepFinish(StepFinishedEvent e) => calls.add('onStepFinish');
  @override
  void onTextChunk(TextMessageContentEvent e) => calls.add('onTextChunk');
  @override
  void onToolCall(ToolCallStartEvent start, ToolCallEndEvent? end) =>
      calls.add('onToolCall');
  @override
  void onToolResult(ToolCallResultEvent e) => calls.add('onToolResult');
  @override
  void onStateDelta(StateDeltaEvent e) => calls.add('onStateDelta');
  @override
  void onReasoning(AgUiEvent e) => calls.add('onReasoning');
  @override
  void onActivity(AgUiEvent e) => calls.add('onActivity');
  @override
  void onUnknownEvent(UnknownAgUiEvent e) => calls.add('onUnknownEvent');
}

// A classifier that throws on every call — proves _SafeClassifier degrades it.
class _ThrowingClassifier implements ErrorClassifier {
  const _ThrowingClassifier();

  @override
  KoelError classify(Object raw, StackTrace? stack, RunAgentInput input) =>
      throw ArgumentError('classifier boom');
}

// Logs enter/exit around delegation — proves registered interceptor order.
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

const _input = RunAgentInput(threadId: 't1', runId: 'r1');

void main() {
  group('KoelClient — constructor (AC1)', () {
    test('a bare client wires the SDK defaults', () {
      final client = KoelClient(agent: _FixtureAgent(const []));
      addTearDown(client.dispose);

      expect(client.devtoolsBufferSize, 1000);
      expect(client.backpressure, BackpressurePolicy.pauseUpstream);
      expect(client.stateConflictResolver, isA<LastWriterWinsResolver>());
      expect(client.subscribers, isEmpty);
    });

    test('accepts every named param in the AC1 order', () {
      final client = KoelClient(
        agent: _FixtureAgent(const []),
        sessionStorage: InMemorySessionStorage(),
        reducer: const DefaultChatStateReducer(),
        interceptors: const [],
        subscribers: [_RecordingSubscriber()],
        errorClassifier: const DefaultErrorClassifier(),
        stateConflictResolver: const LastWriterWinsResolver(),
        devtoolsBufferSize: 500,
        backpressure: BackpressurePolicy.dropOldest,
      );
      addTearDown(client.dispose);

      expect(client.devtoolsBufferSize, 500);
      expect(client.backpressure, BackpressurePolicy.dropOldest);
      expect(client.subscribers, hasLength(1));
    });

    test('subscribers is a mutable list seeded from the ctor', () {
      final client = KoelClient(agent: _FixtureAgent(const []));
      addTearDown(client.dispose);

      final sub = _RecordingSubscriber();
      client.subscribers.add(sub);
      expect(client.subscribers, [sub]);
    });
  });

  group('KoelClient.runRaw (AC1 layer 3)', () {
    test(
      'emits the post-pipeline stream and fires subscribers per event',
      () async {
        final recorder = _RecordingSubscriber();
        final client = KoelClient(
          agent: _FixtureAgent(const [
            RunStartedEvent(threadId: 't1', runId: 'r1'),
            TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
            TextMessageContentEvent(messageId: 'm1', delta: 'hi'),
            TextMessageEndEvent(messageId: 'm1'),
            RunFinishedEvent(threadId: 't1', runId: 'r1'),
          ]),
          subscribers: [recorder],
        );
        addTearDown(client.dispose);

        final out = await client.runRaw(_input).toList();

        // The raw post-pipeline AgUiEvent stream — no ChatState in sight.
        expect(out, isA<List<AgUiEvent>>());
        expect(out.first, isA<RunStartedEvent>());
        expect(out.last, isA<RunFinishedEvent>());
        // Subscribers fired for exactly the curated-subset events.
        expect(recorder.calls, ['onRunStart', 'onTextChunk', 'onRunFinish']);
      },
    );

    test('chunk shapes are synthesized into canonical events', () async {
      final client = KoelClient(
        agent: _FixtureAgent(const [
          ToolCallChunkEvent(
            toolCallId: 'a',
            toolCallName: 'search',
            delta: '{',
          ),
          ToolCallChunkEvent(toolCallId: 'a', delta: '}'),
        ]),
      );
      addTearDown(client.dispose);

      final out = await client.runRaw(_input).toList();

      expect(out.whereType<ToolCallChunkEvent>(), isEmpty);
      expect(out.whereType<ToolCallStartEvent>(), hasLength(1));
      expect(out.whereType<ToolCallEndEvent>(), hasLength(1));
    });

    test('interceptors execute in registered order', () async {
      final log = <String>[];
      final client = KoelClient(
        agent: _FixtureAgent(const [
          RunStartedEvent(threadId: 't1', runId: 'r1'),
          RunFinishedEvent(threadId: 't1', runId: 'r1'),
        ]),
        interceptors: [
          _RecordingInterceptor('A', log),
          _RecordingInterceptor('B', log),
        ],
      );
      addTearDown(client.dispose);

      await client.runRaw(_input).toList();

      expect(log, ['A enter', 'B enter', 'B exit', 'A exit']);
    });

    test(
      'dispatches the full curated routing map to subscriber callbacks',
      () async {
        final recorder = _AllRecordingSubscriber();
        final client = KoelClient(
          agent: _FixtureAgent([
            const RunStartedEvent(threadId: 't1', runId: 'r1'),
            const StepStartedEvent(stepName: 's'),
            const StepFinishedEvent(stepName: 's'),
            const TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
            const TextMessageContentEvent(messageId: 'm1', delta: 'hi'),
            const TextMessageEndEvent(messageId: 'm1'),
            const ToolCallStartEvent(toolCallId: 'c1', toolCallName: 'search'),
            const ToolCallArgsEvent(toolCallId: 'c1', delta: '{}'),
            const ToolCallEndEvent(toolCallId: 'c1'),
            const ToolCallResultEvent(
              messageId: 'mr',
              toolCallId: 'c1',
              content: 'ok',
            ),
            const StateSnapshotEvent(state: {'k': 1}),
            const StateDeltaEvent(patches: [ReplaceOp(path: '/k', value: 2)]),
            const ActivitySnapshotEvent(
              messageId: 'a',
              activityType: 'x',
              content: {},
            ),
            const ReasoningStartEvent(messageId: 'rs'),
            UnknownAgUiEvent(type: 'FUTURE', rawJson: const {}),
            const RunErrorEvent(
              error: AgentError(message: 'x', code: KoelErrorCode.unknown),
            ),
            const RunFinishedEvent(threadId: 't1', runId: 'r1'),
          ]),
          subscribers: [recorder],
        );
        addTearDown(client.dispose);

        await client.runRaw(_input).toList();

        // Every mapped callback fired; the curated-subset framing events did not.
        expect(recorder.calls, [
          'onRunStart',
          'onStepStart',
          'onStepFinish',
          'onTextChunk',
          'onToolCall',
          'onToolResult',
          'onStateDelta',
          'onActivity',
          'onReasoning',
          'onUnknownEvent',
          'onRunError',
          'onRunFinish',
        ]);
      },
    );

    test(
      'a throwing subscriber is isolated and does not break the stream',
      () async {
        final recorder = _RecordingSubscriber();
        final client = KoelClient(
          agent: _FixtureAgent(const [
            RunStartedEvent(threadId: 't1', runId: 'r1'),
            RunFinishedEvent(threadId: 't1', runId: 'r1'),
          ]),
          subscribers: [_ThrowingSubscriber(), recorder],
        );
        addTearDown(client.dispose);

        final caught = <Object>[];
        late List<AgUiEvent> out;
        await runZonedGuarded(() async {
          out = await client.runRaw(_input).toList();
        }, (error, stack) => caught.add(error));

        // The stream survived the throw; the later subscriber still fired.
        expect(out, hasLength(2));
        expect(recorder.calls, ['onRunStart', 'onRunFinish']);
        // The throw surfaced to the Zone — reported, not swallowed.
        expect(caught.whereType<StateError>(), isNotEmpty);
      },
    );
  });

  group('KoelClient — safe classifier (deferred #1)', () {
    test(
      'a throwing classifier degrades to AgentError(unknown), nothing escapes',
      () async {
        final client = KoelClient(
          agent: _FixtureAgent(const [
            RunStartedEvent(threadId: 't1', runId: 'r1'),
          ], throwAfterEmit: StateError('agent boom')),
          errorClassifier: const _ThrowingClassifier(),
        );
        addTearDown(client.dispose);

        final caught = <Object>[];
        late List<AgUiEvent> out;
        await runZonedGuarded(() async {
          out = await client.runRaw(_input).toList();
        }, (error, stack) => caught.add(error));

        final runError = out.whereType<RunErrorEvent>().single;
        expect(runError.error, isA<AgentError>());
        expect(runError.error.code, KoelErrorCode.unknown);
        expect(runError.error.message, 'error classifier threw');
        // The classifier throw was caught by _SafeClassifier, not leaked.
        expect(caught, isEmpty);
      },
    );
  });

  group('KoelClient.dispose (AC1)', () {
    test('disposes active sessions, clears subscribers, is idempotent', () async {
      final client = KoelClient(
        agent: _FixtureAgent(const []),
        subscribers: [_RecordingSubscriber()],
      );
      final session = client.newSession();

      client.dispose();

      // The session's broadcast controllers are closed → a new listener is done.
      await expectLater(session.stream, emitsDone);
      await expectLater(session.events, emitsDone);
      expect(client.subscribers, isEmpty);
      // A second dispose is a no-op.
      expect(client.dispose, returnsNormally);
    });
  });

  group('KoelClient — no global state (AC4)', () {
    test('interleaved runs across two clients never cross-talk', () async {
      final rec1 = _RecordingSubscriber();
      final rec2 = _RecordingSubscriber();
      final c1 = KoelClient(
        agent: _FixtureAgent(const [
          RunStartedEvent(threadId: 'A', runId: 'rA'),
          TextMessageStartEvent(messageId: 'm', role: 'assistant'),
          TextMessageContentEvent(messageId: 'm', delta: 'alpha'),
          TextMessageEndEvent(messageId: 'm'),
          RunFinishedEvent(threadId: 'A', runId: 'rA'),
        ]),
        subscribers: [rec1],
      );
      final c2 = KoelClient(
        agent: _FixtureAgent(const [
          RunStartedEvent(threadId: 'B', runId: 'rB'),
          TextMessageStartEvent(messageId: 'm', role: 'assistant'),
          TextMessageContentEvent(messageId: 'm', delta: 'beta'),
          TextMessageEndEvent(messageId: 'm'),
          RunFinishedEvent(threadId: 'B', runId: 'rB'),
        ]),
        subscribers: [rec2],
      );
      addTearDown(c1.dispose);
      addTearDown(c2.dispose);

      final s1 = c1.newSession(threadId: 'A');
      final s2 = c2.newSession(threadId: 'B');

      // Interleave the two runs.
      await Future.wait([s1.send('one'), s2.send('two')]);

      // Each recorder saw only its own client's RUN_STARTED.
      expect(rec1.runStartThreads, ['A']);
      expect(rec2.runStartThreads, ['B']);
      // Each session's final assistant message is independent.
      final m1 = s1.state.messages.where((m) => m.content == 'alpha');
      final m2 = s2.state.messages.where((m) => m.content == 'beta');
      expect(m1, hasLength(1));
      expect(m2, hasLength(1));
      expect(s1.state.messages.any((m) => m.content == 'beta'), isFalse);
      expect(s2.state.messages.any((m) => m.content == 'alpha'), isFalse);
    });
  });
}
