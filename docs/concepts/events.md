---
id: events
title: Events
---

# Events

Everything a koel agent emits is an `AgUiEvent` — a **sealed union** of the AG-UI
event families. A run is a `Stream<AgUiEvent>`: `RUN_STARTED`, then any number of
message / tool / state / step events, then a terminal `RUN_FINISHED` (or
`RUN_ERROR`).

```dart
await for (final event in agent.run(input)) {
  switch (event) {
    case RunStartedEvent():
      // run opened
    case TextMessageContentEvent(:final delta):
      buffer.write(delta);
    case RunFinishedEvent():
      // run complete
    case _:
      // every other family — see below
  }
}
```

## The union is sealed and exhaustive

`AgUiEvent` is a Dart 3 `sealed` class. A `switch` over it is exhaustive: the
compiler knows the full set of subtypes. koel ships a lint —
`exhaustive_switch_must_have_default` (in `koel_lints`) —
that **requires** a `default:` / `_` branch on any switch over `AgUiEvent`,
`KoelError`, or `MessageSegment`. That branch is the forward-compat seam: when a
future minor adds a new event family, your code keeps compiling and routes the
unknown event to the default arm instead of throwing.

Unknown wire events never crash the stream — an unrecognized `type` deserializes
to `UnknownAgUiEvent`, carrying the raw payload for inspection or pass-through.

## The families

| Family | Events | Carries |
| --- | --- | --- |
| Run lifecycle | `RUN_STARTED`, `RUN_FINISHED`, `RUN_ERROR` | run/thread ids, terminal error |
| Text message | `TEXT_MESSAGE_START` / `CONTENT` / `END` | streamed assistant text deltas |
| Tool call | `TOOL_CALL_START` / `ARGS` / `END`, `TOOL_CALL_RESULT` | tool name, streamed args, result |
| State | `STATE_SNAPSHOT`, `STATE_DELTA` | full state, or a JSON Patch over it |
| Step | `STEP_STARTED`, `STEP_FINISHED` | sub-step boundaries |
| Snapshot | `MESSAGES_SNAPSHOT` | the full message list |
| Reasoning | reasoning start / content / end | model reasoning echo |
| Misc | `ACTIVITY`, `RAW`, `CUSTOM` | progress, raw frames, adapter extensions |

`STATE_DELTA` carries a list of `JsonPatchOp` (RFC 6902 operations); the reducer
applies them — see [The reducer](./reducer.md).

## Chunk synthesis (the 25/28 contract)

The protocol also defines three convenience *chunk* shapes —
`TEXT_MESSAGE_CHUNK`, `TOOL_CALL_CHUNK`, `REASONING_MESSAGE_CHUNK` — that fold a
start/content/end triplet into one frame. koel_http normalizes them back into
their long form **at the transport** (`HttpAgent.synthesizeChunks`, default-on),
so your `switch` only ever sees the `START`/`CONTENT`/`END` triplets. That is the
fixed **25-of-28** surface every native-AG-UI adapter shares — not a limitation,
a normalization. A real runtime never emits chunk shapes anyway.

## Decoding stored traces

For tooling that reads a recorded run (koel_test's fixture loader, devtools
replay), `AgUiEvent.fromWire` is the public decode seam — the same deserializer
the transport uses, exposed for trace inspection.
