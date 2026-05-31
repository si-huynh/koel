---
baseline_commit: d846904d138cf8dab8436cff35327df6c0a27f35
---

# Story 3.5: `ConformanceRunner` skeleton + `CONFORMANCE.md` pin + capture pipeline scaffold

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this is the **Epic 3 sealer** — the largest story of the epic. It does three jobs at once: (1) ships the `ConformanceRunner` + freezed `ConformanceReport`/`ConformanceFailure` in `koel_test`; (2) writes the cross-package doc `koel_core/CONFORMANCE.md` (the AG-UI spec pin + the `AgUiEvent_equal` rule); (3) lands the repo-level `tool/capture_fixtures.dart` scaffold + its `melos` script. **AND** it finalizes `koel_test` as a package: turns on the **doc gate** (`analysis_options.yaml`) and the **≥80% coverage gate** (NFR-12 tooling tier) that stories 3.1–3.4 explicitly deferred to *this* story. It touches `.dart` files, designs new public API (`ConformanceRunner`, two freezed types), and adds new dev-tooling deps, so **invoke `/agent-flutter-engineer` before producing any code** (per CLAUDE.md). Unlike 3.4's 3-file footprint, this footprint is wide: 2 new lib files + 2 barrel lines + pubspec deps + 2 new package-config files + 1 koel_core doc + 1 repo tool + 2 root-pubspec melos edits + 1 new test file (+ dartdoc backfill on existing files if the doc gate surfaces gaps). **Seven things are load-bearing, and the first four are non-obvious traps that will sink a naïve reading of the AC:**
>
> 1. **`ConformanceRunner` must drive the agent *directly* via `agent.run(input)` — NOT through `KoelClient`'s pipeline.** This is the single most important decision. The expected corpus is the synthesized `all_event_types.jsonl`, which deliberately contains **both `RUN_ERROR` and `RUN_FINISHED` in one stream** (it is a *type-coverage* fixture, one event of every type — **not** a valid run). `koel_core`'s `verify_stage` would reject that bracketing as a `ProtocolError`. Conformance asks *"does the agent **emit** the correct events"* — so the runner compares the agent's **raw** output to the fixture. Driving through the pipeline (what 3.4 did, for subscriber observability) would corrupt the comparison. **Do NOT** route `runAgainst` through `KoelClient`. See §"The runner mechanism".
> 2. **`ConformanceFailure.actual` is `AgUiEvent?` (nullable) — the AC writes `actual: AgUiEvent` (non-nullable), but a *missing* event type has no actual event.** When the agent never emits a type at all, there is nothing to put in `actual`. AC prose **predates the resolved comparison model** — same class of AC-vs-reality gap 3.3 hit (`agent.run`/`chatSession` → `session.send`/`session.state`) and 3.4 hit (`result.payload['value']` → `jsonDecode(result.content)['value']`). **RESOLVED:** `actual: AgUiEvent?` where `null` = "the agent emitted no event of this type" and a non-null value = "emitted, but `!=` the expected" (the diverged case). **Do NOT** force a non-null `actual` with a fake/sentinel `UnknownAgUiEvent` — it would lie about what the agent did. See §"Comparison model — RESOLVED".
> 3. **`koel_test` gains `freezed` for the FIRST time — but freezed-ONLY, no `json_serializable`.** The report needs structural `==`/`hashCode` (AR-16's `AgUiEvent_equal`), **not** a JSON codec (no AC asks for `ConformanceReport.toJson`). So you add `freezed_annotation` (dep) + `freezed`+`build_runner` (dev) but **NOT** `json_annotation`/`json_serializable`, and the only generated artifact is `*.freezed.dart` (no `*.g.dart`, so **no `build.yaml` is needed** — koel_core's `build.yaml` exists only to configure `json_serializable`). **Mirror koel_core's exact version pins** (`freezed: 3.2.6-dev.1`, the analyzer-12 stopgap per SCP-2026-05-29-B — do NOT bump to a stable freezed, it breaks the workspace analyzer pin) rather than resolving "latest". See §"Dependency changes — RESOLVED".
> 4. **The runner derives the event-type *label* from the fixture's wire `type` string — there is NO polymorphic `type` getter on `AgUiEvent`.** The sealed base `AgUiEvent` exposes only `fromWire`; the `String get type`/`rawJson` getters belong to **`UnknownAgUiEvent`'s** freezed mixin, not the base (grep-verified: `ag_ui_event.dart:48-65`, `ag_ui_event.freezed.dart:17`). So to get `"RUN_STARTED"` for `passed: List<String>`/`eventType`, read it from the fixture line's `payload['type']` (the spec is the source of truth — no drift, no 29-arm `switch`). Match *actual* events to expected by `runtimeType` (cheap, correct: freezed concrete types are stable), and decide pass/fail by freezed `==`. **Do NOT** add a `type` getter to `koel_core`'s `AgUiEvent` (speculative kernel surface; YAGNI), and **Do NOT** use `runtimeType.toString()` for the label (it yields `_RunStartedEvent`, the private impl name — not the wire type). See §"The runner mechanism".
> 5. **This story turns ON `koel_test`'s package-finalization doc gate** (`public_member_api_docs` via a new `analysis_options.yaml`, mirroring koel_core's). 3.4 said verbatim: "the member doc-gate `analysis_options.yaml` for `koel_test` is **Story 3.5's** epic-sealing AC (not yet present)." Enabling it will flag any **existing** 3.1–3.4 public symbol that lacks a dartdoc — **backfill those** so `melos run analyze` stays at 0. See §"The two finalization gates — RESOLVED".
> 6. **The coverage AC means extending the workspace coverage gate, not inventing a per-story metric.** The current root `test:coverage` melos script is **koel_core-only** (hardcoded `cd packages/koel_core`, 90% awk gate). NFR-12 puts `koel_test` in the **tooling tier (≥80%)**. **RESOLVED:** extract `tool/coverage.sh <pkg> <line%> <branch%>` (matches the existing `tool/format.sh`/`tool/test_package.sh` repo-script pattern) and call it twice — koel_core 90/90, koel_test 80/80 — so one `melos run test:coverage` checks every *finalized* package. **Re-verify koel_core still passes 90%** (regression gate on the refactor). See §"The two finalization gates — RESOLVED".
> 7. **`CONFORMANCE.md` is the ONE allowed `koel_core` change — and it is a doc, not code.** 3.4's "zero koel_core change" was 3.4-specific. 3.5's AC explicitly mandates `koel_core/CONFORMANCE.md`. It is a Markdown file (spec-SHA pin + the `AgUiEvent_equal` equality rule); **no `koel_core` `.dart` change, no `koel_core` dependency change.** The SHA is a **placeholder**, finalized at v1.0.0 per SC-1. See §"CONFORMANCE.md — RESOLVED".

## Story

As a release manager,
I want `ConformanceRunner.runAgainst(AbstractAgent)` returning `ConformanceReport`, plus `koel_core/CONFORMANCE.md` pinning the AG-UI release commit SHA, plus `tool/capture_fixtures.dart` scaffold ready for Epic 5 to execute,
so that backend adapters can plug into a conformance test that runs every event type from fixtures per FR-G4 + AR-14 + AR-16.

## Acceptance Criteria

Verbatim from [epic-3 Story 3.5](../planning-artifacts/epics/epic-3-test-harness-conformance-koeltest.md):

1. **Given** `koel_test/lib/src/conformance_runner.dart`, **When** I inspect it, **Then** `class ConformanceRunner` exposes `Future<ConformanceReport> runAgainst(AbstractAgent agent)` that drives the agent through every event-type scenario in `koel_test/lib/src/fixtures/synthesized/` and records pass/fail per event type.

2. **Given** `koel_test/lib/src/conformance_report.dart`, **When** I inspect it, **Then** `ConformanceReport` is freezed with `passed: List<String>`, `failed: List<ConformanceFailure>`, `agentName: String`, `runDuration: Duration`, **And** `ConformanceFailure` carries `eventType: String`, `expected: AgUiEvent`, `actual: AgUiEvent`, `error: KoelError?`.

3. **Given** `koel_core/CONFORMANCE.md`, **When** I inspect the file, **Then** it pins the specific commit SHA of AG-UI `release/2026-05-26` (placeholder commit hash committed here; finalized at v1.0.0 publish per SC-1), **And** documents the structural-equality rule for `AgUiEvent_equal` per Addendum AR-16 (`freezed`-generated `==` covers all fields including byte-equal `Uint8List` comparison — OQ-Conformance-Equivalence resolves before v1.0.0).

4. **Given** `tool/capture_fixtures.dart`, **When** I inspect the scaffold, **Then** it declares the four backend configurations (dojo, agno, langgraph, CopilotKit Next.js runtime) with `// TODO(Epic 5):` markers pointing to specific story IDs, **And** the script can be invoked via `dart run tool/capture_fixtures.dart --backend=<name>` printing "wired in Epic 5 Story <N>" until populated, **And** `melos.yaml` exposes `melos run capture-fixtures` script wired to this entrypoint.

5. **Given** `koel_test` package overall, **When** I run `melos run test:coverage` for it, **Then** coverage ≥ 80% per NFR-12.

> **AC-vs-reality mappings (RESOLVED, do not re-litigate — implement):**
> - AC2 `ConformanceFailure.actual: AgUiEvent` → **`actual: AgUiEvent?`** (nullable; `null` = the agent emitted no event of that type — a missing type has no actual event to carry — trap #2).
> - AC4 "`melos.yaml` exposes `melos run capture-fixtures`" → the script lives in **`pubspec.yaml` > `melos.scripts`** (Melos 7.x reads scripts from `pubspec.yaml`, not `melos.yaml` — see the comment at the top of the repo's `melos.yaml`). `melos run capture-fixtures` still works; only the file the script is *authored in* differs from the AC's wording.
> - AC5 "run `melos run test:coverage` for it" → the workspace `test:coverage` script is **extended** to check koel_test's 80% tier alongside koel_core's 90% (trap #6); there is no per-package coverage subcommand convention in this repo.

## Tasks / Subtasks

- [x] **Task 0 — Read the real surfaces before writing a line** (AC: all — skipping this is how the wrong contract gets built)
  - [x] Read `packages/koel_core/lib/src/event/ag_ui_event.dart:48-65` — confirm the sealed base `AgUiEvent` exposes **only** `static AgUiEvent fromWire(Map<String,dynamic>)` and a `const` ctor; there is **no** instance `type`/`eventType`/`toJson` on the base (the `String get type`/`rawJson` at `ag_ui_event.freezed.dart:17` belong to `UnknownAgUiEvent`'s mixin). This is why the type *label* is read from the fixture wire, not the event (trap #4). [Source: ag_ui_event.dart:48-65]
  - [x] Read `packages/koel_core/lib/src/agent/abstract_agent.dart` — confirm `AbstractAgent` is an `abstract interface class` with the single method `Stream<AgUiEvent> run(RunAgentInput input)`; adapters NEVER throw, they emit `RunErrorEvent`. The runner drives this and hardens against a buggy agent that *does* throw (trap #1, §"Error channel"). [Source: abstract_agent.dart:10-14]
  - [x] Read `packages/koel_test/lib/src/fixture_loader.dart` — confirm `FixtureLoader.loadSynthesized(name) → Future<List<AgUiEvent>>` decodes via `AgUiEvent.fromWire` and **drops** the `_session` header AND the wire `type` (returns events only). The runner needs the wire `type` string, so it reads the fixture's raw lines itself (mirroring `_load`'s `package:` URI resolution) — `FixtureLoader` does not surface the type label. [Source: fixture_loader.dart:83-165]
  - [x] Read `packages/koel_test/lib/src/mock_agent.dart` — confirm `MockAgent.fromEvents(List<AgUiEvent>)` (verbatim replay, ignores input) and `MockAgent.fromFixture(String name)` (reads a **synthesized** fixture). Both are the agents-under-test for the runner's own tests (Task 8). [Source: mock_agent.dart; 3-3 §fromFixture]
  - [x] Read `packages/koel_core/lib/src/event/run_events.dart:1-60` (a `@freezed` event template) and `koel_core/lib/src/error/koel_error.dart:92-103` (`AgentError(message:, code:, cause?, agentCode?)`). The two freezed result types mirror this `@freezed abstract class … with _$…` shape; a thrown non-`KoelError` is wrapped as `AgentError(message:, code: KoelErrorCode.unknown, cause: error)`. [Source: run_events.dart:9-35; koel_error.dart:92-103]
  - [x] Read `packages/koel_core/pubspec.yaml`, `packages/koel_core/analysis_options.yaml`, `packages/koel_core/coverage_options.yaml`, root `pubspec.yaml` (`melos.scripts`), `tool/test_package.sh`, `tool/format.sh` — these are the **exact templates** to mirror for the pubspec deps, the doc gate, the coverage-exclude file, and the `tool/coverage.sh` extraction. [Source: §"Files you will touch"]
  - [x] Confirm `all_event_types.jsonl` is the type-coverage fixture (one event of every AG-UI type incl. **both** `RUN_ERROR` and `RUN_FINISHED`) — this is *why* the runner drives the agent directly, not through the pipeline (trap #1). [Source: fixtures/synthesized/all_event_types.jsonl]

- [x] **Task 1 — `ConformanceFailure` + `ConformanceReport` (freezed)** (AC: #2)
  - [x] New file `packages/koel_test/lib/src/conformance_report.dart`. Both freezed types live in **one file** (a cohesive pair) with a single `part 'conformance_report.freezed.dart';`. Import `package:koel_core/koel_core.dart` (for `AgUiEvent`, `KoelError`) + `package:freezed_annotation/freezed_annotation.dart`. **No `src/` import into koel_core, no Flutter.** [Source: architecture §6 :684; barrel discipline 3.1/3.3]
  - [x] `@freezed abstract class ConformanceFailure with _$ConformanceFailure` → `const factory ConformanceFailure({required String eventType, required AgUiEvent expected, AgUiEvent? actual, KoelError? error}) = _ConformanceFailure;`. **`actual` is nullable** (trap #2 / AC-mapping). Dartdoc each field: `eventType` = the AG-UI wire `type`; `expected` = the canonical fixture event; `actual` = the agent's same-type event, or `null` if it emitted none; `error` = the run-terminating `KoelError` when the agent errored/threw, else `null`. [Source: AC2; trap #2]
  - [x] `@freezed abstract class ConformanceReport with _$ConformanceReport` → `const factory ConformanceReport({required List<String> passed, required List<ConformanceFailure> failed, required String agentName, required Duration runDuration}) = _ConformanceReport;`. Dartdoc: `passed` = wire-type names that matched; `failed` = per-type failures; `agentName` = the runtime type name of the agent under test; `runDuration` = wall-clock of the drive. freezed gives `DeepCollectionEquality` `==` over the lists (so two equal reports compare equal — used in tests). [Source: AC2]
  - [x] **Do NOT** add `json_serializable`/`toJson`/`fromJson` — no AC needs a JSON codec; freezed-only keeps the generated set to `*.freezed.dart` (trap #3). [Source: trap #3; AC2]

- [x] **Task 2 — `ConformanceRunner` skeleton + public API** (AC: #1)
  - [x] New file `packages/koel_test/lib/src/conformance_runner.dart` (architecture-pinned: `conformance_runner.dart # F-G4`, architecture :966). Import `package:koel_core/koel_core.dart` + the sibling `conformance_report.dart` + `dart:async`/`dart:convert`/`dart:io`/`dart:isolate` (for the fixture read, mirroring `FixtureLoader._load`) + `package:koel_test`'s own `fixture_loader.dart`/`mock_agent.dart` only if reused. **No `src/` import into koel_core, no Flutter.** [Source: architecture :958-977]
  - [x] Declare a **plain `final class ConformanceRunner`** with a public `const` unnamed constructor (it holds no state). Public method: `Future<ConformanceReport> runAgainst(AbstractAgent agent)`. Dartdoc it as FR-G4: "drives `agent` through the synthesized type-coverage corpus and reports pass/fail per AG-UI event type; the AG-UI-spec-pin and equivalence rule live in `koel_core/CONFORMANCE.md`." [Source: AC1; FR-G4 :67]

- [x] **Task 3 — Expected corpus reader (wire-type label preserved)** (AC: #1)
  - [x] Private helper that loads `all_event_types.jsonl` as **`List<({String type, AgUiEvent event})>`** — read the fixture's raw lines via the `package:` asset URI (`Uri.parse('package:koel_test/src/fixtures/synthesized/all_event_types.jsonl')` → `Isolate.resolvePackageUri` → `File`), skip the `_session` header line, and for each event line pair `payload['type'] as String` with `AgUiEvent.fromWire(payload)`. This preserves the wire-type label `FixtureLoader.loadSynthesized` discards (trap #4). [Source: fixture_loader.dart:110-165 — mirror the URI resolution]
  - [x] **Why read the wire type, not switch on the event:** the sealed `AgUiEvent` has no polymorphic `type`; the fixture's `payload['type']` IS the AG-UI registry string (spec source of truth, no drift). A 29-arm `switch` would duplicate that registry in code and rot. [Source: trap #4; ag_ui_event.dart:48-65]

- [x] **Task 4 — Drive the agent directly + capture errors** (AC: #1)
  - [x] Private `_drive(AbstractAgent agent)` → collects the agent's raw output: start a `Stopwatch`, build a minimal `RunAgentInput(threadId: 'conformance-thread', runId: 'conformance-run')`, then `await for (final e in agent.run(input))` accumulating events; capture the first `RunErrorEvent`'s `.error` into a run-level `KoelError? runError`. Wrap the whole loop in `try { … } on KoelError catch (e) { runError = e; } catch (e) { runError = AgentError(message: 'agent threw during run: $e', code: KoelErrorCode.unknown, cause: e); }` — harden against a buggy agent that violates the "never throw" SPI (the conformance harness must survive non-conformant agents). Stop the `Stopwatch`. Return the events + `runError` + elapsed `Duration`. [Source: trap #1; abstract_agent.dart:10-14; koel_error.dart:92-103]
  - [x] **Drive `agent.run(input)` directly — NOT via `KoelClient`** (trap #1): `all_event_types.jsonl` is not a valid run (it carries `RUN_ERROR` *and* `RUN_FINISHED`), so the pipeline's verify stage would reject it. Conformance compares the agent's *emitted* events; the pipeline is the wrong lens here. [Source: trap #1; §"The runner mechanism"]

- [x] **Task 5 — Comparison: pass/fail per event type** (AC: #1)
  - [x] For each `(type, expected)` in the corpus, match against the actual events **by `runtimeType`** (`actual.where((e) => e.runtimeType == expected.runtimeType)`):
    - any match `== expected` (freezed structural `==`) → **pass**: add `type` to `passed`.
    - else a same-`runtimeType` match exists but none equal → **fail**: `ConformanceFailure(eventType: type, expected: expected, actual: <that match>, error: runError)`.
    - else no same-type match → **fail**: `ConformanceFailure(eventType: type, expected: expected, actual: null, error: runError)`. (trap #2)
  - [x] Assemble `ConformanceReport(passed: passed, failed: failed, agentName: agent.runtimeType.toString(), runDuration: elapsed)`. [Source: AC2]
  - [x] **Why `runtimeType` matching + freezed `==`:** freezed concrete types are stable (`_RunStartedEvent`), so `expected.runtimeType == actual.runtimeType` is a cheap, correct same-type test, and `==` is AR-16's `AgUiEvent_equal` (structural, incl. byte-equal `Uint8List`). No reflection, no `switch`. [Source: AR-16; trap #4; reasoning_events.dart:186]

- [x] **Task 6 — Export from the barrel** (AC: #1, #2)
  - [x] In `packages/koel_test/lib/koel_test.dart` (MODIFY), add `export 'src/conformance_report.dart';` then `export 'src/conformance_runner.dart';` — the **4th and 5th** exports (after `mock_agent.dart`, `fixture_loader.dart`, `tool_handler_test_harness.dart`). This surfaces `ConformanceRunner`, `ConformanceReport`, `ConformanceFailure`. **Do NOT** re-export `koel_core` (only the meta-package re-exports). [Source: koel_test.dart:1-13; architecture :980]

- [x] **Task 7 — Dependency changes: add freezed to `koel_test`** (AC: #2)
  - [x] In `packages/koel_test/pubspec.yaml` (MODIFY): add `freezed_annotation: ^3.1.0` to `dependencies` (runtime annotation, mirrors koel_core); add `build_runner: ^2.4.0` and `freezed: 3.2.6-dev.1` to `dev_dependencies`. **Mirror koel_core's exact pins** — `freezed: 3.2.6-dev.1` is the documented analyzer-12 stopgap (D2 / SCP-2026-05-29-B); a stable freezed would break the workspace analyzer pin. **Do NOT** add `json_annotation`/`json_serializable` (no JSON codec needed — trap #3). [Source: koel_core/pubspec.yaml; SCP-2026-05-29-B; trap #3]
  - [x] Adding `build_runner` auto-enrolls `koel_test` in `melos run build` (`packageFilters: dependsOn: build_runner`) and the `codegen-drift` CI gate — expected and correct. Run `melos run build` (or `dart run build_runner build` in `koel_test`) to generate `conformance_report.freezed.dart`. The generated file is **gitignored** (`*.freezed.dart`, root `.gitignore`) — do NOT commit it. [Source: root pubspec `melos.scripts.build`; architecture :712]

- [x] **Task 8 — `koel_test` finalization gate #1: doc gate (`analysis_options.yaml`)** (AC: all — the epic-sealing finalization 3.4 deferred here)
  - [x] New file `packages/koel_test/analysis_options.yaml`, **mirroring koel_core's exactly**: `include: ../../analysis_options.yaml`; `analyzer.exclude: ["**/*.freezed.dart", "**/*.g.dart"]`; `linter.rules: { public_member_api_docs: true, comment_references: true }`. (Declares **no** `plugins:` — that lives only at the workspace root per Story 1.7; this file is plugin-free, scoped to koel_test.) [Source: koel_core/analysis_options.yaml]
  - [x] Run `melos run analyze` and **backfill dartdocs on any existing 3.1–3.4 public symbol** the gate now flags (the gate was absent through 3.4, so prior public members may be undocumented). Target: **0 issues** workspace-wide. Existing files in scope: `mock_agent.dart`, `fixture_loader.dart`, `tool_handler_test_harness.dart` and their public members. [Source: trap #5; 3.4 Task 9 note]
  - [x] New file `packages/koel_test/coverage_options.yaml`, mirroring koel_core's (`ignore_files: ["**/*.freezed.dart", "**/*.g.dart", "**/*.mocks.dart"]`) so generated code is excluded from the coverage number (NFR-12 / SC-2). [Source: koel_core/coverage_options.yaml]

- [x] **Task 9 — `koel_test` finalization gate #2: coverage ≥ 80%** (AC: #5)
  - [x] Extract `tool/coverage.sh` parameterized as `coverage.sh <package-path> <min-line%> <min-branch%>` — the body is koel_core's current inline awk gate generalized (`cd <pkg>; dart test --exclude-tags=perf --coverage=coverage --branch-coverage; format_coverage --lcov --in=coverage --out=coverage/lcov.info --report-on=lib --check-ignore; awk … threshold = $2/$3`). Make it executable. [Source: root pubspec `test:coverage`; tool/format.sh pattern]
  - [x] In root `pubspec.yaml`, rewrite `melos.scripts.test:coverage` `run:` to call the helper twice: `bash "$MELOS_ROOT_PATH/tool/coverage.sh" packages/koel_core 90 90` then `… packages/koel_test 80 80`. Keep `set -e` so either tier failing fails the gate. **Re-verify koel_core still reports ≥90%** after the refactor (regression gate). [Source: trap #6; NFR-12]
  - [x] Confirm `koel_test` lands **≥80% line + branch** — the `ConformanceRunner` branches (pass / diverged / missing / run-error) are all exercised by Task 11's tests; freezed types are generated (excluded); `tool/capture_fixtures.dart` is repo-level (NOT in `koel_test/lib`, so not counted). [Source: NFR-12; §"Coverage reachability"]

- [x] **Task 10 — `CONFORMANCE.md` (koel_core) + capture-pipeline scaffold** (AC: #3, #4)
  - [x] New file `packages/koel_core/CONFORMANCE.md` (the **only** koel_core touch — a doc, no `.dart`/dep change; architecture :757 "only koel_core"). Content: (a) pins AG-UI `release/2026-05-26` with a **placeholder** commit SHA (clearly marked `PLACEHOLDER — finalized at v1.0.0 per SC-1`); (b) documents the `AgUiEvent_equal` rule per AR-16 — freezed-generated `==` covers every field, including **byte-equal `Uint8List`** comparison (`Uint8List` is an `Iterable<int>`, so freezed's `DeepCollectionEquality` compares bytes — see `reasoning_events.dart:186`); (c) notes **OQ-Conformance-Equivalence** (byte-equal-vs-identity for `Uint8List`, and id-normalization for real-backend captures whose `threadId`/`runId`/`messageId` differ from synthesized) **resolves before v1.0.0**. [Source: AC3; AR-16 :146; reasoning_events.dart:179-189]
  - [x] New file `tool/capture_fixtures.dart` (repo-level — architecture :725; **not** in any package's `lib/`). Zero-dependency `dart:io` script: parse `--backend=<name>` from `args` manually (no `package:args` dep — a repo tool has no pubspec of its own beyond the workspace root). Declare the four backend configs (`dojo`, `agno`, `langgraph`, `copilotkit_runtime`) each with a `// TODO(Epic 5):` marker → specific story IDs: **agno → Story 5.3**, **langgraph → Story 5.6**, **dojo & copilotkit_runtime → Story 5.9**. For a recognized `--backend`, print `wired in Epic 5 Story <N>` and exit 0; for an unknown/absent backend, print usage listing the four names and exit non-zero. [Source: AC4; AR-14 :144; Epic 5 story ids 5.3/5.6/5.9]
  - [x] In root `pubspec.yaml` `melos.scripts`, add a `capture-fixtures` script: `run: dart run "$MELOS_ROOT_PATH/tool/capture_fixtures.dart"` (description: "Fixture-capture pipeline scaffold (4 backends → JSONL); wired per backend in Epic 5 — 5.3/5.6/5.9"). `melos run capture-fixtures` invokes the entrypoint (the AC says "`melos.yaml` exposes" it, but Melos 7.x reads scripts from `pubspec.yaml` — see the AC-mapping note). [Source: AC4; melos.yaml comment; root pubspec melos.scripts]

- [x] **Task 11 — Tests** (AC: #1, #2, #5)
  - [x] New `packages/koel_test/test/conformance_runner_test.dart` (`package:test` only; one top-level `group(ConformanceRunner, () {...})`; source-mirror naming — convention §6 :654-664). CWD = package root (the runner reads `all_event_types.jsonl` via `package:` URI, which is CWD-independent, but `melos run test` runs at package root anyway). [Source: architecture §6 :654-664]
  - [x] **AC1 all-pass:** `final report = await const ConformanceRunner().runAgainst(MockAgent.fromFixture('all_event_types'));` → `expect(report.failed, isEmpty)` and `expect(report.passed, hasLength(28))` (one per AG-UI type; assert a few names e.g. `contains('RUN_STARTED')`, `contains('REASONING_ENCRYPTED_VALUE')`, `contains('CUSTOM')`). Assert `report.agentName` contains `MockAgent` and `report.runDuration` is non-negative. **This proves the byte-equal `Uint8List` path** (the fixture's `REASONING_ENCRYPTED_VALUE` round-trips to an equal event). [Source: AC1/AC2; trap #1]
  - [x] **Missing-type fail:** `runAgainst(MockAgent.fromEvents(const []))` → `report.passed` empty, `report.failed` has 28 entries, each with `actual == null` (trap #2). [Source: trap #2]
  - [x] **Diverged-type fail:** `runAgainst(MockAgent.fromEvents([RunStartedEvent(threadId: 'other', runId: 'other')]))` → `RUN_STARTED` is in `failed` (not `passed`) with `actual` = that divergent event (same `runtimeType`, `!= expected`); the other 27 fail with `actual == null`. Proves the runtimeType-match-but-unequal branch. [Source: Task 5]
  - [x] **Run-error capture:** an agent emitting a `RunErrorEvent` (e.g. `MockAgent.fromEvents([RunStartedEvent(threadId:'t',runId:'r'), RunErrorEvent(error: AgentError(message: 'boom', code: KoelErrorCode.unknown))])`) → the resulting failures carry `error` non-null with that `KoelError`. Optionally a throwing agent (a tiny test `AbstractAgent` whose `run` returns `Stream.error(...)`) → `error` wrapped as `AgentError`. Proves the error channel (Task 4). [Source: Task 4 error channel]
  - [x] **`ConformanceReport` value semantics:** two reports built from equal inputs compare `==` (freezed `DeepCollectionEquality`) — a one-liner guarding the freezed contract. [Source: AC2]
  - [x] **`tool/capture_fixtures.dart` (optional but cheap):** the entrypoint is repo-level and not counted in koel_test coverage; a smoke test is not required by AC. If added, place it where it can `Process.run('dart', ['run', 'tool/capture_fixtures.dart', '--backend=agno'])` and assert the "wired in Epic 5 Story 5.3" output — **but** this is out of `koel_test`'s test dir; prefer leaving the scaffold uncovered (it is a TODO-marked stub). [Source: AC4 — scaffold, not logic]

- [x] **Task 12 — Quality gates** (AC: all)
  - [x] `melos run build` → `conformance_report.freezed.dart` generated; `git status` shows it gitignored (not staged). [Source: Task 7]
  - [x] `melos run analyze` → **0 issues** workspace-wide, **with the new koel_test doc gate active** (every public symbol in koel_test documented, incl. backfilled 3.1–3.4 symbols). [Source: Task 8; NFR-13]
  - [x] `melos run test` → green workspace-wide incl. the new `conformance_runner_test.dart`. [Source: Task 11]
  - [x] `melos run test:coverage` → **koel_core ≥90% AND koel_test ≥80%** (both tiers, via `tool/coverage.sh`). [Source: Task 9; AC5; NFR-12]
  - [x] `melos run format:check` → clean (incl. the new lib/tool/config files). [Source: convention; tool/format.sh]
  - [x] `melos run capture-fixtures` (and `dart run tool/capture_fixtures.dart --backend=agno`) → prints the Epic-5 wiring line, exits 0. [Source: AC4]
  - [x] Confirm the change set matches §"Files you will touch" exactly. **`koel_core` change is `CONFORMANCE.md` ONLY** (no `.dart`, no dep). [Source: §"Files you will touch"]

## Dev Notes

### What this story is, in one paragraph
The **Epic 3 sealer**. 3.1 shipped `MockAgent`; 3.2 the fixtures; 3.3 the loader/decoder; 3.4 the tool-handler harness. This story adds the **conformance** layer — `ConformanceRunner.runAgainst(AbstractAgent) → ConformanceReport` — plus the two artifacts a release/conformance story owns: `koel_core/CONFORMANCE.md` (the AG-UI spec-SHA pin + the `AgUiEvent_equal` rule) and the repo-level `tool/capture_fixtures.dart` scaffold (which Epic 5 fills in). It is **also** the package-finalization story for `koel_test`: it turns on the **doc gate** and the **≥80% coverage gate** (NFR-12 tooling tier) that 3.1–3.4 deferred. The skeleton's job is FR-G4 (a backend-agnostic conformance check), not full equivalence — real backends pass in Epic 5, and the byte-equal-vs-identity / id-normalization questions are explicitly **OQ-Conformance-Equivalence**, resolved before v1.0.0. [Source: epic-3 3.5 :107-138; FR-G4 :67; AR-14/16 :144-146]

### The runner mechanism (the heart of this story) — RESOLVED
`runAgainst(agent)` is satisfiable one clean way, given the primitives:
- **Expected corpus = `all_event_types.jsonl`.** It is the one synthesized fixture authored as *exactly one event of every AG-UI type* (28 — verified: `RUN_STARTED … CUSTOM`). "Pass/fail **per event type**" (AC1) is therefore one entry per type, directly. The other synthesized fixtures are flow scenarios with overlapping types; the type-coverage fixture is the minimal, complete corpus for a per-type report.
- **Drive `agent.run(input)` directly (NOT through `KoelClient`).** `all_event_types.jsonl` carries **both `RUN_ERROR` and `RUN_FINISHED`** — it is a type catalogue, not a valid run; `koel_core`'s pipeline `verify_stage` would reject the bracketing. Conformance asks whether the agent *emits* the right events, so the comparison is against the agent's **raw** stream. (3.4 drove through `KoelClient` because it needed `AgentSubscriber` dispatch; 3.5 needs the opposite — the unfiltered emission.)
- **Type label from the wire, match by `runtimeType`, equality by freezed `==`.** There is no polymorphic `type` getter on the sealed `AgUiEvent` (only `UnknownAgUiEvent` has one, via its freezed mixin). So the runner reads each expected line's `payload['type']` for the `String` label, pairs it with `AgUiEvent.fromWire(payload)`, then for each expected event finds same-`runtimeType` actual events and decides pass (`== expected`) / diverged (same type, `!=`) / missing (no same type). freezed concrete types are stable, so `runtimeType ==` is a correct, allocation-free same-type test, and freezed `==` is AR-16's structural `AgUiEvent_equal`.

This is a **skeleton**: in Epic 3 it is verified against `MockAgent`s (a fixture-backed `MockAgent.fromFixture('all_event_types')` passes all 28; an empty/divergent/erroring agent fails). Real backends (Epic 5) emit the canonical types but with backend-specific ids that won't be byte-`==` to the synthesized expected — that gap is **OQ-Conformance-Equivalence** (id-normalization), documented in `CONFORMANCE.md` and resolved before v1.0.0. The skeleton does **exact** structural comparison; it does not pre-build the normalization Epic 5 will need. [Source: trap #1/#4; AR-16; epic-3 3.5 cross-epic notes]

### Comparison model — RESOLVED
- `ConformanceFailure.actual` is **`AgUiEvent?`**, not the AC's literal `AgUiEvent`. A **missing** type (the agent emitted nothing of that `runtimeType`) has no actual event — `null` is the honest representation. A non-null `actual` means the agent *did* emit that type but it diverged structurally. This is the same AC-vs-reality discipline 3.3 used (`agent.run`/`chatSession` → real API) and 3.4 used (`result.payload` → `jsonDecode(content)`). **Do NOT** invent a sentinel `UnknownAgUiEvent` to keep `actual` non-null — it would misreport "the agent emitted an Unknown event" when in fact it emitted nothing. [Source: trap #2]
- `error: KoelError?` carries the run-terminating failure (the first `RunErrorEvent.error`, or a wrapped thrown error) on every failure produced after the agent errored. It is `null` on a clean-but-divergent run. [Source: Task 4]

### Dependency changes — RESOLVED
`koel_test` gains freezed for the first time, **freezed-only**:
- `dependencies: freezed_annotation: ^3.1.0` (runtime annotation).
- `dev_dependencies: build_runner: ^2.4.0`, `freezed: 3.2.6-dev.1`.
- **Exact pins mirror koel_core** — `freezed: 3.2.6-dev.1` is the analyzer-12 stopgap (D2 / SCP-2026-05-29-B: no stable freezed supports analyzer 13, so the workspace is held at analyzer 12). Bumping it would break the pin. **Do NOT** "resolve latest".
- **No `json_annotation`/`json_serializable`** — the report needs structural `==` (AR-16), not a JSON codec. So the only generated artifact is `conformance_report.freezed.dart`; there is **no `*.g.dart`, hence no `build.yaml`** (koel_core's `build.yaml` exists solely to configure `json_serializable.field_rename`). Adding `build_runner` enrols koel_test in `melos run build` + the codegen-drift gate automatically. [Source: koel_core/pubspec.yaml; koel_core/build.yaml; SCP-2026-05-29-B; trap #3]

### The two finalization gates — RESOLVED
3.1–3.4 deliberately left `koel_test` ungated so the in-flight scaffold stayed free of premature gates (3.4 Task 9 says so explicitly). 3.5, the sealer, turns both on:
1. **Doc gate** — `packages/koel_test/analysis_options.yaml` mirrors koel_core's: `include` the root, `analyzer.exclude` the generated files, `public_member_api_docs: true` + `comment_references: true`. **It is plugin-free** (per Story 1.7, `plugins:` lives only at the workspace root; a member options file must not redeclare it — `plugins_in_inner_options`). Turning the gate on will likely flag undocumented public members from 3.1–3.4 — **backfill them**. Also add `coverage_options.yaml` (mirror koel_core) so generated files are excluded from coverage.
2. **Coverage gate** — the root `test:coverage` script is currently a single hardcoded koel_core block (90% line+branch). NFR-12 places `koel_test` in the **tooling tier (≥80%)**. Rather than a second inlined ~15-line awk copy, **extract `tool/coverage.sh <pkg> <line%> <branch%>`** (the repo already factors `tool/format.sh`/`tool/test_package.sh`) and call it twice (koel_core 90/90, koel_test 80/80). **Re-verify koel_core still passes 90%** after the refactor — that is a real regression surface. [Source: koel_core/analysis_options.yaml, coverage_options.yaml; root pubspec test:coverage; NFR-12 :108; Story 1.7]

### CONFORMANCE.md — RESOLVED
`packages/koel_core/CONFORMANCE.md` is the **only** koel_core change — a Markdown doc (no `.dart`, no dependency change). It must:
- Pin AG-UI `release/2026-05-26` with a **placeholder** commit SHA, explicitly labelled as finalized at v1.0.0 publish (SC-1).
- Document the `AgUiEvent_equal` rule (AR-16): freezed-generated `==` compares **all** fields structurally, including `Uint8List` **byte-equal** (it is an `Iterable<int>`, so freezed's `DeepCollectionEquality` compares element-wise — see `reasoning_events.dart:186` and `ReasoningEncryptedValueEvent`).
- Record **OQ-Conformance-Equivalence** as open-until-v1.0.0: (a) `Uint8List` byte-equal vs identity; (b) id-normalization for real captured fixtures (whose `threadId`/`runId`/`messageId` differ from the synthesized corpus) so Epic 5's real backends can pass the runner. The skeleton does exact `==`; the normalization rule is deferred. [Source: AC3; AR-16 :146; SC-1; reasoning_events.dart:179-189]

### Coverage reachability
`koel_test` ≥80% is reachable with Task 11's tests: the runner's four branches (pass / diverged / missing / run-error) are each hit; `agentName`/`runDuration` are asserted; the freezed types' generated code is excluded (`coverage_options.yaml`); and `tool/capture_fixtures.dart` is **repo-level (not in `koel_test/lib`)**, so its TODO-stub body does not drag the package's coverage number down. Watch the error-channel `catch (e)` arm — cover it with a `Stream.error` agent so the wrap-into-`AgentError` line is exercised. [Source: NFR-12; Task 11]

### Out of scope — do NOT build these (RESOLVED)
- **Real fixture captures / live backends** — Epic 5 (5.3 agno, 5.6 langgraph, 5.9 dojo+copilot). `tool/capture_fixtures.dart` is a TODO-marked **scaffold** that prints "wired in Epic 5 Story N"; do **not** implement any real capture, HTTP, or backend deployment. [Source: AR-14; epic-3 3.5 :129-133]
- **Id-normalization / equivalence relaxation** for real backends — OQ-Conformance-Equivalence, resolved before v1.0.0. The skeleton does exact freezed `==`. [Source: AR-16]
- **`json_serializable`/`toJson` on the report**, or any `build.yaml` in koel_test — no JSON codec is required; freezed-only (trap #3). [Source: trap #3]
- **A `type`/`eventType` getter on `koel_core`'s `AgUiEvent`** — speculative kernel surface; the label comes from the fixture wire (trap #4). [Source: trap #4]
- **Any `koel_core` `.dart` or dependency change** — `CONFORMANCE.md` (doc) is the only koel_core touch. [Source: trap #7]
- **A real `melos.yaml` scripts block** — Melos 7.x reads scripts from `pubspec.yaml`; the `capture-fixtures` script goes there (AC-mapping note). [Source: melos.yaml comment]
- **Changing `publish_to: none`** anywhere — flips at Epic 9 Story 9.9. [Source: 3.2/3.3/3.4 Out of scope]
- **The `conformance.yml` CI workflow / `melos run conformance`** — CI matrix is Epic 9 / AR-17; this story ships the runner + `test:coverage` tier, not the conformance CI job. [Source: AR-17 :147; epic scope]

### Files you will touch
| Path | Action | Note |
|------|--------|------|
| `packages/koel_test/lib/src/conformance_report.dart` | **NEW** | `@freezed ConformanceReport` + `@freezed ConformanceFailure` (one file, one `part`); `actual: AgUiEvent?` (Task 1). |
| `packages/koel_test/lib/src/conformance_runner.dart` | **NEW** | `final class ConformanceRunner` + `runAgainst` (drive-direct, wire-label, runtimeType-match) (Tasks 2-5). |
| `packages/koel_test/lib/koel_test.dart` | **MODIFY** | +2 exports (report, runner) — the 4th & 5th (Task 6). |
| `packages/koel_test/pubspec.yaml` | **MODIFY** | +`freezed_annotation` dep; +`build_runner`,+`freezed` dev-deps (exact koel_core pins) (Task 7). |
| `packages/koel_test/analysis_options.yaml` | **NEW** | doc gate (mirror koel_core) (Task 8). |
| `packages/koel_test/coverage_options.yaml` | **NEW** | exclude generated from coverage (mirror koel_core) (Task 8). |
| `packages/koel_core/CONFORMANCE.md` | **NEW** | spec-SHA pin (placeholder) + `AgUiEvent_equal` rule + OQ (Task 10). **Only koel_core touch.** |
| `tool/capture_fixtures.dart` | **NEW** | repo-level scaffold; 4 backends; `// TODO(Epic 5):` → 5.3/5.6/5.9 (Task 10). |
| `tool/coverage.sh` | **NEW** | parameterized coverage gate extracted from `test:coverage` (Task 9). |
| `pubspec.yaml` (root) | **MODIFY** | `test:coverage` → call `tool/coverage.sh` ×2 (koel_core 90, koel_test 80); add `capture-fixtures` script (Tasks 9, 10). |
| `packages/koel_test/test/conformance_runner_test.dart` | **NEW** | all-pass / missing / diverged / run-error / value-semantics (Task 11). |
| `packages/koel_test/lib/src/{mock_agent,fixture_loader,tool_handler_test_harness}.dart` | **MODIFY (only if needed)** | backfill dartdocs the doc gate flags (Task 8). |

**Do NOT touch:** any `koel_core` `.dart` file or its pubspec; 3.2's `.jsonl`/`.placeholder` fixtures (consumed, not modified); `koel_test/lib/src/mock_agent.dart`/`fixture_loader.dart`/`tool_handler_test_harness.dart` logic (docs only, if flagged); any other package; `publish_to`; `koel_test`'s `README`/`CHANGELOG`/`LICENSE`; `melos.yaml` (scripts live in `pubspec.yaml`).

### Library / framework requirements
- **New deps (koel_test only):** `freezed_annotation: ^3.1.0` (dep), `build_runner: ^2.4.0` + `freezed: 3.2.6-dev.1` (dev) — exact koel_core pins. No `json_serializable`. No Flutter. [Source: koel_core/pubspec.yaml; trap #3]
- **`package:test` only** for tests; async/error matchers as needed. The runner reads fixtures via `dart:io`/`dart:isolate` `package:` URI resolution (same mechanism as `FixtureLoader`). [Source: architecture §6 :654-664; fixture_loader.dart:110-165]
- **Consumed from `koel_core`'s public barrel:** `AgUiEvent` (+ `fromWire`), `AbstractAgent`, `RunAgentInput`, `RunStartedEvent`/`RunErrorEvent` (tests), `KoelError`/`AgentError`/`KoelErrorCode`. From `koel_test`: `MockAgent.fromFixture`/`fromEvents`. **Read for use; modify no `koel_core` code.** [Source: koel_core.dart exports]
- **freezed 3.x syntax:** `@freezed abstract class X with _$X { const factory X({...}) = _X; }` (matches every koel_core event/error). No `._()` private ctor is needed (the report types declare no custom members/getters). [Source: run_events.dart:9-35; koel_error.dart:92-103]

### Project Structure Notes
- `conformance_runner.dart` (# F-G4) and `conformance_report.dart` (# result type) are the architecture-pinned locations (architecture :966-967, listed after `tool_handler_test_harness.dart`). [Source: architecture :958-977]
- `lib/koel_test.dart` stays the single barrel; this adds its **4th & 5th** exports. `lib/src/` stays private. [Source: koel_test.dart; architecture §6 :684]
- `tool/capture_fixtures.dart` is **repo-level** (architecture :725, alongside `format.sh`/`test_package.sh`), not a package file — so it is outside every package's `lib/` and coverage scope. [Source: architecture :722-727]
- `CONFORMANCE.md` lives at `packages/koel_core/CONFORMANCE.md` (architecture :757 "only koel_core") — note the repo-root `CONFORMANCE.md` in the architecture root-layout (:710) is the same artifact's documented home; AR-16/AR-21 and this AC pin it to **koel_core**. Author it under `packages/koel_core/`. [Source: AC3; architecture :710,:757; AR-21 :151]
- Adding the doc gate makes `koel_test` the **second** member with an `analysis_options.yaml` (after koel_core, Story 2.15) — same plugin-free, root-`include` shape. [Source: koel_core/analysis_options.yaml]

### Previous Story Intelligence
- **3.4 (`ToolHandlerTestHarness`)** — established two things this story inverts/extends: (a) it drove the agent **through `KoelClient`** for subscriber observability; 3.5 drives **directly** because conformance needs the raw emission, not the post-pipeline view (trap #1). (b) It explicitly named the deferrals 3.5 must now deliver: "the member doc-gate `analysis_options.yaml` for `koel_test` is **Story 3.5's** epic-sealing AC" and "do NOT add `koel_test`'s ≥80% coverage gate … all **Story 3.5**." Both are Tasks 8-9 here. 3.4's AC-vs-reality discipline (map aspirational prose to the real shape, bake as RESOLVED) is reused for `actual: AgUiEvent?`. [Source: 3-4 :11-18,120,123; §"Out of scope"]
- **3.3 (`FixtureLoader`)** — the `package:` asset-URI read mechanism (`Isolate.resolvePackageUri` → `File`) the runner mirrors for the expected-corpus read; the enumerated-`ArgumentError` error contract; and the discipline of mapping AC prose to the real API. `loadSynthesized` returns events only (drops the wire `type`), which is **why** the runner reads the raw lines itself for the type label. [Source: 3-3; fixture_loader.dart:110-165]
- **3.2 (synthesized fixtures)** — `all_event_types.jsonl` is the type-coverage corpus (one event per type, incl. `RUN_ERROR`+`RUN_FINISHED` together) the runner uses as `expected`; the `_session` header shape the corpus reader skips. [Source: 3-2; fixtures/synthesized/all_event_types.jsonl]
- **2.15 (`koel_core` finalization)** — the template for **both** finalization gates: koel_core's `analysis_options.yaml` (doc gate, plugin-free, root-include) and `coverage_options.yaml` (generated-exclude), plus the root `test:coverage` 90% awk gate that 3.5 generalizes into `tool/coverage.sh`. [Source: koel_core/analysis_options.yaml, coverage_options.yaml; root pubspec]
- **2.3 / 2.5 (`KoelError` / `RunErrorEvent`)** — `KoelError` is sealed with non-serializable `cause`; `AgentError(message:, code:, cause?, agentCode?)` is the wrap target for a thrown agent error; `RunErrorEvent.error` is the `KoelError` the runner extracts. [Source: koel_error.dart:92-103; run_events.dart:108-160]
- **1.7 (asp lint pivot)** — `plugins:` only at the workspace root; the new `koel_test/analysis_options.yaml` must be **plugin-free** (it `include`s the root). [Source: root analysis_options.yaml; Story 1.7]

### Git Intelligence Summary
HEAD / expected baseline for 3.5 is `d846904` (`feat(story-3.4): ToolHandlerTestHarness fluent builder + ToolHandler typedef`). Epic 3 commits: 3.1 `8c26147` (MockAgent), 3.2 `b28bbbb` (fixtures), 3.3 `5a15a5f` (FixtureLoader + the one `koel_core` `fromWire` seam), 3.4 `d846904` (harness). Each prior story also touched `sprint-status.yaml` — expect the same. **3.5's footprint is the largest of Epic 3** (epic sealer): 2 new lib files + 2 barrel lines + pubspec deps + 2 package-config files + a koel_core doc + a repo tool + a shared coverage script + 2 root-pubspec melos edits + 1 test file (+ doc backfill). Suggested commit: `feat(story-3.5): ConformanceRunner + freezed ConformanceReport, CONFORMANCE.md pin, capture-fixtures scaffold, koel_test finalization gates`. [Source: git log d846904/5a15a5f/b28bbbb/8c26147; epic-3 3.5]

### Latest Tech Information
- **freezed 3.2.6-dev.1 + analyzer 12** — workspace is pinned here (SCP-2026-05-29-B); the lint stack migrated `custom_lint → analysis_server_plugin` (Story 1.7). Use the same pin for koel_test; do not bump. `@freezed` with a `const factory` generates structural `==`/`hashCode`/`copyWith` and `DeepCollectionEquality` over `List`/`Uint8List` fields. [Source: SCP-2026-05-29-B; koel_core/pubspec.yaml]
- **`Stopwatch`** is the monotonic clock for `runDuration` — not `DateTime.now()` diffs (wall-clock, NTP-skewable). [Source: dart:core Stopwatch]
- **`Isolate.resolvePackageUri`** resolves a `package:` URI to a `file:` URI via `package_config.json`, CWD-independent — the same call `FixtureLoader._load` uses; it is the reason a downstream package can read koel_test fixtures from its own root. [Source: fixture_loader.dart:116; dart:isolate]
- **`melos run build`** runs `build_runner build` only in packages that `dependsOn: build_runner` — adding the dev-dep to koel_test auto-includes it (and the `codegen-drift` CI gate `melos run build && git diff --exit-code`). [Source: root pubspec melos.scripts.build; AR-17]

### References
- [epic-3 Story 3.5 spec + ACs (`ConformanceRunner`/`ConformanceReport`/`CONFORMANCE.md`/`capture_fixtures.dart`/coverage)](../planning-artifacts/epics/epic-3-test-harness-conformance-koeltest.md)
- [architecture.md :710,:757 (`CONFORMANCE.md` only in koel_core); :722-727 (repo-level `tool/capture_fixtures.dart`); :958-977 (`koel_test` layout — `conformance_runner.dart # F-G4` :966, `conformance_report.dart` :967); §6 :632-671,:684 (doc + testing + barrel conventions); :1108-1114 (melos test/coverage/conformance)](../planning-artifacts/architecture.md)
- [requirements-inventory.md :64-67 (FR-G1..G4 — FR-G4 is this runner); :108 (NFR-12 coverage tiers — koel_test tooling ≥80%); :140-146 (AR-13/14/16); :208-211 (F-G1/F-G4 epic split); :240 (AR-13/14-scaffold/16 → Epic 3)](../planning-artifacts/epics/requirements-inventory.md)
- [koel_core/lib/src/event/ag_ui_event.dart:48-65 — sealed base, only `fromWire`, no polymorphic `type` (trap #4)](../../packages/koel_core/lib/src/event/ag_ui_event.dart)
- [koel_core/lib/src/event/run_events.dart:1-60 — `@freezed` event template the report types mirror](../../packages/koel_core/lib/src/event/run_events.dart)
- [koel_core/lib/src/event/reasoning_events.dart:179-189 — `Uint8List` byte-deep `==` (the AR-16 equality the CONFORMANCE.md doc cites)](../../packages/koel_core/lib/src/event/reasoning_events.dart)
- [koel_core/lib/src/error/koel_error.dart:92-103 — `AgentError(message:, code:, cause?, agentCode?)` wrap target](../../packages/koel_core/lib/src/error/koel_error.dart)
- [koel_core/lib/src/agent/abstract_agent.dart:10-14 — `run(RunAgentInput) → Stream<AgUiEvent>`; never throws (the SPI the runner hardens against)](../../packages/koel_core/lib/src/agent/abstract_agent.dart)
- [koel_test/lib/src/fixture_loader.dart:83-165 — `loadSynthesized`; the `package:` URI read the corpus reader mirrors (and why the wire `type` is re-read)](../../packages/koel_test/lib/src/fixture_loader.dart)
- [koel_test/lib/koel_test.dart:1-13 — the barrel that gains exports 4 & 5](../../packages/koel_test/lib/koel_test.dart)
- [koel_test/lib/src/fixtures/synthesized/all_event_types.jsonl — the type-coverage corpus (28 types) the runner uses as `expected`](../../packages/koel_test/lib/src/fixtures/synthesized/all_event_types.jsonl)
- [koel_core/analysis_options.yaml + coverage_options.yaml — the doc/coverage gate templates Task 8 mirrors](../../packages/koel_core/analysis_options.yaml)
- [pubspec.yaml (root) melos.scripts — `test:coverage` (koel_core 90% awk) to generalize into `tool/coverage.sh`; where `capture-fixtures` is added](../../pubspec.yaml)
- [3-4-tool-handler-test-harness.md — the deferrals (`analysis_options.yaml`, coverage gate) this story delivers; the drive-via-KoelClient pattern 3.5 inverts](3-4-tool-handler-test-harness.md)

### Design decisions (RESOLVED — AC/architecture-forced, not open)
Baked in so the dev has zero ambiguity. No confirmation gate.
1. **`runAgainst` drives `agent.run(input)` directly, NOT through `KoelClient`** — `all_event_types.jsonl` isn't a valid run; the pipeline would reject it. Conformance = raw emission vs fixture. [trap #1]
2. **Expected corpus = `all_event_types.jsonl`** (one event per AG-UI type) → per-type report falls out. [trap #1; AC1]
3. **`ConformanceFailure.actual: AgUiEvent?`** (nullable) — `null` = type not emitted; non-null = emitted-but-diverged. (AC's non-nullable `AgUiEvent` mapped.) [trap #2]
4. **Type label from fixture wire `payload['type']`; match actual by `runtimeType`; pass/fail by freezed `==`.** No polymorphic `type` getter on `AgUiEvent`; no 29-arm switch; no kernel `type` getter. [trap #4]
5. **freezed-only deps** (`freezed_annotation`/`freezed`/`build_runner`, koel_core pins; **no** `json_serializable`, **no** `build.yaml`). [trap #3]
6. **Doc gate `koel_test/analysis_options.yaml`** (mirror koel_core; plugin-free) + `coverage_options.yaml`; backfill existing 3.1–3.4 dartdocs to keep `analyze` at 0. [trap #5]
7. **Coverage gate via extracted `tool/coverage.sh`**; `test:coverage` checks koel_core 90 + koel_test 80; re-verify koel_core unbroken. [trap #6]
8. **`CONFORMANCE.md` is the only koel_core change** (doc): placeholder SHA + `AgUiEvent_equal` rule + OQ-Conformance-Equivalence (resolves pre-v1.0.0). [trap #7; AC3]
9. **`tool/capture_fixtures.dart`** repo-level scaffold, zero-dep `dart:io`, `--backend=` manual parse, `// TODO(Epic 5):` → 5.3/5.6/5.9; `capture-fixtures` melos script in root `pubspec.yaml`. [AC4]
10. **`agentName = agent.runtimeType.toString()`; `runDuration` via `Stopwatch`.** [AC2]

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (via `/agent-flutter-engineer` specialist, per CLAUDE.md).

### Debug Log References

- `melos run analyze` — initially surfaced 16 `comment_references` issues the newly-enabled `koel_test` doc gate exposed: record-field refs (`[events]`/`[error]`/`[elapsed]`/`[label]`/`[event]` in the two new typedef docs, plus `[event]`/`[delay]` in `mock_agent.dart`'s pre-existing `_TimedEvent` doc) and one cross-file `[MockAgent]` ref in `fixture_loader.dart` (which doesn't import `mock_agent.dart`). Fixed docs-only by switching unresolvable `[name]` refs to backticks. Re-run: **0 issues** workspace-wide.
- `melos run build` — non-interactive runs need `--no-select` now that two packages (koel_core, koel_test) match `dependsOn: build_runner`; bare `melos run build` prompts for a package and dies on `StdinException` in a non-tty. CI sets `CI=true` so melos auto-runs all; the gate itself is unaffected.

### Completion Notes List

- **AC1** — `ConformanceRunner.runAgainst(AbstractAgent)` drives `agent.run(input)` **directly** (not via `KoelClient`), reads the wire-type label from each `all_event_types.jsonl` line's `payload['type']`, matches actual emission by `runtimeType`, decides pass/fail by freezed `==`. 28 types reported per-type.
- **AC2** — `ConformanceReport` (passed/failed/agentName/runDuration) + `ConformanceFailure` (eventType/expected/actual/error) are freezed-only. `actual: AgUiEvent?` (RESOLVED nullable: `null` = type not emitted, non-null = emitted-but-diverged). No `json_serializable`; only generated artifact is `conformance_report.freezed.dart` (gitignored).
- **AC3** — `koel_core/CONFORMANCE.md` (the only koel_core touch — a doc): pins AG-UI `release/2026-05-26` with a placeholder SHA (marked finalized-at-v1.0.0 per SC-1), documents the `AgUiEvent_equal` rule (freezed `==` incl. byte-equal `Uint8List`), records OQ-Conformance-Equivalence as open-until-v1.0.0.
- **AC4** — `tool/capture_fixtures.dart` (repo-level, zero-dep `dart:io`, manual `--backend=` parse): 4 backends with `TODO(Epic 5):` markers → agno 5.3, langgraph 5.6, dojo+copilotkit_runtime 5.9. Recognized backend → `wired in Epic 5 Story <N>` exit 0; unknown/absent → usage + exit 2. `capture-fixtures` melos script added to root `pubspec.yaml > melos.scripts` (Melos 7.x reads scripts from pubspec, not melos.yaml).
- **AC5** — koel_test coverage **95.24% line / 91.94% branch** (≥80% tooling tier). Coverage gate extracted to `tool/coverage.sh <pkg> <line%> <branch%>`; root `test:coverage` calls it twice. koel_core regression intact: **98.85% line / 97.87% branch** (≥90%).
- **Finalization gates** — `koel_test/analysis_options.yaml` (doc gate, plugin-free, mirrors koel_core) + `coverage_options.yaml` enabled; pre-existing 3.1–3.4 doc-reference gaps backfilled (docs-only).
- **Error channel** — `_drive` captures the first `RunErrorEvent.error`; defensively wraps a thrown non-`KoelError` as `AgentError(unknown)` (covers a buggy agent violating the never-throw SPI). `Stopwatch` (monotonic) times the drive.
- **Quality gates all green:** build (no drift) · analyze (0 issues) · test (workspace green, +6 new) · test:coverage (both tiers) · format:check (clean) · capture-fixtures (exit 0).

### File List

**New**
- `packages/koel_test/lib/src/conformance_report.dart` — `@freezed ConformanceReport` + `ConformanceFailure`.
- `packages/koel_test/lib/src/conformance_runner.dart` — `final class ConformanceRunner` (drive-direct, wire-label, runtimeType-match).
- `packages/koel_test/analysis_options.yaml` — doc gate (mirror koel_core, plugin-free).
- `packages/koel_test/coverage_options.yaml` — exclude generated from coverage.
- `packages/koel_test/test/conformance_runner_test.dart` — all-pass / missing / diverged / run-error / throwing / value-semantics.
- `packages/koel_core/CONFORMANCE.md` — spec-SHA pin (placeholder) + `AgUiEvent_equal` rule + OQ. (Only koel_core touch.)
- `tool/capture_fixtures.dart` — repo-level capture scaffold; 4 backends → 5.3/5.6/5.9.
- `tool/coverage.sh` — parameterized coverage gate.

**Modified**
- `packages/koel_test/lib/koel_test.dart` — +2 exports (report, runner).
- `packages/koel_test/pubspec.yaml` — +`freezed_annotation` dep; +`build_runner`,`freezed` dev-deps (exact koel_core pins).
- `packages/koel_test/lib/src/mock_agent.dart` — docs only (`_TimedEvent` ref → backticks).
- `packages/koel_test/lib/src/fixture_loader.dart` — docs only (`[MockAgent]`/ctor backfill).
- `pubspec.yaml` (root) — `test:coverage` → `tool/coverage.sh` ×2; +`capture-fixtures` script.
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 3-5 → in-progress → review.

**Generated (gitignored, not committed)**
- `packages/koel_test/lib/src/conformance_report.freezed.dart`.

### Review Findings

Code review 2026-05-31 (3 adversarial layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor). **All 5 ACs confirmed met, zero violations.** 0 decision-needed, 0 patch, 3 deferred, 15 dismissed (incl. one false positive — a synchronous throw from `agent.run()` IS caught, since the call is evaluated inside the `try`'s `await for`; and one AC1-misread — per-type matching against a one-event-per-type corpus is the design, not a "multiplicity-blind" bug).

- [x] [Review][Defer] Divergent `actual` is an arbitrary `sameType.first` when an agent emits multiple same-type events [`packages/koel_test/lib/src/conformance_runner.dart:74`] — deferred: skeleton does exact per-type comparison; multi-emit attribution is part of OQ-Conformance-Equivalence (Epic 5 real-backend normalization). The fixture corpus has 28 distinct runtimeTypes, so the path is unreached by the in-Epic-3 MockAgent tests. (Blind + Edge)
- [x] [Review][Defer] `skip(1)` positionally trusts the `_session` header line [`packages/koel_test/lib/src/conformance_runner.dart` `_loadExpectedCorpus`] — deferred: Edge layer verified line 1 IS the `_session` header on the bundled fixture and `skip(1)` drops exactly it; mirrors `FixtureLoader._load`'s documented pattern. Header-shape validation is optional hardening, not a bug. (Blind, downgraded by Edge)
- [x] [Review][Defer] Unguarded `as Map`/`as String`/`jsonDecode` on the bundled corpus → opaque `TypeError`/`FormatException` with no line context [`packages/koel_test/lib/src/conformance_runner.dart` `_loadExpectedCorpus`] — deferred: reads koel_test's own shipped, tested asset (the all-pass test fails loudly if it breaks); same class as the already-accepted 3.3 deferral on `fixture_loader.dart`. Revisit alongside Epic 5 live captures. (Edge)

## Change Log

| Date | Change |
|------|--------|
| 2026-05-31 | Implemented Story 3.5 (review): `ConformanceRunner` + freezed `ConformanceReport`/`ConformanceFailure`; `koel_core/CONFORMANCE.md` spec-pin + `AgUiEvent_equal` rule; `tool/capture_fixtures.dart` scaffold + `capture-fixtures` melos script; koel_test finalization gates (doc gate + `tool/coverage.sh` 80% tier). All ACs satisfied; all gates green (analyze 0, coverage koel_core 98.85/97.87, koel_test 95.24/91.94). Doc-only backfill on mock_agent/fixture_loader for new `comment_references` gate. |
| 2026-05-31 | Created Story 3.5 context (ready-for-dev): `ConformanceRunner` + freezed `ConformanceReport`/`ConformanceFailure` in `koel_test`; `koel_core/CONFORMANCE.md` spec-pin + `AgUiEvent_equal` rule; `tool/capture_fixtures.dart` scaffold + `capture-fixtures` melos script; `koel_test` finalization gates (doc gate `analysis_options.yaml` + ≥80% coverage via extracted `tool/coverage.sh`). Resolved AC-vs-reality mappings (`actual: AgUiEvent` → `AgUiEvent?`; `melos.yaml` script → `pubspec.yaml > melos.scripts`; per-package coverage → extended `test:coverage` tier). Drive-direct (not via `KoelClient`) + wire-type label + freezed-only deps baked as RESOLVED. |
