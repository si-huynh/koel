---
baseline_commit: 7ac485ecbf7a87deed40ebf394db966fe2efdbcc
---

# Story 2.1: Foundation contracts — `AbstractAgent` SPI + `RunAgentInput` + `ToolDefinition` + `Message`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter/Dart developer,
I want the irreducible kernel contracts (`AbstractAgent.run() → Stream<AgUiEvent>`, `RunAgentInput`, `ToolDefinition`, `Message`) defined as freezed-immutable types with the SPI marker,
so that every backend bridge and every consumer surface compiles against a stable foundation per FR-A1.

This is the **first real-code story in the repo** and the **first to introduce `freezed` / `build_runner` codegen**. Two consequences fall on this story specifically (assigned by the Epic 1 retrospective, action items D1 + D2): the CI codegen-drift gate and `format:check` must be made codegen-aware, and `ci.yml` must run codegen before `analyze`/`test` or every gate goes red. Treat the CI tasks as part of the story's done-ness, not optional polish.

## Acceptance Criteria

**AC1 — `AbstractAgent` SPI**
**Given** `koel_core/lib/src/agent/abstract_agent.dart`,
**When** I open it,
**Then** `AbstractAgent` is declared as an interface-class SPI with a single method `Stream<AgUiEvent> run(RunAgentInput input)`,
**And** the dartdoc explicitly states: "Adapters NEVER throw `KoelError` — they emit `RunErrorEvent`. The `interface class` marker prevents accidental instance construction; consumers reach for `KoelClient` instead."

**AC2 — `RunAgentInput`**
**Given** `koel_core/lib/src/input/run_agent_input.dart`,
**When** I inspect the freezed type,
**Then** it carries fields `threadId`, `runId`, `state`, `messages`, `tools`, `context`, `forwardedProps`, and `reasoningEcho: Map<String, Uint8List>?` with a `const` constructor,
**And** all collection fields use `List`/`Map` types whose freezed-generated `==` produces deep equality (including byte-deep equality on `reasoningEcho` values).

**AC3 — `ToolDefinition`**
**Given** `koel_core/lib/src/tool/tool_definition.dart`,
**When** I inspect it,
**Then** `ToolDefinition` is freezed with `name`, `description`, and `parameters: Map<String, dynamic>` (JSON Schema in v1 per OQ-Tool-Param-DSL).

**AC4 — `Message` + `MessageRole`**
**Given** `koel_core/lib/src/message/message.dart`,
**When** I inspect it,
**Then** `Message` is a freezed-immutable type carrying `id: String`, `role: MessageRole` (enum: `user`, `assistant`, `system`, `tool`), `content: String`, `timestamp: DateTime`, plus optional `toolCallId: String?` and `name: String?` per the AG-UI `Message` shape,
**And** `Message` is the element type used by `RunAgentInput.messages: List<Message>` (and later by `ChatState.messages` in Story 2.12),
**And** the freezed-generated `==` produces deep equality across all fields including `timestamp`.

**AC5 — codegen pipeline**
**Given** `koel_core/build.yaml`,
**When** I inspect the build_runner configuration,
**Then** it configures `freezed` (per D2, **SCP-2026-05-29-B**: `3.2.6-dev.1`) and `json_serializable` with `field_rename: none` per architecture convention §3,
**And** running `dart run build_runner build` produces `*.freezed.dart` and `*.g.dart` next to source files with no errors.

**AC6 — repo stays green end-to-end (retro D1 + D2)**
**Given** the workspace after this story lands,
**When** CI runs,
**Then** `melos run analyze` exits 0 (NFR-13) — which requires generated code to exist, so `ci.yml` runs `melos run build` before `analyze`/`test`,
**And** `melos run format:check` does not fail on generated output (generated paths excluded),
**And** the `codegen-drift` workflow actually detects drift now that generated output is gitignored (no longer a silent no-op),
**And** no `*.freezed.dart` / `*.g.dart` files are committed (they remain gitignored per convention §1).

## Tasks / Subtasks

- [x] **Task 1 — Codegen toolchain for `koel_core` (AC5)** _(amended by SCP-2026-05-29-B: analyzer-12 stopgap)_
  - [x] **Workspace analyzer-12 pin (SCP-2026-05-29-B prerequisite).** In `packages/koel_lints/pubspec.yaml` set `analysis_server_plugin: 0.3.14`, `analyzer: ^12.0.0`, `analyzer_testing: 0.2.5` (rule source unchanged — analyzer 12/13 API-compatible). This lets `freezed` (which caps `analyzer` below 13) share the single pub-workspace resolution. After bootstrap, run `dart test` in `packages/koel_lints` and confirm it stays green on analyzer 12.
  - [x] In `packages/koel_core/pubspec.yaml`, add `dependencies`: `freezed_annotation: ^3.1.0` (pairs with freezed 3.2.6-dev), `json_annotation: ^4.12.0` (json_serializable 6.14 requires `>=4.12.0`). Add `dev_dependencies`: `freezed: 3.2.6-dev.1` (D2, SCP-2026-05-29-B stopgap), `json_serializable: ^6.x`, `build_runner: ^2.x`, `test: ^1.x`. Keep the existing `koel_lints:` path dev-dep and `resolution: workspace`.
  - [x] Create `packages/koel_core/build.yaml` configuring the `freezed` builder and the `json_serializable` builder with `field_rename: none` (convention §3). Do **not** invent options that don't exist in freezed 3.x — see Dev Notes "freezed 3.x reality check".
  - [x] Run `melos bootstrap` (or `dart pub get` at root) and confirm `freezed 3.2.6-dev.1` + `analyzer 12.1.0` + `analysis_server_plugin 0.3.14` resolve together on the pinned Dart 3.12 / Flutter 3.44 toolchain (`.tool-versions`). **Retro lesson A1:** touch the real toolchain before assuming the API — freezed 3.x is a breaking change from the 2.x snippets in Addendum A.1, and the analyzer-12 stopgap (SCP-2026-05-29-B) is exactly what A1 warns about.
- [x] **Task 2 — Minimal `sealed class AgUiEvent` root to unblock `AbstractAgent` (AC1 prerequisite)**
  - [x] Create `packages/koel_core/lib/src/event/ag_ui_event.dart` with `sealed class AgUiEvent { const AgUiEvent(); }` and **no concrete subtypes** (subtypes + `UnknownAgUiEvent` + the deserializer dispatcher are Story 2.2's scope).
  - [x] Add a one-line dartdoc noting this is the union root, expanded in Story 2.2.
  - [x] No standalone test here — a subtype-less sealed class has no behavior to exercise; Story 2.2 brings its tests. (Document this in the file header and Completion Notes.)
- [x] **Task 3 — `Message` + `MessageRole` (AC4)** — red → green → refactor
  - [x] RED: `test/message/message_test.dart` — assert (a) two `Message`s with equal field values (including equal `timestamp`) are `==` and share `hashCode`; (b) differing in any single field (incl. `timestamp`) are `!=`; (c) `MessageRole` has exactly `{user, assistant, system, tool}`; (d) optional `toolCallId`/`name` default to null; (e) `Message.fromJson(m.toJson())` round-trips structurally-equal; (f) `copyWith` updates one field and leaves others identical. Confirm RED before implementing.
  - [x] GREEN: implement `lib/src/message/message.dart` — `enum MessageRole { user, assistant, system, tool }` + `@freezed abstract class Message with _$Message` (freezed 3.x syntax — see Dev Notes), with a `Message.fromJson` factory so `message.g.dart` is generated. Run `dart run build_runner build --delete-conflicting-outputs`; make tests pass.
  - [x] REFACTOR: contract-form dartdoc on `Message` + `MessageRole` per convention §6.
- [x] **Task 4 — `ToolDefinition` (AC3)** — red → green → refactor
  - [x] RED: `test/tool/tool_definition_test.dart` — deep equality (including nested `parameters` Map), `const` construction, `parameters` defaulting to `{}`, and `fromJson`/`toJson` round-trip. Confirm RED.
  - [x] GREEN: `lib/src/tool/tool_definition.dart` — `@freezed abstract class ToolDefinition with _$ToolDefinition` carrying `name`, `description`, `@Default({}) Map<String, dynamic> parameters`, plus a `fromJson` factory (generates `tool_definition.g.dart`). Build + pass.
  - [x] REFACTOR: contract dartdoc; note `parameters` is JSON Schema (OQ-Tool-Param-DSL).
- [x] **Task 5 — `RunAgentInput` (AC2)** — red → green → refactor
  - [x] RED: `test/input/run_agent_input_test.dart` — assert (a) `const` construction with required `threadId`/`runId` and defaulted empty collections; (b) deep equality across `state`/`messages`/`tools`/`context`/`forwardedProps`; (c) **byte-deep equality on `reasoningEcho`**: two inputs whose `reasoningEcho` maps hold distinct `Uint8List` instances with identical bytes are `==`; differing bytes are `!=`; (d) `copyWith`. Confirm RED.
  - [x] GREEN: `lib/src/input/run_agent_input.dart` — `import 'dart:typed_data';` + `@freezed abstract class RunAgentInput with _$RunAgentInput` with fields per Addendum A.1; `threadId`/`runId` required, collections `@Default(...)`, `reasoningEcho: Map<String, Uint8List>?` optional. **No `fromJson`/`toJson` in this story** — JSON wire serialization (which needs a base64 `Uint8List` converter) is deferred to the transport story (Epic 4) that actually posts it. Build + pass.
  - [x] REFACTOR: contract dartdoc; document `reasoningEcho` semantics (opaque blobs echoed verbatim).
- [x] **Task 6 — `AbstractAgent` SPI (AC1)** — green → test
  - [x] GREEN: `lib/src/agent/abstract_agent.dart` — declare `abstract interface class AbstractAgent { Stream<AgUiEvent> run(RunAgentInput input); }` with the **exact** dartdoc text from AC1. **Use `abstract interface class`, not bare `interface class`** — see Dev Notes "AbstractAgent declaration trap". Import `ag_ui_event.dart` + `run_agent_input.dart`.
  - [x] TEST: `test/agent/abstract_agent_test.dart` — define a private test double `class _FakeAgent implements AbstractAgent` whose `run` returns an empty `Stream<AgUiEvent>` (e.g. `Stream.empty()`); assert it satisfies the contract (`run` returns a `Stream<AgUiEvent>`, the subscription completes). This proves the SPI is implementable and keeps coverage on the public surface.
- [x] **Task 7 — Make CI codegen-aware (AC6; retro D1 + D2)**
  - [x] `.github/workflows/ci.yml`: insert `- run: melos run build` **after** `melos bootstrap` and **before** `melos run analyze`. (Without generated code, `dart analyze` errors on `part '*.freezed.dart'` and `_$Type` references → main goes red. This is the single most important CI change.)
  - [x] `.github/workflows/codegen-drift.yml` (retro **D1**): make the gate actually detect drift even though `*.g.dart`/`*.freezed.dart` are gitignored. Recommended: after `melos run build`, `git add --force` the generated globs, run `melos run build` again, then `git diff --cached --exit-code` (detects non-deterministic / stale codegen). Alternative per retro: `git status --porcelain` over the untracked generated paths. Either way, prove the gate fails on a deliberate drift and passes when clean.
  - [x] `format:check` (retro **D2**): exclude generated paths so build_runner output can't cause a spurious gate failure. Update the `format:check` melos script in the root `pubspec.yaml` to format only hand-written Dart (e.g. filter out `*.g.dart`/`*.freezed.dart`/`.dart_tool`). Keep `format` (write mode) consistent.
  - [x] Do **not** wire `melos run test` to run real tests here — that script is explicitly owned by Story 2.15. For this story, tests are verified locally via `dart test` in `packages/koel_core` (see Dev Notes "How to run tests").
- [x] **Task 8 — Definition-of-done validation (AC5 + AC6)**
  - [x] `cd packages/koel_core && dart run build_runner build` → exits 0, emits `message.freezed.dart` + `message.g.dart` + `tool_definition.freezed.dart` + `tool_definition.g.dart` + `run_agent_input.freezed.dart`. (Note: `--delete-conflicting-outputs` is removed / a no-op in the current build_runner — omit it.)
  - [x] `cd packages/koel_core && dart test` → all green.
  - [x] `melos run analyze` → exits 0 across the workspace (NFR-13).
  - [x] `melos run format:check` → exits 0 (and is not walking generated files).
  - [x] `git status` shows **no** generated files staged/tracked (confirm `.gitignore` still excludes them).
  - [x] Update File List + Completion Notes + Change Log.

## Dev Notes

### What this story is — and is not
- **Is:** the four irreducible kernel contracts + the codegen pipeline that the rest of Epic 2 builds on, plus the CI changes that keep the repo green once codegen exists.
- **Is not:** `AgUiEvent` subtypes (2.2), `KoelError` (2.3), JSON Patch (2.4), reducer/`ChatState` (2.12), `KoelClient`/`ChatSession` (2.14), barrel finalization + perf benches + coverage gate (2.15). Do **not** create `ToolCall`, `KoelError`, `ChatState`, or any event subtype here — they belong to later stories and creating stubs now invites churn.

### freezed 3.x reality check (critical — prevents a non-compiling copy-paste)
Addendum A.1 shows `class ChatState with _$ChatState { const factory ChatState(...) = _ChatState; }` — that is **freezed 2.x syntax**. Architecture **D2 pins `freezed: 3.2.6-dev.1`** (SCP-2026-05-29-B stopgap; still freezed 3.x), and freezed 3.x's headline breaking change is: **every freezed class must be declared `abstract` (single-constructor data classes) or `sealed` (unions).** Use:

```dart
import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';            // only when the type has fromJson/toJson

enum MessageRole { user, assistant, system, tool }

@freezed
abstract class Message with _$Message {        // ← `abstract`, not bare `class`
  const factory Message({
    required String id,
    required MessageRole role,
    required String content,
    required DateTime timestamp,
    String? toolCallId,
    String? name,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);
}
```
- Do not hand-write `==`/`hashCode`/`copyWith` — freezed generates structural equality using `const DeepCollectionEquality()`, which is what makes the deep-equality ACs pass (it recurses into `List`/`Map`, and `Uint8List` is an `Iterable<int>` so byte-deep equality on `reasoningEcho` falls out for free).
- `DateTime` equality in `Message`: freezed compares with `==`, which compares instants — distinct `DateTime` instances at the same instant are equal (satisfies AC4 "deep equality including timestamp").
- **Verify the exact freezed 3.x `build.yaml` option names by running `build_runner` once** rather than guessing (retro lesson A1). Minimal `build.yaml` is enough; `field_rename: none` under the `json_serializable` builder is the one option AC5 requires.

### `AbstractAgent` declaration trap (correctness over verbatim AC)
AC1 / Addendum A.1 write `interface class AbstractAgent { Stream<AgUiEvent> run(...); }`. A **bare** `interface class` is *concrete*, so a body-less `run` method does not compile ("missing concrete implementation"), and `interface class` alone does **not** prevent construction — contradicting the dartdoc claim. The correct declaration is **`abstract interface class AbstractAgent`**: `abstract` permits the body-less method and genuinely prevents construction; `interface` restricts subtyping to `implements` (the SPI contract). This still satisfies "declared as an interface-class SPI". Use `abstract interface class` and keep the AC1 dartdoc verbatim.

### `AgUiEvent` forward-reference (why Task 2 exists)
`AbstractAgent.run()` returns `Stream<AgUiEvent>`, but `AgUiEvent` is formally Story 2.2's deliverable. The package will not `analyze` clean (AC6) without it. Resolution: Task 2 lands a **minimal `sealed class AgUiEvent` root only** (const ctor, zero subtypes). Story 2.2 then expands it (adds `UnknownAgUiEvent`, the per-family subtypes live in their own files, and the deserializer dispatcher). When you start 2.2, that file will already exist — expand it, do not recreate it. Flag this cross-story handoff in Completion Notes.

### Serialization scope
- `Message` and `ToolDefinition` get `fromJson`/`toJson` (clean shapes; this is also what makes `*.g.dart` generation real for AC5). They are wire types reused everywhere.
- `RunAgentInput` is freezed-only in this story. Its `reasoningEcho: Map<String, Uint8List>?` needs a base64 `JsonConverter` for wire serialization; that converter + `RunAgentInput.toJson` land with the transport that posts it (Epic 4 `koel_http`), not here. Adding them now would be speculative scope.

### CI / codegen infra (retro action items D1 + D2 — owned by this story)
Source: `_bmad-output/implementation-artifacts/epic-1-retro-2026-05-29.md` (Discoveries D1/D2, Actions #2/#3, owner Amelia/Story 2.1).
- **Current `.gitignore` (root)** excludes `*.g.dart`, `*.freezed.dart`, `*.mocks.dart` repo-wide — keep this (convention §1: gitignore + CI-verify, never commit generated).
- **D1 — codegen-drift is a silent no-op today.** `codegen-drift.yml` runs `melos run build` then `git diff --exit-code`; `git diff` only inspects tracked files, and generated files are untracked, so it can never fail. Fix per Task 7 (force-add + rebuild + `git diff --cached`, or `git status --porcelain`).
- **D2 — `format:check` walks generated files.** Once codegen lands in `lib/`, `dart format ... .` formats `*.freezed.dart`/`*.g.dart`; usually format-stable but not guaranteed. Exclude generated paths in the `format:check` script.
- **`ci.yml` ordering (not in the retro, but required):** `ci.yml` runs `analyze`/`test` with **no** prior `melos run build`. `dart analyze` needs the generated parts to exist or it errors. Insert `melos run build` before `analyze`. Without this, the very first PR carrying freezed turns main red.

### How to run tests (this story)
`melos run test` is a stub (`dart --version`) until Story 2.15 wires the real aggregation (Dart-vs-Flutter split + coverage + perf). For 2.1, run `dart test` directly in `packages/koel_core`. CI gates this story via `analyze` + `build` + `codegen-drift`, not via the `test` step — call this out in Completion Notes so the reviewer knows tests were verified locally, by design.

### Coverage
Coverage ≥90% (NFR-12) is **not** an AC for 2.1 (it first gates in 2.5/2.6 and is finalized in 2.15); the `test:coverage` melos script is also a 2.15 stub. Still, write thorough tests — generated files (`*.g.dart`/`*.freezed.dart`) are excluded from coverage via the per-package mechanism (G-6) that 2.15 wires, so hand-written code carries the number.

### Project Structure Notes
- Files land exactly at the epic-specified paths: `lib/src/agent/abstract_agent.dart`, `lib/src/input/run_agent_input.dart`, `lib/src/tool/tool_definition.dart`, `lib/src/message/message.dart`, `lib/src/event/ag_ui_event.dart`. Tests mirror path-for-path under `test/` (convention §1 / §6).
- **Variance:** the architecture's `koel_core` layout (architecture.md §"Per-package layout") omits a `message/` directory, but Epic 2 AC4 mandates `lib/src/message/message.dart`. Follow the epic — `Message` needs a home and is referenced by both `RunAgentInput` and (later) `ChatState`. This is a documented additive variance, not a conflict.
- **Barrel deferred:** do **not** populate `lib/koel_core.dart` yet. The barrel is the frozen 1.x contract finalized in Story 2.15 (where the `dart_apitool` baseline is taken). This story's tests import `src/` paths directly — legal for *in-package* tests; the `lib/src/` privacy rule (convention §2) only bans *cross-package* `src/` imports.
- Naming: `snake_case.dart` files; `UpperCamelCase` types; `lowerCamelCase` members (convention §1). No `print`, no silent `catch (_) {}` (none expected in this story — pure data + SPI).
- Existing scaffold (do not regress): `koel_core/pubspec.yaml` is `version: 0.0.1`, `publish_to: none`, `sdk: ">=3.11.0 <4.0.0"`, `resolution: workspace`, dev-dep `koel_lints:` (path via root). Workspace-root `analysis_options.yaml` already enables the `koel_lints` plugin for all members — `koel_core` carries **no** local `analysis_options.yaml` (it inherits root; a member-level `plugins:` is rejected by the analyzer, per Story 1.7).

### References
- [Source: _bmad-output/planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md#Story 2.1] — story statement + ACs (authoritative for scope).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#A.1 koel_core] — canonical type signatures for `AbstractAgent`, `RunAgentInput`, `ToolDefinition`, `Message`/`MessageRole`, `AgUiEvent` root.
- [Source: _bmad-output/planning-artifacts/architecture.md#D2] — freezed `3.2.6-dev.1` (analyzer-12 stopgap, SCP-2026-05-29-B). [#D3] — `analysis_server_plugin 0.3.14` + `analyzer ^12.0.0`. [#D1] — Dart 3.10+ floor; pin Dart 3.12 / Flutter 3.44.
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-05-29-analyzer12-freezed.md] — the analyzer-12 stopgap reconciling D2 ↔ D3, with the upgrade trigger.
- [Source: _bmad-output/planning-artifacts/architecture.md#3. Type & data conventions] — `field_rename: none`, unmodifiable collections, `const` everywhere, `copyWith`-only mutation, camelCase wire keys.
- [Source: _bmad-output/planning-artifacts/architecture.md#1. Naming & file layout] — snake_case files, generated colocated + gitignored + CI-verified, test mirroring.
- [Source: _bmad-output/planning-artifacts/architecture.md#6. Documentation & testing] — `///` contract-form dartdoc, `package:test`, one top-level `group(<ClassName>)`.
- [Source: _bmad-output/planning-artifacts/architecture.md#Per-package layout: koel_core] — directory map (note `message/` variance above).
- [Source: _bmad-output/implementation-artifacts/epic-1-retro-2026-05-29.md] — Discoveries D1/D2 + Actions #2/#3 (codegen-drift + format:check fixes, owner Story 2.1); lesson A1 (verify toolchain before relying on versions).
- [Source: packages/koel_core/pubspec.yaml, .github/workflows/ci.yml, .github/workflows/codegen-drift.yml, root pubspec.yaml melos.scripts, root analysis_options.yaml] — current scaffold state to extend (not recreate).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8, 1M context)

### Debug Log References

- **Toolchain conflict at Task 1 (retro lesson A1 in the flesh).** `melos bootstrap` failed: `koel_lints` (`analysis_server_plugin 0.3.15` → `analyzer ^13`) vs `freezed ^3.2.5` (`analyzer <11`) — mutually exclusive in one pub-workspace resolution. Escalated via `bmad-correct-course`; four resolution options prototyped end-to-end before deciding. Outcome: **SCP-2026-05-29-B** (analyzer-12 stopgap, Option B). See `_bmad-output/planning-artifacts/sprint-change-proposal-2026-05-29-analyzer12-freezed.md`.
- **Two CI silent-gate bugs caught + fixed during Task 7 validation:**
  - `format:check` written as a melos `exec:` with `$(find …)` — melos interpolated the command substitution to empty, making the gate a no-op (always pass). Moved logic to `tool/format.sh` invoked via `run:`. Verified: passes clean, **fails** on a deliberately misformatted file.
  - `codegen-drift` recommended `git diff --cached --exit-code`, which compares index-vs-HEAD — but generated files are never in HEAD, so it reports every file as added and **fails every PR** (false positive). Corrected to `git diff --exit-code` (working-tree-vs-index after staging build #1 + running build #2 = determinism check). Verified: passes clean, **fails** on injected drift.

### Completion Notes List

- **Story implemented under Option B (analyzer-12 stopgap).** freezed `3.2.6-dev.1` + `analysis_server_plugin 0.3.14` + `analyzer 12.1.0` resolve in one workspace on Dart 3.12; `koel_lints` stays workspace-native (D3 honored); its rule source is unchanged and all 5 koel_lints tests pass on analyzer 12. Upgrade trigger documented in architecture D2/D3.
- **Cross-story handoff (Task 2).** `lib/src/event/ag_ui_event.dart` is the **sealed `AgUiEvent` root only** — no subtypes, no test (a subtype-less sealed class has no behavior). Story 2.2 must **expand this file** (subtypes, `UnknownAgUiEvent`, deserializer dispatcher), not recreate it.
- **Serialization scope.** `Message` + `ToolDefinition` have `fromJson`/`toJson` (→ `*.g.dart`). `RunAgentInput` is **freezed-only** (no `*.g.dart`) — its `reasoningEcho` base64 `Uint8List` codec is deferred to Epic 4 transport.
- **byte-deep equality (AC2)** confirmed by test: distinct `Uint8List` buffers with identical bytes compare `==` (freezed's `DeepCollectionEquality` recurses; `Uint8List` is `Iterable<int>`), differing bytes `!=`.
- **Tests verified locally** via `dart test` in `packages/koel_core` (14 pass) — `melos run test` remains a Story 2.15 stub by design; this story is CI-gated by `analyze` + `build` + `codegen-drift`, not the `test` step.
- DoD: `dart run build_runner build` → 5 generated files; `dart test` 14/14; `melos run analyze` clean across 11 packages; `melos run format:check` clean; `git status` shows no generated files tracked.

### File List

**Source (koel_core):**
- `packages/koel_core/lib/src/event/ag_ui_event.dart` (new) — sealed `AgUiEvent` root (Task 2)
- `packages/koel_core/lib/src/message/message.dart` (new) — `Message` + `MessageRole`
- `packages/koel_core/lib/src/tool/tool_definition.dart` (new) — `ToolDefinition`
- `packages/koel_core/lib/src/input/run_agent_input.dart` (new) — `RunAgentInput`
- `packages/koel_core/lib/src/agent/abstract_agent.dart` (new) — `AbstractAgent` SPI

**Tests (koel_core):**
- `packages/koel_core/test/message/message_test.dart` (new)
- `packages/koel_core/test/tool/tool_definition_test.dart` (new)
- `packages/koel_core/test/input/run_agent_input_test.dart` (new)
- `packages/koel_core/test/agent/abstract_agent_test.dart` (new)

**Toolchain / config:**
- `packages/koel_core/pubspec.yaml` (modified) — freezed/json codegen deps (Option B pins)
- `packages/koel_core/build.yaml` (new) — freezed + json_serializable (`field_rename: none`)
- `packages/koel_lints/pubspec.yaml` (modified) — analyzer-12 stopgap (asp 0.3.14 + analyzer ^12 + analyzer_testing 0.2.5)
- `pubspec.yaml` (modified) — `format`/`format:check` → `tool/format.sh`; `build` drops removed `--delete-conflicting-outputs` flag
- `tool/format.sh` (new) — format/check hand-written Dart, excluding generated

**CI:**
- `.github/workflows/ci.yml` (modified) — `melos run build` before analyze/test
- `.github/workflows/codegen-drift.yml` (modified) — real determinism gate (was a no-op)

**Planning artifacts (via correct-course):**
- `_bmad-output/planning-artifacts/sprint-change-proposal-2026-05-29-analyzer12-freezed.md` (new)
- `_bmad-output/planning-artifacts/architecture.md` (modified) — D1/D2/D3 + decision-completeness summary

### Change Log

- 2026-05-29 — Story 2.1 implemented (foundation contracts + codegen pipeline + codegen-aware CI). Toolchain conflict (freezed ↔ analysis_server_plugin) resolved via SCP-2026-05-29-B (analyzer-12 stopgap). Status → review.
- 2026-05-29 — Code review (3 adversarial layers). 6/6 ACs verified MET; `dart test` 14/14, `melos run analyze` clean (11 pkgs). 3 patches applied: real `codegen-drift` determinism gate (was vacuous — incremental-cache no-op; now wipes outputs+cache before build #2, verified `wrote 7 outputs`), `format.sh` unknown-mode guard, `format` description scope fix. Status → done.

## Review Findings

_Code review 2026-05-29 (bmad-code-review, 3 adversarial layers: Blind Hunter / Edge Case Hunter / Acceptance Auditor). All 6 ACs verified MET; `dart test` 14/14, `melos run analyze` clean across 11 packages, codegen build #2 clean (no conflict). 1 decision-needed, 2 patch, 6 dismissed._

- [x] [Review][Decision→Patch] **`codegen-drift` determinism gate was vacuous — build_runner's incremental cache made build #2 a no-op** — `codegen-drift.yml` staged build #1, re-ran `melos run build` (#2), then `git diff`. Verified empirically: build #2 over unchanged inputs skipped all builders (`wrote 0 outputs`), leaving the working tree byte-identical to the staged index → `git diff` was **always empty**, so the gate could never detect non-deterministic codegen (its stated purpose, AC6). **Resolved (option a — make it a real gate):** before build #2, stage build #1's output then `rm -f $files` + `rm -rf packages/*/.dart_tool/build` so build_runner genuinely re-generates; added `set -euo pipefail`. Verified under bash (CI shell): build #2 now `wrote 7 outputs` (real regen, not skip), determinism diff clean (exit 0). `codegen-drift.yml`.
- [x] [Review][Patch] **`tool/format.sh` silently treats any unknown mode as `write` (mutates tree)** — `tool/format.sh` (`mode="${1:-write}"` + `else`→write). Added an explicit guard: any mode other than `write`/`check` prints an error and `exit 2`. Verified: `bash tool/format.sh bogus` → exit 2; `check` still clean (23 files, 0 changed).
- [x] [Review][Patch] **`format` melos description said "across the workspace" but `tool/format.sh` only walks `packages/`** — `pubspec.yaml:41`. Reworded to "Format hand-written Dart under packages/ …" to match the script's actual scope.

### Dismissed (false positives / handled / accepted-by-design)
- **"Dropping `--delete-conflicting-outputs` breaks/hangs build #2"** (Blind) — false: verified build #2 over existing outputs completes clean (`wrote 0 outputs`), no conflict prompt. The flag is a no-op in current build_runner.
- **"`analyze` may fail over generated `*.freezed.dart`/`*.g.dart` (no analyzer `exclude:`)"** (Edge) — not realized: `melos run analyze` passes clean across all 11 packages with generated files present; freezed/json output carries `ignore_for_file` headers and koel_lints does not trip on it.
- **AbstractAgent dartdoc says "`interface class` marker" while code is `abstract interface class`** (all 3) — intentional per Dev Notes "declaration trap" (keep AC1 dartdoc verbatim + use the correctness keyword). Accepted design tradeoff, not a defect.
- **`field_rename: none` is already json_serializable's default** (Blind) — explicit-set documents the convention (architecture §3) against a future global override; comment is effect-accurate.
- **`Map<String, dynamic>` round-trip untested for non-primitive `dynamic` values** (Blind+Edge) — `parameters` is JSON Schema (primitives) in v1; out-of-domain for this story.
- **`freezed: 3.2.6-dev.1` prerelease pin reproducibility smell** (Blind) — documented, accepted stopgap (D2 / SCP-2026-05-29-B) with an explicit upgrade trigger.
