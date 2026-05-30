import 'dart:async';
import 'dart:typed_data';

import 'package:koel_core/src/agent/agent_subscriber.dart';
import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:test/test.dart';

// A subscriber with zero overrides — every callback stays the inherited no-op.
class _NoopSubscriber extends AgentSubscriber {
  const _NoopSubscriber();
}

// Records a single label when its two overridden callbacks fire; everything else
// stays a no-op. Proves AC2 (override only what you need).
class _RecordingSubscriber extends AgentSubscriber {
  _RecordingSubscriber(this.label, this.log);

  final String label;
  final List<String> log;

  @override
  void onRunStart(RunStartedEvent e) => log.add(label);

  @override
  void onUnknownEvent(UnknownAgUiEvent e) => log.add('$label:unknown');
}

// Records the name of every callback it receives — used to assert the
// event→callback routing map.
class _AllRecordingSubscriber extends AgentSubscriber {
  final List<String> calls = [];
  ToolCallEndEvent? lastToolCallEnd = _sentinelEnd;

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
  void onToolCall(ToolCallStartEvent start, ToolCallEndEvent? end) {
    calls.add('onToolCall');
    lastToolCallEnd = end;
  }

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

// A non-null sentinel so a test can prove `onToolCall` was passed `null` for end.
const _sentinelEnd = ToolCallEndEvent(toolCallId: '_sentinel_');

class _ThrowingSubscriber extends AgentSubscriber {
  @override
  void onRunStart(RunStartedEvent e) => throw StateError('boom');
}

// The test-local dispatcher — the analog of Story 2.9's `_FixtureAgent`. The
// production routing + isolation ships with its first real caller, `KoelClient`
// (Story 2.14); here it exists only to prove AC2/AC3 intent.
void _dispatch(AgentSubscriber s, AgUiEvent e) {
  switch (e) {
    case RunStartedEvent():
      s.onRunStart(e);
    case RunFinishedEvent():
      s.onRunFinish(e);
    case RunErrorEvent():
      s.onRunError(e);
    case StepStartedEvent():
      s.onStepStart(e);
    case StepFinishedEvent():
      s.onStepFinish(e);
    case TextMessageContentEvent():
      s.onTextChunk(e);
    case ToolCallStartEvent():
      s.onToolCall(e, null);
    case ToolCallResultEvent():
      s.onToolResult(e);
    case StateDeltaEvent():
      s.onStateDelta(e);
    case ReasoningStartEvent() ||
        ReasoningEndEvent() ||
        ReasoningMessageStartEvent() ||
        ReasoningMessageContentEvent() ||
        ReasoningMessageEndEvent() ||
        ReasoningMessageChunkEvent() ||
        ReasoningEncryptedValueEvent():
      s.onReasoning(e);
    case ActivitySnapshotEvent() || ActivityDeltaEvent():
      s.onActivity(e);
    case UnknownAgUiEvent():
      s.onUnknownEvent(e);
    default:
      break; // curated subset — these events have no callback
  }
}

// Multi-subscriber notify: registration order, with per-subscriber isolation
// that reports (not swallows) a throw to the current Zone before continuing.
void _notifyAll(List<AgentSubscriber> subs, AgUiEvent e) {
  for (final s in subs) {
    try {
      _dispatch(s, e);
    } catch (error, stack) {
      Zone.current.handleUncaughtError(error, stack);
    }
  }
}

void main() {
  // Shared fixtures (all const-constructible).
  const runStarted = RunStartedEvent(threadId: 't1', runId: 'r1');
  const runFinished = RunFinishedEvent(threadId: 't1', runId: 'r1');
  const runError = RunErrorEvent(
    error: AgentError(message: 'x', code: KoelErrorCode.unknown),
  );
  const stepStarted = StepStartedEvent(stepName: 's');
  const stepFinished = StepFinishedEvent(stepName: 's');
  const textContent = TextMessageContentEvent(messageId: 'm1', delta: 'hi');
  const toolStart = ToolCallStartEvent(
    toolCallId: 'c1',
    toolCallName: 'search',
  );
  const toolResult = ToolCallResultEvent(
    messageId: 'm1',
    toolCallId: 'c1',
    content: 'ok',
  );
  const stateDelta = StateDeltaEvent(patches: []);
  const activitySnapshot = ActivitySnapshotEvent(
    messageId: 'm1',
    activityType: 'progress',
    content: {},
  );
  final unknown = UnknownAgUiEvent(type: 'FUTURE', rawJson: const {});

  group('AgentSubscriber default no-ops', () {
    test('every callback is an inherited no-op that does not throw', () {
      const s = _NoopSubscriber();
      expect(() {
        s.onRunStart(runStarted);
        s.onRunFinish(runFinished);
        s.onRunError(runError);
        s.onStepStart(stepStarted);
        s.onStepFinish(stepFinished);
        s.onTextChunk(textContent);
        s.onToolCall(toolStart, null);
        s.onToolResult(toolResult);
        s.onStateDelta(stateDelta);
        s.onReasoning(const ReasoningStartEvent(messageId: 'm1'));
        s.onActivity(activitySnapshot);
        s.onUnknownEvent(unknown);
      }, returnsNormally);
    });
  });

  group('event → callback routing', () {
    test('a partial subscriber fires only its overridden callbacks (AC2)', () {
      final log = <String>[];
      final s = _RecordingSubscriber('A', log);

      // The two overridden events fire; the other two route to inherited no-ops.
      _dispatch(s, runStarted);
      _dispatch(s, unknown);
      _dispatch(s, textContent);
      _dispatch(s, runFinished);

      expect(log, ['A', 'A:unknown']);
    });

    test('each mapped event reaches exactly its callback', () {
      final s = _AllRecordingSubscriber();
      _dispatch(s, runStarted);
      _dispatch(s, runFinished);
      _dispatch(s, runError);
      _dispatch(s, stepStarted);
      _dispatch(s, stepFinished);
      _dispatch(s, textContent);
      _dispatch(s, toolStart);
      _dispatch(s, toolResult);
      _dispatch(s, stateDelta);
      _dispatch(s, const ReasoningStartEvent(messageId: 'm1'));
      _dispatch(s, activitySnapshot);
      _dispatch(s, unknown);

      expect(s.calls, [
        'onRunStart',
        'onRunFinish',
        'onRunError',
        'onStepStart',
        'onStepFinish',
        'onTextChunk',
        'onToolCall',
        'onToolResult',
        'onStateDelta',
        'onReasoning',
        'onActivity',
        'onUnknownEvent',
      ]);
    });

    test('onToolCall receives a null end under per-event dispatch', () {
      final s = _AllRecordingSubscriber();
      _dispatch(s, toolStart);
      expect(s.lastToolCallEnd, isNull);
    });

    test('all 7 reasoning-family events fan in to onReasoning', () {
      final s = _AllRecordingSubscriber();
      final reasoning = <AgUiEvent>[
        const ReasoningStartEvent(messageId: 'm'),
        ReasoningEndEvent(messageId: 'm'),
        ReasoningMessageStartEvent(messageId: 'm', role: 'reasoning'),
        ReasoningMessageContentEvent(messageId: 'm', delta: 'd'),
        ReasoningMessageEndEvent(messageId: 'm'),
        ReasoningMessageChunkEvent(messageId: 'm'),
        ReasoningEncryptedValueEvent(
          entityId: 'e',
          subtype: 'message',
          encryptedValue: Uint8List(0),
          encryptedValueBase64: '',
        ),
      ];
      for (final e in reasoning) {
        _dispatch(s, e);
      }
      expect(s.calls, List.filled(7, 'onReasoning'));
    });

    test('both activity events fan in to onActivity', () {
      final s = _AllRecordingSubscriber();
      _dispatch(s, activitySnapshot);
      _dispatch(
        s,
        const ActivityDeltaEvent(
          messageId: 'm1',
          activityType: 'progress',
          patches: [],
        ),
      );
      expect(s.calls, ['onActivity', 'onActivity']);
    });

    test('curated-subset events route to no callback', () {
      final s = _AllRecordingSubscriber();
      const noCallback = <AgUiEvent>[
        TextMessageStartEvent(messageId: 'm', role: 'assistant'),
        TextMessageEndEvent(messageId: 'm'),
        TextMessageChunkEvent(),
        ToolCallArgsEvent(toolCallId: 'c', delta: 'd'),
        ToolCallEndEvent(toolCallId: 'c'),
        ToolCallChunkEvent(),
        StateSnapshotEvent(state: {}),
        MessagesSnapshotEvent(messages: []),
        RawEvent(payload: {}),
        CustomEvent(name: 'x', value: null),
      ];
      for (final e in noCallback) {
        _dispatch(s, e);
      }
      expect(s.calls, isEmpty);
    });
  });

  group('multi-subscriber dispatch (AC3)', () {
    test('subscribers fire in registration order', () {
      final log = <String>[];
      final subs = [
        _RecordingSubscriber('A', log),
        _RecordingSubscriber('B', log),
        _RecordingSubscriber('C', log),
      ];

      _notifyAll(subs, runStarted);

      expect(log, ['A', 'B', 'C']);
    });

    test('a throwing subscriber is isolated: others still fire and the error is '
        'reported to the Zone (not swallowed)', () {
      final log = <String>[];
      final caught = <Object>[];
      final subs = [
        _RecordingSubscriber('A', log),
        _ThrowingSubscriber(),
        _RecordingSubscriber('C', log),
      ];

      runZonedGuarded(
        () => _notifyAll(subs, runStarted),
        (error, stack) => caught.add(error),
      );

      // The thrower did not abort the loop — A and C both ran.
      expect(log, ['A', 'C']);
      // The throw surfaced to the Zone exactly once — reported, not swallowed.
      expect(caught, hasLength(1));
      expect(caught.single, isStateError);
    });
  });
}
