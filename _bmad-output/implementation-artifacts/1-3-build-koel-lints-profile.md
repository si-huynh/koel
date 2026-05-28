---
baseline_commit: 5908715ad569e1bea76bdb4a57d00c4a8a6ac8f0
---

# Story 1.3: Build `koel_lints` profile and principal rule

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an OSS contributor,
I want `koel_lints` to ship `lib/koel.yaml` (the canonical analyzer profile) and the principal `custom_lint` rule `exhaustive_switch_must_have_default` fixture-tested,
So that every other package can `include: package:koel_lints/koel.yaml` and lock sealed-union exhaustiveness with mandatory `default:` branches — making future sealed-subtype additions a semver-minor bump per FR-A12 / FC-2 / NFR-17.

## Acceptance Criteria

1. **AC1 — Source tree under `packages/koel_lints/` matches the custom_lint plugin layout.**
   - **Given** `packages/koel_lints/`,
   - **When** I inspect the source tree,
   - **Then** `lib/koel.yaml` exists as a YAML profile that `include`s `package:lints/strict.yaml` and enables `exhaustive_switch_must_have_default: error` under `custom_lint.rules:`,
   - **And** `lib/koel_lints.dart` is the `custom_lint` plugin entrypoint that registers the rule via `createPlugin()` returning a `PluginBase`,
   - **And** the rule source lives at `lib/src/rules/exhaustive_switch_must_have_default.dart` per architecture's `koel_lints` variation layout.

2. **AC2 — Pubspec declares the analyzer plugin deps; AR-1 ban still holds.**
   - **Given** `packages/koel_lints/pubspec.yaml`,
   - **When** I inspect dependencies,
   - **Then** `custom_lint_builder: ^0.8.1` is in `dependencies` (the library imported by the plugin entrypoint and the rule),
   - **And** `analyzer: ^8.0.0` is in `dependencies` (matches `custom_lint`'s pinned constraint per AR-5; the rule imports `package:analyzer/...` directly),
   - **And** `custom_lint: ^0.8.1` is in `dev_dependencies` (the CLI/runner; needed for running the plugin against this package's own fixture tests),
   - **And** `test: ^1.20.2` is in `dev_dependencies` (fixture-test harness),
   - **And** no `very_good_analysis` package appears anywhere (AR-1).

3. **AC3 — Rule fires on `violations/missing_default.dart`; stays silent on `ok/with_default.dart`.**
   - **Given** `packages/koel_lints/test/rules/fixtures/`,
   - **When** I run `dart test` from `packages/koel_lints/` (after `melos bootstrap` has linked workspace state),
   - **Then** the fixture-based test asserts the rule diagnostic appears on `violations/missing_default.dart` at the line of a `switch` over a sealed `AgUiEvent` (declared inside the fixture) lacking a `default:` arm,
   - **And** asserts the rule emits zero diagnostics on `ok/with_default.dart` (same `switch` shape WITH a `default:` arm),
   - **And** both fixtures use the `custom_lint` `// expect_lint: <name>` comment convention as the test signal source.

4. **AC4 — `packages/koel_lints/analysis_options.yaml` carries the G-3 self-include exception.**
   - **Given** `packages/koel_lints/analysis_options.yaml`,
   - **When** I inspect it,
   - **Then** it extends only `package:lints/strict.yaml` — NOT `package:koel_lints/koel.yaml` (a package cannot lint itself; G-3 architectural exception),
   - **And** a one-line comment in the file documents the exception with a pointer to `packages/koel_lints/README.md`,
   - **And** `packages/koel_lints/README.md` documents the self-include exception in a "Note" section + minimal "Getting started" content (one-line install + `include:` snippet) that replaces the `dart create` boilerplate TODO block. PRD §13 D-1 full README quality bar is still owned by Story 1.6.

## Tasks / Subtasks

- [x] **Task 1 — Preflight + working-tree snapshot** (AC: 1, 2, 3, 4)
  - [x] 1.1 Verify toolchain at scaffold time matches Story 1.2's baseline: `dart --version` ≥ 3.9.0 (D1), `flutter --version` ≥ 3.27.0. If either drifts, halt and surface in Completion Notes — do NOT raise the SDK floor in this story (locked by D1; floor reconciliation owned by Story 1.6 / 9.7 per AR-25).
  - [x] 1.2 Confirm `melos bootstrap` is currently green from the Story 1.2 baseline (`-> 11 packages bootstrapped`, no warnings). If not, fix the workspace BEFORE proceeding — this story's verification depends on a clean workspace.
  - [x] 1.3 Snapshot the existing `packages/koel_lints/` state (it is a `dart create --template=package` skeleton from Story 1.2; see Dev Notes → Existing repo state). You will REPLACE four files (`pubspec.yaml`, `lib/koel_lints.dart`, `analysis_options.yaml`, `README.md`) and CREATE the rest.

- [x] **Task 2 — Rewrite `packages/koel_lints/pubspec.yaml`** (AC: 2)
  - [x] 2.1 Replace `packages/koel_lints/pubspec.yaml` with the workspace-aware plugin shape below. Key order matches Story 1.1 / 1.2 conventions; blank line between `publish_to:` and `environment:`, between `environment:` and `resolution:`, and before `dependencies:` / `dev_dependencies:` blocks.
        ```yaml
        name: koel_lints
        description: Analyzer plugin enforcing koel's mandatory rules (custom_lint based).
        version: 0.0.1
        publish_to: none

        environment:
          sdk: ">=3.9.0 <4.0.0"

        resolution: workspace

        dependencies:
          analyzer: ^8.0.0
          custom_lint_builder: ^0.8.1

        dev_dependencies:
          custom_lint: ^0.8.1
          test: ^1.20.2
        ```
  - [x] 2.2 Verify all three pinned versions resolve under Dart 3.9.0+ and the existing pub-workspace setup (no `pubspec_overrides.yaml`; native pub workspace resolution per Story 1.1 finding). After saving, run `melos bootstrap` at the repo root and assert exit 0 with `-> 11 packages bootstrapped`.
  - [x] 2.3 **Do NOT add `koel_lints` to any other package's dependencies in this story.** Story 1.4 owns adoption (`include: package:koel_lints/koel.yaml` + `koel_lints: ^X.Y.0` workspace dep on every non-lints package). Pre-empting it here breaks story boundary discipline + creates merge conflict surface.

- [x] **Task 3 — Author the consumer analyzer profile `lib/koel.yaml`** (AC: 1)
  - [x] 3.1 Create `packages/koel_lints/lib/koel.yaml` with exactly this content (2-space indent; no comments restating obvious keys per NFR-16 / Convention §6):
        ```yaml
        include: package:lints/strict.yaml

        analyzer:
          plugins:
            - custom_lint

        custom_lint:
          rules:
            - exhaustive_switch_must_have_default
        ```
        Rationale per line:
        - `include: package:lints/strict.yaml` — Dart team's strict set as the baseline; AR-1 forbids `very_good_analysis`.
        - `analyzer.plugins: [custom_lint]` — registers the `custom_lint` analyzer plugin runner; consumers running `dart analyze` will route through it.
        - `custom_lint.rules: [exhaustive_switch_must_have_default]` — enables only the principal rule for v1.0.0. Additional rules (e.g., `prefer_named_constructors_on_sealed_subtypes`, architecture line 809) are out of scope for this story.
  - [x] 3.2 This file is **the package's public API**. Any consumer of `koel_lints` writes `include: package:koel_lints/koel.yaml` in their own `analysis_options.yaml` to inherit the profile (wired everywhere by Story 1.4). Treat changes to `koel.yaml` post-v1.0.0 as a semver-affecting API change per D7 / AR-12.

- [x] **Task 4 — Author the plugin entrypoint `lib/koel_lints.dart`** (AC: 1)
  - [x] 4.1 Replace `packages/koel_lints/lib/koel_lints.dart` with the `custom_lint` plugin entrypoint. Final shape (verbatim — `library;` declaration + dartdoc per Convention §2, plus the required `createPlugin()` top-level function):
        ```dart
        /// Analyzer plugin enforcing koel's mandatory rules.
        ///
        /// Consumers wire this profile via `include: package:koel_lints/koel.yaml`
        /// in their per-package `analysis_options.yaml`. See README for details.
        library;

        import 'package:custom_lint_builder/custom_lint_builder.dart';

        import 'src/rules/exhaustive_switch_must_have_default.dart';

        /// Entry point invoked by `custom_lint` to register koel_lints rules.
        PluginBase createPlugin() => _KoelLintsPlugin();

        class _KoelLintsPlugin extends PluginBase {
          @override
          List<LintRule> getLintRules(CustomLintConfigs configs) =>
              const [ExhaustiveSwitchMustHaveDefault()];
        }
        ```
  - [x] 4.2 The `_KoelLintsPlugin` class is private (leading underscore) — only `createPlugin()` is the surface `custom_lint` discovers. **Do not export anything from this file beyond `createPlugin()`** — `koel_lints` ships zero runtime API; the analyzer profile IS the contract. Per Convention §2 the barrel re-exports nothing in this story.

- [x] **Task 5 — Author the principal rule `lib/src/rules/exhaustive_switch_must_have_default.dart`** (AC: 1, 3)
  - [x] 5.1 Create the directory `packages/koel_lints/lib/src/rules/` and write the rule file. Required behavior:
        - Subclass `DartLintRule`.
        - Define `LintCode` with `name: 'exhaustive_switch_must_have_default'`, an actionable `problemMessage`, `errorSeverity: ErrorSeverity.ERROR` (matches `koel.yaml`'s `error` severity).
        - Override `run(resolver, reporter, context)`. Use `context.registry.addSwitchStatement(...)` AND `context.registry.addSwitchExpression(...)` — both forms exist in Dart 3.x and both must be linted (Convention §3 references `switch` over sealed types in either statement or expression position).
        - For each switch node: resolve the **static type of the switch expression** via the analyzer; extract the type's element name; if the name is in the koel sealed-trio set `{'AgUiEvent', 'KoelError', 'MessageSegment'}` AND no `default:` arm exists, emit the diagnostic at the switch keyword.
        - The trio names are **hardcoded as a `static const Set<String>`** in the rule. Rationale: only three types qualify per architecture line 470-471; introducing a `custom_lint` configs surface is over-engineering for v1.0.0. Future expansion (e.g., extension to additional sealed unions) can be addressed in a v1.x minor release.
  - [x] 5.2 Sketch (annotate `// TODO(dev)` where the dev must consult `package:analyzer` 8.x source to pick the exact API; do NOT ship TODOs):
        ```dart
        import 'package:analyzer/dart/ast/ast.dart';
        import 'package:analyzer/error/error.dart';
        import 'package:analyzer/error/listener.dart';
        import 'package:custom_lint_builder/custom_lint_builder.dart';

        /// Lints switches over koel's sealed unions (`AgUiEvent`, `KoelError`,
        /// `MessageSegment`) that lack a `default:` branch.
        ///
        /// Rationale: adding a new subtype to one of these unions must remain a
        /// semver-minor bump (FR-A12 / FC-2 / NFR-17). The `default:` branch is
        /// what makes that safe for downstream switches.
        class ExhaustiveSwitchMustHaveDefault extends DartLintRule {
          const ExhaustiveSwitchMustHaveDefault() : super(code: _code);

          static const _code = LintCode(
            name: 'exhaustive_switch_must_have_default',
            problemMessage:
                'switch over sealed koel type must include a `default:` branch '
                '(adding a new subtype is a semver-minor bump per FR-A12).',
            errorSeverity: ErrorSeverity.ERROR,
          );

          static const _sealedNames = {
            'AgUiEvent',
            'KoelError',
            'MessageSegment',
          };

          @override
          void run(
            CustomLintResolver resolver,
            ErrorReporter reporter,
            CustomLintContext context,
          ) {
            context.registry.addSwitchStatement((node) {
              if (_isKoelSealedSwitch(node.expression) &&
                  !node.members.any((m) => m is SwitchDefault)) {
                reporter.atToken(node.switchKeyword, _code);
              }
            });
            context.registry.addSwitchExpression((node) {
              if (_isKoelSealedSwitch(node.expression) &&
                  !node.cases.any((c) => _isWildcardDefault(c.guardedPattern))) {
                reporter.atToken(node.switchKeyword, _code);
              }
            });
          }

          bool _isKoelSealedSwitch(Expression expr) {
            final type = expr.staticType;
            final name = type?.element3?.name3; // analyzer 8.x element API
            return name != null && _sealedNames.contains(name);
          }

          bool _isWildcardDefault(GuardedPattern guarded) {
            // `_` (WildcardPattern) without a guard = the switch-expression
            // analog of `default:`. See analyzer 8.x switch-expression patterns.
            return guarded.pattern is WildcardPattern && guarded.whenClause == null;
          }
        }
        ```
        The sketch is illustrative — the dev MUST verify the analyzer 8.x AST API (`element3.name3` vs `element.name`, `WildcardPattern`, `GuardedPattern`) against `package:analyzer`'s actual exported surface at implementation time. The contract is the behavior (AC3 fixtures), not the precise API call shape.
  - [x] 5.3 **Do NOT add `// ignore_for_file:` to this rule.** It must analyze clean under `package:lints/strict.yaml` (the self-include profile per Task 6) without local overrides.

- [x] **Task 6 — Rewrite `packages/koel_lints/analysis_options.yaml` for the G-3 exception** (AC: 4)
  - [x] 6.1 Replace the `dart create`-generated `analysis_options.yaml` with this content:
        ```yaml
        # Self-include exception (G-3): a package cannot lint itself.
        # See README "Note: self-include exception" for the rationale.
        include: package:lints/strict.yaml
        ```
        Exactly three lines (two comment + one include). Per NFR-16 / Convention §6: no multi-paragraph comments restating obvious keys; the one-line + README pointer is the documented pattern (architecture line 1160-1164).
  - [x] 6.2 **Do NOT add `include: package:koel_lints/koel.yaml` here** — even though it would technically work (the package can resolve its own `lib/koel.yaml` URI), it makes `koel_lints`'s analyzer pass enforce its own rules against its own rule source, which creates circular load-order problems and contradicts the architectural G-3 decision. Resist the urge.

- [x] **Task 7 — Replace `packages/koel_lints/README.md` with minimal real content** (AC: 4)
  - [x] 7.1 Replace the `dart create` TODO-boilerplate README (currently at `packages/koel_lints/README.md`) with the minimal content below. Story 1.6 owns the PRD §13 D-1 quality bar across all 11 READMEs; the goal here is to ship the **self-include exception note** that AC4 requires + just enough usage context to be coherent for a contributor reading the package in isolation.
        ```markdown
        # koel_lints

        Analyzer plugin enforcing koel's mandatory rules. Consumed via
        `include: package:koel_lints/koel.yaml` in any package's
        `analysis_options.yaml`. Adoption across the koel monorepo is wired in
        Story 1.4; pre-publish consumers reference `koel_lints` as a workspace
        dependency.

        ## Rules

        - `exhaustive_switch_must_have_default` (error) — switches over
          `AgUiEvent`, `KoelError`, or `MessageSegment` must declare a `default:`
          branch. Adding a new subtype to any of these sealed unions is then a
          semver-minor bump (FR-A12 / FC-2 / NFR-17).

        ## Note: self-include exception (G-3)

        `koel_lints` itself cannot include its own profile — a package cannot
        lint itself. Its local `analysis_options.yaml` extends only
        `package:lints/strict.yaml`. Every other koel package extends
        `package:koel_lints/koel.yaml`.

        ## License

        MIT. Full text added in Story 1.6.
        ```
  - [x] 7.2 **Do NOT add an `## Installation` / `## Quickstart` block targeting external consumers** — Story 1.6 owns README polish per PRD §13 D-1, and external installation instructions are premature until `koel_lints` is published (Epic 9, Story 9.9 lock-step publish). The above is the minimal coherent contributor-facing README.

- [x] **Task 8 — Author the fixture-test harness `test/rules/exhaustive_switch_test.dart` + fixtures** (AC: 3)
  - [x] 8.1 Create the directory tree:
        ```
        packages/koel_lints/test/
        └── rules/
            ├── exhaustive_switch_test.dart
            └── fixtures/
                ├── violations/
                │   └── missing_default.dart
                └── ok/
                    └── with_default.dart
        ```
  - [x] 8.2 Write `test/rules/fixtures/violations/missing_default.dart` — a self-contained Dart fixture file that declares a minimal sealed `AgUiEvent` hierarchy locally, then uses it in a `switch` lacking `default:`. The `// expect_lint:` comment at the offending switch is the test signal source (this is the `custom_lint` fixture convention). Suggested shape:
        ```dart
        // Fixture for koel_lints `exhaustive_switch_must_have_default` rule.
        // The local AgUiEvent declared here intentionally collides with koel_core's
        // future AgUiEvent by name — that's what the rule keys off (Story 1.3 §5.1).

        sealed class AgUiEvent {
          const AgUiEvent();
        }

        final class RunStartedEvent extends AgUiEvent {
          const RunStartedEvent();
        }

        final class RunFinishedEvent extends AgUiEvent {
          const RunFinishedEvent();
        }

        void describe(AgUiEvent event) {
          // expect_lint: exhaustive_switch_must_have_default
          switch (event) {
            case RunStartedEvent _:
              print('started');
            case RunFinishedEvent _:
              print('finished');
          }
        }
        ```
  - [x] 8.3 Write `test/rules/fixtures/ok/with_default.dart` — same hierarchy + same switch shape, plus a `default:` arm. NO `// expect_lint:` comment; the file must pass clean.
        ```dart
        sealed class AgUiEvent {
          const AgUiEvent();
        }

        final class RunStartedEvent extends AgUiEvent {
          const RunStartedEvent();
        }

        final class RunFinishedEvent extends AgUiEvent {
          const RunFinishedEvent();
        }

        void describe(AgUiEvent event) {
          switch (event) {
            case RunStartedEvent _:
              print('started');
            case RunFinishedEvent _:
              print('finished');
            default:
              print('unknown');
          }
        }
        ```
  - [x] 8.4 Author `test/rules/exhaustive_switch_test.dart` as the test harness driver. **Read `package:custom_lint` 0.8.1's own test harness pattern at https://github.com/invertase/dart_custom_lint before settling on an approach.** Two viable patterns:
        - **(Preferred) Comment-convention via `custom_lint run` CLI:** run `dart run custom_lint` as a process against the fixtures directory and assert the produced diagnostics match the `// expect_lint:` markers. `custom_lint` ships built-in support for the `// expect_lint:` convention; failing markers cause the CLI to exit non-zero. The test just asserts process exit code + parses output to ensure `missing_default.dart` produced exactly one `exhaustive_switch_must_have_default` diagnostic and `with_default.dart` produced zero.
        - **(Fallback) Unit-style via `analyzer`'s `AnalysisContextCollection`:** load each fixture file via `AnalysisContextCollection`, get the resolved `ResolvedUnitResult`, instantiate `ExhaustiveSwitchMustHaveDefault`, walk the AST applying the rule, collect emitted diagnostics into a fresh `ErrorReporter`, assert their codes + offsets.
        Pick ONE. Document the choice in `Completion Notes`. The Acceptance Auditor cares that AC3 passes; the harness shape is dev discretion within "uses the `custom_lint` test harness pattern" (AC text + epic line 84).
  - [x] 8.5 Verify `dart test` from `packages/koel_lints/` exits 0 after `melos bootstrap`. If the chosen harness pattern is CLI-based and slow, OK — this rule runs only on koel_lints's own CI step. No coverage gate on koel_lints fixture tests in this story (NFR-12 ≥ 90% line/branch on `koel_lints` is enforced from Epic 9 / Story 9.4; the rule has effectively 100% coverage from the two fixtures by construction).

- [x] **Task 9 — Final verification + workspace re-bootstrap** (AC: 1, 2, 3, 4)
  - [x] 9.1 Run `melos bootstrap` at the repo root. Expected: exit 0, `-> 11 packages bootstrapped`, no warnings. If `koel_lints`'s new deps fail to resolve, the most likely cause is `analyzer: ^8.0.0` clashing with a transitive constraint from another workspace member — none should exist in this story (no other package declares `analyzer`), but verify by inspecting `pubspec_overrides.yaml` (should not exist) and `pubspec.lock` (workspace-root level only).
  - [x] 9.2 Run `dart analyze packages/koel_lints/` and assert clean (0 errors / 0 warnings) under the G-3 self-include profile. The expected `include_file_not_found` warning that Story 1.2's Completion Notes documented for every other package does NOT apply here — `koel_lints` now has `dev_dependencies` declared (Task §2.1), so its `analysis_options.yaml`'s `include: package:lints/strict.yaml` resolves cleanly.
  - [x] 9.3 Run `dart test` from `packages/koel_lints/` (or `dart pub run test`). Expected: 2 fixtures × expected outcomes pass, 0 failures.
  - [x] 9.4 Verify AR-1 globally: `grep -rn very_good_analysis packages/` returns zero matches.
  - [x] 9.5 Verify file presence: each of the following exists with non-empty content:
        - `packages/koel_lints/pubspec.yaml`
        - `packages/koel_lints/analysis_options.yaml`
        - `packages/koel_lints/README.md`
        - `packages/koel_lints/lib/koel.yaml`
        - `packages/koel_lints/lib/koel_lints.dart`
        - `packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart`
        - `packages/koel_lints/test/rules/exhaustive_switch_test.dart`
        - `packages/koel_lints/test/rules/fixtures/violations/missing_default.dart`
        - `packages/koel_lints/test/rules/fixtures/ok/with_default.dart`
  - [x] 9.6 Verify barrel hygiene: `grep -nE "^\s*export\s" packages/koel_lints/lib/koel_lints.dart` returns zero matches (Convention §2 — the barrel re-exports nothing in this story; `createPlugin()` is the surface, not a re-export). The other 10 packages' barrels are unchanged from Story 1.2.
  - [x] 9.7 Verify the AR-25 placeholder is untouched: `grep -n "flutter:" packages/koel_lints/pubspec.yaml` returns nothing (Dart-only package; no Flutter constraint).
  - [x] 9.8 Document every diagnostic / warning surfaced during 9.1–9.7 in Completion Notes (even if expected and benign).

### Review Findings

_Code review 2026-05-28 — 3 parallel layers (Blind Hunter / Edge Case Hunter / Acceptance Auditor) against `git diff 5908715 -- packages/koel_lints/` (320 lines, 9 files). 58 raw findings → 1 patch, 1 decision-needed, 12 deferred, 44 dismissed (intentional per spec or out-of-scope)._

- [x] [Review][Decision→Patch] Switch-expression fixture coverage gap — resolved: added `fixtures/violations/missing_default_expression.dart` + `fixtures/ok/with_default_expression.dart` (3-subtype shape mirroring statement-form Deviation 4) + 2 new test cases in `exhaustive_switch_test.dart`. `dart test` → 4/4 passing.
- [x] [Review][Patch] README documentation drift: `strict.yaml` → `recommended.yaml` [packages/koel_lints/README.md:20]
- [x] [Review][Defer] Architecture doc + spec AC text reference nonexistent `package:lints/strict.yaml` — `package:lints` only ships `core.yaml` + `recommended.yaml`; `strict.yaml` never existed across versions 1.0.1 → 6.1.0. Deviation 2 closed in-place; spec/architecture erratum needed for AC1, AC4, Task 3.1, Task 6.1, `architecture.md:1163`. — deferred to spec erratum pass
- [x] [Review][Defer] AC2 enumeration missing `lints: ^6.0.0` dev_dep — Required to resolve the `include:` in both `analysis_options.yaml` and `koel.yaml` (without it, `dart analyze` emits `include_file_not_found` and breaks NFR-13 gate). Deviation 1 closed in-place. — deferred to spec erratum pass
- [x] [Review][Defer] AC3 vs Task 8.4 wording contradiction on `// expect_lint:` signal source — AC3 says fixtures use `// expect_lint:` "as the test signal source"; Task 8.4 says "Pick ONE" harness pattern (CLI subprocess OR analyzer-driven). `// expect_lint:` is `custom_lint`'s suppression marker, not a positive assertion convention. Deviation 3 used `testAnalyzeAndRun` (analyzer-driven) — functionally correct, AC3-text mismatch. — deferred to spec erratum pass
- [x] [Review][Defer] README "Rules" (plural) oversells single-rule v1.0.0 + missing profile-semver policy — `koel.yaml` is one rule on top of `recommended.yaml`; downstream consumers extending `package:koel_lints/koel.yaml` have no documented contract on what a `koel_lints` minor bump adds. — deferred to Story 1.6 README polish (PRD §13 D-1)
- [x] [Review][Defer] Caret pin on `custom_lint` / `custom_lint_builder` `^0.8.1` is a 0.x footgun + no renovate/dependabot config — `0.x` minors are allowed to break; no CI matrix proving the floor; no auto-bump review channel. — deferred to Story 1.5 CI / Story 1.6 toolchain matrix
- [x] [Review][Defer] Severity downgrade / per-consumer disable path not documented — Rule is hardcoded ERROR; consumers wanting `warning` or to disable have no documented override snippet for `analysis_options.yaml`. — deferred to Story 1.4 adoption docs
- [x] [Review][Defer] `analyzer.plugins` merge vs override semantics for consumers — If a consumer already declares `analyzer.plugins:` themselves, include-merging vs overwriting behavior is unspecified; could silently disable `custom_lint`. — deferred to Story 1.4 adoption integration test
- [x] [Review][Defer] Diagnostic reported at `switchKeyword` (head of switch) — no IDE quick-fix; better UX would be reporting at `rightBracket`/last member + providing a `DartFix` that inserts `default: throw StateError(...)` for statements and `_ => throw StateError(...)` for expressions. — deferred to v1.x rule polish
- [x] [Review][Defer] Edge-case AST handling not covered (intentional per Dev Notes 412-416, but accumulate for v1.x) — nullable `AgUiEvent?`, typedef alias of sealed type, extension type with colliding name, upcast to `Object?` hiding sealed origin, parenthesized wildcard `(_)`, `case _:` and `case Object():` catch-alls in switch-statement form, typed wildcard `Object _` / `dynamic _` as default analog in switch-expression. — deferred to v1.x rule refinement
- [x] [Review][Defer] Fixture coverage gaps: `KoelError`, `MessageSegment`, switch-expression form (see also Decision), nested switches in lambdas, single-file element resolution, guarded wildcard arm — only `AgUiEvent` + switch-statement form + ungarded patterns exercised today. — deferred to v1.x test expansion
- [x] [Review][Defer] Transitive `lints` dep resolution for downstream consumers — `lints` is dev-only in `koel_lints`; downstream packages extending `package:koel_lints/koel.yaml` may not resolve `package:lints/recommended.yaml` at analyze-time outside the workspace. — Story 1.4 adoption + Story 9.5 publish dry-run will surface
- [x] [Review][Defer] `custom_lint.rules:` YAML list-of-strings vs map-with-severity syntax for 0.8.1 not verified via consumer plugin path — `testAnalyzeAndRun` bypasses the plugin discovery flow; profile is only end-to-end exercised when a consumer includes `koel.yaml` and runs `dart analyze`. — Story 1.4 adoption is the integration test
- [x] [Review][Defer] Diagnostic `problemMessage` hardcodes `FR-A12` jargon opaque to consumers — message should phrase concern in user terms + put FR ref in `correctionMessage` or doc URL. — deferred to v1.x rule polish

## Dev Notes

### Critical architectural anchors

- **D3 / AR-5 (custom_lint pin):** `koel_lints` is built on `package:custom_lint` 0.8.1 — the Invertase analyzer-plugin wrapper used by `riverpod_lint` and `hooks_riverpod_lint`. Raw `analyzer_plugin` API is a yak-shave for one rule. The 8-month staleness in late 2025 was acceptable; the 2026-05-28 0.8.1 release is fresh. **Do not substitute `analysis_server_plugin` (the Dart 3.10+ native API)** even though riverpod_lint has migrated — the architectural decision is `custom_lint` 0.8.1 (AR-5, AR-23). [Source: `_bmad-output/planning-artifacts/architecture.md` §D3 lines 273-281 + `requirements-inventory.md:132`]
- **FR-A12 / FC-2 / NFR-17 (forward-compat policy):** Adding a new subtype to a sealed AG-UI event / koel error / message segment must be a semver-MINOR bump (not major). That commitment is **only safe** if every consumer's `switch` over the sealed type has a `default:` arm. `exhaustive_switch_must_have_default` is the mechanism that makes that policy enforceable rather than aspirational. Without this rule, `koel` couldn't ship lock-step minor bumps when adding a 29th AG-UI event type in v1.x. [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md:20, 108-109, 116` + `architecture.md` lines 470-471]
- **Convention §2 (barrel = public contract):** `lib/koel_lints.dart` is the barrel. The package's *runtime* public API is zero symbols (just `createPlugin()`, called by the `custom_lint` CLI). The package's *analyzer* public API is `lib/koel.yaml` (consumer-facing profile). Treat them both as semver-affecting from v1.0.0. [Source: `architecture.md` §"Implementation Patterns" §2 lines 386-462]
- **AR-1 (very_good_analysis ban):** Banned everywhere repo-wide. `package:lints/strict.yaml` (Dart team) is the baseline. `koel_lints` adds the principal rule on top. Confirmed clean across all 11 packages in Story 1.2 (zero `very_good_analysis` grep hits). [Source: `requirements-inventory.md:125`]
- **AR-23 G-3 (self-include exception):** A package cannot lint itself. `koel_lints/analysis_options.yaml` extends only `package:lints/strict.yaml`. Documented one-line + README pointer (Task 6 + 7). [Source: `architecture.md` lines 1160-1164]
- **AR-3 (bootstrap order):** `koel_lints` is the SECOND package built (after the workspace skeleton) precisely because every other package's `analysis_options.yaml` will `include` it from day one (Story 1.4). Foundation lock-step boundary: `koel_core` + `koel_http` + `koel_lints` ship at identical semver from v1.0.0. [Source: `requirements-inventory.md:127` + `architecture.md` lines 80, 991]
- **NFR-13 (analyze clean gate):** `dart analyze` MUST be zero warnings across every package under `package:koel_lints/koel.yaml`. Story 1.2 documented one expected `include_file_not_found` warning per non-koel_lints package because dev_deps were stripped; Story 1.4 closes that by adding the `include: package:koel_lints/koel.yaml` line. This story does NOT touch the other 10 packages' `analysis_options.yaml`. [Source: `requirements-inventory.md:109`]

### Library / version pins (already decided — do not re-evaluate)

| Item | Version | Decision ref |
|---|---|---|
| `custom_lint` | `^0.8.1` (dev_dep on `koel_lints`; locked release SHA 2025-09-09) | AR-5 / D3 |
| `custom_lint_builder` | `^0.8.1` (runtime dep; the library imported by plugin code) | implicit from AR-5 — `custom_lint_builder` is the plugin author's library; the `custom_lint` CLI is the runner |
| `analyzer` | `^8.0.0` (runtime dep; pinned to match `custom_lint`'s transitive constraint — `custom_lint` 0.8.1 declares `analyzer: ^8.0.0`. Latest published is 13.0.0, but using ^13 would conflict.) | derived from AR-5 |
| `test` | `^1.20.2` (fixture-test harness) | matches `custom_lint`'s own constraint |
| Dart SDK floor | `>=3.9.0 <4.0.0` | D1, AR-3 — unchanged from Stories 1.1 / 1.2 |
| Lints profile baseline | `package:lints/strict.yaml` | AR-1 |

**Out-of-scope deps (do NOT add):** `analysis_server_plugin`, `analyzer_plugin` (transitive via `custom_lint_builder`; declaring it directly is redundant), `riverpod`, `meta`, `path` (none used by this rule). If `freezed` / `json_serializable` codegen needs surface inside `koel_lints` post-v1.0.0, that's a separate decision — this story ships zero codegen.

### Existing repo state (verified before story creation)

After Story 1.2 (commit `5908715`), `packages/koel_lints/` contains:

```
packages/koel_lints/
├── .gitignore                  # from dart create; redundant with root, harmless
├── CHANGELOG.md                # placeholder: "## 1.0.0\n\n- Initial version."
├── LICENSE                     # one-line: "MIT — full license text added in Story 1.6 (FR-H5)."
├── README.md                   # dart create TODO boilerplate
├── analysis_options.yaml       # include: package:lints/recommended.yaml (REPLACE)
├── lib/
│   └── koel_lints.dart         # empty barrel: dartdoc + library; only (REPLACE)
├── melos_koel_lints.iml        # IDE artifact, gitignored
├── pubspec.yaml                # name/description/version/publish_to/env/resolution; NO deps (REPLACE)
└── test/                       # empty (sample test removed in Story 1.2)
```

After this story:

```
packages/koel_lints/
├── .gitignore                  # unchanged
├── CHANGELOG.md                # unchanged (Story 1.6 normalizes; see deferred-work.md)
├── LICENSE                     # unchanged (Story 1.6 lands MIT)
├── README.md                   # REWRITTEN per Task 7
├── analysis_options.yaml       # REWRITTEN per Task 6 (G-3 self-include exception)
├── lib/
│   ├── koel.yaml               # NEW — consumer analyzer profile (Task 3)
│   ├── koel_lints.dart         # REWRITTEN — plugin entrypoint (Task 4)
│   └── src/
│       └── rules/
│           └── exhaustive_switch_must_have_default.dart   # NEW (Task 5)
├── melos_koel_lints.iml        # unchanged, gitignored
├── pubspec.yaml                # REWRITTEN — plugin deps (Task 2)
└── test/
    └── rules/
        ├── exhaustive_switch_test.dart            # NEW — harness driver (Task 8)
        └── fixtures/
            ├── violations/
            │   └── missing_default.dart           # NEW (Task 8)
            └── ok/
                └── with_default.dart              # NEW (Task 8)
```

### Why the `analyzer: ^8.0.0` pin (not `^13.0.0`)

`custom_lint` 0.8.1 declares `analyzer: ^8.0.0` as a dependency (verified via `https://pub.dev/api/packages/custom_lint`, latest pubspec). The latest standalone `analyzer` is 13.0.0 (2026-05). Declaring `analyzer: ^13.0.0` in `koel_lints` would cause pub resolution to fail because `^13.0.0` is incompatible with `^8.0.0`.

The rule code in Task §5 uses the analyzer AST API. The AST API shape evolved between 8.x and 13.x (e.g., `Element.name3` and `element3` getters were added in 8.x as the migration target). The sketch in §5.2 references `type?.element3?.name3` which is the 8.x form; if 13.x changes this, the dev codes against 8.x (per the `^8.0.0` constraint). **Do not jump to 13.x** even if it "looks cleaner" — staying inside `custom_lint`'s constraint is mandatory for the workspace to resolve.

When `custom_lint` 0.9.x ships and bumps to `analyzer: ^13.0.0`, koel_lints can ride that wave in a coordinated minor bump (lock-step with `koel_core` per AR-3). Until then, 8.x.

### How `custom_lint` plugin discovery works (one-paragraph mental model)

When a consumer runs `dart analyze` in a package whose `analysis_options.yaml` includes `package:koel_lints/koel.yaml`, the analyzer reads `koel.yaml`, sees `analyzer.plugins: [custom_lint]`, and bootstraps `custom_lint` as an analyzer plugin. `custom_lint` then scans the consumer's `pubspec.yaml` `dev_dependencies` for any package depending on `custom_lint_builder` (that's the marker for "this is a plugin"); it finds `koel_lints`, loads `lib/koel_lints.dart`, calls `createPlugin()`, and receives the `_KoelLintsPlugin`. For each rule listed under `custom_lint.rules:` in `koel.yaml` whose name matches a rule returned by `getLintRules()`, the rule runs against every analyzed source file.

The implication for Story 1.4: every non-lints package must declare BOTH `custom_lint` AND `koel_lints` in `dev_dependencies` (the former so `dart analyze` knows the plugin runner exists; the latter so `custom_lint` finds the rule registration). That's already in Story 1.4's epic AC ("`koel_lints` appears as a path dependency to `../koel_lints` ... **And** `custom_lint` appears as a dev dependency on each package consuming the profile"), but note the wording correction flagged in `deferred-work.md` (Story 1.4 cannot use a `path:` declaration against a workspace sibling; it must use a bare workspace-style declaration).

### Critical AST nuance — element name resolution

The rule fires on `switch` whose expression's *static type's element name* is in `{'AgUiEvent', 'KoelError', 'MessageSegment'}`. Two implications:

1. **Names, not full type identity.** A consumer who declares their own local `sealed class AgUiEvent` (as our fixture does!) trips the rule — that's intentional. The cost of a false positive on a misnamed local class is tiny (rename or add `default:`); the value of fixture tests working without depending on `koel_core` (which doesn't exist yet, Story 2.1+) is significant.
2. **Static type, not runtime type.** A switch over `Object event` where `event` happens to be `AgUiEvent` at runtime does NOT trip — because the static type is `Object`, not `AgUiEvent`. This matches Dart's switch-exhaustiveness checker's behavior and is the correct semantics.

### Why hardcode the trio (not configure)

Three options were on the table:
1. **Hardcode `{'AgUiEvent', 'KoelError', 'MessageSegment'}` in the rule.** ← chosen.
2. **Configurable via `custom_lint` config in `koel.yaml`:** `custom_lint.rules.exhaustive_switch_must_have_default.types: [AgUiEvent, KoelError, MessageSegment]`.
3. **Detect sealed-ness from the type's element directly** (any `sealed class` requires `default:`).

(1) wins because: only three types qualify per architecture line 470-471; the policy goal (FR-A12) is specifically about koel's three sealed unions, not "all sealed types ever"; configuration adds surface area + version-coupling between `koel.yaml` and the rule that's hard to walk back. (3) would over-fire on consumer-defined sealed types unrelated to koel — false positives in user code = pain. If v1.x reveals a need for a fourth type, that's a koel_core release-time decision and a koel_lints minor bump.

The fixture's locally-declared `AgUiEvent` is a feature, not a bug — it lets the test run without the eventual `koel_core` exposure (which doesn't exist until Epic 2 / Story 2.1+).

### File structure requirements

After this story (matches `architecture.md` lines 800-818 "koel_lints — non-standard structure"):

```
packages/koel_lints/
├── analysis_options.yaml       # G-3 self-include exception
├── lib/
│   ├── koel.yaml               # consumer profile (PUBLIC API)
│   ├── koel_lints.dart         # plugin entrypoint
│   └── src/
│       └── rules/
│           └── exhaustive_switch_must_have_default.dart
├── pubspec.yaml
├── README.md                   # documents G-3 + rule list
└── test/
    └── rules/
        ├── exhaustive_switch_test.dart
        └── fixtures/
            ├── violations/
            │   └── missing_default.dart
            └── ok/
                └── with_default.dart
```

**Out of scope for Story 1.3** (do NOT create / modify in this story):
- Any other package's `analysis_options.yaml` (Story 1.4 owns adoption).
- Any other package's `pubspec.yaml` (Story 1.4 adds `custom_lint` + `koel_lints` dev_deps).
- The repo-root `analysis_options.yaml` (Story 1.4).
- The full PRD §13 D-1 README quality bar (Story 1.6 — current README is minimal-but-coherent only).
- The `LICENSE` file content (Story 1.6 lands the byte-identical MIT text).
- The `CHANGELOG.md` content (Story 1.6 normalizes the headers across all 11 — see `deferred-work.md` Story 1.2 entries on CHANGELOG drift).
- Any second rule (`prefer_named_constructors_on_sealed_subtypes` — architecture line 809 — is explicitly optional; out of v1.0.0 scope for this story).
- A `custom_lint` config layer / configurable trio names.
- Wiring `dart_apitool` (D7) — Story 9.3 owns API baseline gates.
- Adding `koel_lints` to the `melos run analyze` script (Story 1.4 wires `melos run analyze`).
- Touching the workspace root `pubspec.yaml`'s `melos.scripts:` block.
- Reserving `koel_lints` on pub.dev (Story 1.6 / FR-H4).
- Adding `analyzer_plugin` as a direct dep (transitive via `custom_lint_builder`).

### Previous story intelligence (from Story 1.2 commit `5908715`)

- **Pubspec round-trip discipline:** Story 1.2 rewrote all 11 pubspecs to be byte-identical to the Story 1.1 baseline. This story DIVERGES from that — `packages/koel_lints/pubspec.yaml` gains a `dependencies:` and `dev_dependencies:` block (Task §2.1). That divergence is intentional and on-spec (epic AC2 explicitly enumerates the deps). The other 10 packages stay round-trip-byte-identical to `5908715`.
- **`include_file_not_found` was a deliberate trade in Story 1.2** — every package's `analysis_options.yaml` includes a profile (`package:lints/recommended.yaml` for Dart pkgs, `package:flutter_lints/flutter.yaml` for Flutter pkgs) but no dev_dependencies were declared to resolve the include. Story 1.4 closes the gap. For `koel_lints` specifically, this story closes it locally (the self-include profile is `package:lints/strict.yaml`, NOT `recommended`, and Task §2.1 adds the deps that let `dart analyze packages/koel_lints/` resolve cleanly).
- **`koel_lints` was scaffolded identically to other Dart packages by Story 1.2** (per its Task §4.1) — same `dart create --template=package` shape, same description, same empty barrel. Story 1.3 picks up from that baseline and applies the plugin restructure.
- **Dart 3.12 scaffold-time drift (deferred):** Story 1.2 was scaffolded on Dart 3.12.0 but the SDK floor is 3.9.0. If a contributor re-scaffolds on Dart 3.9 they may see template variance (e.g., `_base.dart` shape). This story's edits don't depend on the original template shape (we REPLACE every file we touch), so the drift is contained.
- **Workspace pub-workspace sibling dep wording (deferred):** Story 1.4's spec mirrors a "(path)" phrasing in Story 1.2 Dev Notes line 171 that's incorrect — `dart pub workspace` rejects `path:` deps targeting workspace members; siblings must declare a bare `koel_lints:` entry. This story doesn't touch Story 1.4's pubspec edits, but flag if the Story 1.4 spec lands with the wrong wording. (Tracked in `deferred-work.md`.)
- **CHANGELOG drift (deferred to Story 1.6):** koel_lints's CHANGELOG.md ships `## 1.0.0` while pubspec is `0.0.1` — Dart 3.12 template default. Do NOT fix it in this story; Story 1.6 owns normalization.

### Anti-patterns to reject in review

- ❌ Using `analysis_server_plugin` (the Dart 3.10+ native plugin API) — architecture pin is `custom_lint` 0.8.1 (AR-5).
- ❌ Declaring `analyzer: ^13.0.0` — conflicts with `custom_lint`'s `^8.0.0` constraint.
- ❌ Including `package:koel_lints/koel.yaml` from `packages/koel_lints/analysis_options.yaml` — G-3 says a package cannot lint itself.
- ❌ Including `very_good_analysis` anywhere (AR-1).
- ❌ Adding `koel_lints` as a dep / dev_dep to any other package (Story 1.4 owns adoption).
- ❌ Editing the `melos run analyze` script body in workspace pubspec (Story 1.4 wires it).
- ❌ Adding a second lint rule (e.g., `prefer_named_constructors_on_sealed_subtypes`) — explicitly out of v1.0.0 scope; ship the principal rule only.
- ❌ Making the trio names configurable via `custom_lint` configs — over-engineered; hardcode `{AgUiEvent, KoelError, MessageSegment}`.
- ❌ Using full type identity (library URI match) instead of element name match — depends on `koel_core` existing, which it doesn't (Story 2.1+). Fixture tests would break.
- ❌ Importing anything from `koel_core` in the rule (`koel_core` doesn't exist yet; would create a phantom dependency).
- ❌ Re-exporting `_KoelLintsPlugin` or `ExhaustiveSwitchMustHaveDefault` from `lib/koel_lints.dart` — `createPlugin()` is the only public surface; the package's *runtime* API is empty.
- ❌ Adding `// ignore_for_file:` directives to the rule source — must analyze clean under `package:lints/strict.yaml`.
- ❌ Adding `analyzer_plugin` as a direct dep (already transitive via `custom_lint_builder`; declaring it directly is noise + version-coupling risk).
- ❌ Pinning Dart SDK above `>=3.9.0 <4.0.0` (D1).
- ❌ Editing other packages' `lib/<name>.dart` barrels — they remain empty per Story 1.2 baseline.
- ❌ Multi-paragraph comments in YAML restating obvious key meanings (NFR-16 / Convention §6).
- ❌ Sample/illustrative code committed as production (the §5.2 sketch is illustrative — the dev MUST verify against actual `package:analyzer` 8.x exports before committing).
- ❌ Pinning Flutter floor in `packages/koel_lints/pubspec.yaml` — koel_lints is Dart-only (no Flutter constraint).
- ❌ Adding `example/` directory to koel_lints (Story 1.2 deleted the Dart 3.12-emitted `example/`; do NOT recreate. Per Convention §6 every package gets an `example/` eventually, but for `koel_lints` the "example" IS the `koel.yaml` profile — Story 1.6 / 9.2 sample app owns the eventual demonstration).

### Testing requirements

- **Functional gate (AC3):** `dart test` in `packages/koel_lints/` passes with both fixtures producing the expected diagnostic count.
- **Static gate (AC1, 4):** `dart analyze packages/koel_lints/` exits 0 with zero warnings under the G-3 self-include profile.
- **Workspace gate (AC2):** `melos bootstrap` exits 0 with `-> 11 packages bootstrapped` after the new deps are added.
- **AR-1 gate:** `grep -rn very_good_analysis packages/` returns zero matches.
- **No NFR-12 coverage gate enforced for this story** — Epic 9 / Story 9.4 lights up coverage CI. The fixture-based design gives effectively 100% coverage of the rule by construction.
- **No `dart_apitool` baseline** — D7 / Story 9.3 owns API surface baselining.

The architecture (line 593-594) notes that `@nodoc` triggers a `koel_lints` warning to encourage privatization. **Do NOT implement that warning in this story** — it is a future v1.x rule, not part of v1.0.0 scope. The principal rule is the only rule.

### Architecture compliance — what this story enables for later

- **Story 1.4** wires `include: package:koel_lints/koel.yaml` into every non-lints package's `analysis_options.yaml` + adds `koel_lints` + `custom_lint` as `dev_dependencies` everywhere. Depends on `lib/koel.yaml` (Task 3) and the plugin entrypoint (Task 4) shipping in this story.
- **Story 2.1+ (Epic 2)** introduces the real `sealed class AgUiEvent` in `koel_core/lib/src/event/ag_ui_event.dart`. Once that lands, every `koel_core` switch over `AgUiEvent` MUST have a `default:` arm per this rule. The rule enforces the FR-A12 / FC-2 commitment that future event additions are minor bumps.
- **Story 2.3 (`koel_error`)** + **Story 6.5 (`MessageSegment`)** introduce the other two sealed types in the trio. They inherit the same `default:` arm requirement automatically — the rule is already in place.
- **Story 9.3 (API diff baseline)** treats `lib/koel.yaml` as part of the API surface for `dart_apitool` purposes. Changing the rule list or severity post-v1.0.0 is a semver-relevant change.
- **Story 9.9 (v1.0.0 lock-step publish)** publishes `koel_core` + `koel_http` + `koel_lints` at identical version. `koel_lints` is one of the three lock-step packages; its v1.0.0 publish gates on this story's deliverables being green in CI.

### Git intelligence

- **Last commit on `main`:** `5908715 chore(story-1.2): scaffold 11 publishable koel_* packages` (2026-05-28). This story builds on the 11-package skeleton state.
- **Working tree:** clean per `git status` at story creation (2026-05-28).
- **Recent commit pattern (from Stories 1.1, 1.2):** `chore(story-X.Y): <descriptive subject>` + bullet body. Commit on completion of this story should match: `chore(story-1.3): wire koel_lints custom_lint plugin + principal rule`.
- **Code review history:** Stories 1.1 + 1.2 both auto-flipped to `done` via the `/bmad-code-review` workflow (per `feedback_bmad_code_review_autocommit.md` memory). Same flow applies here — review + auto-commit on green.
- **Deferred items relevant to this story (from `deferred-work.md`):**
  - "koel_lints not wired to consumers" — closed by Stories 1.3 + 1.4 jointly.
  - "Story 1.4 wording: `koel_lints` cannot be added as `path:` dev-dep" — informational for the *next* story; this story doesn't touch other packages' pubspecs.
  - "Empty `test/` and absent `lib/src/` dirs not tracked by git" — this story creates real content under `lib/src/rules/` and `test/rules/` for `koel_lints`, so the gap is closed for this package (still open for the other 10).

### Latest tech notes (verify at implementation time)

- **`custom_lint` 0.8.1 release date:** 2025-09-09 (latest stable; pubspec verified via pub.dev API). Predecessor `0.8.0` shipped 2025-07-25; the 0.7.x series predates that. No breaking changes between 0.8.0 and 0.8.1 per the changelog (verify at https://pub.dev/packages/custom_lint/versions).
- **`custom_lint_builder` mirrors `custom_lint` versioning** (also `0.8.1`, depends on `custom_lint: 0.8.1` exact). Always pin both at the same minor.
- **`analyzer` 8.x AST API drift:** Dart team renamed several `Element` getters to add `2` / `3` suffixes during the 7→8 migration (`element` → `element3`, `name` → `name3`). The §5.2 sketch uses the 8.x form. If the actual `package:analyzer` 8.0.0+ surface differs at implementation time, code against what's actually exported — `dart pub get` produces the exact version under `.dart_tool/package_config.json`; spelunk there to verify.
- **`riverpod_lint` is NOT a valid reference** for the 0.8.x API — it migrated to `analysis_server_plugin` in early 2026. Refer to (in priority order):
  1. `package:custom_lint`'s own example (https://github.com/invertase/dart_custom_lint/tree/main/packages/custom_lint_builder/example) — but as of 2026-05-28 the example is sparse.
  2. The `custom_lint_builder` README + dartdoc (https://pub.dev/documentation/custom_lint_builder/latest/).
  3. Older `riverpod_lint` releases at the `^0.6.x` / `^0.7.x` constraint range (git blame to a tag).
- **Pub workspace** docs: https://dart.dev/tools/pub/workspaces — `resolution: workspace` line on each member is the contract. Confirmed working from Stories 1.1 / 1.2.
- **`test: ^1.20.2`** is the constraint `custom_lint` declares as a dev-dep on itself. Using the same major minimizes resolver surprises. Latest `test` is 1.27.x as of 2026-05 — `^1.20.2` resolves to current latest cleanly.

### Project Structure Notes

- **Alignment:** Matches architecture §"`koel_lints` — non-standard structure (custom_lint plugin)" lines 800-818 exactly. The optional second rule (`prefer_named_constructors_on_sealed_subtypes`, line 809) is deferred per "Out of scope" above.
- **Detected conflicts:** None. AC1's required file paths match the architecture's enumerated layout.
- **Variances from architecture target state** (intentional, bounded — closed by later stories):
  - Only ONE rule shipped (`exhaustive_switch_must_have_default`); the optional `prefer_named_constructors_on_sealed_subtypes` is deferred to a v1.x minor at most. **Closed:** at the dev team's discretion (post-v1.0.0).
  - README is minimal-coherent, not PRD §13 D-1 quality. **Closed by Story 1.6.**
  - `CHANGELOG.md` retains the `## 1.0.0` Dart 3.12 template default while pubspec is `0.0.1`. **Closed by Story 1.6** (CHANGELOG normalization).
  - `LICENSE` is one-line placeholder. **Closed by Story 1.6.**
  - `package:koel_lints/koel.yaml` is not yet adopted by any other package. **Closed by Story 1.4.**
  - `dart_apitool` baseline is not yet established. **Closed by Story 9.3.**

### References

- [Story 1.3 acceptance criteria source: `_bmad-output/planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md` §"Story 1.3"](../planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md#story-13-build-koel_lints-profile-and-principal-rule)
- [Architecture §D3 — `koel_lints` analyzer plugin technology (custom_lint 0.8.1 pin): `_bmad-output/planning-artifacts/architecture.md` lines 273-281](../planning-artifacts/architecture.md)
- [Architecture §"`koel_lints` — non-standard structure (custom_lint plugin)" — layout spec: `_bmad-output/planning-artifacts/architecture.md` lines 800-818](../planning-artifacts/architecture.md)
- [Architecture §"Implementation Patterns" §3 — "Sealed switches always have `default:` arms": `_bmad-output/planning-artifacts/architecture.md` lines 470-490](../planning-artifacts/architecture.md)
- [Architecture §"Enforcement summary" — automated vs convention lint gates: `_bmad-output/planning-artifacts/architecture.md` lines 623-640](../planning-artifacts/architecture.md)
- [Architecture §"G-3. `koel_lints` self-include exception": `_bmad-output/planning-artifacts/architecture.md` lines 1160-1164](../planning-artifacts/architecture.md)
- [Requirements inventory FR-A12, NFR-13, NFR-17, AR-1, AR-3, AR-5, AR-23: `_bmad-output/planning-artifacts/epics/requirements-inventory.md` lines 20, 108-116, 125-148](../planning-artifacts/epics/requirements-inventory.md)
- [PRD §10.4 N-12 (coverage tiers), §10.4 N-13 (analyze gate): `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md`](../planning-artifacts/prds/prd-koel-2026-05-27/prd.md)
- [Story 1.2 implementation record (baseline this story builds on): `_bmad-output/implementation-artifacts/1-2-scaffold-publishable-packages.md`](./1-2-scaffold-publishable-packages.md)
- [Deferred work tracking (cross-story scope boundaries): `_bmad-output/implementation-artifacts/deferred-work.md`](./deferred-work.md)
- [Implementation readiness report (FR-A12 → 1.3/1.4 trace; AR-5 → 1.3; AR-23 G-3 → 1.3): `_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-28.md`](../planning-artifacts/implementation-readiness-report-2026-05-28.md)
- [custom_lint package: https://pub.dev/packages/custom_lint](https://pub.dev/packages/custom_lint)
- [custom_lint_builder package + plugin author docs: https://pub.dev/packages/custom_lint_builder](https://pub.dev/packages/custom_lint_builder)
- [Invertase dart_custom_lint repo: https://github.com/invertase/dart_custom_lint](https://github.com/invertase/dart_custom_lint)
- [Dart `package:lints` strict profile: https://pub.dev/packages/lints](https://pub.dev/packages/lints)
- [analyzer 8.x package: https://pub.dev/packages/analyzer/versions/8.0.0](https://pub.dev/packages/analyzer/versions/8.0.0)
- [Pub workspaces: https://dart.dev/tools/pub/workspaces](https://dart.dev/tools/pub/workspaces)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (Claude Code, `/bmad-dev-story` workflow + `/agent-flutter-engineer` specialist)

### Debug Log References

- `dart analyze packages/koel_lints/` → exit 0, "No issues found!" (Task 9.2)
- `dart test` (from `packages/koel_lints/`) → 2/2 passing (Task 9.3, AC3)
- `melos bootstrap` → exit 0, `-> 11 packages bootstrapped`, no warnings (Task 9.1)
- Workspace-wide `dart analyze` (from repo root) → 3 pre-existing `include_file_not_found` warnings on `koel_devtools` / `koel_flutter` / `koel_widgets` (`package:flutter_lints/flutter.yaml`); Story 1.2 baseline state, deferred to Story 1.4 per `deferred-work.md`. NOT regressions caused by this story. The other 7 packages' `package:lints/recommended.yaml` includes now resolve cleanly because `lints` was added to `koel_lints`'s `dev_dependencies` (see Completion Notes deviation 1) and is therefore visible workspace-wide via the shared `.dart_tool/package_config.json`.

### Completion Notes List

**Functional outcome**

- All 9 tasks / 30 subtasks completed. All four ACs satisfied:
  - **AC1** layout matches: `lib/koel.yaml`, `lib/koel_lints.dart` (entry with `createPlugin()` → `PluginBase`), `lib/src/rules/exhaustive_switch_must_have_default.dart`.
  - **AC2** deps as enumerated PLUS `lints: ^6.0.0` dev_dep (see Deviation 1). No `very_good_analysis` anywhere (`grep -rn very_good_analysis packages/` → zero matches, AR-1).
  - **AC3** fixture-test asserts: violation fixture emits exactly 1 `exhaustive_switch_must_have_default` diagnostic at the `switch` keyword; ok fixture emits zero diagnostics. Both fixtures use `// expect_lint:` comment convention (documentation; harness uses returned `Diagnostic` list as the actual signal — see Deviation 3).
  - **AC4** `analysis_options.yaml` extends `package:lints/recommended.yaml` (see Deviation 2), G-3 exception documented inline + in README "Note: self-include exception" section.

**Deviations from story spec (intentional, justified, documented for review)**

1. **`lints: ^6.0.0` added as `dev_dependency` (not enumerated in AC2).** Required by AC1's `lib/koel.yaml` and AC4's `analysis_options.yaml`, both of which `include` a profile from the `lints` package. Without this dep, `dart analyze packages/koel_lints/` emits `include_file_not_found`, blocking Task 9.2's "clean exit" gate. AC2 enumeration was incomplete; closing the gap is the minimal-and-only path to passing AC1+AC4 verification. Side effect: 7 of 10 non-Flutter packages in the workspace also resolve their pre-existing `package:lints/recommended.yaml` includes cleanly now, partially anticipating Story 1.4's adoption work (not a problem — Story 1.4 still owns wiring `koel_lints` itself to every consumer).

2. **`include: package:lints/strict.yaml` → `include: package:lints/recommended.yaml`.** Story Tasks 3.1, 6.1 and AC1, AC4 all reference `package:lints/strict.yaml`. That file does NOT exist in any version of `package:lints` (latest: 6.1.0); the package only ships `core.yaml` and `recommended.yaml`. Verified across pub-cached versions 2.0.1 → 6.1.0 — no `strict.yaml` ever shipped. `recommended.yaml` is the Dart team's recommended (and de-facto "strict-ish") profile; it is also Story 1.2's established baseline across the workspace (per Story 1.2 Dev Notes line 472). Story author likely confused with `very_good_analysis`'s "strict" branding (which is AR-1-banned). The koel_lints profile (`lib/koel.yaml`) and its self-include `analysis_options.yaml` both now reference `recommended.yaml`. The spirit of AR-1 ("Dart team's standard set as baseline; no `very_good_analysis`") is preserved.

3. **Test harness uses `DartLintRule.testAnalyzeAndRun(File)` (analyzer-driven), NOT the CLI subprocess pattern.** Task 8.4 listed two options ("Preferred" CLI subprocess via `dart run custom_lint` + `expect_lint:` markers; "Fallback" `AnalysisContextCollection`-based). Chose the latter, refined: the `custom_lint_builder` package itself ships `DartLintRule.testAnalyzeAndRun(File) → Future<List<Diagnostic>>` as a `@visibleForTesting` helper — that IS the `custom_lint` library-provided test harness, just at a layer below the CLI. Trade-offs: (a) faster — no subprocess spawn (~2s vs ~10s+); (b) returns typed `Diagnostic` objects with `diagnosticCode.name`, eliminating brittle stdout parsing; (c) the `// expect_lint:` comment is `custom_lint`'s suppression marker, not a positive assertion — assertions live in the test code via `expect(errors.single.diagnosticCode.name, 'exhaustive_switch_must_have_default')`. The `// expect_lint:` comment in `violations/missing_default.dart` is kept as documentation (and would suppress the lint to keep CI-time `dart analyze` clean if the rule ever gets wired up against its own fixtures via the plugin — which it isn't, per Task 5.3 / Task 6.2).

4. **Fixture restructure: 3 subtypes (not 2) in both fixtures.** Story Task 8.2/8.3 sketched fixtures with 2 sealed subtypes (`RunStartedEvent`, `RunFinishedEvent`). With only 2 subtypes, the OK fixture's `default:` clause becomes **unreachable** (exhaustive over the sealed type) and the analyzer emits the separate `unreachable_switch_default` warning, polluting `dart analyze` output (and inappropriately the OK fixture would not be lint-clean). Added a third subtype (`RunErrorEvent`) to both fixtures: violation switches over all 3 explicitly with no `default:` (analyzer reports nothing about exhaustiveness; rule fires once for missing default — clean signal); OK switches over 2 explicitly + `default:` catches the third (default reachable; rule silent). Preserves AC3's "same switch shape WITH a `default:` arm" contract — both fixtures still have the same shape, just three cases instead of two.

**Analyzer 8.x API divergences from story §5.2 sketch (current 8.4.0, story sketch was 8.0-era)**

- `expr.staticType?.element3?.name3` → `expr.staticType?.element?.name`. The story sketch's 3-suffixed API (`element3` / `name3`) is **deprecated** in 8.4.0 in favor of the un-suffixed accessors. Both work via deprecated typedefs, but the un-suffixed form is the canonical API; using deprecated members would trigger `deprecated_member_use` and break Task 9.2's "0 warnings" gate.
- `ErrorSeverity.ERROR` → `DiagnosticSeverity.ERROR`. `ErrorSeverity` is a deprecated typedef for `DiagnosticSeverity` in analyzer 8.4.0; same value, current name.
- `ErrorReporter` parameter → `DiagnosticReporter` parameter in `run()` override. Same reason — typedef-deprecated. `DartLintRule.run`'s parameter type is declared as `ErrorReporter` in `custom_lint_core` 0.8.1, but Dart override rules treat the typedef and its target identically, so `DiagnosticReporter` in the override is a sound (and lint-clean) substitution.
- `LintCode` ambiguous-import resolved via `import 'package:analyzer/error/error.dart' show DiagnosticSeverity;`. Both `analyzer/error/error.dart` and `custom_lint_builder` re-export a `LintCode` symbol (the analyzer's older one vs the custom_lint_core fork with `errorSeverity` keyword). The `show DiagnosticSeverity` clause imports only the symbol we need from analyzer and leaves `LintCode` resolution to `custom_lint_builder`, which is the one whose constructor signature (`{required name, required problemMessage, errorSeverity, ...}`) the rule actually uses.

**Toolchain at implementation time**

- Dart SDK 3.12.0 (≥ 3.9.0 D1 floor ✓; story §1.1 OK).
- Flutter 3.44.0 (≥ 3.27.0 ✓; story §1.1 OK).
- Resolved deps: `analyzer 8.4.0`, `custom_lint 0.8.1`, `custom_lint_builder 0.8.1`, `custom_lint_core 0.8.1`, `custom_lint_visitor 1.0.0+8.4.0`, `lints 6.1.0`, `test 1.31.1`.

**Out of this story (deferred per spec)**

- Other packages' adoption of `include: package:koel_lints/koel.yaml` → Story 1.4.
- Repo-root `melos run analyze` script wiring → Story 1.4.
- `LICENSE` full MIT text + README PRD §13 D-1 quality bar + CHANGELOG normalization → Story 1.6.
- `dart_apitool` baseline → Story 9.3.
- v1.0.0 lock-step publish → Story 9.9.

**Items to add to `deferred-work.md` (suggested, not yet written)**

- "Story 1.3 spec gap (closed in-place): AC2 enumeration was missing `lints` dev_dep; required by AC1/AC4 includes. Closed by adding `lints: ^6.0.0`."
- "Story 1.3 spec gap (closed in-place): `package:lints/strict.yaml` referenced throughout but file does not exist; switched all references to `package:lints/recommended.yaml`."
- "Story 1.3 fixture shape: switched from 2 sealed subtypes to 3 to keep OK fixture's `default:` clause reachable (avoids `unreachable_switch_default`)."
- "Story 1.3 analyzer 8.x API: rule uses current (un-suffixed) `element`/`name` and `DiagnosticReporter`/`DiagnosticSeverity` rather than story sketch's deprecated 8.0-era 3-suffixed/`Error*` variants."

### File List

**Modified (Story 1.2 baseline → Story 1.3 final):**
- `packages/koel_lints/pubspec.yaml` (rewritten per Task 2; added `lints: ^6.0.0` dev_dep — Deviation 1)
- `packages/koel_lints/analysis_options.yaml` (rewritten per Task 6; G-3 exception, `recommended.yaml` baseline — Deviation 2)
- `packages/koel_lints/README.md` (rewritten per Task 7; G-3 note + minimal usage; `recommended.yaml` referenced via include chain)
- `packages/koel_lints/lib/koel_lints.dart` (rewritten per Task 4; plugin entrypoint + private `_KoelLintsPlugin`)

**Added (new files):**
- `packages/koel_lints/lib/koel.yaml` (Task 3; consumer analyzer profile — `recommended.yaml` baseline — Deviation 2)
- `packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart` (Task 5; principal rule)
- `packages/koel_lints/test/rules/exhaustive_switch_test.dart` (Task 8.4; analyzer-driven harness — Deviation 3)
- `packages/koel_lints/test/rules/fixtures/violations/missing_default.dart` (Task 8.2; rule-fires fixture — Deviation 4)
- `packages/koel_lints/test/rules/fixtures/ok/with_default.dart` (Task 8.3; rule-silent fixture — Deviation 4)

**Workspace state (sibling files updated automatically):**
- `pubspec.lock` (root; auto-regenerated by `melos bootstrap` after adding `lints` dev_dep)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (story_key `1-3-build-koel-lints-profile` flipped `ready-for-dev` → `in-progress` → `review`)

## Change Log

| Date       | Story / Status         | Change                                                                                                                                              |
|------------|------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| 2026-05-28 | 1.3 / ready-for-dev    | Story file created by create-story workflow; sprint-status updated.                                                                                 |
| 2026-05-28 | 1.3 / review           | Implementation complete: koel_lints plugin (entrypoint + principal rule), consumer profile `lib/koel.yaml`, fixture-driven tests (2/2 green), G-3 self-include exception wired. 4 documented deviations from spec (closes in-place spec gaps; rationale in Completion Notes). All 4 ACs satisfied. dart analyze clean, dart test green, melos bootstrap clean. |
| 2026-05-28 | 1.3 / done             | Code review (3 parallel layers) — 58 findings → 1 patch (README drift `strict.yaml`→`recommended.yaml`), 1 decision→patch (switch-expression fixture pair + 2 tests added for coverage parity, 4/4 green), 12 deferred (spec errata + v1.x rule polish + Story 1.4/1.6/9.x carry-overs), 44 dismissed (intentional per spec or out-of-scope). dart analyze clean, dart test 4/4 green. |
