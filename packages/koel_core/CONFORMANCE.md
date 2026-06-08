# AG-UI Conformance

This document pins the AG-UI protocol release `koel_core` targets and defines the
equality rule the conformance harness (`koel_test`'s `ConformanceRunner`, FR-G4)
uses to decide whether a backend adapter reproduces each event type correctly.

## Pinned AG-UI release

- **Release:** `release/2026-05-26`
- **Commit SHA:** `d74e2dfc1e11bebdff419c2cbd347c811555411d`

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

## OQ-Conformance-Equivalence — RESOLVED (v1.0.0)

The runner does **exact** structural `==`, and that is the **final** v1.0.0 rule.
The two questions this OQ deferred both resolve to "the current rule is correct
as it stands" — no new comparison or normalization code is needed:

1. **`Uint8List` byte-equal is the v1.0.0 rule (not identity).** The sole binary
   field across the 28-type event registry is
   `ReasoningEncryptedValueEvent.encryptedValue`
   (`lib/src/event/reasoning_events.dart` — the only `Uint8List` field on any
   inbound `AgUiEvent`; the `Map<String, Uint8List> reasoningEcho` surface lives
   on the **outbound** `RunAgentInput`, not on a graded event). Byte-equal is
   *correct* for it: two backends encrypting the same plaintext to different
   ciphertext are not the same event — content identity, not buffer identity, is
   what conformance must compare. No event type needs identity or normalized
   comparison, so the byte-equal rule above (AR-16) is **final**.

2. **Id-normalization for real backend captures — none required, by design.** The
   concern was that a live backend's backend-specific
   `threadId` / `runId` / `messageId` would not be `==` to the synthesized corpus.
   But the architecture never drives a live backend through the corpus runner; the
   two checks are deliberately split:
   - **Conformance** (`ConformanceRunner.runAgainst`) grades against the
     **synthesized** `all_event_types.jsonl` with canonical
     `conformance-thread` / `conformance-run` / fixed ids, driving the agent over a
     replay of that very corpus. Same ids on both sides → exact `==` is correct.
   - **Real-capture fidelity** is graded **separately** by byte-round-trip
     equality — parse the captured backend SSE through the agent and assert
     `events == FixtureLoader.loadAgno('text_only_run')`
     (`koel_agno/test/conformance_test.dart`, plus the `loadLangGraph` /
     `loadCopilotkit` twins). Both sides decode the **same** captured bytes, so
     backend-specific ids match trivially — again no normalization.

   That split — conformance = corpus-graded (canonical ids); real-capture
   fidelity = same-bytes round-trip — **is** the resolution. No normalization
   layer is added to the runner. (The multi-emit `sameType.first` attribution in
   `ConformanceRunner` remains a documented skeleton limitation — the 28 distinct
   `runtimeType`s mean the path is unreached — not part of the equivalence rule.)
