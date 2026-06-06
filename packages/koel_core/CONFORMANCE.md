# AG-UI Conformance

This document pins the AG-UI protocol release `koel_core` targets and defines the
equality rule the conformance harness (`koel_test`'s `ConformanceRunner`, FR-G4)
uses to decide whether a backend adapter reproduces each event type correctly.

## Pinned AG-UI release

- **Release:** `release/2026-05-26`
- **Commit SHA:** `0000000000000000000000000000000000000000`
  **(PLACEHOLDER — finalized at v1.0.0 publish per SC-1.)**

The 28 typed event families (`RUN_STARTED` … `CUSTOM`) plus the
`UnknownAgUiEvent` forward-compat fallback are the closed registry decoded by
`AgUiEvent.fromWire`. The synthesized type-coverage corpus
(`koel_test/lib/src/fixtures/synthesized/all_event_types.jsonl`, one event of
every type) is the canonical expected set the runner drives an agent against.

## `AgUiEvent_equal` — the structural equality rule (AR-16)

Conformance decides pass/fail by `freezed`-generated `==`. For every event type,
`freezed` synthesizes a structural `==`/`hashCode` over **all** fields, using
`DeepCollectionEquality` for collection fields. Two events are equal iff every
field is equal:

- **Scalars** (`String`, `int`, `bool`, `Object?` like `RunFinishedEvent.result`)
  compare by value / deep value.
- **Collections** (`List`, `Map`, e.g. `MessagesSnapshotEvent.messages`,
  `StateSnapshotEvent.snapshot`) compare element-/entry-wise.
- **Binary blobs** (`Uint8List`, e.g. `ReasoningEncryptedValueEvent.encryptedValue`)
  compare **byte-equal**: `Uint8List` is an `Iterable<int>`, so
  `DeepCollectionEquality` compares contents, not buffer identity. Two events
  carrying distinct buffers with identical bytes are equal. (See
  `lib/src/event/reasoning_events.dart`.)

The runner matches an agent's emitted events to the expected event by
`runtimeType` (the `freezed` concrete type, e.g. `_RunStartedEvent`, is stable
and cheap to compare) and then decides equality by `==`. There is no polymorphic
`type` getter on the sealed `AgUiEvent`; the wire-type *label* (`"RUN_STARTED"`)
is read from the fixture line's `payload['type']` — the spec registry string is
the source of truth.

## Outbound request body (`RunAgentInput`)

The harness above grades **inbound** events. The one **outbound** payload koel
posts is `RunAgentInput`, encoded by `koel_http`'s `encodeRunAgentInput`. Its
seven AG-UI-normative fields are camelCase verbatim; the one type worth pinning
is `context`, which AG-UI defines as a **`List<Context>`** (each
`Context = {description, value}`), *not* a map. An empty input serializes
`"context": []` — a spec-compliant backend (`ag-ui-protocol` 0.1.10) 422-rejects
`{}`. Fixed in SCP-2026-06-06 (Story 2-16).

## OQ-Conformance-Equivalence (open until v1.0.0)

The skeleton runner does **exact** structural `==`. Two equivalence questions are
deliberately deferred and resolve before the v1.0.0 publish:

1. **`Uint8List` byte-equal vs identity.** The current rule is byte-equal (above).
   Whether any event type needs identity (or a normalized) comparison is revisited
   when real captures land.
2. **Id-normalization for real backend captures.** Live backends (Epic 5: agno,
   langgraph, dojo, CopilotKit runtime) emit the canonical event types but with
   backend-specific `threadId` / `runId` / `messageId` values that are not
   byte-`==` to the synthesized corpus. A normalization rule (so a structurally
   conformant real run passes the runner) is the resolution of this OQ; the
   skeleton does not pre-build it.
