---
baseline_commit: 025b899177fb9096ccd58fc0e335f731b9269dfe # feat(story-2.5) — HEAD at story creation
---

# Story 2.6: `TOOL_CALL_*` + `STATE_*` + `MESSAGES_SNAPSHOT` event subtypes

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter/Dart developer,
I want typed event subtypes for tool calls and state synchronization — `ToolCallStartEvent`, `ToolCallArgsEvent`, `ToolCallEndEvent`, `ToolCallResultEvent`, `ToolCallChunkEvent`, `StateSnapshotEvent`, `StateDeltaEvent`, `MessagesSnapshotEvent` — joined into the sealed `AgUiEvent` union and wired into the deserializer registry,
so that consumers can render tool execution and react to state changes with full type safety per FR-A7.

**Why this story now.** Story 2.5 shipped the **first** concrete `AgUiEvent` members (RUN×3, STEP×2, TEXT_MESSAGE×4) and **froze the per-event codec template**: freezed-only (`@freezed abstract class X extends AgUiEvent with _$X` + `const X._() : super();`), a hand-written discriminator-first `toJson`, a `static X fromJson(Map<String, dynamic>)` tear-off registered in `eventTypeRegistry`, shared helpers in `event_codec.dart`. Story 2.6 is the **second** application of that template and the first to consume **two cross-package leaf codecs** — `JsonPatchOp` (Story 2.4, hand-rolled) for `STATE_DELTA`, and `Message` (Story 2.1, json_serializable) for `MESSAGES_SNAPSHOT`. It is also the first event family where a **Dart field name diverges from its wire key** (`state`↔`snapshot`, `patches`↔`delta`). Get those two seams right; 2.7 (`ACTIVITY_*`/`REASONING_*`) and 2.8 (`RAW`/`CUSTOM` + 28-event sweep) close out the union on the same template.

**Scope reality check.** This story ships the **8 event subtypes** (5 TOOL_CALL, 3 STATE/MESSAGES) as freezed-immutable members of the sealed `AgUiEvent` union, their hand-rolled `type`-discriminated `fromJson`/`toJson` codecs, two new shared decode helpers in `event_codec.dart` (`_requireMap`, `_decodeObjectList`), and their registration in `eventTypeRegistry`. It does **NOT** ship: chunk synthesis (the `TOOL_CALL_CHUNK → START/ARGS/END` expansion is the `chunks` pipeline stage in Story 2.11, Addendum F.2), verify-stage semantic rules (`TOOL_CALL_END` without matching `START`, **empty `STATE_DELTA.patches`**, `TOOL_CALL_ARGS` outside an envelope — Story 2.11 / Addendum F.1), `JsonPatch.apply` invocation against a live state document (the reducer's `STATE_*` handling, Story 2.12), the `StateConflict`/`LastWriterWinsResolver` path (Story 2.13), the remaining 11 event types (2.7–2.8), or the barrel export (frozen until 2.15). `StateDeltaEvent` **decodes** its patches via `JsonPatchOp.fromJson` and re-serializes via `JsonPatchOp.toJson`; it does **not** apply them. `MessagesSnapshotEvent` delegates element (de)serialization to the already-shipped `Message.fromJson`/`Message.toJson` — no new message codec.

## Acceptance Criteria

**AC1 — two event files ship the 8 freezed subtypes, joined to the sealed union**
**Given** `koel_core/lib/src/event/tool_call_events.dart` and `koel_core/lib/src/event/state_events.dart`,
**When** I inspect each file,
**Then** each is a `part of 'ag_ui_event.dart'` and defines its family's concrete subclasses of `AgUiEvent` — `tool_call_events.dart`: `ToolCallStartEvent`, `ToolCallArgsEvent`, `ToolCallEndEvent`, `ToolCallResultEvent`, `ToolCallChunkEvent`; `state_events.dart`: `StateSnapshotEvent`, `StateDeltaEvent`, `MessagesSnapshotEvent`,
**And** every subtype is freezed-generated (`@freezed abstract class X extends AgUiEvent with _$X` + `const X._() : super();` + `const factory X(...) = _X;`) using the sealed-parent + private-`._()`-ctor idiom proven by 2.2/2.3/2.4/2.5 — verified by running `build_runner`, not assumed (retro A1),
**And** the field shapes match the AG-UI `release/2026-05-26` wire format per the table in Dev Notes "Wire-format field shapes",
**And** `ToolCallChunkEvent` carries `toolCallId`, `toolCallName`, `parentMessageId`, `delta` — **all `String?` optional** — per Addendum §A.1 / F.2,
**And** `StateDeltaEvent` carries `final List<JsonPatchOp> patches` consuming the Story-2.4 RFC 6902 op type (no new patch type),
**And** `MessagesSnapshotEvent` carries `final List<Message> messages` consuming the Story-2.1 `Message` type (no new message type),
**And** `ag_ui_event.dart` adds `part 'tool_call_events.dart';` and `part 'state_events.dart';` and the two imports `'../json_patch/json_patch_op.dart'` + `'../message/message.dart'` that `StateDeltaEvent`/`MessagesSnapshotEvent` need.

**AC2 — hand-rolled, `type`-discriminated codecs; freezed-only (no `*.g.dart` for events); wire-key ≠ field-name handled**
**Given** the codec wiring,
**When** I inspect it,
**Then** each subtype carries a hand-written `Map<String, dynamic> toJson()` whose first entry is its wire discriminator (`'type': 'TOOL_CALL_START'`, `'STATE_SNAPSHOT'`, …) followed by its fields, omitting absent optionals,
**And** each subtype exposes a `static X fromJson(Map<String, dynamic> json)` usable as an `AgUiEvent Function(Map<String, dynamic>)` registry value (form **(a)** from Story 2.5 — confirmed not to trigger `json_serializable`; verify via `build_runner`),
**And** the wire-key↔field-name divergences are codec-internal: `StateSnapshotEvent.state` reads/writes wire key `snapshot`; `StateDeltaEvent.patches` reads/writes wire key `delta` (an array of patch ops); the Dart names follow Addendum §A.1, the wire keys follow the AG-UI spec — see Dev Notes "Wire-key vs Dart field name",
**And** **no** `json_serializable` is applied to any event subtype and **no** `*.g.dart` is produced for the event family — `StateDeltaEvent` delegates to `JsonPatchOp.fromJson`/`.toJson` (hand-rolled) and `MessagesSnapshotEvent` delegates to `Message.fromJson`/`.toJson` (the leaf type's own generated `*.g.dart`, already shipped in 2.1 — the event itself emits none),
**And** two new shared codec helpers live in `event_codec.dart` (`part of 'ag_ui_event.dart'`): `Map<String, dynamic> _requireMap(json, key)` and `List<T> _decodeObjectList<T>(json, key, T Function(Map<String, dynamic>) decode)`, both throwing `ProtocolError(protocolMalformed)` on a missing/wrong-typed member, mirroring the existing `_requireString`/`_optionalString`.

**AC3 — `eventTypeRegistry` maps all 8 wire types to their concrete subtype; dispatcher round-trips**
**Given** `koel_core/lib/src/event/event_deserializer.dart`,
**When** I inspect `eventTypeRegistry`,
**Then** it now maps **seventeen** wire strings (the nine from 2.5 **plus** these eight): `TOOL_CALL_START`, `TOOL_CALL_ARGS`, `TOOL_CALL_END`, `TOOL_CALL_RESULT`, `TOOL_CALL_CHUNK`, `STATE_SNAPSHOT`, `STATE_DELTA`, `MESSAGES_SNAPSHOT`,
**And** `deserializeAgUiEvent(wireJson)` produces the correct concrete subtype with all fields populated for each of the eight families given sample wire JSON,
**And** for every sample, `deserializeAgUiEvent(event.toJson())` re-dispatches to the **same** concrete subtype, structurally equal to the original (the `type` discriminator on `toJson` makes the event re-routable — the property the 2.8 full-sweep relies on),
**And** `StateSnapshotEvent.state` and `MessagesSnapshotEvent.messages` round-trip the embedded JSON without information loss (nested state object preserved via freezed deep equality; `Message` list preserved via `Message`'s own codec, including `DateTime` and the optional `toolCallId`/`name`).

**AC4 — round-trip + structural-equality tests per subtype; cross-type codec delegation proven**
**Given** the test suite under `koel_core/test/event/`,
**When** I run `dart test test/event/`,
**Then** every one of the eight subtypes has at least one positive deserialization test (wire JSON → typed event, fields asserted) **and** one round-trip test (`deserializeAgUiEvent(e.toJson())` — or `X.fromJson(e.toJson())` — structurally equals `e`, leaning on freezed's generated `==`),
**And** `StateDeltaEvent` round-trips a multi-op patch list (e.g. `[add, remove, replace]`) through `JsonPatchOp.fromJson`/`.toJson` with structural equality, **and** an empty `delta: []` decodes to `patches: []` **without throwing** (the empty-patches rejection is the verify stage's job in 2.11, not the decoder's — see Dev Notes),
**And** `MessagesSnapshotEvent` round-trips a list of ≥2 `Message`s carrying every field shape — a plain user/assistant turn **and** a tool-role message with `toolCallId`+`name` — proving delegation to `Message`'s codec is lossless,
**And** `ToolCallResultEvent` round-trips both with and without the optional `role`, and `ToolCallChunkEvent` round-trips the all-`null` empty chunk (`{'type':'TOOL_CALL_CHUNK'}`) and a partially-populated chunk,
**And** negative tests confirm: a missing required member (e.g. `TOOL_CALL_START` without `toolCallId`) throws `ProtocolError(protocolMalformed)`; a non-`Map` `snapshot` on `STATE_SNAPSHOT`, a non-`List` `delta` on `STATE_DELTA`, a non-`List` `messages` on `MESSAGES_SNAPSHOT`, and a `delta`/`messages` **list element** that is not an object each throw `ProtocolError(protocolMalformed)` (not a raw `TypeError`),
**And** line + branch coverage on the new event sources (excluding generated `ag_ui_event.freezed.dart`) is **≥ 90%** per NFR-12.

**AC5 — repo stays green; codegen deterministic; nothing committed; barrel untouched**
**Given** the workspace after this story lands,
**When** I run the toolchain,
**Then** `cd packages/koel_core && dart run build_runner build` regenerates `ag_ui_event.freezed.dart` (now covering the 8 new subtypes) with **no** new `*.g.dart` for events, and a re-run writes 0 outputs (deterministic; `codegen-drift` green),
**And** `cd packages/koel_core && dart test` passes (existing 288 + the new event tests),
**And** `melos run analyze` exits 0 across all packages including `koel_lints` — with **no** default-less `switch` over `AgUiEvent` introduced into the analyzed tree (the deserializer is a `Map` lookup; the new codecs read getters / `.map`; `StateDeltaEvent` calls `JsonPatchOp.toJson` per element but never `switch`es the `AgUiEvent` union — see Dev Notes "koel_lints + AgUiEvent"),
**And** `melos run format:check` exits 0,
**And** `git ls-files '*.freezed.dart' '*.g.dart'` shows nothing staged/tracked, and the barrel `lib/koel_core.dart` is **not** touched (frozen until 2.15),
**And** no `pubspec.yaml`/`build.yaml` change (no new dependency — `json_patch_op.dart` and `message.dart` are already in-package).

## Tasks / Subtasks

- [x] **Task 1 — shared decode helpers `_requireMap` + `_decodeObjectList` in `event_codec.dart` (AC2)** — red → green → refactor
  - [x] RED: fold into the per-family tests (Tasks 2–3); both helpers are library-private, so their `ProtocolError(protocolMalformed)` behavior is asserted through `StateSnapshotEvent`/`StateDeltaEvent`/`MessagesSnapshotEvent` negative cases. Confirm RED (helpers undefined).
  - [x] GREEN: add to `event_codec.dart` — `Map<String, dynamic> _requireMap(Map<String, dynamic> json, String key)` (absent/non-`Map` → `ProtocolError(protocolMalformed)`); `List<T> _decodeObjectList<T>(Map<String, dynamic> json, String key, T Function(Map<String, dynamic>) decode)` (absent/non-`List` → `ProtocolError`; any element not a `Map<String, dynamic>` → `ProtocolError`; else maps each element through `decode`, returning a `List<T>` — an **empty** input list returns an empty output list, no throw). Mirror the existing `_requireString` error message/`cause: json` shape.
  - [x] REFACTOR: one-line internal-codec-glue dartdoc on each, matching the existing helpers' tone. `build_runner` confirms they compile inside the library.

- [x] **Task 2 — `tool_call_events.dart`: Start/Args/End/Result/Chunk (AC1/AC2/AC4)** — red → green → refactor
  - [x] RED: `test/event/tool_call_events_test.dart` — per subtype: const construction, `isA<AgUiEvent>()`/`isA<X>()`, structural equality (`==` + `hashCode`; differ on any field → `!=`), `copyWith`, `fromJson` with fields asserted, dual round-trip via `X.fromJson(e.toJson())` **and** `deserializeAgUiEvent(e.toJson())`. `ToolCallResultEvent`: round-trip with and without optional `role`. `ToolCallChunkEvent`: empty `{'type':'TOOL_CALL_CHUNK'}` → all-`null` (no throw) + round-trip; partial chunk omits absent optionals. Negatives: missing `toolCallId` (Start/Args/End), missing `toolCallName` (Start), missing `delta` (Args), missing `messageId`/`toolCallId`/`content` (Result) → `ProtocolError(protocolMalformed)`; present-but-non-`String` required + optional → `ProtocolError` (the SF-1 lesson from 2.5). Confirm RED.
  - [x] GREEN: implement the five subtypes per the Wire-format table. Required decode via `_requireString`; optionals via `_optionalString`; `toJson` discriminator-first, absent optionals omitted. `build_runner` confirms the generated parts satisfy `extends AgUiEvent`.
  - [x] REFACTOR: contract-form dartdoc on each — `ToolCallStartEvent`/`ArgsEvent`/`EndEvent` are the canonical long form (Start→N×Args→End share `toolCallId`; concat `Args.delta` to reconstruct the JSON args string); `ToolCallResultEvent` is the agent-emitted backend-tool result (`role` permissive `String?`, wire-defaults to `"tool"` but **not** injected — absent stays absent for lossless round-trip); `ToolCallChunkEvent` is the convenience shape the `chunks` stage (2.11) expands into Start/Args/End per Addendum F.2 — 2.6 ships only the typed value.

- [x] **Task 3 — `state_events.dart`: Snapshot/Delta/MessagesSnapshot (AC1/AC2/AC4)** — red → green → refactor
  - [x] RED: `test/event/state_events_test.dart` — per subtype: construction, `isA`, structural equality, `copyWith`, `fromJson`, dual round-trip. `StateSnapshotEvent`: a nested-object `snapshot` round-trips (freezed deep equality on `Map<String, dynamic>`). `StateDeltaEvent`: multi-op `[add, remove, replace]` round-trips through `JsonPatchOp`; empty `delta: []` → `patches: []` (no throw). `MessagesSnapshotEvent`: ≥2 `Message`s incl. a tool-role message with `toolCallId`+`name` round-trip losslessly (incl. `DateTime`). Negatives: missing/`non-Map` `snapshot`; missing/non-`List` `delta`; non-`Map` `delta` **element**; missing/non-`List` `messages`; non-`Map` `messages` **element** → `ProtocolError(protocolMalformed)`. Confirm RED.
  - [x] GREEN: `StateSnapshotEvent{Map<String, dynamic> state}` ← `_requireMap(json, 'snapshot')`; `toJson` → `{'type':'STATE_SNAPSHOT', 'snapshot': state}`. `StateDeltaEvent{List<JsonPatchOp> patches}` ← `_decodeObjectList(json, 'delta', JsonPatchOp.fromJson)`; `toJson` → `{'type':'STATE_DELTA', 'delta': [for (final p in patches) p.toJson()]}`. `MessagesSnapshotEvent{List<Message> messages}` ← `_decodeObjectList(json, 'messages', Message.fromJson)`; `toJson` → `{'type':'MESSAGES_SNAPSHOT', 'messages': [for (final m in messages) m.toJson()]}`. Add the two imports to `ag_ui_event.dart`. `build_runner`; green.
  - [x] REFACTOR: dartdoc — `StateSnapshotEvent` is the full-state replace (cold start / resync); `StateDeltaEvent` carries RFC 6902 ops the reducer (2.12) folds via `JsonPatch.apply` — **this event only transports them**, the empty-patches + invalid-op rejection is the verify stage (2.11 / Addendum F.1); `MessagesSnapshotEvent` is the full history replay. Note the `state`↔`snapshot` and `patches`↔`delta` wire-key divergence explicitly in dartdoc.

- [x] **Task 4 — register all 8 in `eventTypeRegistry` + dispatcher integration tests (AC3/AC5)** — red → green
  - [x] RED: extend `test/event/event_deserializer_test.dart` — `eventTypeRegistry.keys` is exactly the **seventeen** wire strings (nine from 2.5 + eight new); `deserializeAgUiEvent(sample)` yields the right subtype for each new type; unknown type still falls back to `UnknownAgUiEvent` (2.2 regression guard). Confirm RED (the nine-key `unorderedEquals` assertion fails).
  - [x] GREEN: add the eight `'WIRE_TYPE': XEvent.fromJson` static tear-offs to the `const` map; `deserializeAgUiEvent` body untouched. Update the registry doc comment to note 2.6's eight additions. Green.
  - [x] Update the `event_deserializer_test.dart` key assertion from nine to seventeen.

- [x] **Task 5 — Definition-of-done validation (AC5)**
  - [x] `dart run build_runner build` → exits 0; updated `ag_ui_event.freezed.dart`, **no** new `*.g.dart` for events. Re-run → wrote 0 outputs (deterministic).
  - [x] `dart test` → all green (288 baseline + new event tests).
  - [x] `melos run analyze` → SUCCESS across all packages incl. `koel_lints`; 0 issues. No default-less `switch` over `AgUiEvent`.
  - [x] `melos run format:check` → exit 0. (Watch the brace-less-guard reflow gotcha from 2.4 if any `if (x != null)` map entry is introduced — prefer the `'k': ?x` null-aware element where it applies.)
  - [x] Coverage: `dart test --coverage` + `format_coverage` scoped to `lib/src/event` (excl. `ag_ui_event.freezed.dart`) → ≥ 90% line **and** branch (the list/map guard branches must be exercised by the positive / negative / empty-list / optional-present-and-absent matrix). Report the exact %.
  - [x] `git ls-files '*.freezed.dart' '*.g.dart'` → empty. Barrel `lib/koel_core.dart` untouched. No new dep, no pubspec/build.yaml change, no pipeline/reducer/classifier code, no other event families.
  - [x] Update File List + Completion Notes + Change Log; record cross-story handoffs.

### Review Findings

_Code review 2026-05-30 (`/bmad-code-review`) — 3 layers (Blind Hunter, Edge Case Hunter, Acceptance Auditor); Acceptance Auditor reported all five ACs satisfied. Findings below verified against source (`message.g.dart`, `event_codec.dart`, `json_patch_op.dart`)._

- [x] [Review][Patch] (applied 2026-05-30) `MessagesSnapshotEvent` leaks raw `TypeError`/`FormatException`/`ArgumentError` on a malformed message field — `_decodeObjectList` guards element-is-`Map<String,dynamic>` then delegates to `Message.fromJson` (`state_events.dart:77-80`). Unlike the `STATE_DELTA`→`JsonPatchOp.fromJson` path (which raises typed `ProtocolError`), `Message.fromJson` is json_serializable-generated (`message.g.dart`) and does raw casts: `json['id'] as String`, `json['content'] as String`, `DateTime.parse(json['timestamp'] as String)`, `$enumDecode(_$MessageRoleEnumMap, json['role'])`. A `MESSAGES_SNAPSHOT` whose message has an absent/non-`String` `id`/`content`, an absent/non-`String`/unparseable `timestamp`, or an absent/unknown `role` throws a raw non-`ProtocolError`, contradicting `_decodeObjectList`'s own dartdoc and the SF-1 lesson. `state_events.dart:79` is the **only** inbound `Message.fromJson` call site in `lib/` (`RunAgentInput` is outbound, no `fromJson`), so 2.6 is the first story to decode `Message` from untrusted wire — the typed-error contract for that path is this story's responsibility. **Resolution (decided 2026-05-30):** harden inside `_decodeObjectList` (`event_codec.dart`) — wrap the `decode(element)` call; rethrow `ProtocolError` as-is, normalize any other throw to `ProtocolError(protocolMalformed, cause: error)`. Generic + future-proof (every list-delegation leaf inherits the typed-error guarantee), does not touch the 2.1 `Message` leaf. Add a negative test (e.g. message missing `id` / unparseable `timestamp` / unknown `role`) to lock it.
- [x] [Review][Patch] (applied 2026-05-30) `copyWith` asserted on only 2 of 8 subtypes (`ToolCallStartEvent`, `ToolCallEndEvent`) though Task 2/3 RED list `copyWith` per subtype [packages/koel_core/test/event/tool_call_events_test.dart, packages/koel_core/test/event/state_events_test.dart] — low priority (freezed-generated; ≥90% coverage independently met), but a deviation from the story's stated test plan.

## Dev Notes

### What this story is — and is not
- **Is:** the 8 freezed-immutable event subtypes (TOOL_CALL×5, STATE×2, MESSAGES_SNAPSHOT×1), their hand-rolled `type`-discriminated `fromJson`/`toJson`, two new `event_codec.dart` helpers (`_requireMap`, `_decodeObjectList`), `eventTypeRegistry` registration, and per-subtype positive + round-trip + negative tests at ≥90% line **and** branch coverage. Replicates 2.5's template; adds cross-type codec delegation.
- **Is not:** chunk synthesis (2.11 `chunks` stage, Addendum F.2), verify-stage rules (2.11 / Addendum F.1: `TOOL_CALL_END` without matching `START`, **empty/invalid `STATE_DELTA`**, args-outside-envelope), `JsonPatch.apply` against a live document (2.12 reducer `STATE_*` folding), `StateConflict`/`LastWriterWinsResolver` (2.13), the other 11 event types (2.7–2.8), the barrel export (2.15). Do **not** stub these — placeholders invite churn (the discipline 2.1–2.5 held).

### Wire-format field shapes (AG-UI `release/2026-05-26` — authoritative)
Source: AG-UI spec extract §3 (`discovery-ag-ui-spec.md` lines 55–69) + Addendum §A.1 (typed sketches, lines 126–139). `BaseEvent.timestamp`/`rawEvent` are **not** modeled (the v1 decision from 2.5: `fromJson` ignores those wire keys; round-trip asserts **Dart-object** structural equality, not bit-exact wire). All required members decode via `_requireString`/`_requireMap`/`_decodeObjectList`; absent → `ProtocolError(protocolMalformed)`.

| Wire `type` | Dart subtype | Fields (Dart) — wire key in parens when it differs | Required? |
|---|---|---|---|
| `TOOL_CALL_START` | `ToolCallStartEvent` | `toolCallId: String`, `toolCallName: String`, `parentMessageId: String?` | toolCallId, toolCallName required |
| `TOOL_CALL_ARGS` | `ToolCallArgsEvent` | `toolCallId: String`, `delta: String` | both required |
| `TOOL_CALL_END` | `ToolCallEndEvent` | `toolCallId: String` | required |
| `TOOL_CALL_RESULT` | `ToolCallResultEvent` | `messageId: String`, `toolCallId: String`, `content: String`, `role: String?` | messageId, toolCallId, content required |
| `TOOL_CALL_CHUNK` | `ToolCallChunkEvent` | `toolCallId: String?`, `toolCallName: String?`, `parentMessageId: String?`, `delta: String?` | all optional |
| `STATE_SNAPSHOT` | `StateSnapshotEvent` | `state: Map<String, dynamic>` (wire `snapshot`) | required |
| `STATE_DELTA` | `StateDeltaEvent` | `patches: List<JsonPatchOp>` (wire `delta`, an array) | required (may be empty at decode) |
| `MESSAGES_SNAPSHOT` | `MessagesSnapshotEvent` | `messages: List<Message>` (wire `messages`) | required (may be empty) |

- **`ToolCallResultEvent.role` is a permissive `String?`** (wire `role?: "tool"`): keep the wire boundary untyped, mirroring `TEXT_MESSAGE_START.role` (2.5). Do **not** inject the `"tool"` default — absent stays absent so the round-trip is lossless. The typed `MessageRole` enum lives on `Message` (2.1), not on transient stream events.
- **`ToolCallChunkEvent` all-optional** per Addendum §A.1 (lines 130–135) — exactly parallel to `TextMessageChunkEvent` (2.5). Its `toJson` omits every absent optional; an empty chunk serializes to `{'type':'TOOL_CALL_CHUNK'}` and round-trips to all-`null`.
- **`StateSnapshotEvent.state` is `Map<String, dynamic>`**, not `Object?`: AG-UI state is conventionally a JSON object, `RunAgentInput.state` is `Map<String, dynamic>` (`input/run_agent_input.dart:31`), `ChatState.state` will be `Map<String, dynamic>` (2.12), and `JsonPatch.apply` (2.4) folds patches onto an object document. Typing the field `Map<String, dynamic>` keeps the snapshot consistent with everything that consumes it downstream; a non-object `snapshot` on the wire is malformed → `ProtocolError` via `_requireMap`. Deep equality on the nested map falls out of freezed's `DeepCollectionEquality` (same mechanism as `RunFinishedEvent.result`, 2.5).
- **`StateDeltaEvent.patches` decode does NOT reject an empty list.** AG-UI's "STATE_DELTA must carry ≥1 valid op" is a **verify-stage** rule (Addendum F.1, line 636; Story 2.11) that drops the event and emits `RunErrorEvent(ProtocolError)` — a cross-event pipeline concern, not a per-event decode concern. The decoder's contract is a faithful, lossless wire round-trip; an empty `delta: []` decodes to `patches: []` and round-trips. Adding the rejection here would duplicate (and pre-empt) 2.11's stage and break the round-trip AC. **Decode is lenient; verify is strict.**

### Wire-key vs Dart field name (the new seam in 2.6)
2.5's nine events had 1:1 wire-key↔field-name. 2.6 introduces two divergences, both from Addendum §A.1 choosing a clearer Dart name than the wire:
- `StateSnapshotEvent.state` ↔ wire `snapshot` (`{type:'STATE_SNAPSHOT', snapshot: {...}}`).
- `StateDeltaEvent.patches` ↔ wire `delta` (`{type:'STATE_DELTA', delta: [ {op,path,...}, ... ]}`).

The hand-rolled codec handles this transparently — `fromJson` reads the **wire** key, `toJson` writes the **wire** key, the Dart field uses the **addendum** name. This is *the* reason these events can't use `json_serializable` with `field_rename: none` even if we wanted to: the rename is per-field and semantic, not a mechanical case transform. Document the divergence in each subtype's dartdoc so a future reader doesn't "fix" the apparent mismatch.

### Cross-type codec delegation — the two leaf codecs 2.6 consumes
This is the one genuinely new mechanic vs 2.5. Two already-shipped leaf types provide their own (de)serialization; the event codecs delegate rather than re-implement:

```dart
// state_events.dart — STATE_DELTA delegates to JsonPatchOp (2.4, hand-rolled, freezed-only)
static StateDeltaEvent fromJson(Map<String, dynamic> json) =>
    StateDeltaEvent(patches: _decodeObjectList(json, 'delta', JsonPatchOp.fromJson));

Map<String, dynamic> toJson() => {
      'type': 'STATE_DELTA',
      'delta': [for (final p in patches) p.toJson()],
    };

// state_events.dart — MESSAGES_SNAPSHOT delegates to Message (2.1, json_serializable leaf)
static MessagesSnapshotEvent fromJson(Map<String, dynamic> json) =>
    MessagesSnapshotEvent(messages: _decodeObjectList(json, 'messages', Message.fromJson));

Map<String, dynamic> toJson() => {
      'type': 'MESSAGES_SNAPSHOT',
      'messages': [for (final m in messages) m.toJson()],
    };
```

- **`JsonPatchOp.fromJson`** (`json_patch/json_patch_op.dart`) is a `factory` returning the sealed-union member for the `op` discriminator; it already throws `ProtocolError(protocolMalformed)` on a bad op or missing member — so `StateDeltaEvent`'s decode inherits that error contract for free. `JsonPatchOp.toJson()` is the abstract method each op overrides. Confirmed present and exercised by 2.4's RFC 6902 fixture suite.
- **`Message.fromJson`** (`message/message.dart`) is json_serializable-generated (`message.g.dart`, already tracked-as-generated/gitignored); **`Message.toJson()` is generated too** (verified: `message.freezed.dart:26` declares the mixin `toJson`, `:234` implements it). `MessagesSnapshotEvent` calls both. The event family emits **no** `*.g.dart` of its own — only the leaf `Message` carries one, and that shipped in 2.1.
- **`_decodeObjectList` is the shared seam.** Both lists need: require the member is a `List`, require each element is a `Map<String, dynamic>`, then map through the supplied decoder — uniform `ProtocolError(protocolMalformed)` on any violation (never a raw `TypeError` from a bare `as`). One generic helper serves both call sites and keeps the malformed-payload contract identical to `_requireString`. This is the SF-1 lesson from 2.5's review generalized to collection members: **no raw `as` cast on wire data — every cast that can fail on malformed input goes through a helper that raises the typed error.**

### freezed idiom — reuse 2.2/2.3/2.4/2.5 verbatim (do not reinvent)
Each subtype mirrors the 2.5 events and `JsonPatchOp`:
```dart
// part of 'ag_ui_event.dart';
@freezed
abstract class ToolCallStartEvent extends AgUiEvent with _$ToolCallStartEvent {
  const ToolCallStartEvent._() : super();

  const factory ToolCallStartEvent({
    required String toolCallId,
    required String toolCallName,
    String? parentMessageId,
  }) = _ToolCallStartEvent;

  static ToolCallStartEvent fromJson(Map<String, dynamic> json) =>
      ToolCallStartEvent(
        toolCallId: _requireString(json, 'toolCallId'),
        toolCallName: _requireString(json, 'toolCallName'),
        parentMessageId: _optionalString(json, 'parentMessageId'),
      );

  Map<String, dynamic> toJson() => {
        'type': 'TOOL_CALL_START',
        'toolCallId': toolCallId,
        'toolCallName': toolCallName,
        if (parentMessageId != null) 'parentMessageId': parentMessageId,
      };
}
```
- The `const X._() : super();` private ctor is what lets a freezed class **both** `extends AgUiEvent` **and** carry a hand-written `toJson` body — proven by every prior union member. **Verify with `build_runner`, do not assume** (retro A1).
- **Do NOT** declare an abstract `toJson()` on `AgUiEvent` (`UnknownAgUiEvent` deliberately has none — a generated codec would break its byte-exact passthrough; 2.5 Dev Notes). Each concrete event declares its own `toJson` independently.
- **Codec placement: form (a) `static X fromJson(...)`** — confirmed by 2.5 that a plain `static` method named `fromJson` does **not** trigger `json_serializable` (freezed keys json wiring on `factory X.fromJson`), and the `X.fromJson` tear-off is a compile-time constant assignable to the `const` registry's `AgUiEvent Function(Map<String, dynamic>)` value by return-type covariance. Do not use a `factory X.fromJson` (that is the json_serializable path). Re-verify `build_runner` emits no event `*.g.dart` — but expect form (a) to hold.
- Structural equality (`==`/`hashCode`) is freezed-generated; all 8 subtypes' freezed code accrues into the **single** `ag_ui_event.freezed.dart`. No per-file `.freezed.dart`.

### koel_lints + `AgUiEvent` (don't trip `melos run analyze`)
`koel_lints`' `exhaustive_switch_must_have_default` keys on `_sealedNames = {'AgUiEvent', 'KoelError', 'MessageSegment'}` (`packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart:29`). **`AgUiEvent` IS in that set** — any `switch` *statement* over an `AgUiEvent` value in `lib/` must carry a `default:`. This story introduces **no** such switch: the dispatcher is a `Map` lookup; the new codecs use `_requireString`/`_requireMap`/`_decodeObjectList` + `.map`/getters; `StateDeltaEvent.toJson` calls `JsonPatchOp.toJson` per element (a method call, not a union switch). Note `JsonPatchOp` is **not** in `_sealedNames`, so even its internal `switch` (in `JsonPatch.apply`, 2.4) needs no default — and 2.6 doesn't switch it anyway. Keep it that way: no default-less `switch (event)` over the union anywhere in `lib/`.

### Toolchain (carried from 2.1–2.5 — unchanged, do not modify)
- freezed `3.2.6-dev.1` + `freezed_annotation ^3.1.0`; analyzer pinned to 12 across the workspace (analyzer-12 stopgap, SCP-2026-05-29-B) so freezed + `analysis_server_plugin 0.3.14` coexist in one pub-workspace resolution. Dart 3.12 / Flutter 3.44 (`.tool-versions`); SDK floor `>=3.11.0`.
- `koel_core/pubspec.yaml` already carries `freezed_annotation`, `json_annotation`, dev-deps `freezed`/`json_serializable`/`build_runner`/`test` + path `koel_lints:`. `build.yaml` sets `json_serializable.field_rename: none` (irrelevant here — events use no json_serializable; the in-package `Message` leaf does, unchanged). **No pubspec/build.yaml change needed** (`json_patch_op.dart` + `message.dart` are already in-package — just new imports in `ag_ui_event.dart`).
- CI is codegen-aware (2.1): `ci.yml` runs `melos run build` before `analyze`/`test`; `codegen-drift.yml` is a real determinism gate; `format:check` excludes generated output. **This story adds no CI work.** Generated files gitignored at root (`*.g.dart`, `*.freezed.dart`). Run tests via `dart test` directly in `packages/koel_core` (`melos run test` is still a 2.15 stub).

### Git intelligence (recent work patterns to follow)
- `025b899 feat(story-2.5)` — **immediate predecessor and the closest template.** Read `run_events.dart`, `text_message_events.dart`, `event_codec.dart`, `event_deserializer.dart`: the `static fromJson` + discriminator-first `toJson`, the `_requireString`/`_optionalString` helpers (extend with `_requireMap`/`_decodeObjectList`), the freezed-only (no `*.g.dart`) posture, the registry-row pattern, and the SF-1 review lesson (no raw `as` on wire data — typed error instead).
- `e51c604 feat(story-2.4)` — `JsonPatchOp` (the sealed union `StateDeltaEvent` consumes): `JsonPatchOp.fromJson` factory dispatch + per-subtype `toJson`, `ProtocolError(protocolMalformed)` on missing members. Read `json_patch_op.dart`.
- `b1e0f0d feat(story-2.3)` — the `KoelError`/`KoelErrorCode` types the codec helpers raise (`ProtocolError(protocolMalformed)`).
- `3a6e54d feat(story-2.2)` — `AgUiEvent` sealed root + `UnknownAgUiEvent` + `deserializeAgUiEvent`; the registry this story extends.
- Story 2.1 — the `Message` leaf type `MessagesSnapshotEvent` consumes (`message.dart` + generated `message.g.dart`/`message.freezed.dart`): the json_serializable leaf pattern (the road **not** taken for union members, but **delegated to** here).
- Commit style: Conventional Commits scoped `feat(story-2.6): …`. Do not commit generated files.

### Project Structure Notes
- New files: `lib/src/event/tool_call_events.dart`, `lib/src/event/state_events.dart` (both `part of 'ag_ui_event.dart'`); tests mirror under `test/event/` (`tool_call_events_test.dart`, `state_events_test.dart`). Modified: `lib/src/event/event_codec.dart` (add `_requireMap` + `_decodeObjectList`), `lib/src/event/ag_ui_event.dart` (add 2 `part` directives + 2 imports — `json_patch/json_patch_op.dart`, `message/message.dart`), `lib/src/event/event_deserializer.dart` (8 registry entries + doc-comment refresh), `test/event/event_deserializer_test.dart` (nine-key → seventeen-key assertion).
- Architecture confirms the file split (lines 776–777): `tool_call_events.dart # TOOL_CALL_* + CHUNK`, `state_events.dart # STATE_SNAPSHOT / DELTA, MESSAGES_SNAPSHOT`. The event directory + registry pattern were laid down in 2.2 precisely so 2.5–2.8 only *add* parts + registry rows — no conflict with the unified structure.

### References
- [Source: _bmad-output/planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md#Story 2.6 (lines 138–159)] — story statement + ACs (authoritative for scope); surrounding stories define cross-story consumers (2.11 chunks/verify, 2.12 reducer `STATE_*` folding, 2.13 conflict).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/discovery-ag-ui-spec.md (lines 55–69)] — wire field tables for Tool Call (5), State Management (3): `TOOL_CALL_START{toolCallId,toolCallName,parentMessageId?}`, `_ARGS{toolCallId,delta}`, `_END{toolCallId}`, `_RESULT{messageId,toolCallId,content,role?}`, `_CHUNK{toolCallId?,toolCallName?,parentMessageId?,delta?}`, `STATE_SNAPSHOT{snapshot:any}`, `STATE_DELTA{delta:any[] RFC 6902}`, `MESSAGES_SNAPSHOT{messages:Message[]}`.
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md (lines 126–139)] — §A.1 typed sketches: `ToolCallChunkEvent{String? toolCallId; String? toolCallName; String? parentMessageId; String? delta;}`, `StateDeltaEvent{final List<JsonPatchOp> patches;}`, the Dart names `state`/`patches` for the renamed wire keys.
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md (lines 630–647)] — §F.1 verify rules (empty/invalid `STATE_DELTA`, `TOOL_CALL_END` without `START` — **2.11, not here**) + §F.2 `chunks` synthesis (`TOOL_CALL_CHUNK` → Start/Args/End — **2.11, not here**); wire names `toolCallId`/`toolCallName`/`parentMessageId`/`delta`.
- [Source: packages/koel_core/lib/src/event/run_events.dart + text_message_events.dart + event_codec.dart + event_deserializer.dart (Story 2.5)] — the per-event codec template to replicate verbatim; `_requireString`/`_optionalString` to extend; the registry to grow.
- [Source: packages/koel_core/lib/src/json_patch/json_patch_op.dart (Story 2.4)] — `JsonPatchOp.fromJson` factory + per-op `toJson` that `StateDeltaEvent` delegates to; the `ProtocolError(protocolMalformed)` contract inherited.
- [Source: packages/koel_core/lib/src/message/message.dart (Story 2.1)] — `Message.fromJson`/`Message.toJson` (generated) that `MessagesSnapshotEvent` delegates to; `MessageRole` enum; freezed deep-equality incl. `DateTime`.
- [Source: packages/koel_core/lib/src/json_patch/json_patch.dart (Story 2.4)] — `JsonPatch.apply(Object? document, List<JsonPatchOp>)` — the consumer of `StateDeltaEvent.patches` in the 2.12 reducer (not invoked here; cited to justify `state: Map<String, dynamic>`).
- [Source: packages/koel_core/lib/src/input/run_agent_input.dart:31] — `state: Map<String, dynamic>` — the type `StateSnapshotEvent.state` aligns with.
- [Source: packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart:29] — `_sealedNames = {'AgUiEvent','KoelError','MessageSegment'}`; `AgUiEvent` IS keyed — avoid default-less union switches.
- [Source: _bmad-output/planning-artifacts/architecture.md (lines 771–777, §3 lines ~513–563)] — event-dir layout (`tool_call_events.dart`/`state_events.dart`); freezed-for-immutables, `const` everywhere, `copyWith`-only, camelCase wire keys, deep structural equality.
- [Source: _bmad-output/implementation-artifacts/2-5-run-step-text-message-events.md] — predecessor story: codec template, SF-1 (no raw `as` on wire data), "verify build_runner don't assume" (retro A1), barrel/CI deferral, decode-lenient/verify-strict split, in-package `src/` test imports.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Claude Opus 4.8) via `/bmad-dev-story` + `/agent-flutter-engineer`.

### Debug Log References

- `dart run build_runner build` → 1 output (`ag_ui_event.freezed.dart`, now covering the 8 new subtypes); re-run wrote 0 outputs (deterministic, `codegen-drift` clean). `json_serializable` wrote 0 outputs for events — the `static fromJson` form (a) did **not** trigger a `*.g.dart` (retro A1 verified by build, not assumed; the only event-tree `*.g.dart` is the pre-existing `Message`'s, untouched).
- `dart test` → **333 pass** (288 baseline + 45 new event tests), 0 failures. `dart test test/event/` alone → 100 cases green.
- `melos run analyze` → SUCCESS across all 12 packages incl. `koel_lints`; 0 issues. No default-less `switch` over `AgUiEvent` introduced (deserializer is a `Map` lookup; `StateDeltaEvent.toJson` calls `JsonPatchOp.toJson` per element via a `for`-comprehension, never a union `switch`).
- `melos run format:check` → exit 0 (the `dart format` pass reflowed the two new `const factory` single-arg constructors and a couple of long test `expect`s to the formatter's canonical shape — no semantic change).
- Coverage (`dart test --coverage` + `format_coverage`, scoped to `lib/src/event`, excl. generated `ag_ui_event.freezed.dart`): `tool_call_events.dart` 50/50 = **100%**, `state_events.dart` 16/16 = **100%**, `event_codec.dart` 31/31 = **100%** — every new branch (list/map guards, optional present/absent, empty-list) exercised. ≥ 90% NFR-12 satisfied.

### Completion Notes List

- Shipped the 8 freezed-immutable `AgUiEvent` subtypes (TOOL_CALL×5 in `tool_call_events.dart`, STATE×2 + MESSAGES_SNAPSHOT×1 in `state_events.dart`) as `part of 'ag_ui_event.dart'`, each with a hand-rolled `type`-discriminated `static fromJson` + discriminator-first `toJson`. Freezed-only; no event `*.g.dart`. Registered all eight in `eventTypeRegistry` (9 → 17 keys).
- **Two new shared helpers in `event_codec.dart`** (`_requireMap`, `_decodeObjectList`) generalize the SF-1 lesson from 2.5 to object/array members: every wire cast that can fail on malformed input raises `ProtocolError(protocolMalformed)` instead of leaking a raw `TypeError`. `_decodeObjectList<T>` serves both `STATE_DELTA.delta`→`JsonPatchOp` and `MESSAGES_SNAPSHOT.messages`→`Message`.
- **Cross-type codec delegation (the new mechanic vs 2.5):** `StateDeltaEvent` decodes/encodes via `JsonPatchOp.fromJson`/`.toJson` (2.4, hand-rolled); `MessagesSnapshotEvent` via `Message.fromJson`/`.toJson` (2.1, json_serializable leaf). The events emit no codec of their own — they delegate. Added the two imports (`json_patch/json_patch_op.dart`, `message/message.dart`) to `ag_ui_event.dart`.
- **Wire-key↔field-name divergence handled in-codec:** `StateSnapshotEvent.state` reads/writes wire `snapshot`; `StateDeltaEvent.patches` reads/writes wire `delta`. Dart names per Addendum §A.1, wire keys per the AG-UI spec; each documented in dartdoc so the apparent mismatch isn't "fixed" later.
- **Field-shape calls (per Dev Notes):** `StateSnapshotEvent.state` typed `Map<String, dynamic>` (aligns with `RunAgentInput.state`, the future `ChatState.state`, and `JsonPatch.apply`'s object document) — a non-object `snapshot` is malformed; `ToolCallResultEvent.role` is a permissive `String?`, **not** defaulted to `"tool"`, so absent round-trips to absent; `ToolCallChunkEvent` all-optional (parallel to `TextMessageChunkEvent`).
- **Decode-lenient / verify-strict split:** an empty `STATE_DELTA.delta: []` decodes to `patches: []` without throwing — the empty/invalid-patch rejection is the verify stage (Story 2.11 / Addendum F.1), not the decoder. A regression test pins this so 2.11's stage isn't pre-empted here.
- **koel_lints stays satisfied:** the new code reads getters / `.map` / `JsonPatchOp.toJson`, never a `switch` over `AgUiEvent` (which IS in `_sealedNames`). `melos run analyze` green.
- **Cross-story handoffs:** (2.7) `ACTIVITY_*`/`REASONING_*` reuse this same `static fromJson` + discriminator-first `toJson` template and the `event_codec.dart` helpers (incl. `_requireMap`/`_decodeObjectList` for the activity `content`/`patch` shapes); (2.8) the full-sweep round-trip relies on every `toJson` emitting `type` so `deserializeAgUiEvent(toJson())` re-routes; (2.11) the `chunks` stage expands `ToolCallChunkEvent` → Start/Args/End (Addendum F.2) and the verify stage enforces the empty-`STATE_DELTA` + START/END pairing rules this story only carries as transported values; (2.12) the reducer folds `STATE_SNAPSHOT`/`STATE_DELTA` (via `JsonPatch.apply`) and `MESSAGES_SNAPSHOT` into `ChatState`.
- **Untouched (scope discipline):** barrel `lib/koel_core.dart` (frozen until 2.15), `pubspec.yaml`/`build.yaml` (no new dep — both consumed types are in-package), CI, the other 11 event types (2.7–2.8), and any pipeline/reducer/classifier code.

### File List

- `packages/koel_core/lib/src/event/tool_call_events.dart` (new) — `ToolCallStartEvent`, `ToolCallArgsEvent`, `ToolCallEndEvent`, `ToolCallResultEvent`, `ToolCallChunkEvent`.
- `packages/koel_core/lib/src/event/state_events.dart` (new) — `StateSnapshotEvent`, `StateDeltaEvent`, `MessagesSnapshotEvent`.
- `packages/koel_core/lib/src/event/event_codec.dart` (modified) — added `_requireMap` + `_decodeObjectList` shared decode helpers.
- `packages/koel_core/lib/src/event/ag_ui_event.dart` (modified) — added 2 `part` directives + `json_patch/json_patch_op.dart` & `message/message.dart` imports.
- `packages/koel_core/lib/src/event/event_deserializer.dart` (modified) — registered the eight new wire types; refreshed the registry doc comment.
- `packages/koel_core/test/event/tool_call_events_test.dart` (new).
- `packages/koel_core/test/event/state_events_test.dart` (new).
- `packages/koel_core/test/event/event_deserializer_test.dart` (modified) — registry key assertion 9 → 17; added dispatch assertions for the eight new types.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — `2-6` → `in-progress` → `review`.

_Generated `ag_ui_event.freezed.dart` is regenerated by `build_runner` and gitignored — not tracked._

### Change Log

| Date | Change |
|---|---|
| 2026-05-30 | Story drafted (ready-for-dev): 8 `TOOL_CALL_*`/`STATE_*`/`MESSAGES_SNAPSHOT` event subtypes on the 2.5 codec template; new `_requireMap`/`_decodeObjectList` helpers; cross-type delegation to `JsonPatchOp` (2.4) + `Message` (2.1); `state`↔`snapshot` / `patches`↔`delta` wire-key divergence; decode-lenient (empty `STATE_DELTA` OK, verify is 2.11). |
| 2026-05-30 | Implemented Story 2.6: 8 freezed event subtypes (`tool_call_events.dart`, `state_events.dart`) + hand-rolled `type`-discriminated codecs delegating to `JsonPatchOp`/`Message`; added `_requireMap`/`_decodeObjectList` to `event_codec.dart`; registered all eight in `eventTypeRegistry` (9 → 17). 45 new tests, 333 total green; analyze + format:check exit 0; 100% line coverage on new sources; codegen deterministic with no event `*.g.dart`. Status → review. |
| 2026-05-30 | Code review (`/bmad-code-review`, 3 layers): all 5 ACs confirmed. **Patch F1** — hardened `_decodeObjectList` to normalize any non-`ProtocolError` thrown by a leaf decoder (`Message.fromJson`'s raw `TypeError`/`FormatException`/`ArgumentError`) into `ProtocolError(protocolMalformed, cause:)` while passing `ProtocolError` through unchanged; closes the only inbound `Message`-from-wire leak (the `delta`→`JsonPatchOp` sibling was already typed-safe). **Patch F6** — added `copyWith` tests for the 6 remaining subtypes. 9 new tests (342 total green); analyze + format:check exit 0; codegen still deterministic. 4 findings dismissed as convention/unreachable. Status → done. |
