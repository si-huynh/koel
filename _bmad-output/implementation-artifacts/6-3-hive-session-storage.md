---
baseline_commit: e47e112
---

# Story 6.3: `HiveSessionStorage`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter developer,
I want `HiveSessionStorage implements SessionStorage` persisting a `ChatState` (including the partial in-progress message) into a `hive_ce` box,
so that conversations — including an interrupted, mid-stream turn — survive app restarts per FR-D1.

## Context & scope (read first)

This is the **first real persistence implementation** in koel and it is **cross-package**:

- **`koel_core`** — add `toJson()` / `fromJson()` to `ChatState` and `ToolCall`. `ChatState` was authored with serialization **deliberately deferred to this point**: the class header says *"it is never serialized here (persistence is Story 2.13 / Epic 6)"* ([chat_state.dart:35-37](../../packages/koel_core/lib/src/state/chat_state.dart#L35)). 2.13 shipped the in-memory adapter without a codec; Epic 6 is the home. This is a **deliberate 1.x public-surface addition** (one-way door) — blessed by Addendum B.2 (*freezed "integrates cleanly with `json_serializable`"*) and the epic AC (*"`ChatState` serialization uses freezed's `toJson()` / `fromJson()`"*, [epic-6:67](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L67)).
- **`koel_flutter`** — add `HiveSessionStorage` over a `hive_ce` box, plus the `hive_ce` runtime dependency.

The epic's three BDD blocks ([epic-6:61-76](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L61)) are faithfully expanded below into ACs that also close two spec-reality gaps surfaced during analysis (the missing `toJson`, and the non-existent `isComplete` field). Read **Dev Notes → Design decisions** before writing any code — D1–D8 are locked.

## Acceptance Criteria

1. **`ChatState` and `ToolCall` gain freezed JSON codecs in `koel_core` (AC source: [epic-6:67](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L67)).** `packages/koel_core/lib/src/state/chat_state.dart` adds `part 'chat_state.g.dart';` and a `factory ChatState.fromJson(Map<String, dynamic> json) => _$ChatStateFromJson(json);` (the canonical freezed+JSON form — see [tool_definition.dart](../../packages/koel_core/lib/src/tool/tool_definition.dart)). `packages/koel_core/lib/src/state/tool_call.dart` does the same (`part 'tool_call.g.dart';` + `ToolCall.fromJson`). Both `*.g.dart` regenerate via `build_runner`. **A `koel_core` round-trip test proves `ChatState.fromJson(state.toJson())` is structurally equal to `state`** across: empty state; a fully-populated state (messages + `pendingMessage` + `pendingToolCalls` + non-empty `state` map + non-empty `reasoningEcho` + each `RunPhase` value).

2. **Tricky fields serialize correctly (D2, D3).** `reasoningEcho: Map<String, Uint8List>` round-trips via base64 `@JsonKey` converters — a `Uint8List` value survives `toJson`→`fromJson` byte-for-byte (D3). The non-serializable `error: KoelError?` is **excluded from the codec** (`@JsonKey(includeToJson: false, includeFromJson: false)`) — `error` is `null` after any round-trip regardless of its pre-serialization value (D2; matches [koel_error.dart:38-40](../../packages/koel_core/lib/src/error/koel_error.dart#L38) — *"Often non-serializable, which is why `KoelError` carries no JSON codec"*). A round-trip test asserts both: `reasoningEcho` bytes identical, and a state built with a non-null `error` reloads with `error == null` (other fields intact).

3. **`HiveSessionStorage` class shape matches Addendum A.6 (AC source: [epic-6:63-67](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L63)).** `packages/koel_flutter/lib/src/session_storage/hive_session_storage.dart` exposes `class HiveSessionStorage implements SessionStorage` with `HiveSessionStorage({required String boxName})` per A.6 ([addendum.md A.6](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md)). `save` / `load` / `delete` / `listThreads` are implemented against a `hive_ce` box. Serialization goes through `ChatState.toJson()` / `ChatState.fromJson()` (D5 — store `jsonEncode(state.toJson())` as a `String`, **no Hive `TypeAdapter`**). **Nothing else public** beyond `SessionStorage`'s four members + the constructor.

4. **The four methods honor the `SessionStorage` contract exactly (AC source: [session_storage.dart:18-35](../../packages/koel_core/lib/src/session/session_storage.dart#L18)).** Mirroring `InMemorySessionStorage` ([in_memory_session_storage.dart](../../packages/koel_core/lib/src/session/in_memory_session_storage.dart)): `save` is last-write-wins per `threadId`; `load` of an unknown `threadId` returns `null` and **never throws**; `delete` is **idempotent** (deleting an absent thread completes normally); `listThreads()` returns a **fresh snapshot** the caller owns, with **no ordering guarantee**. A test exercises each (save→overwrite→load, load-missing→null, delete-absent→no-throw, listThreads after 3 saves + 1 delete).

5. **Partial in-progress message survives a save/load round-trip (AC source: [epic-6:69-72](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L69)).** Given a mid-stream `ChatState` (`phase == RunPhase.running`, `pendingMessage` populated, possibly non-empty `pendingToolCalls`), `save(threadId, state)` then `load(threadId)` returns a state whose `pendingMessage` carries the **same content** and whose `phase` is still `running`. The "`isComplete: false`" marker of FR-D1 is **structural, not a new field** (D4): committed turns live in `messages` (complete); the interrupted turn lives in `pendingMessage` (incomplete). A test asserts the reloaded `pendingMessage.content`, `phase`, and that `messages` is unchanged.

6. **Persisted-JSON schema is stable for v1.0.0 (AC source: [epic-6:74-76](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L74)).** A checked-in golden JSON string representing a v1.0.0-shaped `ChatState` deserializes via `ChatState.fromJson(jsonDecode(golden))` **without error and equal to the expected state**. (The epic phrases this as a "Hive type-adapter regression" — with the `toJson`/`fromJson` strategy there are **no binary `typeId`s**, so the regression surface is the **JSON wire-shape**, which the golden pins as the v1.0.0 persistence contract.)

7. **Barrel, dartdoc, consumer-bootstrap docs, and gates.** `lib/koel_flutter.dart` exports `hive_session_storage.dart` under a banner mirroring the controller/scope banners (export **only** `HiveSessionStorage` — never re-export `SessionStorage`/`ChatState`, which reach consumers through `koel_core`). Every public symbol carries contract-form dartdoc (NFR-16). The package README documents that the **consumer bootstraps Hive** (`Hive.initFlutter()` from `hive_ce_flutter`, or `Hive.init(path)` for pure-Dart) before constructing `HiveSessionStorage` (D5). `melos run analyze` (11 pkgs clean), `melos run test` (full sweep SUCCESS), `melos run format:check` (0 changed) all green. Coverage written to the ≥90% bar (gate wiring stays Story 6.8 — see Dev Notes).

## Tasks / Subtasks

- [x] **Task 1 — `koel_core`: add JSON codec to `ChatState` + `ToolCall` (AC: 1, 2)**
  - [x] `tool_call.dart`: add `part 'tool_call.g.dart';` (after the existing `part 'tool_call.freezed.dart';`) and `factory ToolCall.fromJson(Map<String, dynamic> json) => _$ToolCallFromJson(json);` inside the class. All four fields (`id`, `name`, `arguments`, `parentMessageId`) are plain `String`/`String?` — no custom `@JsonKey` needed. Add a one-line dartdoc on the factory ("Decodes a [ToolCall] from its JSON map.") matching [tool_definition.dart](../../packages/koel_core/lib/src/tool/tool_definition.dart).
  - [x] `chat_state.dart`: add `part 'chat_state.g.dart';` and `factory ChatState.fromJson(Map<String, dynamic> json) => _$ChatStateFromJson(json);`.
  - [x] `chat_state.dart` — `error` field (D2): annotate `@JsonKey(includeToJson: false, includeFromJson: false) KoelError? error,`. `KoelError` is a sealed `Exception` with a frequently non-serializable `cause` ([koel_error.dart:38-40](../../packages/koel_core/lib/src/error/koel_error.dart#L38)); it is intentionally codec-less. Persisted error state is transient run state, not part of the conversation FR-D1 restores. **Document in the field dartdoc** that `error` is not persisted (a reloaded state has `error == null`).
  - [x] `chat_state.dart` — `reasoningEcho` field (D3): annotate `@JsonKey(toJson: _reasoningEchoToWire, fromJson: _reasoningEchoFromWire) Map<String, Uint8List> reasoningEcho,`. Add top-level helpers mirroring Message's `_timestampToWire`/`_timestampFromWire` pattern ([message.dart:69-103](../../packages/koel_core/lib/src/message/message.dart#L69)):
    ```dart
    Map<String, String> _reasoningEchoToWire(Map<String, Uint8List> echo) =>
        echo.map((k, v) => MapEntry(k, base64Encode(v)));

    Map<String, Uint8List> _reasoningEchoFromWire(Object? wire) =>
        (wire as Map<String, dynamic>).map(
          (k, v) => MapEntry(k, base64Decode(v as String)),
        );
    ```
    Add `import 'dart:convert';` (carries `base64Encode`/`base64Decode`). `dart:typed_data` (`Uint8List`) is already imported ([chat_state.dart:1](../../packages/koel_core/lib/src/state/chat_state.dart#L1)). **The `fromJson` helper takes `Object?` (not `Map<String, dynamic>`) to match Message's `_timestampFromWire`/`_contentFromWire` signatures** — json_serializable passes the raw decoded value untyped, so an `Object?` param avoids a codegen cast mismatch; the `toJson` helper takes the concrete field type (mirrors `_timestampToWire`).
  - [x] Verify `messages`/`pendingMessage` (`Message` — already JSON, [message.g.dart](../../packages/koel_core/lib/src/message/message.g.dart)), `pendingToolCalls` (`ToolCall` — now JSON), `state: Map<String, dynamic>` (pass-through), and `phase: RunPhase` (json_serializable encodes enums by name) all need **no** extra annotation. `build.yaml` already sets `field_rename: none` ([koel_core/build.yaml](../../packages/koel_core/build.yaml)) — wire keys stay verbatim camelCase.
  - [x] Regenerate: `dart run build_runner build --delete-conflicting-outputs` in `packages/koel_core`. **AI-5.9 watch:** do not bump `freezed 3.2.6-dev.1` / `analyzer 12.1.0` in `pubspec.lock`. `koel_core` already declares `json_annotation ^4.12.0` / `json_serializable ^6.8.0` / `build_runner` / `freezed` ([koel_core/pubspec.yaml](../../packages/koel_core/pubspec.yaml)) — **no new dependency**.
  - [x] `koel_core` round-trip tests (`test/state/chat_state_test.dart` — extend or create): `ChatState.fromJson(s.toJson())` equals `s` for the matrix in AC1; `reasoningEcho` bytes identical (AC2); a non-null-`error` state reloads with `error == null` (AC2). These live in `koel_core` because the types and the codec do (foundation tier, ≥90%).

- [x] **Task 2 — `koel_flutter`: add `hive_ce` dependency (AC: 3)**
  - [x] Add to `packages/koel_flutter/pubspec.yaml` `dependencies:` → `hive_ce: ^2.19.3` (the maintained successor to the abandoned `hive` — D5). **Runtime only**: the storage uses `Hive.openBox` / `Box` API; **no** `hive_ce_generator`, **no** `hive_ce_flutter` dependency (the consumer adds `hive_ce_flutter` for `initFlutter` in their own bootstrap — D5). Add a comment explaining the runtime-only / no-codegen / consumer-bootstraps rationale, in the house style of the existing pubspec comments.
  - [x] `melos bootstrap` / `dart pub get`. Confirm the lock did not bump the pinned `analyzer`/`freezed` (AI-5.9).

- [x] **Task 3 — `koel_flutter`: implement `HiveSessionStorage` (AC: 3, 4, 5)**
  - [x] Create `lib/src/session_storage/hive_session_storage.dart`. Imports: `dart:convert` (`jsonEncode`/`jsonDecode`), `package:hive_ce/hive_ce.dart` (or `package:hive_ce/hive.dart` — use the one that exports `Hive`/`Box`), `package:koel_core/koel_core.dart` (carries `SessionStorage`, `ChatState` — both barrel-exported; never import `src/`).
  - [x] `class HiveSessionStorage implements SessionStorage` with `HiveSessionStorage({required String boxName}) : _boxName = boxName;` and `final String _boxName;`. The constructor is **synchronous** (A.6-pinned) — it cannot `await` the box open.
  - [x] **Lazy box open, cached (D6):** `late final Future<Box<String>> _box = _openBox();` where `_openBox()` returns `Hive.isBoxOpen(_boxName) ? Future.value(Hive.box<String>(_boxName)) : Hive.openBox<String>(_boxName);`. Every method does `final box = await _box;` first. (Re-opening an already-open box throws in Hive — the `isBoxOpen` guard avoids it.)
  - [x] `save`: `final box = await _box; await box.put(threadId, jsonEncode(state.toJson()));` — last-write-wins (`put` overwrites).
  - [x] `load`: `final raw = (await _box).get(threadId); if (raw == null) return null; return ChatState.fromJson(jsonDecode(raw) as Map<String, dynamic>);` — missing key → `null`, no throw (AC4).
  - [x] `delete`: `await (await _box).delete(threadId);` — `Box.delete` of an absent key is a no-op (idempotent, AC4).
  - [x] `listThreads`: `return (await _box).keys.cast<String>().toList();` — `.toList()` is a fresh snapshot the caller owns; no ordering guarantee (AC4).
  - [x] Contract-form dartdoc on the class (state it persists `ChatState` JSON in a `hive_ce` box keyed by `threadId`; the consumer must initialize Hive first — D5/D7), the constructor, and each method (restate the `SessionStorage` guarantee each upholds). `HiveSessionStorage` is on the 1.x public contract.

- [x] **Task 4 — `koel_flutter`: tests (AC: 3, 4, 5, 6)**
  - [x] Create `test/session_storage/hive_session_storage_test.dart`. **Pure-Dart Hive init (D7):** `setUp` → create a unique temp dir and `Hive.init(tempDir.path)`; `tearDown` → `await Hive.deleteFromDisk()` (closes + deletes all boxes) and recursively delete the temp dir. No `flutter_test` binding is needed for plain `Hive` (only `initFlutter` needs it) — but the file still runs under `flutter test` via the package's harness routing.
  - [x] Build `ChatState` fixtures with the programmatic `MockAgent`/helpers already in [test/support/test_agent.dart](../../packages/koel_flutter/test/support/test_agent.dart) where a session is needed, or construct `ChatState`/`Message` directly for storage round-trips (no agent needed — these are pure data tests).
  - [x] AC3/AC4 contract suite: save→load equal; save-twice→load returns the second (last-write-wins); `load('absent')` → `null` (no throw); `delete('absent')` → completes (no throw); after 3 saves + 1 delete, `listThreads()` returns the remaining 2 (assert as a set — no ordering); mutating the returned list does not affect a subsequent `listThreads()`.
  - [x] AC5 partial-message suite: construct a mid-stream `ChatState(phase: RunPhase.running, messages: [committed...], pendingMessage: Message(content: 'half-written', ...))`; `save`→`load`; assert reloaded `pendingMessage!.content == 'half-written'`, `phase == RunPhase.running`, and `messages` unchanged.
  - [x] AC6 schema-stability suite: a `const goldenV1 = '{...}'` JSON string (the v1.0.0 persisted shape — hand-write it from the actual `toJson()` of a representative state, or capture once and paste); assert `ChatState.fromJson(jsonDecode(goldenV1) as Map<String, dynamic>)` loads without throwing and equals the expected `ChatState`. Keep the golden inline or under `test/session_storage/fixtures/` — this is the v1.0.0 persistence contract; a future field change that breaks it is a deliberate, reviewed schema decision, not an accident.
  - [x] Write to the ≥90% bar (every method, both `load` branches, the `isBoxOpen` open/cached paths). Coverage-gate wiring is Story 6.8.

- [x] **Task 5 — Barrel, README, gates (AC: 7)**
  - [x] `lib/koel_flutter.dart`: add `export 'src/session_storage/hive_session_storage.dart';` under a new banner `// ---- Session storage: Hive-backed persistence (F-D1) ----` mirroring the existing controller/scope banners. Export **only** `HiveSessionStorage`.
  - [x] `packages/koel_flutter/README.md`: a short "Session persistence" section — the consumer initializes Hive once at startup (`await Hive.initFlutter();` via `hive_ce_flutter`, added to *their* app, not koel) before `HiveSessionStorage(boxName: '...')`; note per-platform Hive storage locations are managed by `initFlutter` (the deeper per-platform caveat table is Story 6.4/6.7 scope). Keep it tight.
  - [x] Gates from a clean repo-root CWD: `melos run analyze`, `melos run test`, `melos run format:check`. If any intermediate sweep shows a flaky failure in `koel_http` (real-socket teardown) or a CWD-relative `koel_test` fixture miss, rule it out adversarially as in [6-2 Debug Log](6-2-koel-client-scope.md) — but a `koel_core` failure here is **in-scope** (you changed it).

### Review Findings

Code review 2026-06-05 (adversarial — Blind Hunter / Edge Case Hunter / Acceptance Auditor). No happy-path correctness bug; auditor verified AC1–AC7 + D1–D8 all satisfied and the AI-5.9 pins held. Findings are robustness / forward-compat / doc-precision.

- [ ] [Review][Patch] AC6 golden pins only the decode direction — add the encode-side assertion so additive schema drift is caught [test/session_storage/hive_session_storage_test.dart:533-541] — `fromJson(golden) == state` tolerates a *new* field with a `@Default` (old golden still decodes + equals), so the most common schema evolution slips through untested. Add `expect(jsonEncode(_goldenState().toJson()), equals(_goldenV1));` to make the golden bidirectional — this is the exact v1.0.0 wire-contract AC6/D8 claims to pin.
- [ ] [Review][Patch] `_box` dartdoc overstates consumer box-reuse [lib/src/session_storage/hive_session_storage.dart:330-332] — "a box the consumer (or a prior call) already opened is reused" is only true when the prior open used exactly `Box<String>`; `Hive.isBoxOpen` matches by name only, so a consumer-opened `Box<dynamic>` makes `Hive.box<String>` throw. Tighten the dartdoc to state the box is koel-owned (String keys, `Box<String>` values) and the reuse guard targets koel's own re-instantiation.
- [ ] [Review][Patch] AC1 per-`RunPhase` loop asserts only `.phase`, not full structural equality [test/state/chat_state_test.dart:247-256] — strengthen the loop assertion to `equals(_populated(phase: phase))` so the matrix is literally "structural round-trip per RunPhase" as AC1 phrases it (currently adequate-by-inference: full structural proven once at `running`, phase is the sole varying field).
- [x] [Review][Defer] `load()` has no decode-hardening seam — corrupt/legacy/foreign persisted JSON throws out of `load`, poisoning that thread until deleted [lib/src/session_storage/hive_session_storage.dart:350-354] — deferred. Faithful by design: the `SessionStorage` contract says I/O/decode failures surface as a future error and only *absence* returns `null` ([session_storage.dart:12-15]), and the kernel deliberately avoids speculative parsing (`Message` parity). Covers: non-object/truncated JSON (`jsonDecode`/`as Map` throw), malformed base64 / non-String `reasoningEcho` value, and an unknown `RunPhase` name (`$enumDecode` → `ArgumentError`). Real-world trigger is schema drift across an app upgrade; catch-and-drop-vs-throw is a deliberate future decision (candidate: `@JsonKey(unknownEnumValue: RunPhase.idle)` + a `load` try/return-null seam), not a 6.3 defect.
- [x] [Review][Defer] `_box` caches a *rejected* future on open failure → the instance is permanently dead, no retry [lib/src/session_storage/hive_session_storage.dart:330-332] — deferred. Direct consequence of locked D6 (`late final Future<Box<String>> _box = _openBox()`) plus the documented "consumer initializes Hive before first use" precondition (D7). Under that precondition a failed open is a programming error surfaced loudly on every call. Recorded for a future robustness pass; not changed (D6 is locked).

Dismissed as noise (4): `explicit_to_json: true` blast radius — auditor verified inert (no `koel_core` composite has nested model fields; `jsonEncode` wire output unchanged); `late final` concurrent-first-caller race — verified safe (single future cached, event-loop atomic); empty `reasoningEcho` round-trip — verified clean; `state: Map<String,dynamic>` non-JSON values throwing on save + `listThreads` non-String keys — by design (`state` holds wire JSON; the box is koel-owned, String keys only).

## Dev Notes

### Design decisions (locked — implement as stated)

- **D1 — Serialization's home is `koel_core`, and adding it is a deliberate 1.x surface addition.** `ChatState` was authored to defer its codec to exactly this point ([chat_state.dart:35-37](../../packages/koel_core/lib/src/state/chat_state.dart#L35) — *"never serialized here (persistence is Story 2.13 / Epic 6)"*). Putting `toJson`/`fromJson` on `ChatState`+`ToolCall` (rather than hand-rolling a map in `koel_flutter`) is what the epic AC mandates (*"`ChatState` serialization uses freezed's `toJson()` / `fromJson()`"*) and matches the established freezed+JSON form already used by `Message`/`ToolDefinition`. Yes, this widens `koel_core`'s public API (one-way door) — that is intended and architecturally sanctioned (Addendum B.2).

- **D2 — `error: KoelError?` is NOT persisted; it is excluded from the codec.** `@JsonKey(includeToJson: false, includeFromJson: false)`. The koel_core source already states the reason: `KoelError.cause` is *"Often non-serializable, which is why `KoelError` carries no JSON codec"* ([koel_error.dart:38-40](../../packages/koel_core/lib/src/error/koel_error.dart#L38)). FR-D1 restores the **conversation** (messages + the interrupted turn), not a live error banner — a failed run's error is stale across an app restart. **Documented caveat:** a state persisted while `phase == RunPhase.error` reloads with `phase == error` but `error == null`. That is acceptable and honest (the consumer's `error` accessor is already nullable); do **not** add phase-normalization logic — no AC asks for it, and inventing it is scope creep. Do **not** build a lossy `KoelError` JSON shim — that is a one-way-door surface expansion with no AC behind it (parity decides; see [[project_parity_decides_ambiguous_api]]).

- **D3 — `reasoningEcho: Map<String, Uint8List>` serializes via base64.** `Uint8List` has no native JSON form. Use the top-level `_reasoningEchoToWire`/`_reasoningEchoFromWire` helpers (in Task 1) wired through `@JsonKey(toJson:, fromJson:)` — the exact idiom `Message` uses for its custom `timestamp` codec ([message.dart:69-103](../../packages/koel_core/lib/src/message/message.dart#L69)). base64 is the standard, lossless byte↔string encoding; round-trip must be byte-identical (AC2).

- **D4 — The FR-D1 "`isComplete: false`" marker is STRUCTURAL — do not add an `isComplete` field.** Neither `Message` nor `ChatState` has (or gains) an `isComplete` flag. koel's model already encodes completion structurally: the reducer commits `pendingMessage → messages` on `TEXT_MESSAGE_END`, so **a turn in `messages` is complete; a turn in `pendingMessage` is in-progress/interrupted**. Persisting `pendingMessage != null` *is* the "incomplete" marker — and the epic AC explicitly allows "**(or equivalent marker per Addendum FR-D1 specification)**" ([epic-6:71](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L71)). On load, the consumer renders a non-null `pendingMessage` as the interrupted output. This keeps the `koel_core` schema unchanged and is faithful to the existing reducer contract.

- **D5 — Use `hive_ce`, not the abandoned `hive`; store JSON strings, no `TypeAdapter`.** The architecture says only "Hive" ([architecture.md:1087](../planning-artifacts/architecture.md#L1087)) — silent on `hive` vs `hive_ce`. The original `hive` (2.2.3) is effectively unmaintained; **`hive_ce`** ("Hive Community Edition", v2.19.3, 160/160 pub points, actively maintained by iodesignteam.com) is the maintained drop-in successor. Choosing the maintained fork follows the same source-evidence discipline as the lint pivot ([[project_lint_pivot_analysis_server_plugin]]) and the publish-confidence gate ([[project_publish_confidence_gate]] — don't ship v1.0.0 on abandoned-dep debt). Because the AC mandates `toJson`/`fromJson`, we store **`jsonEncode(state.toJson())` as a `String` in a `Box<String>`** — this needs **only the hive_ce runtime** (no `hive_ce_generator`, no `typeId` registry) and sidesteps Hive's `Map<dynamic,dynamic>` read-casting entirely. `delete`/`keys`/`get`/`put` are the only box ops used.

- **D6 — Sync constructor, lazy+cached box open.** A.6 pins `HiveSessionStorage({required String boxName})` — synchronous, so it cannot `await Hive.openBox`. Cache the open as `late final Future<Box<String>> _box = _openBox();` and `await _box` at the head of every method; `_openBox` guards with `Hive.isBoxOpen` (re-opening an open box throws). This keeps the pinned constructor and makes the four already-async methods clean. Do **not** introduce an async `HiveSessionStorage.open(...)` factory — A.6 lists only the unnamed constructor (surface discipline, parity with 6.1/6.2's A.6-exact reviews).

- **D7 — Box bootstrap (`Hive.initFlutter`) is the CONSUMER's job, documented, not the storage's.** `HiveSessionStorage` opens a box but never initializes Hive's storage path — that is `Hive.initFlutter()` (Flutter) or `Hive.init(path)` (pure-Dart), a one-time app-startup concern owned by the consumer. This mirrors Story 6.1/6.2's D1 ("injected collaborator ⇒ caller owns the cross-cutting setup") and how `SecureSessionStorage`'s platform setup is the consumer's (Story 6.4). koel_flutter therefore depends only on `hive_ce` (runtime) — the consumer adds `hive_ce_flutter` for `initFlutter`. Tests use `Hive.init(tempDir)` — no Flutter binding required for plain `Hive`.

- **D8 — Schema regression is JSON-shape stability, not `typeId` versioning.** The epic says "Hive type-adapter regression" ([epic-6:74](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L74)) — but with the `toJson`/`fromJson` strategy there are **no `TypeAdapter`s and no binary `typeId`s**, so there is no type-adapter version to regress. The real persistence contract is the **JSON wire-shape** of `ChatState.toJson()`. AC6 pins it with a checked-in v1.0.0 golden so any future field change that would break old persisted data is caught as a deliberate, reviewed decision.

### `SessionStorage` contract (the interface to satisfy — already in koel_core, do not modify)

`abstract class SessionStorage` ([session_storage.dart:18-35](../../packages/koel_core/lib/src/session/session_storage.dart#L18), barrel-exported):

```dart
abstract class SessionStorage {
  Future<void> save(String threadId, ChatState state);   // last-write-wins per thread
  Future<ChatState?> load(String threadId);              // null on missing, never throws on absence
  Future<void> delete(String threadId);                  // idempotent — absent thread completes normally
  Future<List<String>> listThreads();                    // fresh snapshot, caller owns it, no ordering guarantee
}
```

The reference `InMemorySessionStorage` ([in_memory_session_storage.dart](../../packages/koel_core/lib/src/session/in_memory_session_storage.dart)) is the behavioral spec to match: `_store[threadId] = state` (overwrite); `load` returns `_store[threadId]` (null for unknown); `delete` is `_store.remove` (no-op if absent); `listThreads` is `_store.keys.toList()` (fresh list). I/O failures surface by completing the future with an error — `SessionStorage` does **not** wrap them in `KoelError` (persistence is below the classifier seam, [session_storage.dart:12-15](../../packages/koel_core/lib/src/session/session_storage.dart#L12)). Absence is **not** an error.

### `ChatState` shape (koel_core — the value being persisted)

```dart
@freezed
abstract class ChatState with _$ChatState {
  const factory ChatState({
    @Default(<Message>[]) List<Message> messages,          // committed turns — JSON-ready (Message has .g.dart)
    Message? pendingMessage,                               // in-flight turn — the structural "incomplete" marker (D4)
    @Default(<ToolCall>[]) List<ToolCall> pendingToolCalls,// needs ToolCall.toJson (Task 1)
    @Default(<String, dynamic>{}) Map<String, dynamic> state,        // arbitrary wire JSON — pass-through
    @Default(<String, Uint8List>{}) Map<String, Uint8List> reasoningEcho, // base64 codec (D3)
    KoelError? error,                                      // EXCLUDED from codec (D2)
    @Default(RunPhase.idle) RunPhase phase,                // enum — json_serializable encodes by name
  }) = _ChatState;
}
```

`RunPhase` values: `idle`, `running`, `stepRunning`, `error`, `cancelled` ([chat_state.dart:18-33](../../packages/koel_core/lib/src/state/chat_state.dart#L18)). The AC1 round-trip matrix must cover each.

### Canonical freezed+JSON form to copy (already in the repo)

`ToolDefinition` is the template — same package, same generators:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';
part 'tool_definition.freezed.dart';
part 'tool_definition.g.dart';

@freezed
abstract class ToolDefinition with _$ToolDefinition {
  const factory ToolDefinition({ ... }) = _ToolDefinition;
  factory ToolDefinition.fromJson(Map<String, dynamic> json) =>
      _$ToolDefinitionFromJson(json);
}
```

Round-trip test idiom (from [tool_definition_test.dart:44-50](../../packages/koel_core/test/tool/tool_definition_test.dart#L44)): `expect(ChatState.fromJson(s.toJson()), equals(s));`. `ChatState`/`Message`/`ToolCall` are deeply-immutable freezed types with structural `==`, so `equals` is a true value compare.

### Project Structure Notes

- New file: `packages/koel_flutter/lib/src/session_storage/hive_session_storage.dart` — matches the architecture source tree exactly ([architecture.md:900-902](../planning-artifacts/architecture.md#L900) — `session_storage/hive_session_storage.dart`). The `session_storage/` directory is new; `secure_session_storage.dart` (Story 6.4) lands beside it next.
- Modified in `koel_core`: `lib/src/state/chat_state.dart`, `lib/src/state/tool_call.dart` (+ regenerated `*.g.dart`/`*.freezed.dart`, gitignored). Modified in `koel_flutter`: `lib/koel_flutter.dart` (barrel), `pubspec.yaml` (hive_ce), `README.md`.
- This is the **third** symbol in `koel_flutter` (after `KoelChatController`, `KoelClientScope`). It is the first to touch `koel_core` — keep that change minimal (codec only; no behavior change to the reducer or any existing field).
- No codegen in `koel_flutter` (it has no `build_runner`/`freezed`); the only codegen is in `koel_core` (Task 1).

### Carry-ins from Story 6.1 / 6.2 / Epic-5 retro

- **AI-5.9 (freezed `3.2.6-dev.1` / analyzer `12.1.0` pin watch)** — Task 1 regenerates `koel_core` codegen and Task 2 adds a `koel_flutter` dependency; after both, confirm `pubspec.lock` did **not** bump those pins. Do not bump.
- **Flutter test-harness routing** — `tool/test_package.sh` already routes `koel_flutter` to `flutter test` (landed in 6.1); `koel_core` runs `dart test`. No harness change here. (The latent 6.1 deferred item — Flutter-branch line + coarse grep — is not triggered by 6.3.)
- **A.6-exact surface discipline** — 6.1 dropped the controller's `tools` param and 6.2 omitted `maybeOf` to stay verbatim-A.6. Same here: `HiveSessionStorage` exposes only the A.6 constructor + the four `SessionStorage` members. No `open` factory, no extra config knobs.
- **House pattern — injected collaborator ⇒ caller owns cross-cutting lifecycle** (6.1 D1, 6.2 D1, here D7): the storage opens a box but the consumer initializes Hive.

### References

- [Source: epics/epic-6-flutter-glue-persistence-koelflutter.md#Story-6.3] (lines 55-77) — user story + the three BDD ACs (surface, partial-persistence, schema regression).
- [Source: prds/prd-koel-2026-05-27/addendum.md#A.6] — canonical `HiveSessionStorage({required String boxName})` + `SessionStorage` abstract surface.
- [Source: prds/prd-koel-2026-05-27/addendum.md#B.2] — freezed + json_serializable serialization strategy (toJson/fromJson, not TypeAdapters).
- FR-D1 — PRD §8 F-D1 (SessionStorage adapter + partial persistence; partial messages persist as interrupted).
- [Source: packages/koel_core/lib/src/session/session_storage.dart] — the interface contract (null-on-missing, idempotent delete, snapshot listThreads, below the classifier seam).
- [Source: packages/koel_core/lib/src/session/in_memory_session_storage.dart] — reference behavioral spec to match.
- [Source: packages/koel_core/lib/src/state/chat_state.dart#L35] — serialization-deferred-to-Epic-6 comment; the 7-field shape; `RunPhase`.
- [Source: packages/koel_core/lib/src/state/tool_call.dart] — `ToolCall` (needs the new codec).
- [Source: packages/koel_core/lib/src/error/koel_error.dart#L38] — `KoelError` is intentionally codec-less ("often non-serializable cause") — basis for D2.
- [Source: packages/koel_core/lib/src/message/message.dart#L69] — the `@JsonKey(toJson:,fromJson:)` + top-level-helper idiom to mirror for `reasoningEcho` (D3).
- [Source: packages/koel_core/lib/src/tool/tool_definition.dart] — canonical freezed+JSON class form to copy.
- [Source: architecture.md#L900] — source-tree placement of `session_storage/hive_session_storage.dart`.
- [Source: architecture.md#L1087] — "Session storage → Hive / flutter_secure_storage / in-memory (consumer-pluggable)".
- [Source: _bmad-output/implementation-artifacts/6-2-koel-client-scope.md] — sibling story; A.6-exact discipline, injected-collaborator lifecycle pattern, flaky-gate triage idiom.
- `hive_ce` 2.19.3 / `hive_ce_flutter` 2.3.4 (pub.dev, publisher iodesignteam.com) — maintained Hive successor (basis for D5).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context) — via `/bmad-dev-story`, specialist `agent-flutter-engineer` (Implement mode).

### Debug Log References

- **AC1 literal `ChatState.fromJson(state.toJson())` failed on first run** — `type '_Message' is not a subtype of type 'Map<String, dynamic>'`. Root cause: json_serializable's default `explicit_to_json: false` emits nested `Message`/`ToolCall` **raw** in `toJson()` (relying on a later `jsonEncode` to call their `.toJson()`), so a direct `fromJson(toJson())` with no intervening encode sees real model objects. ToolDefinition's round-trip only passed because it has no nested codec types. Fix: set `explicit_to_json: true` in `koel_core/build.yaml` (recurse into nested `toJson()`); final `jsonEncode` wire-shape is identical, so no wire change and no regression (full koel_core sweep 587 green after regen).
- **AI-5.9 pin watch** — after codegen regen (Task 1) and `melos bootstrap` for `hive_ce` (Task 2), confirmed `pubspec.lock` held `analyzer 12.1.0` / `freezed 3.2.6-dev.1`; lock diff added only the `hive_ce` subtree, no pin bump.
- **Golden capture (AC6)** — `_goldenV1` was captured once from `jsonEncode(_goldenState().toJson())` via a throwaway script (deleted), not hand-written, so it is the true v1.0.0 wire-shape.

### Completion Notes List

- **Task 1 (koel_core codec)** — `ToolCall` + `ChatState` gained `part '*.g.dart'` and `fromJson`. `error` excluded via `@JsonKey(includeToJson/FromJson: false)` (D2); `reasoningEcho` base64 via top-level `_reasoningEchoToWire`/`_reasoningEchoFromWire` (`Object?` fromJson param, mirroring `Message._timestampFromWire`) (D3). `build.yaml` gained `explicit_to_json: true` (see Debug Log). 5 round-trip tests in `koel_core/test/state/chat_state_test.dart` cover the AC1 matrix (empty / fully-populated / every `RunPhase`), AC2 byte-identical `reasoningEcho`, and AC2 `error → null`.
- **Task 2 (dependency)** — `hive_ce: ^2.19.3` added to `koel_flutter` (runtime only — no `hive_ce_generator`, no `hive_ce_flutter`), resolved to 2.19.3.
- **Task 3 (impl)** — `HiveSessionStorage implements SessionStorage` with the A.6-exact `HiveSessionStorage({required String boxName})`. Sync constructor + lazy/cached `late final Future<Box<String>> _box` guarded by `Hive.isBoxOpen` (D6). Stores `jsonEncode(state.toJson())` in a `Box<String>`, no `TypeAdapter` (D5). Four methods honor the contract: last-write-wins `save`, null-on-missing `load`, idempotent `delete`, fresh-unordered-snapshot `listThreads`. Public surface = constructor + 4 members only.
- **Task 4 (tests)** — 9 tests in `koel_flutter/test/session_storage/hive_session_storage_test.dart`: pure-Dart `Hive.init(tempDir)` setUp / `Hive.deleteFromDisk()` tearDown (D7); AC3/AC4 contract suite (save→load, last-write-wins, load-missing→null, delete-absent→no-throw, listThreads-after-delete-as-set, snapshot-ownership, second-instance `isBoxOpen` reuse); AC5 mid-stream `pendingMessage`/`phase`/`messages` round-trip; AC6 golden decode. Coverage hits every method, both `load` branches, both `_openBox` paths.
- **Task 5 (barrel/README/gates)** — barrel exports **only** `HiveSessionStorage` under the F-D1 banner; README gained a "Session persistence" section documenting consumer Hive bootstrap (D5/D7). Gates green from repo root: `melos run analyze` (11 pkgs clean), `melos run test` (full sweep SUCCESS — koel_flutter 19→28, koel_core +5), `melos run format:check` (0 changed).
- **D4 honored** — no `isComplete` field added; the structural `pendingMessage != null` marker carries "interrupted", asserted by the AC5 test.

### File List

- `packages/koel_core/lib/src/state/chat_state.dart` (modified — JSON part, `fromJson`, `error`/`reasoningEcho` `@JsonKey`, base64 helpers, `dart:convert`)
- `packages/koel_core/lib/src/state/tool_call.dart` (modified — JSON part, `fromJson`)
- `packages/koel_core/build.yaml` (modified — `explicit_to_json: true`)
- `packages/koel_core/test/state/chat_state_test.dart` (new — codec round-trip tests)
- `packages/koel_flutter/lib/src/session_storage/hive_session_storage.dart` (new — `HiveSessionStorage`)
- `packages/koel_flutter/lib/koel_flutter.dart` (modified — barrel export)
- `packages/koel_flutter/pubspec.yaml` (modified — `hive_ce` dependency)
- `packages/koel_flutter/README.md` (modified — Session persistence section)
- `packages/koel_flutter/test/session_storage/hive_session_storage_test.dart` (new — storage tests)
- `pubspec.lock` (modified — `hive_ce` subtree added; analyzer/freezed pins held)
- Regenerated (gitignored): `packages/koel_core/lib/src/state/chat_state.g.dart`, `tool_call.g.dart`, `*.freezed.dart`

## Change Log

- 2026-06-05 — Story 6.3 code review → **done**. 3-layer adversarial (Blind Hunter / Edge Case Hunter / Acceptance Auditor): AC1–AC7 + D1–D8 all verified PASS, A.6-exact surface, AI-5.9 pins held. 3 patches applied — (1) AC6 golden made bidirectional (`expect(jsonEncode(_goldenState().toJson()), equals(_goldenV1))`) so additive schema drift is caught, fully realizing D8's wire-contract pin; (2) `_box` dartdoc tightened (koel-owned box, reuse guard scoped to koel's own re-instantiation, not a consumer-pre-opened `Box<dynamic>`); (3) AC1 per-`RunPhase` loop strengthened from `.phase`-only to full structural `equals(s)`. 2 deferred (deferred-work.md) — `load()` decode-hardening (contract-faithful: errors surface, absence→`null`, + `Message` no-speculative-parse parity; covers unknown `RunPhase`/corrupt JSON) and `_box` rejected-future caching (consequence of locked D6 + D7 precondition). 4 dismissed — `explicit_to_json` verified inert, `late final` race safe, empty `reasoningEcho` clean, `state` non-JSON / non-String keys by-design. +1 test (koel_flutter 28→29). All gates re-green: analyze 11 pkgs clean, full sweep SUCCESS, format:check 0 changed.
- 2026-06-05 — Story 6.3 `HiveSessionStorage` implemented → review. koel_core: `ChatState`/`ToolCall` JSON codec (`error` excluded D2, `reasoningEcho` base64 D3), `build.yaml` `explicit_to_json: true` (nested `toJson` recursion — required for AC1's literal `fromJson(toJson())`; wire-shape unchanged). koel_flutter: `hive_ce ^2.19.3` runtime dep, `HiveSessionStorage` (sync ctor + lazy/cached `isBoxOpen`-guarded box D6, JSON-string storage no `TypeAdapter` D5, consumer-bootstraps-Hive D7), barrel export, README section. 14 tests added (koel_core +5, koel_flutter +9). All gates green: analyze 11 pkgs clean, full test sweep SUCCESS, format:check 0 changed; AI-5.9 pins (analyzer 12.1.0 / freezed 3.2.6-dev.1) held.
- 2026-06-05 — Story 6.3 `HiveSessionStorage` created (ready-for-dev). Cross-package: adds `toJson`/`fromJson` to `ChatState`+`ToolCall` in koel_core (deferred-serialization home per chat_state.dart:37), implements Hive-backed `SessionStorage` over `hive_ce` in koel_flutter. Resolved spec-reality gaps: `error` excluded from codec (D2, koel_error is intentionally codec-less), `reasoningEcho` base64 (D3), structural `pendingMessage` "incomplete" marker instead of a non-existent `isComplete` field (D4), `hive_ce` over abandoned `hive` (D5), JSON-shape golden instead of typeId regression (D8).
