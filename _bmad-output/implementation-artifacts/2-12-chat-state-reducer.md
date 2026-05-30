---
baseline_commit: e2d5c08
---

# Story 2.12: `ChatState` + `ChatStateReducer` + `DefaultChatStateReducer` + `ComposedReducer` + reducer purity test

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this story touches `.dart` files, freezed data classes, and a `switch` over the sealed `AgUiEvent` union. **Invoke `/agent-flutter-engineer` before producing any code** (per CLAUDE.md). Three disciplines are load-bearing here: (1) **reducer purity** — `reduce(s, e)` must never mutate `s` and must be deterministic (no `DateTime.now()`, no `Random`); the whole story exists to make this testable (FR-D2, architecture cross-cutting #8 + convention §3). (2) **no vestigial code** — build the reducer types **in isolation**; do **NOT** wire them into `applyStage` or `KoelClient` (that is Story 2.14). The `apply` stage stays the identity transformer 2.11 shipped. (3) **the sealed-switch default-arm rule** — `koel_lints`' `exhaustive_switch_must_have_default` fires on every `switch` over `AgUiEvent`; the reducer's `default:` arm is where the no-op event families (Unknown/Raw/Custom/Activity/reasoning-non-encrypted) genuinely belong, not ceremony.

## Story

As a Flutter/Dart developer,
I want `ChatState` (freezed-immutable, const-comparable) plus the reducer hierarchy (`abstract ChatStateReducer`, `DefaultChatStateReducer`, `ComposedReducer`) with reducer purity verified by test,
so that the reduce step in the pipeline is replaceable, composable, and Riverpod-friendly per FR-D2.

## Acceptance Criteria

Verbatim from [epic-2 Story 2.12](../planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md):

1. **Given** `koel_core/lib/src/state/chat_state.dart`, **When** I inspect the freezed class, **Then** it carries `messages`, `pendingMessage`, `pendingToolCalls`, `state`, `reasoningEcho`, `error`, and `phase: RunPhase` with const constructor per Addendum A.1, **And** `RunPhase` enum lists `idle`, `running`, `stepRunning`, `error`, `cancelled`.

2. **Given** `koel_core/lib/src/state/chat_state_reducer.dart`, **When** I inspect it, **Then** `abstract class ChatStateReducer { ChatState reduce(ChatState state, AgUiEvent event); }` is declared, **And** `DefaultChatStateReducer` handles every event family appropriately (`RUN_*` → phase transitions; `TEXT_MESSAGE_*` → message accumulation; `TOOL_CALL_*` → pending tool tracking; `STATE_*` → JSON-patch application via Story 2.4; `REASONING_ENCRYPTED_VALUE` → `reasoningEcho` accumulation; `RunErrorEvent` → error field; `UnknownAgUiEvent` → no-op), **And** `ComposedReducer(List<ChatStateReducer>)` composes reducers left-to-right.

3. **Given** `koel_core/test/state/reducer_purity_test.dart`, **When** I run it, **Then** the test confirms `reduce(s, e)` never mutates `s.messages`/`s.state`/`s.reasoningEcho` (asserts they're identical-pointer or fully-immutable post-call) per architecture convention §3, **And** repeated `reduce(s, e)` invocations produce structurally-equal results (idempotence on idempotent events).

## Tasks / Subtasks

- [x] **Task 1 — `ChatState` + `RunPhase` + `ToolCall` value types** (AC: #1)
  - [x] New file `packages/koel_core/lib/src/state/chat_state.dart`. Declare `enum RunPhase { idle, running, stepRunning, error, cancelled }` (top of file, like `MessageRole` lives in `message.dart`) and `@freezed abstract class ChatState with _$ChatState` carrying **exactly** the Addendum A.1 fields, in this shape:
    ```dart
    @freezed
    abstract class ChatState with _$ChatState {
      const factory ChatState({
        @Default(<Message>[]) List<Message> messages,
        Message? pendingMessage,
        @Default(<ToolCall>[]) List<ToolCall> pendingToolCalls,
        @Default(<String, dynamic>{}) Map<String, dynamic> state,
        @Default(<String, Uint8List>{}) Map<String, Uint8List> reasoningEcho,
        KoelError? error,
        @Default(RunPhase.idle) RunPhase phase,
      }) = _ChatState;
    }
    ```
    Imports: `dart:typed_data` (`Uint8List`), `package:freezed_annotation/freezed_annotation.dart`, `../message/message.dart` (`Message`), `../error/koel_error.dart` (`KoelError`), `tool_call.dart` (`ToolCall`). `part 'chat_state.freezed.dart';`. **No** `json_serializable` / `.g.dart` / `fromJson` — `ChatState` is an in-memory state value, not a wire type (mirror `run_agent_input.dart`, which is freezed-only; JSON persistence is Story 2.13 / Epic 6, not this story). [Dev Notes §"ChatState is freezed-only (no JSON)"]
  - [x] New file `packages/koel_core/lib/src/state/tool_call.dart`. The Addendum references `List<ToolCall>` for `pendingToolCalls` but **never defines `ToolCall`** — this story creates it (Dev Notes §"`ToolCall` — the type the addendum names but never defines"). Freezed value type accumulating an in-flight tool call:
    ```dart
    @freezed
    abstract class ToolCall with _$ToolCall {
      const factory ToolCall({
        required String id,                 // toolCallId
        required String name,               // toolCallName
        @Default('') String arguments,      // concatenated TOOL_CALL_ARGS deltas
        String? parentMessageId,
      }) = _ToolCall;
    }
    ```
    Freezed-only (no JSON), `part 'tool_call.freezed.dart';`. Contract-form dartdoc explaining it is the reducer's per-call accumulator, distinct from the transient `ToolCall*Event` stream events.
  - [x] Run `dart run build_runner build --delete-conflicting-outputs` (from `packages/koel_core`) → generates `chat_state.freezed.dart` + `tool_call.freezed.dart`. Confirm `Uint8List` gets byte-deep `==` from freezed for free (it is an `Iterable<int>` — same property `run_agent_input.dart`'s `reasoningEcho` relies on) and that `Map<String, dynamic> state` / `List<Message> messages` get `DeepCollectionEquality`.

- [x] **Task 2 — `ChatStateReducer` interface + `DefaultChatStateReducer`** (AC: #2)
  - [x] New file `packages/koel_core/lib/src/state/chat_state_reducer.dart`. Declare `abstract class ChatStateReducer { ChatState reduce(ChatState state, AgUiEvent event); }` and `class DefaultChatStateReducer implements ChatStateReducer` with a `const` constructor. Single event import: `../event/ag_ui_event.dart` (all 28 subtypes are `part of` it). Plus `chat_state.dart`, `tool_call.dart`, `../message/message.dart`, `../json_patch/json_patch.dart` (`JsonPatch.apply` for `STATE_DELTA`), and `../error/koel_error.dart` — needed because the `STATE_DELTA` branch's `on ProtocolError catch` clause references the `ProtocolError` symbol (imports are not transitive through `json_patch.dart`). You do **not** *construct* any error: `RunErrorEvent.error` and the caught `ProtocolError` are already `KoelError` values you fold verbatim.
  - [x] Implement `reduce` as a `switch (event)` over the sealed root with the **exact** event-family mapping in Dev Notes §"DefaultChatStateReducer — the event-family fold table". Every branch returns `state.copyWith(...)` (the only mutation path — convention §3); never mutate `state.messages`/`state.state`/`state.reasoningEcho` in place (rebuild collections: `[...state.messages, m]`, `{...state.reasoningEcho, id: bytes}`).
  - [x] The `switch` **must** carry a `default:` arm returning `state` unchanged (koel_lints `exhaustive_switch_must_have_default`, architecture §3 :519-522). This arm is the genuine home of the no-op families: `UnknownAgUiEvent`, `RawEvent`, `CustomEvent`, `ActivitySnapshotEvent`/`ActivityDeltaEvent`, `ReasoningStartEvent`/`ReasoningEndEvent`/`ReasoningMessage*Event`, and the `*ChunkEvent`s (which never reach `apply` post-chunks, but are homed defensively). Document that the reducer assumes **post-chunks canonical input** (Dev Notes §"The reducer folds the canonical stream, not raw chunks").
  - [x] `STATE_DELTA` is the one branch that can fail: fold via `JsonPatch.apply(state.state, event.patches)` inside a `try`; on the `ProtocolError` it throws for an inapplicable patch, **fold the error into state** (`state.copyWith(error: caught, phase: RunPhase.error)`) — the reducer is **total, it never rethrows** (Dev Notes §"STATE_DELTA can throw — the reducer is total; Design Decision 2"). `JsonPatch.apply` is non-mutating + atomic (`json_patch.dart:18-26` — "the contract the reducer-purity test in Story 2.12 relies on"), so a successful apply leaves `state.state` untouched and returns a fresh tree.

- [x] **Task 3 — `ComposedReducer`** (AC: #2)
  - [x] New file `packages/koel_core/lib/src/state/composed_reducer.dart`. `class ComposedReducer implements ChatStateReducer` holding `final List<ChatStateReducer> reducers;` with a `const ComposedReducer(this.reducers);`. `reduce(state, event)` folds left-to-right: `reducers.fold(state, (s, r) => r.reduce(s, event))`. Imports: `chat_state.dart`, `chat_state_reducer.dart`, `../event/ag_ui_event.dart`.
  - [x] Contract-form dartdoc: composes reducers in registration order — each reducer sees the prior reducer's output for the **same** event; an empty list is identity. This is the F-D2 composition seam consumers use to layer custom reduction on top of `DefaultChatStateReducer`.

- [x] **Task 4 — Reducer purity test** (AC: #3)
  - [x] New file `packages/koel_core/test/state/reducer_purity_test.dart` (mirrors `lib/src/state/` path-for-path per architecture §"tests mirror lib/src"; the AC pins this path — note the variance vs. architecture.md:818 which sketches it at `test/` root, resolved in favor of the AC + mirroring convention).
  - [x] **No-mutation proof:** seed a non-trivial `ChatState` (populated `messages`, `state` map, `reasoningEcho`). Capture the input collection references **and** a deep snapshot of their contents. For each representative event family, call `reduce(s, e)`, then assert the **input** `s.messages`/`s.state`/`s.reasoningEcho` are unchanged — both that the references the caller holds still equal their pre-call snapshot (contents) and, where applicable, that `reduce` returned a *fresh* collection (`identical(result.messages, s.messages)` is **false** when the event mutates messages; **true**/equal when it doesn't). [Dev Notes §"Purity test — what to actually assert"]
  - [x] **Idempotence:** for genuinely idempotent events (`StateSnapshotEvent`, `MessagesSnapshotEvent`, `RunErrorEvent`, `ReasoningEncryptedValueEvent` with the same blob), assert `reduce(reduce(s, e), e) == reduce(s, e)` (structural equality via freezed `==`). Do **not** assert idempotence on accumulating events (`TextMessageContentEvent`, `ToolCallArgsEvent`) — applying them twice **correctly** doubles the accumulation; that is not an idempotent event and asserting it would be a false test (koel bans tests that assert the wrong thing).
  - [x] **Determinism:** assert two independent `reduce(s, e)` calls on the same inputs are `==` (catches any accidental `DateTime.now()`/`Random` leak — see Dev Notes §"The timestamp purity trap").

- [x] **Task 5 — Behavioral coverage test** (AC: #2, supports N-12)
  - [x] New file `packages/koel_core/test/state/chat_state_reducer_test.dart`. One focused test per event-family branch in the fold table (phase transitions for `RUN_*`/`STEP_*`; text Start/Content/End accumulation → `pendingMessage` then commit to `messages`; tool Start/Args/End/Result → `pendingToolCalls` lifecycle; `STATE_SNAPSHOT` replace + `STATE_DELTA` apply + the inapplicable-patch → `error`/`phase: error` path; `MESSAGES_SNAPSHOT` replace; `REASONING_ENCRYPTED_VALUE` → `reasoningEcho`; `RunErrorEvent` → `error` + `phase: error`; a `default:`-arm no-op event asserting `identical(reduce(s, e), s)` **or** `reduce(s, e) == s`). Plus a `ComposedReducer` test (order matters; empty list = identity) and a small `ChatState` equality/`copyWith` smoke test. Every `DefaultChatStateReducer` branch + `ComposedReducer` must be exercised for ≥ 90% line + branch (N-12).

- [x] **Task 6 — Quality gates** (AC: all)
  - [x] `dart test` (from `packages/koel_core`) → all green (existing 485 + new). No regressions.
  - [x] `melos run analyze` → 0 issues (workspace-wide, all 10 packages).
  - [x] `dart format --set-exit-if-changed .` → clean.
  - [x] Coverage on `lib/src/state/` ≥ 90% line + branch (N-12).
  - [x] Confirm **untouched**: `lib/koel_core.dart` barrel (export sweep is Story 2.15), `pubspec.yaml` (no new dependency — `JsonPatch`/`freezed_annotation` already present), `build.yaml`, every event/error/pipeline/json_patch/agent/input file. **`applyStage` stays identity** — the reducer is NOT wired into the pipeline here (Story 2.14). Commit the source files; the generated `*.freezed.dart` are gitignored + CI-verified (architecture §1) — do not commit them.

### Review Findings

_Code review 2026-05-30 (Blind Hunter + Edge Case Hunter + Acceptance Auditor). 1 patch, 1 defer, 10 dismissed as noise._

- [x] [Review][Patch] **FIXED** `STATE_DELTA` root-replacing op crashes the "total" reducer with an uncaught `CastError` [packages/koel_core/lib/src/state/chat_state_reducer.dart:155-178] — `JsonPatch.apply` is documented to return a non-`Map` for a root-replacing op (`ReplaceOp(path: '', value: [...])` / `AddOp(path: '', value: <scalar>)`) — its own dartdoc (`json_patch.dart:17-19`) flags this as conformance-suite behavior. The reducer casts the result `as Map<String, dynamic>`, which throws a `TypeError`/`CastError` — **not** a `ProtocolError`, so `on ProtocolError catch` does not catch it. A non-empty patch of individually-valid root-replace ops passes the verify stage (verify only rejects *empty* patches), so this is reachable on the canonical stream and lets a `throw` escape `reduce` — directly violating Design Decision 2 (the reducer is total) and the reducer dartdoc's "it never lets a `throw` escape" claim. Fix: after `apply`, guard the type — if the result is not a `Map<String, dynamic>`, fold a `ProtocolError(protocolMalformed)` into `error` + `phase: error` (state must be a JSON object; a non-object root is inapplicable), exactly like the existing throw path. (Source: Edge Case Hunter; confirmed against `json_patch.dart`.)
- [x] [Review][Defer] `ComposedReducer` / custom reducers are not guaranteed total — a throwing member escapes `reduce` [packages/koel_core/lib/src/state/composed_reducer.dart:343-344] — deferred to **Story 2.14**, defense-in-depth. `ComposedReducer.reduce` folds members with no `try/catch`; a non-total custom reducer a consumer registers would throw out of the fold and defeat `applyStage`'s totality assumption. Not actionable in 2.12 (nothing is wired into the pipeline — Design Decision 1; `DefaultChatStateReducer` itself is total once the patch above lands). This is the **same** home as the re-pointed `buildStage` throw-guard (`deferred-work.md`): harden the stage boundary in 2.14 when the reducer is wired in, so a non-total custom reducer cannot hang the pipeline. (Source: Edge Case Hunter.)

## Dev Notes

### What this story is, in one paragraph
You are building the **session state model and the reducer that folds events into it** — the heart of FR-D2. `ChatState` is a freezed-immutable snapshot of a conversation; `DefaultChatStateReducer.reduce(state, event)` is the pure function that, given the current state and one canonical `AgUiEvent`, returns the next state. The reducer is the third pipeline stage's engine (`apply`), but **this story ships it standalone** — proven by direct unit tests, not wired into the pipeline. The load-bearing craft is **purity**: `reduce` rebuilds collections (never mutates the input), is deterministic (no wall-clock, no RNG), and is total (it folds even a failing `STATE_DELTA` into `ChatState.error` rather than throwing). That purity is what keeps `ChatState` const-comparable and Riverpod-friendly, and what makes time-travel replay (re-folding events `[0..N]`) correct. [Source: epic-2 §"Story 2.12"; addendum.md A.1 :91-176, F.3 :650-652, C.1 :515-528; architecture.md §3 :513-546, cross-cutting #8 :119-123, FR-D2 file layout :787-790]

### Scope: build the reducer in isolation — do NOT wire the pipeline (RESOLVED — Design Decision 1)
This mirrors **2.10 and 2.11 exactly**: ship the deliverables whose dependencies exist; defer the wiring to its real home.

| Deliverable | This story | Why |
|---|---|---|
| `ChatState` + `RunPhase` + `ToolCall` | **NEW, full** | All field types exist: `Message` (2.1), `KoelError` (2.3), `Uint8List`/`Map`. `ToolCall` is created here (addendum names it, never defines it). |
| `ChatStateReducer` + `DefaultChatStateReducer` | **NEW, full real logic** | Every event family (2.5–2.8) and `JsonPatch.apply` (2.4) exist. |
| `ComposedReducer` | **NEW, full** | Pure composition over `ChatStateReducer`. |
| Reducer purity + behavioral tests | **NEW** | The story's *raison d'être* (AC3). |
| **`applyStage` reducer-fold wiring** | **❌ NOT here — Story 2.14** | `applyStage` stays the identity transformer 2.11 shipped. 2.11's `applyStage` dartdoc is explicit: *"`KoelClient` (Story 2.14) injects the reducer wired from `ChatStateReducer` (Story 2.12)."* Wiring it now means touching `applyStage` ahead of `KoelClient`'s constructor (which owns reducer registration, Addendum A.1 :34) — the exact one-way-door-ahead-of-definition smell 2.9/2.10/2.11 warned against. |

The "pull to make it real" here is wiring `DefaultChatStateReducer` into `applyStage`. Resist it: the reducer is a pure `(ChatState, AgUiEvent) → ChatState` function, fully testable and fully proven **without** a stream. The seam where it plugs into `apply` is `applyStage`'s permanent dartdoc contract (already written in 2.11); 2.14 calls it.

### `ToolCall` — the type the addendum names but never defines
`ChatState.pendingToolCalls: List<ToolCall>` (addendum A.1 :97) is the **only** reference to `ToolCall` in the entire addendum — there is no class body for it anywhere (grep-confirmed: the only other `ToolCall*` symbols are the `ToolCall*Event` stream events). So this story **defines** it. The shape in Task 1 is the minimal accumulator the fold needs: `id` (the `toolCallId`), `name` (the `toolCallName`), `arguments` (the concatenated `TOOL_CALL_ARGS` deltas — a JSON-fragment string per `tool_call_events.dart:37-40`), and `parentMessageId`. It deliberately does **not** carry a decoded-args `Map` or a `result` — args stay a raw string (the wire ships fragments; full parse is a consumer concern), and a returned result **removes** the call from `pendingToolCalls` rather than mutating it. Name it `ToolCall` (no `Event` suffix) per the addendum; the `*Event` suffix convention (architecture §1) keeps it unambiguous against `ToolCallStartEvent` et al.

### `ChatState` is freezed-only (no JSON)
`ChatState` and `ToolCall` are freezed with **no** `json_serializable` — no `.g.dart`, no `fromJson`/`toJson`. Rationale: they are in-memory state values, not wire payloads. `RunAgentInput` (the closest sibling — also freezed-only, also carries `Map<String, Uint8List>`) is the template: it explicitly defers JSON to "the transport that posts this payload (Epic 4)". `ChatState` persistence is `SessionStorage` (Story 2.13, in-memory `Map` — no serialization) and Hive/secure storage (Epic 6). Adding a codec now is vestigial. `Uint8List` getting byte-deep `==` for free from freezed (it is an `Iterable<int>`) is the same property `run_agent_input.dart:13-17` documents — `reasoningEcho` comparison "just works".

### DefaultChatStateReducer — the event-family fold table
The reducer runs **after** `chunks` + `verify`, so it folds the **canonical** stream. Field names below are confirmed against the shipped event files. Every row is `state.copyWith(...)`; unlisted fields carry forward.

| Event | Fold |
|---|---|
| `RunStartedEvent` | `phase: running`, `error: null`, `pendingMessage: null`, `pendingToolCalls: const []` — a new run clears prior transients + error (Design Decision 3). `messages` (history) persists. |
| `RunFinishedEvent` | `phase: idle`. (Well-formed streams close messages via `TEXT_MESSAGE_END` before finishing; do not flush `pendingMessage` here.) |
| `RunErrorEvent` | `error: event.error`, `phase: error`. `event.error` is already a `KoelError` (an `AgentError` from decode) — fold verbatim. |
| `StepStartedEvent` | `phase: stepRunning`. |
| `StepFinishedEvent` | `phase: running` (back inside the run after the step). |
| `TextMessageStartEvent` | `pendingMessage: Message(id: event.messageId, role: _roleFrom(event.role), content: '', timestamp: _epoch)`. See §"The timestamp purity trap" for `_epoch`. `_roleFrom` maps the permissive wire `role` string → `MessageRole` (default `assistant`). |
| `TextMessageContentEvent` | `pendingMessage: state.pendingMessage?.copyWith(content: (pendingMessage.content) + event.delta)` — concatenate. If `pendingMessage` is null (Content with no Start — verify would have caught a malformed envelope, but be defensive), no-op return `state`. |
| `TextMessageEndEvent` | commit: `messages: [...state.messages, state.pendingMessage!], pendingMessage: null` (guard null → no-op). |
| `ToolCallStartEvent` | `pendingToolCalls: [...state.pendingToolCalls, ToolCall(id: event.toolCallId, name: event.toolCallName, parentMessageId: event.parentMessageId)]`. |
| `ToolCallArgsEvent` | find the open call by `id == event.toolCallId`, append `event.delta` to its `arguments` (rebuild the list with the updated `ToolCall`). No match → no-op. |
| `ToolCallEndEvent` | no state change to `pendingToolCalls` membership (the call stays "pending" until a result) — End only closes the args stream. Return `state` (or carry forward). Document the choice. |
| `ToolCallResultEvent` | remove the matching `ToolCall` (`id == event.toolCallId`) from `pendingToolCalls` — the call is resolved. (Do **not** synthesize a tool `Message` here; `MESSAGES_SNAPSHOT` / the next run's `messages` is the source of truth for tool-result history — avoids double-counting.) |
| `StateSnapshotEvent` | `state: event.state` — wholesale replace (the `state_events.dart:3-5` contract). |
| `StateDeltaEvent` | `try { final next = JsonPatch.apply(state.state, event.patches) as Map<String, dynamic>; return state.copyWith(state: next); } on ProtocolError catch (e) { return state.copyWith(error: e, phase: RunPhase.error); }`. See §"STATE_DELTA can throw". |
| `MessagesSnapshotEvent` | `messages: event.messages, pendingMessage: null` — snapshot supersedes the streaming buffer. |
| `ReasoningEncryptedValueEvent` | `reasoningEcho: {...state.reasoningEcho, event.entityId: event.encryptedValue}` — accumulate the byte blob keyed by `entityId` (round-trips into the next run's `RunAgentInput.reasoningEcho`, FR-A9). |
| `default:` (Unknown/Raw/Custom/Activity*/Reasoning{Start,End,Message*}/`*ChunkEvent`) | return `state` unchanged (no-op). Homes the families `ChatState` does not model + satisfies the lint default-arm rule. |

### STATE_DELTA can throw — the reducer is total (RESOLVED — Design Decision 2)
`verify` (2.11) only rejects **empty** `STATE_DELTA.patches`; a non-empty patch of individually-valid ops can still be **inapplicable** to the current `state.state` (e.g. `remove` a path that isn't there) — and that is only discoverable at **apply** time, where `JsonPatch.apply` throws `ProtocolError(protocolMalformed)`. Per Addendum C.1, *emitting* a `RunErrorEvent` in-stream is the **verify** stage's role (step 2), not **apply**'s (step 3 just "folds"). So an apply-time failure has a natural home that is **not** a new in-stream event: `ChatState.error`. Therefore the `DefaultChatStateReducer` **catches** the `ProtocolError` and folds it into `state.copyWith(error: caught, phase: RunPhase.error)`, leaving `state.state` unchanged (atomic — `JsonPatch.apply` discards its partial copy on failure). The reducer is **total**: it never lets a `throw` escape. This (a) keeps `reduce` pure/total/deterministic for the purity test, (b) honors the kernel "no raw throw crosses a koel boundary" invariant at the reducer's boundary, (c) uses `ChatState.error` for exactly its designed purpose, and (d) keeps apply's role as "fold," not "mint errors."

> **Re-pointing the 2.11 deferred item.** 2.11's review deferred *"`buildStage` does not guard a throw inside `stage.onEvent` — becomes live in Story 2.12 when `applyStage` folds via a reducer."* (see `deferred-work.md:167`). That estimate predates this story's scope clarification: **2.12 does not wire `applyStage`** (Design Decision 1 — wiring is 2.14), and the reducer is **total** (Design Decision 2 — it never throws). So the `buildStage` throw-guard is **not** actionable in 2.12 and does not become a live bug here. It remains deferred to **Story 2.14** (when `KoelClient` wires the reducer into `applyStage`) as defense-in-depth — even a total reducer benefits from a guarded stage, but nothing in 2.12 can make `applyStage` hang. Update `deferred-work.md` to re-point that item to 2.14 with this rationale.

### The timestamp purity trap
`Message` requires a `timestamp: DateTime`, but the typed `TEXT_MESSAGE_*` events carry **no** timestamp (only the trace-export wrapper adds one — `addendum.md C.4`, not the typed event). The reducer therefore has no wall-clock source for a streamed assistant message — and it **must not** call `DateTime.now()`: that would make `reduce` non-deterministic and **fail the purity/determinism test** (`reduce(s, e) == reduce(s, e)` would be false across the millisecond boundary). **Decision (RESOLVED — Design Decision 4):** synthesized `pendingMessage`s use a deterministic sentinel `final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)` (a private top-level/static const-ish value; note `DateTime.fromMillisecondsSinceEpoch` is not a `const` constructor, so make it a `final` static field, not `const`). Real wall-clock timestamps are assigned where a clock legitimately exists: `MESSAGES_SNAPSHOT` carries backend timestamps (used verbatim), and the controller/persistence layer (Epic 6) can re-stamp on commit. Document the sentinel on the reducer. This is the same "purity over convenience" call the architecture's cross-cutting #8 forces.

### The reducer folds the canonical stream, not raw chunks
`reduce` is the engine of the `apply` stage, which sits **after** `chunks` + `verify` (C.1 order). So in production it never sees `TextMessageChunkEvent`/`ToolCallChunkEvent`/`ReasoningMessageChunkEvent` — those are synthesized into Start/Content|Args/End triplets upstream. The `*ChunkEvent` arms therefore live in the `default:` no-op (defensive homing), not as real fold logic — building chunk-accumulation in the reducer would duplicate the chunks stage and is vestigial. Document this assumption so a future reader doesn't "fix" the missing chunk handling.

### Purity test — what to actually assert
AC3 has two halves; make both real, not ceremonial:
- **No-mutation.** Build `s` with non-empty `messages`/`state`/`reasoningEcho`. Before calling `reduce`, snapshot the *contents* (e.g. `final msgsBefore = List.of(s.messages); final stateBefore = Map.of(s.state);`). After `reduce(s, e)`, assert `s.messages` still equals `msgsBefore`, `s.state` still equals `stateBefore`, `s.reasoningEcho` unchanged — i.e. the input the caller still holds was not mutated underneath them. Freezed's default unmodifiable collections + `JsonPatch.apply`'s deep-copy make this hold; the test is the **guard** against a future `state.messages.add(...)` regression. Additionally, for a *non*-mutating event (e.g. a `default:` no-op or a `RunFinishedEvent` that only flips `phase`), assert `identical(result.messages, s.messages)` — `copyWith` preserves unchanged collection references, proving the reducer doesn't needlessly copy.
- **Idempotence (idempotent events only).** `StateSnapshotEvent`, `MessagesSnapshotEvent`, `RunErrorEvent`, and `ReasoningEncryptedValueEvent` (same blob) are idempotent: `reduce(reduce(s, e), e) == reduce(s, e)`. Assert it. **Do not** assert idempotence on `TextMessageContentEvent`/`ToolCallArgsEvent` — re-applying a delta *correctly* doubles it; these are accumulating, not idempotent. (Asserting otherwise tests a falsehood — koel bans it.)
- **Determinism.** `reduce(s, e) == reduce(s, e)` for a fresh-message event (`TextMessageStartEvent`) — this is the trip-wire that catches an accidental `DateTime.now()` in `pendingMessage` synthesis.

### Files you will touch
| Path | Action | Note |
|------|--------|------|
| `packages/koel_core/lib/src/state/chat_state.dart` | **NEW** | `RunPhase` enum + freezed `ChatState`. ~35-55 lines incl. dartdoc. |
| `packages/koel_core/lib/src/state/tool_call.dart` | **NEW** | freezed `ToolCall` accumulator. ~20-30 lines. |
| `packages/koel_core/lib/src/state/chat_state_reducer.dart` | **NEW** | `abstract ChatStateReducer` + `DefaultChatStateReducer` (the fold switch). ~90-140 lines incl. dartdoc. |
| `packages/koel_core/lib/src/state/composed_reducer.dart` | **NEW** | `ComposedReducer` left-to-right fold. ~25-35 lines. |
| `packages/koel_core/lib/src/state/chat_state.freezed.dart` | **GENERATED** | build_runner; gitignored. |
| `packages/koel_core/lib/src/state/tool_call.freezed.dart` | **GENERATED** | build_runner; gitignored. |
| `packages/koel_core/test/state/reducer_purity_test.dart` | **NEW** | AC3 — no-mutation + idempotence + determinism. |
| `packages/koel_core/test/state/chat_state_reducer_test.dart` | **NEW** | per-family behavioral coverage + `ComposedReducer` + `ChatState` ==/copyWith. |

**Do NOT touch:** `lib/koel_core.dart` (barrel — frozen until Story 2.15), `pubspec.yaml`, `build.yaml`, any pipeline file (`applyStage` stays identity — wiring is 2.14), any event/error/json_patch/agent/input/message file. Every type you need already exists or is created in `state/`.

### Library / framework requirements
- **freezed `3.2.6-dev.1`** (the documented analyzer-12 stopgap, `pubspec.yaml:12-20`; per project memory the asp/freezed pivot is tracked separately and does **not** change the `@freezed` authoring surface). Author with `@freezed abstract class X with _$X { const factory X({...}) = _X; }` — the exact idiom `run_agent_input.dart` / `message.dart` use. **No** private `._()` constructor is needed (you add `._()` only when a freezed class has custom methods/getters — `ChatState`/`ToolCall` have none; contrast the event subtypes which need `._()` for `toJson`).
- **`json_serializable` is NOT used** for these types (no `.g.dart`). `build.yaml`'s `field_rename: none` is irrelevant here (no JSON).
- **`JsonPatch.apply(Object?, List<JsonPatchOp>)`** (`json_patch.dart`) — non-mutating, atomic, throws `ProtocolError(protocolMalformed)`. Cast its `Object?` result to `Map<String, dynamic>` for the state fold. No new dependency — `freezed_annotation`, `json_annotation`, and the vendored JSON Patch are all in `koel_core` already.
- **`dart:typed_data`** (`Uint8List`) — core. **`dart:async` / `dart:convert`** are **not** needed (no streams, no base64 in the reducer — the encrypted blob arrives pre-decoded on `ReasoningEncryptedValueEvent.encryptedValue`).

### Project Structure Notes
- Files land exactly where architecture.md:787-790 places them: `lib/src/state/{chat_state, chat_state_reducer, composed_reducer}.dart`. `tool_call.dart` is a koel addition in the same `state/` directory (the addendum names `ToolCall` but the layout sketch omitted its file) — no structural variance, just one more one-type-per-file value class beside `chat_state.dart`.
- Tests mirror `lib/src/state/` under `test/state/` path-for-path (architecture §"tests mirror lib/src"). The AC pins `test/state/reducer_purity_test.dart`; architecture.md:818 sketches `reducer_purity_test.dart` at `test/` root and §3:562 says "in koel_test" — both reconciled in favor of the **AC** (`koel_core/test/state/`), which is authoritative and consistent with the mirroring convention. Known doc-vs-AC drift, not a conflict.
- `state_conflict.dart` + `LastWriterWinsResolver` (also in the `state/` layout) are **Story 2.13**, not here — do not create them.

## Previous Story Intelligence
From the koel_core lineage 2.1–2.11:
- **2.11 (4-stage pipeline)** is the immediate predecessor and the reason `apply` is currently identity. Re-read its `apply_stage.dart` dartdoc before starting — it is the **contract you build against**: it states the reducer folds events into `ChatState`, is pure, never mutates `state.messages`/`state.state`/`state.reasoningEcho`, and is injected by `KoelClient` (2.14). Your `DefaultChatStateReducer` is the thing that dartdoc promises; **do not wire it into `apply_stage.dart`** — that is 2.14. 2.11 also left the `buildStage` throw-guard deferred "to 2.12" — re-pointed to 2.14 here (see §"Re-pointing the 2.11 deferred item"; the reducer being total means it can't make a stage hang).
- **2.4 (JSON Patch)** shipped `JsonPatch.apply` whose dartdoc *names this story*: "the contract the reducer-purity test in Story 2.12 relies on" (non-mutating + atomic). The `STATE_DELTA` fold consumes it directly; the inapplicable-patch `ProtocolError` it throws is folded into `ChatState.error` (total reducer), not rethrown.
- **2.1 (`Message`/`RunAgentInput`)** is the **freezed-only template** (no JSON codec, `Uint8List` byte-deep `==` for free). `message.dart`'s own dartdoc already forward-references this story ("the element type of `RunAgentInput.messages` and, from Story 2.12, `ChatState.messages`"). `Message.role: MessageRole` is the enum your text-message fold maps the wire `role` string onto.
- **2.5–2.8 (event subtypes)** are the fold's input. Several dartdocs forward-reference 2.12 by name: `text_message_events.dart:35-36` ("the reducer concatenates deltas in order (Story 2.12)"), `state_events.dart:3-5` (snapshot "replaces `ChatState.state` wholesale"), `reasoning_events.dart:158-160` (`encryptedValue` "accumulated by the reducer in Story 2.12"). The field names in the fold table are confirmed against these files.
- **Recurring SF-1 discipline (2.3–2.11):** no raw throw / silent catch crosses a koel boundary. Here it manifests as: the reducer is **total** (catches the `STATE_DELTA` `ProtocolError`, folds to `error`), and the sealed `switch` has the mandated `default:` no-op arm. [Source: 2-11/2-4/2-1 stories; event files 2-5..2-8]

## Git Intelligence Summary
Recent commits: `feat(story-2.11)` (four-stage pipeline — the `apply` identity stage + deferred buildStage item this story re-points), `feat(story-2.10)` (AgentSubscriber — forward-reference deferral template), `feat(story-2.5..2.8)` (event codecs — the fold's input types). The relevant precedents are **2.11** (scope discipline: ship the part whose deps exist, defer the wiring) and **2.1** (`message.dart`/`run_agent_input.dart` — the freezed-only, no-JSON, `Uint8List`-equality data-class template). Expect a **surgical** footprint: 4 new lib files (+2 generated) + 2 test files; **zero** modified production files; **zero** new deps; **two** new freezed-generated artifacts (run build_runner). Commit message: `feat(story-2.12): ChatState + reducer hierarchy + purity test`. [Source: `git log` e2d5c08/5c3e56a/37e0f97]

## Latest Tech Information
- **freezed 3.x authoring** — `@freezed abstract class ChatState with _$ChatState { const factory ChatState({...}) = _ChatState; }`. `@Default(...)` on a `const factory` parameter sets the default for non-passed args; collection defaults (`@Default(<Message>[])`) generate unmodifiable views, so a `.add()` on `state.messages` throws at runtime — which is the purity property you want (and test). No `._()` needed (no custom members). [Source: freezed_annotation 3.1.0; run_agent_input.dart/message.dart patterns]
- **freezed `copyWith` reference-preservation** — `s.copyWith(phase: x)` reuses the *same* collection instances for unchanged fields, so `identical(s.copyWith(phase: x).messages, s.messages)` is `true`. The purity test exploits this to prove the reducer doesn't gratuitously copy. [Source: freezed copyWith semantics]
- **`DateTime.fromMillisecondsSinceEpoch(0)` is not `const`** — make `_epoch` a `final` static/top-level field, not a `const`. Determinism (not const-ness) is the property the purity test needs. [Source: dart:core]
- **Dart 3 sealed `switch` exhaustiveness** — a `switch (event)` over `sealed AgUiEvent` is compile-exhaustive, but `koel_lints`' `exhaustive_switch_must_have_default` still **requires** a `default:` arm (architecture §3:519-522) — it is the runtime home for forward-compat `UnknownAgUiEvent` and the families `ChatState` doesn't model. SDK `>=3.11.0 <4.0.0`. [Source: ag_ui_event.dart sealed root; architecture §3]
- **No new dependency.** Everything (`freezed_annotation`, vendored `JsonPatch`, `dart:typed_data`) is already in `koel_core`. [Source: pubspec.yaml]

### References
- [epic-2 Story 2.12 spec + ACs](../planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md)
- [addendum.md A.1 :91-107 (`ChatState` fields + `RunPhase` enum), :148-176 (`ReasoningEncryptedValueEvent`, `ChatStateReducer`, `ComposedReducer`); C.1 :515-528 (apply = fold, verify = emit RunError); F.3 :650-652 (apply/reducer purity — "rebuild lists each call")](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md)
- [architecture.md — `state/` file layout :787-790; convention §3 :513-546 (immutability, copyWith-only, sealed-switch default arm); cross-cutting #8 :119-123 (const-comparable ChatState ⇒ reducer purity); const-comparable reducer :560-562; tests mirror lib/src :809-818](../planning-artifacts/architecture.md)
- [json_patch.dart :9-40 — `JsonPatch.apply` non-mutating + atomic, throws `ProtocolError`, names "the reducer-purity test in Story 2.12"](../../packages/koel_core/lib/src/json_patch/json_patch.dart)
- [message.dart — freezed-only `Message` + `MessageRole`; forward-references `ChatState.messages` (Story 2.12)](../../packages/koel_core/lib/src/message/message.dart)
- [run_agent_input.dart — freezed-only, no-JSON, `Uint8List` byte-deep `==` template](../../packages/koel_core/lib/src/input/run_agent_input.dart)
- [text_message_events.dart / tool_call_events.dart / state_events.dart / reasoning_events.dart — the fold's input event shapes (field names confirmed)](../../packages/koel_core/lib/src/event/text_message_events.dart)
- [run_events.dart / step_events.dart — `RunErrorEvent.error: KoelError`; `RUN_*`/`STEP_*` lifecycle for phase transitions](../../packages/koel_core/lib/src/event/run_events.dart)
- [pipeline/apply_stage.dart — the identity stage whose dartdoc is this reducer's wiring contract; stays identity until 2.14](../../packages/koel_core/lib/src/pipeline/apply_stage.dart)
- [2-11-four-stage-event-pipeline.md — predecessor; deferred buildStage item re-pointed here; deferred-work.md:167](2-11-four-stage-event-pipeline.md)

### Design decisions (RESOLVED — AC/convention-forced, not open)
Baked in so the dev has zero ambiguity. No confirmation gate.
1. **Build the reducer types in isolation; do NOT wire `applyStage`/`KoelClient`.** The fold seam is `applyStage`'s permanent dartdoc (2.11); the injection is `KoelClient` (2.14). Mirrors 2.10/2.11 deferral discipline. `applyStage` stays identity.
2. **The `DefaultChatStateReducer` is total — it never throws.** `STATE_DELTA`'s inapplicable-patch `ProtocolError` (from `JsonPatch.apply`) is **caught and folded** into `ChatState.error` + `phase: error` (apply's job is fold, not emit — emit is verify's, C.1). Keeps `reduce` pure/total/deterministic and honors the no-throw-crosses-boundary invariant.
3. **`RUN_STARTED` resets per-run transients** (`error: null`, `pendingMessage: null`, `pendingToolCalls: []`) and sets `phase: running`; `messages` history persists. The reducer-policy phase map (Start→running, Step→stepRunning, StepFinished→running, Finished→idle, Error→error) is the RESOLVED default; each transition is test-covered.
4. **Synthesized `pendingMessage`s use a deterministic `_epoch` sentinel timestamp** (`DateTime.fromMillisecondsSinceEpoch(0)`), never `DateTime.now()` — purity/determinism over convenience. Real timestamps come from `MESSAGES_SNAPSHOT` / the controller layer.
5. **`ToolCall` is defined here** (addendum names it, never defines it): `{id, name, arguments, parentMessageId?}` — a freezed accumulator; `TOOL_CALL_RESULT` removes the resolved call; args stay a raw concatenated string.
6. **`ChatState`/`ToolCall` are freezed-only (no JSON codec)** — in-memory state, not wire types (mirrors `RunAgentInput`). Persistence serialization is 2.13/Epic 6.
7. **The reducer folds the post-chunks canonical stream** — `*ChunkEvent`s are homed in the `default:` no-op (not re-accumulated; that's the chunks stage's job). `MESSAGES_SNAPSHOT`/`STATE_SNAPSHOT` replace wholesale.
8. **The 2.11 deferred `buildStage` throw-guard is re-pointed to Story 2.14** (not actionable in 2.12: no `applyStage` wiring + total reducer). Update `deferred-work.md` accordingly.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context) — via `/agent-flutter-engineer` discipline (CLAUDE.md).

### Debug Log References

- **Purity-test reference-identity correction.** The story's "Latest Tech Information" claimed freezed `copyWith` preserves collection *references* (`identical(result.messages, s.messages) == true` for unchanged fields). This is **empirically false** for freezed `3.2.6-dev.1`: the generated getter (`chat_state.freezed.dart:231-234`) wraps `_messages` in a **fresh** `EqualUnmodifiableListView` on every access unless the backing field already is one — which it never becomes through the public construct/`copyWith` path — so `identical` on the public getter is always `false`. Resolved by proving purity via AC3's **other** sanctioned path ("identical-pointer **or fully-immutable**"): content-unchanged after `reduce` **plus** the input collections genuinely reject in-place mutation (`throwsUnsupportedError`). This is a stronger guard (it proves the reducer structurally cannot mutate the caller's state) and avoids asserting a falsehood (koel bans tests that assert the wrong thing).
- **Coverage gap → real test.** First coverage pass left `chat_state_reducer.dart:37-38` (the `_roleFrom` `'system'`/`'tool'` arms) uncovered. Closed with a focused per-role mapping test (every wire role + unrecognized→assistant default), not a coverage-theater touch. Final: **100% line** on the hand-written `lib/src/state/` files.

### Completion Notes List

- Built the FR-D2 session-state model + reducer hierarchy **in isolation** (Design Decision 1): `applyStage` stays the identity transformer 2.11 shipped; the reducer is **not** wired into the pipeline or `KoelClient` (that is Story 2.14). Verified `apply_stage.dart`, the barrel, `pubspec.yaml`, `build.yaml`, and every event/error/json_patch/pipeline file are **untouched** (git-confirmed).
- `DefaultChatStateReducer.reduce` is a `switch` over the sealed `AgUiEvent` root with the exact Addendum A.1 / C.1 fold table. It is **total** (Design Decision 2): the lone failable branch — `STATE_DELTA` — catches the `ProtocolError` `JsonPatch.apply` throws for an inapplicable patch and folds it into `ChatState.copyWith(error:, phase: error)`, never rethrowing. The mandated `default:` arm (koel_lints `exhaustive_switch_must_have_default`) is the genuine home of the no-op families (Unknown/Raw/Custom/Activity*/Reasoning{Start,End,Message*}/`*ChunkEvent`).
- **Purity** is enforced structurally: every branch returns `state.copyWith(...)`, collections are rebuilt (`[...]`, `{...}`), and the deterministic `_epoch` sentinel (`DateTime.fromMillisecondsSinceEpoch(0)`, a lazy `final` — not `const`) replaces any wall-clock for synthesized `pendingMessage`s (Design Decision 4), so `reduce` is deterministic and the determinism test trips on any future `DateTime.now()` leak.
- `ToolCall` (defined here per Design Decision 5 — the addendum names it but never bodies it) is a freezed accumulator `{id, name, arguments, parentMessageId?}`; `TOOL_CALL_RESULT` removes the resolved call; args stay a raw concatenated string.
- `ChatState`/`ToolCall` are **freezed-only, no JSON codec** (Design Decision 6, mirrors `RunAgentInput`); persistence is 2.13/Epic 6.
- Re-pointed the 2.11 deferred `buildStage` throw-guard from "Story 2.12" → **Story 2.14** in `deferred-work.md` (Design Decision 8): 2.12 wires nothing and the reducer is total, so the guard is not actionable until the reducer is wired into `applyStage`.
- **Quality gates:** `dart test` → **532 passed** (485 prior + 47 new, no regressions); `melos run analyze` → **0 issues** across all 11 packages; `dart format --set-exit-if-changed .` → clean; coverage on `lib/src/state/` → **100% line** (every reducer branch + both no-op/match paths + STATE_DELTA success/failure + all 5 role arms exercised by construction). Generated `*.freezed.dart` are gitignored (not committed).

### File List

- `packages/koel_core/lib/src/state/chat_state.dart` (NEW) — `RunPhase` enum + freezed `ChatState`.
- `packages/koel_core/lib/src/state/tool_call.dart` (NEW) — freezed `ToolCall` accumulator.
- `packages/koel_core/lib/src/state/chat_state_reducer.dart` (NEW) — `ChatStateReducer` interface + `DefaultChatStateReducer` fold + `_epoch`/`_roleFrom` helpers.
- `packages/koel_core/lib/src/state/composed_reducer.dart` (NEW) — `ComposedReducer` left-to-right fold.
- `packages/koel_core/test/state/reducer_purity_test.dart` (NEW) — AC3: no-mutation + idempotence + determinism.
- `packages/koel_core/test/state/chat_state_reducer_test.dart` (NEW) — per-family behavioral coverage + `ComposedReducer` + `ChatState` ==/copyWith.
- `_bmad-output/implementation-artifacts/deferred-work.md` (MODIFIED) — re-pointed the 2.11 `buildStage` throw-guard item to Story 2.14.
- `packages/koel_core/lib/src/state/chat_state.freezed.dart`, `tool_call.freezed.dart` (GENERATED, gitignored) — build_runner output.

## Change Log

| Date | Change |
|------|--------|
| 2026-05-30 | Story drafted (create-story). Status → ready-for-dev. |
| 2026-05-30 | Implemented `ChatState`/`RunPhase`/`ToolCall` + `ChatStateReducer`/`DefaultChatStateReducer`/`ComposedReducer` + purity & behavioral tests (47 new, 100% line coverage on `state/`). Re-pointed 2.11 `buildStage` deferred item to 2.14. All gates green. Status → review. |
| 2026-05-30 | Code review (3 layers). 1 patch fixed: `STATE_DELTA` root-replacing op (`path: ""` → non-`Map`) crashed the total reducer with an uncaught `CastError`; now type-guarded → folds `ProtocolError(protocolMalformed)` into `error`/`phase: error` (+ regression test, 533 pass). 1 item deferred to 2.14 (`ComposedReducer`/custom-reducer totality). All gates green. Status → done. |
