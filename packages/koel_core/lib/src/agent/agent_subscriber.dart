import '../event/ag_ui_event.dart';

/// A passive, post-pipeline observer of an agent run — the cross-cutting hook
/// bag for devtools, telemetry, and analytics (FR-A10).
///
/// Each callback fires when its matching [AgUiEvent] reaches subscribers, which
/// is **after** the interceptor chain and the four-stage pipeline have run, so a
/// subscriber sees canonical events (e.g. a synthesized [ToolCallStartEvent],
/// never a raw [ToolCallChunkEvent]). Subscribers are **observation-only**: a
/// callback must never mutate the client, the session, or the [ChatState] it is
/// watching — it reads and reacts (log, count, forward), nothing more.
///
/// **Extend, do not implement.** Every callback ships an empty default body, so
/// you override only the events you care about and the rest stay free no-ops:
///
/// ```dart
/// class RunCounter extends AgentSubscriber {
///   int runs = 0;
///   @override
///   void onRunStart(RunStartedEvent e) => runs++;
/// }
/// ```
///
/// Implementing the interface instead forfeits the defaults (you must define all
/// of them) and makes every future callback a breaking change; extending keeps
/// new 1.x callbacks additive — a new empty method your subclass inherits for
/// free (forward-compat policy).
///
/// The bag is a **curated subset** of the ~28 [AgUiEvent] types, not a 1:1
/// mirror — the streaming framing events (`*_START`/`*_END`/`*_CHUNK`/`*_ARGS`),
/// the snapshot events, and `RAW`/`CUSTOM` have no callback; observe those via
/// the raw `ChatSession.events` stream. Whole event families fan in to one hook:
/// every reasoning event reaches [onReasoning] and both activity events reach
/// [onActivity], each typed as the [AgUiEvent] base — `switch` on `e` inside the
/// callback to narrow.
///
/// **Subscriber-isolation contract.** When the dispatcher fires several
/// subscribers for one event (wired in `KoelClient`), it invokes them in
/// registration order and isolates them: a throw from one callback is reported
/// to the current `Zone` (not silently swallowed) and does **not** stop the
/// others. Do not rely on a throw to abort the run — it won't.
abstract class AgentSubscriber {
  const AgentSubscriber();

  /// The agent began a run (`RUN_STARTED`).
  void onRunStart(RunStartedEvent e) {}

  /// The agent completed a run successfully (`RUN_FINISHED`).
  void onRunFinish(RunFinishedEvent e) {}

  /// The agent terminated a run with a typed failure (`RUN_ERROR`).
  void onRunError(RunErrorEvent e) {}

  /// The agent entered a named step within a run (`STEP_STARTED`).
  void onStepStart(StepStartedEvent e) {}

  /// The agent left a named step (`STEP_FINISHED`).
  void onStepFinish(StepFinishedEvent e) {}

  /// One streamed delta of an assistant message (`TEXT_MESSAGE_CONTENT`) — the
  /// content event only, not the `START`/`END`/`CHUNK` framing.
  void onTextChunk(TextMessageContentEvent e) {}

  /// A tool invocation began (`TOOL_CALL_START`). [end] is reserved for a future
  /// correlated dispatch and is `null` under the current per-event firing;
  /// start↔end pairing is the reducer's responsibility, not this hook's.
  void onToolCall(ToolCallStartEvent start, ToolCallEndEvent? end) {}

  /// A tool invocation produced a result (`TOOL_CALL_RESULT`).
  void onToolResult(ToolCallResultEvent e) {}

  /// An incremental mutation of the shared agent state (`STATE_DELTA`) — not the
  /// wholesale `STATE_SNAPSHOT`.
  void onStateDelta(StateDeltaEvent e) {}

  /// Any reasoning-family event (`REASONING_*`, including the chain-of-thought
  /// message stream and the encrypted-value blob). `switch` on [e] to narrow.
  void onReasoning(AgUiEvent e) {}

  /// Any activity-family event (`ACTIVITY_SNAPSHOT` / `ACTIVITY_DELTA`). `switch`
  /// on [e] to narrow.
  void onActivity(AgUiEvent e) {}

  /// An unrecognized wire event that decoded to the forward-compat fallback
  /// (`UnknownAgUiEvent`, FC-1) — the seam for diagnosing protocol drift.
  void onUnknownEvent(UnknownAgUiEvent e) {}
}
