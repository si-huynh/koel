part of 'koel_client.dart';

/// The middle layer of the three-layer API (F-A2): one stateful conversation
/// over a [KoelClient]. Construct it via [KoelClient.newSession], never directly.
///
/// It folds the agent's events into a running [ChatState] (via the apply stage's
/// side accumulation) and surfaces two **broadcast** streams: [stream] for the
/// `ChatState` snapshots a UI binds to, and [events] for the raw post-pipeline
/// `AgUiEvent`s an observer taps. Broadcast controllers do **not** replay — read
/// the [state] snapshot for "now", then `listen` to [stream] for changes (the
/// `ValueListenable` idiom).
///
/// Reads its collaborators (reducer, classifier, storage, dispatcher, pipeline)
/// from its owning [KoelClient] back-reference rather than threading a fat param
/// list. Owns a [StreamSubscription] and two [StreamController]s — [dispose] it.
class ChatSession {
  ChatSession._(this._client, this._threadId, ChatState initial)
    : _state = initial;

  final KoelClient _client;
  final String _threadId;
  ChatState _state;

  final StreamController<ChatState> _stateCtrl =
      StreamController<ChatState>.broadcast();
  final StreamController<AgUiEvent> _eventsCtrl =
      StreamController<AgUiEvent>.broadcast();

  StreamSubscription<AgUiEvent>? _sub;
  Completer<void>? _completer;
  int _runSeq = 0;

  /// The thread id this session reads and persists under.
  String get threadId => _threadId;

  /// The current folded [ChatState] — always up to date, the snapshot a late
  /// listener reads before subscribing to [stream].
  ChatState get state => _state;

  /// Broadcast stream of folded [ChatState] snapshots (architecture §4 — a UI
  /// binds many widgets to it). Does not replay; pair with [state].
  Stream<ChatState> get stream => _stateCtrl.stream;

  /// Broadcast stream of raw **post-pipeline** [AgUiEvent]s — the canonical
  /// events after chunks/verify, for multi-observer taps. Does not replay.
  Stream<AgUiEvent> get events => _eventsCtrl.stream;

  /// Sends a user turn and runs the agent, returning a future that completes when
  /// the run finishes (so `await session.send(...)` waits for the turn).
  ///
  /// Optimistically folds the user message locally (the agent never echoes it
  /// back — the reducer accumulates only the assistant side), builds the wire
  /// [RunAgentInput] from the current state (echoing reasoning blobs, FR-A9),
  /// then runs the client pipeline with the reducer folded as a side
  /// accumulation pushed to [_emit].
  Future<void> send(String content, {List<ToolDefinition>? tools}) {
    final completer = _completer = Completer<void>();
    final runIndex = _runSeq++;

    final userMsg = Message(
      id: 'msg-$_threadId-$runIndex',
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
    );
    _emit(
      _state.copyWith(
        messages: [..._state.messages, userMsg],
        phase: RunPhase.running,
      ),
    );

    final input = RunAgentInput(
      threadId: _threadId,
      runId: 'run-$_threadId-$runIndex',
      state: _state.state,
      messages: _state.messages,
      tools: tools ?? const <ToolDefinition>[],
      reasoningEcho: _state.reasoningEcho.isEmpty ? null : _state.reasoningEcho,
    );

    final stream = _client._pipelined(
      input,
      apply: reducingApplyStage(
        reducer: _client._reducer,
        initial: _state,
        onState: _emit,
        classifier: _client._safeClassifier,
        input: input,
      ),
    );

    _sub = stream.listen(
      (e) {
        _client._notify(e);
        if (!_eventsCtrl.isClosed) _eventsCtrl.add(e);
      },
      onError: (Object e, StackTrace st) {
        _emit(
          _state.copyWith(
            error: _client._safeClassifier.classify(e, st, input),
            phase: RunPhase.error,
          ),
        );
        _complete();
      },
      onDone: _complete,
      cancelOnError: false,
    );

    return completer.future;
  }

  /// Cancels the in-flight run and flips [state] to [RunPhase.cancelled]
  /// **immediately** — there is no cancel *event*; the session synthesizes the
  /// phase regardless of any transport outcome (there is none for an in-memory
  /// agent). The gating [send] future completes.
  void cancel() {
    _sub?.cancel();
    _emit(_state.copyWith(phase: RunPhase.cancelled));
    _complete();
  }

  /// Resets to a fresh idle [ChatState] and deletes any persisted copy.
  Future<void> clear() {
    _emit(const ChatState());
    return _client._sessionStorage?.delete(_threadId) ?? Future<void>.value();
  }

  /// Persists the current [state] under [threadId]. A no-op (completes normally)
  /// when the client has no [SessionStorage].
  Future<void> persist() =>
      _client._sessionStorage?.save(_threadId, _state) ?? Future<void>.value();

  /// Shallow-merges [patch] into the agent [ChatState.state] map mid-session
  /// and re-emits, so the NEXT [send] carries it in `RunAgentInput.state`
  /// without recreating the session (transcript/messages preserved). Mirrors
  /// CopilotKit `agent.setState({ ...agent.state, ...patch })`. Guarded against a
  /// closed controller via [_emit].
  void updateState(Map<String, dynamic> patch) {
    _emit(_state.copyWith(state: {..._state.state, ...patch}));
  }

  /// Cancels the in-flight run, closes both broadcast controllers, and
  /// unregisters from the owning client. Idempotent.
  void dispose() {
    _sub?.cancel();
    if (!_stateCtrl.isClosed) _stateCtrl.close();
    if (!_eventsCtrl.isClosed) _eventsCtrl.close();
    _client._sessions.remove(this);
  }

  /// Updates the running [state] and pushes it to the broadcast controller,
  /// guarding a late emit after [dispose] (a closed broadcast controller rejects
  /// `add`).
  void _emit(ChatState s) {
    _state = s;
    if (!_stateCtrl.isClosed) _stateCtrl.add(s);
  }

  /// Completes the in-flight [send] future once; guards a double-complete on
  /// cancel-after-done.
  void _complete() {
    final c = _completer;
    if (c != null && !c.isCompleted) c.complete();
  }
}
