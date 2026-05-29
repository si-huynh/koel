# Epic 1: Workspace Foundation & Lint Profile

Developer can `git clone koel && melos bootstrap` and have every package compile + `dart analyze` clean against `package:koel_lints/koel.yaml`. CI skeleton (six workflow files) and brand/license/MIT scaffolding ship together so subsequent epics inherit a green baseline.

## Story 1.1: Workspace bootstrap (pub workspace + Melos + Dart 3.9.0+ floor)

As an OSS contributor,
I want a Dart pub workspace + Melos 7.8.0 orchestration at the repo root with strict Dart 3.9.0+ floor,
So that running `melos bootstrap` produces a linked monorepo whose Dart toolchain matches the architectural Decision D1 (raised from PRD's original 3.0+).

**Acceptance Criteria:**

**Given** a fresh clone of the repo with `dart pub global activate melos 7.8.0` available,
**When** I run `melos bootstrap` at the repo root,
**Then** the command exits 0 with every workspace member linked via `path:` resolutions in `pubspec_overrides.yaml`,
**And** no warning about workspace-incompatible members appears.

**Given** the repo-root `pubspec.yaml` is opened,
**When** I inspect its `environment.sdk` constraint,
**Then** it is `>=3.9.0 <4.0.0` (AR-3 / D1),
**And** the `workspace:` array lists exactly the 11 entries: `packages/koel`, `packages/koel_core`, `packages/koel_http`, `packages/koel_lints`, `packages/koel_agno`, `packages/koel_langgraph`, `packages/koel_runtime`, `packages/koel_flutter`, `packages/koel_widgets`, `packages/koel_devtools`, `packages/koel_test`.

**Given** the repo-root `melos.yaml`,
**When** I run `melos list`,
**Then** every workspace member is enumerated,
**And** the following scripts are defined under `scripts:`: `analyze`, `test`, `test:coverage`, `build`, `format`, `format:check`, `analyze:apply` (no-ops permitted; full bodies wired in later stories).

**Given** the repo-root `.gitignore`,
**When** I grep it,
**Then** it excludes `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, `.dart_tool/`, `build/`, `coverage/`, `.melos_tool/`, and `pubspec.lock` per-package (workspace-level lock kept).

## Story 1.2: Scaffold the ten publishable packages

As an OSS contributor,
I want all ten `koel_*` packages plus the `koel` meta-package scaffolded under `packages/` with the official Dart/Flutter package templates and a single `lib/<package_name>.dart` barrel file each,
So that each package is a publishable skeleton ready for FRs to land in subsequent epics.

**Acceptance Criteria:**

**Given** the `packages/` directory after Story 1.1,
**When** I list its children,
**Then** I see exactly: `koel`, `koel_core`, `koel_http`, `koel_lints`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`, `koel_devtools`, `koel_test`,
**And** each Dart-only package (`koel`, `koel_core`, `koel_http`, `koel_lints`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_test`) was created via `dart create --template=package`,
**And** each Flutter package (`koel_flutter`, `koel_widgets`, `koel_devtools`) was created via `flutter create --template=package`.

**Given** any package directory,
**When** I open `lib/<package_name>.dart`,
**Then** the file exists as the single barrel and re-exports nothing yet (placeholder OK),
**And** all source code is constrained to live under `lib/src/` per architecture Convention §2.

**Given** any package's `pubspec.yaml`,
**When** I inspect dependencies,
**Then** no `very_good_analysis` package appears anywhere (per AR-1 rationale),
**And** Dart packages declare `environment.sdk: ">=3.9.0 <4.0.0"`,
**And** Flutter packages declare both Dart sdk constraint and `flutter: ">=3.27.0"` (verified during Story 1.6 reconciliation against AR-25).

**Given** any package directory,
**When** I list its root,
**Then** it contains placeholder `README.md`, `CHANGELOG.md`, and `LICENSE` files (content finalized in Story 1.6).

## Story 1.3: Build `koel_lints` profile and principal rule

> ⚠️ **Lint mechanism SUPERSEDED by Story 1.7 (SCP-2026-05-29).** The `custom_lint`,
> `package:lints/strict.yaml`, and per-package `include:` acceptance criteria below are
> retired — `custom_lint` was archived 2026-03-24 and fails on native pub workspaces.
> Status stays `done` (historical record); the asp re-implementation lives in **Story 1.7**.

As an OSS contributor,
I want `koel_lints` to ship `lib/koel.yaml` (the canonical analyzer profile) and the principal custom_lint rule `exhaustive_switch_must_have_default` fixture-tested,
So that every other package can `include: package:koel_lints/koel.yaml` and lock sealed-union exhaustiveness with mandatory `default:` branches — making future sealed-subtype additions a semver-minor bump per FR-A12 / FC-2.

**Acceptance Criteria:**

**Given** `packages/koel_lints/`,
**When** I inspect the source tree,
**Then** `lib/koel.yaml` exists as a YAML profile that `include`s `package:lints/strict.yaml` and enables `exhaustive_switch_must_have_default: error`,
**And** `lib/koel_lints.dart` is the `custom_lint` plugin entrypoint that registers the rule,
**And** rules live under `lib/src/rules/exhaustive_switch_must_have_default.dart` per architecture's `koel_lints` variation layout.

**Given** `packages/koel_lints/pubspec.yaml`,
**When** I inspect dependencies,
**Then** it declares `custom_lint: ^0.8.1` (per AR-5) and `analyzer` as runtime/build deps,
**And** declares `custom_lint_builder` as a build dep.

**Given** `packages/koel_lints/test/rules/fixtures/`,
**When** I run `dart test`,
**Then** the rule fires on `violations/missing_default.dart` (a `switch` over `AgUiEvent` lacking `default:`),
**And** the rule stays silent on `ok/with_default.dart`,
**And** both fixtures use the `custom_lint` test harness pattern.

**Given** `packages/koel_lints/analysis_options.yaml` (the self-include exception G-3),
**When** I inspect it,
**Then** it extends only `package:lints/strict.yaml` (NOT `package:koel_lints/koel.yaml` — a package cannot lint itself),
**And** a one-line comment in the file documents the exception with a pointer to the package README,
**And** `packages/koel_lints/README.md` documents the self-include exception in a "Note" section.

## Story 1.4: Adopt `koel_lints` profile across every other package

> ⚠️ **Lint mechanism SUPERSEDED by Story 1.7 (SCP-2026-05-29).** Per-package
> `include: package:koel_lints/koel.yaml` + per-package `custom_lint` dev-deps are retired;
> under `analysis_server_plugin` the rule is enabled from a single workspace-root
> `analysis_options.yaml`. Status stays `done` (historical record); see **Story 1.7**.

As an OSS contributor,
I want every package except `koel_lints` itself to include `package:koel_lints/koel.yaml` in its `analysis_options.yaml` via a path dependency during pre-publish development,
So that `melos run analyze` runs the koel-mandatory rules everywhere and contributors get the exhaustive-switch enforcement from day one.

**Acceptance Criteria:**

**Given** Story 1.3 has shipped,
**When** I inspect each non-lints package's `analysis_options.yaml`,
**Then** it has a single `include: package:koel_lints/koel.yaml` line as its top directive,
**And** no other `linter:` or `analyzer:` overrides appear unless documented inline.

**Given** each non-lints package's `pubspec.yaml` `dev_dependencies:` section,
**When** I inspect it,
**Then** `koel_lints` appears as a path dependency to `../koel_lints` (path-dep during dev, package-dep at first publish per AR-3),
**And** `custom_lint` appears as a dev dependency on each package consuming the profile.

**Given** the workspace bootstrapped,
**When** I run `melos run analyze` (delegating to `dart analyze` per package),
**Then** the command exits 0 across all eleven packages,
**And** no `dart analyze` warnings or errors are emitted from any package skeleton (per NFR-13).

## Story 1.5: CI workflow skeleton (six GitHub Actions workflows)

As a release manager,
I want the six CI workflow files (`ci.yml`, `conformance.yml`, `perf-bench.yml`, `api-diff.yml`, `codegen-drift.yml`, `publish-dry-run.yml`) scaffolded under `.github/workflows/`,
So that every subsequent epic extends existing workflows rather than authoring fresh ones, and per-PR gating is in place from Epic 1 onward.

**Acceptance Criteria:**

**Given** `.github/workflows/`,
**When** I list its contents,
**Then** the six files exist: `ci.yml`, `conformance.yml`, `perf-bench.yml`, `api-diff.yml`, `codegen-drift.yml`, `publish-dry-run.yml` (per AR-17).

**Given** `ci.yml`,
**When** I inspect its triggers and jobs,
**Then** it triggers on `pull_request` to main and `push` to main,
**And** it runs a matrix job that executes `dart pub global activate melos 7.8.0 && melos bootstrap && melos run analyze && melos run test` on Linux,
**And** the job uses Dart 3.9.0 (matching AR-3 / NFR-9).

**Given** `codegen-drift.yml`,
**When** I inspect it,
**Then** it runs `melos run build && git diff --exit-code` on every PR (per AR-18),
**And** the job fails the build with the offending diff if any tracked file changes after build_runner execution.

**Given** the four remaining workflow files (`conformance.yml`, `perf-bench.yml`, `api-diff.yml`, `publish-dry-run.yml`),
**When** I open each,
**Then** each contains a valid YAML structure with a placeholder job that exits 0 with an explicit `echo "Wired in Epic <N>"` body,
**And** each file's header comment names which epic completes the workflow (`api-diff.yml` → Epic 9; `perf-bench.yml` → Epic 9; `conformance.yml` → Epic 5; `publish-dry-run.yml` → Epic 9).

## Story 1.6: Repo documentation + brand reservation + license placement

As a release manager,
I want a repo-root `README.md` + `CONTRIBUTING.md` + MIT `LICENSE` and per-package LICENSE copies, plus the ten `koel_*` slot names reserved on pub.dev with the credit-line stub to community `ag_ui` 0.1.0 placed in `koel_core/README.md`,
So that visitors land on a coherent monorepo intro, contributors understand the workflow, and brand/licensing gates are met ahead of v1.0.0 publish.

**Acceptance Criteria:**

**Given** the repo root,
**When** I list it,
**Then** `README.md`, `CONTRIBUTING.md`, `LICENSE`, `CHANGELOG.md` all exist,
**And** `README.md` follows PRD §13 D-1 quality bar: one-paragraph "what is this", a 10-line quickstart snippet using the `koel` meta-package (compile-clean even if quickstart code is a placeholder pending Epic 9), link to docs site (placeholder pending OQ-Docs-Framework), link to per-package CHANGELOGs, MIT license note,
**And** `CONTRIBUTING.md` documents the Melos monorepo workflow (`melos bootstrap`, `melos run analyze`, `melos run test`, codegen drift expectations) per FR-H1.

**Given** every `packages/<name>/` directory,
**When** I check for `LICENSE`,
**Then** the file exists in every package root,
**And** all eleven files are byte-identical MIT-licensed copies attributed to "2026 Si Huynh" (per FR-H5).

**Given** `koel_core/README.md`,
**When** I inspect its credits section,
**Then** it carries a one-line credit-line stub crediting the community `ag_ui` 0.1.0 package as the genre's first attempt (per FR-H4 + AR-21),
**And** a tracking note marks the credit as pending OQ-AGUI-License verification (cleared in Epic 9 via FR-I3).

**Given** pub.dev,
**When** I check each of the ten reserved `koel_*` slot names + the `koel` meta-package name,
**Then** all eleven names are reserved to the owner account ahead of pre-publish (per FR-H4),
**And** evidence (reservation receipts or pub.dev verification screenshots) is committed to `_bmad-output/planning-artifacts/brand-reservation.md` as a traceability artifact.

## Story 1.7: Migrate `koel_lints` to `analysis_server_plugin`

_Added via correct-course SCP-2026-05-29. Supersedes the lint mechanism of Stories 1.3 + 1.4. Reverses AR-5 + architecture D3. Critical-path gate before Epic 2 (Story 2.1)._

As an OSS contributor,
I want `koel_lints` rebuilt on the first-party `analysis_server_plugin` API and wired through a single workspace-root `analysis_options.yaml`,
So that `exhaustive_switch_must_have_default` actually fires on consumer source under `dart analyze` + IDEs in our native pub workspace — delivering the FR-A12 / FC-2 guarantee that `custom_lint` (archived 2026-03-24) could not.

**Acceptance Criteria:**

**Given** the asp plugin wired at the workspace-root `analysis_options.yaml`,
**When** I run `dart analyze` on a member package containing a `switch` over sealed `AgUiEvent` without a `default:` branch,
**Then** `exhaustive_switch_must_have_default` is reported as an **ERROR** (and the IDE surfaces the same),
**And** it stays silent when a `default:` branch is present.
_(AC1 — the server-plugin integration is the one piece not yet proven by the spike; do this first. `analyzer_testing` is the unit-test backbone.)_

**Given** `packages/koel_lints/`,
**When** I inspect the source tree,
**Then** `lib/main.dart` is a `Plugin` subclass whose `register(PluginRegistry)` calls `registry.registerLintRule(...)`,
**And** the rule extends `AnalysisRule` with `LintCode(name, message, severity: DiagnosticSeverity.ERROR)`, overrides `registerNodeProcessors` → `registry.addSwitchStatement` / `addSwitchExpression`, and reports via `reportAtToken`,
**And** the old `custom_lint` entrypoint `lib/koel_lints.dart` is removed.

**Given** `packages/koel_lints/pubspec.yaml` and the 10 consumer pubspecs,
**When** I inspect dependencies,
**Then** `koel_lints` declares `analysis_server_plugin: ^0.3.15` + `analyzer: ^13.0.0`,
**And** `custom_lint` + `custom_lint_builder` are removed from `koel_lints` and from all 10 consumer pubspecs.

**Given** the test suite,
**When** I run `dart test` in `koel_lints`,
**Then** rule unit tests via `analyzer_testing` (`AnalysisRuleTest`) fire on a no-`default:` switch over sealed `AgUiEvent` (statement + expression form) and stay silent with `default:`,
**And** a dedicated `dart analyze` integration check covers AC1.

**Given** the toolchain pins,
**When** I inspect `.tool-versions`, the 11 pubspecs, and CI,
**Then** `.tool-versions` pins Dart `3.12` / Flutter `3.44`,
**And** the declared floor is raised to Dart `>=3.10.0` across all 11 pubspecs and Flutter `>=3.38.0` (exact mapping confirmed) on the 3 Flutter packages,
**And** `pubspec.lock` re-resolves clean and the CI `setup-dart` pin is bumped to match. _(Resolves retro Discovery-D4.)_

**Given** the workspace,
**When** I inspect `analysis_options.yaml` files,
**Then** a single repo-root `analysis_options.yaml` declares asp `plugins:` + `diagnostics: { exhaustive_switch_must_have_default: true }` enabling the rule for all members,
**And** per-member `include: package:koel_lints/koel.yaml` lines are removed/reconciled. _(Closes Story 1.1's deferred "no root analysis_options.yaml".)_

**Given** `koel_lints/README.md` and `lib/koel.yaml`,
**When** I inspect docs,
**Then** the README reflects asp (not custom_lint), documents the opt-out via `diagnostics: { exhaustive_switch_must_have_default: false }`, and drops the pub-workspace-bug caveat,
**And** `lib/koel.yaml` is retained as the external-consumer profile with a note that its `include:`-based distribution is verified at Epic 9 (Story 9-5).

**Given** the workspace bootstrapped,
**When** I run `melos run analyze`,
**Then** it exits 0 across all 11 packages with the rule live.

---
