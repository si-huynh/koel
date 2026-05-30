---
baseline_commit: 39949894dc1a8179ffe25e3b825fe7ea2fcb2ee9 # feat(story-2.6) — HEAD at story creation
---

# Story 2.7: `ACTIVITY_*` + `REASONING_*` event subtypes with `encryptedValue` bit-exact round-trip

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter/Dart developer,
I want typed event subtypes for the activity and reasoning families — `ActivitySnapshotEvent`, `ActivityDeltaEvent`, `ReasoningStartEvent`, `ReasoningEndEvent`, `ReasoningMessageStartEvent`, `ReasoningMessageContentEvent`, `ReasoningMessageEndEvent`, `ReasoningMessageChunkEvent`, and `ReasoningEncryptedValueEvent` (the last carrying a **bit-exact opaque round-trip**) — joined into the sealed `AgUiEvent` union and wired into the deserializer registry,
so that Anthropic/OpenAI zero-retention reasoning replay requirements are met per FR-A9 and pattern matching over reasoning/activity is exhaustive per FR-A7.

**Why this story now.** This is the **third** application of the per-event codec template frozen by Story 2.5 and reused verbatim by Story 2.6: `@freezed abstract class X extends AgUiEvent with _$X` + `const X._() : super();`, a hand-written discriminator-first `toJson`, a `static X fromJson(Map<String, dynamic>)` tear-off registered in `eventTypeRegistry`, shared helpers in `event_codec.dart`. 2.5 shipped 9 lifecycle/text events; 2.6 shipped 8 tool-call/state events **and** introduced cross-type codec delegation (`JsonPatchOp`, `Message`) plus the wire-key≠field-name seam. 2.7 ships the **9 remaining typed families** (2 activity + 7 reasoning) and adds **one genuinely new mechanic the prior two stories did not exercise: a binary field** — `ReasoningEncryptedValueEvent.encryptedValue: Uint8List` decoded from a wire base64 string, with the original base64 string preserved on a sibling field so the wire round-trip is **byte-exact** (FR-A9). After this story the union has **26** of the ~28 members; Story 2.8 closes it with `RAW` + `CUSTOM` and the 28-event integration sweep on the same template.

**Scope reality check.** This story ships the **9 event subtypes** as freezed-immutable members of the sealed `AgUiEvent` union, their hand-rolled `type`-discriminated `fromJson`/`toJson` codecs, **two new shared helpers** in `event_codec.dart` (`_optionalBool` for `ACTIVITY_SNAPSHOT.replace`; `_decodeBase64` for the encrypted blob), and their registration in `eventTypeRegistry` (17 → 26 keys). It does **NOT** ship: the `reasoningEcho` echo path (the reducer's `REASONING_ENCRYPTED_VALUE → ChatState.reasoningEcho` accumulation is **Story 2.12**, epic line 299; the round-trip-to-backend verification is **Epic 5** with real fixtures and **Story 3.1** via `MockAgent`), the verify-stage rule "`REASONING_ENCRYPTED_VALUE` must have both `Uint8List` and base64 string" (that cross-event drop-and-emit-`RunErrorEvent` rule is **Story 2.11** / Addendum F.1 line 522 — this story guarantees the codec *produces* both fields, not the stage that *polices* their presence across a stream), `JsonPatch.apply` against any live document (the reducer, 2.12), reasoning/activity reduction into `ChatState`, the `RAW`/`CUSTOM` types and 28-event sweep (2.8), or the barrel export (frozen until 2.15). `ActivityDeltaEvent` **decodes** its RFC 6902 ops via `JsonPatchOp.fromJson` and re-serializes via `JsonPatchOp.toJson`; it does **not** apply them. **No `THINKING_*` aliases** are modeled — those are deprecated upstream (the TS SDK marks `ThinkingStartEventSchema` et al. `@deprecated`, removal in 1.0.0); koel models reasoning only, per PRD §6.1 / FR-A7, and an incoming `THINKING_*` wire type falls through to `UnknownAgUiEvent` (forward-compat FC-1).

## Acceptance Criteria

**AC1 — two event files ship the 9 freezed subtypes, joined to the sealed union**
**Given** `koel_core/lib/src/event/activity_events.dart` and `koel_core/lib/src/event/reasoning_events.dart`,
**When** I inspect each file,
**Then** each is a `part of 'ag_ui_event.dart'` and defines its family's concrete subclasses of `AgUiEvent` — `activity_events.dart`: `ActivitySnapshotEvent`, `ActivityDeltaEvent`; `reasoning_events.dart`: `ReasoningStartEvent`, `ReasoningEndEvent`, `ReasoningMessageStartEvent`, `ReasoningMessageContentEvent`, `ReasoningMessageEndEvent`, `ReasoningMessageChunkEvent`, `ReasoningEncryptedValueEvent`,
**And** every subtype is freezed-generated (`@freezed abstract class X extends AgUiEvent with _$X` + `const X._() : super();` + `const factory X(...) = _X;`) using the sealed-parent + private-`._()`-ctor idiom proven by 2.2–2.6 — **verified by running `build_runner`, not assumed** (retro A1),
**And** the field shapes match the AG-UI `release/2026-05-26` wire format per the table in Dev Notes "Wire-format field shapes" (sourced from the authoritative TS schema, not guessed),
**And** `ReasoningMessageChunkEvent` carries `messageId: String?` + `delta: String?` — **both optional** — exactly parallel to `TextMessageChunkEvent` (2.5),
**And** `ReasoningEncryptedValueEvent` carries `entityId: String`, `subtype: String`, `encryptedValue: Uint8List`, **and** `encryptedValueBase64: String` per Addendum §A.1 (lines 148–157),
**And** `ActivityDeltaEvent` carries `final List<JsonPatchOp> patches` consuming the Story-2.4 RFC 6902 op type (no new patch type),
**And** `ag_ui_event.dart` adds `part 'activity_events.dart';` and `part 'reasoning_events.dart';`, the two `dart:` imports `dart:typed_data` (for `Uint8List`) + `dart:convert` (for `base64Decode`), and reuses the already-present `'../json_patch/json_patch_op.dart'` import (added in 2.6).

**AC2 — hand-rolled, `type`-discriminated codecs; freezed-only (no `*.g.dart` for events); base64 + wire-key divergences handled**
**Given** the codec wiring,
**When** I inspect it,
**Then** each subtype carries a hand-written `Map<String, dynamic> toJson()` whose first entry is its wire discriminator (`'type': 'REASONING_START'`, `'ACTIVITY_SNAPSHOT'`, …) followed by its fields, omitting absent optionals,
**And** each subtype exposes a `static X fromJson(Map<String, dynamic> json)` usable as an `AgUiEvent Function(Map<String, dynamic>)` registry value (form **(a)** from Story 2.5 — confirmed not to trigger `json_serializable`; **verify via `build_runner`**),
**And** **no** `json_serializable` is applied to any event subtype and **no** `*.g.dart` is produced for the activity/reasoning family,
**And** `ReasoningEncryptedValueEvent`'s codec is **bit-exact-preserving**: `fromJson` reads the wire `encryptedValue` base64 **string**, stores it verbatim on `encryptedValueBase64`, **and** decodes it to bytes on `encryptedValue: Uint8List`; `toJson` writes the **preserved `encryptedValueBase64` string** back to wire key `encryptedValue` and **never re-encodes** the `Uint8List` (re-encoding could canonicalize padding/whitespace and break the byte-exact wire round-trip) — see Dev Notes "The encryptedValue codec",
**And** the wire-key↔field-name divergence is codec-internal: `ActivityDeltaEvent.patches` reads/writes wire key `patch` (singular; an array of RFC 6902 ops) — Dart name per Addendum, wire key per AG-UI spec — see Dev Notes "Wire-key vs Dart field name",
**And** two new shared codec helpers live in `event_codec.dart` (`part of 'ag_ui_event.dart'`): `bool? _optionalBool(json, key)` (absent/`null` → `null`; non-`bool` present → `ProtocolError(protocolMalformed)`; mirrors `_optionalString`) and `Uint8List _decodeBase64(String wire)` (a malformed/non-base64 string → `ProtocolError(protocolMalformed)`, never a raw `FormatException`), both following the existing helpers' typed-error contract.

**AC3 — `eventTypeRegistry` maps all 9 wire types to their concrete subtype; dispatcher round-trips**
**Given** `koel_core/lib/src/event/event_deserializer.dart`,
**When** I inspect `eventTypeRegistry`,
**Then** it now maps **twenty-six** wire strings (the seventeen from 2.5+2.6 **plus** these nine): `ACTIVITY_SNAPSHOT`, `ACTIVITY_DELTA`, `REASONING_START`, `REASONING_END`, `REASONING_MESSAGE_START`, `REASONING_MESSAGE_CONTENT`, `REASONING_MESSAGE_END`, `REASONING_MESSAGE_CHUNK`, `REASONING_ENCRYPTED_VALUE`,
**And** `deserializeAgUiEvent(wireJson)` produces the correct concrete subtype with all fields populated for each of the nine given sample wire JSON,
**And** for every sample, `deserializeAgUiEvent(event.toJson())` re-dispatches to the **same** concrete subtype, structurally equal to the original (the `type` discriminator on `toJson` makes the event re-routable — the property the 2.8 full-sweep relies on),
**And** an incoming `THINKING_*` wire type (deprecated upstream, **not** registered) still falls through to `UnknownAgUiEvent` (FC-1 regression guard).

**AC4 — round-trip + structural-equality tests per subtype; the encryptedValue bit-exact property test**
**Given** the test suite under `koel_core/test/event/`,
**When** I run `dart test test/event/`,
**Then** every one of the nine subtypes has at least one positive deserialization test (wire JSON → typed event, fields asserted) **and** one round-trip test (`deserializeAgUiEvent(e.toJson())` — or `X.fromJson(e.toJson())` — structurally equals `e`, leaning on freezed's generated `==`),
**And** `ReasoningEncryptedValueEvent` is verified two ways: (i) a **wire round-trip** test confirming `fromJson(wire).toJson()['encryptedValue']` equals the original wire base64 string **verbatim** (no re-encode drift), and (ii) a **property-based test over 100 random byte sequences** — covering lengths whose `% 3` is 0, 1, and 2 (all base64 padding cases) **and** the empty blob — confirming `base64Decode(event.toJson()['encryptedValue'])` is **bit-exact** equal to the original bytes and that two independently-built events with equal bytes are `==` (freezed byte-deep equality — see Dev Notes; mirror the proven pattern at `test/input/run_agent_input_test.dart:51-81`),
**And** `ActivityDeltaEvent` round-trips a multi-op `patch` list (e.g. `[add, remove, replace]`) through `JsonPatchOp.fromJson`/`.toJson` with structural equality, **and** an empty `patch: []` decodes to `patches: []` **without throwing** (the empty/invalid rejection is the verify stage's job in 2.11, not the decoder — decode-lenient/verify-strict, the 2.6 split),
**And** `ActivitySnapshotEvent` round-trips with `replace` **present** (`true` and `false`) **and absent** (absent → `null`, omitted on `toJson`, not defaulted), and a nested-object `content` round-trips via freezed deep equality,
**And** `ReasoningMessageChunkEvent` round-trips the all-`null` empty chunk (`{'type':'REASONING_MESSAGE_CHUNK'}`) and a partially-populated chunk,
**And** negative tests confirm: a missing required member (e.g. `REASONING_START` without `messageId`, `ACTIVITY_SNAPSHOT` without `content`, `REASONING_ENCRYPTED_VALUE` without `entityId`/`subtype`/`encryptedValue`) throws `ProtocolError(protocolMalformed)`; a present-but-non-`String` required member, a non-`Map` `content`, a non-`List` `patch`, a `patch` **element** that is not an object, a non-`bool` `replace`, and a **non-base64** `encryptedValue` string each throw `ProtocolError(protocolMalformed)` (never a raw `TypeError`/`FormatException`),
**And** line + branch coverage on the new event sources (excluding generated `ag_ui_event.freezed.dart`) is **≥ 90%** per NFR-12.

**AC5 — repo stays green; codegen deterministic; nothing committed; barrel untouched**
**Given** the workspace after this story lands,
**When** I run the toolchain,
**Then** `cd packages/koel_core && dart run build_runner build` regenerates `ag_ui_event.freezed.dart` (now covering the 9 new subtypes) with **no** new `*.g.dart` for events, and a re-run writes 0 outputs (deterministic; `codegen-drift` green),
**And** `cd packages/koel_core && dart test` passes (the 342 from 2.6 + the new event tests),
**And** `melos run analyze` exits 0 across all packages including `koel_lints` — with **no** default-less `switch` over `AgUiEvent` introduced into the analyzed tree (the deserializer is a `Map` lookup; the new codecs read getters / `.map`; `ActivityDeltaEvent.toJson` calls `JsonPatchOp.toJson` per element but never `switch`es the `AgUiEvent` union — see Dev Notes "koel_lints + AgUiEvent"),
**And** `melos run format:check` exits 0,
**And** `git ls-files '*.freezed.dart' '*.g.dart'` shows nothing staged/tracked, and the barrel `lib/koel_core.dart` is **not** touched (frozen until 2.15),
**And** no `pubspec.yaml`/`build.yaml` change — `Uint8List`/`base64Decode` come from the Dart SDK (`dart:typed_data`/`dart:convert`), and `json_patch_op.dart` is already in-package.

## Tasks / Subtasks

- [x] **Task 1 — shared helpers `_optionalBool` + `_decodeBase64` in `event_codec.dart` (AC2)** — red → green → refactor
  - [x] RED: fold into the per-family tests (Tasks 2–3). `_optionalBool` is exercised through `ActivitySnapshotEvent` (`replace` present-`true`/present-`false`/absent/non-`bool`); `_decodeBase64` through `ReasoningEncryptedValueEvent` (valid base64 → bytes; non-base64 string → `ProtocolError`). Both helpers are library-private, asserted through their consumers. Confirm RED (helpers undefined).
  - [x] GREEN: add to `event_codec.dart` — `bool? _optionalBool(Map<String, dynamic> json, String key)` (absent/`null` → `null`; `bool` → value; other present type → `ProtocolError(protocolMalformed)`, `cause: json`), mirroring `_optionalString` exactly; `Uint8List _decodeBase64(String wire)` — `try { return base64Decode(wire); } on FormatException catch (e) { throw ProtocolError(message: 'AG-UI event encryptedValue is not valid base64', code: KoelErrorCode.protocolMalformed, cause: e); }`. Import `dart:convert` + `dart:typed_data` at the top of `ag_ui_event.dart` (the library file the `part` belongs to).
  - [x] REFACTOR: one-line internal-codec-glue dartdoc on each, matching the existing helpers' tone (`_requireString`/`_optionalString`/`_requireMap`/`_decodeObjectList`). `build_runner` confirms they compile inside the library.

- [x] **Task 2 — `activity_events.dart`: Snapshot/Delta (AC1/AC2/AC4)** — red → green → refactor
  - [x] RED: `test/event/activity_events_test.dart` — per subtype: const construction, `isA<AgUiEvent>()`/`isA<X>()`, structural equality (`==`+`hashCode`; differ on any field → `!=`), `copyWith`, `fromJson` with fields asserted, dual round-trip via `X.fromJson(e.toJson())` **and** `deserializeAgUiEvent(e.toJson())`. `ActivitySnapshotEvent`: `replace` present-`true`, present-`false`, absent (→`null`, omitted on `toJson`), non-`bool` → `ProtocolError`; nested-object `content` round-trips (freezed deep equality). `ActivityDeltaEvent`: multi-op `patch: [add, remove, replace]` round-trips through `JsonPatchOp`; empty `patch: []` → `patches: []` (no throw). Negatives: missing/`non-String` `messageId`/`activityType` (both); missing/`non-Map` `content`; missing/non-`List` `patch`; non-`Map` `patch` **element** → `ProtocolError(protocolMalformed)`. Confirm RED.
  - [x] GREEN: `ActivitySnapshotEvent{String messageId, String activityType, Map<String, dynamic> content, bool? replace}` ← `_requireString`×2 + `_requireMap(json,'content')` + `_optionalBool(json,'replace')`; `toJson` → `{'type':'ACTIVITY_SNAPSHOT','messageId':…,'activityType':…,'content':content, if (replace != null) 'replace': replace}`. `ActivityDeltaEvent{String messageId, String activityType, List<JsonPatchOp> patches}` ← `_requireString`×2 + `_decodeObjectList(json,'patch',JsonPatchOp.fromJson)`; `toJson` → `{'type':'ACTIVITY_DELTA','messageId':…,'activityType':…,'patch':[for (final p in patches) p.toJson()]}`. `build_runner`; green.
  - [x] REFACTOR: contract-form dartdoc — `ActivitySnapshotEvent` is a frontend-only structured-UI element (progress bar / checklist) that never reaches the agent; `replace` defaults to `true` *on the wire* but is **not** injected here (absent stays `null` for lossless round-trip — the reducer/consumer applies the default, 2.12). `ActivityDeltaEvent` carries RFC 6902 ops that patch the prior activity `content`; **this event only transports them** (empty/invalid rejection is the verify stage, 2.11). Note the `patches`↔`patch` wire-key divergence explicitly.

- [x] **Task 3 — `reasoning_events.dart`: Start/End/MessageStart/Content/End/Chunk/EncryptedValue (AC1/AC2/AC4)** — red → green → refactor
  - [x] RED: `test/event/reasoning_events_test.dart` — per subtype: construction, `isA`, structural equality, `copyWith`, `fromJson`, dual round-trip. `ReasoningMessageStartEvent`: `role` is a required `String` (wire literal `"reasoning"`, kept permissive — do **not** narrow to an enum). `ReasoningMessageChunkEvent`: empty `{'type':'REASONING_MESSAGE_CHUNK'}` → all-`null` (no throw) + round-trip; partial chunk omits absent optionals. **`ReasoningEncryptedValueEvent` (the crux):** (i) positive decode asserts `entityId`/`subtype`/`encryptedValueBase64`/`encryptedValue` bytes; (ii) **wire round-trip** asserts `fromJson(wire).toJson()['encryptedValue'] == wire['encryptedValue']` verbatim; (iii) **property test, 100 random byte sequences** (lengths `%3 ∈ {0,1,2}` + empty) asserting `base64Decode(e.toJson()['encryptedValue'])` is bit-exact equal to the source bytes; (iv) **byte-deep `==`**: two independently-built events with equal bytes (distinct `Uint8List` instances, `identical(...) == false`) are `==` and share `hashCode` — copy the idiom from `test/input/run_agent_input_test.dart:51-81`. Negatives: missing/`non-String` `messageId` (Start/End/MessageStart/Content/MessageEnd), missing `delta` (Content), missing `role` (MessageStart), missing `entityId`/`subtype`/`encryptedValue` (EncryptedValue), **non-base64 `encryptedValue`** string → `ProtocolError(protocolMalformed)` (not a raw `FormatException`). Confirm RED.
  - [x] GREEN: implement the seven subtypes per the Wire-format table. `ReasoningStartEvent`/`ReasoningEndEvent`/`ReasoningMessageEndEvent`{`String messageId`}; `ReasoningMessageStartEvent`{`String messageId, String role`}; `ReasoningMessageContentEvent`{`String messageId, String delta`}; `ReasoningMessageChunkEvent`{`String? messageId, String? delta`}; `ReasoningEncryptedValueEvent`{`String entityId, String subtype, Uint8List encryptedValue, String encryptedValueBase64`} — codec per Dev Notes "The encryptedValue codec" (read `encryptedValue` string once, store on `encryptedValueBase64`, decode to bytes via `_decodeBase64`; `toJson` echoes `encryptedValueBase64`). `build_runner` confirms the generated parts satisfy `extends AgUiEvent` **and** that the `Uint8List` field gets byte-deep `==` (do not assume — assert via the test in (iv)).
  - [x] REFACTOR: contract-form dartdoc — `ReasoningStartEvent`/`ReasoningEndEvent` bracket a reasoning span sharing `messageId`; `ReasoningMessage*` are the streamed reasoning text (Start→N×Content→End, the `chunks`-stage expansion target for `ReasoningMessageChunkEvent` in 2.11, parallel to TEXT_MESSAGE); `ReasoningEncryptedValueEvent` carries an **opaque provider blob** (Anthropic/OpenAI zero-retention CoT) echoed verbatim via `RunAgentInput.reasoningEcho` in a later run (2.12 accumulates it; Epic 5 round-trips to a backend) — document that `encryptedValue` is **never inspected** and that `encryptedValueBase64` exists *solely* to guarantee a byte-exact wire round-trip (the bytes are for the typed `reasoningEcho: Map<String, Uint8List>` surface; the string is the wire echo). Document the `subtype` values (`"tool-call"`/`"message"`, kept permissive `String`).

- [x] **Task 4 — register all 9 in `eventTypeRegistry` + dispatcher integration tests (AC3/AC5)** — red → green
  - [x] RED: extend `test/event/event_deserializer_test.dart` — `eventTypeRegistry.keys` is exactly the **twenty-six** wire strings (seventeen prior + nine new); `deserializeAgUiEvent(sample)` yields the right subtype for each new type; an unknown type **and** a `THINKING_MESSAGE_START`-style deprecated type both fall back to `UnknownAgUiEvent` (2.2 + no-THINKING-alias regression guard). Confirm RED (the seventeen-key assertion fails).
  - [x] GREEN: add the nine `'WIRE_TYPE': XEvent.fromJson` static tear-offs to the `const` map; `deserializeAgUiEvent` body untouched. Update the registry doc comment to note 2.7's nine additions (and that the union now has 26/28 — RAW+CUSTOM remain for 2.8). Green.
  - [x] Update the `event_deserializer_test.dart` key assertion from seventeen to twenty-six.

- [x] **Task 5 — Definition-of-done validation (AC5)**
  - [x] `dart run build_runner build` → exits 0; updated `ag_ui_event.freezed.dart`, **no** new `*.g.dart` for events. Re-run → wrote 0 outputs (deterministic). Confirm the `Uint8List` field's generated `==` is byte-deep (the test in Task 3 (iv) is the proof, not an assumption).
  - [x] `dart test` → all green (342 baseline + new event tests). Report the new total.
  - [x] `melos run analyze` → SUCCESS across all packages incl. `koel_lints`; 0 issues. No default-less `switch` over `AgUiEvent`.
  - [x] `melos run format:check` → exit 0. (Watch the brace-less-guard reflow gotcha from 2.4/2.6 if any `if (x != null)` map entry is introduced — prefer the `'k': ?x` null-aware element where it applies for the `replace`/chunk optionals.)
  - [x] Coverage: `dart test --coverage` + `format_coverage` scoped to `lib/src/event` (excl. `ag_ui_event.freezed.dart`) → ≥ 90% line **and** branch (the base64 success/failure branches, the `replace` present/absent branches, the `patch` list/empty/element-guard branches must all be exercised). Report the exact %.
  - [x] `git ls-files '*.freezed.dart' '*.g.dart'` → empty. Barrel `lib/koel_core.dart` untouched. No new dep, no pubspec/build.yaml change, no pipeline/reducer/classifier code, no other event families.
  - [x] Update File List + Completion Notes + Change Log; record cross-story handoffs (2.8 sweep, 2.11 chunks/verify, 2.12 reducer reasoningEcho).

## Dev Notes

### What this story is — and is not
- **Is:** the 9 freezed-immutable event subtypes (ACTIVITY×2, REASONING×7), their hand-rolled `type`-discriminated `fromJson`/`toJson`, two new `event_codec.dart` helpers (`_optionalBool`, `_decodeBase64`), `eventTypeRegistry` registration (17 → 26), and per-subtype positive + round-trip + negative tests at ≥90% line **and** branch coverage. Replicates 2.5/2.6's template; adds the **binary (`Uint8List`) field** mechanic and its bit-exact wire round-trip (FR-A9).
- **Is not:** the `reasoningEcho` accumulation into `ChatState` (2.12 reducer; epic line 299), the round-trip-to-backend verification (Epic 5 fixtures + 3.1 `MockAgent`), the verify-stage "both bytes+base64 present" drop rule (2.11 / Addendum F.1 line 522 — this story makes the codec *produce* both; it does not police a stream), `JsonPatch.apply` against a live document (2.12), reasoning/activity reduction into `ChatState`, the `RAW`/`CUSTOM` types + 28-event sweep (2.8), the barrel export (2.15). Do **not** stub these — placeholders invite churn (the discipline 2.1–2.6 held).

### Wire-format field shapes (AG-UI `release/2026-05-26` — authoritative, sourced from the TS schema)
Source: AG-UI TS `sdks/typescript/packages/core/src/events.ts` (`ActivitySnapshotEventSchema` … `ReasoningEncryptedValueEventSchema`) cross-checked against `discovery-ag-ui-spec.md` §3 (lines 71–78) + Addendum §A.1 (lines 140–158). `BaseEvent.timestamp`/`rawEvent` are **not** modeled (the v1 decision from 2.5: `fromJson` ignores those wire keys; round-trip asserts **Dart-object** structural equality, not bit-exact wire — **except** the `encryptedValue` blob, which IS byte-exact by design). All required members decode via `_requireString`/`_requireMap`/`_decodeObjectList`/`_decodeBase64`; absent → `ProtocolError(protocolMalformed)`.

| Wire `type` | Dart subtype | Fields (Dart) — wire key in parens when it differs | Required? |
|---|---|---|---|
| `ACTIVITY_SNAPSHOT` | `ActivitySnapshotEvent` | `messageId: String`, `activityType: String`, `content: Map<String, dynamic>`, `replace: bool?` | messageId, activityType, content required; replace optional |
| `ACTIVITY_DELTA` | `ActivityDeltaEvent` | `messageId: String`, `activityType: String`, `patches: List<JsonPatchOp>` (wire `patch`) | all required (patches may be empty at decode) |
| `REASONING_START` | `ReasoningStartEvent` | `messageId: String` | required |
| `REASONING_END` | `ReasoningEndEvent` | `messageId: String` | required |
| `REASONING_MESSAGE_START` | `ReasoningMessageStartEvent` | `messageId: String`, `role: String` (wire literal `"reasoning"`) | both required |
| `REASONING_MESSAGE_CONTENT` | `ReasoningMessageContentEvent` | `messageId: String`, `delta: String` | both required |
| `REASONING_MESSAGE_END` | `ReasoningMessageEndEvent` | `messageId: String` | required |
| `REASONING_MESSAGE_CHUNK` | `ReasoningMessageChunkEvent` | `messageId: String?`, `delta: String?` | all optional |
| `REASONING_ENCRYPTED_VALUE` | `ReasoningEncryptedValueEvent` | `entityId: String`, `subtype: String`, `encryptedValue: Uint8List` (wire `encryptedValue` = base64 string), `encryptedValueBase64: String` (no wire key of its own; the preserved original) | entityId, subtype, encryptedValue(wire) required |

- **`ActivitySnapshotEvent.replace` is `bool?` (absent-preserving), NOT defaulted.** The wire schema is `z.boolean().optional().default(true)` — the default is applied by *consumers* (the reducer, 2.12), not the decoder. Per the 2.6 decode-lenient lesson (`ToolCallResultEvent.role` was **not** defaulted to `"tool"`), absent `replace` decodes to `null` and `toJson` omits it, so the round-trip is lossless. Needs the new `_optionalBool` helper (the first `bool` field in the event family).
- **`ActivitySnapshotEvent.content` is `Map<String, dynamic>`** (`z.record(z.any())`), decoded via `_requireMap` (wire key `content`, no divergence). Deep equality on the nested map falls out of freezed's `DeepCollectionEquality` (same as `StateSnapshotEvent.state`, 2.6).
- **`ActivityDeltaEvent.patches: List<JsonPatchOp>`** — the wire `patch` is `z.array(z.any())` annotated "RFC 6902" in the spec (line 75). Decode to typed ops via `_decodeObjectList(json, 'patch', JsonPatchOp.fromJson)`, exactly as `STATE_DELTA.delta` does (2.6) — same generic helper, same op type, **no new patch type**. This is the deliberate, consistent call: an RFC 6902 array is an RFC 6902 array regardless of whether it patches chat state or activity content. As with `STATE_DELTA`, decode does **not** reject an empty `patch: []` (verify-stage concern, 2.11).
- **`ReasoningMessageStartEvent.role` is a permissive required `String`** (wire literal `"reasoning"`): keep the wire boundary untyped, mirroring `TextMessageStartEvent.role` (2.5) and `ToolCallResultEvent.role` (2.6). Do **not** introduce a `ReasoningRole` enum — the typed role vocabulary lives on `Message` (2.1), not on transient stream events.
- **`ReasoningEncryptedValueEvent.subtype` is a permissive `String`** (wire `"tool-call" | "message"`): per AC, model as `String`, decode via `_requireString`, do **not** narrow to an enum and do **not** reject unknown subtype values at decode (decode-lenient; any narrowing is a downstream concern).
- **`ReasoningMessageChunkEvent` is all-optional** (`messageId?`, `delta?`) — exactly parallel to `TextMessageChunkEvent` (2.5). `toJson` omits every absent optional; an empty chunk serializes to `{'type':'REASONING_MESSAGE_CHUNK'}` and round-trips to all-`null`. (Note: unlike `TextMessageChunkEvent`, there is **no** `role` on the reasoning chunk — the TS schema omits it.)

### The encryptedValue codec — the one genuinely new mechanic in 2.7 (FR-A9)
`ReasoningEncryptedValueEvent` is the **first binary field** in the union. The wire carries a base64 **string**; the Dart type carries **both** the decoded `Uint8List` (for the typed `reasoningEcho: Map<String, Uint8List>` surface, 2.1) **and** the original base64 string (so the wire round-trip is byte-exact). The codec:

```dart
// reasoning_events.dart
static ReasoningEncryptedValueEvent fromJson(Map<String, dynamic> json) {
  final base64 = _requireString(json, 'encryptedValue');   // the wire string
  return ReasoningEncryptedValueEvent(
    entityId: _requireString(json, 'entityId'),
    subtype: _requireString(json, 'subtype'),
    encryptedValue: _decodeBase64(base64),                 // bytes (non-base64 → ProtocolError)
    encryptedValueBase64: base64,                          // preserved verbatim
  );
}

Map<String, dynamic> toJson() => {
      'type': 'REASONING_ENCRYPTED_VALUE',
      'subtype': subtype,
      'entityId': entityId,
      'encryptedValue': encryptedValueBase64,  // ECHO the preserved string — NEVER base64Encode(encryptedValue)
    };
```

- **Why echo `encryptedValueBase64` and never re-encode the bytes:** `base64Encode(base64Decode(s))` is *not* guaranteed to equal `s` for every valid wire string — padding normalization, line breaks, and the standard-vs-url alphabet can differ. Anthropic/OpenAI reject a reasoning blob whose bytes don't round-trip verbatim (discovery-ag-ui-spec.md line 204). Echoing the preserved string makes `wire → fromJson → toJson → wire` byte-exact on the `encryptedValue` member, satisfying FR-A9. The decoded `Uint8List` exists for the *typed* surface (`reasoningEcho`), not for re-serialization.
- **`_decodeBase64` wraps `base64Decode` (`dart:convert`)** and maps its `FormatException` to `ProtocolError(protocolMalformed)` — the SF-1 lesson (no raw error past the codec boundary) applied to the base64 path. **Correction (review 2026-05-30):** `base64Decode` is Dart's *normalizing* decoder — it **accepts both** the standard (`+/`) and url-safe (`-_`) alphabets, so a base64url payload is decoded, **not** rejected (verified: `base64Decode('a-_b')` → `[107,239,219]`). This is harmless and arguably more robust: the verbatim `encryptedValueBase64` is echoed on `toJson` so the wire round-trip stays byte-exact regardless of alphabet, and the decoded bytes feed only the opaque, never-inspected `reasoningEcho` surface. (It also reinforces the never-re-encode rule — `base64Encode` would emit `a+/b ≠ a-_b`.)
- **Freezed gives byte-deep `==` on `Uint8List` for free** — already proven and documented for `RunAgentInput.reasoningEcho: Map<String, Uint8List>` (see `input/run_agent_input.dart:14-15` and the test `test/input/run_agent_input_test.dart:51-81`): `Uint8List` is an `Iterable<int>`, so freezed's `DeepCollectionEquality` compares it element-wise. **Verify, do not assume** (retro A1): Task 3 (iv) asserts two independently-built events with equal bytes (distinct instances, `identical == false`) are `==`. If `build_runner` ever generated reference equality instead, the round-trip structural-equality AC would fail — the test is the canary. Expected to hold (the `Map<String, Uint8List>` precedent proves the mechanism).
- The property test constructs each event from random bytes: `bytes = …; b64 = base64Encode(bytes); event = ReasoningEncryptedValueEvent(entityId:'e', subtype:'message', encryptedValue: bytes, encryptedValueBase64: b64);` then asserts `base64Decode(event.toJson()['encryptedValue'])` (== `base64Decode(b64)`) is bit-exact `bytes`. Cover lengths `%3 ∈ {0,1,2}` (e.g. 0, 1, 2, 3, 16, 17) to exercise all base64 padding cases. Deterministic randomness is fine (a fixed seed) — bit-exactness must hold for every sequence, not a lucky one.

### Wire-key vs Dart field name (the 2.7 divergences)
2.6 introduced `state↔snapshot` and `patches↔delta`. 2.7 adds:
- `ActivityDeltaEvent.patches` ↔ wire `patch` (singular; `{type:'ACTIVITY_DELTA', messageId, activityType, patch:[ {op,path,…}, … ]}`). Same `JsonPatchOp` array shape as `STATE_DELTA.delta`, different wire key.
- `ReasoningEncryptedValueEvent.encryptedValue` (a `Uint8List`) ↔ wire `encryptedValue` (a base64 **string**) — **same key, divergent type**; and `encryptedValueBase64` has **no wire key of its own** (it is written *to* wire key `encryptedValue` on `toJson`, while the `Uint8List` field is *not* directly serialized). This is the trickiest seam in the union — document it in the subtype's dartdoc so a future reader doesn't "simplify" it by dropping the base64 sibling or re-encoding the bytes.

The hand-rolled codec handles all of this transparently — `fromJson` reads the **wire** key, `toJson` writes the **wire** key, the Dart field uses the **Addendum** name/type. This is *the* reason these events can't use `json_serializable` with `field_rename: none`: the renames and the string↔bytes transform are per-field and semantic, not a mechanical case transform.

### freezed idiom — reuse 2.2–2.6 verbatim (do not reinvent)
Each subtype mirrors the 2.5/2.6 events and `JsonPatchOp`:
```dart
// part of 'ag_ui_event.dart';
@freezed
abstract class ReasoningStartEvent extends AgUiEvent with _$ReasoningStartEvent {
  const ReasoningStartEvent._() : super();

  const factory ReasoningStartEvent({required String messageId}) =
      _ReasoningStartEvent;

  static ReasoningStartEvent fromJson(Map<String, dynamic> json) =>
      ReasoningStartEvent(messageId: _requireString(json, 'messageId'));

  Map<String, dynamic> toJson() => {
        'type': 'REASONING_START',
        'messageId': messageId,
      };
}
```
- The `const X._() : super();` private ctor is what lets a freezed class **both** `extends AgUiEvent` **and** carry a hand-written `toJson` body — proven by every prior union member. **Verify with `build_runner`, do not assume** (retro A1).
- **Do NOT** declare an abstract `toJson()` on `AgUiEvent` (`UnknownAgUiEvent` deliberately has none; 2.5 Dev Notes). Each concrete event declares its own `toJson` independently.
- **Codec placement: form (a) `static X fromJson(...)`** — confirmed by 2.5/2.6 that a plain `static` method named `fromJson` does **not** trigger `json_serializable` and the `X.fromJson` tear-off is a compile-time constant assignable to the `const` registry's `AgUiEvent Function(Map<String, dynamic>)` value by return-type covariance. Do **not** use `factory X.fromJson` (the json_serializable path). Re-verify `build_runner` emits no event `*.g.dart`.
- Structural equality (`==`/`hashCode`) is freezed-generated; all 9 subtypes' freezed code accrues into the **single** `ag_ui_event.freezed.dart`. No per-file `.freezed.dart`.

### koel_lints + `AgUiEvent` (don't trip `melos run analyze`)
`koel_lints`' `exhaustive_switch_must_have_default` keys on `_sealedNames = {'AgUiEvent','KoelError','MessageSegment'}` (`packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart:29`). **`AgUiEvent` IS in that set** — any `switch` *statement* over an `AgUiEvent` value in `lib/` must carry a `default:`. This story introduces **no** such switch: the dispatcher is a `Map` lookup; the new codecs use the helpers + `.map`/getters; `ActivityDeltaEvent.toJson` calls `JsonPatchOp.toJson` per element (a method call, not a union switch). `JsonPatchOp` is **not** in `_sealedNames`. Keep it that way: no default-less `switch (event)` over the union anywhere in `lib/`.

### Toolchain (carried from 2.1–2.6 — unchanged, do not modify)
- freezed `3.2.6-dev.1` + `freezed_annotation ^3.1.0`; analyzer pinned to 12 across the workspace (analyzer-12 stopgap, SCP-2026-05-29-B) so freezed + `analysis_server_plugin 0.3.14` coexist in one pub-workspace resolution. Dart 3.12 / Flutter 3.44 (`.tool-versions`); SDK floor `>=3.11.0`.
- `koel_core/pubspec.yaml` already carries `freezed_annotation`, `json_annotation`, dev-deps `freezed`/`json_serializable`/`build_runner`/`test` + path `koel_lints:`. **No pubspec/build.yaml change needed** — `Uint8List` (`dart:typed_data`) and `base64Decode` (`dart:convert`) are Dart SDK, and `json_patch_op.dart` is already in-package (imported by `ag_ui_event.dart` since 2.6). Add the two `dart:` imports to `ag_ui_event.dart` (mirroring `input/run_agent_input.dart:1` which already imports `dart:typed_data`).
- CI is codegen-aware (2.1): `ci.yml` runs `melos run build` before `analyze`/`test`; `codegen-drift.yml` is a real determinism gate; `format:check` excludes generated output. **This story adds no CI work.** Generated files gitignored at root (`*.g.dart`, `*.freezed.dart`). Run tests via `dart test` directly in `packages/koel_core` (`melos run test` is still a 2.15 stub).

### Git intelligence (recent work patterns to follow)
- `3994989 feat(story-2.6)` — **immediate predecessor and the closest template.** Read `tool_call_events.dart`, `state_events.dart`, `event_codec.dart`, `event_deserializer.dart`: the `static fromJson` + discriminator-first `toJson`, the `_requireString`/`_optionalString`/`_requireMap`/`_decodeObjectList` helpers (extend with `_optionalBool`/`_decodeBase64`), the freezed-only (no `*.g.dart`) posture, the registry-row pattern, the wire-key↔field-name handling (`state↔snapshot`, `patches↔delta`), and the decode-lenient/verify-strict split.
- `025b899 feat(story-2.5)` — froze the codec template; `TextMessageChunkEvent` is the all-optional-chunk pattern `ReasoningMessageChunkEvent` mirrors.
- `e51c604 feat(story-2.4)` — `JsonPatchOp` (the sealed union `ActivityDeltaEvent` consumes via `_decodeObjectList`): `JsonPatchOp.fromJson` factory + per-op `toJson`, `ProtocolError(protocolMalformed)` on bad ops. Read `json_patch_op.dart`.
- Story 2.1 — the `Uint8List` byte-deep-equality precedent: `input/run_agent_input.dart:1` imports `dart:typed_data`; `:14-15` documents freezed's free byte-deep equality on `reasoningEcho: Map<String, Uint8List>`; `test/input/run_agent_input_test.dart:51-81` is the exact equality-test idiom to copy for `ReasoningEncryptedValueEvent`.
- Commit style: Conventional Commits scoped `feat(story-2.7): …`. Do not commit generated files.

### Project Structure Notes
- New files: `lib/src/event/activity_events.dart`, `lib/src/event/reasoning_events.dart` (both `part of 'ag_ui_event.dart'`); tests mirror under `test/event/` (`activity_events_test.dart`, `reasoning_events_test.dart`). Modified: `lib/src/event/event_codec.dart` (add `_optionalBool` + `_decodeBase64`), `lib/src/event/ag_ui_event.dart` (add 2 `part` directives + 2 `dart:` imports — `dart:typed_data`, `dart:convert`), `lib/src/event/event_deserializer.dart` (9 registry entries + doc-comment refresh), `test/event/event_deserializer_test.dart` (seventeen-key → twenty-six-key assertion).
- Architecture confirms the file split (lines 778–779): `activity_events.dart # ACTIVITY_*`, `reasoning_events.dart # REASONING_* incl. ENCRYPTED_VALUE (F-A9)`. The event directory + registry pattern were laid down in 2.2 precisely so 2.5–2.8 only *add* parts + registry rows — no conflict with the unified structure.
- F-A9 traceability (architecture line 999): `reasoning_events.dart` + `input/run_agent_input.dart` is the F-A9 implementation locus. This story delivers the `reasoning_events.dart` half (typed event + bit-exact codec); the `run_agent_input.dart` half (the `reasoningEcho` field) already shipped in 2.1; the wiring between them (reducer accumulation) is 2.12.

### References
- [Source: _bmad-output/planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md#Story 2.7 (lines 161–186)] — story statement + ACs (authoritative for scope); surrounding stories define cross-story consumers (2.8 sweep, 2.11 chunks/verify, 2.12 reducer reasoningEcho accumulation, Epic 5 backend round-trip).
- [Source: sdks/typescript/packages/core/src/events.ts @ ag-ui-protocol/ag-ui (`ActivitySnapshotEventSchema`…`ReasoningEncryptedValueEventSchema`, fetched 2026-05-30)] — authoritative wire field shapes: `ACTIVITY_SNAPSHOT{messageId,activityType,content:record,replace?:bool=true}`, `ACTIVITY_DELTA{messageId,activityType,patch:any[]}`, `REASONING_START{messageId}`, `REASONING_END{messageId}`, `REASONING_MESSAGE_START{messageId,role:"reasoning"}`, `REASONING_MESSAGE_CONTENT{messageId,delta}`, `REASONING_MESSAGE_END{messageId}`, `REASONING_MESSAGE_CHUNK{messageId?,delta?}`, `REASONING_ENCRYPTED_VALUE{subtype:"tool-call"|"message",entityId,encryptedValue:base64string}`; `THINKING_*` schemas are `@deprecated` (removal 1.0.0) — **not** modeled.
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/discovery-ag-ui-spec.md (lines 71–78, 204)] — Activity (2) + Reasoning (7) families; "Reasoning encryption is opaque round-trip data — must be preserved verbatim in message history or providers reject."
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md (lines 140–158)] — §A.1 typed sketches: the four-field `ReasoningEncryptedValueEvent{entityId, subtype, encryptedValue:Uint8List, encryptedValueBase64:String}` mandate ("codec layer decodes to bytes here AND preserves the original string on a sibling field so round-trip is bit-exact").
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md (lines 62–64, 99–101, 522, 638)] — `RunAgentInput.reasoningEcho` + `ChatState.reasoningEcho` (the typed surface the bytes feed, 2.1/2.12); the verify-stage rule "every `REASONING_ENCRYPTED_VALUE` has both `Uint8List` and base64 string" (Story 2.11, **not** here).
- [Source: packages/koel_core/lib/src/event/text_message_events.dart + tool_call_events.dart + state_events.dart + event_codec.dart + event_deserializer.dart (Stories 2.5/2.6)] — the per-event codec template to replicate verbatim; `_requireString`/`_optionalString`/`_requireMap`/`_decodeObjectList` to extend; the registry to grow; `TextMessageChunkEvent` (all-optional chunk) the reasoning chunk mirrors.
- [Source: packages/koel_core/lib/src/json_patch/json_patch_op.dart (Story 2.4)] — `JsonPatchOp.fromJson` factory + per-op `toJson` that `ActivityDeltaEvent` delegates to via `_decodeObjectList`; the `ProtocolError(protocolMalformed)` contract inherited.
- [Source: packages/koel_core/lib/src/input/run_agent_input.dart:1,14-15,36 + test/input/run_agent_input_test.dart:51-81 (Story 2.1)] — `dart:typed_data` import precedent; freezed byte-deep equality on `Uint8List`/`Map<String,Uint8List>`; the equality-test idiom to copy for `ReasoningEncryptedValueEvent`.
- [Source: packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart:29] — `_sealedNames = {'AgUiEvent','KoelError','MessageSegment'}`; `AgUiEvent` IS keyed — avoid default-less union switches.
- [Source: _bmad-output/planning-artifacts/architecture.md (lines 778–779, 999)] — event-dir layout (`activity_events.dart`/`reasoning_events.dart`); F-A9 traceability row (`reasoning_events.dart` + `input/run_agent_input.dart`).
- [Source: _bmad-output/implementation-artifacts/2-6-tool-call-state-messages-snapshot-events.md] — predecessor story: codec template, cross-type delegation, wire-key divergence handling, SF-1 (no raw error past the codec boundary), "verify build_runner don't assume" (retro A1), decode-lenient/verify-strict split, barrel/CI deferral, in-package `src/` test imports.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Claude Opus 4.8) via `/bmad-dev-story` + `/agent-flutter-engineer`.

### Debug Log References

- `dart run build_runner build` → 1 output (`ag_ui_event.freezed.dart`, now covering the 9 new subtypes); re-run wrote **0 outputs** (deterministic, `codegen-drift` clean). `json_serializable` wrote **0 outputs for events** — the `static fromJson` form (a) did not trigger a `*.g.dart`; the only event-tree `*.g.dart` remains the pre-existing `Message`'s, untouched (retro A1 verified by build, not assumed).
- **Uint8List byte-deep `==` verified by source, not assumption** (retro A1): generated `ag_ui_event.freezed.dart:6822` emits `const DeepCollectionEquality().equals(other.encryptedValue, encryptedValue)` for the `Uint8List` field — element-wise, not reference. The Task-3(iv) test (distinct `Uint8List` instances, equal bytes, `identical == false` → `==` true) is the runtime canary.
- `dart test` → **405 pass** (342 baseline + 63 new event tests), 0 failures.
- `melos run analyze` → SUCCESS across all 10 packages incl. `koel_lints`; 0 issues. No default-less `switch` over `AgUiEvent` introduced (deserializer is a `Map` lookup; `ActivityDeltaEvent.toJson` calls `JsonPatchOp.toJson` per element via a `for`-comprehension, never a union `switch`).
- `melos run format:check` → exit 0 (after `dart format` reflowed the two new test files to the formatter's canonical shape — no semantic change).
- Coverage (`dart test --coverage` + `coverage:format_coverage`, scoped to `lib/src/event`, excl. generated `ag_ui_event.freezed.dart`): `activity_events.dart` 23/23 = **100%**, `reasoning_events.dart` 51/51 = **100%**, `event_codec.dart` 43/43 = **100%** — every new branch (base64 success/failure, `replace` present/absent, `patch` list/empty/element-guard, optionals present/absent) exercised. ≥ 90% NFR-12 satisfied.

### Completion Notes List

- Shipped the 9 freezed-immutable `AgUiEvent` subtypes (ACTIVITY×2 in `activity_events.dart`, REASONING×7 in `reasoning_events.dart`) as `part of 'ag_ui_event.dart'`, each with a hand-rolled `type`-discriminated `static fromJson` + discriminator-first `toJson`. Freezed-only; no event `*.g.dart`. Registered all nine in `eventTypeRegistry` (17 → 26 keys).
- **Two new shared helpers in `event_codec.dart`:** `_optionalBool` (absent-preserving `bool?`, non-`bool` → `ProtocolError`) for `ACTIVITY_SNAPSHOT.replace`; `_decodeBase64` (wraps `base64Decode`, `FormatException` → `ProtocolError(protocolMalformed)`) for the encrypted blob — the SF-1 lesson (no raw error past the codec boundary) extended to the boolean + binary paths.
- **The encryptedValue bit-exact codec (FR-A9, the one new mechanic vs 2.5/2.6):** `ReasoningEncryptedValueEvent.fromJson` reads the wire `encryptedValue` base64 string once, stores it verbatim on `encryptedValueBase64`, and decodes it to bytes on `encryptedValue: Uint8List`. `toJson` **echoes the preserved string** back to wire key `encryptedValue` and never re-encodes the bytes — `base64Encode(base64Decode(s))` is not guaranteed to reproduce `s`, so echoing is what makes the wire round-trip byte-exact. A property test over 100 byte sequences (lengths 0–99 → all `%3` padding cases + empty) confirms `base64Decode(toJson()['encryptedValue'])` is bit-exact equal to the source bytes.
- **Field-shape calls (per Dev Notes, sourced from the AG-UI TS schema):** `ActivitySnapshotEvent.replace` is `bool?` and **not** defaulted to the wire's `true` (absent → `null`, omitted on `toJson`, lossless round-trip — the wire default is the consumer's concern); `ReasoningMessageStartEvent.role` and `ReasoningEncryptedValueEvent.subtype` are permissive `String` (no enum narrowing at the wire boundary); `ReasoningMessageChunkEvent` is all-optional (`messageId?`, `delta?`) with **no** `role` (unlike `TEXT_MESSAGE_CHUNK`).
- **`ActivityDeltaEvent.patches: List<JsonPatchOp>`** decodes the wire `patch` array via `_decodeObjectList(json, 'patch', JsonPatchOp.fromJson)` — reusing the Story-2.4 op type and the 2.6 helper, exactly as `STATE_DELTA` does (wire-key divergence `patches`↔`patch`). Decode is lenient: an empty `patch: []` decodes to `patches: []` (the empty/invalid rejection is the verify stage, 2.11).
- **No `THINKING_*` aliases:** koel models `REASONING_*` only; the deprecated upstream `THINKING_*` types are not registered and fall through to `UnknownAgUiEvent` (FC-1). A dispatcher regression test pins this.
- **koel_lints stays satisfied:** the new code reads getters / `.map` / `JsonPatchOp.toJson`, never a `switch` over `AgUiEvent` (which IS in `_sealedNames`). `melos run analyze` green.
- **Cross-story handoffs:** (2.8) the full 28-event sweep round-trip relies on every `toJson` emitting `type` so `deserializeAgUiEvent(toJson())` re-routes — RAW+CUSTOM are the only two members left to close the union; (2.11) the `chunks` stage expands `ReasoningMessageChunkEvent` → MessageStart/Content/End (parallel to TEXT_MESSAGE), and the verify stage enforces the "`REASONING_ENCRYPTED_VALUE` has both bytes + base64" rule this story only *produces*; (2.12) the reducer accumulates `REASONING_ENCRYPTED_VALUE` into `ChatState.reasoningEcho: Map<String, Uint8List>` keyed by `entityId`; (Epic 5) real-backend fixtures verify the bytes echo verbatim through `RunAgentInput.reasoningEcho`.
- **Untouched (scope discipline):** barrel `lib/koel_core.dart` (frozen until 2.15), `pubspec.yaml`/`build.yaml` (no new dep — `Uint8List`/`base64Decode` are Dart SDK, `JsonPatchOp` in-package), CI, the `RAW`/`CUSTOM` types (2.8), and any pipeline/reducer/classifier code.

### File List

- `packages/koel_core/lib/src/event/activity_events.dart` (new) — `ActivitySnapshotEvent`, `ActivityDeltaEvent`.
- `packages/koel_core/lib/src/event/reasoning_events.dart` (new) — `ReasoningStartEvent`, `ReasoningEndEvent`, `ReasoningMessageStartEvent`, `ReasoningMessageContentEvent`, `ReasoningMessageEndEvent`, `ReasoningMessageChunkEvent`, `ReasoningEncryptedValueEvent`.
- `packages/koel_core/lib/src/event/event_codec.dart` (modified) — added `_optionalBool` + `_decodeBase64` shared helpers.
- `packages/koel_core/lib/src/event/ag_ui_event.dart` (modified) — added 2 `part` directives + `dart:convert` & `dart:typed_data` imports.
- `packages/koel_core/lib/src/event/event_deserializer.dart` (modified) — registered the nine new wire types; refreshed the registry doc comment (26/28 union).
- `packages/koel_core/test/event/activity_events_test.dart` (new).
- `packages/koel_core/test/event/reasoning_events_test.dart` (new) — incl. the encryptedValue bit-exact property test + byte-deep equality test.
- `packages/koel_core/test/event/event_deserializer_test.dart` (modified) — registry key assertion 17 → 26; dispatch assertions for the nine new types; `THINKING_*` fall-through guard.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — `2-7` → `in-progress` → `review`.

_Generated `ag_ui_event.freezed.dart` is regenerated by `build_runner` and gitignored — not tracked._

### Change Log

| Date | Change |
|---|---|
| 2026-05-30 | Story drafted (ready-for-dev): 9 `ACTIVITY_*`/`REASONING_*` event subtypes on the 2.5/2.6 codec template; new `_optionalBool`/`_decodeBase64` helpers; `ActivityDeltaEvent.patches` delegates to `JsonPatchOp` (2.4); `ReasoningEncryptedValueEvent` bit-exact `Uint8List`+base64 round-trip (FR-A9) echoing the preserved base64 string (never re-encoding); wire-key divergences (`patches`↔`patch`, `encryptedValue` string↔bytes); decode-lenient (empty `ACTIVITY_DELTA.patch` OK, verify is 2.11; `replace` absent-preserving); no `THINKING_*` aliases. Registry 17 → 26. |
| 2026-05-30 | Implemented Story 2.7: 9 freezed event subtypes (`activity_events.dart`, `reasoning_events.dart`) + hand-rolled `type`-discriminated codecs; added `_optionalBool`/`_decodeBase64` to `event_codec.dart`; `ReasoningEncryptedValueEvent` bit-exact codec (echoes preserved base64, never re-encodes) verified by a 100-sequence property test; `Uint8List` byte-deep `==` confirmed in generated source (`DeepCollectionEquality`, retro A1). Registered all nine in `eventTypeRegistry` (17 → 26); `THINKING_*` fall-through guard. 63 new tests, **405 total green**; analyze + format:check exit 0; **100% line coverage** on new sources; codegen deterministic with no event `*.g.dart`. Status → review. |

| 2026-05-30 | Code review (3 adversarial layers): all 5 ACs FULLY MET, 0 Critical/High. 1 decision + 2 patches applied — corrected the `_decodeBase64` dartdoc + Dev Notes (Dart's `base64Decode` *accepts* base64url, doesn't reject — verified empirically); added an exact wire-shape assertion to `ReasoningEncryptedValueEvent.toJson` (guards against a stray base64 sibling key); reworked the 100-sequence property test to route through `fromJson` so `_decodeBase64` is the path under test. 405 tests still green; analyze + format clean. Status → done. |

### Review Findings

_Code review 2026-05-30 (Blind Hunter + Edge Case Hunter + Acceptance Auditor). All 5 ACs assessed FULLY MET by the Acceptance Auditor; toolchain green; 100% line coverage. Findings below are correctness-of-documentation + test-strength refinements, none blocking. **All resolved 2026-05-30** — 405 tests still green, analyze + format clean._

- [x] [Review][Patch] `_decodeBase64` accepts base64url but doc comments claim it rejects it — Dart's `base64Decode` is the **normalizing** decoder: `base64Decode('a-_b')` is **accepted** (→ `[107,239,219]`), not rejected (verified empirically). The comment in `event_codec.dart` ("A future base64url payload would be rejected here") and the Dev Notes line 156 ("decode would reject → `ProtocolError`") are both factually wrong. Runtime behavior is *safe* (the verbatim `encryptedValueBase64` is echoed on `toJson`, so the wire round-trip stays byte-exact and FR-A9 holds; the decoded bytes feed the opaque, never-inspected `reasoningEcho` surface) — re-encoding `a-_b`'s bytes with the std alphabet yields `a+/b ≠ a-_b`, which is exactly why the "never re-encode" design is correct. **Decision (Si, 2026-05-30): Option A — accept reality**, correct both comments to state base64url is accepted and the bytes may use a url-safe interpretation (minimal, no behavior change). [`packages/koel_core/lib/src/event/event_codec.dart` + `reasoning_events.dart` dartdoc]
- [x] [Review][Patch] `ReasoningEncryptedValueEvent.toJson` has no exact key-set assertion — a regression that added a stray `'encryptedValueBase64'` wire key (or reordered/dropped a key) would pass every existing test; other events assert full-map equality but the encrypted event only checks the `encryptedValue` value. Add a full-map equality assertion on its `toJson` output. [`packages/koel_core/test/event/reasoning_events_test.dart`]
- [x] [Review][Patch] 100-sequence property test's `toJson` leg is tautological — events are built by direct construction with `encryptedValueBase64 = base64Encode(bytes)`, so `base64Decode(event.toJson()['encryptedValue'])` reduces to `base64Decode(base64Encode(bytes))` (a Dart-SDK identity), never exercising koel's `fromJson`/`_decodeBase64` across the 100 sequences. The verbatim-echo behaviour is covered by the separate single-case wire round-trip test, but the *sweep* should route through `fromJson(wire)` so `_decodeBase64` is the path under test for all padding residues. [`packages/koel_core/test/event/reasoning_events_test.dart`]
