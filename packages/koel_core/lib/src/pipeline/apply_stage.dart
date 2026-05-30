import 'dart:async';

import '../error/error_classifier.dart';
import '../event/ag_ui_event.dart';
import '../input/run_agent_input.dart';
import '../state/chat_state.dart';
import '../state/chat_state_reducer.dart';
import 'stage_support.dart';

/// Pipeline stage 3 — the **no-reducer** identity pass-through.
///
/// The reducer is **pure**: it rebuilds `ChatState` on every call and never
/// mutates `state.messages` / `state.state` / `state.reasoningEcho`, which is
/// what keeps `ChatState` const-comparable and Riverpod-friendly. The fold is a
/// **side accumulation** surfaced to `ChatSession.stream` as `ChatState` — it
/// does **not** rewrite the event stream, so [transformStage] (and the
/// subscribers after it) see the same `AgUiEvent`s flow through unchanged.
///
/// This value is the apply stage with **no reducer registered**: a pure
/// pass-through. It is what `KoelClient.runRaw` runs (`runRaw` =
/// "pipeline applied but no reducer", Addendum A.1 :47). `ChatSession`, which
/// *does* fold a reducer, swaps in [reducingApplyStage] instead — same pipeline,
/// different apply stage. The two consumers share one backbone and differ only
/// here.
final StreamTransformer<AgUiEvent, AgUiEvent> applyStage =
    StreamTransformer.fromBind((events) => events);

/// The apply stage **with** a reducer registered — the side-accumulation half of
/// the apply seam that `ChatSession` composes (and `runRaw` deliberately does
/// not).
///
/// Folds each event into `ChatState` via [reducer] as a **side accumulation**
/// pushed to [onState], then passes the event through unchanged — it **never**
/// rewrites the stream (the identity above is the same value flow with the fold
/// removed). [initial] seeds the fold; [onState] receives every new `ChatState`
/// (the session forwards it to its broadcast `ChatState` controller).
///
/// **Reducer-throw guard (deferred-work #3).** A consumer-supplied or
/// `ComposedReducer` reduce is not guaranteed total. A throw is caught and folded
/// into `ChatState.error` + [RunPhase.error] via [classifier] (over the run's
/// [input]) — it degrades the state, it does not hang the consumer.
/// `DefaultChatStateReducer` is already total, so the `catch` is dead on the
/// default path. [Source: deferred-work.md :171; apply_stage side-accumulation
/// contract]
StreamTransformer<AgUiEvent, AgUiEvent> reducingApplyStage({
  required ChatStateReducer reducer,
  required ChatState initial,
  required void Function(ChatState) onState,
  required ErrorClassifier classifier,
  required RunAgentInput input,
}) => buildStage(
  () => _ReducingApplyStage(
    reducer: reducer,
    initial: initial,
    onState: onState,
    classifier: classifier,
    input: input,
  ),
);

/// Per-subscription apply stage carrying the running `ChatState` fold.
///
/// [buildStage] mints a fresh instance per `listen`, so the same
/// [reducingApplyStage] value is safe to reuse across runs/clients without
/// shared state (FR-D3).
class _ReducingApplyStage extends PipelineStage {
  _ReducingApplyStage({
    required this.reducer,
    required ChatState initial,
    required this.onState,
    required this.classifier,
    required this.input,
  }) : _state = initial;

  final ChatStateReducer reducer;
  final void Function(ChatState) onState;
  final ErrorClassifier classifier;
  final RunAgentInput input;
  ChatState _state;

  @override
  void onEvent(AgUiEvent event, EventSink<AgUiEvent> out) {
    try {
      _state = reducer.reduce(_state, event);
    } catch (e, st) {
      // A non-total custom/Composed reducer degrades in-band to ChatState.error;
      // it never escapes to hang the downstream consumer (deferred-work #3).
      _state = _state.copyWith(
        error: classifier.classify(e, st, input),
        phase: RunPhase.error,
      );
    }
    onState(_state);
    out.add(event); // Pass-through: the stage never rewrites the stream.
  }
}
