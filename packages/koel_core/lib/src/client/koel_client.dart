import 'dart:async';

import '../agent/abstract_agent.dart';
import '../agent/agent_subscriber.dart';
import '../agent/interceptor.dart';
import '../error/error_classifier.dart';
import '../error/koel_error.dart';
import '../error/koel_error_code.dart';
import '../event/ag_ui_event.dart';
import '../input/run_agent_input.dart';
import '../message/message.dart';
import '../pipeline/apply_stage.dart';
import '../pipeline/pipeline.dart';
import '../session/session_storage.dart';
import '../state/chat_state.dart';
import '../state/chat_state_reducer.dart';
import '../state/state_conflict.dart';
import '../tool/tool_definition.dart';

part 'chat_session.dart';

/// How the SDK sheds load when a consumer reads slower than an agent produces.
///
/// **Stored configuration only in `koel_core`.** An in-memory agent has no
/// byte-stream to bound, so [KoelClient] stores the policy and builds no buffer;
/// the bounded buffer that consumes it ships in `koel_http` (Epic 4, Addendum
/// C.5). [pauseUpstream] (the default) closes the TCP window upstream;
/// [dropOldest]/[dropNewest] are loss-tolerant and log at warning level with a
/// dropped-event counter — all in `koel_http`.
enum BackpressurePolicy { dropOldest, dropNewest, pauseUpstream }

/// The top of the three-layer API (F-A2): a non-singleton client that wires
/// every Epic 2 kernel piece — the terminal [AbstractAgent], the
/// [Interceptor] chain, the [AgentSubscriber] bag, the [ChatStateReducer], the
/// [ErrorClassifier], the [StateConflictResolver], persistence, and the
/// backpressure/devtools config — into one consumable surface.
///
/// Two consumers share one backbone (`_pipelined`) and differ only in the apply
/// stage: [runRaw] (layer 3) runs the pipeline with **no** reducer; a
/// [ChatSession] from [newSession] (layer 2) runs the **same** pipeline with the
/// reducer folded as a side accumulation. A fresh [InterceptorChain] is built
/// per run (the chain is a stateful cursor).
///
/// **Non-singleton (FR-D3):** every per-run/per-session piece is instance-scoped
/// and the class holds **no `static` mutable state**, so independent clients in
/// one process never share state. Construct one per agent endpoint; [dispose] it
/// when done.
class KoelClient {
  /// Wires [agent] (the only required collaborator) and the optional kernel
  /// pieces, each falling back to its SDK default so a bare
  /// `KoelClient(agent: ...)` is fully functional. Parameter order and defaults
  /// match Addendum A.1.
  KoelClient({
    required AbstractAgent agent,
    SessionStorage? sessionStorage,
    ChatStateReducer? reducer,
    List<Interceptor>? interceptors,
    List<AgentSubscriber>? subscribers,
    ErrorClassifier? errorClassifier,
    StateConflictResolver? stateConflictResolver,
    this.devtoolsBufferSize = 1000,
    this.backpressure = BackpressurePolicy.pauseUpstream,
  }) : _agent = agent,
       _sessionStorage = sessionStorage,
       _reducer = reducer ?? const DefaultChatStateReducer(),
       stateConflictResolver =
           stateConflictResolver ?? const LastWriterWinsResolver(),
       _safeClassifier = _SafeClassifier(
         errorClassifier ?? const DefaultErrorClassifier(),
       ),
       _interceptors = List<Interceptor>.unmodifiable(
         interceptors ?? const <Interceptor>[],
       ),
       subscribers = <AgentSubscriber>[...?subscribers];

  final AbstractAgent _agent;
  final SessionStorage? _sessionStorage;
  final ChatStateReducer _reducer;
  final ErrorClassifier _safeClassifier;

  /// Stored configuration consumed downstream, **not** invoked in `koel_core`:
  /// [stateConflictResolver] is read by the apply-stage conflict wiring that a
  /// `ChatState` provenance model unlocks post-2.14; [devtoolsBufferSize] sizes
  /// the `koel_devtools` ring buffer (Epic 8); [backpressure] feeds the
  /// `koel_http` bounded buffer (Epic 4). Exposed read-only so devtools/tests can
  /// inspect the resolved wiring.
  final StateConflictResolver stateConflictResolver;
  final int devtoolsBufferSize;
  final BackpressurePolicy backpressure;

  /// The post-pipeline observer bag, fired in registration order on every event
  /// of every run. **Mutable**: register observers with `client.subscribers.add(...)`
  /// (Addendum F.4 / G.2). Cleared on [dispose].
  final List<AgentSubscriber> subscribers;

  List<Interceptor> _interceptors;
  final Set<ChatSession> _sessions = <ChatSession>{};

  /// A stable per-client discriminator for generated thread ids, derived from
  /// object identity — **no** `static` counter (FR-D3) and no `uuid` dependency.
  late final String _clientTag = identityHashCode(this).toRadixString(36);
  int _threadSeq = 0;

  /// Runs [input] through a **fresh** [InterceptorChain] (stateful cursor) and
  /// the four-stage pipeline. [apply] swaps the apply stage: `null` → identity
  /// (no reducer, the [runRaw] path); a `reducingApplyStage(...)` → the reducer
  /// fold (the [ChatSession] path).
  Stream<AgUiEvent> _pipelined(
    RunAgentInput input, {
    StreamTransformer<AgUiEvent, AgUiEvent>? apply,
  }) => runPipeline(
    InterceptorChain(
      interceptors: _interceptors,
      agent: _agent,
      errorClassifier: _safeClassifier,
    ).proceed(input),
    apply: apply,
  );

  /// Layer-3 escape hatch (F-A2): the **post-pipeline** event stream with
  /// interceptors and subscribers wired, but **no** reducer, **no** persistence,
  /// and **no** `ChatSession`/controller binding. Power users consume the
  /// canonical `AgUiEvent` stream directly.
  ///
  /// Single-subscription — listen once. Subscribers fire as each event passes.
  Stream<AgUiEvent> runRaw(RunAgentInput input) => _pipelined(input).map((e) {
    _notify(e);
    return e;
  });

  /// Returns a fresh [ChatSession] seeded with [initial] (default
  /// `const ChatState()`) under [threadId] (default a generated id) and registers
  /// it for [dispose].
  ///
  /// **Synchronous → no auto-load.** Returning `ChatSession` (not a `Future`)
  /// means it cannot `await` [SessionStorage.load]; [initial] is the only seed.
  /// Resume is explicit: load the persisted state and pass it as [initial] (the
  /// Epic 6 `KoelChatController` automates this).
  ChatSession newSession({String? threadId, ChatState? initial}) {
    final session = ChatSession._(
      this,
      threadId ?? 'koel-$_clientTag-${_threadSeq++}',
      initial ?? const ChatState(),
    );
    _sessions.add(session);
    return session;
  }

  /// Cancels and disposes every active session, then releases the subscriber and
  /// interceptor references. Idempotent — a second call is a no-op.
  void dispose() {
    // Snapshot: ChatSession.dispose removes itself from _sessions.
    for (final session in _sessions.toList()) {
      session.dispose();
    }
    subscribers.clear();
    _interceptors = const <Interceptor>[];
  }

  /// Fires every subscriber for [e] in registration order, isolating each: a
  /// throw is **reported** to the current `Zone` (not swallowed) and does not
  /// stop the others (the subscriber-isolation contract, `agent_subscriber.dart`).
  void _notify(AgUiEvent e) {
    for (final s in subscribers) {
      try {
        _dispatch(s, e);
      } catch (error, stack) {
        Zone.current.handleUncaughtError(error, stack);
      }
    }
  }

  /// Routes one canonical [AgUiEvent] to its [AgentSubscriber] callback. The bag
  /// is a curated subset of the ~28 event types, so the streaming-framing /
  /// snapshot / raw events fall through `default:` to no callback (observe those
  /// via `ChatSession.events`). `ToolCallStartEvent` dispatches with a `null`
  /// end — start↔end pairing is the reducer's job, not this hook's.
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
}

/// Wraps a consumer-supplied [ErrorClassifier] so a buggy `classify`
/// **degrades** instead of escaping the kernel's "nothing escapes" invariant: a
/// throw is caught and mapped to `AgentError(unknown)` carrying the thrown
/// object as its cause. Transparent for the never-throwing
/// [DefaultErrorClassifier]. [Source: deferred-work.md :162]
class _SafeClassifier implements ErrorClassifier {
  const _SafeClassifier(this._delegate);

  final ErrorClassifier _delegate;

  @override
  KoelError classify(Object raw, StackTrace? stack, RunAgentInput input) {
    try {
      return _delegate.classify(raw, stack, input);
    } catch (thrown) {
      return AgentError(
        message: 'error classifier threw',
        code: KoelErrorCode.unknown,
        cause: thrown,
      );
    }
  }
}
