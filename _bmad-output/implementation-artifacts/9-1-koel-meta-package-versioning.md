---
baseline_commit: ca5213ac7a2ac21814e78765a5c73ad4ccda1224
---

# Story 9.1: `koel` meta-package re-exports + hybrid versioning ranges

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter developer,
I want `dart pub add koel` to produce a working SDK installation by re-exporting `koel_core` + `koel_http` + `koel_flutter` with hybrid-versioning ranged dependencies (`^X.Y.0`),
so that the quickstart path is one package add per FR-H3 + FR-H2.

## Context — Epic 9 kickoff (resequenced ahead of DevTools)

This is the **first story of Epic 9** (`epic-9` flips `backlog → in-progress`). Per **SCP-2026-06-06-B** (Epic-7 retro), Epic 9 now runs **before** the DevTools epic: v1.0.0 ships the **ten** packages that exist today; `koel_devtools` is deferred post-1.0 (→ Epic 10) and is **excluded from the v1.0.0 lock-step + versioning convention** below. Story 9.1 establishes the **versioning + re-export convention** for the whole release set; Story 9.9 performs the actual publish. The version bump and the `pub publish`/`publish_to` removal are split between them on purpose (see Scope).

## Acceptance Criteria

**AC1 — Barrel: exactly three re-exports, ≤6 LOC.**
**Given** `packages/koel/lib/koel.dart`, **when** I inspect the barrel, **then** it contains exactly three `export 'package:<name>/<name>.dart';` lines — `koel_core`, `koel_http`, `koel_flutter` — per Addendum + architecture §2, **and** the file is ≤ 6 LOC total (the `library;` directive + a one-line doc header are permitted within the 6).

**AC2 — Meta-package ranged dependencies.**
**Given** `packages/koel/pubspec.yaml`, **when** I inspect dependencies, **then** `koel_core: ^1.0.0`, `koel_http: ^1.0.0`, `koel_flutter: ^1.0.0` are declared with proper version ranges per FR-H2, **and** `koel_lints` is NOT a runtime dependency (it stays a `dev_dependency`; consumers integrate it via `analysis_options.yaml` separately) per FR-H3.

**AC3 — Foundation lock-step versions.**
**Given** the foundation lock-step constraint, **when** I check `koel_core` + `koel_http` + `koel_lints` pubspec versions, **then** all three carry identical `1.0.0` versions per FR-H2 + PRD §12 R-2.

**AC4 — Dependents declare ranged (not pinned) foundation deps + CI assertion.**
**Given** the backend bridges + Flutter + widgets + test packages, **when** I check their pubspec dependency on the foundations, **then** each declares a `^1.0.0` range (NOT a tight `1.0.0` pin, NOT a bare workspace key) on every foundation it depends on (`koel_core`, and `koel_http` where applicable) per FR-H2 + PRD §12 R-3, **and** an internal CI step asserts the convention on every PR (`koel_devtools` and the `koel_widgets/example` app are excluded — not in the v1.0.0 release set).

## Tasks / Subtasks

- [x] **Task 1 — Write the 3-export barrel** (AC1)
  - [x] Replace the body of [packages/koel/lib/koel.dart](packages/koel/lib/koel.dart) (currently an empty `library;` stub) with exactly three re-export lines:
    ```dart
    /// koel — the AG-UI SDK quickstart barrel: core protocol + HTTP/SSE transport + Flutter glue.
    library;

    export 'package:koel_core/koel_core.dart';
    export 'package:koel_http/koel_http.dart';
    export 'package:koel_flutter/koel_flutter.dart';
    ```
  - [x] Confirm ≤ 6 LOC total. **Do NOT** re-export `koel_widgets`, `koel_test`, the backend adapters, or `koel_lints` — see **D1** (architecture §2 line 512–514 is explicit).

- [x] **Task 2 — Wire the meta-package pubspec** (AC2, AC3-adjacent, D4)
  - [x] In [packages/koel/pubspec.yaml](packages/koel/pubspec.yaml), add a `dependencies:` block with the three runtime re-exports as caret ranges:
    ```yaml
    dependencies:
      koel_core: ^1.0.0
      koel_http: ^1.0.0
      koel_flutter: ^1.0.0
    ```
  - [x] Keep `koel_lints` as a `dev_dependency` (AC2: never runtime) and give it a range: `koel_lints: ^1.0.0`.
  - [x] Add the Flutter environment constraint (the barrel re-exports `koel_flutter` ⇒ `koel` is a Flutter package — **D4**): under `environment:` add `flutter: ">=3.38.0"` (parity with `koel_flutter`/`koel_widgets`). Do **NOT** add a direct `flutter: sdk: flutter` dependency — `koel`'s own source imports zero Flutter symbols; Flutter arrives transitively via `koel_flutter`.
  - [x] Bump `version: 0.0.1` → `version: 1.0.0`. Leave `publish_to: none` in place (publish wiring is Story 9.5/9.9 — see Scope).

- [x] **Task 3 — Foundation lock-step versions** (AC3)
  - [x] Set `version: 1.0.0` in [packages/koel_core/pubspec.yaml](packages/koel_core/pubspec.yaml), [packages/koel_http/pubspec.yaml](packages/koel_http/pubspec.yaml), [packages/koel_lints/pubspec.yaml](packages/koel_lints/pubspec.yaml) — identical strings.

- [x] **Task 4 — Bump dependents to 1.0.0 + swap every intra-repo dep to `^1.0.0`** (AC4, D2, D3)
  - [x] Bump `version: 0.0.1` → `version: 1.0.0` in the remaining release-set packages: `koel_test`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`. **D2 (proven empirically — see Dev Notes):** any package targeted by a `^1.0.0` range MUST be `≥1.0.0` or pub workspace resolution fails. Uniform `1.0.0` is the honest v1.0.0 baseline.
  - [x] Swap every bare intra-repo key → `^1.0.0` across the ten release packages, per this exact table (current bare keys → target):

    | Package | `dependencies:` (runtime) → `^1.0.0` | `dev_dependencies:` → `^1.0.0` |
    |---|---|---|
    | `koel` (meta) | koel_core, koel_http, koel_flutter *(added in Task 2)* | koel_lints |
    | `koel_core` | — | koel_lints |
    | `koel_http` | koel_core | koel_lints, koel_test |
    | `koel_test` | koel_core | koel_lints |
    | `koel_flutter` | koel_core | koel_lints, koel_test |
    | `koel_widgets` | koel_core, koel_flutter | koel_lints |
    | `koel_agno` | koel_core, koel_http | koel_lints, koel_test |
    | `koel_langgraph` | koel_core, koel_http | koel_lints, koel_test |
    | `koel_runtime` | koel_core, koel_http | koel_lints, koel_test |

  - [x] **DO NOT TOUCH** [packages/koel_devtools/pubspec.yaml](packages/koel_devtools/pubspec.yaml) — it keeps `version: 0.0.1` + bare keys (Epic 10; bare keys resolve fine against `1.0.0` siblings — proven). **DO NOT TOUCH** [packages/koel_widgets/example/pubspec.yaml](packages/koel_widgets/example/pubspec.yaml) — bare keys, not in the release set.

- [x] **Task 5 — Convention-assert script + CI wiring** (AC4)
  - [x] Create `tool/verify_versioning.sh` (bash + grep — house pattern, **zero new dependency**; mirrors `tool/format.sh`/`tool/coverage.sh`). It iterates the **ten release pubspecs** (exclude `koel_devtools` and `koel_widgets/example`) and asserts, exiting non-zero with a clear message on any violation:
    1. **Lock-step:** `koel_core`, `koel_http`, `koel_lints` carry an **identical** `version:` string (R-2).
    2. **Ranged, not pinned, not bare:** every intra-repo dependency key (any line whose key is `koel` or `koel_*`) under `dependencies:`/`dev_dependencies:` has a value matching `^\d+\.\d+\.\d+` — reject bare keys (empty value) and tight pins (`1.0.0` without `^`).
    3. **`koel_lints` never runtime:** `koel_lints` appears only under `dev_dependencies:`, never `dependencies:` (AC2 / FR-H3).
  - [x] Add a `verify:versioning` script to the `melos:` block in [pubspec.yaml](pubspec.yaml) (root) running `bash "$MELOS_ROOT_PATH/tool/verify_versioning.sh"`.
  - [x] Add a `melos run verify:versioning` step to the `analyze-test` job in [.github/workflows/ci.yml](.github/workflows/ci.yml) (the always-on per-PR gate ⇒ green main is a publish precondition ⇒ "asserts before each publish"). Do **NOT** wire `publish-dry-run.yml` — that placeholder is Story 9.5's.

- [x] **Task 6 — Barrel-resolve test** (AC1 proof)
  - [x] Add `flutter_test: { sdk: flutter }` to `koel`'s `dev_dependencies` and create `packages/koel/test/koel_barrel_test.dart`: import only `package:koel/koel.dart` and reference **one symbol from each re-exported package** so the test fails to compile if any re-export is missing — e.g. `KoelClient` (core), `HttpAgent` (http), `KoelChatController` (flutter). A single `test('barrel re-exports core + http + flutter', () { … })` that constructs/`expect`s those types is sufficient; the real assertion is compile-time resolution. Runs under `flutter test` (koel is now a Flutter package — D4); it is auto-detected by `tool/test_package.sh` via the `sdk: flutter` anchor (AI-6.2).

- [x] **Task 7 — Resolve + gate verification** (all ACs)
  - [x] Run `melos bootstrap` (flutter-aware) from repo root; confirm **green resolution** (this empirically validates D2/D3 — a missed bump surfaces here as "version solving failed").
  - [x] `git diff pubspec.lock` (root) — confirm **AI-5.9 pins held**: `analyzer 12.1.0` + `freezed 3.2.6-dev.1` MUST NOT drift (SCP-2026-05-29-B). New `version:`/range edits should produce **near-zero** lock churn (intra-workspace path resolution; no new hosted dep).
  - [x] `melos run analyze` (all pkgs + asp plugin) clean — including `koel` (the barrel must resolve all three re-exports).
  - [x] `melos run verify:versioning` green.
  - [x] `melos run test` SUCCESS (koel barrel test passes; existing suites unchanged).
  - [x] `melos run format:check` 0-changed.

- [x] **Task 8 — README touch-up** (D1, no AC but ship-coherent)
  - [x] In [packages/koel/README.md](packages/koel/README.md), remove/replace the stale line "*The re-export barrel is finalized in Epic 9 once the underlying packages ship.*" — it IS finalized here. Keep the existing quickstart prose (already accurate). Do not add badges/marketing (architecture anti-pattern rules; full README polish is Story 9.6).

### Review Findings

Code review 2026-06-06 (3-layer adversarial: Blind Hunter / Edge Case Hunter / Acceptance Auditor). Auditor: **0 AC violations**, all Tasks realized, no scope-creep, gates green. 1 patch, 12 dismissed (by-design / YAGNI / verified-fine).

- [x] [Review][Patch] `verify_versioning.sh` success message overclaimed "10 release packages lock-step" — only the three foundations (core/http/lints) have their `version:` strings compared for equality; the other 7 release packages are scanned for caret-ranged deps but never asserted same-version. **Fixed:** reworded OK line → "foundation lock-step ($core_v) + ranged intra-repo deps across 10 release packages + koel_lints dev-only" (pure-string change, gate re-run OK, format:check 0-changed). [tool/verify_versioning.sh:72]

## Dev Notes

### Locked decisions

- **D1 — Three re-exports; `koel_widgets` EXCLUDED (locked, not stale).** Architecture §2 (architecture.md:512–514) is explicit: *"Meta-package `koel`: re-exports `koel_core` + `koel_http` + `koel_flutter` only. Does not re-export … `koel_widgets` / `koel_devtools` / `koel_test`."* The epic AC ("exactly three") + the SCP-2026-06-06-B resequence note ("re-exports just core/http/flutter") agree. The widget layer (Material 3 + Cupertino) is opinionated UI — consumers opt into it with a direct `koel_widgets` dep. **FYI → Story 9.2:** its sample app uses `MessageBubble` + `ChatInput`, so 9.2's `example/pubspec.yaml` MUST declare `koel_widgets` **in addition to** `koel` (the meta-barrel does not surface widget symbols). This is by design, not a gap.

- **D2 — Version bump to `1.0.0` is REQUIRED now, not deferrable to 9.9 (proven empirically).** A pub workspace fails `version solving` when a member declares `^1.0.0` on a sibling still at `0.0.1`. Verified on this machine (Dart 3.12.0 stable):
  - `pkg_b → pkg_a: ^1.0.0` with `pkg_a` at `0.0.1` ⇒ `Because pkg_b depends on pkg_a ^1.0.0 … version solving failed.`
  - Bump `pkg_a → 1.0.0` ⇒ `Got dependencies!`
  - A **bare** key (`pkg_a:`) resolves against a `1.0.0` sibling ⇒ `Got dependencies!` (this is why `koel_devtools` may keep bare keys at `0.0.1`).
  AC3 independently mandates `core`/`http`/`lints` = `1.0.0`. The meta's `koel_flutter: ^1.0.0` forces `koel_flutter` ≥ `1.0.0`; `koel_widgets`'s `koel_flutter: ^1.0.0` likewise; the dev `koel_test: ^1.0.0`/`koel_lints: ^1.0.0` edges force those ≥ `1.0.0`. The coherent, AC-satisfying result is the whole ten-package release set at a uniform `1.0.0`. `publish_to: none` stays — `version: 1.0.0` is just metadata until 9.9 removes the marker and publishes; the version still gates in-workspace range satisfaction.

- **D3 — Range-swap blast radius is the full ten-set, runtime AND dev (so the assert passes uniformly).** The convention-assert (Task 5) rejects bare keys; for it to pass, every intra-repo edge in the release set must be `^1.0.0`. Hence dev-dependency edges (`koel_lints`, `koel_test`) are swapped too — they already resolve at `1.0.0`. `koel_lints` stays a **dev** dependency everywhere (AC2/FR-H3 — it is an analyzer profile, consumed via `analysis_options.yaml`, never imported). Exact edges in the Task 4 table.

- **D4 — `koel` becomes a Flutter package.** Re-exporting `package:koel_flutter/koel_flutter.dart` makes `koel` transitively depend on the Flutter SDK ⇒ resolve with `flutter pub get`/`melos bootstrap` (already flutter-aware: the workspace contains `koel_flutter`/`koel_widgets`). Add `environment: flutter: ">=3.38.0"` (honest classification + pub.dev Flutter detection). **No** direct `flutter: sdk: flutter` dependency — `koel`'s own `lib/koel.dart` imports no Flutter symbols (it only re-exports); the SDK arrives transitively. The barrel test (Task 6) needs `flutter_test` because it references `KoelChatController` (a `ChangeNotifier`, framework type).

- **D5 — Convention-assert lives in `ci.yml`, bash, zero new dep.** `publish-dry-run.yml` is a placeholder owned by Story 9.5; do not pre-empt it. `analyze-test` in `ci.yml` runs on every PR + push to main, and green main is the publish precondition (R-5), so an assert there satisfies "before each publish." Bash+grep mirrors the existing `tool/*.sh` gates and adds no hosted dependency (preserving the zero-new-dep streak). If a future maintainer prefers Dart for robust YAML parsing, note that `package:yaml` would land in root `dev_dependencies` and is AI-5.9-inert (pure Dart, no analyzer edge) — but bash is the house default here.

### Current state of files being modified (read before editing)

- [packages/koel/lib/koel.dart](packages/koel/lib/koel.dart): an **empty** `library;` stub with a doc comment — no exports yet. Task 1 fills it.
- [packages/koel/pubspec.yaml](packages/koel/pubspec.yaml): `version: 0.0.1`, `publish_to: none`, `resolution: workspace`, `environment: sdk` only (no flutter), and **only** `dev_dependencies: koel_lints:` (bare) — **no runtime deps today**. Task 2 wires the three runtime re-exports + flutter env + version + lints range.
- [packages/koel/README.md](packages/koel/README.md): already describes the 3-package re-export quickstart correctly; only the "finalized in Epic 9 …" forward-reference line is stale (Task 8).
- Foundation + dependent pubspecs: all `version: 0.0.1`, `resolution: workspace`, bare intra-repo keys (e.g. `koel_core:`). See the Task 4 table for the precise set of keys per package.
- [.github/workflows/ci.yml](.github/workflows/ci.yml): `analyze-test` job runs `melos bootstrap` → `melos run build` → `analyze` → `format:check` → `test` on ubuntu+macos. Add the `verify:versioning` step here.
- Root [pubspec.yaml](pubspec.yaml): `workspace:` lists every member (incl. `packages/koel_widgets/example`); `melos.scripts:` lives here (Melos 7.x reads scripts from `pubspec.yaml`, not `melos.yaml`). Add `verify:versioning` to `melos.scripts`.

### What must keep working (regression guards)

- **Workspace resolution stays green.** `melos bootstrap` must succeed after the bumps; a forgotten bump surfaces as `version solving failed` (Task 7 catches it).
- **AI-5.9 pins held.** `analyzer 12.1.0` / `freezed 3.2.6-dev.1` must not drift in the root `pubspec.lock` (SCP-2026-05-29-B; held every story since). These edits add no hosted dependency, so lock churn should be limited to version-string updates of workspace members.
- **`koel_devtools` and `koel_widgets/example` stay untouched** — bare keys at `0.0.1`. Touching them would pull devtools into the v1.0.0 lock-step (wrong, per SCP-2026-06-06-B) or break the example's dev resolution.
- **Committed `.api-baseline/*.json` are NOT regenerated here.** They freeze API *surface*, not version; bumping `version:` doesn't invalidate them. `dart_apitool` baselines/gate are Story 9.3.

### Scope boundaries (explicitly OUT of 9.1)

- Removing `publish_to: none` and `pub publish --dry-run` → **Story 9.5**.
- `melos publish` orchestration, mirrored `CHANGELOG` 1.0.0 entries, `CONFORMANCE.md` SHA pin → **Story 9.9**.
- `dart_apitool` wiring / `api-diff.yml` → **Story 9.3**. Perf artifacts / `BENCHMARKS.md` → **Story 9.4**.
- The repo-root `example/` sample app + its `flutter build` matrix → **Story 9.2** (do not create it here).
- README/docs polish to the §13 D-1 bar across all packages → **Story 9.6** (9.1 only un-stales the one koel meta line).

### Testing standards

- `koel`'s barrel test runs under `flutter test` (D4). The whole-workspace gate is `melos run test` via `tool/test_package.sh`, which routes `sdk: flutter` packages to `flutter test` (AI-6.2 anchor) and tolerates exit-79 (no tests) — so `koel` flips to the flutter lane automatically once `flutter_test` + a test file exist.
- Keep the barrel test minimal: its job is to prove the three re-exports resolve at compile time, not to re-test the re-exported packages' behavior.

### Project Structure Notes

- Matches architecture.md:993–1000 — `packages/koel/` = `pubspec.yaml` + `README.md` + `lib/koel.dart` ("one barrel: 3 re-exports, ~5 LOC total"). Task 6 adds a `test/` dir (consistent with every other package's `test/` mirror). No structural variance.
- The ten-package v1.0.0 release set = `koel`, `koel_core`, `koel_http`, `koel_lints`, `koel_test`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`. `koel_devtools` is the 11th, deferred to Epic 10.

### References

- [Source: epics/epic-9-meta-package-sample-app-v100-release-gates.md#Story 9.1] — AC1–AC4 verbatim; resequence note (lines 5–12).
- [Source: architecture.md#2. Public/private discipline (lines 503–514)] — barrel hygiene; meta re-exports core+http+flutter only, NOT widgets.
- [Source: architecture.md#koel meta-package — re-exports only (lines 993–1000)] — package layout, "3 re-exports, ~5 LOC".
- [Source: prds/prd-koel-2026-05-27/prd.md#12. Release & Versioning (R-1..R-5)] — lock-step foundations (R-2), ranged dependents (R-3), green-gates-before-v1 (R-5).
- [Source: prds/prd-koel-2026-05-27/prd.md#Group H — F-H2 Hybrid Versioning] — `^X.Y.0` ranges; sealed-subtype minor-bump safety via `koel_lints` default-branch rule.
- [Source: sprint-change-proposal-2026-06-06-B.md] — Epic 9 resequenced ahead of DevTools; ten-package release set; koel_devtools → Epic 10.
- [Source: sprint-change-proposal-2026-05-29-analyzer12-freezed.md] — AI-5.9 pins (analyzer 12.1.0 / freezed 3.2.6-dev.1).
- Empirical: pub workspace `^1.0.0`-vs-`0.0.1` solving test (Dart 3.12.0 stable) — documented in D2.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Flutter Engineer persona — `/agent-flutter-engineer`)

### Debug Log References

- `melos bootstrap` → SUCCESS (12 packages; flutter-aware `flutter pub get`). The green resolution empirically validates D2/D3 — every `^1.0.0` edge is satisfied because the targeted sibling is now `1.0.0`.
- `git diff pubspec.lock` → **0 drift**. AI-5.9 pins held: `analyzer 12.1.0`, `freezed 3.2.6-dev.1`. No hosted dep added; range/version edits resolve via intra-workspace paths, so the lock is byte-identical.
- Per-package `dart analyze` (12 pkgs, run **sequentially**) → all "No issues found!", incl. `koel` (barrel resolves all three re-exports) + `koel_widgets/example`. NOTE: `melos exec -- dart analyze .` crashed the analysis_server_plugin under parallel fan-out (`Bad state: analysis server crashed`) — an environment resource limit on 12 concurrent asp servers, NOT a code defect; sequential runs are clean. CI's `melos run analyze` runs on hosted runners where this does not reproduce.
- `bash tool/verify_versioning.sh` → OK (10 release pkgs lock-step `1.0.0` + ranged intra-repo deps + koel_lints dev-only). Negative-tested: a bare key and a tight `1.0.0` pin both correctly trip exit 1.
- `bash tool/format.sh check` → 210 files, **0 changed**.
- Test sweep (per-package `tool/test_package.sh`, mirrors `melos run test`): koel **+1**, koel_core +590, koel_http +99, koel_lints +5, koel_test +81, koel_agno +38, koel_langgraph +44, koel_runtime +34, koel_flutter +74, koel_widgets +42; koel_devtools no-tests (tolerated). All SUCCESS.
- Harness note: `melos run <script>` (the `build`/`analyze`/`test` wrappers) crashes on this non-TTY shell via `Stdin.echoMode` (melos package-picker prompt). Worked around by invoking the underlying tool/script directly (`build_runner` per codegen pkg, `dart analyze` per pkg, `tool/*.sh`) — identical gate bodies. Unaffected on CI (TTY-less but CI-detected).

### Completion Notes List

- **AC1** — `packages/koel/lib/koel.dart` is exactly 6 LOC (doc header + `library;` + blank + 3 `export` lines): `koel_core`, `koel_http`, `koel_flutter`. No `koel_widgets`/`koel_test`/adapters/`koel_lints` re-export (D1 — architecture §2:512–514).
- **AC2** — `packages/koel/pubspec.yaml` declares `koel_core: ^1.0.0`, `koel_http: ^1.0.0`, `koel_flutter: ^1.0.0` under `dependencies:`; `koel_lints: ^1.0.0` stays a `dev_dependency` (never runtime). Added `environment: flutter: ">=3.38.0"` (D4 — barrel re-exports koel_flutter ⇒ koel is a Flutter package) with NO direct `flutter: sdk: flutter` dep (koel's source imports zero Flutter symbols). Version `0.0.1 → 1.0.0`; `publish_to: none` retained (publish wiring → 9.5/9.9).
- **AC3** — `koel_core` / `koel_http` / `koel_lints` all carry identical `version: 1.0.0` (foundation lock-step, R-2).
- **AC4** — every release-set package declares `^1.0.0` (not pinned, not bare) on each foundation it depends on (Task 4 table, runtime + dev). `tool/verify_versioning.sh` (bash + awk, zero new dep) asserts the convention and is wired into the `analyze-test` job of `ci.yml` (always-on per-PR gate) + a `verify:versioning` melos script.
- **D2 confirmed live** — the whole ten-package release set is now uniform `1.0.0`; `koel_devtools` stays `0.0.1` with bare keys (untouched, Epic 10) and `koel_widgets/example` stays bare/`0.0.1` (untouched, not in release set). Both excluded from `verify_versioning.sh`.
- **Barrel test (Task 6)** — `packages/koel/test/koel_barrel_test.dart` imports only `package:koel/koel.dart` and builds the real three-layer chain `HttpAgent → KoelClient → newSession() → KoelChatController`, naming one public symbol per re-exported package so a dropped export fails to **compile**. Runs under `flutter test` (D4), auto-detected by `tool/test_package.sh` via the `sdk: flutter` anchor (AI-6.2). Teardowns ordered LIFO so the controller (cancels its session sub) tears down before the client (owns session disposal).
- **Scope held** — no `publish_to` removal, no `dart_apitool`/`.api-baseline` regeneration, no perf/docs/sample-app work (all → 9.2–9.9 per Scope). `koel`'s real `url:` ctor param (not the README's illustrative `endpoint:`) used in the barrel test.

### File List

- `packages/koel/lib/koel.dart` (modified — 3-export barrel)
- `packages/koel/pubspec.yaml` (modified — runtime deps, flutter env, version 1.0.0, lints range, flutter_test dev-dep)
- `packages/koel/README.md` (modified — removed stale "finalized in Epic 9" line)
- `packages/koel/test/koel_barrel_test.dart` (new — barrel-resolve compile-time test)
- `packages/koel_core/pubspec.yaml` (modified — version 1.0.0, koel_lints ^1.0.0)
- `packages/koel_http/pubspec.yaml` (modified — version 1.0.0, koel_core/koel_lints/koel_test ^1.0.0)
- `packages/koel_lints/pubspec.yaml` (modified — version 1.0.0)
- `packages/koel_test/pubspec.yaml` (modified — version 1.0.0, koel_core/koel_lints ^1.0.0)
- `packages/koel_agno/pubspec.yaml` (modified — version 1.0.0, koel_core/koel_http/koel_lints/koel_test ^1.0.0)
- `packages/koel_langgraph/pubspec.yaml` (modified — version 1.0.0, koel_core/koel_http/koel_lints/koel_test ^1.0.0)
- `packages/koel_runtime/pubspec.yaml` (modified — version 1.0.0, koel_core/koel_http/koel_lints/koel_test ^1.0.0)
- `packages/koel_flutter/pubspec.yaml` (modified — version 1.0.0, koel_core/koel_lints/koel_test ^1.0.0)
- `packages/koel_widgets/pubspec.yaml` (modified — version 1.0.0, koel_core/koel_flutter/koel_lints ^1.0.0)
- `tool/verify_versioning.sh` (new — hybrid-versioning convention gate)
- `pubspec.yaml` (modified — `verify:versioning` melos script)
- `.github/workflows/ci.yml` (modified — `verify:versioning` step in analyze-test job)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified — 9-1 → in-progress → review)

## Change Log

| Date | Version | Description |
|---|---|---|
| 2026-06-06 | 1.0.0 | Story 9.1 implemented — `koel` 3-export meta-barrel + ten-package hybrid-versioning convention (uniform `1.0.0`, ranged intra-repo deps), `verify_versioning.sh` gate wired into CI, barrel-resolve test. All gates green (bootstrap, analyze, verify:versioning, format:check, test); pubspec.lock 0-drift, AI-5.9 pins held. Status → review. |
| 2026-06-06 | 1.0.1 | Code review (3-layer adversarial) → **done**. 0 decision-needed, 1 patch, 0 defer, 12 dismissed. Patch: reworded `verify_versioning.sh` success line — it overclaimed "10 release packages lock-step" while only the 3 foundations are version-compared (pure-string change; gate re-run OK, format:check 210/0-changed, analyze/test inert). Auditor confirmed 0 AC violations + no scope-creep. |
