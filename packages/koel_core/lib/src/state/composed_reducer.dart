import '../event/ag_ui_event.dart';
import 'chat_state.dart';
import 'chat_state_reducer.dart';

/// Composes [reducers] left-to-right over the same event — the F-D2 layering
/// seam consumers use to stack custom reduction on top of
/// [DefaultChatStateReducer].
///
/// Each reducer sees the prior reducer's output for the **same** event:
/// `reduce(s, e)` folds `reducers` over `s`, threading each result into the
/// next. Order is therefore significant (a later reducer can override an earlier
/// one's field). An empty list is the identity reducer (returns `state`
/// unchanged). Purity composes: if every member is pure, so is the composition.
class ComposedReducer implements ChatStateReducer {
  /// Composes [reducers] left-to-right over the same event.
  const ComposedReducer(this.reducers);

  /// The reducers folded in order; a later one can override an earlier one.
  final List<ChatStateReducer> reducers;

  @override
  ChatState reduce(ChatState state, AgUiEvent event) =>
      reducers.fold(state, (s, r) => r.reduce(s, event));
}
