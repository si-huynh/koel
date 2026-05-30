---
baseline_commit: 1dca714
---

# Story 2.13: `SessionStorage` interface + `InMemorySessionStorage` + `StateConflict` + `LastWriterWinsResolver`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this story touches `.dart` files, freezed data classes, and `async`/`Future` APIs. **Invoke `/agent-flutter-engineer` before producing any code** (per CLAUDE.md). Three disciplines are load-bearing here: (1) **build in isolation, do NOT wire the pipeline** — mirror 2.10/2.11/2.12 exactly: ship the four types whose dependencies exist (`SessionStorage`, `InMemorySessionStorage`, `StateConflict`, `LastWriterWinsResolver`), and **defer all wiring** — `KoelClient` injection (`sessionStorage`/`stateConflictResolver` ctor params) and `applyStage`'s conflict *detection* are **Story 2.14**. `applyStage` stays the identity transformer 2.11 shipped; `DefaultChatStateReducer` (2.12) is **not** touched. (2) **leverage `ChatState` immutability** — it is freezed-deeply-immutable, so `InMemorySessionStorage` is a trivially-correct `Map<String, ChatState>` with **no** defensive copies and **no** serialization (Design Decision 6 of 2.12: persistence is "in-memory `Map` — no codec"). (3) **don't repeat the 2.12 `STATE_DELTA` `CastError` review bug** — `LastWriterWinsResolver` folds incoming patches via `JsonPatch.apply`, whose `Object?` result is **not** always a `Map` (a root-replacing op returns a list/scalar); **type-guard the cast** exactly as the 2.12 code-review patch did (§"`LastWriterWinsResolver` — the verbatim fold, and the root-replace trap").

## Story

As a Flutter/Dart developer,
I want the `SessionStorage` interface, `InMemorySessionStorage` reference impl, `StateConflict` value type, and `LastWriterWinsResolver` default,
so that consumers can persist `ChatState` across sessions and handle delta-vs-snapshot conflicts per FR-D1 (interface + in-memory portion) and FR-A8.

## Acceptance Criteria

Verbatim from [epic-2 Story 2.13](../planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md):

1. **Given** `koel_core/lib/src/session/session_storage.dart`, **When** I inspect it, **Then** `abstract class SessionStorage` declares `Future<void> save(String threadId, ChatState state)`, `Future<ChatState?> load(String threadId)`, `Future<void> delete(String threadId)`, `Future<List<String>> listThreads()`.

2. **Given** `koel_core/lib/src/session/in_memory_session_storage.dart`, **When** I exercise it, **Then** save/load/delete/listThreads round-trip correctly, **And** the storage holds only an in-process `Map` (no I/O).

3. **Given** `koel_core/lib/src/state/state_conflict.dart`, **When** I inspect it, **Then** `StateConflict` is freezed with `incomingPatches: List<JsonPatchOp>`, `localState: Map<String, dynamic>`, `snapshotState: Map<String, dynamic>`, **And** `abstract class StateConflictResolver` declares `Map<String, dynamic> resolve(StateConflict conflict)`, **And** `LastWriterWinsResolver implements StateConflictResolver` ships as the default (applies incoming patches verbatim).

4. **Given** the apply stage detects a STATE_DELTA whose patches reference a path mutated locally since the last STATE_SNAPSHOT, **When** the configured `StateConflictResolver` runs, **Then** the resolver's output replaces the conflicting state slice in the next `ChatState` per Addendum C.1 step 3.

> **AC4 is the integration contract that Story 2.14 wires — this story proves the resolver fulfills its half.** The apply stage stays identity until 2.14 (Design Decision 1); `ChatState` does not yet track "paths mutated locally since the last SNAPSHOT", so *detection* has no home here. In 2.13 you prove AC4's resolver half **directly**: construct a `StateConflict` and assert `LastWriterWinsResolver.resolve(conflict)` returns `localState` with `incomingPatches` applied (the slice the next `ChatState.state` will carry). The "apply stage detects … replaces the slice" wiring is Story 2.14. [Source: 2.12 Design Decision 1 isolation precedent; Addendum C.1 step 3 :523; Addendum A.1 :33,38 — `KoelClient` owns `sessionStorage`/`stateConflictResolver` registration]

## Tasks / Subtasks

- [x] **Task 1 — `SessionStorage` interface** (AC: #1)
  - [x] New file `packages/koel_core/lib/src/session/session_storage.dart`. Declare `abstract class SessionStorage` with **exactly** the four async members from Addendum A.1 :241-246 — no more:
    ```dart
    abstract class SessionStorage {
      Future<void> save(String threadId, ChatState state);
      Future<ChatState?> load(String threadId);
      Future<void> delete(String threadId);
      Future<List<String>> listThreads();
    }
    ```
    Single import: `../state/chat_state.dart` (`ChatState`). The members are `Future`-typed because the real impls are I/O-backed — `HiveSessionStorage` / `SecureSessionStorage` (Epic 6, Addendum A.1 :401-406). The in-memory impl (Task 2) completes them synchronously. [Dev Notes §"Why the interface is `async` but in-memory isn't"]
  - [x] Contract-form dartdoc (architecture §6) on the class + every method: one-line summary, when-to-use / when-not, error/absence cases. Pin the contract the way the existing `koel_core` interfaces (`abstract_agent.dart`, `error_classifier.dart`) do: `load` returns `null` for an unknown `threadId` (not a throw); `delete` of an absent `threadId` is a no-op (idempotent); `listThreads` returns a **snapshot** the caller may freely retain (impls must not hand back a live view); ordering is **unspecified** (consumers must not depend on it). State whether `save` overwrites (it does — last write wins per `threadId`). Note adapters surface I/O failures as a thrown error, classified by the consumer's `ErrorClassifier` — `SessionStorage` itself does **not** wrap errors in `KoelError` (that is the transport/classifier seam, not persistence).

- [x] **Task 2 — `InMemorySessionStorage` reference impl** (AC: #2)
  - [x] New file `packages/koel_core/lib/src/session/in_memory_session_storage.dart`. `class InMemorySessionStorage implements SessionStorage` holding a single private `final Map<String, ChatState> _store = {};` (a `LinkedHashMap`). Imports: `../state/chat_state.dart`, `session_storage.dart`.
  - [x] Implement the four members against `_store` — **no serialization, no defensive copies** (`ChatState` is deeply immutable: freezed unmodifiable collections + `Uint8List` blobs, so storing/returning the reference is safe — this is exactly why the in-memory reference impl is trivially correct):
    - `save` → `_store[threadId] = state;` (overwrites; last-write-wins per thread).
    - `load` → `_store[threadId]` (returns `null` for an unknown thread — `Map`'s `[]` already does this; do **not** throw).
    - `delete` → `_store.remove(threadId);` (idempotent — removing an absent key is a no-op).
    - `listThreads` → `_store.keys.toList()` — a **fresh** `List` snapshot (never expose `_store.keys`, which is a live view).
  - [x] Complete each `Future` **synchronously** — the body does zero I/O. Use the no-`async` `Future.value(...)` / `Future<void>.value()` idiom (or `async`; either compiles, but `Future.value` signals "no suspension point"). [Dev Notes §"Why the interface is `async` but in-memory isn't"]
  - [x] Contract-form dartdoc: the canonical zero-dependency `SessionStorage` — process-lifetime only, lost on restart; the reference impl `koel_test`/examples wire and the fallback when no persistent adapter is configured. State plainly: holds a plain `Map` (no I/O, no codec), leans on `ChatState` immutability so no copy is needed, `listThreads` order is insertion-order **but not contractual**.

- [x] **Task 3 — `StateConflict` value type + `StateConflictResolver` + `LastWriterWinsResolver`** (AC: #3, #4)
  - [x] New file `packages/koel_core/lib/src/state/state_conflict.dart`. All three symbols live in this one file (architecture layout :791 — `state_conflict.dart # F-A8 + LastWriterWinsResolver`). Imports: `package:freezed_annotation/freezed_annotation.dart`, `../json_patch/json_patch_op.dart` (`JsonPatchOp`), `../json_patch/json_patch.dart` (`JsonPatch.apply`), `../error/koel_error.dart` (`ProtocolError`) + `../error/koel_error_code.dart` (`KoelErrorCode`) for the root-replace guard. `part 'state_conflict.freezed.dart';`.
  - [x] **`StateConflict`** — freezed value type carrying **exactly** the Addendum A.1 :228-232 fields, freezed-only (no JSON — it is an in-memory conflict descriptor, never serialized, mirroring `ChatState`):
    ```dart
    @freezed
    abstract class StateConflict with _$StateConflict {
      const factory StateConflict({
        required List<JsonPatchOp> incomingPatches,
        required Map<String, dynamic> localState,
        required Map<String, dynamic> snapshotState,
      }) = _StateConflict;
    }
    ```
    No `@Default` (all three are required), no `._()` (no custom members). `List<JsonPatchOp>` gets deep `==` for free: freezed's `DeepCollectionEquality` compares elements via each `JsonPatchOp` subtype's freezed-generated `==`.
  - [x] **`StateConflictResolver`** — `abstract class StateConflictResolver { Map<String, dynamic> resolve(StateConflict conflict); }`. Contract-form dartdoc: a **pure, synchronous** resolution policy — given a detected conflict, returns the state map the next `ChatState.state` should carry. This is the F-A8 seam consumers swap to inject custom merge strategies (e.g. a 3-way merge that reads `snapshotState`); the SDK default is `LastWriterWinsResolver`.
  - [x] **`LastWriterWinsResolver`** — `class LastWriterWinsResolver implements StateConflictResolver` with a `const` constructor. `resolve` applies the incoming patches **verbatim** onto `localState` (last writer = the incoming delta; it wins, no merge) — and **type-guards** the `JsonPatch.apply` result exactly as the 2.12 review patch did (§"the root-replace trap"):
    ```dart
    @override
    Map<String, dynamic> resolve(StateConflict conflict) {
      final next = JsonPatch.apply(conflict.localState, conflict.incomingPatches);
      if (next is! Map<String, dynamic>) {
        throw ProtocolError(
          message: 'STATE_DELTA produced a non-object root; '
              'a conflict-resolved state must be a JSON object',
          code: KoelErrorCode.protocolMalformed,
          cause: conflict.incomingPatches,
        );
      }
      return next;
    }
    ```
    Contract-form dartdoc: the SDK default — "last writer wins", incoming delta applied verbatim onto `localState`, no merge against `snapshotState` (that field exists for *other* resolvers; LWW ignores it). Document that `resolve` may throw `ProtocolError(protocolMalformed)` when the patches are inapplicable to `localState` **or** produce a non-object root — the Story 2.14 apply-stage wiring catches it and folds it into `ChatState.error` (the same totality contract the 2.12 reducer's `STATE_DELTA` branch honors). [Dev Notes §"`LastWriterWinsResolver` — the verbatim fold, and the root-replace trap"]
  - [x] Run `dart run build_runner build --delete-conflicting-outputs` (from `packages/koel_core`) → generates `state_conflict.freezed.dart`. Confirm `List<JsonPatchOp>` + both `Map`s get `DeepCollectionEquality` `==`.

- [x] **Task 4 — `InMemorySessionStorage` round-trip test** (AC: #2)
  - [x] New file `packages/koel_core/test/session/in_memory_session_storage_test.dart` (mirrors `lib/src/session/` path-for-path — architecture §"tests mirror lib/src", and the `test/session/` dir is already in the layout :815). Cover every member + every documented edge:
    - save → load round-trips the **structurally-equal** `ChatState` (use a non-trivial state: populated `messages`, `state` map, `reasoningEcho` blob — assert `loaded == saved` via freezed `==`).
    - `load` of an unknown `threadId` → `null` (no throw).
    - `save` overwrites: two saves to the same `threadId`, second `load` returns the second value.
    - `delete` removes (subsequent `load` → `null`); `delete` of an absent thread → completes normally (idempotent, no throw).
    - `listThreads` after N saves returns all N ids; returns `[]` when empty; the returned list is a **snapshot** — mutating it does not affect storage, and a later `save` does not mutate the previously-returned list.
    - **No-I/O / immutability proof:** `load` returns the *same* `ChatState` instance that was saved (`identical(loaded, saved)` — proves no copy/serialization round-trip), and a `ChatState` retrieved twice is `identical` across both loads.
  - [x] These are `async` tests — `await` every storage call.

- [x] **Task 5 — `StateConflict` + `LastWriterWinsResolver` test** (AC: #3, #4)
  - [x] New file `packages/koel_core/test/state/state_conflict_test.dart`. Cover:
    - **`StateConflict` value semantics:** two instances with equal fields are `==`; `copyWith` produces the expected diff; `incomingPatches` list equality is deep (two distinct-but-equal `JsonPatchOp` lists compare equal).
    - **LWW happy path (AC4 resolver half):** build a conflict where `localState` diverged from `snapshotState` and `incomingPatches` touch the diverged path; assert `resolve(conflict)` == `JsonPatch.apply(localState, incomingPatches)` — i.e. the incoming delta wins, applied verbatim onto `localState`, and `snapshotState` is **not** consulted (prove by making `snapshotState` value differ and confirming it never appears in the output).
    - **LWW is pure / non-mutating:** snapshot `localState`'s contents before `resolve`; assert the caller's `localState` map is unchanged after (leans on `JsonPatch.apply`'s non-mutating + atomic contract).
    - **Inapplicable-patch path:** `incomingPatches` with an op inapplicable to `localState` (e.g. `RemoveOp` of an absent path) → `resolve` throws `ProtocolError(protocolMalformed)`.
    - **Root-replace guard (the 2.12 regression class):** `incomingPatches: [ReplaceOp(path: '', value: <scalar-or-list>)]` → `JsonPatch.apply` returns a non-`Map`; assert `resolve` throws `ProtocolError(protocolMalformed)`, **not** an uncaught `CastError`/`TypeError`. [Dev Notes §"the root-replace trap"]
  - [x] Every public branch of `state_conflict.dart` exercised for ≥ 90% line + branch (N-12).

- [x] **Task 6 — Quality gates** (AC: all)
  - [x] `dart test` (from `packages/koel_core`) → all green (existing 533 + new). No regressions.
  - [x] `melos run analyze` → 0 issues (workspace-wide, all packages).
  - [x] `dart format --set-exit-if-changed .` → clean.
  - [x] Coverage on `lib/src/session/` + the new `state_conflict.dart` ≥ 90% line + branch (N-12).
  - [x] Confirm **untouched**: `lib/koel_core.dart` barrel (export sweep is Story 2.15), `pubspec.yaml` (no new dependency — `freezed_annotation` + vendored `JsonPatch` already present), `build.yaml`, `chat_state.dart`/`chat_state_reducer.dart`/`composed_reducer.dart`/`tool_call.dart` (the 2.12 reducer is **not** wired to the resolver here — that is 2.14), every pipeline file (**`applyStage` stays identity**), every event/error/json_patch/agent/input file. Commit the source files; the generated `state_conflict.freezed.dart` is gitignored + CI-verified (architecture §1) — do not commit it.

### Review Findings

_Code review 2026-05-30 (baseline `1dca714`, 3 layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor). AC1–AC4 all PASS; isolation/"do not touch" scope clean; no Critical/High correctness defects. 3 test-hardening patches, 0 decision-needed, 0 defer, 7 dismissed as noise/by-design._

- [x] [Review][Patch] Add `AddOp(path:'')` root-replace regression test [packages/koel_core/test/state/state_conflict_test.dart] — the inherited 2.12 root-replace guard is only proven for `ReplaceOp(path:'')`. `json_patch.dart:108` (`_add`: `if (tokens.isEmpty) return value`) makes `AddOp(path:'', value: <list/scalar>)` route through the **identical** `is! Map` guard. Since AC's whole point #3 is "don't repeat the 2.12 root-replace bug", proving both root-replacing ops throw `ProtocolError(protocolMalformed)` is cheap insurance against the exact regression class. **Fixed: added test asserting `AddOp(path:'', value: 42)` throws `ProtocolError(protocolMalformed)`.**
- [x] [Review][Patch] Add empty-`incomingPatches` no-op test for `resolve` [packages/koel_core/test/state/state_conflict_test.dart] — `resolve(conflict)` with `incomingPatches: []` returns a fresh deep-copy of `localState` (`JsonPatch.apply` deep-copies even for an empty patch list). Behavior is correct but undocumented/untested through the resolver seam. **Fixed: added test asserting `resolve` with empty patches yields a `localState`-equal map, ignoring `snapshotState`.**
- [x] [Review][Patch] Add same-instance-two-keys + delete-one aliasing test [packages/koel_core/test/session/in_memory_session_storage_test.dart] — the no-copy design means `save('t1', s); save('t2', s); delete('t1')` must leave `t2 → s` intact. The `identical` no-copy property is only tested for a single key; the two-key alias the design explicitly relies on is untested. **Fixed: added test saving one instance under `t1`/`t2`, deleting `t1`, asserting `t2` still returns the identical instance.**

## Dev Notes

### What this story is, in one paragraph
You are shipping the **persistence and conflict-resolution contracts** of the kernel — FR-D1 (the `SessionStorage` interface + its in-memory reference impl) and FR-A8 (the `StateConflict` descriptor + `StateConflictResolver` policy seam + `LastWriterWinsResolver` default). Like 2.10/2.11/2.12 before it, this story ships the **types whose dependencies already exist** and **defers all wiring**: `KoelClient` will inject a `SessionStorage` and a `StateConflictResolver` (its ctor already lists both, Addendum A.1 :33,38) and the `applyStage` will *detect* conflicts and invoke the resolver — **both in Story 2.14**. Nothing here touches the pipeline or the 2.12 reducer. The two deliverables are small and orthogonal: (1) `InMemorySessionStorage` is a `Map<String, ChatState>` made trivially correct by `ChatState`'s deep immutability (no serialization, no copies); (2) `LastWriterWinsResolver` is a pure fold of incoming JSON-Patch ops onto the local state via the 2.4 `JsonPatch.apply` engine, with the same root-replace type-guard the 2.12 code review added to the reducer. [Source: epic-2 §"Story 2.13"; addendum.md A.1 :227-248, C.1 :523; architecture.md §"state/"+"session/" layout :787-802, FR-D1/F-A8 map :998, :1074]

### Scope: build the four types in isolation — do NOT wire `KoelClient`/`applyStage` (RESOLVED — Design Decision 1)
This mirrors **2.10, 2.11, and 2.12 exactly**: ship the deliverables whose dependencies exist; defer the wiring to its real home (`KoelClient`, Story 2.14).

| Deliverable | This story | Why |
|---|---|---|
| `SessionStorage` interface | **NEW, full** | Depends only on `ChatState` (2.12). |
| `InMemorySessionStorage` | **NEW, full** | Pure `Map<String, ChatState>`; `ChatState` immutability makes it correct with no codec. |
| `StateConflict` + `StateConflictResolver` + `LastWriterWinsResolver` | **NEW, full** | All field types exist: `JsonPatchOp` (2.4), `JsonPatch.apply` (2.4), `ProtocolError` (2.3). |
| **`KoelClient` injection** of `sessionStorage`/`stateConflictResolver` | **❌ NOT here — Story 2.14** | `KoelClient` does not exist until 2.14; it owns both ctor params (Addendum A.1 :33,38). |
| **`applyStage` conflict *detection* + resolver invocation** | **❌ NOT here — Story 2.14** | `applyStage` stays the identity transformer 2.11 shipped. Detection needs "paths mutated locally since last SNAPSHOT" tracking that `ChatState` does not model yet — a 2.14+ concern. The 2.12 reducer's `STATE_DELTA` branch applies the delta blind; it is **not** modified here. |

The "pull to make it real" here is wiring the resolver into the reducer / `applyStage`, or threading `SessionStorage` into a `ChatSession`. Resist it: the resolver is a pure `(StateConflict) → Map` function and the storage is a pure `Map` wrapper — both fully testable and fully proven **without** a pipeline or a client. The seams where they plug in are owned by `KoelClient` (2.14).

### Why the interface is `async` but in-memory isn't
`SessionStorage` is `Future`-typed because its **real** impls do I/O: `HiveSessionStorage` (disk box) and `SecureSessionStorage` (`flutter_secure_storage`), both Epic 6 (Addendum A.1 :401-406). The interface must be `async` so those compile against it. `InMemorySessionStorage` does **zero** I/O, so it completes each `Future` synchronously — prefer the no-`async` `Future.value(...)` / `Future<void>.value()` form to signal "no suspension point" (an `async` body also compiles; the microtask hop is irrelevant for a reference impl, so this is style, not correctness). The async surface is also what lets `koel_test` and Epic 6 swap a real adapter behind the same type without touching consumers.

### `InMemorySessionStorage` leans on `ChatState` immutability — no copies, no codec
`ChatState` (2.12) is freezed-deeply-immutable: `messages`/`pendingToolCalls` are unmodifiable `List`s, `state`/`reasoningEcho` unmodifiable `Map`s, the `Uint8List` blobs are not handed out mutably through any public path. So a `Map<String, ChatState>` is a **correct** store with **no defensive copy on save or load** — the caller cannot mutate a stored state underneath you, and you cannot mutate theirs. This is the direct payoff of 2.12 Design Decision 6 ("`ChatState` persistence is `SessionStorage` (Story 2.13, in-memory `Map` — no serialization)"). Do **not** add a JSON codec or a deep-copy — both are vestigial here. `listThreads` is the one spot that must hand back a fresh `List` (`_store.keys.toList()`), because `Map.keys` is a **live view** that would mutate under the caller as threads are added/removed.

### `StateConflict` is freezed-only (no JSON), mirroring `ChatState`
`StateConflict` is an **in-memory** conflict descriptor the apply stage hands to a resolver and discards — it never hits the wire or disk. So it is freezed with **no** `json_serializable` (no `.g.dart`, no `fromJson`/`toJson`), exactly like `ChatState`/`ToolCall`/`RunAgentInput`. `List<JsonPatchOp>` and the two `Map<String, dynamic>` fields get freezed `DeepCollectionEquality` for free, so two equal conflicts compare `==` (useful for tests). No `._()` constructor (no custom members). [Source: 2.12 Design Decision 6; run_agent_input.dart freezed-only template]

### `LastWriterWinsResolver` — the verbatim fold, and the root-replace trap (RESOLVED — Design Decision 2)
**Semantics.** "Last writer wins" = the **incoming** STATE_DELTA is the last writer, so it wins; the local divergence loses. "Applies incoming patches verbatim" means **no merge** — LWW does not diff `localState` against `snapshotState` and reconcile (that is what a *smarter* resolver would do with `snapshotState`). It simply applies `incomingPatches` onto `localState` via `JsonPatch.apply` — the **same** call the 2.12 reducer's non-conflict `STATE_DELTA` branch makes. So LWW makes conflict resolution a **no-op relative to plain application**: the conflict machinery exists so *other* resolvers can do something smarter; the default falls through to plain apply. `snapshotState` is carried in `StateConflict` for those other resolvers (e.g. a future 3-way merge) — LWW deliberately ignores it.

**The root-replace trap (learn from 2.12's code review).** `JsonPatch.apply` returns `Object?`, **not** `Map<String, dynamic>` — a root-replacing op (`ReplaceOp(path: '', value: <list-or-scalar>)` / `AddOp(path: '', value: ...)`) returns a list or scalar (`json_patch.dart:17-19,108,156`). The 2.12 reducer originally cast the result `as Map<String, dynamic>` and a code-review found this throws an **uncaught `CastError`** on a root-replace patch — fixed by type-guarding the result (2.12 Change Log :264). `LastWriterWinsResolver.resolve` makes the **same** `JsonPatch.apply` call and must carry the **same** guard from day one: if the result `is! Map<String, dynamic>`, throw `ProtocolError(protocolMalformed)` (a conflict-resolved state must be a JSON object — a non-object root is inapplicable), not let a `CastError` escape. Test it (Task 5).

**Throw vs. total.** Unlike the 2.12 *reducer* (which is **total** — it catches and folds into `ChatState.error`), `resolve` returns a bare `Map` and is allowed to **throw** `ProtocolError` for inapplicable/non-object results. Rationale: `resolve` is a pure helper, not a stream-boundary; the **caller** (the Story 2.14 apply-stage wiring) is where the throw is caught and folded into `ChatState.error` — exactly as the reducer's `STATE_DELTA` branch already does for the non-conflict path. Keeping `resolve` simple-and-throwing (rather than total-and-`ChatState`-returning) is correct because `resolve` returns a state **slice** (`Map`), not a whole `ChatState`, so it has nowhere to fold an error itself. Document this on `resolve` so 2.14 knows to wrap it.

### Files you will touch
| Path | Action | Note |
|------|--------|------|
| `packages/koel_core/lib/src/session/session_storage.dart` | **NEW** | `abstract SessionStorage` — 4 async members. ~20-35 lines incl. dartdoc. |
| `packages/koel_core/lib/src/session/in_memory_session_storage.dart` | **NEW** | `Map<String, ChatState>` impl, no I/O. ~25-40 lines incl. dartdoc. |
| `packages/koel_core/lib/src/state/state_conflict.dart` | **NEW** | freezed `StateConflict` + `StateConflictResolver` + `LastWriterWinsResolver`. ~45-70 lines incl. dartdoc. |
| `packages/koel_core/lib/src/state/state_conflict.freezed.dart` | **GENERATED** | build_runner; gitignored. |
| `packages/koel_core/test/session/in_memory_session_storage_test.dart` | **NEW** | AC2 round-trip + edges + immutability proof. |
| `packages/koel_core/test/state/state_conflict_test.dart` | **NEW** | AC3/AC4 — value semantics + LWW verbatim + inapplicable + root-replace guard. |

**Do NOT touch:** `lib/koel_core.dart` (barrel — frozen until Story 2.15), `pubspec.yaml`, `build.yaml`, any pipeline file (`applyStage` stays identity — wiring is 2.14), `chat_state.dart`/`chat_state_reducer.dart`/`composed_reducer.dart`/`tool_call.dart` (the reducer is **not** wired to the resolver here), any event/error/json_patch/agent/input/message file. Every type you need already exists or is created in this story.

### Library / framework requirements
- **freezed `3.2.6-dev.1`** (the documented analyzer-12 stopgap, `pubspec.yaml:12-20`). Author `StateConflict` with `@freezed abstract class StateConflict with _$StateConflict { const factory StateConflict({...}) = _StateConflict; }` — the exact idiom `tool_call.dart` / `chat_state.dart` use. All three fields `required` (no `@Default`); **no** `._()` (no custom members). [Source: tool_call.dart, chat_state.dart]
- **`json_serializable` is NOT used** for `StateConflict` (no `.g.dart`). It is freezed-only — in-memory descriptor, not a wire type.
- **`JsonPatch.apply(Object?, List<JsonPatchOp>)`** (`json_patch.dart:38`) — non-mutating, atomic, returns `Object?`, throws `ProtocolError(protocolMalformed)`. LWW consumes it directly; **type-guard the `Object?` result** before returning it as `Map<String, dynamic>` (the root-replace trap above). [Source: json_patch.dart:13-37]
- **`ProtocolError` + `KoelErrorCode`** (`error/koel_error.dart`, `error/koel_error_code.dart`, 2.3) — the LWW guard mints a `ProtocolError(code: KoelErrorCode.protocolMalformed)`. This is the **only** place this story constructs an error.
- **No new dependency.** `freezed_annotation`, the vendored `JsonPatch`, and `ChatState` are all already in `koel_core`. `dart:async` (`Future`) and `dart:core` (`Map`) are core — no imports needed for those.

### Project Structure Notes
- Files land exactly where the architecture places them: `lib/src/session/{session_storage, in_memory_session_storage}.dart` (:800-802) and `lib/src/state/state_conflict.dart` (:791 — the layout comment `# F-A8 + LastWriterWinsResolver` confirms all three F-A8 types share this one file). No structural variance.
- Tests mirror `lib/src/` path-for-path: `test/session/` (already in the layout :815) and `test/state/` (exists — `reducer_purity_test.dart`/`chat_state_reducer_test.dart` from 2.12 live there).
- `state_conflict.dart` is the **last** new file in `state/` for Epic 2 — `chat_state.dart`, `chat_state_reducer.dart`, `composed_reducer.dart`, `tool_call.dart` (2.12) are done; the barrel export of all of them is Story 2.15.

### Previous Story Intelligence
From the koel_core lineage 2.1–2.12:
- **2.12 (`ChatState` + reducer)** is the immediate predecessor and supplies **both** of this story's key dependencies: (a) `ChatState` — the value `SessionStorage` persists, and its deep immutability is *why* `InMemorySessionStorage` needs no codec/copy (2.12 Design Decision 6 explicitly hands persistence to "Story 2.13, in-memory `Map` — no serialization"); (b) the `STATE_DELTA` `CastError` **code-review patch** — `JsonPatch.apply`'s `Object?` result is not always a `Map`, and casting blind throws on a root-replace op. `LastWriterWinsResolver` makes the same call and **must** ship the same type-guard from the start (do not re-introduce the bug the 2.12 review caught). The 2.12 reducer is **total** (catches + folds); `resolve` is allowed to **throw** (the 2.14 caller folds) — see §"Throw vs. total".
- **2.10 / 2.11 / 2.12 isolation discipline** is the governing precedent: ship the part whose deps exist, defer the wiring. Here it means: build the four types, **do not** wire `KoelClient` (doesn't exist until 2.14) or `applyStage` (stays identity). `KoelClient`'s ctor already names `sessionStorage` + `stateConflictResolver` (Addendum A.1 :33,38) — that injection is 2.14's job.
- **2.4 (JSON Patch)** shipped `JsonPatch.apply` (non-mutating, atomic, throws `ProtocolError`) and `JsonPatchOp` (sealed, freezed, deep-`==`). `StateConflict.incomingPatches` is a `List<JsonPatchOp>`; `LastWriterWinsResolver.resolve` folds via `JsonPatch.apply`. Both consumed verbatim — no changes to the patch engine.
- **2.1 (`Message`/`RunAgentInput`)** remains the **freezed-only, no-JSON** template `StateConflict` follows.
- **Recurring SF-1 discipline (2.3–2.12):** no raw throw / silent catch crosses a *stream* boundary. `resolve` is a pure helper *below* that boundary — it may throw `ProtocolError`; the 2.14 apply-stage wiring is the boundary that catches it (just as the 2.12 reducer's `STATE_DELTA` branch catches the same error type today). [Source: 2-12/2-11/2-4/2-1 stories]

### Git Intelligence Summary
Recent commits: `feat(story-2.12)` (`ChatState` + reducer + the `STATE_DELTA` `CastError` review fix this story inherits the guard from), `feat(story-2.11)` (four-stage pipeline — `apply` identity stage that stays identity here), `feat(story-2.10)` (forward-reference deferral template). The governing precedents are **2.12** (the immutable `ChatState` this persists + the root-replace type-guard) and the **2.10/2.11/2.12 isolation pattern** (ship types, defer wiring). Expect a **surgical** footprint: 3 new lib files (+1 generated) + 2 test files; **zero** modified production files; **zero** new deps; **one** new freezed-generated artifact (run build_runner). Commit message: `feat(story-2.13): SessionStorage + InMemorySessionStorage + StateConflict + LastWriterWinsResolver`. [Source: `git log` 1dca714/e2d5c08/5c3e56a]

### Latest Tech Information
- **freezed 3.x authoring** — `@freezed abstract class StateConflict with _$StateConflict { const factory StateConflict({required ...}) = _StateConflict; }`. `required` collection fields (no `@Default`) still get unmodifiable views + `DeepCollectionEquality` `==`. No `._()` needed (no custom members). [Source: tool_call.dart / chat_state.dart patterns, freezed_annotation 3.1.0]
- **`Future.value()` for synchronous completion** — `Future<void>.value()` and `Future.value(x)` complete on the current microtask with no `await`-suspension; correct for an in-memory store's zero-I/O methods. (An `async` body is equivalent in behavior; `Future.value` just reads as "no suspension point".) [Source: dart:async]
- **`Map.keys` is a live view** — `_store.keys` reflects later mutations; `listThreads` must return `_store.keys.toList()` so the caller holds a stable snapshot. `Map.remove` of an absent key is a no-op returning `null` (idempotent `delete`); `Map[]` of an absent key returns `null` (no-throw `load`). [Source: dart:core `Map`]
- **`JsonPatch.apply` returns `Object?`** — a root-replace op yields a non-`Map`; guard the result type in `LastWriterWinsResolver.resolve` (the 2.12-review regression class), throwing `ProtocolError(protocolMalformed)` rather than letting a `CastError` escape. [Source: json_patch.dart:13-19; 2-12 Change Log :264]
- **No new dependency.** Everything (`freezed_annotation`, vendored `JsonPatch`/`JsonPatchOp`, `ProtocolError`, `ChatState`) is already in `koel_core`. [Source: pubspec.yaml]

### References
- [epic-2 Story 2.13 spec + ACs](../planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md)
- [addendum.md A.1 :227-248 (`StateConflict` fields, `StateConflictResolver`, `LastWriterWinsResolver`, `SessionStorage` 4 members, `InMemorySessionStorage`); A.1 :33,38 (`KoelClient` ctor names `sessionStorage`/`stateConflictResolver` — the 2.14 injection seam); A.1 :401-406 (`HiveSessionStorage`/`SecureSessionStorage` — the I/O impls justifying the async interface); C.1 :523 (apply = fold + resolve conflict via resolver)](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md)
- [architecture.md — `session/` + `state/` file layout :787-802; `test/session/` mirror :815; FR-D1/F-A8 component map :998, :1074; convention §3 :513-562 (freezed immutability, copyWith-only, const-comparable); tests mirror lib/src :807-818](../planning-artifacts/architecture.md)
- [chat_state.dart — the freezed-immutable `ChatState` this persists (no JSON codec; deep immutability ⇒ no defensive copy)](../../packages/koel_core/lib/src/state/chat_state.dart)
- [tool_call.dart — freezed-only `required`-field value-type idiom `StateConflict` mirrors](../../packages/koel_core/lib/src/state/tool_call.dart)
- [json_patch.dart :13-37 — `JsonPatch.apply` non-mutating + atomic, returns `Object?` (root-replace ⇒ non-`Map`), throws `ProtocolError`](../../packages/koel_core/lib/src/json_patch/json_patch.dart)
- [json_patch_op.dart — sealed freezed `JsonPatchOp` (`incomingPatches` element type; deep-`==`)](../../packages/koel_core/lib/src/json_patch/json_patch_op.dart)
- [koel_error.dart / koel_error_code.dart — `ProtocolError(KoelErrorCode.protocolMalformed)` the LWW guard mints](../../packages/koel_core/lib/src/error/koel_error.dart)
- [2-12-chat-state-reducer.md — predecessor: `ChatState` immutability + Design Decision 6 (persistence = in-memory Map, no codec) + the `STATE_DELTA` `CastError` review fix (Change Log :264) `LastWriterWinsResolver` inherits the guard from](2-12-chat-state-reducer.md)

### Design decisions (RESOLVED — AC/convention-forced, not open)
Baked in so the dev has zero ambiguity. No confirmation gate.
1. **Build the four types in isolation; do NOT wire `KoelClient`/`applyStage`.** `KoelClient` (Story 2.14) injects `sessionStorage` + `stateConflictResolver` (Addendum A.1 :33,38) and the apply stage detects conflicts + invokes the resolver. `applyStage` stays identity; the 2.12 reducer is untouched. Mirrors 2.10/2.11/2.12 deferral discipline. AC4's "apply stage detects … replaces the slice" is proven here only as the **resolver half** (direct `resolve` test), the wiring in 2.14.
2. **`LastWriterWinsResolver` applies incoming patches verbatim onto `localState`, with a root-replace type-guard.** Incoming delta wins, no merge against `snapshotState` (carried for other resolvers; LWW ignores it). Fold via `JsonPatch.apply`; **type-guard the `Object?` result** — non-`Map` ⇒ throw `ProtocolError(protocolMalformed)` (the 2.12-review regression class). `resolve` is a pure helper that **throws** (not total); the 2.14 caller catches + folds into `ChatState.error`.
3. **`SessionStorage` is `async`; `InMemorySessionStorage` completes synchronously.** The interface is `Future`-typed for the Epic 6 I/O impls (`Hive`/`secure`); the in-memory impl does zero I/O and completes via `Future.value(...)`.
4. **`InMemorySessionStorage` is a plain `Map<String, ChatState>` — no codec, no defensive copies.** `ChatState`'s deep immutability makes storing/returning references correct (2.12 Design Decision 6). `load`/`delete` of an unknown thread are no-throw/no-op; `save` overwrites; `listThreads` returns a fresh `_store.keys.toList()` snapshot, order unspecified.
5. **`StateConflict` is freezed-only (no JSON codec)** — an in-memory conflict descriptor, never serialized (mirrors `ChatState`/`RunAgentInput`). All three fields `required`; `List<JsonPatchOp>` + both `Map`s get deep `==` for free.
6. **No barrel/pubspec/build.yaml changes.** Export sweep is Story 2.15; no new dependency.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context) — via `/agent-flutter-engineer` discipline (CLAUDE.md).

### Debug Log References

- **`dart format` reflowed the two new test files** (cosmetic line-wrapping of long `test('…', () { … })` headers and inline map literals) on the first `--set-exit-if-changed` pass. Re-ran format → clean (exit 0); tests unaffected. No source files were reformatted.
- **No design surprises.** The story's design decisions held verbatim — the only non-obvious call (the `LastWriterWinsResolver` root-replace type-guard) was pre-specified from the 2.12 code-review precedent, so it shipped correct on the first write and its dedicated test passed without iteration.

### Completion Notes List

- Shipped the FR-D1 persistence contract + FR-A8 conflict-resolution contract **in isolation** (Design Decision 1): `KoelClient` injection and `applyStage` conflict *detection* are deferred to Story 2.14. Git-confirmed **untouched**: the `koel_core.dart` barrel, `pubspec.yaml`, `build.yaml`, every pipeline file (`applyStage` stays the 2.11 identity transformer), and the 2.12 reducer files (`chat_state*.dart`, `composed_reducer.dart`, `tool_call.dart`).
- `SessionStorage` is the four-method async SPI (`save`/`load`/`delete`/`listThreads`); `load` of an unknown thread → `null`, `delete` of an absent thread → no-op, `listThreads` → a fresh snapshot, order non-contractual. The async surface exists for the Epic 6 I/O adapters (`Hive`/`secure`).
- `InMemorySessionStorage` is a plain `Map<String, ChatState>` with **no codec and no defensive copies** — proven correct by `ChatState`'s deep immutability (Design Decision 4). A dedicated `identical(loaded, saved)` test pins the no-copy/no-serialization property; a snapshot-decoupling test pins that `listThreads` hands back a list independent of the store. Each `Future` completes synchronously via `Future.value(...)`.
- `StateConflict` is a freezed-only value type (no JSON — in-memory descriptor, Design Decision 5); `List<JsonPatchOp>` + both `Map`s get deep `==` for free. `StateConflictResolver` is the pure synchronous policy seam; `LastWriterWinsResolver` (the `const` default) applies `incomingPatches` **verbatim** onto `localState` via `JsonPatch.apply`, ignoring `snapshotState` (Design Decision 2) — proven by a test where only `localState` carries a path the output preserves.
- **Inherited the 2.12 `STATE_DELTA` `CastError` fix from day one:** `LastWriterWinsResolver.resolve` type-guards the `JsonPatch.apply` `Object?` result — a root-replacing op (`ReplaceOp(path: '')`) yields a non-`Map`, so it throws `ProtocolError(protocolMalformed)` rather than letting a `CastError` escape (dedicated regression test). `resolve` is allowed to **throw** (unlike the total reducer) — it returns a bare `Map` slice with nowhere to fold an error; the Story 2.14 apply-stage wiring catches it, exactly as the reducer's `STATE_DELTA` branch does today.
- **Quality gates:** `dart test` → **547 passed** (533 prior + 14 new, no regressions); `melos run analyze` → **0 issues** across all packages; `dart format --set-exit-if-changed .` → clean; coverage on the hand-written new files → **100% line** (`state_conflict.dart` 6/6, `in_memory_session_storage.dart` 10/10; `session_storage.dart` is a pure abstract interface with no executable lines; the resolver's lone `is! Map` branch has both arms exercised). Generated `state_conflict.freezed.dart` is gitignored (not committed).

### File List

- `packages/koel_core/lib/src/session/session_storage.dart` (NEW) — `abstract SessionStorage` 4-method async SPI.
- `packages/koel_core/lib/src/session/in_memory_session_storage.dart` (NEW) — `Map<String, ChatState>` reference impl, no I/O.
- `packages/koel_core/lib/src/state/state_conflict.dart` (NEW) — freezed `StateConflict` + `StateConflictResolver` + `LastWriterWinsResolver`.
- `packages/koel_core/test/session/in_memory_session_storage_test.dart` (NEW) — AC2 round-trip + edges + immutability/no-copy proof.
- `packages/koel_core/test/state/state_conflict_test.dart` (NEW) — AC3/AC4 value semantics + LWW verbatim + purity + inapplicable + root-replace guard.
- `packages/koel_core/lib/src/state/state_conflict.freezed.dart` (GENERATED, gitignored) — build_runner output.

## Change Log

| Date | Change |
|------|--------|
| 2026-05-30 | Story drafted (create-story). Status → ready-for-dev. |
| 2026-05-30 | Implemented `SessionStorage` + `InMemorySessionStorage` + `StateConflict`/`StateConflictResolver`/`LastWriterWinsResolver` (in isolation — no pipeline/`KoelClient` wiring) + storage & conflict-resolver tests (14 new, 100% line on hand-written files; LWW root-replace guard inherited from the 2.12 review). All gates green (547 pass, analyze 0, format clean). Status → review. |
| 2026-05-30 | Code review (3 layers): AC1–AC4 PASS, isolation scope clean, 0 correctness defects. Applied 3 test-hardening patches (AddOp root-replace guard, empty-patch no-op, two-key alias+delete). 7 findings dismissed (incl. minor `ProtocolError` message-text deviation from spec literal — non-blocking, `code` correct). Gates green (550 pass, analyze 0, format clean). Status → done. |
