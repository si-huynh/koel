---
baseline_commit: d7efe39c6b3cb8ba9aa8c352fad2e3d54ed4e962
---

# Story 2.8: `RAW` + `CUSTOM` events + 28-type integration sweep

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter/Dart developer,
I want `RawEvent` and `CustomEvent` typed subtypes plus an integration sweep that exercises all ~28 event types together,
so that the sealed `AgUiEvent` union closes out the AG-UI `release/2026-05-26` registry per FR-A7.

## Acceptance Criteria

Verbatim from [epic-2 Story 2.8](../planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md):

1. **Given** `koel_core/lib/src/event/raw_event.dart` and `custom_event.dart`, **When** I inspect them, **Then** each subtype is freezed with the wire-defined fields (`RawEvent.payload: Map<String, dynamic>`; `CustomEvent` per AG-UI spec).

2. **Given** a synthesized fixture file `koel_core/test/event/full_event_sweep.jsonl` containing one canonical example of every ~28 event types, **When** I run the sweep test, **Then** each line deserializes to a non-`Unknown` typed subtype, **And** round-tripping each event through `toJson() → fromJson()` produces structural equality, **And** the dispatcher `eventTypeRegistry` maps every wire-type string to its concrete subtype with no orphans.

3. **Given** the consumer-side switch over `AgUiEvent` (in a test file that intentionally omits `default:`), **When** `dart analyze` runs with `package:koel_lints/koel.yaml`, **Then** `exhaustive_switch_must_have_default` fires with error severity per FR-A12 (validated end-to-end here, not just in koel_lints fixtures).

> **⚠️ AC3 wording is stale — read Dev Notes §"AC3: how the lint actually fires now".** The `include: package:koel_lints/koel.yaml` mechanism the AC names was the **custom_lint** path, which Story 1.7 ripped out. Under `analysis_server_plugin` the rule is enabled at the **workspace-root** `analysis_options.yaml` and fires through plain `dart analyze`. The AC's *intent* (prove the rule fires on real consumer source, not just koel_lints unit fixtures) is unchanged and is what you must satisfy.

## Tasks / Subtasks

- [x] **Task 1 — Create `raw_event.dart` with `RawEvent`** (AC: #1)
  - [x] New file `packages/koel_core/lib/src/event/raw_event.dart`, first line `part of 'ag_ui_event.dart';`.
  - [x] Define `RawEvent` as a freezed subtype using the **exact** idiom in Dev Notes §"Freezed subtype template". Fields per the **recommended spec** in Dev Notes §"RAW/CUSTOM wire schema — decisions": `payload: Map<String, dynamic>` (required, ↔ wire key `event`) + `source: String?` (optional, ↔ wire key `source`).
  - [x] `fromJson`: `payload: _requireMap(json, 'event')`, `source: _optionalString(json, 'source')`.
  - [x] `toJson`: discriminator-first `'type': 'RAW'`, then `'event': payload`, then `if (source != null) 'source': source`.
  - [x] Dartdoc per Dev Notes §"Dartdoc requirements" — document the `payload`↔`event` wire-key divergence and the PII/passthrough warning.
- [x] **Task 2 — Create `custom_event.dart` with `CustomEvent`** (AC: #1)
  - [x] New file `packages/koel_core/lib/src/event/custom_event.dart`, first line `part of 'ag_ui_event.dart';`.
  - [x] Define `CustomEvent` (freezed): `name: String` (required, wire `name`) + `value: Object?` (required parameter, holds AG-UI `value: any`, wire `value`).
  - [x] `fromJson`: `name: _requireString(json, 'name')`, `value: json['value']` (raw — `any` permits any JSON type incl. `null`; no helper).
  - [x] `toJson`: `'type': 'CUSTOM'`, `'name': name`, `'value': value` (always emit `value`, even when `null`, to preserve round-trip).
  - [x] Dartdoc: when to use `CustomEvent` (consumer/provider-declared extension events) vs `RawEvent` (opaque upstream passthrough).
- [x] **Task 3 — Wire the two parts + registry** (AC: #1, #2)
  - [x] In `packages/koel_core/lib/src/event/ag_ui_event.dart`, add `part 'raw_event.dart';` and `part 'custom_event.dart';` **before** `part 'ag_ui_event.freezed.dart';`. Update the closing dartdoc sentence "join the union as parts in Stories 2.5–2.8" if any list is enumerated.
  - [x] In `packages/koel_core/lib/src/event/event_deserializer.dart`, add `'RAW': RawEvent.fromJson,` and `'CUSTOM': CustomEvent.fromJson,` to `eventTypeRegistry` (→ 28 entries). Update the doc comment: "(26 of the ~28-type union — `RAW` + `CUSTOM` remain for Story 2.8)" → state the union is now complete at 28 typed families + `UnknownAgUiEvent`.
  - [x] `dart run build_runner build --delete-conflicting-outputs` from `packages/koel_core`; re-run → expect **0** new outputs (deterministic codegen).
- [x] **Task 4 — Per-subtype unit tests** (AC: #1)
  - [x] `packages/koel_core/test/event/raw_event_test.dart` and `custom_event_test.dart`, mirroring `reasoning_events_test.dart` exactly (see Dev Notes §"Test template"). Cover: const construction + type membership; equality + copyWith; round-trip via `fromJson(toJson())` AND `deserializeAgUiEvent(toJson())`; missing/wrong-type required field → `ProtocolError(protocolMalformed)`; optional `source` absent→null & present-wrong-type→throw; `CustomEvent.value` round-trips for object/list/string/number/`null`.
- [x] **Task 5 — Synthesized sweep fixture + sweep test** (AC: #2)
  - [x] Create `packages/koel_core/test/event/full_event_sweep.jsonl` — exactly **28** lines, one canonical wire-JSON object per registered type (one per `eventTypeRegistry` key). Build canonical examples from the dispatch cases in `event_deserializer_test.dart` (they already enumerate valid minimal payloads for 26 types) + RAW + CUSTOM.
  - [x] Create `packages/koel_core/test/event/full_event_sweep_test.dart`. Read the file via `File('test/event/full_event_sweep.jsonl').readAsLinesSync()` (paths in `dart test` resolve from package root). For each non-empty line: `jsonDecode` → `deserializeAgUiEvent` → assert `isNot(isA<UnknownAgUiEvent>())`; assert round-trip `deserializeAgUiEvent(event.toJson())` `equals(event)` (structural).
  - [x] **No-orphans assertion:** parse the `type` of every fixture line into a Set and assert it `unorderedEquals` `eventTypeRegistry.keys` — proves the fixture covers every registered type and the registry has no type the fixture misses. This is the "no orphans" clause.
- [x] **Task 6 — Grow the existing registry test from 26 → 28** (AC: #2)
  - [x] In `event_deserializer_test.dart`: rename the test ("twenty-six" → "twenty-eight"; "Story-2.5–2.7" → "Story-2.5–2.8"), add `'RAW'` + `'CUSTOM'` to the `unorderedEquals` set, and add two `deserializeAgUiEvent(...) isA<RawEvent>()` / `isA<CustomEvent>()` dispatch cases.
- [x] **Task 7 — AC3 end-to-end lint validation (transient probe)** (AC: #3)
  - [x] Follow Dev Notes §"AC3: how the lint actually fires now" to the letter. Create a **transient** probe file with a `switch` over an `AgUiEvent`-typed variable and **no** `default:`, run `dart analyze packages/koel_core`, capture the diagnostic showing `exhaustive_switch_must_have_default` at **error** severity on koel_core source, paste the captured output into Completion Notes, then **delete the probe** so `melos run analyze` stays zero-warning. Do **not** leave a failing file in the tree.
- [x] **Task 8 — Quality gates** (AC: all)
  - [x] `dart test` (from `packages/koel_core`) → all green.
  - [x] `melos run analyze` → 0 issues (probe removed).
  - [x] `melos run format:check` (or `dart format --set-exit-if-changed .`) → clean.
  - [x] Coverage on `lib/src/event/raw_event.dart` + `custom_event.dart` (excl. `*.freezed.dart`) ≥ 90% line + branch (N-12).
  - [x] Confirm `lib/koel_core.dart` barrel is **untouched** (export sweep is Story 2.15) and no `pubspec.yaml` / `build.yaml` changes.

### Review Findings

_Code review 2026-05-30 (3 adversarial layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor). All 3 ACs substantiated; registry closed at 28 + `UnknownAgUiEvent`; no `Critical`/`High` correctness defects in production codecs. One documentation-correctness patch, one deferred test-harness item, four dismissed._

- [x] [Review][Patch] `CustomEvent.value` dartdoc states the opposite of actual freezed equality — claims `value: Object?` is compared "by `==`/identity, **not** deep equality" so "two `CustomEvent`s built from separate equal-but-distinct maps are not `==`". **Verified false:** the generated `ag_ui_event.freezed.dart:7354/7359` emits `const DeepCollectionEquality().equals(other.value, value)` + `DeepCollectionEquality().hash(value)`, so distinct content-equal maps **are** `==` (and `hashCode`-equal). The same wrong claim is duplicated in the Completion Notes ("`Object?` is not statically a collection, so freezed compares it by `==`/identity, not deep equality"). Misleads anyone reasoning about dedup/caching by equality. Fix: correct the dartdoc (and the Completion Notes bullet) to state `value` IS deep-equality compared at runtime via `DeepCollectionEquality`, regardless of the `Object?` static type. [packages/koel_core/lib/src/event/custom_event.dart:175-182] (source: blind+edge, confirmed by reviewer)

- [x] [Review][Defer] `full_event_sweep_test` relative fixture path fails to load when `dart test` runs from a CWD other than the package root [packages/koel_core/test/event/full_event_sweep_test.dart:14-17] — deferred, pre-existing convention. The `File('test/event/full_event_sweep.jsonl')` read sits at `group`-body scope, so a non-package-root CWD (e.g. `dart test packages/koel_core/...` from the monorepo root) throws `FileSystemException` and fails the whole file to load. This exactly matches the already-shipping `rfc6902_conformance_test.dart` convention (`File('test/json_patch/...')`); `melos exec` runs scripts per-package (CWD = package root) and `melos run test` is still a stub until Story 2.15. Revisit when the test harness is wired in 2.15. (source: edge)

## Dev Notes

### What this story is, in one paragraph
The `AgUiEvent` sealed union is a closed registry. Stories 2.5–2.7 added 26 typed families; this story adds the final two — `RawEvent` and `CustomEvent` — bringing the registry to **28** typed families + the always-present `UnknownAgUiEvent` forward-compat fallback. Then it proves the whole union holds together: a single 28-line JSONL fixture deserializes line-by-line into concrete (non-`Unknown`) subtypes, each round-trips structurally, the registry has no orphans, and the `exhaustive_switch_must_have_default` lint is shown firing on real koel_core consumer source (not just koel_lints unit fixtures). This is the closeout of Epic 2's event layer. **The codec mechanics are 100% established — you are copying a proven pattern twice, not inventing anything.** [Source: epic-2 §"Story 2.8"; architecture.md L33 "`AgUiEvent` (~28 subtypes + `UnknownAgUiEvent`)"]

### Files you will touch
| Path | Action | Note |
|------|--------|------|
| `packages/koel_core/lib/src/event/raw_event.dart` | **NEW** | `RawEvent` part file |
| `packages/koel_core/lib/src/event/custom_event.dart` | **NEW** | `CustomEvent` part file |
| `packages/koel_core/lib/src/event/ag_ui_event.dart` | UPDATE | add 2 `part` directives (before the `.freezed.dart` part) |
| `packages/koel_core/lib/src/event/event_deserializer.dart` | UPDATE | add 2 registry entries; refresh doc comment |
| `packages/koel_core/lib/src/event/ag_ui_event.freezed.dart` | REGEN | generated; do not hand-edit |
| `packages/koel_core/test/event/raw_event_test.dart` | **NEW** | per-subtype tests |
| `packages/koel_core/test/event/custom_event_test.dart` | **NEW** | per-subtype tests |
| `packages/koel_core/test/event/full_event_sweep.jsonl` | **NEW** | 28-line fixture |
| `packages/koel_core/test/event/full_event_sweep_test.dart` | **NEW** | sweep + no-orphans test |
| `packages/koel_core/test/event/event_deserializer_test.dart` | UPDATE | 26 → 28 |

**Do NOT touch:** `lib/koel_core.dart` (barrel — frozen until Story 2.15), `pubspec.yaml`, `build.yaml`, the existing 26 event files, or `event_codec.dart` (all needed helpers already exist — see below). Adding a new codec helper is a smell here; both new events decode with `_requireMap` / `_optionalString` / `_requireString` that already ship.

### RAW/CUSTOM wire schema — decisions (read before coding)

The epic AC1 says `RawEvent.payload: Map<String, dynamic>` and `CustomEvent` "per AG-UI spec." The canonical AG-UI `release/2026-05-26` wire shapes (confirmed against `@ag-ui/core` `events.ts`, docs.ag-ui.com/sdk/js/core/events) are:

```typescript
// BaseEvent (all events): { type, timestamp?: number, rawEvent?: any }  .passthrough()
RawEvent    = BaseEvent.extend({ type: "RAW",    event: z.any(),  source: z.string().optional() })
CustomEvent = BaseEvent.extend({ type: "CUSTOM", name: z.string(), value: z.any() })
```

There is a real gap between the AC and the canonical wire, resolved here per the codebase's established conventions (the `Dart-field-name ≠ wire-key` divergence is already used by `StateSnapshotEvent.state ↔ wire snapshot`, `ActivityDeltaEvent.patches ↔ wire patch`, etc.). **Recommended spec — implement this; see "Open questions" to confirm/override with Si:**

- **`RawEvent`**
  - Dart `payload: Map<String, dynamic>` (required) **↔ wire key `event`**. Keep the epic's `Map<String, dynamic>` typing (koel narrows AG-UI's `any` to an object — the typed surface only models object payloads; non-object raw payloads are out of koel's typed model and would throw `protocolMalformed`, which is acceptable since the synthesized canonical example is an object).
  - Dart `source: String?` (optional) **↔ wire key `source`** — include it. It is RawEvent's own first-class field; dropping it would silently lose data on round-trip if a backend sends it. Cheap, and matches "freezed with the wire-defined fields."
  - Do **not** model base `timestamp`/`rawEvent` — koel's existing typed events (e.g. `RunStartedEvent`) deliberately model only semantically-needed fields and are lossy w.r.t. base passthrough keys. Stay consistent.
- **`CustomEvent`**
  - Dart `name: String` (required) ↔ wire `name`.
  - Dart `value: Object?` (required parameter that may hold `null`) ↔ wire `value`. AG-UI `value` is `any` and **required**, so model it as a required-but-nullable `Object?`. Decode with a bare `json['value']` (any JSON type is valid — object, list, string, num, bool, null); `toJson` always emits `'value': value`.

**Why `payload ↔ event` and not wire key `payload`:** real AG-UI servers emit `{"type":"RAW","event":…}`. The fixture is ours to write, so either key passes AC2 in isolation — but Epic 5 conformance runs against captured real-backend fixtures, where the wire key is `event`. Choosing `event` now avoids a guaranteed rework. The Dart-side name stays `payload` exactly as AC1 dictates.

[Source: AG-UI `@ag-ui/core` events.ts via docs.ag-ui.com/sdk/js/core/events; epic-2 §"Story 2.8" AC1; divergence-handling convention architecture.md L513-558 "JSON serialization wire conventions"]

### Freezed subtype template (copy this idiom EXACTLY — it is the frozen 2.5–2.7 pattern)

From [reasoning_events.dart](../../packages/koel_core/lib/src/event/reasoning_events.dart) — every event in the package follows this shape:

```dart
part of 'ag_ui_event.dart';

/// `RAW` — <one-line contract>. <when to use / divergence / PII note>.
@freezed
abstract class RawEvent extends AgUiEvent with _$RawEvent {
  const RawEvent._() : super();                 // REQUIRED private ctor — enables hand-written toJson

  const factory RawEvent({
    required Map<String, dynamic> payload,
    String? source,
  }) = _RawEvent;

  /// Decodes a `RAW` wire payload. Throws [ProtocolError]`(protocolMalformed)`
  /// when `event` is absent or not a JSON object.
  static RawEvent fromJson(Map<String, dynamic> json) => RawEvent(
    payload: _requireMap(json, 'event'),        // wire key 'event' → Dart field 'payload'
    source: _optionalString(json, 'source'),
  );

  Map<String, dynamic> toJson() => {
    'type': 'RAW',                              // discriminator FIRST (makes toJson re-routable)
    'event': payload,                           // write the WIRE key
    if (source != null) 'source': source,       // omit absent optionals
  };
}
```

Non-negotiable rules baked into this idiom:
- `@freezed` (lowercase), `abstract class X extends AgUiEvent with _$X`.
- `const X._() : super();` private ctor is mandatory — without it the hand-written `toJson` won't compile against the freezed mixin.
- `static fromJson` (NOT a `factory`) — it must be assignable as a `AgUiEvent Function(Map<String, dynamic>)` tear-off into `eventTypeRegistry`. **No `json_serializable` on events** — there is no `*.g.dart` for events; only `ag_ui_event.freezed.dart` is generated.
- `toJson` is **discriminator-first** and writes **wire** key names; absent optionals omitted via `if (x != null) 'k': x`.
- All malformed-input paths must surface `ProtocolError(protocolMalformed)`, never a raw `TypeError`/`FormatException` — that's exactly what the `_require*`/`_optional*` helpers guarantee (SF-1 lesson). [Source: event_codec.dart helper dartdocs]

### Codec helpers that already exist (use; do not add new ones)
From [event_codec.dart](../../packages/koel_core/lib/src/event/event_codec.dart):
- `String _requireString(json, key)` — required string, else `protocolMalformed`.
- `String? _optionalString(json, key)` — null if absent/null; throws if present non-string. → use for `RawEvent.source`.
- `Map<String, dynamic> _requireMap(json, key)` — required object, else `protocolMalformed`. → use for `RawEvent.payload` (reading wire key `event`).
- `_decodeObjectList`, `_optionalBool`, `_decodeBase64`, `_koelErrorCodeFromWire` — not needed for 2.8.
`CustomEvent.value` needs **no** helper: `json['value']` is already `Object?` and any JSON value is valid.

### The dispatcher contract (important nuance the AC glosses over)
[deserializeAgUiEvent](../../packages/koel_core/lib/src/event/event_deserializer.dart) **never throws.** Unknown type, missing `type`, or non-`String` `type` → `UnknownAgUiEvent` (FR-A6/FC-1). A `ProtocolError` only escapes when a **registered** factory is called on a malformed payload of that known type (e.g. `RAW` with a non-object `event`). So:
- In the sweep test, every fixture line has a valid registered `type`, so each routes to a concrete factory.
- Negative tests for malformed RAW/CUSTOM payloads must call the factory `RawEvent.fromJson({...})` **directly** (or `deserializeAgUiEvent` with a present-but-bad payload of a registered type) to observe the throw — calling `deserializeAgUiEvent` with an *unregistered* type yields `UnknownAgUiEvent`, not a throw.

### Test template (mirror `reasoning_events_test.dart`)
Top-of-file `_malformed` matcher and imports are standardized:
```dart
import 'dart:convert';
import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/event/event_deserializer.dart';
import 'package:test/test.dart';

final _malformed = throwsA(
  isA<ProtocolError>().having((e) => e.code, 'code', KoelErrorCode.protocolMalformed),
);
```
Per-subtype `group` covers (from the proven 2.7 test): const construction + `isA<AgUiEvent>()`/`isA<RawEvent>()`; `equals` + `copyWith` inequality; explicit `toJson()` map literal; `fromJson(toJson())` equals; `deserializeAgUiEvent(toJson())` equals; required-field-missing → `_malformed`; required-field-wrong-type → `_malformed`. For `RawEvent.source` add absent→null and present-non-string→`_malformed`. For `CustomEvent.value` add round-trips for `{}`, `[1,2]`, `'s'`, `42`, and `null` (the null case is why `toJson` must always emit `'value'`). Tests import from `package:koel_core/src/...` (the barrel is empty until 2.15 — see existing tests).

### AC3: how the lint actually fires now (Story 1.7 changed the mechanism)
The AC names `include: package:koel_lints/koel.yaml` — that was the **custom_lint** wiring, which Story 1.7 removed entirely (custom_lint was archived upstream; koel pivoted to first-party `analysis_server_plugin`). Current reality:
- Enforcement is wired **once** at the workspace-root [analysis_options.yaml](../../analysis_options.yaml):
  ```yaml
  plugins:
    koel_lints:
      path: packages/koel_lints
      diagnostics:
        exhaustive_switch_must_have_default: true
  ```
  Members carry no `analysis_options.yaml` and inherit this. `koel_core` has none — correct, leave it that way.
- The rule keys on the switch subject's **type name** via `_sealedNames = {'AgUiEvent', 'KoelError', 'MessageSegment'}` ([exhaustive_switch_must_have_default.dart:29](../../packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart)). Your probe switch **must** be over a variable statically typed `AgUiEvent` (not a concrete subtype) for the rule to engage.
- Under asp, plain `dart analyze` loads the plugin (unlike custom_lint, which `dart analyze` ignored — see deferred-work.md). So the end-to-end validation the AC wants is now genuinely achievable on consumer source, which is the whole point of the asp pivot.

**Procedure (transient — must leave the tree clean):**
1. Create `packages/koel_core/lib/_ac3_probe.dart` with `part`-free standalone code:
   ```dart
   import 'src/event/ag_ui_event.dart';
   String probe(AgUiEvent e) {
     switch (e) {                          // no default: — must trip the rule
       case RunStartedEvent(): return 'run';
       case RawEvent(): return 'raw';
       // intentionally non-exhaustive, no default
     }
   }
   ```
2. Run `dart analyze packages/koel_core` (from repo root). Confirm `exhaustive_switch_must_have_default` is reported at **error** severity on `_ac3_probe.dart`.
3. Paste the analyzer output verbatim into Completion Notes as the AC3 evidence.
4. **Delete `_ac3_probe.dart`.** Re-run `melos run analyze` → 0 issues.
> Prior stories used the same throwaway-probe approach (`_verify_lint.dart`) and deleted it; the CI `melos run analyze` zero-warning gate (NFR-13) forbids a permanently-failing file. If the rule does **not** fire on koel_core source under asp, that is a finding worth surfacing immediately (it would mean the 1.7 pivot's consumer-source enforcement is incomplete) — do not silently mark AC3 done; record the evidence either way. [Source: deferred-work.md L43-59 custom_lint→asp spike; story 1-7]

### Counts to assert (so "~28" is concrete)
Current `eventTypeRegistry` = **26** keys (verified). +`RAW` +`CUSTOM` = **28**. The sweep fixture = **28** lines. `UnknownAgUiEvent` is not wire-deserializable (it has no `fromJson` and is never in the registry), so it is **not** a fixture line; its fallback behavior is already covered in `event_deserializer_test.dart` and needs no new test here. [Source: event_deserializer.dart registry; unknown_event.dart]

### Project structure & conventions
- koel_core layout: events live in `lib/src/event/`, each family one `part of 'ag_ui_event.dart'` file; tests mirror at `test/event/<name>_test.dart`. [Source: architecture.md L780-781 lists `raw_event.dart # RAW` and `custom_event.dart # CUSTOM` explicitly]
- Wire keys are `camelCase`, Dart fields `camelCase`, no translation layer; per-field divergence handled in the hand-rolled codec (not `@JsonKey`). [Source: architecture.md L552-558]
- `const` everywhere; freezed immutables; `copyWith` is the only mutation path. [Source: architecture.md L541-548]
- Collections: freezed wraps top-level collection fields in unmodifiable views automatically (gives deep `==`); `Map<String,dynamic> payload` therefore compares structurally. Do not mutate nested values post-construction. [Source: unknown_event.dart dartdoc; reasoning_events.dart]

### Dartdoc requirements
Every public symbol needs a doc comment: one-line contract summary, blank line, then semantics + when-to-use + when-NOT-to-use + error cases, optional example. For `RawEvent`, document (a) the `payload ↔ event` wire-key divergence, (b) that the payload is an opaque passthrough koel never inspects/validates/redacts — consumers own any sensitive data (a `PIIRedactionInterceptor`, default-OFF, ships later in `koel_http`), and (c) prefer `CustomEvent` for provider-declared structured extensions vs `RawEvent` for opaque upstream passthrough. [Source: architecture.md implementation patterns; epic cross-cutting #3]

### Tech stack (no changes needed; for reference)
- Dart SDK `>=3.11.0 <4.0.0`; freezed_annotation `^3.1.0`; `freezed: 3.2.6-dev.1` (analyzer-12 stopgap, SCP-2026-05-29-B); json_serializable `^6.8.0` (unused by events); test `^1.25.0`. [Source: packages/koel_core/pubspec.yaml]
- Analyzer/lint: `analysis_server_plugin`-based `koel_lints` (Story 1.7); rule off-by-default, enabled at root with `diagnostics:`. [Source: root analysis_options.yaml; project memory "lint pivot"]

## Previous Story Intelligence

From Stories 2.5 → 2.7 (the immediate template lineage):
- **2.5** froze the codec template (RUN×3, STEP×2, TEXT×4 = 9 events): static `fromJson`, discriminator-first `toJson`, `const X._()` seam, helper-based decode.
- **2.6** added 8 events + introduced **wire-key divergence** (`StateSnapshotEvent.state ↔ snapshot`) and cross-type delegation (`JsonPatchOp`, `Message`). This is the precedent for `RawEvent.payload ↔ event`.
- **2.7** added 9 events + the `Uint8List` **bit-exact** codec (`encryptedValue` echoed verbatim, never re-encoded) and helpers `_optionalBool`/`_decodeBase64`. Confirmed freezed gives `Uint8List`/`Map`/`List` deep `==`.
- **Recurring review theme across 2.5–2.7:** no raw `TypeError`/`FormatException` may cross the codec boundary — every cast that can fail on malformed wire data goes through a `_require*`/`_optional*` helper that emits `ProtocolError(protocolMalformed)`. Carry this discipline into RAW/CUSTOM.
- **Pattern for registry growth:** one `const` map entry per type (tear-off), one `part` directive, one mirrored test file, and bump the `event_deserializer_test.dart` count assertion. The git stats for 2.6/2.7 commits show exactly this surgical footprint (≈+1300–1500 lines, ~10 files). [Source: 2-7-activity-reasoning-events.md; git log d7efe39/3994989]

## Git Intelligence Summary
Last event-story commits are textbook templates for this one:
- `d7efe39 feat(story-2.7)` touched: `activity_events.dart`(+81), `reasoning_events.dart`(+205), `ag_ui_event.dart`(+5 parts), `event_codec.dart`(+42), `event_deserializer.dart`(+18), 3 test files, `event_deserializer_test.dart`(+83). 
- `3994989 feat(story-2.6)` same shape (+state/tool files, +66 codec, registry +15).
Your 2.8 footprint will be **smaller** (no new codec helpers, simpler events): 2 new `lib` files, 2 `part` lines, 2 registry entries, 2 new test files, 1 fixture, 1 sweep test, +2 in the count test. Match the commit-message convention: `feat(story-2.8): RAW/CUSTOM event subtypes + 28-type integration sweep`.

## Latest Tech Information
AG-UI `release/2026-05-26` event registry, confirmed against `@ag-ui/core` (`events.ts`) and docs.ag-ui.com/sdk/js/core/events:
- `RawEvent`: `{ type:"RAW", event: any (required), source?: string }` + base `timestamp?`, `rawEvent?`. **The raw payload field is `event`, not `payload`** — hence the koel-side divergence.
- `CustomEvent`: `{ type:"CUSTOM", name: string (required), value: any (required) }` + base optionals.
- `BaseEvent` is `.passthrough()` (extra keys preserved upstream) and carries optional `timestamp:number` + `rawEvent:any` — koel deliberately does not model these on typed events (consistent with 2.5–2.7).
No new dependencies, no version changes. [Sources: github.com/ag-ui-protocol/ag-ui `sdks/typescript/packages/core/src/events.ts`; https://docs.ag-ui.com/sdk/js/core/events]

### Project Structure Notes
- New files land exactly where architecture.md L780-781 already pencils them in (`raw_event.dart`, `custom_event.dart`). No structural variance.
- The barrel `lib/koel_core.dart` is intentionally empty (`library;` only) until Story 2.15's export sweep — do not add exports. Tests import `package:koel_core/src/...` directly, as all existing event tests do.
- AC3 wording variance (custom_lint `koel.yaml` vs asp root wiring) is documented above; this is a known spec-vs-reality drift from the Story 1.7 pivot, not a structure conflict.

### References
- [epic-2 Story 2.8 spec + ACs](../planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md)
- [architecture.md — event layout L780-781; wire conventions L513-558; ~28 subtypes L33](../planning-artifacts/architecture.md)
- [reasoning_events.dart — template](../../packages/koel_core/lib/src/event/reasoning_events.dart)
- [event_codec.dart — helpers](../../packages/koel_core/lib/src/event/event_codec.dart)
- [event_deserializer.dart — registry + dispatcher contract](../../packages/koel_core/lib/src/event/event_deserializer.dart)
- [event_deserializer_test.dart — count + dispatch test to extend](../../packages/koel_core/test/event/event_deserializer_test.dart)
- [reasoning_events_test.dart — test template](../../packages/koel_core/test/event/reasoning_events_test.dart)
- [root analysis_options.yaml — asp lint wiring](../../analysis_options.yaml)
- [exhaustive_switch_must_have_default.dart — `_sealedNames` keys on `AgUiEvent`](../../packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart)
- [deferred-work.md L43-59 — custom_lint→asp spike (why AC3 wording is stale)](deferred-work.md)
- [2-7-activity-reasoning-events.md — prior-story patterns](2-7-activity-reasoning-events.md)
- AG-UI spec: https://docs.ag-ui.com/sdk/js/core/events

### Open questions for Si — RESOLVED (Si: "let's go with your recommendations", 2026-05-30)
1. **`RawEvent.payload` wire key** — ✅ Dart `payload` ↔ wire `event` (canonical AG-UI; matches real backends for Epic 5 conformance).
2. **`RawEvent.source`** — ✅ included as optional `source: String?` (omitted from `toJson` when null).
3. **`CustomEvent.value` Dart type** — ✅ `Object?` (required-nullable); decoded as-is, always emitted (even `null`).
4. **Map narrowing** — ✅ kept `payload: Map<String, dynamic>` per AC1; non-object `event` decodes to `ProtocolError(protocolMalformed)`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8, 1M context) — via `/agent-flutter-engineer` implement mode.

### Debug Log References

- `dart run build_runner build` → 1 output (`ag_ui_event.freezed.dart` regen for `RawEvent`+`CustomEvent`); 2nd run → 0 outputs (deterministic).
- `dart test` (koel_core) → **428 passed** (baseline 405 + 23 new).
- `dart run melos run analyze` → 0 issues across all 10 packages.
- `dart run melos run format:check` → 0 changed (after applying `format`).
- Coverage: `raw_event.dart` 8/8 lines (100%), `custom_event.dart` 6/6 lines (100%) — both ≥ 90% (N-12).
- **AC3 evidence (transient probe over the real 28-type closed union, since deleted):**
  ```
  $ dart analyze packages/koel_core   # with lib/_ac3_probe.dart present
    error - lib/_ac3_probe.dart:9:37 - switch over sealed koel type must include a
            `default:` branch (adding a new subtype is a semver-minor bump per FR-A12).
            - exhaustive_switch_must_have_default
  1 issue found.   (exit 3)
  ```
  Exactly one error, ERROR severity, on a switch over the real `AgUiEvent` — proving the rule guards real consumer source, not just koel_lints unit fixtures. Probe deleted; `dart analyze packages/koel_core` → "No issues found!".
- Corroboration: the permanent end-to-end check `koel_lints/test/integration/dart_analyze_fires_test.dart` passes ("reports exactly one error via the server-plugin path").

### Completion Notes List

- **All 3 ACs satisfied.** Registry closed at 28 typed families + `UnknownAgUiEvent`; sweep proves every type deserializes to a non-`Unknown` subtype, round-trips structurally, and has no orphans; the exhaustiveness lint fires at ERROR on the real union.
- **Schema decisions** implemented per Si's confirmation (see Open questions, all ✅): `RawEvent.payload: Map<String,dynamic>` ↔ wire `event` + optional `source: String?`; `CustomEvent.name: String` + `value: Object?` (any JSON value incl. `null`).
- **No new codec helpers** — `RawEvent` decodes via existing `_requireMap`/`_optionalString`; `CustomEvent.value` reads `json['value']` raw (any JSON value valid). `event_codec.dart` untouched.
- **`CustomEvent.value` equality** (documented in its dartdoc): despite the `Object?` static type, freezed compares `value` with `DeepCollectionEquality` at runtime — two `CustomEvent`s built from separate but content-equal maps/lists **are** `==` (and share a `hashCode`); scalars compare by value. `RawEvent.payload` (a `Map` field) gets deep equality as usual. _(Corrected in code review 2026-05-30 — the original note here and the dartdoc wrongly claimed identity-only comparison; verified against `ag_ui_event.freezed.dart` `DeepCollectionEquality().equals(other.value, value)`.)_
- **Re-encode in the sweep** (`full_event_sweep_test.dart::_encode`): the sealed root declares no `toJson` (each subtype owns its codec; `UnknownAgUiEvent` deliberately has none), and `deserializeAgUiEvent` returns the root type — so the sweep re-serializes via an exhaustive `switch` with a wildcard `default` (the exact koel_lints-mandated forward-compat shape). This keeps the public API as specified by Stories 2.2/2.8 (no root `toJson` added).
- **Deferred-work observation (not actioned — out of scope):** a polymorphic `AgUiEvent.toJson()` on the sealed root would remove the need for consumer-side re-encode switches and is likely wanted by Epic 8 (`koel_devtools` JSONL export / `jsonl_reader.dart` re-import). Adding it now would force `@override` across all 28 existing event files (out of this story's scope, which excludes touching them) and would revisit `UnknownAgUiEvent`'s documented "no `toJson`" stance (`=> rawJson` would be byte-exact and correct). Flag for a future story.
- **AC3 spec drift confirmed & handled:** the AC's `include: package:koel_lints/koel.yaml` is the dead custom_lint mechanism (Story 1.7 pivot); enforcement is now the workspace-root `analysis_options.yaml` `plugins:` + `diagnostics:` wiring, fired via `dart analyze`. Intent (end-to-end firing on consumer source) satisfied.
- Barrel `lib/koel_core.dart`, `pubspec.yaml`, `build.yaml` untouched (export sweep is Story 2.15). Generated `ag_ui_event.freezed.dart` is gitignored.

### File List

New:
- `packages/koel_core/lib/src/event/raw_event.dart`
- `packages/koel_core/lib/src/event/custom_event.dart`
- `packages/koel_core/test/event/raw_event_test.dart`
- `packages/koel_core/test/event/custom_event_test.dart`
- `packages/koel_core/test/event/full_event_sweep.jsonl`
- `packages/koel_core/test/event/full_event_sweep_test.dart`

Modified:
- `packages/koel_core/lib/src/event/ag_ui_event.dart` (2 `part` directives + closing dartdoc)
- `packages/koel_core/lib/src/event/event_deserializer.dart` (`RAW`/`CUSTOM` registry entries + dartdoc)
- `packages/koel_core/test/event/event_deserializer_test.dart` (26 → 28 keys + 2 dispatch cases)

Regenerated (gitignored): `packages/koel_core/lib/src/event/ag_ui_event.freezed.dart`

## Change Log

| Date | Change |
|------|--------|
| 2026-05-30 | Implemented Story 2.8: `RawEvent` + `CustomEvent` freezed subtypes + codecs; registry closed at 28 types; 28-line `full_event_sweep.jsonl` + sweep test; AC3 exhaustiveness-lint validated end-to-end on the real union. All ACs met; 428 tests green; analyze/format clean; new files 100% line coverage. Status → review. |
