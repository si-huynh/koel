---
baseline_commit: fa0f25deef911efbfe611cc643c92a0a9ac1ce12
---

# Story 1.4: Adopt `koel_lints` profile across every other package

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an OSS contributor,
I want every package except `koel_lints` itself to include `package:koel_lints/koel.yaml` in its `analysis_options.yaml` via a workspace-sibling dev-dependency,
So that `melos run analyze` runs the koel-mandatory rules everywhere from day one and contributors get `exhaustive_switch_must_have_default` enforcement before a single line of `koel_core` lands (closes deferred items "koel_lints not wired to consumers" and "no shared analysis_options.yaml" from the 1-1 / 1-3 review cycles).

## Acceptance Criteria

1. **AC1 — Every non-lints package consumes `package:koel_lints/koel.yaml`.**
   - **Given** Story 1.3 has shipped (`koel_lints/lib/koel.yaml` exists and self-tests green at `fa0f25d`),
   - **When** I inspect each non-lints package's `analysis_options.yaml`,
   - **Then** the file is **exactly two lines** — one inline comment naming the include source, then `include: package:koel_lints/koel.yaml` — with no other `linter:` / `analyzer:` overrides,
   - **And** this holds for all 10 packages: `koel`, `koel_core`, `koel_http`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_test`, `koel_flutter`, `koel_widgets`, `koel_devtools`,
   - **And** the previous `package:lints/recommended.yaml` (Dart pkgs) / `package:flutter_lints/flutter.yaml` (Flutter pkgs) include is replaced — NOT layered alongside.

2. **AC2 — Every non-lints package's pubspec declares `koel_lints` + `custom_lint` as workspace-resolved dev-deps.**
   - **Given** each non-lints package's `pubspec.yaml` `dev_dependencies:` section,
   - **When** I inspect it,
   - **Then** `koel_lints:` appears as a **bare workspace-sibling entry** (no `path:`, no `version:`, no `any` constraint) — pub workspaces resolve siblings by name and reject `path:` deps targeting workspace members (deferred-work erratum from Story 1.2 review),
   - **And** `custom_lint: ^0.8.1` appears as a dev-dep on every non-lints package (the analyzer-plugin loader; without it `dart analyze` cannot discover the rule despite the include),
   - **And** no `flutter_lints` package appears anywhere (was implicit via dart/flutter-create on `koel_flutter` / `koel_widgets` / `koel_devtools` pre-Story 1.2; Story 1.2 already stripped the dev_dep block — verify still gone),
   - **And** no `very_good_analysis` appears anywhere (AR-1, re-verified across the whole `packages/` tree).

3. **AC3 — `melos run analyze` exits 0 across all eleven workspace members; `melos run format` and `melos run analyze:apply` wired with real bodies.**
   - **Given** the workspace bootstrapped (`melos bootstrap` exit 0, `-> 11 packages bootstrapped`),
   - **When** I run `melos run analyze` (delegates `dart analyze .` per package via Melos 7 `exec:`),
   - **Then** the command exits 0 across all eleven packages,
   - **And** zero `dart analyze` warnings or errors are emitted — closing the three pre-existing `include_file_not_found` warnings on `koel_devtools` / `koel_flutter` / `koel_widgets` that Story 1.3's debug log documented (NFR-13 gate),
   - **And** `melos run format` runs `dart format .` per package (Story 1.4 ownership per workspace `pubspec.yaml` script annotation),
   - **And** `melos run analyze:apply` runs `dart fix --apply` per package (Story 1.4 ownership; auto-fix path),
   - **And** the script `description:` strings in `pubspec.yaml` are updated to reflect the wired state (no more "wired in story 1.4" placeholders for these three scripts).

## Tasks / Subtasks

- [x] **Task 1 — Preflight + working-tree snapshot** (AC: 1, 2, 3)
  - [x] 1.1 Verify toolchain at edit time: `dart --version` ≥ 3.9.0 (D1 floor); `flutter --version` ≥ 3.27.0 (AR-25 placeholder; reconciliation lives in Story 1.6 / 9.7). If either drifts, halt and surface in Completion Notes — do NOT raise the floor in this story.
  - [x] 1.2 Confirm `melos bootstrap` is currently green from the Story 1.3 baseline (`-> 11 packages bootstrapped`, no warnings). If not, fix the workspace BEFORE proceeding — every AC depends on a clean baseline.
  - [x] 1.3 Confirm `dart test` from `packages/koel_lints/` is currently 4/4 green (Story 1.3 final state per its Change Log row "1.3 / done"). If not, fix the regression in `koel_lints` first; this story does NOT touch `koel_lints/` itself.
  - [x] 1.4 Snapshot current per-package state — verified via direct inspection at story creation (see Dev Notes → Existing repo state). 7 Dart packages currently include `package:lints/recommended.yaml`; 3 Flutter packages currently include `package:flutter_lints/flutter.yaml`; all 10 have **zero** `dev_dependencies` blocks (Story 1.2 stripped the create-template dev_deps). The package being modified is the per-pkg `analysis_options.yaml` + `pubspec.yaml`, never `koel_lints/*`.

- [x] **Task 2 — Rewrite every non-lints package's `analysis_options.yaml`** (AC: 1)
  - [x] 2.1 For each of the 10 packages listed below, REPLACE the entire `analysis_options.yaml` content with these exact two lines (one inline comment + the include — matches Convention §6 "no multi-paragraph comments restating obvious keys" / NFR-16):
        ```yaml
        # koel-mandatory profile (extends package:lints/recommended.yaml + custom_lint rules).
        include: package:koel_lints/koel.yaml
        ```
        Target files (10 total):
        - `packages/koel/analysis_options.yaml`
        - `packages/koel_core/analysis_options.yaml`
        - `packages/koel_http/analysis_options.yaml`
        - `packages/koel_agno/analysis_options.yaml`
        - `packages/koel_langgraph/analysis_options.yaml`
        - `packages/koel_runtime/analysis_options.yaml`
        - `packages/koel_test/analysis_options.yaml`
        - `packages/koel_flutter/analysis_options.yaml`
        - `packages/koel_widgets/analysis_options.yaml`
        - `packages/koel_devtools/analysis_options.yaml`
  - [x] 2.2 **Do NOT touch** `packages/koel_lints/analysis_options.yaml` — G-3 self-include exception (architecture lines 1160-1164). Story 1.3 already wired it to extend `package:lints/recommended.yaml` directly.
  - [x] 2.3 **Do NOT create** a workspace-root `analysis_options.yaml` in this story. Architecture line 665 calls for one but no `tool/` or root-level Dart code exists yet (planned per architecture lines 675-685); root analyzer coverage is moot until that lands. Tracked as a deferred follow-up (see Project Structure Notes).
  - [x] 2.4 **Do NOT add** any `linter:` / `analyzer:` overrides under the include line. The epic AC explicitly bans overrides "unless documented inline" — there are zero such cases in v1.0.0 scope.

- [x] **Task 3 — Wire `koel_lints` + `custom_lint` into every non-lints package's `dev_dependencies`** (AC: 2)
  - [x] 3.1 For each of the 10 packages above, APPEND (or insert if no `dev_dependencies:` block exists yet — true for all 10) the following block at the end of `pubspec.yaml`. Preserve the existing `name` / `description` / `version` / `publish_to` / `environment` / `resolution` block byte-for-byte; the blank line between `resolution: workspace` and `dev_dependencies:` is intentional (matches the Story 1.1 / 1.2 / 1.3 conventions):
        ```yaml

        dev_dependencies:
          koel_lints:
          custom_lint: ^0.8.1
        ```
        Notes per line:
        - **`koel_lints:`** — bare entry (NO `path:`, NO `version:`, NO `any`). Dart pub workspace (Story 1.1 finding; verified end-to-end by Story 1.3's `melos bootstrap`) resolves workspace-sibling deps by name. `path:` deps targeting workspace members are rejected by `dart pub workspace` — this was the central erratum surfaced in Story 1.2's review (deferred-work line 20). At first publish (Story 9.9 v1.0.0 lock-step), this becomes `koel_lints: ^1.0.0` per AR-3, but for the pre-publish path that's later.
        - **`custom_lint: ^0.8.1`** — pinned to match `koel_lints`'s own `dev_dep` constraint (Story 1.3 §2.1). `custom_lint` is the analyzer-plugin runner CLI/loader; without it on the consumer side, `dart analyze` will not discover the registered plugin even though `koel.yaml` declares `analyzer.plugins: [custom_lint]`. See Story 1.3 Dev Notes §"How `custom_lint` plugin discovery works" for the mental model.
  - [x] 3.2 **Do NOT add** `lints: ^6.0.0` to consumer pubspecs. `koel_lints` already declares it as a `dev_dep` (Story 1.3 Deviation 1); within the shared workspace `.dart_tool/package_config.json` it is visible to every member. Adding it again is redundant and creates version-coupling surface. (Outside the workspace — i.e., after publish — `koel_lints` will need to promote `lints` to a runtime dep so downstream consumers can resolve `package:lints/recommended.yaml`. That promotion is **deferred to Story 9.5 publish-dry-run** per the Story 1.3 review's deferred-work entry "Transitive `lints` dep resolution for downstream consumers".)
  - [x] 3.3 **Do NOT add** `analyzer:` to consumer pubspecs. Only `koel_lints` itself (the plugin author) needs the analyzer at edit time. Consumers only run the plugin via `custom_lint`'s loader — the loader pulls in the `analyzer` transitively.
  - [x] 3.4 **Do NOT pre-empt** any future deps (e.g., `freezed`, `build_runner`, `test`, `mocktail`). Those land per-package in their respective implementation stories (Epic 2 onward). The ONLY dev_deps any non-lints package carries after Story 1.4 are these two.
  - [x] 3.5 **Do NOT touch** the workspace-root `pubspec.yaml`'s `dev_dependencies:` block (currently `melos: ^7.8.0` only). The workspace root is not a workspace member and does not consume the lint profile in this story (see Task 2.3).

- [x] **Task 4 — Wire real bodies into Melos `analyze` / `format` / `analyze:apply` scripts** (AC: 3)
  - [x] 4.1 In the workspace-root `pubspec.yaml`, REPLACE the three placeholder script blocks under `melos.scripts:` with these exact bodies. Use the Melos 7 `exec:` form (runs the command per workspace member, output prefixed by package name; cleanest for this kind of per-package pass):
        ```yaml
            analyze:
              description: Run `dart analyze .` per package (NFR-13 gate).
              exec: dart analyze .
            format:
              description: Run `dart format .` per package.
              exec: dart format .
            analyze:apply:
              description: Run `dart fix --apply` per package (auto-apply analyzer fixes).
              exec: dart fix --apply
        ```
        Indentation: 4 spaces (matches the existing script indent under `scripts:`).
  - [x] 4.2 **Do NOT touch** the other four scripts (`test`, `test:coverage`, `build`, `format:check`). Their `wired in story X.Y` descriptions are still accurate (`test` / `test:coverage` → Story 2.15; `build` → Story 1.5; `format:check` → Story 1.5). The `dart --version` no-op body stays as-is per Story 1.1's contract.
  - [x] 4.3 **Do NOT add** `melos run analyze` to any `.github/workflows/*.yml` in this story — those files do not exist yet (Story 1.5 owns `.github/workflows/`). The script is invoked via `melos run analyze` from a developer shell; CI wiring is Story 1.5's job.
  - [x] 4.4 **Do NOT add** `--fatal-infos` or `--fatal-warnings` flags to `dart analyze .` in the `analyze:` script body. `dart analyze` already exits non-zero on errors; warnings and infos are advisory. The CI-time fatality decision (which Story 1.5 will encode via `dart analyze --fatal-infos`) is layered on top of this script body, not baked into it.

- [x] **Task 5 — Re-bootstrap + analyzer-clean verification** (AC: 2, 3)
  - [x] 5.1 Run `melos bootstrap` at the repo root. Expected: exit 0, `-> 11 packages bootstrapped`, no warnings. If `koel_lints:` bare entries fail to resolve, the most likely cause is a syntax error in one of the modified pubspecs — re-check indentation and YAML structure. If the workspace rejects a `koel_lints:` declaration, verify the entry is bare (no `version:` / `path:` / quoted-string `any`).
  - [x] 5.2 Run `melos run analyze`. Expected: exit 0, eleven `[koel_*] dart analyze .` lines each ending with `No issues found!`. **Inspect the output carefully** — `melos exec` returns non-zero only if ANY child exits non-zero, but a `dart analyze` warning does NOT cause non-zero exit by default. So manually scan for any line containing `warning -`, `error -`, or `info -`.
  - [x] 5.3 Specifically verify the three pre-existing `include_file_not_found` warnings (`koel_devtools` / `koel_flutter` / `koel_widgets` × `package:flutter_lints/flutter.yaml`) documented in Story 1.3's Debug Log are now absent — the include swap closes them.
  - [x] 5.4 Run `melos run format`. Expected: exit 0, eleven `[koel_*] dart format .` lines each reporting `Formatted N files (0 changed)`. The codebase is already formatted clean after Stories 1.1 / 1.2 / 1.3; this run is a smoke-test of the script wiring, not a code-change pass. **Deviation:** first run reformatted 2 `koel_lints/` files under Dart 3.12 trailing-comma layout (formatter drift vs `fa0f25d` baseline); second run reports `(0 changed)` across all 11 packages. See Dev Agent Record → Completion Notes + `deferred-work.md`.
  - [x] 5.5 Run `melos run analyze:apply`. Expected: exit 0; `dart fix --apply` reports nothing to fix per package (no lint diagnostics exist after Task 2 + 3, so there is nothing for `dart fix` to auto-fix). This is also a wiring smoke test.

- [ ] **Task 6 — End-to-end plugin-discovery smoke test** (AC: 1, 2, 3 + closes Story 1.3 deferred items) — **DEFERRED (user-approved Option A, 2026-05-28)**: `custom_lint` 0.8.1 has a pub-workspace-mode bug in `visitAnalysisOptionAndIncludes` (workspace.dart:333-341) that breaks resolution of `package:` URIs in `analysis_options.yaml` include chains, silently skipping the project before the rule can fire. Attempted on `koel_core` with both the Task 6.2 private-subtype shape and the public-subtype shape from the koel_lints test fixture — both returned `No issues found!` under `dart run custom_lint`. Working tree returned to clean state. Re-execute when upstream `custom_lint` ships a workspace fix or when an out-of-workspace integration test setup is added. See `deferred-work.md` § "Deferred from: Story 1.4 implementation (2026-05-28)" for full root-cause analysis. AC3's plugin-discovery gate is unfulfilled; AC1 / AC2 / AC3-analyze-clean remain green.
  - [ ] 6.1 **Why this task exists:** Story 1.3's Deviation 3 noted that its fixture-test harness uses `DartLintRule.testAnalyzeAndRun` (analyzer-driven), which bypasses `custom_lint`'s plugin-discovery flow. The deferred-work entry "`custom_lint.rules:` YAML syntax for 0.8.1 not end-to-end verified via consumer plugin path" explicitly assigns the integration test to Story 1.4. Likewise the entry "`analyzer.plugins:` merge vs override semantics for consumers unverified" needs Story 1.4 to confirm consumer-side plugin loading actually fires the rule.
  - [ ] 6.2 In `packages/koel_core/lib/_verify_lint.dart` (temporary file — NOT committed; delete after verification), write this **deliberately-failing** Dart source:
        ```dart
        // TEMPORARY verification fixture for Story 1.4. DELETE after asserting `dart analyze` fires the rule. Not committed.
        sealed class AgUiEvent {
          const AgUiEvent();
        }
        final class _A extends AgUiEvent { const _A(); }
        final class _B extends AgUiEvent { const _B(); }
        final class _C extends AgUiEvent { const _C(); }

        void describe(AgUiEvent e) {
          switch (e) {
            case _A _:
            case _B _:
            case _C _:
              break;
          }
        }
        ```
        Three subtypes (not two) to avoid the analyzer's separate `unreachable_switch_default` warning on the OK variant — same fixture shape used by Story 1.3 Deviation 4.
  - [ ] 6.3 Run `dart analyze packages/koel_core/`. **Expected:** exit non-zero, exactly one `error - ... exhaustive_switch_must_have_default ...` diagnostic at the `switch` keyword in `_verify_lint.dart`. If the rule does NOT fire, the consumer-side plugin discovery is broken — most likely cause is a missing `custom_lint:` dev-dep, a typo in the include URI, or a Melos bootstrap stale-state (re-run `melos bootstrap`).
  - [ ] 6.4 **Delete** `packages/koel_core/lib/_verify_lint.dart` (`git status` must end clean for `lib/` per the AC scope).
  - [ ] 6.5 Repeat 6.2-6.4 against `packages/koel_widgets/` (a Flutter package, to verify the plugin loads under the Flutter analyzer profile too). Use the same temporary `lib/_verify_lint.dart` shape; same expected error; same deletion.
  - [ ] 6.6 Document both fixture runs (and the exact diagnostic line emitted) in Completion Notes. These two runs ARE the integration test the deferred-work items required.

- [x] **Task 7 — Cross-cutting verification + final state assertion** (AC: 1, 2, 3)
  - [x] 7.1 Verify AR-1 globally: `grep -rn very_good_analysis packages/` returns zero matches.
  - [x] 7.2 Verify AR-1 / no `flutter_lints` leak: `grep -rn flutter_lints packages/` returns zero matches (the dart-create boilerplate comment is gone after Task 2; the dev_dep was already gone after Story 1.2).
  - [x] 7.3 Verify the include line is identical across all 10 non-lints packages:
        ```bash
        grep -l "include: package:koel_lints/koel.yaml" packages/*/analysis_options.yaml | wc -l
        ```
        Must return `10` (excludes `packages/koel_lints/analysis_options.yaml` which has the G-3 self-include).
  - [x] 7.4 Verify the dev-dep block is identical across all 10 non-lints packages:
        ```bash
        grep -A2 "^dev_dependencies:" packages/*/pubspec.yaml | grep -c "koel_lints:"
        ```
        Must return `10`. (`koel_lints/pubspec.yaml` declares `custom_lint` + `lints` + `test` in its dev_deps but not `koel_lints:` itself — G-3.)
  - [x] 7.5 Verify the workspace-root `pubspec.yaml` `melos.scripts:` block: `analyze` / `format` / `analyze:apply` now use `exec:` (not `run: dart --version`); `test` / `test:coverage` / `build` / `format:check` remain `run: dart --version` placeholders.
  - [x] 7.6 Verify `dart analyze packages/koel_lints/` still exits 0 (Story 1.3 baseline preserved — this story does not touch `koel_lints/` files).
  - [x] 7.7 Verify `dart test` from `packages/koel_lints/` still exits 0 with 4/4 passing (Story 1.3's fixture tests unaffected).
  - [x] 7.8 Document every diagnostic / warning surfaced during 5.1-7.7 in Completion Notes, even if expected and benign.

### Review Findings

Reviewed 2026-05-28 via `/bmad-code-review` (Blind Hunter + Edge Case Hunter + Acceptance Auditor). 0 decision-needed, 0 patch, 5 defer, ~14 dismissed (Blind-Hunter context-blind false alarms verified against `koel.yaml` baseline; Edge-Case items verified clean by running `dart analyze` on `koel_lints/` and all 3 Flutter packages).

- [x] [Review][Defer] Flutter-specific lint rules lost from `koel_devtools` / `koel_flutter` / `koel_widgets` — `flutter_lints/flutter.yaml` previously layered `use_key_in_widget_constructors`, `sized_box_for_whitespace`, `avoid_unnecessary_containers`, etc. on top of `recommended.yaml`; `koel.yaml` chains only `recommended.yaml`. Spec consciously chose this via AR-1 ("one lint baseline") and forbids re-adding `flutter_lints`. Consequence will only manifest once widgets land (Epic 4+) — until then, empty `lib/` masks the gap. **Action:** before Epic 4 widget stories land, either (a) merge select Flutter rules into `koel.yaml`, or (b) ship `koel_lints/lib/koel_flutter.yaml` variant. Deferred — pre-existing architectural decision; not actionable in 1.4.
- [x] [Review][Defer] `custom_lint: ^0.8.1` constraint duplicated across 10 consumer pubspecs — 10 strings to update on every bump; drift risk between packages. **Closes into:** existing deferred-work entry "Caret pin `^0.8.1` on `custom_lint` (0.x footgun) + no renovate/dependabot config" (Story 1.3 review). Owned by Story 1.5/1.6 toolchain matrix.
- [x] [Review][Defer] `melos run analyze:apply` (`dart fix --apply`) and `melos run format` (`dart format .`) run unconstrained across every workspace member — currently safe (Task 5.4/5.5 verified `0 changed` / `Nothing to fix!`), but once `koel_lints/test/rules/fixtures/violations/` grows files with intentional layout or non-exhaustive switches, `dart fix --apply` could silently auto-correct fixtures and break Story 1.3's rule tests. **Action:** add `analyzer.exclude: [test/rules/fixtures/**]` to `koel_lints/analysis_options.yaml` and/or restrict the melos scripts to `lib test` paths before Epic 2+ fixture-heavy work begins. Deferred — pre-existing future-safety concern; not actionable today.
- [x] [Review][Defer] `format` melos script ships destructive (`dart format .`) without paired read-only `format:check` (`dart format --output=none --set-exit-if-changed .`) — contributors get a mutation script with no CI-safe counterpart. Story 1.5 already owns `format:check` per its `description:` annotation; flagged here so Story 1.5 prioritizes it alongside `analyze`.
- [x] [Review][Defer] Workspace-root `melos:` script block lacks `failFast` / `orderDependents` / `concurrency` config on `exec:` scripts — when failures land in Epic 2+, parallel `dart analyze` runs may interleave output across 11 packages with no fail-fast. Future hardening; not blocking 1.4.

## Dev Notes

### Critical architectural anchors

- **AR-3 (bootstrap order — the "why" of this story):** `koel_lints` ships first precisely so every other package's `analysis_options.yaml` can include it from day one. Story 1.3 shipped the profile; Story 1.4 wires the adoption. Without Story 1.4, the `koel_lints` rule fires only inside `koel_lints/`'s own test fixtures — useless for the rest of the codebase. After this story, every non-lints package has the exhaustive-switch rule active from the moment its first `switch` over `AgUiEvent` / `KoelError` / `MessageSegment` lands (Story 2.1+). [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md:127` + `_bmad-output/planning-artifacts/architecture.md` lines 80, 228-230, 991]
- **NFR-13 (analyze clean gate):** `dart analyze` MUST be zero warnings across every package under `package:koel_lints/koel.yaml`. After Story 1.3 the gate held for `koel_lints` itself + 7 Dart packages (via transitive `lints` dev_dep workspace-visibility); Story 1.4 closes the last 3 Flutter packages by swapping their `flutter_lints` include for `koel_lints`. CI enforcement of NFR-13 lands in Story 1.5 (.github/workflows/ci.yml). [Source: `requirements-inventory.md:109` + Story 1.3 Debug Log line documenting the 3 pre-existing warnings]
- **AR-1 (very_good_analysis ban):** Banned repo-wide. Verified clean in every prior story; verify again in Task §7.1. [Source: `requirements-inventory.md:125`]
- **AR-5 / D3 (custom_lint pin):** Foundation pinned to `^0.8.1`. Every consumer's `dev_dependencies` aligns to that pin (Task §3.1). The 0.x footgun is acknowledged (deferred-work line 31, Story 1.3); CI matrix that exercises a `custom_lint` floor lives in Story 1.5 / 1.6 toolchain story. [Source: `requirements-inventory.md:132` + `architecture.md` lines 273-281]
- **AR-23 G-3 (`koel_lints` self-include exception):** `packages/koel_lints/analysis_options.yaml` extends `package:lints/recommended.yaml` only — Story 1.3 wired it; Story 1.4 explicitly leaves it untouched. [Source: `architecture.md` lines 1160-1164]
- **Convention §2 (barrel = public contract):** The 10 non-lints packages' `lib/<name>.dart` barrels are still empty per Story 1.2 baseline. Story 1.4 does not touch them. [Source: `architecture.md` §"Implementation Patterns" §2 lines 386-462]
- **Convention §6 / NFR-16 (no multi-paragraph comments restating obvious keys):** The 2-line `analysis_options.yaml` shape in Task §2.1 (one inline-purpose comment + the include) is the documented pattern. Story 1.3 used the same 3-line shape for its self-include profile. [Source: `architecture.md` §"Implementation Patterns" + Story 1.3 Task 6.1]

### Library / version pins (already decided — do not re-evaluate)

| Item | Version on consumer pubspec | Decision ref |
|---|---|---|
| `koel_lints` | bare entry (no `path:`, no `version:`) — workspace-sibling resolution | AR-3 + Story 1.2 review deferred-work erratum (line 20) |
| `custom_lint` | `^0.8.1` | AR-5 / D3 (matches `koel_lints`'s own dev-dep) |
| `lints` | NOT declared on consumers (transitive via `koel_lints`'s workspace-visible dev_dep) | Story 1.3 Deviation 1 / deferred-work line 37 (Story 9.5 owns post-publish promotion) |
| `analyzer` | NOT declared on consumers (pulled transitively by `custom_lint`) | implicit from AR-5 |
| `flutter_lints` | REMOVED from `koel_flutter` / `koel_widgets` / `koel_devtools` `analysis_options.yaml` includes (it was never in their pubspec dev_deps — Story 1.2 already stripped) | AR-1 spirit + Story 1.2 baseline |
| Dart SDK floor | unchanged: `>=3.9.0 <4.0.0` per package | D1, AR-3 |
| Flutter floor | unchanged: `>=3.27.0` for the 3 Flutter packages | AR-25 placeholder; Story 1.6 reconciles |

**Out-of-scope deps (do NOT add):** `freezed`, `build_runner`, `json_serializable`, `test`, `mocktail`, `coverage`. Those land per-package in their feature stories (Epic 2 onward). The ONLY new dev_deps any non-lints package carries after Story 1.4 are `koel_lints:` + `custom_lint: ^0.8.1`.

### Why `koel_lints:` bare (not `path:` or version-constrained)

The Story 1.2 spec mirrored a `(path)` phrasing in its Dev Notes line 171. The Story 1.2 review caught this — `dart pub workspace` rejects `path:` declarations targeting workspace members. The mechanism is:

- Workspace root `pubspec.yaml` declares `workspace:` listing the 11 members (already in place since Story 1.1).
- Each member declares `resolution: workspace` (already in place since Stories 1.1 / 1.2 — verified across all 11 pubspecs at story creation).
- A member declaring another member as a dep uses a **bare entry**: just `package_name:` with no constraint. Pub resolves it to the workspace sibling.
- Adding `path: ../koel_lints` triggers `Workspace member ... has both 'workspace' resolution and a path dependency` errors.
- Adding `version: ^0.0.1` works but is brittle: every version bump in `koel_lints/pubspec.yaml` requires a sweep across the 10 consumer pubspecs. Bare is cleaner for pre-publish.

At first publish (Story 9.9 v1.0.0 lock-step), the bare entries get rewritten to `koel_lints: ^1.0.0` (per AR-3 "path-dep during dev, package-dep at first publish" — Story 1.4 is the "path-dep" lane semantically, even though the actual syntax is workspace-bare). That rewrite is a single sed in Story 9.9, not a Story 1.4 concern.

[Source: `_bmad-output/implementation-artifacts/deferred-work.md` line 20 + verified during this story's artifact analysis against the Dart 3.12 pub-workspace docs]

### How `custom_lint` plugin discovery works at the consumer (recap from Story 1.3)

When a consumer runs `dart analyze` in a package whose `analysis_options.yaml` includes `package:koel_lints/koel.yaml`:

1. The analyzer reads `koel.yaml`, sees `analyzer.plugins: [custom_lint]`, and bootstraps `custom_lint` as an analyzer plugin.
2. `custom_lint` scans the consumer's `pubspec.yaml` `dev_dependencies` for any package depending on `custom_lint_builder` — that's the "this is a plugin" marker.
3. It finds `koel_lints` (whose pubspec declares `custom_lint_builder` as a runtime dep per Story 1.3 §2.1), loads `lib/koel_lints.dart`, calls `createPlugin()`.
4. For each rule listed under `custom_lint.rules:` in `koel.yaml` whose name matches a rule returned by `getLintRules()`, the rule runs.

**Implication:** every non-lints package needs BOTH `custom_lint` (so the analyzer knows the plugin runner exists) AND `koel_lints` (so `custom_lint` finds the rule registration). Either dev-dep alone is non-functional. [Source: Story 1.3 Dev Notes lines 425-429]

### Existing repo state (verified at story creation, baseline `fa0f25d`)

After Story 1.3, the 10 non-lints packages all have:

- `analysis_options.yaml`:
  - 7 Dart packages (`koel`, `koel_core`, `koel_http`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_test`): full dart-create boilerplate (~30 lines of comments) + `include: package:lints/recommended.yaml`
  - 3 Flutter packages (`koel_flutter`, `koel_widgets`, `koel_devtools`): minimal 2-line file + `include: package:flutter_lints/flutter.yaml`
- `pubspec.yaml`: `name` / `description` / `version` / `publish_to` / `environment` / `resolution: workspace` block only. **Zero `dev_dependencies` lines on any of the 10.**
- `lib/<name>.dart`: empty barrel (just dartdoc + `library;`) per Story 1.2 baseline.
- `test/`: empty per Story 1.2 baseline.

After Story 1.4 (target state):

- Every non-lints `analysis_options.yaml`: 2 lines (inline comment + `include: package:koel_lints/koel.yaml`).
- Every non-lints `pubspec.yaml`: appends a `dev_dependencies:` block with `koel_lints:` (bare) + `custom_lint: ^0.8.1`.
- Workspace-root `pubspec.yaml` `melos.scripts:` `analyze` / `format` / `analyze:apply`: real `exec:` bodies. The other four scripts unchanged (still `dart --version` placeholders owned by Story 1.5 / 2.15).
- `packages/koel_lints/`: unchanged (G-3).
- `lib/<name>.dart` barrels: unchanged.

### Anti-patterns to reject in review

- ❌ Declaring `koel_lints` as `koel_lints: { path: ../koel_lints }` — workspace rejects. **Use bare `koel_lints:`.**
- ❌ Declaring `koel_lints` as `koel_lints: ^0.0.1` or `koel_lints: any` — works but brittle (version-coupling) and noisier than bare for pre-publish.
- ❌ Adding `lints: ^6.0.0` as a consumer dev-dep — redundant in-workspace; promotion to runtime dep is Story 9.5's job.
- ❌ Adding `analyzer` as a consumer dev-dep — transitive via `custom_lint`; declaring it directly is noise + version-coupling risk.
- ❌ Adding `flutter_lints` back anywhere (including dev_deps of the 3 Flutter packages) — banned by AR-1's spirit (one lint baseline) + we are switching their include AWAY from it.
- ❌ Keeping the dart-create boilerplate comments in `analysis_options.yaml` after the rewrite. The rewrite is a **complete file replacement** to the 2-line shape, not an in-place include-line swap that leaves the boilerplate above/below.
- ❌ Adding any `linter:` or `analyzer:` override block under the include line in any consumer `analysis_options.yaml`. Epic AC text bans it ("no other ... overrides appear unless documented inline").
- ❌ Modifying `packages/koel_lints/analysis_options.yaml` (G-3) or `packages/koel_lints/pubspec.yaml` (Story 1.3 final) in this story.
- ❌ Modifying any package's `lib/<name>.dart` barrel — Convention §2 baseline is empty barrels until Epic 2 / Story 2.1+.
- ❌ Adding a workspace-root `analysis_options.yaml` (deferred — see Task 2.3 + Project Structure Notes).
- ❌ Adding `koel_lints` + `custom_lint` to the workspace-root `pubspec.yaml`'s `dev_dependencies:` (root is not a workspace member; the lint profile is scoped per-member).
- ❌ Wiring the `test` / `test:coverage` / `build` / `format:check` melos scripts — those are owned by Stories 1.5 / 2.15 (per their `description:` strings in workspace pubspec). Touching them creates cross-story merge conflict surface.
- ❌ Adding `.github/workflows/*.yml` for CI lint enforcement — that's Story 1.5's job.
- ❌ Adding `--fatal-infos` / `--fatal-warnings` to the `melos run analyze` body — fatality is a CI-time concern (Story 1.5), not a script-body concern.
- ❌ Adding a permanent verification fixture (anything under `packages/*/test/` or `packages/*/lib/_verify_*.dart`) — the Task 6 smoke test is **temporary and deleted before commit**.
- ❌ Committing `packages/koel_core/lib/_verify_lint.dart` or `packages/koel_widgets/lib/_verify_lint.dart` to git. They are tooling-grade scratch files; final `git status` must be clean of them.
- ❌ Sample/placeholder dev-dep lines like `# koel_lints: # add when 1.3 ships` — Story 1.3 has shipped (baseline `fa0f25d`); the entry is real.

### Previous story intelligence (from Story 1.3 commit `fa0f25d`)

- **`strict.yaml` does not exist.** Story 1.3 Deviation 2 documented that `package:lints` only ships `core.yaml` and `recommended.yaml` (versions 1.0.1 → 6.1.0, no exceptions). Every reference to `package:lints/strict.yaml` in Story 1.4's *epic source text* (`epic-1-workspace-foundation-lint-profile.md` Story 1.4 ACs — the original wording referenced "strict") inherits the erratum: the consumer profile is `package:koel_lints/koel.yaml`, which extends `package:lints/recommended.yaml`, NOT strict. This story's ACs already reflect the correction.
- **`koel_lints` ships zero runtime API beyond `createPlugin()`.** The "import" from consumer code is the `analysis_options.yaml` include — there is nothing else to import. Do not write `import 'package:koel_lints/koel_lints.dart';` anywhere in this story; that would be a non-functional import of an empty barrel (Story 1.3 Task 4.1 confirms the barrel only exports `createPlugin()`).
- **`koel_lints` dev_deps already include `lints: ^6.0.0`.** That's why the 7 Dart packages' current `package:lints/recommended.yaml` include resolves cleanly today — the workspace-shared `.dart_tool/package_config.json` makes `lints` visible to every member. Story 1.4's include-swap (recommended → koel) does not change the resolution path (`koel.yaml` itself extends `package:lints/recommended.yaml`).
- **3 Flutter packages still warn `include_file_not_found` for `package:flutter_lints/flutter.yaml` today** — Story 1.3 Debug Log line 605. Closing those warnings is part of AC3.
- **`koel_lints` rule fixtures use 3-subtype sealed unions to avoid `unreachable_switch_default` on OK variants** — Story 1.3 Deviation 4. Task §6.2's verification fixture reuses the same shape.
- **Test harness in `koel_lints` is `testAnalyzeAndRun` (analyzer-driven), NOT `dart run custom_lint` (CLI-driven)** — Story 1.3 Deviation 3. That means Story 1.3's tests do NOT exercise the consumer plugin-discovery path. Task §6 of this story IS that exercise.

### Latest tech notes (verified at story creation, 2026-05-28)

- **Dart pub workspace docs** (https://dart.dev/tools/pub/workspaces) confirm: workspace members reference each other by bare name; pub resolves to the local copy; `path:` targeting a workspace member is an error.
- **Melos 7.8.0 `exec:` script form** (https://melos.invertase.dev/configuration/scripts#per-package-execution) confirmed: `exec: <command>` runs the command in each workspace member's directory, prefixing output with `[package_name]`. The Story 1.1 finding was that `melos.scripts:` lives in workspace `pubspec.yaml` (not `melos.yaml`) — verified still true at 1.4 creation time.
- **`custom_lint` 0.8.1** (https://pub.dev/packages/custom_lint/versions): unchanged since Story 1.3 (latest stable). No 0.9.x release as of 2026-05-28 per pub.dev.
- **`dart fix --apply`** (https://dart.dev/tools/dart-fix) applies all available analyzer fixes. Works in workspace-member directories. Cooperates cleanly with `custom_lint`-registered fixes (none for `exhaustive_switch_must_have_default` in v1.0.0 — the rule is diagnostic-only; quick-fix is deferred to v1.x per deferred-work line 34).
- **`dart format` in Dart 3.9+** uses the new 2025+ formatter (trailing-comma-aware, narrower default width). All 11 packages were formatted by Stories 1.1 / 1.2 / 1.3 under this formatter; Task §5.4's smoke test should report `0 changed` per package.

### Architecture compliance — what this story enables for later

- **Story 1.5 (CI workflows):** `melos run analyze` becoming real (this story) is a prerequisite for `ci.yml`'s analyze job. After Story 1.4, the CI workflow body is literally `melos bootstrap && melos run analyze && melos run test` — no per-package matrix gymnastics needed.
- **Story 1.6 (root docs):** `CONTRIBUTING.md` will document the developer workflow as `melos bootstrap → melos run analyze → melos run test`. Each command must be real (not a `dart --version` placeholder) for the doc to be honest.
- **Story 2.1+ (`koel_core` events):** the moment `sealed class AgUiEvent` lands in `koel_core/lib/src/event/ag_ui_event.dart`, every `switch` over it inside `koel_core` (and later `koel_http`, `koel_flutter`, etc.) MUST carry a `default:` arm — the rule fires from this story onward.
- **Story 9.3 (dart_apitool baseline):** `analysis_options.yaml` is not part of the dart_apitool surface (which only covers public Dart symbols). However `lib/koel.yaml` IS treated as part of `koel_lints`'s public API (Story 1.3 Task §3.2); changes to the rule list post-v1.0.0 are semver-relevant.
- **Story 9.5 (publish dry-run):** the deferred-work entry "Transitive `lints` dep resolution for downstream consumers" surfaces here — `koel_lints` will need `lints` promoted from dev_dep to runtime dep so downstream pub.dev consumers resolve `package:lints/recommended.yaml` outside the workspace.
- **Story 9.9 (v1.0.0 lock-step publish):** the bare `koel_lints:` entries on the 10 consumer pubspecs get rewritten to `koel_lints: ^1.0.0` ranges across all consumers in one sweep. Foundation lock-step (`koel_core` + `koel_http` + `koel_lints` identical version) is the constraint.

### Git intelligence

- **Last commit on `main`:** `fa0f25d chore(story-1.3): wire koel_lints custom_lint plugin + principal rule` (2026-05-28). This story builds directly on it.
- **Working tree:** clean per `git status` at story creation (2026-05-28).
- **Commit pattern (from Stories 1.1, 1.2, 1.3):** `chore(story-X.Y): <descriptive subject>` + body listing the high-level change. Commit on completion of this story should match: `chore(story-1.4): adopt koel_lints profile + wire melos analyze/format scripts`.
- **Code review history:** Stories 1.1 / 1.2 / 1.3 all auto-flipped to `done` via the `/bmad-code-review` workflow (per `feedback_bmad_code_review_autocommit.md` memory). Same flow applies here — review + auto-commit on green.
- **Deferred items this story closes** (from `deferred-work.md`):
  - "koel_lints not wired to consumers" (Story 1.1 review) — **closed by this story.**
  - "No shared analysis_options.yaml" (Story 1.1 review) — **closed by this story** (per-package include; root-level deferred per Task §2.3).
  - "Story 1.4 wording: `koel_lints` cannot be added as `path:` dep across siblings" (Story 1.2 review) — **closed in-place** by AC2 + Task §3.1 prescribing the bare workspace-sibling entry.
  - "`custom_lint.rules:` YAML syntax for 0.8.1 not end-to-end verified via consumer plugin path" (Story 1.3 review) — **closed by Task §6 smoke tests.**
  - "`analyzer.plugins:` merge vs override semantics for consumers unverified" (Story 1.3 review) — **closed by Task §6 smoke tests** (the consumer `analysis_options.yaml` does NOT declare its own `analyzer.plugins:`, so merge/override is trivial; the include drives the plugin chain).
- **Deferred items this story explicitly does NOT close** (carry to later stories):
  - "Severity downgrade / per-consumer rule-disable path not documented" (deferred-work line 32) — was suggested as "Story 1.4 adoption docs should ship the snippet" by Story 1.3 review, but the snippet itself is README content; defer to Story 1.6 README polish (PRD §13 D-1).
  - "Caret pin `^0.8.1` on `custom_lint` is a 0.x footgun + no renovate/dependabot config" — Story 1.5 / 1.6 toolchain matrix.
  - "Transitive `lints` dep resolution for downstream consumers" — Story 9.5 publish-dry-run.

### File structure requirements (target state after this story)

```
koel/
├── pubspec.yaml                # WORKSPACE ROOT — melos.scripts.{analyze,format,analyze:apply} get real exec: bodies (Task 4)
└── packages/
    ├── koel/
    │   ├── analysis_options.yaml          # 2 lines: comment + include: package:koel_lints/koel.yaml (Task 2)
    │   └── pubspec.yaml                   # appends dev_dependencies block (Task 3)
    ├── koel_core/                          (same)
    ├── koel_http/                          (same)
    ├── koel_agno/                          (same)
    ├── koel_langgraph/                     (same)
    ├── koel_runtime/                       (same)
    ├── koel_test/                          (same)
    ├── koel_flutter/                       (same — Flutter pkg)
    ├── koel_widgets/                       (same — Flutter pkg)
    ├── koel_devtools/                      (same — Flutter pkg)
    └── koel_lints/                         (UNCHANGED — G-3)
```

**Out of scope for Story 1.4** (do NOT create / modify in this story):

- Any file under `packages/koel_lints/` (G-3 + Story 1.3 done).
- Any package's `lib/<name>.dart` barrel (Convention §2; barrels stay empty until Epic 2+).
- Any package's `lib/src/` or `test/` directory (Epic 2+ owns feature code + tests).
- Workspace-root `analysis_options.yaml` (no root-level Dart code yet; deferred — see Task §2.3).
- `.github/workflows/*.yml` (Story 1.5).
- Root `README.md` / `CONTRIBUTING.md` / `LICENSE` / `CHANGELOG.md` (Story 1.6).
- Per-package `LICENSE` / `CHANGELOG.md` / `README.md` polish (Story 1.6).
- `melos.scripts:` `test` / `test:coverage` / `build` / `format:check` bodies (Stories 2.15 / 1.5).
- `.tool-versions` / `.fvmrc` / `dependabot.yml` / `renovate.json` (Story 1.5 / 1.6).
- `dart_apitool` baseline (Story 9.3).
- Any pub.dev publishing or reservation step (Story 1.6 / 9.9).
- Adding a second rule to `koel_lints` (out of v1.0.0 scope per Story 1.3 §5).
- Documenting the per-consumer rule-disable snippet (Story 1.6 README polish).
- Promoting `lints` from dev-dep to runtime dep on `koel_lints` (Story 9.5).

### Testing requirements

- **Functional gate (AC3):** `melos run analyze` exits 0 across all 11 members; output contains zero `warning -` / `error -` / `info -` lines.
- **Smoke gate (AC3):** `melos run format` and `melos run analyze:apply` each exit 0 (script wiring works; codebase already clean).
- **Plugin-discovery gate (Task §6):** the temporary `_verify_lint.dart` fixture fires `exhaustive_switch_must_have_default` under `dart analyze` in both `koel_core` (Dart) and `koel_widgets` (Flutter), confirming consumer-side plugin loading is real. Fixture deleted before commit.
- **Workspace gate (AC2 + Task §5.1):** `melos bootstrap` exits 0 with `-> 11 packages bootstrapped` after the dev-dep additions.
- **AR-1 gate:** `grep -rn very_good_analysis packages/` returns zero matches (Task §7.1).
- **AR-1 spirit gate:** `grep -rn flutter_lints packages/` returns zero matches (Task §7.2).
- **Non-regression gate:** `dart analyze packages/koel_lints/` + `dart test` in `packages/koel_lints/` still green (Story 1.3 final state preserved — Tasks §7.6, §7.7).
- **No NFR-12 coverage gate enforced for this story** — Story 1.5 (CI) / Story 9.4 (perf+coverage release artifacts) own coverage. The 10 consumer packages still have empty `test/` directories.
- **No `dart_apitool` baseline** — Story 9.3.

### Project Structure Notes

- **Alignment:** Matches `architecture.md` lines 228-230, 991, 1160-1164 exactly. Every package's `analysis_options.yaml` includes `package:koel_lints/koel.yaml` (line 228); `koel_lints` itself is exempt per G-3 (line 1160).
- **Detected conflicts:** None against the post-correction story spec. Two erratum-style conflicts vs the **original epic source text** (resolved in this story's ACs):
  1. Epic source says `include: package:lints/strict.yaml` — corrected throughout to `package:koel_lints/koel.yaml` per Story 1.3 Deviation 2 (recommended.yaml is the real lints profile).
  2. Epic source says `koel_lints` "as a path dependency to `../koel_lints`" — corrected to "bare workspace-sibling entry" per the Story 1.2 review deferred-work item (Dart pub workspace rejects `path:` for siblings).
- **Variances from architecture target state** (intentional, bounded — closed by later stories):
  - Workspace-root `analysis_options.yaml` not yet created (architecture line 665). **Closed by:** whichever story introduces the first root-level Dart code (currently planned `tool/capture_fixtures.dart` per architecture line 676 — owned by `koel_test` / Epic 3 fixture work). Tracked as a deferred follow-up: see "deferred items" list in Git intelligence.
  - `melos.scripts:` `test` / `test:coverage` / `build` / `format:check` remain `dart --version` placeholders. **Closed by Stories 2.15 / 1.5** per their `description:` annotations.
  - The 10 consumer packages still have empty `lib/<name>.dart` barrels and empty `test/` dirs. **Closed by Epic 2+ feature work**, not this story.
  - Per-consumer rule-disable snippet not documented in any README. **Closed by Story 1.6** README polish (PRD §13 D-1).
  - CI `dart analyze --fatal-infos` gate not wired. **Closed by Story 1.5** `.github/workflows/ci.yml`.

### References

- [Story 1.4 acceptance criteria source: `_bmad-output/planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md` §"Story 1.4"](../planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md#story-14-adopt-koel_lints-profile-across-every-other-package)
- [Story 1.3 implementation record (baseline this story builds on; carries the Deviation 1 / 2 errata): `_bmad-output/implementation-artifacts/1-3-build-koel-lints-profile.md`](./1-3-build-koel-lints-profile.md)
- [Story 1.2 implementation record (Dart pub workspace bare-sibling-dep rationale + path-dep rejection): `_bmad-output/implementation-artifacts/1-2-scaffold-publishable-packages.md`](./1-2-scaffold-publishable-packages.md)
- [Story 1.1 implementation record (`melos.scripts:` lives in workspace `pubspec.yaml`, not `melos.yaml`): `_bmad-output/implementation-artifacts/1-1-workspace-bootstrap.md`](./1-1-workspace-bootstrap.md)
- [Architecture §"Project Scaffolding Approach" — per-package `analysis_options.yaml` shape: `_bmad-output/planning-artifacts/architecture.md` lines 228-230](../planning-artifacts/architecture.md)
- [Architecture §"Enforcement summary" — automated vs convention gates: `_bmad-output/planning-artifacts/architecture.md` lines 623-640](../planning-artifacts/architecture.md)
- [Architecture §"Architectural boundaries" — foundation lock-step (koel_core + koel_http + koel_lints): `_bmad-output/planning-artifacts/architecture.md` lines 968-991](../planning-artifacts/architecture.md)
- [Architecture §"G-3. `koel_lints` self-include exception": `_bmad-output/planning-artifacts/architecture.md` lines 1160-1164](../planning-artifacts/architecture.md)
- [Requirements inventory AR-1, AR-3, AR-5, AR-23, NFR-13, FR-A12: `_bmad-output/planning-artifacts/epics/requirements-inventory.md` lines 20, 108-116, 125-153](../planning-artifacts/epics/requirements-inventory.md)
- [Deferred work tracking (the erratum carry-forward and integration-test assignment): `_bmad-output/implementation-artifacts/deferred-work.md`](./deferred-work.md)
- [PRD §10.4 N-13 (`dart analyze` clean gate): `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md`](../planning-artifacts/prds/prd-koel-2026-05-27/prd.md)
- [Implementation readiness report (1.4 dependency map + erratum traceability): `_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-28.md`](../planning-artifacts/implementation-readiness-report-2026-05-28.md)
- [Dart pub workspaces: https://dart.dev/tools/pub/workspaces](https://dart.dev/tools/pub/workspaces)
- [Melos 7 scripts (`exec:` per-package execution): https://melos.invertase.dev/configuration/scripts](https://melos.invertase.dev/configuration/scripts)
- [custom_lint package: https://pub.dev/packages/custom_lint](https://pub.dev/packages/custom_lint)
- [Dart `package:lints` profile catalogue: https://pub.dev/packages/lints](https://pub.dev/packages/lints)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (1M ctx) via Claude Code; loaded `/agent-flutter-engineer` (implement) per CLAUDE.md trigger before producing code.

### Debug Log References

- **Toolchain (Task 1.1):** Dart 3.12.0 (stable, 2026-05-08), Flutter 3.44.0 (channel stable, 2026-05-15) — both ≥ story floors.
- **Pre-implementation baseline (Tasks 1.2, 1.3):** `melos bootstrap` → `-> 11 packages bootstrapped`. `dart test` in `packages/koel_lints/` → 4/4 green.
- **Per-package snapshot (Task 1.4):** matches Dev Notes "Existing repo state" exactly — 7 Dart packages × 30-line `package:lints/recommended.yaml` boilerplate; 3 Flutter packages × 4-line `package:flutter_lints/flutter.yaml`; all 10 with **zero** `dev_dependencies` blocks.
- **Post-implementation `melos run analyze` (Task 5.2):** 11/11 packages report `No issues found!`. Output scanned manually for `warning -` / `error -` / `info -` — zero matches.
- **AC3 NFR-13 gate (Task 5.3):** the three pre-existing `include_file_not_found` warnings on `koel_devtools` / `koel_flutter` / `koel_widgets` from Story 1.3's Debug Log are absent in the post-implementation `melos run analyze` output — the include swap closed them as predicted.
- **`melos run format` first run (Task 5.4) — DEVIATION:** reformatted 2 files in `packages/koel_lints/` (`lib/koel_lints.dart` + `test/rules/exhaustive_switch_test.dart`) under Dart 3.12 trailing-comma-aware vertical layout. Tests stay 4/4 green after the reformat. **Second `melos run format` run reports `(0 changed)` across all 11 packages.** Diagnosis: source committed at `fa0f25d` was hand-formatted (or formatted under an older Dart) and never re-`dart format`-ed; the wired script surfaces the latent drift on first run. Reformat is mechanical (whitespace + arg-list layout, no semantic change). Kept the reformat over reverting because (a) the formatter is canonical at edit time, (b) reverting would re-introduce the drift on every contributor's first `melos run format`, and (c) Convention §6 "framework is the truth" — formatter is the framework here.
- **`melos run analyze:apply` (Task 5.5):** 11/11 packages report `Nothing to fix!`. Script wiring correct.
- **Task 6 plugin-discovery smoke test (DEFERRED per user-approved Option A):** Attempted `packages/koel_core/lib/_verify_lint.dart` (Task 6.2 spec shape — 3 private subtypes + fall-through `break`) and `packages/koel_core/lib/verify_lint.dart` (public-subtype shape matching the working `koel_lints` test fixture at `test/rules/fixtures/violations/missing_default.dart`). Both ran under `dart run custom_lint` from `packages/koel_core/` and from the workspace root with explicit target. Both returned `Analyzing... No issues found!`. Story Task 6.3 specifies `dart analyze` as the verification command, but `dart analyze` (CLI) does not load `custom_lint` plugins by design — only the analyzer server (IDE) and `dart run custom_lint` (CLI) do. Switched to the correct command; still zero diagnostics. Root cause traced to `custom_lint` 0.8.1 `visitAnalysisOptionAndIncludes` (`workspace.dart:333-341`) reading `package_config.json` from `analysisOptionsFile.parent.path/.dart_tool/` — empty per-member in pub-workspace mode — silently `null`ing the package-URI include resolver and aborting the chain before `analyzer.plugins: [custom_lint]` is discovered. Workaround consideration with `analyzer.plugins:` + `custom_lint.rules:` declared inline on `packages/koel_core/analysis_options.yaml` was tested under user-pause: still no diagnostics, indicating the plugin discovery path itself may also be impaired in workspace mode, not only the include-chain step. Reverted all debug edits; deleted `lib/_verify_lint.dart` / `lib/verify_lint.dart`. See `deferred-work.md` § "Deferred from: Story 1.4 implementation (2026-05-28)" for the full chain.
- **Task 7 cross-cutting (Task 7.1-7.7):**
  - 7.1 `grep -rn very_good_analysis packages/` → zero matches ✓
  - 7.2 `grep -rn flutter_lints packages/` → zero matches ✓
  - 7.3 `grep -l "include: package:koel_lints/koel.yaml" packages/*/analysis_options.yaml | wc -l` → `10` ✓
  - 7.4 `grep -A2 "^dev_dependencies:" packages/*/pubspec.yaml | grep -c "koel_lints:"` → `10` ✓
  - 7.5 Inspected workspace `pubspec.yaml`: `analyze` / `format` / `analyze:apply` → `exec:` bodies; `test` / `test:coverage` / `build` / `format:check` → `run: dart --version` placeholders ✓
  - 7.6 `dart analyze packages/koel_lints/` → `No issues found!` ✓
  - 7.7 `dart test` in `packages/koel_lints/` → 4/4 passing ✓ (re-run after the Dart 3.12 formatter pass confirmed no regression)
  - 7.8 All diagnostics surfaced are listed above; no unexpected warnings.

### Completion Notes List

1. **AC1 met.** All 10 non-lints `analysis_options.yaml` are the canonical 2-line shape (`# koel-mandatory profile ...` + `include: package:koel_lints/koel.yaml`). Previous `package:lints/recommended.yaml` (7 Dart) / `package:flutter_lints/flutter.yaml` (3 Flutter) includes replaced, not layered. `packages/koel_lints/analysis_options.yaml` untouched (G-3 preserved).
2. **AC2 met.** Every non-lints `pubspec.yaml` now declares `koel_lints:` (bare workspace-sibling entry) + `custom_lint: ^0.8.1` as the only dev_deps; preceded by the intentional blank line after `resolution: workspace`. No `path:`, no `version:`, no `flutter_lints`, no `very_good_analysis`. Workspace root `dev_dependencies:` block (`melos: ^7.8.0`) untouched.
3. **AC3 partially met.** `melos run analyze` exits 0 with 11/11 packages `No issues found!`; three pre-existing `include_file_not_found` warnings from Story 1.3 are gone (NFR-13 gate green). `melos run format` and `melos run analyze:apply` wired with `exec:` bodies; script `description:` strings updated to reflect the wired state. **`melos run format` deviation:** first run reformatted 2 files inside `koel_lints/` under Dart 3.12 — kept; second run reports `(0 changed)`. **AC3 plugin-discovery sub-gate (Task 6) DEFERRED per user-approved Option A:** `custom_lint` 0.8.1 has a pub-workspace include-resolution bug that prevents consumer-side plugin chain from firing the rule; documented in `deferred-work.md` as a tracked follow-up. Until upstream fix, `exhaustive_switch_must_have_default` enforces only inside `koel_lints` unit tests, not on consumer source.
4. **Closes** deferred-work items: "koel_lints not wired to consumers" (Story 1.1), "No shared analysis_options.yaml" (Story 1.1, per-package leg; root-level deferred per Task 2.3 to whichever story introduces root-level Dart code), "Story 1.4 wording: `koel_lints` cannot be added as `path:` dep across siblings" (Story 1.2; implementation uses bare workspace-sibling entries per Task 3.1).
5. **Surfaces** new deferred-work items: (a) `custom_lint` 0.8.1 workspace include-resolution bug — Task 6 deferred; (b) Dart 3.12 formatter drift on 2 `koel_lints/` files — resolved in-place; (c) Severity-downgrade snippet for consumers — carries to Story 1.6 README polish per Story 1.4 Dev Notes "Git intelligence". All three captured in `deferred-work.md`.
6. **Does NOT close** Story 1.3 deferred items: "`custom_lint.rules:` YAML syntax for 0.8.1 not end-to-end verified via consumer plugin path" remains open — the integration test was attempted and produced the inverse result (negative confirmation of upstream bug). The item is now `deferred-work.md` Story 1.4 entry's primary surface. Likewise "`analyzer.plugins:` merge vs override semantics for consumers unverified" remains effectively unverified — consumers don't declare `analyzer.plugins:` per the 2-line AC1 shape, so the merge question never arises in the v1.0.0 surface; tracked implicitly via the workspace bug entry.
7. **Reviewer focus:** validate that the 10-file change set on `analysis_options.yaml` + `pubspec.yaml` matches the exact target state (Dev Notes "After Story 1.4 target state"); confirm `deferred-work.md` Story 1.4 entry adequately captures the `custom_lint` workspace bug so it's traceable from Story 1.5 CI work and Story 1.6 README polish; sanity-check the `koel_lints/` formatter drift is whitespace-only (no semantic change) by reading the 2-file diff.

### File List

- `packages/koel/analysis_options.yaml` (modified — rewrite)
- `packages/koel_core/analysis_options.yaml` (modified — rewrite)
- `packages/koel_http/analysis_options.yaml` (modified — rewrite)
- `packages/koel_agno/analysis_options.yaml` (modified — rewrite)
- `packages/koel_langgraph/analysis_options.yaml` (modified — rewrite)
- `packages/koel_runtime/analysis_options.yaml` (modified — rewrite)
- `packages/koel_test/analysis_options.yaml` (modified — rewrite)
- `packages/koel_flutter/analysis_options.yaml` (modified — rewrite)
- `packages/koel_widgets/analysis_options.yaml` (modified — rewrite)
- `packages/koel_devtools/analysis_options.yaml` (modified — rewrite)
- `packages/koel/pubspec.yaml` (modified — append dev_deps block)
- `packages/koel_core/pubspec.yaml` (modified — append dev_deps block)
- `packages/koel_http/pubspec.yaml` (modified — append dev_deps block)
- `packages/koel_agno/pubspec.yaml` (modified — append dev_deps block)
- `packages/koel_langgraph/pubspec.yaml` (modified — append dev_deps block)
- `packages/koel_runtime/pubspec.yaml` (modified — append dev_deps block)
- `packages/koel_test/pubspec.yaml` (modified — append dev_deps block)
- `packages/koel_flutter/pubspec.yaml` (modified — append dev_deps block)
- `packages/koel_widgets/pubspec.yaml` (modified — append dev_deps block)
- `packages/koel_devtools/pubspec.yaml` (modified — append dev_deps block)
- `pubspec.yaml` (modified — wire `analyze` / `format` / `analyze:apply` melos script bodies)
- `packages/koel_lints/lib/koel_lints.dart` (modified — Dart 3.12 formatter pass; mechanical layout, no semantic change)
- `packages/koel_lints/test/rules/exhaustive_switch_test.dart` (modified — Dart 3.12 formatter pass; mechanical layout, no semantic change)
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified — appended Story 1.4 deferred-work section)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified — `1-4-adopt-koel-lints-profile` ready-for-dev → in-progress → review)
- `_bmad-output/implementation-artifacts/1-4-adopt-koel-lints-profile.md` (modified — Status, Tasks/Subtasks checkboxes, Dev Agent Record, File List, Change Log)

## Change Log

| Date       | Story / Status         | Change                                                                                                                                              |
|------------|------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| 2026-05-28 | 1.4 / ready-for-dev    | Story file created by create-story workflow; sprint-status updated.                                                                                 |
| 2026-05-28 | 1.4 / review           | Implemented Tasks 1-5 + 7: 10 consumer `analysis_options.yaml` rewritten to 2-line `package:koel_lints/koel.yaml` include; 10 consumer `pubspec.yaml` gained `koel_lints:` (bare workspace-sibling) + `custom_lint: ^0.8.1` dev_deps; workspace `melos.scripts:` `analyze` / `format` / `analyze:apply` wired with `exec:` bodies. NFR-13 green: `melos run analyze` exits 0, 11/11 packages "No issues found!", three pre-existing `include_file_not_found` warnings closed. **Task 6 (plugin-discovery smoke test) DEFERRED** per user-approved Option A — `custom_lint` 0.8.1 pub-workspace bug blocks consumer plugin chain (`workspace.dart:333-341`); rule still validated via `koel_lints` `testAnalyzeAndRun` unit tests. Two Dart 3.12 formatter-drift files in `koel_lints/` reformatted on first `melos run format`; second run `(0 changed)` confirms script wiring. Deferred-work entries added for: workspace bug (re-verify on upstream fix), Task 6 deferral, formatter drift (resolved in-place), severity-downgrade snippet (carries to Story 1.6). |
| 2026-05-28 | 1.4 / done             | `/bmad-code-review` ran 3 layers (Blind Hunter + Edge Case Hunter + Acceptance Auditor) on diff vs `fa0f25d`. 0 decision-needed, 0 patch, 5 defer, ~14 dismissed. Review Findings subsection appended to Tasks/Subtasks; deferred items appended to `deferred-work.md`. Acceptance Auditor verdict: all ACs met per spec attestation (AC3 plugin-discovery sub-gate openly marked unfulfilled, Task 6 deferral properly documented). Verified `dart analyze` clean on `koel_lints/` (fixtures don't trip built-in `non_exhaustive_switch_statement`) and all 3 Flutter packages (empty `lib/` masks any Flutter-lint regression today — flagged for Epic 4). Status → done. |
