import 'dart:async';

import 'package:koel_core/koel_core.dart';

import 'fixture_loader.dart';

/// One timeline entry: the [event] to emit, and the [delay] to wait *before*
/// emitting it. Named fields so the replay loop can destructure by name.
typedef _TimedEvent = ({AgUiEvent event, Duration delay});

/// A deterministic [AbstractAgent] test double that replays a fixed
/// [AgUiEvent] sequence through a real [Stream].
///
/// Authored inline two ways:
/// - [MockAgent.fromEvents] — a flat list, the low-level path.
/// - [MockAgent.programmatic] — a fluent [MockAgentBuilder] for declarative
///   construction (`programmatic().runStarted().textMessage('hi').runFinished().build()`).
///
/// It is the blessed alternative to hand-mocking [AbstractAgent]. Replay is
/// **verbatim**: [run] ignores its [RunAgentInput] and emits the canned sequence
/// exactly as authored — the sequence *is* the contract. As an adapter it
/// **never throws** a `KoelError`; an error scenario is authored in-band by
/// placing a [RunErrorEvent] in the sequence.
final class MockAgent implements AbstractAgent {
  MockAgent._(this._timeline);

  /// Replays [events] verbatim, waiting [delay] before each (default: no delay,
  /// i.e. emit on the next event-loop turn). The list is defensively copied —
  /// mutating [events] after construction does not change replay.
  factory MockAgent.fromEvents(
    List<AgUiEvent> events, {
    Duration delay = Duration.zero,
  }) => MockAgent._(
    List<_TimedEvent>.unmodifiable(
      events.map((event) => (event: event, delay: delay)),
    ),
  );

  /// A fresh fluent builder for declarative inline construction.
  static MockAgentBuilder programmatic() => MockAgentBuilder._();

  /// Loads the synthesized fixture [name] and wraps its decoded events into a
  /// replaying [MockAgent] — the one-line, zero-setup test double
  /// (`await MockAgent.fromFixture('text_only_run')`, FR-G2).
  ///
  /// `static` returning a `Future`, **not** a `factory` (Dart factories cannot
  /// be async). Delegates to [MockAgent.fromEvents], so verbatim replay,
  /// defensive copy, and cancellation semantics are unchanged — this adds only
  /// the load+decode. An unknown [name] propagates
  /// [FixtureLoader.loadSynthesized]'s enumerated [ArgumentError] as the
  /// future's error (a test-authoring mistake, not a runtime failure).
  static Future<MockAgent> fromFixture(String name) async {
    final events = await FixtureLoader.loadSynthesized(name);
    return MockAgent.fromEvents(events);
  }

  final List<_TimedEvent> _timeline;

  /// Replays the canned sequence on a fresh single-subscription stream. [input]
  /// is ignored — the sequence is the contract. Cancelling the subscription
  /// terminates replay at the next suspension point (TCP-close analog); the
  /// agent is reusable across runs.
  @override
  Stream<AgUiEvent> run(RunAgentInput input) async* {
    for (final (:event, :delay) in _timeline) {
      // Always await, even on Duration.zero: this makes emission asynchronous
      // (never delivered synchronously inside listen()) and makes cancellation
      // observable between every pair of events.
      await Future<void>.delayed(delay);
      yield event;
    }
  }
}

/// A mutable, fluent builder for a [MockAgent].
///
/// Each method appends to an internal timeline and returns `this` for chaining;
/// [build] freezes the accumulated timeline into an immutable [MockAgent]. The
/// builder does **not** enforce lifecycle ordering — authors are free to build
/// deliberately malformed sequences for negative tests. The sugar methods
/// produce well-formed *sub*-sequences; overall coherence is the author's.
final class MockAgentBuilder {
  MockAgentBuilder._();

  final List<_TimedEvent> _timeline = [];

  String _threadId = 'mock-thread';
  String _runId = 'mock-run';
  int _messageSeq = 0;
  bool _built = false;

  /// Appends a `RUN_STARTED`. Overriding [threadId]/[runId] updates the
  /// builder's current run pair so a following [runFinished] matches.
  MockAgentBuilder runStarted({
    String? threadId,
    String? runId,
    Duration? delay,
  }) {
    if (threadId != null) _threadId = threadId;
    if (runId != null) _runId = runId;
    return _append(RunStartedEvent(threadId: _threadId, runId: _runId), delay);
  }

  /// Appends the three events of a streamed assistant message —
  /// `TEXT_MESSAGE_START` → `TEXT_MESSAGE_CONTENT` → `TEXT_MESSAGE_END` — sharing
  /// one [messageId]. [delay] (if any) applies before each of the three. The
  /// generated id is counter-based and non-empty (`mock-msg-N`); pass an empty
  /// [messageId] only for a deliberate negative test.
  MockAgentBuilder textMessage(
    String text, {
    String? messageId,
    String role = 'assistant',
    Duration? delay,
  }) {
    final id = messageId ?? 'mock-msg-${++_messageSeq}';
    _append(TextMessageStartEvent(messageId: id, role: role), delay);
    _append(TextMessageContentEvent(messageId: id, delta: text), delay);
    return _append(TextMessageEndEvent(messageId: id), delay);
  }

  /// Appends a `RUN_FINISHED` closing the current run pair, carrying the
  /// optional backend [result].
  MockAgentBuilder runFinished({Object? result, Duration? delay}) => _append(
    RunFinishedEvent(threadId: _threadId, runId: _runId, result: result),
    delay,
  );

  /// The escape hatch: appends any [event] verbatim (tool calls, state deltas,
  /// [RunErrorEvent], reasoning, …). This authors non-text and negative-path
  /// scenarios without per-type sugar.
  MockAgentBuilder event(AgUiEvent event, {Duration? delay}) =>
      _append(event, delay);

  /// Freezes the accumulated timeline into an immutable [MockAgent].
  ///
  /// Single-shot: a builder is spent once built. Calling [build] a second time
  /// throws a [StateError] rather than silently emitting the accumulated
  /// timeline again — reuse is a misuse, not a feature. Start a fresh
  /// [MockAgent.programmatic] for another agent.
  MockAgent build() {
    if (_built) {
      throw StateError(
        'MockAgentBuilder.build() already called — a builder is single-use. '
        'Call MockAgent.programmatic() for a new builder.',
      );
    }
    _built = true;
    return MockAgent._(List<_TimedEvent>.unmodifiable(_timeline));
  }

  MockAgentBuilder _append(AgUiEvent event, Duration? delay) {
    _timeline.add((event: event, delay: delay ?? Duration.zero));
    return this;
  }
}
