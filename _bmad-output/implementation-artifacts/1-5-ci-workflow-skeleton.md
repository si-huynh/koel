---
baseline_commit: 2ef0a5f39b112f005784524d5adffe02c644d225
---

# Story 1.5: CI workflow skeleton (six GitHub Actions workflows)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a release manager,
I want the six CI workflow files (`ci.yml`, `conformance.yml`, `perf-bench.yml`, `api-diff.yml`, `codegen-drift.yml`, `publish-dry-run.yml`) scaffolded under `.github/workflows/` — with `ci.yml` and `codegen-drift.yml` carrying real bodies and the other four as exit-0 placeholders — plus the two remaining Melos scripts (`format:check`, `build`) wired,
So that every subsequent epic extends existing workflows rather than authoring fresh ones, per-PR analyze/test/format gating is in place from Epic 1 onward, and the destructive `melos run format` finally has a read-only CI counterpart (closes deferred items "No CI workflow files for format:check/build gates" and "`format:check` script bodyless while `format` is destructive").

## Acceptance Criteria

1. **AC1 — All six workflow files exist under `.github/workflows/`.**
   - **Given** the repo root (no `.github/` directory exists at baseline `2ef0a5f`),
   - **When** I list `.github/workflows/`,
   - **Then** exactly these six files exist: `ci.yml`, `conformance.yml`, `perf-bench.yml`, `api-diff.yml`, `codegen-drift.yml`, `publish-dry-run.yml` (per AR-17),
   - **And** every file is valid YAML that GitHub Actions accepts (parses, has `name:`, `on:`, and at least one job).

2. **AC2 — `ci.yml` runs analyze + test + format-check on Linux at the Dart 3.9.0 floor.**
   - **Given** `ci.yml`,
   - **When** I inspect its triggers and jobs,
   - **Then** it triggers on `pull_request` targeting `main` **and** `push` to `main`,
   - **And** it defines a `strategy.matrix` job (single Linux entry for the skeleton, structured for later platform expansion) running on `ubuntu-latest`,
   - **And** the job pins Dart **3.9.0** via `dart-lang/setup-dart@v1` with `sdk: 3.9.0` (matching D1 / NFR-9 / AR-3),
   - **And** the job executes, in order: `dart pub global activate melos 7.8.0` → `melos bootstrap` → `melos run analyze` → `melos run format:check` → `melos run test`,
   - **And** `melos run test` is invoked even though its body is a `dart --version` placeholder until Story 2.15 — the workflow references the script so it gains real coverage when 2.15 lands, with zero `ci.yml` edit needed.

3. **AC3 — `codegen-drift.yml` runs `melos run build && git diff --exit-code` and `build` is wired safely.**
   - **Given** `codegen-drift.yml`,
   - **When** I inspect it,
   - **Then** it triggers on `pull_request` to `main` and `push` to `main`, pins Dart 3.9.0 via `setup-dart`, activates melos, runs `melos bootstrap`, then runs `melos run build` followed by `git diff --exit-code` (per AR-18),
   - **And** the workflow's header comment names Epic 2 (first `freezed` codegen) as the epic that makes this gate meaningful,
   - **And** the workspace `pubspec.yaml` `build:` Melos script is wired to `dart run build_runner build --delete-conflicting-outputs` scoped via `packageFilters: { dependsOn: build_runner }` so it exits 0 today (zero packages declare `build_runner`) and auto-activates per-package when Epic 2 adds the dep — its `description:` no longer reads "wired in story 1.5".

4. **AC4 — The four remaining workflows are valid-YAML exit-0 placeholders naming their completing epic.**
   - **Given** `conformance.yml`, `perf-bench.yml`, `api-diff.yml`, `publish-dry-run.yml`,
   - **When** I open each,
   - **Then** each is valid YAML with a single placeholder job whose only meaningful step is `echo "Wired in Epic <N>"` and exits 0,
   - **And** each file's header comment names which epic completes the workflow: `conformance.yml` → Epic 5; `perf-bench.yml` → Epic 9; `api-diff.yml` → Epic 9; `publish-dry-run.yml` → Epic 9,
   - **And** each triggers on `pull_request` to `main` + `push` to `main` (so the check name is registered in the PR flow from Epic 1 onward; the job is a no-op until its epic wires the real body).

5. **AC5 — `format:check` Melos script wired; the analyze/format/analyze:apply trio from Story 1.4 untouched.**
   - **Given** the workspace `pubspec.yaml` `melos.scripts:` block,
   - **When** I inspect it,
   - **Then** `format:check` is wired to `dart format --output=none --set-exit-if-changed .` (read-only counterpart to the destructive `format` script) and its `description:` no longer reads "wired in story 1.5 (CI)",
   - **And** the `analyze` / `format` / `analyze:apply` script bodies wired by Story 1.4 are **byte-for-byte unchanged**,
   - **And** the `test` / `test:coverage` placeholders (owned by Story 2.15) are **unchanged** (still `run: dart --version`),
   - **And** `melos run format:check` exits 0 against the current tree (already formatted clean after Stories 1.1–1.4).

## Tasks / Subtasks

- [x] **Task 1 — Preflight + baseline assertion** (AC: all)
  - [x] 1.1 Confirm baseline is `2ef0a5f` (Story 1.4 done) and working tree is clean (`git status`). Every AC assumes the Story 1.4 end-state.
  - [x] 1.2 Confirm `.github/` does **not** exist yet (`ls .github` → no such directory). This story creates it from scratch.
  - [x] 1.3 Confirm `melos bootstrap` is green (`-> 11 packages bootstrapped`, no warnings) and `melos run analyze` exits 0 — the CI workflows you author must mirror commands that already pass locally.
  - [x] 1.4 Verify toolchain at edit time: `dart --version` ≥ 3.9.0 (D1 floor). Do NOT raise the floor; the CI pin is `3.9.0` regardless of your local patch version.

- [x] **Task 2 — Wire the two remaining Melos scripts** (AC: 3, 5)
  - [x] 2.1 In the workspace-root `pubspec.yaml`, REPLACE the `format:check` placeholder block with:
        ```yaml
            format:check:
              description: Run `dart format` in check mode per package (read-only CI gate).
              exec: dart format --output=none --set-exit-if-changed .
        ```
        4-space indent (matches the existing `analyze` / `format` blocks wired by Story 1.4).
  - [x] 2.2 REPLACE the `build` placeholder block with:
        ```yaml
            build:
              description: Run `build_runner build` in packages that declare build_runner (codegen-drift gate).
              exec: dart run build_runner build --delete-conflicting-outputs
              packageFilters:
                dependsOn: build_runner
        ```
        The `packageFilters.dependsOn` knob (Melos 7) scopes the script to members declaring `build_runner` as any dependency. **Today zero packages match**, so `melos run build` prints "No packages match the filter" and exits 0 — making `codegen-drift.yml` green from day one. When Story 2.1 adds `build_runner` + `freezed` to `koel_core`, the filter picks it up with no `pubspec.yaml` re-edit.
  - [x] 2.3 **Do NOT touch** the `analyze` / `format` / `analyze:apply` script bodies (Story 1.4's `exec:` forms are final) or the `test` / `test:coverage` placeholders (Story 2.15 owns them). Editing them creates cross-story merge-conflict surface.
  - [x] 2.4 Run `melos run format:check`. Expected: exit 0, eleven `[koel_*] dart format --output=none --set-exit-if-changed .` lines each reporting no changes. Run `melos run build`. Expected: exit 0 with a "no packages match" notice (no `build_runner` consumer exists yet).

- [x] **Task 3 — Author `ci.yml` (the real analyze/test/format gate)** (AC: 2)
  - [x] 3.1 Create `.github/workflows/ci.yml`. Required shape:
        ```yaml
        # ci.yml — primary per-PR gate: analyze + format-check + test.
        # Epic 1 skeleton: single Linux matrix entry. Expanded to 10 pkgs × 6 platforms in Epic 9 (AR-17 complete).
        name: CI
        on:
          pull_request:
            branches: [main]
          push:
            branches: [main]
        jobs:
          analyze-test:
            strategy:
              fail-fast: false
              matrix:
                os: [ubuntu-latest]
            runs-on: ${{ matrix.os }}
            steps:
              - uses: actions/checkout@v4
              - uses: dart-lang/setup-dart@v1
                with:
                  sdk: 3.9.0
              - run: dart pub global activate melos 7.8.0
              - run: melos bootstrap
              - run: melos run analyze
              - run: melos run format:check
              - run: melos run test
        ```
  - [x] 3.2 The matrix is a single-entry `os` list **on purpose** — it establishes the `strategy.matrix` structure so Epic 9 adds platforms/packages by extending the list, never by rewriting the file (epic goal: "every subsequent epic extends existing workflows rather than authoring fresh ones"). Do NOT collapse it to a plain `runs-on: ubuntu-latest` job.
  - [x] 3.3 Pin Dart to the literal `3.9.0` (not `stable`, not `3.9`). The floor is an architectural decision (D1 / NFR-9); CI must fail loudly if a future Dart breaks the 3.9.0 contract rather than silently floating.
  - [x] 3.4 Order matters: `analyze` → `format:check` → `test`. Analyze first (cheapest signal, most common failure); format-check second; test last. Each `melos run` step exits non-zero on failure, failing the job.
  - [x] 3.5 **Do NOT add** `--fatal-infos` / `--fatal-warnings` to any step here. The `melos run analyze` body (`dart analyze .`) already exits non-zero on errors; the fatal-infos escalation is tracked but NOT in this story's epic AC — keep the skeleton honest to the AC.

- [x] **Task 4 — Author `codegen-drift.yml`** (AC: 3)
  - [x] 4.1 Create `.github/workflows/codegen-drift.yml`:
        ```yaml
        # codegen-drift.yml — fails the PR if committed sources drift from build_runner output.
        # Meaningful from Epic 2 onward (first freezed/json_serializable codegen lands in koel_core, Story 2.1).
        name: Codegen drift
        on:
          pull_request:
            branches: [main]
          push:
            branches: [main]
        jobs:
          codegen-drift:
            runs-on: ubuntu-latest
            steps:
              - uses: actions/checkout@v4
              - uses: dart-lang/setup-dart@v1
                with:
                  sdk: 3.9.0
              - run: dart pub global activate melos 7.8.0
              - run: melos bootstrap
              - run: melos run build
              - run: git diff --exit-code
        ```
  - [x] 4.2 **Known semantic gap to document, NOT fix here:** generated files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`) are gitignored repo-wide (`.gitignore` at baseline). `git diff --exit-code` only inspects *tracked* files — so once real codegen lands, regenerated (gitignored) output will NOT register as a diff, partially defeating the drift gate. This is an **Epic 2 / Story 2.1 coordination item** (resolve by either un-gitignoring generated files for the CI check, or switching the assertion to `git status --porcelain` over untracked generated paths). The AR-18 literal command (`melos run build && git diff --exit-code`) is honored verbatim by this skeleton; the semantic reconciliation is out of scope for 1.5. Record this in Dev Notes + `deferred-work.md`.

- [x] **Task 5 — Author the four placeholder workflows** (AC: 4)
  - [x] 5.1 For each of `conformance.yml`, `perf-bench.yml`, `api-diff.yml`, `publish-dry-run.yml`, create a valid-YAML exit-0 placeholder. Template (substitute `<NAME>`, `<N>`, and the header rationale per file):
        ```yaml
        # <filename> — placeholder. Real body wired in Epic <N>.
        # <one-line note on what the real workflow will do>
        name: <Human Name>
        on:
          pull_request:
            branches: [main]
          push:
            branches: [main]
        jobs:
          placeholder:
            runs-on: ubuntu-latest
            steps:
              - run: echo "Wired in Epic <N>"
        ```
  - [x] 5.2 Per-file specifics:
        - `conformance.yml` → **Epic 5**. Header note: "AG-UI conformance suite via koel_test's ConformanceRunner."
        - `perf-bench.yml` → **Epic 9**. Header note: "Regression-relative perf SLOs (N-1..N-5) via test/perf/*_bench.dart."
        - `api-diff.yml` → **Epic 9**. Header note: "dart_apitool public-surface diff per package against published baseline (D7 / N-14)."
        - `publish-dry-run.yml` → **Epic 9**. Header note: "`dart pub publish --dry-run` per package."
  - [x] 5.3 Each placeholder job MUST exit 0 (a bare `echo` step does). Do NOT add steps that could fail (no checkout-then-build). The job's sole purpose is to register the check name and validate YAML until its epic lands.

- [x] **Task 6 — Local validation of the workflow YAML** (AC: 1, all)
  - [x] 6.1 Validate every file parses as YAML. If `yq` or `python3 -c 'import yaml,sys,glob; [yaml.safe_load(open(f)) for f in glob.glob(".github/workflows/*.yml")]'` is available, run it; otherwise eyeball-validate indentation. All six must parse.
  - [x] 6.2 Confirm `ls .github/workflows/ | wc -l` returns exactly `6` and the filenames match AC1 exactly (`.yml`, not `.yaml`).
  - [x] 6.3 Re-run `melos run analyze`, `melos run format:check`, `melos run build`, `melos run test` locally to confirm each command `ci.yml` / `codegen-drift.yml` invokes actually exits 0 at this baseline (so the first CI run on push is green). Document each exit code in Completion Notes.
  - [x] 6.4 `git status` should show exactly: six new files under `.github/workflows/`, and a modified workspace `pubspec.yaml` (the two script bodies). Nothing else.

- [x] **Task 7 — Cross-cutting verification + deferred-work bookkeeping** (AC: all)
  - [x] 7.1 Grep the six workflows for `3.9.0` — every workflow that runs Dart code (`ci.yml`, `codegen-drift.yml`) must pin it; placeholders need not.
  - [x] 7.2 Confirm no workflow references `melos run conformance` / `perf` / `api-diff` / `publish-dry` (those scripts don't exist yet; the placeholder workflows must NOT invoke them).
  - [x] 7.3 Confirm the workspace `pubspec.yaml` `melos.scripts:` block still has all seven keys (`analyze`, `test`, `test:coverage`, `build`, `format`, `format:check`, `analyze:apply`) — Story 1.1's contract that the script *names* are stable; only `format:check` + `build` change bodies this story.
  - [x] 7.4 Update `deferred-work.md`: mark "No CI workflow files for format:check/build gates" (1.1 review) and "`format:check` script bodyless while `format` is destructive" (1.4 review) as **closed by Story 1.5**; add a new entry for the codegen-drift gitignore-vs-`git diff` semantic gap (Task 4.2) assigned to Epic 2 / Story 2.1; carry forward the still-open toolchain items (local `.tool-versions`/`.fvmrc`, dependabot/renovate, full platform matrix) with their owners noted.
  - [x] 7.5 Document any diagnostic surfaced during 6.x–7.x in Completion Notes, even if expected/benign.

### Review Findings (code review 2026-05-29)

Adversarial review (Blind Hunter + Edge Case Hunter + Acceptance Auditor). Acceptance Auditor: all of AC1–AC5 PASS, no anti-patterns present. Triage: 1 decision-needed, 0 patch, 3 defer, 7 dismissed.

- [x] [Review][Patch applied 2026-05-29] Missing `permissions:` block on all six workflows — RESOLVED: added top-level `permissions: { contents: read }` to all six (least-privilege `GITHUB_TOKEN`). All six re-validated as parseable YAML.
- [x] [Review][Defer] `format:check` will check generated `*.g.dart`/`*.freezed.dart` in `lib/` once Epic 2 codegen lands [pubspec.yaml:43-45] — `dart format --set-exit-if-changed .` re-walks package `lib/`; if generator output is not format-stable, the gate fails spuriously. Resolve in Epic 2 (add `analyzer:`/format exclude for generated paths). Deferred.
- [x] [Review][Defer] No `concurrency:` group + PR-and-push double-run on `main` [.github/workflows/ci.yml] — redundant in-flight runs pile up; merge to main re-runs the full matrix. Add a `concurrency` block with `cancel-in-progress` during Epic 9 CI hardening (alongside `.pub-cache` caching). Deferred.
- [x] [Review][Defer] Four placeholder workflows are green-by-default [.github/workflows/{conformance,perf-bench,api-diff,publish-dry-run}.yml] — if marked "required" in branch protection before their epic wires a real body, green = "not implemented", not "passed". Caution flag for branch-protection config when real bodies land. Deferred.

Dismissed (noise / handled / by-design):
- `melos` not on PATH after `dart pub global activate` (Blind Hunter, claimed High) — FALSE POSITIVE. Verified `dart-lang/setup-dart@v1` `lib/main.dart:136` runs `core.addPath(pubCache + '/bin')`, adding `$HOME/.pub-cache/bin` to `GITHUB_PATH`. `melos` resolves correctly.
- Unpinned action major tags `@v1`/`@v4` — Dev Notes "Latest tech notes" explicitly mandates major-tag pinning. By design.
- `melos run build` emits `NoPackageFoundScriptException` but exits 0 (vacuous drift gate) — intended/documented (Task 2.2, deferred-work). Self-resolves at Story 2.1.
- `git diff --exit-code` blind to gitignored generated files — already documented and recorded in deferred-work as an Epic 2 / Story 2.1 item.
- `--delete-conflicting-outputs` masks generator conflicts — spec-specified canonical `build_runner` invocation (Task 2.2).
- No `.pub-cache` caching / cold pub fetch — already deferred to Epic 9 (CM-5) and recorded in deferred-work.
- No clean-checkout guarantee before `git diff` — `checkout@v4` is clean by default and `.dart_tool`/`build/` are gitignored.

## Dev Notes

### Scope perimeter — what this story touches (and what it must not)

**In scope (the ONLY files this story creates/modifies):**
- `.github/workflows/ci.yml` (NEW — real)
- `.github/workflows/codegen-drift.yml` (NEW — real)
- `.github/workflows/conformance.yml` (NEW — placeholder)
- `.github/workflows/perf-bench.yml` (NEW — placeholder)
- `.github/workflows/api-diff.yml` (NEW — placeholder)
- `.github/workflows/publish-dry-run.yml` (NEW — placeholder)
- `pubspec.yaml` (workspace root — wire `format:check` + `build` script bodies only)
- `deferred-work.md` (bookkeeping)

**This story is YAML + Melos-config only — no Dart source is touched.** The `/agent-flutter-engineer` deep-dive (mandated by CLAUDE.md for `.dart` work) is therefore **not** required for the implementation itself; the engineering judgment here is GitHub Actions + Melos 7 script semantics, both fully specified below. (If you find yourself editing a `.dart` file, you've left this story's perimeter — stop.)

**Out of scope (do NOT create/modify):**
- `.tool-versions` / `.fvmrc` (local contributor toolchain pin) — **Story 1.6** (deferred-work line 11; 1.5 owns the *CI* Dart pin via `setup-dart`, 1.6 owns the *local* pin).
- `dependabot.yml` / `renovate.json` (custom_lint 0.x footgun automation) — **Story 1.6** toolchain hardening.
- Root `README.md` / `CONTRIBUTING.md` / `LICENSE` — **Story 1.6**.
- The full 10-package × 6-platform CI matrix, web/macOS/Windows/Linux/iOS/Android lanes, coverage thresholds, caching — **Epic 9** (AR-17 "complete"). This story ships the *skeleton* only.
- `melos run test` / `test:coverage` script bodies — **Story 2.15**.
- Real `conformance` / `perf` / `api-diff` / `publish-dry` melos scripts — their respective epics.
- Any `packages/**` file (no package source, pubspec, or analysis_options change).

### Critical architectural anchors

- **AR-17 (CI matrix shape — the spine of this story):** GitHub Actions workflows are `ci.yml` (analyze+test+coverage), `conformance.yml`, `perf-bench.yml`, `api-diff.yml` (dart_apitool per package), `codegen-drift.yml` (`melos run build && git diff --exit-code`), `publish-dry-run.yml`. Epic 1 ships the *skeleton* (AR-17 "skeleton"); Epic 9 ships AR-17 "complete". [Source: `requirements-inventory.md:147`, `:238`, `:245`; `architecture.md:667-674`]
- **AR-18 (codegen orchestration):** Generated files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`) gitignored repo-wide; CI runs `melos run build && git diff --exit-code` to guarantee no drift. `freezed` + `json_serializable` + `koel_lints` compose via the Melos build pipeline. [Source: `requirements-inventory.md:148`; `architecture.md:402`, `:632`, `:1059-1062`]
- **D1 / NFR-9 (Dart floor):** Dart 3.9.0+ (raised from PRD's 3.0+; Melos 7.x recommends 3.9.0+, pub-workspace minimum 3.6.0+). CI pins the literal `3.9.0`. [Source: `architecture.md:258-264`; `requirements-inventory.md:102`]
- **AR-3 (bootstrap order):** `melos bootstrap` links the workspace; CI's first real step after toolchain setup. [Source: Story 1.1 / 1.4 records]
- **NFR-13 (analyze-clean gate):** `dart analyze` zero warnings across every package; `ci.yml`'s `melos run analyze` step is the CI enforcement point the prior stories deferred to "Story 1.5". [Source: `requirements-inventory.md:109`; Story 1.4 Dev Notes line 173]
- **FR-I1 (full CI matrix):** 10 pkgs × 6 platforms × analyze+test+coverage+conformance+publish-dry-run. **This is the Epic 9 target, NOT Story 1.5.** Story 1.5 ships the single-Linux skeleton that FR-I1 expands. [Source: `requirements-inventory.md:80`]

### Melos 7 script semantics (the two bodies you wire)

- **`exec:` form** runs the command once per workspace member, prefixing output with `[package_name]` — already proven by Story 1.4's `analyze` / `format` / `analyze:apply`. [Source: Story 1.4 Dev Notes line 270; https://melos.invertase.dev/configuration/scripts]
- **`packageFilters.dependsOn:`** scopes an `exec:` script to members declaring the named dependency. Used on `build:` so it no-ops until a package declares `build_runner` (Epic 2). This is the idiomatic Melos way to make a codegen script forward-safe without per-package edits. Confirm the exact key spelling against the installed Melos 7.8.0 (it is `packageFilters` with a nested `dependsOn`; older Melos 2.x used `select-package --depends-on` — do NOT use the legacy CLI-flag form inside the script block). [Source: Melos 7 config schema; verify against `~/.pub-cache` melos 7.8.0 if uncertain]
- **`melos.scripts:` lives in the workspace `pubspec.yaml`, NOT `melos.yaml`** — Story 1.1 finding, still true at this baseline (verified: `pubspec.yaml` lines 24-46). The `melos.yaml` file holds only `name` + `packages:` glob. [Source: Story 1.1 / 1.4 records; verified at story creation]

### GitHub Actions specifics

- **`dart-lang/setup-dart@v1`** with `with: { sdk: 3.9.0 }` installs the exact SDK and puts `dart`/`pub` on PATH. It does not cache `.pub-cache` by default — caching is an Epic 9 optimization (CM-5 CI-runtime counter-metric), deliberately omitted from the skeleton. [Source: architecture CM-5; D1 floor]
- **`melos` is a global pub package**, activated per-job via `dart pub global activate melos 7.8.0` (NOT a `setup-dart` feature). The pinned `7.8.0` matches the workspace `dev_dependencies: melos: ^7.8.0` and Story 1.1's decision. [Source: workspace `pubspec.yaml:22`; Story 1.1]
- **Trigger shape** `pull_request: { branches: [main] }` + `push: { branches: [main] }` mirrors the epic AC ("triggers on `pull_request` to main and `push` to main"). Applied uniformly across all six files so every check registers in the PR flow from Epic 1.
- **Matrix skeleton:** `strategy.matrix.os: [ubuntu-latest]` with `fail-fast: false`. Single entry now; the structure is the point. Epic 9 extends to `[ubuntu-latest, macos-latest, windows-latest]` and adds package/platform dimensions. [Source: AR-17 skeleton→complete split]

### Why `melos run test` is wired into `ci.yml` despite being a placeholder

`test`'s body is `run: dart --version` until Story 2.15. Invoking `melos run test` in `ci.yml` today runs `dart --version` per package (exit 0, trivially green). This is **intentional and correct**: the workflow references the *script name*, so when Story 2.15 swaps in the real `dart test` body, CI gains full test coverage with **zero `ci.yml` edit**. Do NOT omit the `melos run test` step "because it's a no-op" — that would force a `ci.yml` change in 2.15 and breaks the epic's "extend, don't rewrite" contract. Same logic applies to `codegen-drift.yml` invoking `melos run build` before any package has `build_runner`.

### The custom_lint workspace plugin-discovery bug (inherited context — do NOT try to "fix" in CI)

Story 1.4 confirmed (`deferred-work.md` § "Deferred from: Story 1.4 implementation") that `custom_lint` 0.8.1 has a pub-workspace-mode bug: `package:` URIs in consumer `analysis_options.yaml` include chains don't resolve, so `exhaustive_switch_must_have_default` does **not** fire on consumer source via `melos run analyze`. Crucially, **`dart analyze` still exits 0** (NFR-13's zero-warning gate holds — the rule simply never runs on consumers). For `ci.yml` this means: the analyze step is green and correct *as a skeleton*; it does NOT yet enforce the custom rule on consumer code. **Do not interpret a green analyze step as "the custom rule is enforced in CI" — it isn't, until upstream `custom_lint` ships a workspace fix.** No action in this story; flagged so the dev agent doesn't add workarounds chasing a non-failure. [Source: `deferred-work.md:43-44`]

### codegen-drift `git diff` vs gitignore tension (Task 4.2 expanded)

AR-18 literally says `melos run build && git diff --exit-code`, and `.gitignore` lists `*.g.dart` / `*.freezed.dart` / `*.mocks.dart`. `git diff --exit-code` inspects only tracked files; gitignored regenerated output is invisible to it. So once Epic 2 codegen lands, the drift gate as-literally-specified catches only drift in *tracked* sources that `build_runner` happens to touch (rare). The skeleton ships the AR-18 command verbatim (correct per the AC); the semantic fix — un-gitignore generated files for the CI lane, or assert over `git status --porcelain` of untracked generated paths — is an **Epic 2 / Story 2.1** decision. This is a known, documented gap, not an oversight. Record in `deferred-work.md`.

### Existing repo state (verified at story creation, baseline `2ef0a5f`)

- **No `.github/` directory.** This story creates it.
- **Workspace `pubspec.yaml` `melos.scripts:`** (lines 24-46) — seven keys: `analyze` (wired `exec: dart analyze .`), `test` (placeholder `dart --version`, → 2.15), `test:coverage` (placeholder, → 2.15), `build` (placeholder, description "wired in story 1.5 (codegen-drift gate); exercised by 2.1 (freezed)"), `format` (wired `exec: dart format .`), `format:check` (placeholder, description "wired in story 1.5 (CI)"), `analyze:apply` (wired `exec: dart fix --apply`). **Story 1.5 wires exactly two: `format:check` and `build`.**
- **`.gitignore`** excludes `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, `.dart_tool/`, `build/`, `coverage/`, `.melos_tool/`, per-package `pubspec.lock`. [Story 1.1]
- **`melos.yaml`** holds `name` + `packages:` glob only (114 bytes). Scripts live in `pubspec.yaml`.
- **No `build_runner` anywhere** — so the `build` script's `dependsOn` filter matches zero packages today (intended).

### Anti-patterns to reject in review

- ❌ Pinning Dart to `stable` / `3.9` / `latest` in any workflow — the floor is the literal `3.9.0` (D1).
- ❌ Collapsing `ci.yml`'s `strategy.matrix` to a plain single job — kills the Epic 9 extension point.
- ❌ Omitting the `melos run test` step from `ci.yml` "because it's a placeholder" — breaks the "extend, don't rewrite" contract for Story 2.15.
- ❌ Giving any of the four placeholder workflows steps that can fail (checkout + build) — they must exit 0 via a bare `echo`.
- ❌ Having a placeholder workflow invoke a non-existent melos script (`melos run conformance`, etc.) — it would fail the no-op job.
- ❌ Adding `--fatal-infos` / `--fatal-warnings` to `ci.yml`'s analyze step — not in this story's AC (the fatality escalation is a separately-tracked future item).
- ❌ Editing the `analyze` / `format` / `analyze:apply` bodies (Story 1.4 final) or the `test` / `test:coverage` placeholders (Story 2.15) — cross-story conflict surface.
- ❌ Wiring `build` without the `dependsOn: build_runner` filter — bare `dart run build_runner build` fails in packages lacking the dev-dep, breaking `codegen-drift.yml` on the first run.
- ❌ Creating `.tool-versions` / `.fvmrc` / `dependabot.yml` / `README.md` — Story 1.6 perimeter.
- ❌ Building the full 10×6 platform matrix, coverage gates, or `.pub-cache` caching — Epic 9 (AR-17 complete). This is the *skeleton*.
- ❌ Touching any `packages/**` file or any `.dart` file — outside the perimeter.
- ❌ Using `.yaml` extensions — the AC enumerates `.yml`.
- ❌ "Fixing" a green `melos run analyze` to fail because the custom_lint rule isn't firing — the green is correct (see workspace-bug note); the enforcement gap is upstream, not a CI defect.

### Previous story intelligence (from Story 1.4, commit `2ef0a5f`)

- **Story 1.4 wired `analyze` / `format` / `analyze:apply` Melos scripts** with `exec:` forms and updated their descriptions away from placeholders. Story 1.5 follows the identical pattern for the last two scripts. [Source: 1.4 Task 4]
- **Story 1.4 explicitly deferred the `format:check` body to Story 1.5** ("`format` melos script ships destructive without paired read-only `format:check` … Story 1.5 already owns `format:check` per its `description:` annotation"). [Source: `deferred-work.md:53`; 1.4 Review Findings line 165]
- **Story 1.4 explicitly deferred CI lint enforcement to Story 1.5** ("CI `dart analyze --fatal-infos` gate not wired. Closed by Story 1.5 `.github/workflows/ci.yml`"). Note: 1.4's phrasing mentions `--fatal-infos`; the *epic AC* for ci.yml does NOT require it — honor the epic AC (plain `melos run analyze`), and leave the fatal-infos escalation as a tracked future refinement rather than silently introducing it. [Source: 1.4 Dev Notes line 362]
- **Melos `exec:` scripts lack `failFast` / `orderDependents` / `concurrency`** (1.4 deferred-work line 54) — flagged for "Story 1.5 CI hardening or a dedicated melos-config polish story". For the *skeleton*, leave the script bodies as plain `exec:` (matching 1.4); CI-noise hardening is optional polish, not an AC. Do not gold-plate.
- **Commit convention:** `chore(story-X.Y): <subject>` (Stories 1.1–1.4). This story → `chore(story-1.5): scaffold six CI workflows + wire format:check/build melos scripts`. [Source: `git log`]
- **Code-review autocommit:** per `feedback_bmad_code_review_autocommit.md`, when `/bmad-code-review` flips this story to `done`, commit all related changes in the same turn. [Source: user memory]

### Latest tech notes (verify at implementation time if uncertain)

- **`dart-lang/setup-dart@v1`** is the current major; `sdk: 3.9.0` selects an exact release. Pin to `@v1` (major), not a floating `@latest`.
- **`actions/checkout@v4`** is current. Pin the major.
- **Melos 7.8.0** `packageFilters.dependsOn` is the in-`pubspec.yaml` script-scoping mechanism (not the legacy `melos exec --depends-on` CLI flag). If the installed schema rejects `packageFilters`, fall back to `exec --depends-on build_runner` inside the script's command string and document the deviation.
- **`dart format --output=none --set-exit-if-changed`** is the canonical read-only check invocation (exits 1 if any file would change). Confirmed stable across Dart 3.9+.

### Architecture compliance — what this story enables for later

- **Story 1.6 (root docs):** `CONTRIBUTING.md` documents the workflow as `melos bootstrap → melos run analyze → melos run format:check → melos run test`; after this story all four are real (or honest placeholders that resolve to real). Story 1.6 also adds the *local* toolchain pin (`.tool-versions`/`.fvmrc`) that complements this story's *CI* pin.
- **Story 2.1 (`koel_core` events + first freezed codegen):** activates the `codegen-drift.yml` gate (the `build` script's `dependsOn` filter starts matching `koel_core`) and resolves the gitignore-vs-`git diff` semantic gap (Task 4.2).
- **Story 2.15 (test scripts):** swaps the `test` / `test:coverage` placeholder bodies for real `dart test` — `ci.yml` gains coverage with no edit.
- **Epic 5 (conformance):** wires `conformance.yml`'s real body + a `melos run conformance` script.
- **Epic 9 (release gates):** completes AR-17 — expands `ci.yml` to the full 10×6 matrix; wires `api-diff.yml` (dart_apitool, D7/N-14), `perf-bench.yml` (N-1..N-5 SLOs), `publish-dry-run.yml`.

### Git intelligence

- **Last commit on `main`:** `2ef0a5f chore(story-1.4): adopt koel_lints profile + wire melos analyze/format scripts`. This story builds directly on it.
- **Working tree:** clean at story creation (2026-05-29).
- **Deferred items this story CLOSES** (from `deferred-work.md`):
  - "No CI workflow files for format:check/build gates" (1.1 review, line 9) — **closed** (six workflows + `build` script).
  - "`format:check` script bodyless while `format` is destructive" (1.4 review, line 53) — **closed** (Task 2.1).
- **Deferred items this story PARTIALLY addresses:**
  - "No toolchain pin (.fvmrc / asdf)" (1.1 review, line 11) — CI Dart pin via `setup-dart` shipped here; the *local* `.tool-versions`/`.fvmrc` stays with Story 1.6.
  - "`melos.yaml packages/*` can drift from root `workspace:` list — Story 1.5 CI can add membership guard" (1.1 review, line 13) — **NOT shipped** in this skeleton (a membership-guard job is gold-plating beyond the six-file AC); carry forward, optionally fold into Epic 9 ci.yml hardening.
- **Deferred items this story does NOT close** (carry forward with owners):
  - "Caret pin `^0.8.1` on `custom_lint` (0.x footgun) + no renovate/dependabot config" → Story 1.6 toolchain hardening.
  - custom_lint workspace plugin-discovery bug → upstream; re-verify when `custom_lint` ships a workspace fix.
  - codegen-drift gitignore-vs-`git diff` semantic gap → **NEW entry**, Epic 2 / Story 2.1.
  - Melos `exec:` `failFast`/`concurrency` config → optional polish, not blocking.

### File structure requirements (target state after this story)

```
koel/
├── pubspec.yaml                       # WORKSPACE ROOT — format:check + build script bodies wired (Task 2)
├── .github/
│   └── workflows/
│       ├── ci.yml                     # NEW — real: analyze + format:check + test, Linux matrix, Dart 3.9.0 (Task 3)
│       ├── codegen-drift.yml          # NEW — real: melos run build && git diff --exit-code (Task 4)
│       ├── conformance.yml            # NEW — placeholder → Epic 5 (Task 5)
│       ├── perf-bench.yml             # NEW — placeholder → Epic 9 (Task 5)
│       ├── api-diff.yml               # NEW — placeholder → Epic 9 (Task 5)
│       └── publish-dry-run.yml        # NEW — placeholder → Epic 9 (Task 5)
└── packages/                          # UNTOUCHED
```

### Testing requirements

- **AC1 gate:** `ls .github/workflows/*.yml | wc -l` → `6`; all parse as YAML (Task 6.1).
- **AC2/AC3 gate:** every command `ci.yml` / `codegen-drift.yml` invokes (`melos bootstrap`, `melos run analyze`, `melos run format:check`, `melos run test`, `melos run build`, `git diff --exit-code`) exits 0 locally at this baseline (Task 6.3) — so the first push to a CI-enabled remote is green.
- **AC5 gate:** `melos run format:check` exits 0; the `analyze`/`format`/`analyze:apply` bodies are byte-identical to baseline; `test`/`test:coverage` unchanged (Task 7.3).
- **No unit/widget tests** — this story ships CI config + Melos scripts, no Dart source. The "tests" are the local dry-runs of the CI commands.
- **No coverage / dart_apitool / conformance gate** — those workflows are placeholders here.

### Project Structure Notes

- **Alignment:** Matches `architecture.md:667-674` (the `.github/workflows/` six-file layout) and `:1057-1069` (development-workflow command list) exactly. The `melos.scripts:` keys match Story 1.1's stable-name contract.
- **Detected conflicts / errata vs source text:**
  1. Epic AC for `ci.yml` says it runs "`... && melos run analyze && melos run test`" but omits `format:check`. This story **adds `format:check`** to `ci.yml` because the 1.4 review deferred-work explicitly assigns the read-only format gate to Story 1.5 and a CI without it leaves the destructive `format` script un-paired. This is an additive reconciliation, not a contradiction — documented here.
  2. Epic AC mentions `ci.yml` Dart "3.9.0"; the architecture's FR-I1 describes a 10×6 matrix. Reconciled via the AR-17 skeleton-vs-complete split: this story = skeleton (single Linux), Epic 9 = complete (10×6).
  3. `codegen-drift.yml`'s `git diff --exit-code` is semantically partial under the repo's gitignore policy (Task 4.2) — honored verbatim per AR-18, semantic fix deferred to Epic 2.
- **Variances from architecture target state** (intentional, bounded — closed by later stories):
  - Single-Linux matrix vs full 10×6 → Epic 9.
  - No `.pub-cache` caching → Epic 9 CM-5 optimization.
  - Four workflows are no-op placeholders → their respective epics.
  - Local toolchain pin absent → Story 1.6.

### References

- [Story 1.5 acceptance criteria source: `_bmad-output/planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md` §"Story 1.5"](../planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md#story-15-ci-workflow-skeleton-six-github-actions-workflows)
- [Story 1.4 implementation record (Melos `exec:` script pattern + `format:check`/`build` deferral to 1.5): `_bmad-output/implementation-artifacts/1-4-adopt-koel-lints-profile.md`](./1-4-adopt-koel-lints-profile.md)
- [Story 1.1 implementation record (`melos.scripts:` live in `pubspec.yaml`; `.gitignore` shape; script-name contract): `_bmad-output/implementation-artifacts/1-1-workspace-bootstrap.md`](./1-1-workspace-bootstrap.md)
- [Architecture §"Project structure" `.github/workflows/` six-file layout: `_bmad-output/planning-artifacts/architecture.md` lines 667-674](../planning-artifacts/architecture.md)
- [Architecture §"Development workflow integration" (bootstrap/codegen/test command list): `_bmad-output/planning-artifacts/architecture.md` lines 1057-1069](../planning-artifacts/architecture.md)
- [Architecture D1 (Dart 3.9.0 floor), D7 (dart_apitool), AR-18 codegen-drift command: `_bmad-output/planning-artifacts/architecture.md` lines 258-264, 318-327, 402, 632](../planning-artifacts/architecture.md)
- [Requirements inventory AR-17 (CI matrix shape), AR-18 (codegen orchestration), FR-I1, NFR-9, NFR-13, NFR-14: `_bmad-output/planning-artifacts/epics/requirements-inventory.md` lines 80, 102, 109-110, 147-148](../planning-artifacts/epics/requirements-inventory.md)
- [Deferred work tracking (CI-gate + format:check deferrals this story closes; custom_lint workspace bug context): `_bmad-output/implementation-artifacts/deferred-work.md`](./deferred-work.md)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Claude Opus 4.8) via bmad-dev-story workflow.

### Debug Log References

- Preflight: Dart SDK 3.12.0 (≥ 3.9.0 floor), `melos bootstrap` → `-> 11 packages bootstrapped`, `melos run analyze` exit 0. Baseline confirmed at `2ef0a5f`; `.github/` absent at baseline.
- `melos run format:check` exit 0 (eleven `[koel_*] dart format --output=none --set-exit-if-changed .` lines, all "0 changed").
- `melos run build` exit 0 (verified deterministic across two runs). Prints `NoPackageFoundScriptException` notice because `packageFilters.dependsOn: build_runner` matches zero packages today — benign, exit code is 0.
- `melos run test` exit 0 (placeholder `dart --version` per package, → Story 2.15).
- `melos run build` introduces zero file changes (git status byte-identical before/after) → `codegen-drift.yml`'s `git diff --exit-code` is green on a clean checkout. The local `git diff --exit-code` exit 1 is solely from this story's own in-progress edits, not codegen drift.
- All six `.github/workflows/*.yml` parse via `yaml.safe_load`; `ls .github/workflows | wc -l` → 6; filenames match AC1 exactly (`.yml`).
- `3.9.0` pinned in `ci.yml` + `codegen-drift.yml` only (placeholders need no pin). No placeholder invokes a non-existent melos script. `melos.scripts:` retains all seven keys.

### Completion Notes List

- **AC1 ✅** — Six workflow files created under `.github/workflows/`; all valid YAML with `name:`/`on:`/≥1 job; `ls | wc -l` = 6, all `.yml`.
- **AC2 ✅** — `ci.yml` triggers on `pull_request`+`push` to `main`; `strategy.matrix.os: [ubuntu-latest]` with `fail-fast: false` (single-entry by design, the Epic 9 extension point); pins Dart `3.9.0` via `setup-dart@v1`; runs in order: activate melos 7.8.0 → bootstrap → analyze → format:check → test. `melos run test` referenced despite its placeholder body so Story 2.15 gains coverage with zero `ci.yml` edit.
- **AC3 ✅** — `codegen-drift.yml` triggers PR+push to `main`, pins 3.9.0, activates melos, bootstrap, `melos run build` → `git diff --exit-code`; header comment names Epic 2. `build` Melos script wired to `dart run build_runner build --delete-conflicting-outputs` scoped via `packageFilters.dependsOn: build_runner`; exits 0 today (zero consumers), auto-activates when Epic 2 adds the dep.
- **AC4 ✅** — `conformance.yml` (→Epic 5), `perf-bench.yml` (→Epic 9), `api-diff.yml` (→Epic 9), `publish-dry-run.yml` (→Epic 9): each a valid-YAML single-job placeholder whose only step is `echo "Wired in Epic <N>"`, triggers PR+push to `main`, header comment names completing epic + real-body note.
- **AC5 ✅** — `format:check` wired to `dart format --output=none --set-exit-if-changed .`; `analyze`/`format`/`analyze:apply` bodies byte-for-byte unchanged; `test`/`test:coverage` unchanged (still `dart --version`); `melos run format:check` exits 0 against current tree.
- **Diagnostic (benign, expected):** `melos run build` emits `NoPackageFoundScriptException` to stderr but exits 0 — this is the intended no-op state until a package declares `build_runner` (Story 2.1). Recorded in `deferred-work.md`.
- **Deferred-work bookkeeping:** closed "No CI workflow files for format:check/build gates" (1.1) and "`format:check` bodyless while `format` destructive" (1.4); added new entry for the codegen-drift gitignore-vs-`git diff` semantic gap (Epic 2 / Story 2.1); carried forward local toolchain pin (1.6), dependabot/renovate (1.6), full 10×6 matrix (Epic 9), and membership-guard job (Epic 9, not gold-plated here).
- **No Dart source touched** — story stayed within YAML + Melos-config perimeter; `/agent-flutter-engineer` deep-dive not required (per Dev Notes).

### File List

- `.github/workflows/ci.yml` (NEW — real: analyze + format:check + test, single-Linux matrix, Dart 3.9.0)
- `.github/workflows/codegen-drift.yml` (NEW — real: `melos run build && git diff --exit-code`)
- `.github/workflows/conformance.yml` (NEW — placeholder → Epic 5)
- `.github/workflows/perf-bench.yml` (NEW — placeholder → Epic 9)
- `.github/workflows/api-diff.yml` (NEW — placeholder → Epic 9)
- `.github/workflows/publish-dry-run.yml` (NEW — placeholder → Epic 9)
- `pubspec.yaml` (MODIFIED — wired `format:check` + `build` Melos script bodies only)
- `_bmad-output/implementation-artifacts/deferred-work.md` (MODIFIED — bookkeeping)

## Change Log

- 2026-05-29 — Story 1.5 implemented: scaffolded six `.github/workflows/` files (`ci.yml` + `codegen-drift.yml` real, four placeholders), wired `format:check` + `build` Melos scripts. Status → review.
