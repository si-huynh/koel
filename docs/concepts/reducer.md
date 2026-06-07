---
id: reducer
title: The reducer
---

# The reducer

A run is a stream of events; what your UI renders is a single value:
`ChatState`. The **reducer** is the pure fold that turns the event stream into
that value. `ChatSession` runs it for you — `session.state` is always the latest
fold, and `session.stream` emits a new `ChatState` after each event is applied.

```dart
final session = client.newSession();
session.stream.listen((state) {
  // state.messages — the conversation so far
  // state.phase    — run lifecycle position (idle / running / error)
  // state.state    — the agent's shared state map (driven by STATE_SNAPSHOT / STATE_DELTA)
});
await session.send('Summarize this thread');
```

## What the reducer folds

- **Text messages** — `TEXT_MESSAGE_START/CONTENT/END` accumulate into a single
  assistant `Message`; the partial message is visible mid-stream and committed on
  `END`.
- **Tool calls** — `TOOL_CALL_*` build up a `ToolCall` (name + streamed args +
  result) attached to the message.
- **Shared state** — `STATE_SNAPSHOT` replaces `state.state` (the agent state
  map) wholesale; `STATE_DELTA` applies a list of `JsonPatchOp` (RFC 6902) on top
  of it.
- **Lifecycle** — `RUN_STARTED`/`RUN_FINISHED` move `state.phase`; `RUN_ERROR`
  surfaces a typed `KoelError` on `state.error`.

The reducer is a pure function `(ChatState, AgUiEvent) -> ChatState` — no I/O, no
hidden mutation. That purity is what makes time-travel replay and conformance
testing possible: feed the same events, get the same state.

## STATE_DELTA conflicts

A `STATE_DELTA` is a JSON Patch against the current `state.state`. If a patch
cannot apply cleanly (a `test` op fails, or a path is missing), the reducer does
**not** silently drop it — it surfaces a `StateConflict` carrying the incoming
patches, so the conflict reaches a surface rather than corrupting state.

## Composing reducers

Most apps never write a reducer — the default handles the full AG-UI surface. When
you need to fold an app-specific `CUSTOM` event into your own state, compose:
`ComposedReducer` runs the koel default first, then your reducer over the result,
so you extend the fold without forking it.

```dart
// Pseudocode shape: default fold, then your handling of a CUSTOM event.
final reducer = ComposedReducer([defaultReducer, myCustomEventReducer]);
```

See [Events](./events.md) for the family list and
[Sessions](./sessions.md) for how the folded state is persisted.
