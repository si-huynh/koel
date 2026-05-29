---
baseline_commit: e944807737f9cff85bc57bfa84efd5d49a93eefd
---

# Story 2.2: Sealed `AgUiEvent` root + `UnknownAgUiEvent` forward-compat fallback

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter/Dart developer,
I want `sealed class AgUiEvent` as the root union plus `UnknownAgUiEvent(type, rawJson)` as the forward-compat fallback, deserialized by a registry-driven dispatcher,
so that future AG-UI events deserialize into a typed surface that never crashes the SDK per FR-A6 and FC-1.

This is the **first story to extend the kernel union** that Story 2.1 stubbed. Story 2.1 deliberately landed `lib/src/event/ag_ui_event.dart` as a *subtype-less* sealed root so the package could analyze clean while `AbstractAgent.run() → Stream<AgUiEvent>` had a type to reference. This story turns that stub into a real, dispatchable union: it adds the first concrete subtype (`UnknownAgUiEvent`), the registry-driven deserializer that every later event-family story (2.5–2.8) plugs into, and the forward-compat guarantee that the SDK never throws on an unrecognized wire event.

**Scope reality check:** there are **no other concrete event subtypes yet** — `RUN_*`/`TEXT_MESSAGE_*` (2.5), `TOOL_CALL_*`/`STATE_*` (2.6), `REASONING_*`/`ACTIVITY_*` (2.7), `RAW`/`CUSTOM` + 28-type sweep (2.8) all come later. That means in *this* story the registry is **empty**, so the dispatcher routes **every** wire `type` to `UnknownAgUiEvent`. That is correct and testable: feed any `type` string, get a non-crashing `UnknownAgUiEvent`. The dispatcher is the seam later stories register into.

## Acceptance Criteria

**AC1 — sealed `AgUiEvent` root (expand, do not recreate)**
**Given** `koel_core/lib/src/event/ag_ui_event.dart`,
**When** I inspect it,
**Then** `sealed class AgUiEvent` is declared (Dart 3) with a `const` constructor,
**And** no concrete event subtypes are declared inline (subtypes live in their own files per the per-package layout in architecture),
**And** the file is the one already created by Story 2.1 — *expanded*, not replaced (keep/extend the existing dartdoc; remove the "no concrete subtypes yet" stub language now that `UnknownAgUiEvent` exists).

**AC2 — `UnknownAgUiEvent` forward-compat subtype**
**Given** `koel_core/lib/src/event/unknown_event.dart`,
**When** I inspect `UnknownAgUiEvent`,
**Then** it extends `AgUiEvent`, carries `final String type` + `final Map<String, dynamic> rawJson`,
**And** its `==`/`hashCode` use freezed-generated structural equality (deep equality over `rawJson` via `DeepCollectionEquality`, the same mechanism proven on `RunAgentInput.reasoningEcho` in Story 2.1).

**AC3 — registry-driven deserializer with forward-compat fallback (FR-A6 / FC-1)**
**Given** the event-deserializer dispatcher in `koel_core` (`lib/src/event/event_deserializer.dart`),
**When** it receives raw wire JSON whose `type` string is **not** in the current event registry (which, in this story, is *every* type — the registry is empty until 2.5+),
**Then** it returns `UnknownAgUiEvent(type: <the type string>, rawJson: <the raw map>)` **without throwing**,
**And** when the `type` key is missing or not a `String`, it still returns a non-crashing `UnknownAgUiEvent` (`type` falls back to `''`) rather than throwing,
**And** the registry is structured so later stories (2.5–2.8) register concrete subtypes by adding entries in **one** place (no mutable global state, no per-call registration side effects).

**AC4 — repo stays green; codegen produces the freezed part; nothing committed**
**Given** the workspace after this story lands,
**When** I run the toolchain,
**Then** `dart run build_runner build` in `packages/koel_core` produces `unknown_event.freezed.dart` next to source with no errors,
**And** `melos run analyze` exits 0 across the workspace (NFR-13),
**And** `melos run format:check` exits 0 (does not walk generated output — already handled by Story 2.1's `tool/format.sh`),
**And** no `*.freezed.dart` / `*.g.dart` are committed (they stay gitignored per convention §1; CI's `codegen-drift` gate from Story 2.1 verifies determinism).

> **Note on `onUnknownEvent`:** the epic's third AC clause ("`AgentSubscriber.onUnknownEvent` fires once when the pipeline routes it") is **explicitly deferred to Story 2.10** (subscriber bag) and Story 2.11 (pipeline). `AgentSubscriber` does **not exist yet**. Do **not** create it here. This story stops at "the dispatcher returns `UnknownAgUiEvent` and the pipeline *would* route it" — the callback wiring is 2.10's job.

## Tasks / Subtasks

- [x] **Task 1 — Expand the sealed `AgUiEvent` root (AC1)**
  - [x] Open the existing `packages/koel_core/lib/src/event/ag_ui_event.dart` (created by Story 2.1). **Do not recreate it** — Story 2.1's Completion Notes flag this as a cross-story handoff.
  - [x] Keep `sealed class AgUiEvent { const AgUiEvent(); }`. Update the dartdoc: drop the "this story (2.1) lands the sealed root only / no concrete subtypes" stub framing and replace with the contract-form doc for the live union (one-line summary + what it represents + that subtypes are exhaustive, `koel_lints`-enforced once consumers `switch`; cross-ref `[UnknownAgUiEvent]`). Keep the `sealed`-restricts-subtyping rationale.
  - [x] No standalone behavior test on the root itself (a sealed root with one subtype is exercised through `UnknownAgUiEvent` + the dispatcher tests). A trivial `expect(unknown, isA<AgUiEvent>())` assertion belongs in the `UnknownAgUiEvent` test.

- [x] **Task 2 — `UnknownAgUiEvent` freezed subtype (AC2)** — red → green → refactor
  - [x] RED: `test/event/unknown_event_test.dart` — assert (a) `const` construction with required `type` + `rawJson`; (b) `isA<AgUiEvent>()`; (c) **deep structural equality**: two instances with equal `type` and *distinct but content-equal* `rawJson` maps (including a nested map/list value) are `==` and share `hashCode`; (d) differing `type` **or** differing `rawJson` → `!=`; (e) `copyWith` updates one field, leaves the other identical. Confirm RED before implementing.
  - [x] GREEN: implement `lib/src/event/unknown_event.dart` using the freezed-3.x **"freezed subtype extends a hand-written sealed parent"** pattern (see Dev Notes "freezed 3.x: extending the sealed root" — this is the correctness trap of this story). Run `dart run build_runner build`; make tests pass.
  - [x] REFACTOR: contract-form dartdoc per convention §6 (what it represents, when to use / when not, that `rawJson` is the verbatim wire payload never inspected, cross-ref `[AgUiEvent]` and — as a doc-only forward pointer — `AgentSubscriber.onUnknownEvent` arriving in Story 2.10).

- [x] **Task 3 — Registry-driven deserializer dispatcher (AC3)** — red → green → refactor
  - [x] RED: `test/event/event_deserializer_test.dart` — assert (a) an arbitrary unknown `type` string → `UnknownAgUiEvent(type: <that>, rawJson: <the full input map>)`, no throw; (b) `rawJson` is the **entire** input map verbatim (not a copy stripped of `type`); (c) missing `type` key → `UnknownAgUiEvent(type: '', rawJson: <input>)`, no throw; (d) `type` present but non-`String` (e.g. an `int`) → non-crashing `UnknownAgUiEvent`. Confirm RED.
  - [x] GREEN: implement `lib/src/event/event_deserializer.dart`:
    - A registry: `const Map<String, AgUiEvent Function(Map<String, dynamic>)> eventTypeRegistry = {};` — **empty in this story.** Add a header comment documenting that stories 2.5–2.8 add entries here (one per wire `type` → its `fromJson` factory) and this is the single source of truth for FC-1's "current `koel_core` event registry".
    - A pure top-level function `AgUiEvent deserializeAgUiEvent(Map<String, dynamic> json)` that reads `json['type']`, and: if it's a `String` present in `eventTypeRegistry`, delegates to that factory; otherwise returns `UnknownAgUiEvent(type: <type as String, or '' if missing/non-String>, rawJson: json)`.
  - [x] REFACTOR: contract-form dartdoc on both `eventTypeRegistry` and `deserializeAgUiEvent` (FR-A6 / FC-1; "never throws on unrecognized wire data"; pointer that koel_http's SSE parser (Epic 4) consumes this, and that the registry grows in 2.5–2.8).

- [x] **Task 4 — Definition-of-done validation (AC4)**
  - [x] `cd packages/koel_core && dart run build_runner build` → exits 0, emits `unknown_event.freezed.dart` (and **no** `unknown_event.g.dart` — see Dev Notes "Serialization scope").
  - [x] `cd packages/koel_core && dart test` → all green (existing 14 + the new event tests).
  - [x] `melos run analyze` → exits 0 across the workspace (NFR-13).
  - [x] `melos run format:check` → exits 0 (and is not walking generated files — Story 2.1's `tool/format.sh` already excludes them).
  - [x] `git status` shows **no** generated files staged/tracked.
  - [x] **Do not** populate `lib/koel_core.dart` (barrel is frozen until Story 2.15). **Do not** add CI changes (Story 2.1 already made CI codegen-aware). **Do not** create `AgentSubscriber` (Story 2.10).
  - [x] Update File List + Completion Notes + Change Log; flag the cross-story handoff for 2.5–2.8 (register subtypes in `eventTypeRegistry`) and 2.10 (`onUnknownEvent` wiring).

## Dev Notes

### What this story is — and is not
- **Is:** the live sealed `AgUiEvent` union root (expanded from 2.1's stub), the first concrete subtype `UnknownAgUiEvent`, and the registry-driven deserializer that guarantees forward-compat (FR-A6 / FC-1).
- **Is not:** any of the 28 concrete event subtypes (`RUN_*`/`TEXT_MESSAGE_*` → 2.5; `TOOL_CALL_*`/`STATE_*`/`MESSAGES_SNAPSHOT` → 2.6; `REASONING_*`/`ACTIVITY_*` → 2.7; `RAW`/`CUSTOM` + the full 28-type sweep → 2.8). **Is not** `AgentSubscriber` (2.10), the 4-stage pipeline (2.11), the reducer (2.12), or the barrel/perf/coverage finalize (2.15). Do **not** stub `KoelError`, `JsonPatchOp`, `ChatState`, or any event subtype here — creating placeholders now invites churn (the same discipline Story 2.1 held).

### freezed 3.x: extending the sealed root (critical — this story's correctness trap)
Addendum A.1 writes `UnknownAgUiEvent` as a **hand-written** class:
```dart
class UnknownAgUiEvent extends AgUiEvent {
  final String type;
  final Map<String, dynamic> rawJson;
  const UnknownAgUiEvent({required this.type, required this.rawJson});
}
```
But AC2 requires **freezed-generated** structural equality. The two are reconciled by the freezed-3.x pattern for a freezed subtype that `extends` a hand-written sealed parent. The parent (`AgUiEvent`) stays a plain `sealed class` with a `const` constructor; the subtype is freezed **and** extends it via a **private constructor**:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

import 'ag_ui_event.dart';

part 'unknown_event.freezed.dart';

@freezed
abstract class UnknownAgUiEvent extends AgUiEvent with _$UnknownAgUiEvent {
  const UnknownAgUiEvent._() : super();          // ← required: lets the freezed class extend AgUiEvent

  const factory UnknownAgUiEvent({
    required String type,
    required Map<String, dynamic> rawJson,
  }) = _UnknownAgUiEvent;
}
```
- `abstract class … with _$UnknownAgUiEvent` is the freezed-3.x shape proven by `Message`/`ToolDefinition`/`RunAgentInput` in Story 2.1 (every freezed class is `abstract` or `sealed` in 3.x).
- The `const UnknownAgUiEvent._() : super();` private constructor is what makes `extends AgUiEvent` work under freezed. Without it the generated mixin can't satisfy the superclass's `const AgUiEvent()`. This is the analogue of 2.1's "`AbstractAgent` declaration trap" — **verify by running `build_runner` once, do not assume** (retro lesson A1).
- Deep equality on `rawJson: Map<String, dynamic>` falls out of freezed's `const DeepCollectionEquality()` — the *exact* mechanism that made byte-deep `reasoningEcho` equality pass in 2.1. Do not hand-write `==`/`hashCode`.

### Serialization scope (why `UnknownAgUiEvent` is freezed-only, no `*.g.dart`)
Do **not** give `UnknownAgUiEvent` a `fromJson`/`toJson` via `json_serializable`. Reason: the forward-compat contract is that `rawJson` **is** the verbatim wire event. A `json_serializable`-generated `toJson()` would emit `{"type": ..., "rawJson": {...}}` — a *wrapped* shape that is **not** the original wire payload, breaking the round-trip semantics the 28-type sweep (Story 2.8) will assert. So:
- `UnknownAgUiEvent` is **freezed-only** → generates `unknown_event.freezed.dart`, **no** `unknown_event.g.dart`. (Same freezed-only posture as `RunAgentInput` in 2.1.)
- It is **constructed by the dispatcher** (`deserializeAgUiEvent`) from `(type, rawJson)`, not by a `fromJson` factory.
- If a later story needs to re-emit an unknown event to the wire, the semantic is `event.rawJson` verbatim — there is no transformation. Don't add a wrapping `toJson` now.

### Dispatcher + registry design (the seam later stories depend on)
- **Home:** `koel_core`, not `koel_http`. FC-1 defines the check as "against the current **`koel_core`** event registry", and `koel_core` must own deserialization because the pipeline/reducer (Epic 2) operate without `koel_http`. The `SseParser` in `koel_http` (Epic 4, `lib/src/sse_parser.dart`) is a *consumer* of `deserializeAgUiEvent`, not a reimplementation.
- **Registry shape:** a single `const Map<String, AgUiEvent Function(Map<String, dynamic>)> eventTypeRegistry`. Each later story adds entries (`'RUN_STARTED': RunStartedEvent.fromJson`, …) to this one map. A `const` map (single source of truth, edited at authoring time) is deliberately chosen over a mutable global with runtime `register(...)` calls — the project's principles forbid hidden mutable state and "design for what users can't misuse". No `late`, no top-level `var`, no init-order coupling.
- **In this story the map is empty** → `deserializeAgUiEvent` always falls through to `UnknownAgUiEvent`. That is the correct, testable behavior; AC3 is satisfiable with an empty registry.
- **Defensive fallback:** missing `type`, or `type` not a `String`, must **not** throw (FR-A6: "SDK never crashes on forward-compat events"). Coerce to `type: ''` and still return `UnknownAgUiEvent(rawJson: json)`. The malformed-but-present case is a forward-compat scenario, not a protocol error — `ProtocolError` classification (Story 2.3) and the verify-stage drop rules (Story 2.11) are out of scope here.

### Cross-story handoffs to record in Completion Notes
- **2.5–2.8:** add concrete subtypes in their own files under `lib/src/event/` and register each wire `type` → `Type.fromJson` in `eventTypeRegistry`. The dispatcher needs no further change.
- **2.8:** the full 28-event sweep validates round-trip for every subtype and asserts the registry has no orphans; it also validates `exhaustive_switch_must_have_default` end-to-end. `UnknownAgUiEvent` is the union member that lets consumer `switch`es stay non-crashing across minor bumps (FC-2).
- **2.10:** `AgentSubscriber.onUnknownEvent(UnknownAgUiEvent e)` is defined and wired to fire when the pipeline routes an `UnknownAgUiEvent`. Not this story.

### Project Structure Notes
- Files land exactly at the epic-specified paths: `lib/src/event/ag_ui_event.dart` (expand), `lib/src/event/unknown_event.dart` (new), `lib/src/event/event_deserializer.dart` (new). Tests mirror path-for-path under `test/event/` (convention §1 / §6).
- **Naming:** `snake_case.dart` files; sealed-subtype types end in their family suffix (`*Event`); `UpperCamelCase` types; `lowerCamelCase` members (convention §1). No `print`, no silent `catch (_) {}`.
- **Barrel deferred:** do **not** export to `lib/koel_core.dart` — it is the frozen 1.x contract finalized in Story 2.15 (where the `dart_apitool` baseline is taken). Tests import `src/` paths directly (legal for *in-package* tests; the `lib/src/` privacy rule only bans *cross-package* `src/` imports — convention §2).
- **Existing scaffold (do not regress):** `koel_core/pubspec.yaml` already carries `freezed_annotation: ^3.1.0`, `json_annotation: ^4.12.0`, dev-deps `freezed: 3.2.6-dev.1` + `json_serializable: ^6.8.0` + `build_runner` + `test` + path `koel_lints:`. `build.yaml` already sets `json_serializable.field_rename: none`. **No pubspec or build.yaml changes are needed** for this story (no new deps; `UnknownAgUiEvent` uses only freezed). The workspace-root `analysis_options.yaml` enables the `koel_lints` plugin for all members; `koel_core` carries no local `analysis_options.yaml`.

### Toolchain (carried from Story 2.1 — unchanged, do not modify)
- freezed `3.2.6-dev.1` + `freezed_annotation ^3.1.0`; analyzer pinned to 12 across the workspace via the analyzer-12 stopgap (SCP-2026-05-29-B / architecture D2 + D3) so freezed and `analysis_server_plugin 0.3.14` coexist in one pub-workspace resolution. Dart 3.12 / Flutter 3.44 (`.tool-versions`).
- CI is already codegen-aware (Story 2.1, retro D1/D2): `ci.yml` runs `melos run build` before `analyze`/`test`; `codegen-drift.yml` is a real determinism gate; `format:check` excludes generated output. **This story adds no CI work.**

### How to run / coverage (carried from Story 2.1)
- Run tests via `dart test` directly in `packages/koel_core` (`melos run test` remains a Story 2.15 stub). CI gates this story via `analyze` + `build` + `codegen-drift`, not the `test` step — note this in Completion Notes.
- Coverage ≥90% (NFR-12) is **not** an AC here (it first gates in 2.5/2.6, finalized in 2.15). Still write thorough tests; generated files are excluded from coverage by the 2.15 mechanism.

### References
- [Source: _bmad-output/planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md#Story 2.2] — story statement + ACs (authoritative for scope).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#A.1 koel_core (lines 109–166)] — canonical `sealed class AgUiEvent { const AgUiEvent(); }` root and `UnknownAgUiEvent extends AgUiEvent { final String type; final Map<String, dynamic> rawJson; const UnknownAgUiEvent({required this.type, required this.rawJson}); }` (hand-written form; AC2 upgrades it to freezed-generated equality — see Dev Notes).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md#§11 Forward-compat policy] — FC-1 (unknown events → `UnknownAgUiEvent(type, rawJson)`, surfaced via `onUnknownEvent`, SDK never crashes); FC-2 (sealed-union evolution safe only because `koel_lints` enforces `default:`).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md#§8 Group A] — FR-A6 forward-compat fallback; FR-A10 `AgentSubscriber.onUnknownEvent` (deferred to Story 2.10).
- [Source: _bmad-output/planning-artifacts/architecture.md#Per-package layout: koel_core] — `lib/src/event/` directory map: `ag_ui_event.dart` (sealed root), per-family subtype files, `unknown_event.dart` (F-A6 fallback).
- [Source: _bmad-output/planning-artifacts/architecture.md#3. Type & data conventions] — freezed for crossing-boundary immutables; `const` everywhere; camelCase wire keys; `field_rename: none`; `copyWith`-only mutation.
- [Source: _bmad-output/planning-artifacts/architecture.md#1. Naming & file layout] — snake_case files, `*Event` subtype suffix, generated colocated + gitignored + CI-verified, test mirroring.
- [Source: _bmad-output/planning-artifacts/architecture.md#6. Documentation & testing] — `///` contract-form dartdoc; `package:test`; one top-level `group(<ClassName>)` per file.
- [Source: _bmad-output/planning-artifacts/architecture.md#D2 / #D3] — freezed `3.2.6-dev.1` + analyzer-12 stopgap (SCP-2026-05-29-B); `analysis_server_plugin 0.3.14`.
- [Source: _bmad-output/implementation-artifacts/2-1-foundation-contracts.md] — the just-completed predecessor: freezed-3.x `abstract class … with _$X` idiom, `AgUiEvent` stub + "expand, don't recreate" handoff, `DeepCollectionEquality` deep-equality proof, freezed-only (no `*.g.dart`) posture for non-wire-round-trip types, codegen-aware CI already wired, barrel/coverage deferral.
- [Source: packages/koel_core/lib/src/event/ag_ui_event.dart] — the existing sealed-root stub to expand (not recreate).
- [Source: packages/koel_core/lib/src/message/message.dart, packages/koel_core/pubspec.yaml, packages/koel_core/build.yaml] — established freezed-3.x idiom + current dep/codegen config to extend (no changes needed).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (1M) via Claude Code + `agent-flutter-engineer` skill (implement mode).

### Debug Log References

- `dart run build_runner build` (koel_core) → 1 output, no errors.
- `dart test` (koel_core) → 25 passed (14 prior + 11 new: 6 `unknown_event` + 5 `event_deserializer`).
- `melos run analyze` → 0 issues across all 11 packages (NFR-13).
- `melos run format:check` → 0 changed (after `melos run format` reflowed the two new test files to 80 cols).
- `git check-ignore … ag_ui_event.freezed.dart` → gitignored; `git ls-files '*.freezed.dart' '*.g.dart'` → none tracked.

### Completion Notes List

Implemented Tasks 1–4; all ACs satisfied. Two findings forced design decisions the story under-specified — both verified empirically (retro lesson A1: "verify by running build_runner, do not assume"), both pattern-setting for Stories 2.5–2.8.

**① Sealed-union-across-files needs classic parts, not `import` (AC1+AC2 reconciliation, and the real "correctness trap").**
The story's Dev Notes snippet writes `unknown_event.dart` with `import 'ag_ui_event.dart';` + `extends AgUiEvent`. Dart rejects this: a `sealed` type can only be extended **within its own library**, and an importing file is a separate library (`invalid_use_of_type_outside_library` — confirmed by analyzer + `dart analyze`). Enhanced parts (a part file carrying its own `import`/`part` directives) would let each subtype keep an independent `*.freezed.dart`, but the analyzer-12 pin rejects it (`non_part_of_directive_in_part`) and enabling a language experiment is out of scope ("do not modify the toolchain"). The only arrangement satisfying **AC1 (`sealed`)** + **AC2 (separate `unknown_event.dart`)** together is the classic single-library/multi-part layout:
- `ag_ui_event.dart` is the **library root**: holds `import 'package:freezed_annotation'`, `part 'unknown_event.dart'`, `part 'ag_ui_event.freezed.dart'`, and the `sealed class AgUiEvent`.
- `unknown_event.dart` is a pure `part of 'ag_ui_event.dart'` (the only directive a part may carry here) defining `UnknownAgUiEvent`.

**Deviation from AC4 wording:** freezed emits one shared part per **library root**, so the generated file is **`ag_ui_event.freezed.dart`**, not `unknown_event.freezed.dart` as AC4 literally states. The *intent* of AC4 is fully met (freezed part emitted, no errors, **no `*.g.dart`**, nothing committed). The filename is a mechanical consequence of Dart's sealed rule + classic-parts freezed generation, not a scope change.
**Handoff for 2.5–2.8:** every concrete subtype file (`run_events.dart`, `tool_call_events.dart`, …) is a `part of 'ag_ui_event.dart'` and adds its `part '<file>.dart'` directive to `ag_ui_event.dart`; all generated freezed code accrues into the single `ag_ui_event.freezed.dart`. Subtype files contain **only** `part of` — shared imports live in the root.

**② `rawJson` is value-verbatim, not reference-identical (AC3 test contract).**
freezed's default `makeCollectionsUnmodifiable: true` wraps a `Map` field in an unmodifiable view at construction, so `deserializeAgUiEvent(json).rawJson` is **deep-equal** to `json` but not `identical` to it. The RED test initially asserted `same(json)` and failed; corrected to `equals(json)` — which is the actual forward-compat contract (no key stripped, no transform; the wire payload round-trips at the value level) and additionally gives us an immutable held payload, matching the project's immutability principle. The dispatcher passes `json` straight through; it performs no copy/strip itself.

**Discipline held:** barrel `lib/koel_core.dart` untouched (frozen until 2.15); no CI changes (codegen-aware since 2.1); `AgentSubscriber`/`onUnknownEvent` **not** created (deferred to 2.10) — left as a doc-only forward pointer in `UnknownAgUiEvent`'s dartdoc; no `KoelError`/`JsonPatchOp`/`ChatState`/event-subtype placeholders. Registry is a `const` map (no mutable global, no runtime `register`).

**Cross-story handoffs:**
- **2.5–2.8:** add subtype files as `part of 'ag_ui_event.dart'` (+ `part` directive in the root) and register each wire `type` → `Subtype.fromJson` in `eventTypeRegistry`. `deserializeAgUiEvent` needs no change.
- **2.8:** 28-type round-trip sweep + registry-no-orphans assertion; `UnknownAgUiEvent` is the union member keeping consumer `switch`es non-crashing across minor bumps (FC-2).
- **2.10:** define and wire `AgentSubscriber.onUnknownEvent(UnknownAgUiEvent)` to fire when the pipeline routes an `UnknownAgUiEvent`.

### File List

- `packages/koel_core/lib/src/event/ag_ui_event.dart` — modified (expanded dartdoc for the live union; became the library root via `part 'unknown_event.dart'` + `part 'ag_ui_event.freezed.dart'`; added `freezed_annotation` import).
- `packages/koel_core/lib/src/event/unknown_event.dart` — new (`part of 'ag_ui_event.dart'`; freezed `UnknownAgUiEvent extends AgUiEvent`).
- `packages/koel_core/lib/src/event/event_deserializer.dart` — new (`const eventTypeRegistry` + `deserializeAgUiEvent`).
- `packages/koel_core/test/event/unknown_event_test.dart` — new (6 tests).
- `packages/koel_core/test/event/event_deserializer_test.dart` — new (5 tests).
- `packages/koel_core/lib/src/event/ag_ui_event.freezed.dart` — generated, gitignored, **not committed** (supersedes the transient `unknown_event.freezed.dart` from the import-based first attempt).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — modified (2-2 → in-progress → review).

### Change Log

- 2026-05-29 — Story 2.2 implemented: expanded sealed `AgUiEvent` root, added `UnknownAgUiEvent` freezed forward-compat subtype, and the `const`-registry-driven `deserializeAgUiEvent` dispatcher (FR-A6 / FC-1). Sealed union split across files via classic single-library parts (enhanced parts unavailable under analyzer-12); freezed therefore emits library-level `ag_ui_event.freezed.dart` rather than `unknown_event.freezed.dart`. 25/25 tests green, analyze/format clean, no generated files committed. Status → review.

## Review Findings

_Code review 2026-05-29 (3 layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor). Acceptance Auditor: **zero AC violations** — all of AC1–AC4 met; the AC4 `unknown_event.freezed.dart`→`ag_ui_event.freezed.dart` filename departure is a sound, forced, documented deviation. Triage: 2 decision-needed, 0 patch, 1 defer, 11 dismissed._

- [x] [Review][Patch] Document caller-ownership contract on `deserializeAgUiEvent` + `rawJson` [packages/koel_core/lib/src/event/event_deserializer.dart:30] — `deserializeAgUiEvent` passes `json` straight into the event by reference; freezed wraps only the **top-level** map in `EqualUnmodifiableMapView` (`ag_ui_event.freezed.dart:215`), leaving nested maps/lists mutable and shared with the caller's input. A consumer that retains the decoded map and mutates `json['payload']['x']`, or reaches through `event.rawJson['payload']['x'] = …`, silently mutates a "held untouched … byte-for-byte" value object and corrupts its cached structural equality. **Resolution (decision #1 → option 1):** keep zero-copy (no per-event deep-copy cost on budget phones; the Epic-4 SSE pipeline decodes a fresh map per event so the alias is benign), and document a caller-ownership contract — "do not retain or mutate the map passed to `deserializeAgUiEvent`; nested values are shared" — on the function dartdoc and the `rawJson` dartdoc. Dartdoc-only, zero behaviour change. (Source: blind+edge)
- [x] [Review][Defer] Registered-factory invocation is unguarded — `event_deserializer.dart:34` `return factory(json);` has no try/catch and no null-check. Cannot fire in this story (registry is empty) but it sets the contract Stories 2.5–2.8 plug into: once a registered `fromJson` throws on a malformed-but-present payload, `deserializeAgUiEvent` throws — breaking FR-A6's "SDK never crashes on wire data" for the **known**-type path. **Resolution (decision #2 → option 1):** dispatcher stays strict; malformed-registered-payload handling is delegated to the Story 2.11 verify stage (+ `ProtocolError`, Story 2.3) per Dev Notes scope. Recorded as a 2.5/2.11 handoff. — deferred. Reason: per Dev Notes, malformed-but-present payload classification belongs to the verify stage (2.11) + `ProtocolError` (2.3), not the dispatcher. (Source: edge)
- [x] [Review][Defer] `deserializeAgUiEvent`'s non-null `Map` signature pushes the null/non-`Map` top-level case onto the caller — `event_deserializer.dart:30`. `jsonDecode` of an empty SSE data line / `"null"` / a JSON array yields `null` or a non-`Map`, and the `as Map<String, dynamic>` cast at the call site (the Epic-4 `koel_http` SSE parser, which does not exist yet) throws `TypeError` before this function runs. The "never throws" contract holds within the declared input type; the gap lives in unwritten Epic-4 code. — deferred to the Epic 4 SSE-parser story. (Source: blind+edge)
