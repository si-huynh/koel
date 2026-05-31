---
baseline_commit: b4f86bf
---

# Story 2.15: Performance baselines + dartdoc + barrel finalize

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this story touches `.dart` files (bench harnesses), the package's public-API barrel, dartdoc contracts, melos script wiring, and `dart_apitool` API extraction. **Invoke `/agent-flutter-engineer` before producing any code** (per CLAUDE.md). This is the **Epic 2 sealing story** — it does NOT add behavior; it locks the 1.x contract and stands up the regression scaffolding. Four disciplines are load-bearing, and three are *non-obvious traps*:
> 1. **The barrel is a one-way door (AR: API surface).** `lib/koel_core.dart` must export **exactly** the consumable surface from PRD §9 + Addendum §A — *no more, no less* (AC4). Over-exporting an internal (the pipeline stages, the event deserializer, `JsonPatch`, `JsonPointer`, `stage_support`) bakes it into the 1.x contract permanently and `dart_apitool` will pin it. Under-exporting is recoverable in a 1.x minor; over-exporting needs a 2.0.0. **When unsure, leave it out.** See §"The barrel: export exactly the contract".
> 2. **`MockAgent.empty` does NOT exist** (same trap as 2.14). AC2 says `cold_start_bench` runs against `MockAgent.empty`, but `MockAgent` is **Story 3.1** in the still-empty `koel_test` package. **Do not import or build it.** Use a private inline `AbstractAgent` empty double (mirror `test/agent/abstract_agent_test.dart`'s `_FakeAgent`). See §"The MockAgent trap (again)".
> 3. **Perf benches must not be flaky** (convention §6: "A test that occasionally fails is a bug"). A naive `expect(p99 < baseline*1.10)` that runs on every `dart test` will flap on a loaded laptop. The bench **records-or-passes** by default and only **enforces** the >10% gate when `KOEL_PERF_GATE` is set (the CI reference-device path, wired in Epic 9's `perf-bench.yml`). This is faithful to NFR-2's own framing ("Tracked per-PR in CI … on the CI reference device profile"). See §"Perf benches: record-or-gate, never flake".
> 4. **`melos run test` / `test:coverage` are stubs that literally say "wired in story 2.15"** (root `pubspec.yaml` `melos.scripts`). AC5 requires `melos run test:coverage` to produce a real ≥ 90% line+branch number. Wiring them is **in scope**; the `dart test` script must run with CWD = package root (`exec`) to keep the CWD-sensitive fixture reads working (`full_event_sweep_test.dart:14`, `rfc6902_conformance_test.dart:22`). See §"Wiring the melos test scripts".

## Story

As a release manager,
I want `koel_core` to ship perf bench harnesses (`reducer_bench.dart`, `cold_start_bench.dart`) capturing v1.0.0 baselines + every public symbol carrying a contract-form dartdoc + a finalized barrel `lib/koel_core.dart`,
so that NFR-2 + NFR-4 regression-relative SLOs are enforceable and the 1.x public contract is sealed per AR-15 + AR-21 + NFR-13.

## Acceptance Criteria

Verbatim from [epic-2 Story 2.15](../planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md):

1. **Given** `koel_core/test/perf/reducer_bench.dart`, **When** I run `dart test test/perf/reducer_bench.dart --reporter=expanded`, **Then** the harness measures p99 reduce-time per event across the synthesized 28-event sweep and writes baseline numbers to `koel_core/test/perf/baselines/reducer_bench.json`, **And** subsequent runs compare against the baseline and fail when regression > 10% per NFR-2.

2. **Given** `koel_core/test/perf/cold_start_bench.dart`, **When** I run it, **Then** it measures the time from `KoelClient(...)` constructor return to first event subscription readiness against `MockAgent.empty`, **And** writes baseline to `cold_start_bench.json` with the same > 10% regression gate per NFR-4.

3. **Given** every public symbol in `lib/koel_core.dart`, **When** I run `dart doc`, **Then** every exported class, method, getter, enum value carries a contract-form dartdoc (one-line summary + when-to-use / when-not / error cases / example) per architecture convention §6 + PRD §13 D-2, **And** `dart doc` exits 0 with no missing-doc warnings.

4. **Given** `lib/koel_core.dart`, **When** I inspect the barrel, **Then** it exports exactly the surface listed in PRD §9 + Addendum A.1 — no more, no less, **And** `dart_apitool extract` produces a baseline diffable in Epic 9 per AR-12, **And** `melos run analyze` exits 0 across the package per NFR-13.

5. **Given** the full `koel_core` test suite, **When** I run `melos run test:coverage` for the package, **Then** line + branch coverage ≥ 90% per NFR-12.

> **On AC2's `MockAgent.empty`:** the wire is correct, the symbol is not yet real. `MockAgent` is **Story 3.1** (`koel_test`, an empty barrel today). Satisfy AC2 with a **private inline `AbstractAgent` double** that yields an empty stream — mirror `test/agent/abstract_agent_test.dart`'s `_FakeAgent`. When 3.1 ships `MockAgent.empty`, the bench can be re-pointed; 2.15 measures cold-start against the inline empty agent. [Source: 2-14 §"The MockAgent trap"; abstract_agent_test.dart:8-11]

## Tasks / Subtasks

- [x] **Task 1 — Finalize the barrel `lib/koel_core.dart` to the exact public contract** (AC: #4)
  - [x] Replace the current placeholder barrel (today: just `library;` + a header doc, **zero exports**) with the explicit export list in §"The barrel: export exactly the contract". Use a `///` library-level doc + ordered `export 'src/...';` directives grouped by subsystem (client, agent, event, error, state, session, input, message, tool, json_patch). **freezed `part` files ride along automatically** — never export a `*.freezed.dart`/`*.g.dart` directly. [Source: PRD §9 :211-230; addendum §A; architecture §6 "Single barrel file per package" :684]
  - [x] **Export exactly the consumable surface.** Cross-check every `export` against the §"export / do-NOT-export" table. The disaster to prevent: exporting an internal (`pipeline/*`, `event/event_codec.dart`, `event/event_deserializer.dart`, `json_patch/json_patch.dart`, `json_patch/json_pointer.dart`, `pipeline/stage_support.dart`) — these are the kernel's machinery, not its contract, and `dart_apitool` (Task 4) will freeze whatever leaks. [Source: AC4 "no more, no less"; PRD §9 :209 "every public name … is a one-way door"]
  - [x] **`JsonPatch` (the applier) and `JsonPointer` stay internal; `JsonPatchOp` + its subtypes are exported** because they appear in public signatures (`StateDeltaEvent.patches: List<JsonPatchOp>`, `StateConflict.incomingPatches: List<JsonPatchOp>`). `JsonPatch` appears nowhere in PRD §9 or Addendum §A — leaving it out is the contract-correct, reversible choice. [Source: PRD §9 :211-230 (no `JsonPatch`); addendum §A (no `JsonPatch` symbol); state_events.dart `StateDeltaEvent`; state_conflict.dart]
  - [x] After writing the barrel, run `dart analyze packages/koel_core` and confirm no `unused_import`-style or export-collision diagnostics, and that nothing previously-private is now needed-but-missing by a consumer (there are no in-repo consumers yet; this is the contract for Epics 3-9).

- [x] **Task 2 — Contract-form dartdoc sweep over the full barrel surface** (AC: #3)
  - [x] Walk **every exported symbol** (class, public method, getter, enum, enum value, named constructor) reachable through the Task-1 barrel and ensure it carries a **contract-form** `///` doc per convention §6: one-line summary → blank → contract (what it represents / when to use / when NOT / error cases) → blank → `///` example block or `[See also]` link. Most symbols already carry docs (written per-story 2.1-2.14); this task **fills gaps and upgrades restatement-style docs to contract-form**. Do **not** doc-comment private (`_`) or generated (`*.freezed.dart`/`*.g.dart`) members. [Source: architecture §6 :632-639; PRD §13 D-2]
  - [x] **Stand up the doc-coverage gate (scoped to koel_core).** Add `packages/koel_core/analysis_options.yaml`:
    - `include: ../../analysis_options.yaml` (inherit the workspace `recommended.yaml` + the asp `exhaustive_switch_must_have_default` plugin — do **not** re-declare `plugins:`; the analyzer rejects it in a member file, `plugins_in_inner_options`).
    - `analyzer: exclude: ['**/*.freezed.dart', '**/*.g.dart']` (generated code is not part of the documented contract and would otherwise trip the doc lint).
    - `linter: rules: { public_member_api_docs: true, comment_references: true }` — `public_member_api_docs` is the machine enforcer of AC3's "every public symbol documented"; `comment_references` keeps `[Type]` links in dartdoc resolvable so `dart doc` stays warning-clean.
    - **Why a member file, given Story 1.7's "members carry no `analysis_options.yaml`" design:** that convention exists so `plugins:` lives only at the root (analyzer constraint). This file declares **no plugins** — it only adds package-finalization lint rules and a generated-file exclude. It is a justified, plugin-free exception, not a reversal of 1.7. Other packages stay undocumented-gate-free until their own finalize story. [Source: root analysis_options.yaml comment; architecture §6 :635; project memory: lint pivot to analysis_server_plugin]
  - [x] Run `dart doc` from `packages/koel_core` → **exits 0, no warnings** (fix any unresolved `[references]` or ambiguous-reexport warnings the barrel introduces). Run `dart analyze` → 0 issues incl. the new `public_member_api_docs`. [Source: AC3]

- [x] **Task 3 — `reducer_bench.dart` (N-2 p99 reduce-time baseline)** (AC: #1)
  - [x] New file `packages/koel_core/test/perf/reducer_bench.dart` (new `test/perf/` dir per architecture layout :819-821). A `package:test` file (one top-level `group('reducer_bench', …)`), runnable as `dart test test/perf/reducer_bench.dart --reporter=expanded`.
  - [x] **Workload:** the **28-event sweep**. Load it the same way `test/event/full_event_sweep_test.dart` does (read `test/event/full_event_sweep.jsonl`, deserialize each line via the existing event deserializer). Construct one `DefaultChatStateReducer` and a seed `const ChatState()`. **The bench measures `reducer.reduce(state, event)` per event**, not the pipeline. [Source: AC1 "p99 reduce-time per event across the synthesized 28-event sweep"; full_event_sweep_test.dart load pattern; NFR-2 :294]
  - [x] **Measurement:** warm up (e.g. ≥ 200 untimed folds of the full sweep to let the JIT settle), then time a large number of folds (e.g. N iterations × 28 events), recording per-event durations with `Stopwatch` (`elapsedMicroseconds`). Compute **p99** across the sample. Avoid allocation in the hot loop beyond what `reduce` itself does (purity means each `reduce` allocates a fresh `ChatState` — that allocation IS part of the measured cost). [Source: NFR-2 "p99 reduce time per event"]
  - [x] **Baseline I/O:** write/read `test/perf/baselines/reducer_bench.json` (e.g. `{ "p99_micros": <num>, "sample_size": <n>, "recorded_dart": "<Platform.version>" }`). **Record-or-gate** (see §"Perf benches: record-or-gate, never flake"):
    - If the baseline file is **absent** OR env `KOEL_PERF_UPDATE` is set → measure, **write** the baseline, pass (this is how the v1.0.0 baseline is first captured and committed).
    - If env `KOEL_PERF_GATE` is set → measure, read baseline, **`expect(p99 <= baseline.p99 * 1.10)`** and fail on regression > 10%.
    - Otherwise (default local `dart test`) → measure, **log** the p99 vs baseline delta, **pass unconditionally** (never flake).
  - [x] **Commit the captured baseline JSON** (it is the v1.0.0 reference Epic 9's `perf-bench.yml` will gate against). Add a one-line dartdoc atop the file explaining the record/gate/update env contract.

- [x] **Task 4 — `cold_start_bench.dart` (N-4 cold-start baseline)** (AC: #2)
  - [x] New file `packages/koel_core/test/perf/cold_start_bench.dart`, same `package:test` + record-or-gate shape as Task 3, baseline at `test/perf/baselines/cold_start_bench.json`.
  - [x] **Define the measured interval precisely** (AC2: "from `KoelClient(...)` constructor return to first event subscription readiness against `MockAgent.empty`"): start the `Stopwatch` immediately **before** `KoelClient(agent: _EmptyAgent())`, stop it the moment a subscription to a post-pipeline stream is live and ready to receive — i.e. `client.newSession().stream.listen((_){})` returns a non-null `StreamSubscription` (or, equivalently, `client.runRaw(emptyInput).listen((_){})`). Pick **one** definition, document it in the file's dartdoc, and keep it stable (the number is only meaningful against itself). [Source: AC2; NFR-4 :296 "time from `KoelClient(...)` constructor return to first event subscription readiness"]
  - [x] **`_EmptyAgent`** = a private inline `AbstractAgent` whose `run` yields nothing (`async* { }` or `Stream.empty()`). **Do NOT import/build `MockAgent`** — it is Story 3.1 / empty `koel_test`. Mirror `abstract_agent_test.dart:8-11` (`_FakeAgent`). [Source: §"The MockAgent trap (again)"; 2-14 Design Decision 1]
  - [x] Warm up, then time many cold-start cycles (fresh `KoelClient` each iteration — cold start means a *new* client, so do not reuse), compute p99 (or median + p99), write/compare per the record-or-gate contract. **Dispose each client** after measuring to avoid leaking `StreamController`s across iterations. Commit the captured baseline JSON.

- [x] **Task 5 — Wire the `melos run test` + `test:coverage` scripts** (AC: #5)
  - [x] In the **root** `pubspec.yaml` `melos.scripts`, replace the two stubs (currently `run: dart --version`, described "wired in story 2.15") with real bodies:
    - `test`: `exec: dart test` (per-package; `exec` sets CWD = each package root, which is **required** so the CWD-sensitive fixture reads in `full_event_sweep_test.dart:14` and `rfc6902_conformance_test.dart:22` resolve). Consider a `--exclude-tags=perf` (and tag the two bench files `@Tags(['perf'])`) so the perf benches don't run in the default `test` pass — they are baseline tools, not unit tests, and would slow `melos run test`. [Source: deferred-work.md :158 CWD-sensitivity; root pubspec melos.scripts stubs; convention §6 test conventions]
    - `test:coverage`: per-package `dart test --coverage=coverage` then `format_coverage` (via the already-present `coverage 1.15.0` dev tool) to LCOV, **excluding generated files**, then assert the koel_core line+branch ≥ 90%. Use the established mechanism — a `coverage_options.yaml` per package (architecture §6 :662-664) ignoring `*.g.dart`/`*.freezed.dart`/`*.mocks.dart`, honored by the coverage tooling. Keep the script package-scoped or filtered so it produces a koel_core number AC5 can read. [Source: PRD SC-2 :64 "package:coverage aggregated via Melos; generated files excluded"; architecture §6 :662-664; §"Wiring the melos test scripts"]
  - [x] Add `packages/koel_core/coverage_options.yaml` with the generated-file ignore list (if `format_coverage --ignore-files` is used instead, document that — but the per-package `coverage_options.yaml` is the architecture-blessed mechanism).
  - [x] **Do NOT add `melos run perf` / `melos run api-diff` scripts** and **do NOT touch** `.github/workflows/perf-bench.yml` / `api-diff.yml` — those CI bodies are explicitly **Epic 9** (the placeholder workflows say "Wired in Epic 9"; Epic 9 stories `9-3`/`9-4` own them). 2.15 produces the *artifacts* (bench baselines + apitool baseline); Epic 9 wires the *gates*. [Source: perf-bench.yml/api-diff.yml placeholders; epic-9 stories 9-3/9-4; deferred-work.md :85]

- [x] **Task 6 — `dart_apitool` API-surface baseline (AR-12 / D7)** (AC: #4)
  - [x] Activate the tool **globally** (isolated from the workspace's analyzer-12 hold — global activation carries its own pubspec, so the freezed↔asp analyzer pin does NOT constrain it): `dart pub global activate dart_apitool 0.23.1`. [Source: architecture §362 "dart_apitool: ^0.23.1"; project memory: analyzer-12 stopgap is a *workspace* constraint, global activation is independent]
  - [x] Run `dart_apitool extract` against `packages/koel_core` to produce the public-surface baseline artifact, and **commit it** where Epic 9's `api-diff.yml` will diff against it (e.g. `packages/koel_core/.api-baseline/koel_core.json` — confirm the path/format `9-3-dart-apitool-baselines-ci-gate` expects; if unspecified there, choose `.api-baseline/` and note it in `deferred-work.md` so 9-3 reads from the same place). The artifact must reflect **only** the Task-1 barrel surface — run extract *after* the barrel is final. [Source: AC4 "dart_apitool extract produces a baseline diffable in Epic 9"; architecture :362-369, :726 `tool/verify_api_surface.dart`]
  - [x] If `dart_apitool 0.23.1` cannot extract against this package on the current SDK (3.12) — verify, don't assume — capture the exact failure, record it in `deferred-work.md` as a precise hand-off to `9-3`, and satisfy AC4's intent by committing a hand-verified surface manifest (the barrel export list) as the interim baseline. **Do not fabricate** a passing extract. [Source: project memory "Confirmed needs adversarial evidence"; architecture §362]

- [x] **Task 7 — Quality gates** (AC: all)
  - [x] `melos run analyze` → **0 issues** workspace-wide, including the new `public_member_api_docs` on koel_core. [Source: AC4 / NFR-13]
  - [x] `melos run test` → all green (existing ~572 tests, perf benches excluded via the `perf` tag). **No regressions** from the barrel exports or the new member `analysis_options.yaml`. [Source: AC5]
  - [x] `melos run test:coverage` → koel_core line + branch ≥ **90%** (N-12). The perf benches themselves need not be coverage-counted (they are tooling); the barrel adds no new logic to cover. [Source: AC5 / NFR-12 :315]
  - [x] `dart format --set-exit-if-changed .` (via `melos run format:check`) → clean. The perf benches and the barrel are hand-written Dart subject to formatting. [Source: convention; tool/format.sh]
  - [x] `dart doc` (from `packages/koel_core`) → exits 0, no warnings. [Source: AC3]
  - [x] `dart test test/perf/reducer_bench.dart` and `…/cold_start_bench.dart` each run green and (re)write their baseline JSON on a clean checkout (record path). [Source: AC1/AC2]
  - [x] Confirm **no behavior change**: the only production-`lib/` edit is `lib/koel_core.dart` (barrel exports — no logic). No `lib/src/**` file changes; no `pubspec.yaml` dependency additions (the bench harnesses use `package:test` + `dart:io` for baseline JSON; `coverage` is already a dev tool; `dart_apitool` is a global, not a dependency). [Source: §"Files you will touch"]

## Dev Notes

### What this story is, in one paragraph
This is the **finalizer of Epic 2**, not a feature. Epic 2 shipped the entire protocol kernel across 2.1-2.14; 2.15 **seals** it: (1) publishes the public-API barrel (`lib/koel_core.dart`) as the exact 1.x contract, (2) brings every exported symbol to contract-form dartdoc and gates it with `public_member_api_docs`, (3) stands up two regression-relative perf benches (`reducer_bench`/`cold_start_bench`) that record committed v1.0.0 baselines and gate >10% regressions on the CI reference device, (4) extracts the `dart_apitool` API baseline Epic 9 will diff against, and (5) wires the two stubbed melos test scripts so `melos run test:coverage` proves the ≥90% tier. **Zero new behavior, zero new `lib/src` logic, zero new runtime dependency.** The risk profile is entirely "lock the right contract and don't introduce a flaky gate." [Source: epic-2 Story 2.15 :364-396; architecture §6, §10]

### The barrel: export exactly the contract (the heart of this story)
The current `lib/koel_core.dart` is a placeholder (`library;` + a one-line header, **no exports**). Replace it with an ordered export list. The decisive rule (AC4): **export exactly PRD §9 + Addendum §A — no more, no less.** `dart_apitool` (Task 6) freezes whatever you export into the diff baseline, so a leaked internal becomes a permanent 1.x obligation.

**Export these source files** (the freezed `part` `*.freezed.dart`/`*.g.dart` come along automatically — never list them):

| Subsystem | File(s) to `export` | Public symbols surfaced |
|---|---|---|
| client | `src/client/koel_client.dart` | `KoelClient`, `BackpressurePolicy` (ctor param type — consumers must name it) |
| client | `src/client/chat_session.dart` | `ChatSession` |
| agent | `src/agent/abstract_agent.dart` | `AbstractAgent` (SPI — `interface class`) |
| agent | `src/agent/interceptor.dart` | `Interceptor`, `InterceptorChain` |
| agent | `src/agent/agent_subscriber.dart` | `AgentSubscriber` |
| event | `src/event/ag_ui_event.dart` | `AgUiEvent` (sealed root) |
| event | `src/event/unknown_event.dart` | `UnknownAgUiEvent` |
| event | `src/event/run_events.dart`, `step_events.dart`, `text_message_events.dart`, `tool_call_events.dart`, `state_events.dart`, `activity_events.dart`, `reasoning_events.dart`, `raw_event.dart`, `custom_event.dart` | all ~28 concrete `AgUiEvent` subtypes |
| error | `src/error/koel_error.dart` | `KoelError`, `TransportError`, `ProtocolError`, `AgentError`, `BusinessError` |
| error | `src/error/koel_error_code.dart` | `KoelErrorCode` |
| error | `src/error/error_classifier.dart` | `ErrorClassifier`, `DefaultErrorClassifier` |
| state | `src/state/chat_state.dart` | `ChatState`, `RunPhase` |
| state | `src/state/chat_state_reducer.dart` | `ChatStateReducer`, `DefaultChatStateReducer` |
| state | `src/state/composed_reducer.dart` | `ComposedReducer` |
| state | `src/state/state_conflict.dart` | `StateConflict`, `StateConflictResolver`, `LastWriterWinsResolver` |
| state | `src/state/tool_call.dart` | `ToolCall` (reachable via `ChatState.pendingToolCalls`) |
| session | `src/session/session_storage.dart` | `SessionStorage` |
| session | `src/session/in_memory_session_storage.dart` | `InMemorySessionStorage` |
| input | `src/input/run_agent_input.dart` | `RunAgentInput` |
| message | `src/message/message.dart` | `Message`, `MessageRole` |
| tool | `src/tool/tool_definition.dart` | `ToolDefinition` |
| json_patch | `src/json_patch/json_patch_op.dart` | `JsonPatchOp` + `AddOp`/`RemoveOp`/`ReplaceOp`/`MoveOp`/`CopyOp`/`TestOp` (reachable via `StateDeltaEvent.patches` + `StateConflict.incomingPatches`) |

**Do NOT export (internal machinery — keep `lib/src` private):**

| File | Why internal |
|---|---|
| `src/pipeline/pipeline.dart` (`runPipeline`), `apply_stage.dart` (`applyStage`/`reducingApplyStage`), `chunks_stage.dart`, `verify_stage.dart`, `transform_stage.dart`, `stage_support.dart` (`PipelineStage`/`buildStage`) | The pipeline is the kernel's mechanism; consumers reach it through `KoelClient`/`ChatSession`/`runRaw`. Not in PRD §9. |
| `src/event/event_codec.dart`, `src/event/event_deserializer.dart` | Internal deserialization dispatcher / `eventTypeRegistry`. Consumers receive typed events from the stream, never deserialize directly. Not in §9. |
| `src/json_patch/json_patch.dart` (`JsonPatch.apply`), `src/json_patch/json_pointer.dart` | The patch *applier* + pointer helper are used internally by the reducer. Absent from §9 and Addendum §A → keep internal (under-exporting is a recoverable 1.x-minor addition; over-exporting needs 2.0.0). |

**The one genuine judgment call — `JsonPatch`:** it is the patch *engine*. A power user might want to apply patches manually, but PRD §9 and Addendum §A name neither `JsonPatch` nor `JsonPointer`. Per AR ("API surface is a one-way door — design for what users *can't* misuse") and AC4's "no more," **leave them internal.** If a real consumer need surfaces in Epic 4-9, exporting `JsonPatch` is a non-breaking 1.x minor; pulling it back is not. [Source: PRD §9 :211-230; addendum §A; CLAUDE.md always-on principles]

### The MockAgent trap (again — RESOLVED, Design Decision 1)
AC2 names `MockAgent.empty`. **`MockAgent` does not exist** — it is Story 3.1 in `koel_test` (today `packages/koel_test/lib/koel_test.dart` = `library;` and nothing else). 2.14 hit the identical trap with `MockAgent.fromEvents` and resolved it with a private inline `AbstractAgent` double. Do the same: `cold_start_bench.dart` defines a private `_EmptyAgent implements AbstractAgent` yielding an empty stream (mirror `test/agent/abstract_agent_test.dart:8-11` `_FakeAgent`). **Do not import `package:koel_test` and do not build `MockAgent`** — wrong package, pre-empts 3.1, and crosses the barrel boundary. When 3.1 ships `MockAgent.empty`, the bench can adopt it; the inline double is the in-package measurement for now. [Source: 2-14 §"The MockAgent trap"; koel_test empty barrel; architecture adapter boundary :1043-1045]

### Perf benches: record-or-gate, never flake (RESOLVED, Design Decision 2)
Two hard constraints collide:
- **AC1/AC2:** "subsequent runs compare against the baseline and fail when regression > 10%."
- **Convention §6:** "No flaky tests. A test that occasionally fails is a bug." A wall-clock `expect(p99 < baseline*1.10)` running on every developer laptop **will** flap under load.

NFR-1..N-5 resolve the tension in their own words: the gate is **"Tracked per-PR in CI … on the CI reference device profile"** (PRD §10.1 :291-296). So the gate belongs to the *reference device*, not the local run. The bench therefore has three modes:
1. **Baseline absent / `KOEL_PERF_UPDATE` set** → measure, write baseline JSON, pass. (How v1.0.0 baselines are captured + committed.)
2. **`KOEL_PERF_GATE` set** (the CI reference-device path, wired by Epic 9 `perf-bench.yml`) → measure, `expect(p99 <= baseline*1.10)`, fail on regression.
3. **Default local `dart test`** → measure, log the delta, pass unconditionally. Never flakes.

This satisfies AC1/AC2 literally (the gate exists and fires where NFR-2 says it should) and convention §6 (the default run can't flap). Document the env contract in each bench file's dartdoc. **Tag both files `@Tags(['perf'])`** and exclude them from `melos run test` so they don't slow the unit pass (they are baseline tools, run on demand / in the perf job). [Source: PRD §10.1 :289-296; architecture §6 :660-661 "No flaky tests"; epic-2 AC1/AC2 :372-380]

### Wiring the melos test scripts (RESOLVED, Design Decision 3)
The root `pubspec.yaml` `melos.scripts` has two stubs whose descriptions literally read **"wired in story 2.15"** (`test:` and `test:coverage:`, both `run: dart --version`). This is 2.15's explicit hand-off. Replace them:
- **`test`** → `exec: dart test` (NOT `run:`). `exec` runs per-package with **CWD = the package root**, which is mandatory: `full_event_sweep_test.dart:14` and `rfc6902_conformance_test.dart:22` read fixtures via package-relative `File('test/...')` paths and throw `FileSystemException` if CWD is the repo root (reproduced both ways in `deferred-work.md` :158). Exclude perf via `--exclude-tags=perf`.
- **`test:coverage`** → `dart test --coverage=coverage` + `package:coverage`'s `format_coverage` → LCOV, generated files excluded via per-package `coverage_options.yaml` (architecture §6 :662-664), then a ≥90% line+branch assertion for koel_core (AC5 / N-12). `coverage 1.15.0` is already available; **no new dependency**. Keep `koel`/scaffold packages out of the threshold check or filter to koel_core (the only package with real coverage today).

**Do NOT** invent `perf`/`api-diff` melos scripts or edit the placeholder CI workflows — Epic 9 owns those (`perf-bench.yml`/`api-diff.yml` say "Wired in Epic 9"; stories `9-3`/`9-4`). [Source: root pubspec melos.scripts; deferred-work.md :158, :85; architecture §10 :1110-1116]

### dartdoc enforcement — why a koel_core member `analysis_options.yaml` (RESOLVED, Design Decision 4)
AC3 demands "every public symbol carries a contract-form dartdoc … `dart doc` exits 0 with no missing-doc warnings." The active workspace lints (`recommended.yaml` + the single asp rule) do **not** include `public_member_api_docs` — so nothing currently *enforces* the doc contract. Add a **koel_core-scoped** `analysis_options.yaml` that `include:`s the root and turns on `public_member_api_docs` + `comment_references`, plus an `analyzer: exclude:` for generated files (else the doc lint fires on `*.freezed.dart`). This is NOT a reversal of Story 1.7's "no member options" design — that design exists so `plugins:` lives only at the root (an analyzer hard-constraint); this file declares **no plugins**, only finalize-stage lint rules. Scope it to koel_core so the in-flight scaffold packages don't get a premature doc gate. `dart doc` itself doesn't emit missing-doc warnings (it warns on broken refs / ambiguous reexports); `public_member_api_docs` is the real "every symbol documented" enforcer, and `comment_references` keeps `dart doc` warning-clean. [Source: root analysis_options.yaml; architecture §6 :635, :662-664; project memory: lint pivot to analysis_server_plugin]

### Out of scope — do NOT build these (RESOLVED, Design Decision 5)
- **CI workflow bodies** (`perf-bench.yml`, `api-diff.yml`, the coverage-gate in `ci.yml`) — Epic 9 (`9-3`/`9-4`). 2.15 ships the *artifacts* they consume (committed bench baselines, apitool baseline), not the gates. [Source: workflow placeholders; epic-9]
- **`melos run perf` / `melos run api-diff` scripts** — not referenced as 2.15 stubs (only `test`/`test:coverage` are). Epic 9. [Source: root pubspec melos.scripts]
- **`BENCHMARKS.md` reference-device profile** — architecture §10.1 / repo-root doc; Epic 9 / `9-4`. 2.15 captures device-local baselines; the canonical reference-device numbers are Epic 9. [Source: architecture :711, :846]
- **`sse_parse_bench` / memory bench (`chat_session_memory_bench`, N-3)** — `koel_http` (N-1) and a later memory-bench story respectively. 2.15 ships only the two `koel_core` benches the AC names (`reducer_bench`, `cold_start_bench`). [Source: NFR N-1 :293, N-3 :295; architecture :846]
- **Any `lib/src/**` logic change** — 2.15 adds no behavior. If the dartdoc sweep reveals a genuine contract bug, log it to `deferred-work.md`, do not fix it inline (a behavior change in the finalizer story is out of band). [Source: story intent]
- **Exporting internals "to be safe"** — see the do-NOT-export table. Under-export deliberately. [Source: AC4]

### Files you will touch
| Path | Action | Note |
|------|--------|------|
| `packages/koel_core/lib/koel_core.dart` | **MODIFY** | Replace placeholder with the exact export list (Task 1). The only `lib/` change. |
| `packages/koel_core/test/perf/reducer_bench.dart` | **NEW** | N-2 p99 bench, `@Tags(['perf'])`, record-or-gate (Task 3). |
| `packages/koel_core/test/perf/cold_start_bench.dart` | **NEW** | N-4 cold-start bench vs inline `_EmptyAgent`, record-or-gate (Task 4). |
| `packages/koel_core/test/perf/baselines/reducer_bench.json` | **NEW (committed)** | v1.0.0 reducer baseline. |
| `packages/koel_core/test/perf/baselines/cold_start_bench.json` | **NEW (committed)** | v1.0.0 cold-start baseline. |
| `packages/koel_core/analysis_options.yaml` | **NEW** | Doc-coverage gate scoped to koel_core (Task 2). |
| `packages/koel_core/coverage_options.yaml` | **NEW** | Generated-file ignore list for coverage (Task 5). |
| `packages/koel_core/.api-baseline/koel_core.json` (path TBD vs 9-3) | **NEW (committed)** | `dart_apitool` surface baseline (Task 6). |
| root `pubspec.yaml` (`melos.scripts`) | **MODIFY** | Wire `test` + `test:coverage` (Task 5). |
| dartdoc across exported `lib/src/**` symbols | **MODIFY (docs only)** | Fill/upgrade contract-form docs — **no logic** (Task 2). |

**Do NOT touch:** any `lib/src/**` *logic*; `pubspec.yaml` dependencies; `build.yaml`; the placeholder CI workflows; `koel.yaml` (the koel_lints profile — inactive since 1.7, not 2.15's concern); other packages.

### Library / framework requirements
- **No new dependency.** Benches use `package:test` + `dart:io` (baseline JSON read/write) + `dart:core` (`Stopwatch`). Coverage uses the already-present `coverage 1.15.0` dev tool. `dart_apitool` is a **global** (`dart pub global activate`), not a workspace dependency — its global pubspec is isolated from the analyzer-12 hold. [Source: pubspec.yaml; project memory: analyzer-12 stopgap is a workspace constraint]
- **No freezed / no build_runner in this story.** The barrel re-exports existing freezed types; it generates nothing. The benches are plain classes/functions. [Source: convention §3]
- **`package:test` only** for the benches (convention §6 :656 "No alternative frameworks") — one top-level `group()` per file, written to never flake (record-or-gate). [Source: architecture §6 :654-661]
- **Consumed verbatim:** the entire `koel_core` public surface (events, errors, state, reducer, session, client, json_patch_op) — read for export + doc, never modified.

### Project Structure Notes
- `test/perf/` is a **new directory** — the architecture pins it (:819-821) with exactly `reducer_bench.dart` + `cold_start_bench.dart`. `test/perf/baselines/` for the committed JSON.
- `lib/koel_core.dart` is the single barrel (architecture §6 :684 "Single barrel file per package"); `lib/src/` stays private (no external import of internal paths, :685).
- The koel_core `analysis_options.yaml` is the **first** member options file in the workspace (Story 1.7 removed per-member options). It declares **no `plugins:`** — see Design Decision 4 for why this is a plugin-free, justified exception, not a 1.7 reversal.
- `dart_apitool` baseline path: confirm against `9-3-dart-apitool-baselines-ci-gate` if that story pre-specifies a path; otherwise `.api-baseline/koel_core.json` and note the choice in `deferred-work.md` for 9-3 to read from the same place. Architecture names `tool/verify_api_surface.dart` (:726) as the Epic 9 wrapper — out of scope here.

### Previous Story Intelligence
- **2.14 (`KoelClient`/`ChatSession`)** — the immediate predecessor; supplies the `KoelClient` ctor (`cold_start_bench` instantiates it) and the `runRaw`/`newSession`/`stream` surfaces the cold-start interval measures. 2.14 deliberately left the barrel **untouched** ("export sweep is **Story 2.15** — do not add exports", 2-14 Task 8) — so 2.15 is the *first* story to populate `lib/koel_core.dart`. 2.14 also re-proved the **MockAgent trap** (use an inline `AbstractAgent` double) which Task 4 repeats. [Source: 2-14 Task 8 "Confirm untouched: lib/koel_core.dart barrel"; §"The MockAgent trap"]
- **2.12 (`ChatState` + reducer)** — `DefaultChatStateReducer.reduce` is the exact function `reducer_bench` times; it is **total** and rebuilds `ChatState` per call (the per-fold allocation is part of the measured p99). [Source: 2-12; chat_state_reducer.dart]
- **2.8 (28-event sweep)** — shipped `test/event/full_event_sweep.jsonl` (one canonical example of every ~28 event types) + the `full_event_sweep_test.dart` load pattern `reducer_bench` reuses as its workload. **Note its CWD-sensitivity** (deferred-work.md :158) — which is precisely why Task 5's `test` script must use `exec` (CWD = package root). [Source: 2-8; full_event_sweep_test.dart:14; deferred-work.md :158]
- **2.3 (`KoelError`) / 2.4 (`JsonPatchOp`)** — both ship sealed unions that the barrel exports; the do-NOT-export decision on `JsonPatch` (the applier from 2.4) vs the exported `JsonPatchOp` is the one barrel judgment call (§"The barrel"). [Source: 2-3, 2-4]
- **Story 1.7 (lint pivot to `analysis_server_plugin`)** — established the "single root `analysis_options.yaml`, no member options" design (because `plugins:` is root-only). Task 2's koel_core member file is the first principled exception (no plugins, just finalize lints). [Source: project memory lint pivot; root analysis_options.yaml comment]

### Git Intelligence Summary
Recent commits are the Epic 2 build-out: `feat(story-2.14)` (KoelClient/ChatSession — exercised by cold_start_bench), `feat(story-2.13)`/`2.12`/`2.11`/`2.10` (the reducer + pipeline + subscriber surfaces the barrel now exports). The governing precedent: **2.14's explicit deferral of the barrel to 2.15** and the **2.8 sweep fixture + its CWD-sensitivity note**. Expect a footprint of: 1 barrel rewrite, 2 bench files + 2 baseline JSONs, 1 member analysis_options, 1 coverage_options, 1 apitool baseline, and a root-pubspec melos-scripts edit — plus a dartdoc sweep across the existing surface. **Zero new deps, zero codegen, zero `lib/src` logic change.** Commit message: `feat(story-2.15): perf baselines + dartdoc + barrel finalize`. [Source: `git log` b4f86bf/fddcf8c/1dca714/…; 2-14 Task 8]

### Latest Tech Information
- **`melos exec` sets CWD = package root**; `melos run` (a single `run:` body) runs from the workspace root. The `test` script **must** be `exec: dart test` so package-relative fixture reads work (deferred-work.md :158). [Source: Melos 7.x exec semantics; deferred-work.md :158]
- **`public_member_api_docs`** is a standalone linter rule **not** included in `package:lints/recommended.yaml` — it must be turned on explicitly to enforce AC3. It does not apply to `_private` members; exclude generated files via `analyzer: exclude:` so it doesn't fire on `*.freezed.dart`. [Source: dart linter rules; architecture §6 :635]
- **`dart doc`** emits warnings for unresolved `[references]` and ambiguous reexports — `comment_references: true` + a clean barrel keep it at exit 0. It does **not** itself warn on missing docs; pair it with `public_member_api_docs`. [Source: dart doc behavior; AC3]
- **`dart_apitool` global activation is isolated** from the workspace pub solve — its own pubspec resolves independently, so the analyzer-12 freezed-stopgap hold does NOT block it. Verify 0.23.1 extracts on SDK 3.12; if not, capture the failure precisely and hand off to `9-3` (do not fabricate a baseline). [Source: `dart pub global` semantics; architecture §362; project memory: analyzer-12 stopgap]
- **`package:coverage` honors a per-package `coverage_options.yaml`** ignore list for generated files (the architecture-blessed exclusion mechanism, §6 :662-664). [Source: package:coverage; architecture §6]
- **`Stopwatch.elapsedMicroseconds`** is the right resolution for per-event reduce timing; warm up before measuring to exclude JIT compilation from the p99. [Source: dart:core `Stopwatch`]

### References
- [epic-2 Story 2.15 spec + ACs](../planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md)
- [PRD §9 — `koel_core` public API surface (the barrel contract); §10.1 N-1..N-5 (regression-relative perf, CI-on-reference-device framing); §10.4 N-12 (coverage tiers); SC-2 (coverage methodology, generated-file exclusion)](../planning-artifacts/prds/prd-koel-2026-05-27/prd.md)
- [addendum.md §A — full type-level public signatures to reconcile the barrel against (`KoelClient` ctor :30-41, `RunPhase` :107, `BackpressurePolicy` :266); confirms `JsonPatch`/`JsonPointer` are NOT public](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md)
- [architecture.md §6 Documentation & testing :632-697 (contract-form dartdoc, `public_member_api_docs` intent, coverage_options exclusion, no-flaky-tests, single barrel); §10 :1105-1120 (melos run test/test:coverage/perf/api-diff); :362-369 (`dart_apitool` D7); :819-821 (`test/perf/` layout); :846 (sse_parse_bench is koel_http)](../planning-artifacts/architecture.md)
- [root pubspec.yaml `melos.scripts` — the `test`/`test:coverage` stubs marked "wired in story 2.15"](../../pubspec.yaml)
- [root analysis_options.yaml — the single-root-options design (Story 1.7) the koel_core member file extends](../../analysis_options.yaml)
- [lib/koel_core.dart — the placeholder barrel to populate (currently `library;` + header, zero exports)](../../packages/koel_core/lib/koel_core.dart)
- [test/event/full_event_sweep_test.dart + full_event_sweep.jsonl — the 28-event workload `reducer_bench` reuses + its CWD-sensitive read](../../packages/koel_core/test/event/full_event_sweep_test.dart)
- [test/agent/abstract_agent_test.dart:8-11 — the `_FakeAgent` inline-double pattern `cold_start_bench`'s `_EmptyAgent` mirrors (NOT `MockAgent`)](../../packages/koel_core/test/agent/abstract_agent_test.dart)
- [deferred-work.md :158 (full_event_sweep CWD-sensitivity → `exec` test script), :85 (perf-bench/api-diff CI bodies are Epic 9)](deferred-work.md)
- [2-14-koel-client-chat-session-api.md — predecessor; deferred the barrel to 2.15 (Task 8) and established the MockAgent inline-double resolution](2-14-koel-client-chat-session-api.md)
- [.github/workflows/perf-bench.yml + api-diff.yml — placeholders explicitly "Wired in Epic 9"; 2.15 ships the artifacts, not the gates](../../.github/workflows/perf-bench.yml)

### Design decisions (RESOLVED — AC/convention-forced, not open)
Baked in so the dev has zero ambiguity. No confirmation gate.
1. **`MockAgent.empty` does not exist — use a private inline `AbstractAgent` empty double for `cold_start_bench`.** `MockAgent` is Story 3.1 / empty `koel_test`. Mirror `abstract_agent_test.dart`'s `_FakeAgent`. Do not import/build it.
2. **Perf benches are record-or-gate, never flaky.** Default `dart test` records-or-logs-and-passes; the >10% gate fires only under `KOEL_PERF_GATE` (CI reference device, Epic 9). Baselines (re)written when absent or under `KOEL_PERF_UPDATE`. Tag `@Tags(['perf'])`, exclude from `melos run test`. Reconciles AC1/AC2 with convention §6 "no flaky tests" via NFR's own "CI-on-reference-device" framing.
3. **Wire `melos run test` (`exec: dart test`, CWD=package root for fixture reads) + `test:coverage` (`coverage` tool + per-package `coverage_options.yaml`, ≥90% assert).** Those two stubs are 2.15's explicit hand-off; `perf`/`api-diff` scripts + CI bodies are Epic 9.
4. **Doc gate via a koel_core-scoped member `analysis_options.yaml`** (`include` root + `public_member_api_docs`/`comment_references` + generated-file `exclude`). Plugin-free → not a Story 1.7 reversal. `dart doc` exit-0 needs `comment_references`, not just docs present.
5. **Barrel exports exactly PRD §9 + Addendum §A — under-export deliberately.** Export `JsonPatchOp` (public via `StateDeltaEvent`/`StateConflict`); keep `JsonPatch`/`JsonPointer`/pipeline/codec/deserializer/stage_support internal. `dart_apitool` pins whatever leaks; over-export is a 2.0.0 obligation, under-export a recoverable 1.x minor.
6. **No behavior change.** Only `lib/koel_core.dart` (exports) + dartdoc + new test/config files + root melos-scripts. No `lib/src` logic, no new dependency, no codegen. Contract bugs found during the doc sweep go to `deferred-work.md`, not inline fixes.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Claude Opus 4.8, 1M context) via `/bmad-dev-story`; `/agent-flutter-engineer` specialist loaded first per CLAUDE.md. The contract-form dartdoc sweep over the existing `lib/src` surface was delegated to a parallel sub-agent under tight doc-only constraints; the barrel, benches, melos wiring, and apitool baseline were authored on the main thread.

### Debug Log References

- **Barrel table correction (Task 1):** the story's export table listed each event subtype file and `chat_session.dart` as separate exports, but they are all `part of` their sealed root (`ag_ui_event.dart` / `koel_client.dart`). Exporting a part file is a compile error — the surface collapses to one `export` per library, which yields the *exact* intended symbols. Verified with positive + negative probe files (all intended symbols reachable; `JsonPatch`/`PipelineStage`/`runPipeline`/`deserializeAgUiEvent`/`eventTypeRegistry` all unreachable).
- **Doc gate `include` (Task 2):** empirically confirmed `packages/koel_core/analysis_options.yaml` with `include: ../../analysis_options.yaml` does **not** trip `plugins_in_inner_options` (Design Decision 4 validated). `comment_references` in the pure-export barrel doc don't resolve (empty import scope) → de-bracketed those to backtick code spans; internal `[JsonPatch.apply]`/pipeline refs likewise → backticks.
- **Perf resolution (Tasks 3/4):** a single `reduce` is sub-microsecond (below `elapsedMicroseconds`), so `reducer_bench` samples one full 28-event fold's time ÷ event count (stable per-event average, non-flaky p99). Both benches verified in all three record-or-gate modes.
- **melos `test` exit 79 (Task 5):** all 11 member packages carry a scaffolded `test/` dir, so `dirExists` can't filter the 9 empty ones (they exit 79 "no tests"). melos interpolates `$?` at expansion time, so the exit-79 tolerance lives in `tool/test_package.sh` (invoked via `$MELOS_ROOT_PATH`), not inline.
- **Branch coverage (Task 5):** `format_coverage --lcov` emits per-branch `BRDA:` lines but no `BRF`/`BRH` summaries; the `test:coverage` awk computes branch% from `BRDA` (found = count, hit = taken≠`-`).
- **apitool (Task 6):** `dart_apitool 0.23.1` (global, isolated from the analyzer-12 hold) extracted cleanly on SDK 3.12 — no fallback manifest needed.

### Completion Notes List

All 5 ACs satisfied; zero `lib/src` behavior change (only `lib/koel_core.dart` exports + doc comments + 3 enum reformats + new test/config files + root melos scripts).

- **AC1** — `test/perf/reducer_bench.dart` measures p99 reduce-time/event over the 28-event sweep, writes `baselines/reducer_bench.json` (p99 ≈ 2.536µs), gates >10% under `KOEL_PERF_GATE`.
- **AC2** — `test/perf/cold_start_bench.dart` times `KoelClient(...)` → first `runRaw(...).listen` readiness vs a private inline `_EmptyAgent` (not the not-yet-built `MockAgent.empty`); `baselines/cold_start_bench.json` (p99 ≈ 201µs), same gate.
- **AC3** — `public_member_api_docs` + `comment_references` enabled and driven to **0** across the exported surface; `dart doc` → 0 warnings / 0 errors, exit 0.
- **AC4** — barrel finalized to exactly PRD §9 + Addendum A.1 (probe-verified); `dart_apitool extract` → `.api-baseline/koel_core.json` (internals confirmed absent); `melos run analyze` → 0 workspace-wide.
- **AC5** — `melos run test:coverage` → koel_core **line 98.85% (857/867), branch 97.87% (413/422)**, both ≥ 90%.

Quality gates: `melos run test` 577 green (koel_core 572 + koel_lints 5; perf excluded), `melos run analyze` clean, `dart doc` clean, `format:check` clean.

Deviations from the story's literal file list (all justified, noted in `deferred-work.md`): `test/perf/perf_baseline.dart` (shared record-or-gate helper, DRY across both benches; `test/`-only, off-contract), `dart_test.yaml` (declares the `perf` tag → warning-free suite), `tool/test_package.sh` (exit-79 tolerance the inline melos script can't express).

### File List

**Modified**
- `packages/koel_core/lib/koel_core.dart` — placeholder → finalized public-API barrel (Task 1).
- `packages/koel_core/lib/src/**` (30 files: agent, client, error, event, input, json_patch, message, state, tool, pipeline) — contract-form dartdoc added/upgraded + internal `[ref]`→backtick; 3 enums (`BackpressurePolicy`/`MessageRole`/`RunPhase`) reformatted one-value-per-line for per-value docs (values/order unchanged). **Docs only — no logic** (Task 2).
- `pubspec.yaml` — wired `melos.scripts` `test` (+ `tool/test_package.sh`) and `test:coverage` (Task 5).
- `_bmad-output/implementation-artifacts/deferred-work.md` — Story 2.15 hand-off notes (apitool path for 9-3; melos test/coverage mechanics; perf-baseline recapture for 9-4).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 2-15 → in-progress → review.

**New**
- `packages/koel_core/test/perf/reducer_bench.dart` — NFR-2 p99 reduce bench (Task 3).
- `packages/koel_core/test/perf/cold_start_bench.dart` — NFR-4 cold-start bench (Task 4).
- `packages/koel_core/test/perf/perf_baseline.dart` — shared record-or-gate helper.
- `packages/koel_core/test/perf/baselines/reducer_bench.json` — committed v1.0.0 reducer baseline.
- `packages/koel_core/test/perf/baselines/cold_start_bench.json` — committed v1.0.0 cold-start baseline.
- `packages/koel_core/analysis_options.yaml` — koel_core-scoped doc gate (Task 2).
- `packages/koel_core/coverage_options.yaml` — generated-file ignore list for coverage (Task 5).
- `packages/koel_core/dart_test.yaml` — declares the `perf` tag.
- `packages/koel_core/.api-baseline/koel_core.json` — `dart_apitool` surface baseline (Task 6).
- `tool/test_package.sh` — per-package test runner (exit-79 tolerance, Task 5).

## Change Log

| Date | Change |
|------|--------|
| 2026-05-30 | Story 2.15 implemented — finalized `koel_core` public-API barrel, contract-form dartdoc sweep + `public_member_api_docs`/`comment_references` doc gate, `reducer_bench` + `cold_start_bench` record-or-gate perf harnesses with committed v1.0.0 baselines, `dart_apitool` API-surface baseline, and wired `melos run test`/`test:coverage`. Zero `lib/src` behavior change. All 5 ACs satisfied; coverage line 98.85% / branch 97.87%. |
| 2026-05-31 | Code review (3-layer adversarial: Blind Hunter / Edge Case Hunter / Acceptance Auditor). AC1-AC5 independently verified met (barrel surface cross-checked against committed apitool baseline — internals confirmed absent; zero `lib/src` logic change confirmed; no scope creep). 2 patch findings **fixed**: (1) High — `tool/test_package.sh` now tolerates the no/empty-`test/`-dir exit 65 so `melos run test` survives a fresh CI checkout; (2) Low — `recordOrGate` now `fail()`s with a precise message on a malformed/missing-key baseline. Also fixed `dart_test.yaml` (`perf: {}` — empty mapping clears the IDE YAML-schema "expected object" error on the null tag value). 5 findings deferred to Epic 9 (perf recapture / coverage-CI / flutter-aware test runner). Status → done. |

## Review Findings

_Code review 2026-05-31 — 3 adversarial layers (Blind / Edge Case / Acceptance). All 5 ACs verified genuinely met; findings below are correctness/robustness gaps, not AC violations._

- [x] **[Review][Patch] `melos run test` fails on a clean CI checkout — scaffold packages exit 65, not 79** [tool/test_package.sh:16, pubspec.yaml:31] — **FIXED 2026-05-31:** `tool/test_package.sh` now skips a package with an absent/empty `test/` dir (`exit 0`) and tolerates exit 65 in addition to 0/79. Verified: fresh-checkout sim (no `test/`) → exit 0; koel_core → 572 pass. — Empirically verified on SDK 3.12: a package with **no `test/` dir** → `dart test` exits **65**; an **empty** `test/` dir → exits 79. The 8 scaffold packages have **zero git-tracked files under `test/`** (`git ls-files packages/*/test` = 0; empty dirs aren't tracked), so on a fresh `actions/checkout@v4` the dirs don't exist → `dart test` exits 65 → `tool/test_package.sh` tolerates only `0`/`79` → propagates 65 → `melos exec` fails the `test` script. `.github/workflows/ci.yml:31` runs `melos run test` on every PR/push to `main`, so the gate this story was meant to satisfy (Task 7 "melos run test → all green") is **red on CI**. The "577 green" completion claim holds only on the dev's dirty local tree where stale empty `test/` dirs happen to exist. `deferred-work.md`'s 2.15 hand-off ("empty test/ dir → exit 79, no change needed") encodes the same flawed assumption. **Fix:** tolerate exit 65 in `tool/test_package.sh`, OR guard `[ ! -d test ] && exit 0` / `[ -z "$(ls -A test 2>/dev/null)" ] && exit 0` before invoking `dart test`. (Source: edge, verified by reviewer.)
- [x] **[Review][Patch] `recordOrGate` baseline read throws an opaque crash on a malformed/missing-key baseline** [test/perf/perf_baseline.dart] — **FIXED 2026-05-31:** explicit guards now `fail()` with a precise message ("not valid JSON" / "must be a JSON object" / "missing a numeric `$metric` key; re-record with KOEL_PERF_UPDATE"). Verified the missing-key path emits the clear message under `KOEL_PERF_GATE`. — On the `KOEL_PERF_GATE` path, `jsonDecode(...) as Map<String,dynamic>` then `(baseline[metric] as num)` surfaces a raw `FormatException`/`CastError` (vs the clear `ArgumentError` `percentile` throws on empty). A corrupted committed baseline becomes a confusing cast crash inside the Epic-9 perf job. Add an explicit "baseline malformed / missing key `$metric`" guard. (Source: blind+edge.)

- [x] **[Review][Defer] cold_start bench measures a near-trivial interval against a tight >10% gate** [test/perf/cold_start_bench.dart] — deferred to Epic 9 `9-4` reference-device recapture; baselines are device-local single-run and the gate only fires under `KOEL_PERF_GATE` (already noted in deferred-work).
- [x] **[Review][Defer] `reducer_bench` integer-µs truncation could record p99 = 0.0 on faster hardware, trivially passing the gate** [test/perf/reducer_bench.dart] — `elapsedMicroseconds` is floored before the ÷28; if a full sweep ever runs <1µs the gate `value <= baseline*1.10` always passes. Not hit today (~71µs/sweep). Use `elapsedTicks`+`frequency` or recapture at 9-4. (Source: blind+edge.)
- [x] **[Review][Defer] `test:coverage` depends on a globally-activated `format_coverage` on PATH (unguarded `set -e`)** [pubspec.yaml:38] — Epic 9 coverage CI must `dart pub global activate coverage` first, else the gate dies with a bare "command not found". (Source: blind+edge.)
- [x] **[Review][Defer] branch-coverage awk computes from `BRDA:` only with no `BRF:`/`BRH:` reconciliation** [pubspec.yaml:41] — works on the current `coverage 1.15.0` output; could diverge if a future version emits summary lines. (Source: edge.)
- [x] **[Review][Defer] `melos run test` runs `dart test` (not `flutter test`) in Flutter packages** [tool/test_package.sh] — `koel_flutter`/`koel_widgets`/`koel_devtools` declare the Flutter SDK; fine now (no widget tests → exit 79/65), but the runner needs a flutter-aware branch before those packages gain binding tests. (Source: edge, downgraded — current "hard fail" claim refuted: koel_flutter exits 79 like any package.)
