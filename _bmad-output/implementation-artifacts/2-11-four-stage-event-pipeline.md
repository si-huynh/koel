---
baseline_commit: 5c3e56a5035d83346be15c774bdce73dbe30dd86
---

# Story 2.11: 4-stage event pipeline (chunks → verify → apply → transform)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this story touches `.dart` files, `StreamTransformer` design, and stateful async stream processing. **Invoke `/agent-flutter-engineer` before producing any code** (per CLAUDE.md). Two disciplines are load-bearing here: (1) **no vestigial code** — two of the four stages (`apply`, `transform`) have their *real* behaviour blocked on later stories (reducer = 2.12, consumer transforms = 2.14); building that behaviour now is exactly the "just in case" code koel bans (see Dev Notes §"Scope: which stages are real now"). (2) **no raw throw / silent catch crosses a koel boundary** — verify failures surface **in-stream** as `RunErrorEvent(ProtocolError)`, never as a thrown exception (the 2.9 `InterceptorChain.proceed` idiom, generalized).

## Story

As a Flutter/Dart developer,
I want the four pipeline stages declared as pure `StreamTransformer<AgUiEvent, AgUiEvent>` instances in `koel_core/lib/src/pipeline/`, composed in the fixed order chunks → verify → apply → transform,
so that every consumer of the pipeline sees identical canonical events with reducer-folded state per FR-A11 and Addendum C.1.

## Acceptance Criteria

Verbatim from [epic-2 Story 2.11](../planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md):

1. **Given** `koel_core/lib/src/pipeline/`, **When** I list the directory, **Then** `chunks_stage.dart`, `verify_stage.dart`, `apply_stage.dart`, `transform_stage.dart` all exist, **And** each defines a `StreamTransformer<AgUiEvent, AgUiEvent>` exported as a top-level value or factory.

2. **Given** the `chunks` stage processing a `TOOL_CALL_CHUNK` sequence, **When** the chunk synthesizer runs, **Then** the first chunk emits `ToolCallStartEvent`, subsequent chunks emit `ToolCallArgsEvent`, and the trailing marker emits `ToolCallEndEvent` per Addendum F.2, **And** the same behavior applies to `TEXT_MESSAGE_CHUNK`.

3. **Given** the `verify` stage processing a stream containing a `ToolCallEndEvent` without a matching `ToolCallStartEvent`, **When** the offending event arrives, **Then** the stage drops it and emits a `RunErrorEvent(error: ProtocolError(...))` per Addendum F.1, **And** all other documented verify rules (state_delta empty patches, REASONING_ENCRYPTED_VALUE bytes/base64 mismatch, etc.) are tested.

4. **Given** the four-stage pipeline composed via `events.transform(chunks).transform(verify).transform(apply).transform(transform)`, **When** I run an integration test that feeds the full 28-event sweep, **Then** the output stream contains only canonical events with the reducer state folded correctly, **And** stage order is locked (assertion that swapping any two stages breaks at least one test).

> **⚠️ AC4's "reducer state folded correctly" references machinery that does NOT exist yet.** The reducer (`ChatState`, `ChatStateReducer`, `DefaultChatStateReducer`) is **Story 2.12**; `StateConflict`/`LastWriterWinsResolver` are **Story 2.13**; consumer-registered `transforms` and the `KoelClient` that wires a reducer in are **Story 2.14**. This is the *exact* forward-reference situation 2.9 hit with `MockAgent` and 2.10 hit with "the pipeline"/`KoelClient`. **Resolution (binding — see Dev Notes §"Scope" + Design Decision 1):** in 2.11 the `chunks` and `verify` stages ship their full real logic (every dependency exists: events 2.5–2.8, errors 2.3, JSON Patch 2.4). The `apply` and `transform` stages ship as **pure identity `StreamTransformer`s** — which is *exactly* C.1's defined behaviour when no reducer / no transforms are registered, and they exist to lock the 3rd/4th positions in the composition order. The reducer-fold + conflict-resolution land in 2.12/2.13; consumer transforms land in 2.14. AC4 is reconciled this way: prove **event-stream canonicalness + locked stage order** end-to-end now (that is fully buildable); the **state fold** is proven where its type lives — 2.12's reducer-purity + integration tests. Do **NOT** build a reducer, a `ChatState`, a `StateConflictResolver`, or a production transform registry in this story.

## Tasks / Subtasks

- [x] **Task 1 — Create the `chunks` stage** (AC: #1, #2)
  - [x] New file `packages/koel_core/lib/src/pipeline/chunks_stage.dart`. **Single import:** `../event/ag_ui_event.dart` (all 28 event subtypes are `part of` it — `ToolCallChunkEvent`, `ToolCallStartEvent`, `ToolCallArgsEvent`, `ToolCallEndEvent`, `TextMessageChunkEvent`, `TextMessageStartEvent`, `TextMessageContentEvent`, `TextMessageEndEvent`, the `AgUiEvent` root). Plus `import 'dart:async';` for `StreamTransformer`. **No** freezed, **no** `part` directive, **no** `build_runner`, **no** error import (this stage emits no `RunErrorEvent` — see Dev Notes §"chunks emits no errors").
  - [x] Export a top-level `StreamTransformer<AgUiEvent, AgUiEvent> chunksStage` (a value or zero-arg factory). It is **stateful per subscription** — it tracks the currently-open synthesized `toolCallId` and `messageId` to distinguish first-vs-subsequent chunks and to know when to emit the `END`. Build it via `StreamTransformer.fromBind` over a per-subscription state object (Dev Notes §"How to build a stateful StreamTransformer — and the cancellation trap"). Do **not** use a single shared mutable closure variable across subscriptions.
  - [x] Implement F.2 synthesis exactly (Dev Notes §"chunks stage — the F.2 synthesis algorithm"): first `TOOL_CALL_CHUNK` for an id → `ToolCallStartEvent(toolCallId, toolCallName, parentMessageId)` (+ a `ToolCallArgsEvent` if that first chunk *also* carries a non-null `delta`, per Design Decision 3 — never drop a delta); each subsequent → `ToolCallArgsEvent(toolCallId, delta)`; the **next non-chunk event for that id, a chunk for a *different* id, or stream-done** flushes a `ToolCallEndEvent(toolCallId)` *before* the triggering event passes through. Mirror for `TEXT_MESSAGE_CHUNK` → `TextMessageStartEvent(messageId, role)` / `TextMessageContentEvent(messageId, delta)` / `TextMessageEndEvent(messageId)`.
  - [x] Handle the **un-synthesizable chunk** edge: a `*_CHUNK` whose keying id (`toolCallId` / `messageId`) is `null` cannot open or extend a call. Per Design Decision 4, **drop it silently** (it carries no addressable payload) — the chunks stage emits no `RunErrorEvent`; protocol-shape policing is verify's job. Cover with a test.
  - [x] Non-chunk events pass through **unchanged** (identity) except for the END-flush they may trigger. The stage must `close` cleanly: on `onDone`, flush any still-open `END`(s) then close the sink.

- [x] **Task 2 — Create the `verify` stage** (AC: #1, #3)
  - [x] New file `packages/koel_core/lib/src/pipeline/verify_stage.dart`. Imports: `dart:async`, `../event/ag_ui_event.dart`, `../error/koel_error.dart` (for `ProtocolError`), `../error/koel_error_code.dart` (for `KoelErrorCode.protocolMalformed`). No json_patch import needed — `StateDeltaEvent.patches` is already a decoded `List<JsonPatchOp>` (validity of *individual ops* was enforced at decode time in 2.4/2.6; verify only checks the F.1 cross-event/emptiness rules — Dev Notes §"verify — what's already guaranteed vs. what verify adds").
  - [x] Export a top-level `StreamTransformer<AgUiEvent, AgUiEvent> verifyStage`. Stateful per subscription: it tracks open `TOOL_CALL_START` ids to validate `END`/`ARGS` envelopes.
  - [x] Implement every F.1 rule (Dev Notes §"verify stage — the F.1 rule table"). On a violation: **drop the offending event** and **emit `RunErrorEvent(error: ProtocolError(message: …, code: KoelErrorCode.protocolMalformed, eventType: <wire type>))`** in its place. Do **not** throw. Valid events pass through unchanged.
  - [x] Rules to implement + test: (a) `ToolCallEndEvent` with no matching open `ToolCallStartEvent` id → drop+error; (b) `ToolCallArgsEvent` outside a START/END envelope (no open id) → drop+error; (c) `StateDeltaEvent` with empty `patches` → drop+error; (d) `TextMessageStartEvent`/`TextMessageContentEvent`/`TextMessageEndEvent` with an empty `messageId` → drop+error (the typed events guarantee the field *exists*, but an empty-string id is still a protocol violation — Dev Notes); (e) `ReasoningEncryptedValueEvent` whose `encryptedValue` bytes do not round-trip to `encryptedValueBase64` → drop+error.

- [x] **Task 3 — Create the `apply` stage (identity now; reducer-fold deferred)** (AC: #1)
  - [x] New file `packages/koel_core/lib/src/pipeline/apply_stage.dart`. Import only `dart:async` + `../event/ag_ui_event.dart`.
  - [x] Export a top-level `StreamTransformer<AgUiEvent, AgUiEvent> applyStage` that is the **identity transformer** (every event passes through unchanged, order preserved). This is C.1 step 3's "if a reducer is registered" path with **no reducer registered** — the only state koel can fold in 2.11, since `ChatState`/`ChatStateReducer` are Story 2.12.
  - [x] **Contract dartdoc must state** (Dev Notes §"apply + transform dartdoc obligations"): this stage's runtime job is to fold each event into `ChatState` via the registered `ChatStateReducer` and resolve `StateConflict` via the registered resolver (Addendum C.1 step 3 / F.3); that fold is wired by `KoelClient` once `ChatStateReducer` (Story 2.12) + `StateConflictResolver` (Story 2.13) exist; with no reducer the stage is a pure pass-through. The dartdoc is the seam that tells 2.12/2.14 where the fold lands — it is **not** a TODO comment; write it as the stage's permanent contract.

- [x] **Task 4 — Create the `transform` stage (identity over an empty transform list now)** (AC: #1)
  - [x] New file `packages/koel_core/lib/src/pipeline/transform_stage.dart`. Import only `dart:async` + `../event/ag_ui_event.dart`.
  - [x] Export `transformStage`. Per Addendum F.4, this stage applies consumer-registered `StreamTransformer<AgUiEvent, AgUiEvent>` instances in registration order. No consumer transforms exist until `KoelClient.transforms` (Story 2.14), so the 2.11 deliverable is the **identity transformer** (the empty-list composition). Dartdoc states the F.4 contract + that registration is `KoelClient`'s job (Story 2.14). Keep it a top-level value matching the other three stages — do **not** invent a `transforms`-list parameter or registry here (that API lives on `KoelClient`, Story 2.14; adding it now is a one-way-door built ahead of its definition).

- [x] **Task 5 — Compose + lock the pipeline** (AC: #1, #4)
  - [x] Decide the composition seam (Dev Notes §"Where composition lives"). **Recommended:** a small top-level helper in a new `pipeline.dart` (e.g. `Stream<AgUiEvent> runPipeline(Stream<AgUiEvent> events) => events.transform(chunksStage).transform(verifyStage).transform(applyStage).transform(transformStage);`) so the **locked order** lives in exactly one place and AC4's "swap breaks a test" assertion targets it. Do **not** wire this into `KoelClient` (Story 2.14) — `pipeline.dart` is a pure function over a `Stream<AgUiEvent>`, matching architecture §"the 4 stages are pure functions invoked by `KoelClient`."
  - [x] Order-lock test: assert the fixed order is `chunks → verify → apply → transform`, and that **swapping any adjacent pair breaks at least one behavioural test** (Dev Notes §"Order-lock — how to make the swap actually fail"). The load-bearing pair is chunks↔verify: chunks must run **before** verify, because verify checks the START/END pairing that chunks *creates* (Addendum C.1 §1) — a sequence of `TOOL_CALL_CHUNK`s passed verify-first would have no synthesized START and verify would reject the synthesized END.

- [x] **Task 6 — Integration sweep test** (AC: #4)
  - [x] New `packages/koel_core/test/pipeline/pipeline_test.dart` (+ per-stage `chunks_stage_test.dart`, `verify_stage_test.dart`, mirroring `lib/src/pipeline/` path-for-path per architecture §"Tests mirror `lib/src/`").
  - [x] Build **purpose-built, pipeline-valid** fixtures for the chunk/verify sequences (Dev Notes §"Do NOT blindly reuse the 2.8 full_event_sweep.jsonl"). The 2.8 `full_event_sweep.jsonl` carries **all-null** `TOOL_CALL_CHUNK`/`TEXT_MESSAGE_CHUNK` lines and an **empty-patch** `STATE_DELTA` — i.e. exactly the events 2.11's chunks-drop + verify-reject rules act on — so feeding it raw will (correctly) drop those three lines and emit verify errors. For AC4's "full 28-event sweep flows through producing only canonical events," construct a sweep whose chunk lines carry real ids and whose `STATE_DELTA` carries a non-empty op, so the canonical-output assertion is meaningful. You may load the 2.8 fixture to assert the *drop/error* behaviour separately.
  - [x] Assert: every output event is a concrete `AgUiEvent` subtype (no synthesis leaves a raw `*_CHUNK` in the canonical output for a *synthesizable* chunk); the chunk sequences became START/ARGS|CONTENT/END triplets; verify errors appear as `RunErrorEvent` in place of dropped events; nothing throws; the stream closes.

- [x] **Task 7 — Quality gates** (AC: all)
  - [x] `dart test` (from `packages/koel_core`) → all green (existing 446 + new). No regressions.
  - [x] `melos run analyze` → 0 issues (workspace-wide, all 10 packages).
  - [x] `dart format --set-exit-if-changed .` → clean.
  - [x] Coverage on `lib/src/pipeline/` ≥ 90% line + branch (N-12). The identity `apply`/`transform` stages are near-trivial; `chunks`/`verify` carry the real branch coverage — every F.1 rule arm and every F.2 first/subsequent/end branch must be exercised.
  - [x] Confirm **untouched**: `lib/koel_core.dart` barrel (export sweep is Story 2.15), `pubspec.yaml` (no new dependency — `dart:async` is core), `build.yaml`, every event/error/json_patch/agent file. No `*.freezed.dart`/`*.g.dart` generated (no freezed types added).

### Review Findings

_Adversarial code review 2026-05-30 (Blind Hunter + Edge Case Hunter + Acceptance Auditor). Resolved: 3 patch, 1 defer, 8 dismissed as noise (1 decision-needed → patch, option 1: synthesize reasoning chunk)._

- [x] [Review][Patch] **`REASONING_MESSAGE_CHUNK` is not synthesized — contradicts the committed 2.7 type contract.** `chunks_stage.dart` only switches on `ToolCallChunkEvent`/`TextMessageChunkEvent`; a `ReasoningMessageChunkEvent` falls into `default:` and leaks through **raw**. But `reasoning_events.dart:124-128` (shipped 2.7) states verbatim: "the `chunks` pipeline stage (Story 2.11) expands [`REASONING_MESSAGE_CHUNK`] into `ReasoningMessageStart→Content→End` … the expansion is Story 2.11." Net effect: raw `REASONING_MESSAGE_CHUNK` reaches consumers, breaking AC4's "only canonical events" guarantee for that family. **Resolution (decision → option 1):** add a `ReasoningMessageChunkEvent` case to the chunks state machine, mirroring text (keyed by `messageId`, default `role: 'reasoning'` since reasoning chunks carry no role), with a synthesis test + an AC4-sweep assertion. [chunks_stage.dart:54-116 ↔ reasoning_events.dart:124-128] (source: edge)
- [x] [Review][Patch] **`chunksStage` dartdoc overclaims verify rejects "empty id" — only empty `messageId` (text) is guarded.** The dartdoc (lines 36-39) delegates "empty id" rejection generically to verify, but per Addendum F.1 verify only guards `TEXT_MESSAGE_*` empty `messageId`. An empty-string `toolCallId` is reachable on the wire (`{"toolCallId":""}` → `""`, not `null`, so the chunks null-guard misses it), and `_VerifyStage`'s `ToolCallStartEvent` arm does an unconditional `_openToolCalls.add('')` with no `isEmpty` check (asymmetric with the text arms) — producing a phantom valid empty-id tool envelope. Spec-faithful fix: correct the dartdoc wording to "empty `messageId`". (Open design question, not required by F.1: whether to also add an empty-`toolCallId` verify rule for symmetry.) [chunks_stage.dart:36-39, verify_stage.dart:189-191] (source: blind+edge)
- [x] [Review][Patch] **Story-record test-count inconsistency.** Completion Notes say AC3 has "13 tests"; the actual `verify_stage_test.dart` has 12 (the Debug Log correctly says 12). Cosmetic — fix the record. [2-11 story Completion Notes] (source: auditor)
- [x] [Review][Defer] **`buildStage` does not guard exceptions thrown inside `stage.onEvent`** — a synchronous throw escapes the `onData` callback to the zone (not forwarded via `controller.addError`), and the controller is never closed → consumer hangs. Latent today (`chunks`/`verify` provably never throw — verify converts to `RunErrorEvent` values, chunks is null-safe), but becomes live in 2.12 when `applyStage` folds via a reducer (`JsonPatch.apply` throws `ProtocolError`). [stage_support.dart:417-419] — deferred, becomes actionable in Story 2.12 (source: blind+edge)

## Dev Notes

### What this story is, in one paragraph
You are building the **four-stage event pipeline** — the spine of `koel_core` that turns a raw `Stream<AgUiEvent>` (as delivered by `AbstractAgent.run` / the interceptor chain) into the **canonical** event stream every consumer sees. Four pure `StreamTransformer<AgUiEvent, AgUiEvent>` stages compose in a **locked** order: **chunks** (synthesize the streaming `*_CHUNK` convenience shapes into START/CONTENT|ARGS/END triplets, F.2) → **verify** (cross-event protocol sanity; drop-and-`RunErrorEvent` on violation, F.1) → **apply** (fold into `ChatState` via the reducer — *identity until 2.12*) → **transform** (consumer-supplied transformers — *identity until 2.14*). Stage internals are **pure** (no I/O) and **errors surface in-stream**, never as a `throw` (the 2.9 invariant). This is the first `koel_core` subsystem that is *stateful per stream* (chunks/verify track open ids) and the first to compose `StreamTransformer`s — so the load-bearing craft is correct stateful-transformer construction with clean cancellation/close, not codec round-trips. [Source: epic-2 §"Story 2.11"; addendum.md C.1 :515-528, F.1 :630-638, F.2 :640-648, F.3 :650-652, F.4 :654-656; architecture.md :792-796, :1047-1050, :1066, :1082]

### Scope: which stages are real now (RESOLVED — Design Decision 1)
| Stage | 2.11 deliverable | Why |
|---|---|---|
| **chunks** | **Full real logic** (F.2 synthesis, stateful) | Every dep exists: `*ChunkEvent`/`*StartEvent`/`*ArgsEvent`/`*ContentEvent`/`*EndEvent` shipped in 2.5/2.6. |
| **verify** | **Full real logic** (all F.1 rules → drop + `RunErrorEvent(ProtocolError)`) | Deps exist: events (2.5–2.8), `ProtocolError`/`KoelErrorCode` (2.3), decoded `JsonPatchOp` lists (2.4/2.6). |
| **apply** | **Identity transformer** (the "no reducer registered" path, C.1 §3) | The fold target — `ChatState` + `ChatStateReducer` — is **Story 2.12**; `StateConflictResolver` is **2.13**. Building the fold now needs types that do not exist → vestigial. |
| **transform** | **Identity transformer** (empty consumer-transform list, F.4) | Consumer transforms register via `KoelClient.transforms` — **Story 2.14**. No registry exists to apply. |

This mirrors **2.10 exactly**: ship the deliverables whose dependencies exist; for the not-yet-existent machinery (there the dispatcher/`KoelClient`; here the reducer/conflict-resolver/transform-registry) ship **nothing production** — the stage *files* exist (AC1 requires all four, and they lock the composition order), but their bodies are pure pass-throughs until their real types land. The "pull to make it real" is the bug 2.9/2.10 warned about — resist it. `apply`/`transform` being identity is **not** vestigial: they are required by AC1, they lock positions 3 and 4 (AC4's order-lock), and identity is their *correct, spec-defined* behaviour with nothing registered (C.1 §3 "if a reducer is registered"; F.4 "registered … instances"). The vestigial trap is building a reducer-fold engine or a transform registry inside them now.

### Files you will touch
| Path | Action | Note |
|------|--------|------|
| `packages/koel_core/lib/src/pipeline/chunks_stage.dart` | **NEW** | `StreamTransformer<AgUiEvent,AgUiEvent> chunksStage` — F.2 synthesis, stateful. ~90-130 lines incl. dartdoc. |
| `packages/koel_core/lib/src/pipeline/verify_stage.dart` | **NEW** | `verifyStage` — F.1 rules → drop + `RunErrorEvent(ProtocolError)`, stateful envelope tracking. ~80-120 lines. |
| `packages/koel_core/lib/src/pipeline/apply_stage.dart` | **NEW** | `applyStage` — identity now; dartdoc carries the reducer-fold contract for 2.12/2.14. ~20-30 lines (mostly dartdoc). |
| `packages/koel_core/lib/src/pipeline/transform_stage.dart` | **NEW** | `transformStage` — identity now; dartdoc carries the F.4 contract for 2.14. ~15-25 lines. |
| `packages/koel_core/lib/src/pipeline/pipeline.dart` | **NEW** | `runPipeline(Stream<AgUiEvent>)` — the single place the locked order lives. ~15-25 lines. |
| `packages/koel_core/test/pipeline/chunks_stage_test.dart` | **NEW** | F.2 first/subsequent/end, mirror for text, null-id drop. |
| `packages/koel_core/test/pipeline/verify_stage_test.dart` | **NEW** | every F.1 rule + the pass-through happy path. |
| `packages/koel_core/test/pipeline/pipeline_test.dart` | **NEW** | composition, order-lock (swap-breaks-a-test), 28-event integration sweep. |

**Do NOT touch:** `lib/koel_core.dart` (barrel — frozen until Story 2.15), `pubspec.yaml`, `build.yaml`, any event/error/json_patch/agent/input file. Every type you need already exists. Adding a dependency, a freezed annotation, a reducer, a `ChatState`, a `StateConflictResolver`, a transform registry, or a `KoelClient` is a smell.

### How to build a stateful StreamTransformer — and the cancellation trap
The chunks and verify stages must hold **per-subscription** state (open ids). The koel-correct construction is `StreamTransformer.fromBind`, which gives each subscription its own bind closure (so two concurrent runs don't share one stage's id-tracking):

```dart
final StreamTransformer<AgUiEvent, AgUiEvent> chunksStage =
    StreamTransformer.fromBind((source) {
  // per-subscription state captured here, fresh on every bind:
  String? openToolCallId;
  String? openMessageId;
  // ... return a stream derived from `source` that emits 0..n events per input
});
```

**Why not the interceptor's `StreamTransformer.fromHandlers`?** `fromHandlers` is for *stateless 1→{0,1,n}* mapping with no need to flush on done with held state. The 2.9 `InterceptorChain.proceed` used `fromHandlers` precisely because it only needed a stateless `handleError`. Here you need (a) per-subscription state and (b) a **flush on `onDone`** (emit the trailing synthesized `END` for any still-open chunk before closing). `fromBind` returning a stream built from a `StreamController` (or an `async*` generator) is the clean fit.

**The cancellation trap (read the 2.9 note in `interceptor.dart`):** the interceptor's `proceed` deliberately avoids `yield*`/`await for` because the former routes errors past `catch` and the latter "strands an in-flight `cancel()` on a pending `await`." For the chunks/verify stages you are **not** catching stream errors (chunks emits none; verify converts *event content* to `RunErrorEvent` values, not stream errors) — so an `async*` generator over `source` is acceptable **if** you respect cancellation: an `async*` that does `await for (final e in source)` cancels the upstream subscription when the consumer cancels, which is correct here (no pending non-source `await` to strand). If you prefer a `StreamController`-backed bind, forward `subscription.cancel()` in the controller's `onCancel` and `pause`/`resume` in `onPause`/`onResume` so backpressure (N-6, owned by `koel_http`) still propagates through your stage. **Pick one idiom, document it, and test cancellation** (subscribe, cancel mid-stream, assert no further emissions + upstream cancelled). Preserve the **single-subscription** model — the pipeline runs over `AbstractAgent.run`'s single-subscription stream (architecture §4); do not turn it into a broadcast stream.

### chunks stage — the F.2 synthesis algorithm
Per Addendum F.2 (runs **before** verify). Wire field names: `toolCallId`, `toolCallName`, `parentMessageId`, `delta` (tool); `messageId`, `role`, `delta` (text). Confirmed against the typed shapes in `tool_call_events.dart` / `text_message_events.dart` (all `*ChunkEvent` fields are nullable optionals).

**Tool-call chunks** (track `openToolCallId`):
- Incoming `ToolCallChunkEvent` with `toolCallId == X`, **no open call** → emit `ToolCallStartEvent(toolCallId: X, toolCallName: e.toolCallName ?? '', parentMessageId: e.parentMessageId)`; set `openToolCallId = X`. **If that same chunk also carries a non-null `delta`** → immediately also emit `ToolCallArgsEvent(toolCallId: X, delta: e.delta!)` (Design Decision 3 — never silently drop a first-chunk delta).
- Incoming `ToolCallChunkEvent` with `toolCallId == X` **while X is open** → emit `ToolCallArgsEvent(toolCallId: X, delta: e.delta ?? '')`.
- **END trigger** for an open `X`: the next event that is *not* a `ToolCallChunkEvent` for `X` — i.e. a non-chunk event, or a chunk for a different id, or stream-done → emit `ToolCallEndEvent(toolCallId: X)` **first**, clear `openToolCallId`, **then** let the triggering event proceed (it may itself open a new call / be synthesized).
- Incoming `ToolCallChunkEvent` with `toolCallId == null` → **drop** (Design Decision 4 — un-addressable).

**Text-message chunks** (track `openMessageId`): identical structure → `TextMessageStartEvent(messageId, role: e.role ?? 'assistant')` / `TextMessageContentEvent(messageId, delta)` / `TextMessageEndEvent(messageId)`; null `messageId` → drop.

**Interleaving:** a tool-call chunk stream and a text-message chunk stream can be open simultaneously (different id namespaces) — track both `openToolCallId` and `openMessageId` independently. A real `TOOL_CALL_START`/`TEXT_MESSAGE_START` (non-chunk) arriving while a synthesized call of the *same* family is open is an END-trigger for the open synthesized call, then passes through. **On `onDone`, flush both** still-open ENDs (order: deterministic — pick tool-then-text or insertion order and document it) before closing.

> **`role`/`toolCallName` defaulting:** the typed `*StartEvent`s require non-null `role`/`toolCallName`, but the chunk shapes make them optional. Default to `'assistant'` (text role) / `''` (tool name) when the chunk omits them — synthesis must produce a *valid* typed event. This is a synthesis convenience, not a wire contract; document it. (A first chunk that omits `toolCallName` is unusual but legal on the wire.)

### chunks emits no errors
The chunks stage **never** emits a `RunErrorEvent` — it synthesizes or drops, full stop. Protocol-shape policing (orphan END, args-outside-envelope, empty messageId) is **verify's** job, and verify runs *after* chunks precisely so it sees the synthesized START/END pairs (C.1 §1-2). Keep the two concerns separate: chunks = shape transformation; verify = shape validation. This is why `chunks_stage.dart` needs no error import.

### verify stage — the F.1 rule table
Per Addendum F.1 (runs **after** chunks). On any violation: **drop the offending event** and emit in its place `RunErrorEvent(error: ProtocolError(message: '<human, sentence-cased, no trailing period>', code: KoelErrorCode.protocolMalformed, eventType: '<WIRE_TYPE>'))`. Never throw. `ProtocolError` is the 2.3 type and carries an `eventType` field built for exactly this (`error/koel_error.dart` :"names the wire event involved"). Valid events pass through unchanged.

| F.1 rule | Detection | State needed |
|---|---|---|
| `TOOL_CALL_END` without matching `TOOL_CALL_START` (same id) | `ToolCallEndEvent` whose `toolCallId` is not in the open-start set | track open `ToolCallStartEvent` ids; `START` adds, valid `END` removes |
| `TOOL_CALL_ARGS` outside a START/END envelope | `ToolCallArgsEvent` whose `toolCallId` is not in the open-start set | same open-start set |
| `STATE_DELTA.patches` empty (or invalid ops) | `StateDeltaEvent` with `patches.isEmpty` | none — per-event. *Invalid ops can't reach here:* `JsonPatchOp.fromJson` already rejected malformed ops at decode (2.4/2.6), so verify only checks **emptiness** (Dev Notes §"what's already guaranteed"). |
| `TEXT_MESSAGE_*` without a `messageId` | `TextMessageStartEvent`/`ContentEvent`/`EndEvent` with `messageId.isEmpty` | none — per-event. The typed field is non-null, so "without" = empty string. |
| `REASONING_ENCRYPTED_VALUE` bytes/base64 mismatch | `ReasoningEncryptedValueEvent` where `base64Encode(encryptedValue) != encryptedValueBase64` … (see note) | none — per-event |

> **REASONING_ENCRYPTED_VALUE check — be precise.** The event preserves the original wire base64 *verbatim* and decodes bytes from it (`reasoning_events.dart`: `toJson` echoes `encryptedValueBase64` and "**never** re-encodes" because `base64Encode(base64Decode(s))` is not always identity — padding/whitespace canonicalization differs). So the verify mismatch test is: do the **bytes round-trip back to the same base64 the event holds**? Use `base64Decode(encryptedValueBase64)` and compare to `encryptedValue` **byte-for-byte** (lengths + each byte), OR compare `base64Encode(encryptedValue)` against a *canonical re-encode* of `encryptedValueBase64` — pick the comparison that does not false-positive on a non-canonical-but-valid wire string. The honest invariant F.1 wants: the bytes the SDK will replay (`encryptedValue`) decode from the string it will echo (`encryptedValueBase64`). The 2.7 codec already guarantees this on the decode path; verify is the defense-in-depth re-check for events constructed off the wire (e.g. by a buggy adapter). Document the exact comparison you choose and why it can't false-positive.

### verify — what's already guaranteed vs. what verify adds
Do **not** re-validate what the typed layer already enforces — that's duplicated logic and dead branches that hurt coverage honesty:
- Individual RFC 6902 op validity: enforced by `JsonPatchOp.fromJson` at decode (2.4). `StateDeltaEvent.patches` is a `List<JsonPatchOp>` of *already-valid* ops. Verify checks **emptiness only**.
- Required-field presence on typed events (`messageId`, `toolCallId`, `delta`): the `fromJson` factories `_requireString` these (throwing `ProtocolError` at decode). By the time an event reaches verify it is a constructed typed instance — its required fields are non-null. The F.1 "without a messageId" rule therefore targets the **empty-string** degenerate (a wire `"messageId": ""` passes `_requireString` but is a protocol violation). Test with `messageId: ''`.
- Wire-shape sanity (raw JSON structure): enforced in the SSE parser in `koel_http` (C.1: "Wire-format sanity … is enforced inside the SSE parser … **not here**"). Verify is **cross-event** sanity over already-typed events, not JSON validation.

### apply + transform dartdoc obligations
These two stages are thin now but their **dartdoc is the contract** 2.12/2.14 build against — write it as permanent contract prose, not as a `// TODO`:
- **`applyStage`**: "Folds each event into `ChatState` via the registered `ChatStateReducer` (Addendum F.3) and resolves any `StateConflict` via the registered `StateConflictResolver` (C.1 §3). The reducer is pure — it rebuilds `ChatState` each call and never mutates `state.messages`/`state.state`/`state.reasoningEcho` (keeps `ChatState` const-comparable / Riverpod-friendly). With no reducer registered this stage is a pure pass-through; `KoelClient` (Story 2.14) injects the reducer wired from `ChatStateReducer` (Story 2.12)." State the event-identity guarantee: apply does **not** rewrite the event stream — the fold is a side accumulation surfaced to `ChatSession.stream` as `ChatState`; events flow through to `transform` + subscribers unchanged (F.4: "transforms see the post-reduce stream" — still `Stream<AgUiEvent>`).
- **`transformStage`**: "Applies consumer-registered `StreamTransformer<AgUiEvent, AgUiEvent>` instances in registration order, *after* `apply`, so transforms see the post-reduce stream (Addendum F.4 — PII redaction, translation, custom telemetry, A/B tagging). Registration is via `KoelClient.transforms` (Story 2.14); with none registered this stage is identity."

### Where composition lives
`pipeline.dart` exports a pure `Stream<AgUiEvent> runPipeline(Stream<AgUiEvent> events)` (name it to match the kernel's vocabulary; `runPipeline`/`applyPipeline` are both fine — pick one). It is the **single** site of the locked order `events.transform(chunksStage).transform(verifyStage).transform(applyStage).transform(transformStage)`. Keeping the order in one function (not scattered at call sites) is what makes AC4's order-lock testable and what `KoelClient` (2.14) will call. Do not import `KoelClient` here — it doesn't exist, and the pipeline is deliberately transport/persistence/UI-agnostic (architecture §"Stages do not know about transport, persistence, or UI").

### Order-lock — how to make the swap actually fail
AC4: "swapping any two stages breaks at least one test." Make this real, not ceremonial:
- **chunks↔verify (the load-bearing pair):** feed a valid `TOOL_CALL_CHUNK`→`TOOL_CALL_CHUNK`→(non-chunk) sequence. Correct order (chunks→verify): synthesizes START/ARGS/END, all pass verify → canonical triplet out, no error. Swapped (verify→chunks): verify sees raw `TOOL_CALL_CHUNK`s (no synthesized START), and when chunks later synthesizes an END there's no START in verify's (already-passed) view — the swapped pipeline cannot produce the clean triplet. Write the test so the **correct** order asserts "triplet, zero `RunErrorEvent`," which a swapped composition fails.
- For the apply/transform identity stages, an order swap is observationally inert *today* (both identity), so do not fabricate a brittle assertion there — document that the apply/transform order-lock is enforced by their **position contract** + the chunks↔verify behavioural test, and becomes behaviourally testable in 2.12/2.14 when those stages gain logic. (Honesty over ceremony — koel bans tests that assert nothing. The binding, testable order constraint in 2.11 is chunks-before-verify.) If you want a structural guard, a test that asserts `runPipeline` applies the four stages in the named order via a spy/identity-tagging transformer is acceptable, but the chunks↔verify behavioural test is the one that matters.

### Do NOT blindly reuse the 2.8 `full_event_sweep.jsonl`
The existing `test/event/full_event_sweep.jsonl` (28 lines, one per type) was built for **deserialization** coverage, not pipeline-validity. Three of its lines are *exactly* the degenerate inputs 2.11's rules act on:
- L9 `{"type":"TEXT_MESSAGE_CHUNK"}` and L14 `{"type":"TOOL_CALL_CHUNK"}` — **all-null** → chunks **drops** them (Design Decision 4).
- L16 `{"type":"STATE_DELTA","delta":[]}` — **empty patches** → verify **drops + errors**.

So piping the 2.8 fixture through `runPipeline` will (correctly) yield fewer-than-28 canonical events plus a verify `RunErrorEvent` — which is a *fine thing to assert in a dedicated "degenerate inputs" test*, but is **not** the "full 28-event sweep flows through producing only canonical events" AC4 asks for. For the AC4 happy-path sweep, author a **new** fixture (inline list or a new `.jsonl`) whose chunk lines carry real ids+deltas and whose `STATE_DELTA` carries a non-empty op, so "only canonical events, correctly synthesized" is a meaningful assertion. Keep the deserializer's all-types coverage as the 2.8 test's job; 2.11's job is *pipeline behaviour*.

### Error idiom (the kernel invariant — architecture §5, generalized from 2.9)
No raw `throw` crosses a koel boundary. The pipeline's only error surface is **in-stream `RunErrorEvent(ProtocolError)`** emitted by verify. Concretely: a stage must never let an exception escape its transformer — verify *converts protocol violations to RunErrorEvent values* (it does not throw, and it does not catch *stream* errors; an upstream stream error is the interceptor chain's concern — 2.9 — and passes through the pipeline untouched). This is the same invariant 2.3–2.10 upheld; here it manifests as "verify emits a value, never throws." Build `ProtocolError` via its `const` factory: `ProtocolError(message: …, code: KoelErrorCode.protocolMalformed, eventType: …)`. [Source: koel_error.dart; addendum F.1; architecture §5 "No silent catches; errors surface in-stream as RUN_ERROR"]

### Project structure & conventions
- Files land exactly where architecture pencils them: `lib/src/pipeline/{chunks,verify,apply,transform}_stage.dart` ([architecture.md:792-796](../planning-artifacts/architecture.md)), feature map F-A11 → `koel_core/lib/src/pipeline/` ([architecture.md:1001](../planning-artifacts/architecture.md)). `pipeline.dart` (the composer) is a koel addition at the same level — no structural variance.
- Naming: stage transformers are top-level `lowerCamelCase` values (`chunksStage`, `verifyStage`, `applyStage`, `transformStage`); `snake_case.dart` filenames. [Source: architecture naming conventions]
- Tests mirror `lib/src/pipeline/` path-for-path under `test/pipeline/`. [Source: architecture.md:1096]
- No silent catches; pure stage internals (no I/O). [Source: architecture.md :1047-1050, §5]

### Data-flow context (where the pipeline sits)
Runtime order: `backend SSE → SseParser → typed Stream<AgUiEvent> → interceptor chain → **pipeline (chunks→verify→apply→transform)** → subscribers fire (observation-only) → ChatSession.stream emits ChatState → KoelChatController → widgets` ([architecture.md:1080-1087](../planning-artifacts/architecture.md)). The pipeline consumes the **post-interceptor** stream and produces the **pre-subscriber** canonical stream. In 2.11 nothing downstream of the pipeline exists yet (subscribers fire from `KoelClient`, 2.14); the pipeline is a standalone pure `Stream→Stream` function, tested in isolation. The interceptor chain (2.9) already wraps error-to-`RunErrorEvent` for *thrown* failures; the pipeline adds the *protocol-violation*-to-`RunErrorEvent` surface (verify). They are complementary, not overlapping.

## Previous Story Intelligence
From the koel_core lineage 2.1–2.10:
- **2.9 (`Interceptor`/`InterceptorChain`)** is the closest *mechanism* sibling — it is the codebase's reference for **`StreamTransformer` construction + the no-throw, error-as-value, cancellation-safe idiom**. Re-read `lib/src/agent/interceptor.dart` before starting: `proceed` uses `StreamTransformer.fromHandlers` for a *stateless* error-to-value conversion and documents *why* `yield*`/`await for` are wrong there. Your chunks/verify stages are *stateful*, so you'll reach for `StreamTransformer.fromBind` instead — but the cancellation discipline (don't strand an in-flight `cancel()`, preserve single-subscription) transfers directly.
- **2.10 (`AgentSubscriber`)** is the closest *process* sibling — its **forward-reference resolution** is the template for AC4 here: when an AC names a later story's component (there pipeline/`KoelClient`; here reducer/conflict-resolver/transforms), build the missing piece as a test double / defer to its real home; ship **nothing vestigial**. 2.10 shipped only `AgentSubscriber` and proved the dispatcher in tests; 2.11 ships only chunks+verify real and the apply/transform stages as identity, proving fold/transform belong to 2.12/2.14.
- **2.5/2.6 (event subtypes)** shipped the exact `*ChunkEvent`/`*StartEvent`/`*ArgsEvent`/`*ContentEvent`/`*EndEvent` types this story synthesizes between, and their dartdocs **already forward-reference 2.11** ("the expansion … and the verify rule … are Story 2.11" in `tool_call_events.dart` / `text_message_events.dart`). The chunk events' all-optional fields are by design for your synthesis input.
- **2.4 (JSON Patch)** shipped `JsonPatch.apply` + the `JsonPatchOp` union that `StateDeltaEvent.patches` already holds as *validated* ops — so verify checks emptiness, not op validity. `JsonPatch.apply` throwing `ProtocolError` is the *reducer's* (2.12) concern, not verify's.
- **2.3 (`KoelError`)** shipped `ProtocolError(message, code, cause?, eventType?)` + `KoelErrorCode.protocolMalformed` — the exact type/code verify emits. No new error type.
- **Recurring SF-1 discipline (2.3–2.10):** no raw throw / silent catch crosses a koel boundary. Here: verify emits `RunErrorEvent` values; no stage throws. [Source: 2-9/2-10 stories; 2-5/2-6 event files; 2-4/2-3]

## Git Intelligence Summary
Recent commits: `feat(story-2.10)` (AgentSubscriber — behavioral, 2 files, no freezed), `feat(story-2.9)` (Interceptor — the StreamTransformer/error-idiom precedent), `feat(story-2.5..2.8)` (event codecs — the synthesis source/target types). The relevant precedents are **2.9** (transformer construction + no-throw stream idiom) and **2.10** (forward-reference deferral, no vestigial code). The 2.5–2.8 codec commits are **not** a template (no freezed/registry work here — the pipeline adds no types). Expect a **larger but still surgical** footprint than 2.10: ~5 new lib files (4 stages + composer) + ~3 test files; **zero** modified production files; **zero** regenerated artifacts; **zero** new deps. Commit message: `feat(story-2.11): four-stage event pipeline`. [Source: `git log` 5c3e56a/37e0f97/c4c6b60]

## Latest Tech Information
- **`StreamTransformer.fromBind`** (`dart:async`) — the idiom for a **stateful** transformer: `StreamTransformer<S,T>.fromBind((Stream<S> source) => Stream<T> …)` runs the bind closure **once per subscription**, giving fresh per-stream state (open ids). Prefer this over a top-level closure-captured `var` (which would leak state across concurrent runs). Pair with a `StreamController` (forward `onListen`/`onCancel`/`onPause`/`onResume` to the source subscription to preserve backpressure + cancellation) **or** an `async*` generator over `await for (final e in source)` (cancellation-safe here since there's no non-source pending `await`). [Source: dart:async StreamTransformer API; interceptor.dart 2.9 cancellation note]
- **`StreamTransformer.fromHandlers`** — the *stateless* variant (`handleData`/`handleError`/`handleDone`); used by 2.9's `proceed`. Works for verify only if you thread state via a captured-per-bind object — but `fromBind` is cleaner when you need `onDone` flush with held state (chunks). Choose deliberately; document the choice. [Source: dart:async]
- **`base64Encode`/`base64Decode`** (`dart:convert`) — for the REASONING_ENCRYPTED_VALUE verify check. Note `base64Encode(base64Decode(s))` is **not** guaranteed identity (padding/whitespace), which is why 2.7 preserves the wire string verbatim — design the verify comparison to avoid that false-positive (Dev Notes §"REASONING_ENCRYPTED_VALUE check — be precise"). [Source: reasoning_events.dart 2.7; dart:convert]
- **Dart 3 sealed-class `switch`** over `AgUiEvent` — exhaustive with a `default:`/`_` arm (satisfies `koel_lints`' `exhaustive_switch_must_have_default` and genuinely homes the events a stage doesn't act on). No version change. SDK `>=3.11.0 <4.0.0`. [Source: ag_ui_event.dart sealed root; Dart 3 patterns]
- **No new dependency.** `dart:async` + `dart:convert` are core. `koel_core` has only `freezed_annotation`/`json_annotation` (runtime) — unchanged. [Source: pubspec.yaml]

### Project Structure Notes
- New files land exactly where architecture.md:792-796/:1001 place them, plus a sibling `pipeline.dart` composer. No barrel change (Story 2.15), no pubspec change, no `build.yaml` change.
- AC4's "reducer state folded"/"transform" are forward-references to Stories 2.12/2.13/2.14 — satisfied here by shipping `apply`/`transform` as their spec-defined identity (no-reducer / no-transforms) behaviour and proving event-stream canonicalness + order-lock now. Known spec-vs-sequencing drift, identical in kind to 2.10's "pipeline/KoelClient" and 2.9's "MockAgent" forward-references — not a structure conflict.

### References
- [epic-2 Story 2.11 spec + ACs](../planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md)
- [addendum.md C.1 :515-528 (4-stage pipeline, locked order, interceptors-vs-pipeline-vs-subscribers); F.1 :630-638 (verify rules); F.2 :640-648 (chunk synthesis); F.3 :650-652 (apply/reducer purity); F.4 :654-656 (transform extensibility); C.5 :565-573 (backpressure — koel_http's job, context only)](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md)
- [architecture.md — pipeline file layout :792-796; F-A11 location :1001; pipeline boundary/pure-functions :1047-1050; pipeline-stages-as-chained-StreamTransformer :1066; data flow :1080-1087; tests mirror lib/src :1096; error §5](../planning-artifacts/architecture.md)
- [tool_call_events.dart / text_message_events.dart — `*ChunkEvent` (synthesis input, all-optional) + `*Start/Args/Content/End` (synthesis output); both forward-reference 2.11](../../packages/koel_core/lib/src/event/tool_call_events.dart)
- [state_events.dart — `StateDeltaEvent.patches: List<JsonPatchOp>` (verify checks emptiness); `StateSnapshotEvent`](../../packages/koel_core/lib/src/event/state_events.dart)
- [reasoning_events.dart — `ReasoningEncryptedValueEvent` bytes+base64 (verify round-trip check); 2.7 preserves wire string verbatim](../../packages/koel_core/lib/src/event/reasoning_events.dart)
- [koel_error.dart — `ProtocolError(message, code, cause?, eventType?)`; koel_error_code.dart — `protocolMalformed`](../../packages/koel_core/lib/src/error/koel_error.dart)
- [interceptor.dart — `InterceptorChain.proceed` StreamTransformer + no-throw/cancellation idiom (the mechanism precedent)](../../packages/koel_core/lib/src/agent/interceptor.dart)
- [json_patch.dart — `JsonPatch.apply` throws `ProtocolError` (reducer's concern in 2.12, not verify's); `JsonPatchOp.fromJson` already validated ops](../../packages/koel_core/lib/src/json_patch/json_patch.dart)
- [test/event/full_event_sweep.jsonl — 28-type fixture; do NOT pipe raw through the pipeline for the AC4 happy-path (L9/L14 all-null chunks, L16 empty STATE_DELTA are drop/error inputs)](../../packages/koel_core/test/event/full_event_sweep.jsonl)
- [2-10-agent-subscriber-callback-bag.md — forward-reference deferral template; 2-9-interceptor-chain-framework.md — StreamTransformer/error idiom](2-10-agent-subscriber-callback-bag.md)

### Design decisions (RESOLVED — AC/convention-forced, not open)
Baked in so the dev has zero ambiguity. No confirmation gate.
1. **chunks + verify ship real; apply + transform ship as identity.** The fold target (reducer/`ChatState`, 2.12), conflict resolver (2.13), and transform registry (`KoelClient.transforms`, 2.14) do not exist; building them now is vestigial. Identity is C.1 §3 / F.4's *defined* behaviour with nothing registered. The four files exist (AC1) and lock the composition order (AC4). Mirrors 2.10 shipping only `AgentSubscriber` and deferring the dispatcher. The reducer-fold contract lives in `applyStage`'s dartdoc for 2.12/2.14 to build against.
2. **Composition lives in one `pipeline.dart` `runPipeline(Stream<AgUiEvent>)` function**, not at a call site and not in `KoelClient` (2.14). One site for the locked order → testable order-lock; pure `Stream→Stream`, transport/UI-agnostic per architecture.
3. **A first chunk that carries both an id *and* a `delta` emits START *then* ARGS/CONTENT** (not START alone). F.2 says first→Start, subsequent→Args, but is silent on a first chunk bearing a delta; dropping that delta would lose wire data and break round-trip fidelity (a koel non-negotiable). So: synthesize Start, then immediately Args/Content for the carried delta.
4. **A `*_CHUNK` with a null keying id (`toolCallId`/`messageId`) is dropped silently by chunks** — it cannot open or extend an addressable call, and chunks emits no errors (shape policing is verify's job). The 2.8 sweep's all-null chunk lines exercise this. Covered by a test.
5. **verify emits `RunErrorEvent(ProtocolError(code: protocolMalformed, eventType: <wire>))` and never throws.** Drop the offending event; emit the error value in its place. Generalizes the 2.9 no-throw-crosses-boundary invariant.
6. **verify checks only what the typed layer hasn't already guaranteed** — `STATE_DELTA` emptiness (not op validity — done at decode), empty-string `messageId` (not absence — `_requireString` done at decode), cross-event START/END/ARGS envelopes, and the REASONING bytes↔base64 round-trip. No re-validation of decode-time invariants (dead branches).
7. **Order-lock's binding, testable constraint is chunks-before-verify** (verify needs chunks' synthesized START/END). The apply/transform order is enforced by position contract + becomes behaviourally testable in 2.12/2.14; do not fabricate a hollow swap-assertion on two identity stages.
8. **Stateful stages use `StreamTransformer.fromBind` (per-subscription state), preserve single-subscription + cancellation, and flush open synthesized `END`s on `onDone`.** No broadcast conversion; no stranded `cancel()`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8, 1M context) — via `/agent-flutter-engineer` implement mode.

### Debug Log References

- `dart analyze lib/src/pipeline/` → "No issues found!"
- `dart test test/pipeline/` → **39 passed** (chunks_stage 20, verify_stage 12, pipeline 7). _(Was 35; +4 chunks tests for the reasoning-chunk synthesis patch — code review 2026-05-30.)_
- `dart test` (full koel_core) → **485 passed** (baseline 446 + 39 new). No regressions.
- `melos run analyze` (workspace) → all 10 packages "No issues found!".
- `dart format --set-exit-if-changed lib test` → clean.
- Coverage on `lib/src/pipeline/` → **110/110 lines (100%)** across all 6 files (`stage_support`, `chunks_stage`, `verify_stage`, `apply_stage`, `transform_stage`, `pipeline`); well above N-12's ≥ 90% line + branch.

### Completion Notes List

- **All 4 ACs satisfied.** AC1: all four stage files exist under `lib/src/pipeline/`, each exporting a top-level `StreamTransformer<AgUiEvent, AgUiEvent>` (`chunksStage`/`verifyStage`/`applyStage`/`transformStage`); a fifth `pipeline.dart` exposes `runPipeline` composing them in the locked order. AC2: the chunks stage synthesizes `TOOL_CALL_CHUNK` → Start/Args/End and `TEXT_MESSAGE_CHUNK` → Start/Content/End per F.2, proven by 16 tests. AC3: the verify stage drops + emits `RunErrorEvent(ProtocolError)` for an orphan `TOOL_CALL_END`, args-outside-envelope, empty `STATE_DELTA`, empty `messageId` on each text event, and a REASONING bytes↔base64 mismatch — every F.1 rule tested (12 tests). AC4: a purpose-built full-family sweep flows through to canonical events with verify adding zero errors and chunk shapes synthesized away; the order-lock is proven by an empty-`messageId` chunk that yields 3 errors in correct order vs 0 in the swapped order (`isNot(swapped)`).
- **Scope held exactly per Design Decision 1 — no vestigial code.** `chunks` + `verify` ship full real logic (deps all exist). `apply` + `transform` ship as pure identity (`StreamTransformer.fromBind((events) => events)`) — C.1 §3 / F.4's defined behaviour with no reducer / no transforms registered; their dartdocs carry the reducer-fold (2.12/2.14) and transform-registry (2.14) contracts. No reducer, `ChatState`, `StateConflictResolver`, or transform registry was built.
- **Transformer construction — pivoted from `async*` to explicit `StreamController` (the story's sanctioned alternative).** An initial `async*` + `await for` implementation passed all logic tests but **deadlocked on `subscription.cancel()`** over an idle, open upstream — exactly the "stranded `cancel()`" DD8 forbids (and N-6 backpressure requires deterministic pause/resume). Switched both stateful stages to a shared private `buildStage`/`PipelineStage` helper (`stage_support.dart`) that wires a single-subscription `StreamController` forwarding `onListen`/`onPause`/`onResume`/`onCancel` to the upstream subscription. Cancellation, pause/resume backpressure, and on-done flush are now deterministic and tested.
- **Independent envelopes (refined during impl).** The first chunks design wrongly closed an open *tool* envelope when a *text* chunk arrived. Corrected so tool-call and text-message envelopes are tracked independently (separate id namespaces, may be open simultaneously); only a genuinely non-chunk event closes both. Covered by the "open at once" test.
- **Order-lock is honest, not ceremonial.** For *well-formed* chunk input, swapping chunks↔verify is observationally inert (synthesis only ever emits well-formed pairs, and verify is a no-op on raw `*_CHUNK`). The genuinely-observable order dependency is an empty-`messageId` chunk: correct order synthesizes the triplet then verify rejects each (3 errors); swapped order passes the raw chunk untouched then synthesizes (0 errors). This is C.1's "verify checks the pairing chunks creates" made testable.
- **REASONING_ENCRYPTED_VALUE check avoids the base64 false-positive.** `_encryptedValueRoundTrips` decodes the held base64 string and compares byte-for-byte to the bytes (not re-encoding the bytes), guarding `base64Decode` with `on FormatException` for the off-wire-adapter case. Both the byte-mismatch and the non-base64-string paths are tested.
- **No new dependency, no codegen.** `dart:async` + `dart:convert` are core. No freezed types added; barrel/pubspec/build.yaml untouched.

### File List

New:
- `packages/koel_core/lib/src/pipeline/chunks_stage.dart`
- `packages/koel_core/lib/src/pipeline/verify_stage.dart`
- `packages/koel_core/lib/src/pipeline/apply_stage.dart`
- `packages/koel_core/lib/src/pipeline/transform_stage.dart`
- `packages/koel_core/lib/src/pipeline/pipeline.dart`
- `packages/koel_core/lib/src/pipeline/stage_support.dart`
- `packages/koel_core/test/pipeline/chunks_stage_test.dart`
- `packages/koel_core/test/pipeline/verify_stage_test.dart`
- `packages/koel_core/test/pipeline/pipeline_test.dart`

## Change Log

| Date | Change |
|------|--------|
| 2026-05-30 | Story drafted (create-story). Status → ready-for-dev. |
| 2026-05-30 | Implemented Story 2.11: four-stage event pipeline. `chunks` (F.2 synthesis) + `verify` (F.1 rules → drop + `RunErrorEvent(ProtocolError)`) ship full logic; `apply` + `transform` ship as identity (reducer-fold / transform-registry deferred to 2.12/2.14). Stateful stages built on a shared `StreamController`-backed `buildStage` helper after an `async*` first cut deadlocked on cancel (DD8). `runPipeline` composes the locked order; order-lock proven via an empty-`messageId` chunk. All 4 ACs met; 35 new tests; 481 koel_core tests green; 10-package analyze + format clean; pipeline lib 100% line coverage. A sixth lib file (`stage_support.dart`) was added beyond the story's 5-file sketch to centralize the lifecycle wiring. Status → review. |
| 2026-05-30 | Code review (adversarial, 3 layers). 1 decision-needed → patch + 2 patch applied; 1 defer; 8 dismissed. **Patch:** added `REASONING_MESSAGE_CHUNK` synthesis to `chunksStage` (third independent envelope keyed by `messageId`, default `role: 'reasoning'`) — honors the committed 2.7 `reasoning_events.dart` contract that the chunks stage expands it; +4 chunks tests + AC4-sweep assertion. Corrected `chunksStage` dartdoc "empty id" → "empty `messageId`" (verify only guards text/reasoning per F.1) and the AC3 test-count note (13→12). **Defer:** `buildStage` does not guard a throw from inside `stage.onEvent` → actionable in Story 2.12 when the reducer (which can throw) lands. 485 koel_core tests green; pipeline analyze + 10-package analyze + format clean. Status → done. |
