import 'dart:async';

import '../event/ag_ui_event.dart';

/// Pipeline stage 3 — folds each event into `ChatState` via the registered
/// `ChatStateReducer` and resolves any `StateConflict` via the registered
/// `StateConflictResolver` (Addendum C.1 §3 / F.3).
///
/// The reducer is **pure**: it rebuilds `ChatState` on every call and never
/// mutates `state.messages` / `state.state` / `state.reasoningEcho`, which is
/// what keeps `ChatState` const-comparable and Riverpod-friendly. The fold is a
/// **side accumulation** surfaced to `ChatSession.stream` as `ChatState` — it
/// does **not** rewrite the event stream, so [transformStage] (and the
/// subscribers after it) see the same `AgUiEvent`s flow through unchanged.
///
/// With **no reducer registered** this stage is a pure pass-through — the
/// identity it is today. The reducer (`ChatStateReducer`, Story 2.12) and the
/// conflict resolver (`StateConflictResolver`, Story 2.13) are wired in by
/// `KoelClient` (Story 2.14); this stage's position in the locked composition
/// order is its contract until then.
final StreamTransformer<AgUiEvent, AgUiEvent> applyStage =
    StreamTransformer.fromBind((events) => events);
