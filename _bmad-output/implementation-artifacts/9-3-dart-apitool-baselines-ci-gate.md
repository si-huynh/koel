---
baseline_commit: c15227912f106a32c8271eef3987d4029bafa5a6
---

# Story 9.3: `dart_apitool` wiring + per-package baseline + CI gate

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a release manager,
I want `dart_apitool: ^0.23.1` wired in `api-diff.yml` extracting an API surface per package and diffing against the committed v1.x baseline,
so that NFR-14 (zero breaking changes after 1.0.0) is mechanically enforced per AR-12 + D7.

## Context — third story of Epic 9 (the breaking-change gate)

Story 9.1 sealed the `koel` meta-barrel + ten-package hybrid-versioning convention; Story 9.2 shipped the repo-root `example/` and kept the `koel_widgets` public surface **deliberately frozen** "precisely so 9.3 owns the gate" (9.2 D5). **9.3 stands up that gate** — the `dart_apitool` per-package API-surface diff that makes NFR-14 (zero breaking changes to the 1.x surface) a mechanical CI block, not a review convention.

Three pieces ship together: **(a)** `tool/verify_api_surface.dart` — the wrapper architecture.md:736 names, orchestrating `dart_apitool` extract + diff per package; **(b)** a **complete, self-consistent baseline set** at `packages/<pkg>/.api-baseline/<pkg>.json` — today only 3 of the 9 surface-bearing packages have a baseline (one of them **stale**), so this story regenerates all of them through the pinned wrapper and fills the 6 gaps; **(c)** the real `api-diff.yml` body (currently an Epic-1 `echo "Wired in Epic 9"` placeholder) + a `melos run api-diff` script (architecture.md:1129).

**Scope frame:** this is **tooling + CI**, not a library change. It adds **no new public symbol** and **no new workspace dependency** — `dart_apitool` is a *global* activation (its own pubspec, isolated from the AI-5.9 analyzer-12/freezed pins), exactly as the 2.15 / 6.8 / 7.4 baseline extractions already proved. The only `lib/` churn is whatever the regenerated baselines capture as the v1.0.0 truth (notably the `koel_core` `Context` retype already shipped in Story 2.16 — see D2).

## Acceptance Criteria

**AC1 — `tool/verify_api_surface.dart` wraps `dart_apitool` per package + writes per-package baselines.**
**Given** `tool/verify_api_surface.dart`, **when** I inspect it, **then** it wraps `dart_apitool` per package (extract a package's public API surface; diff a current extract against a committed baseline) and writes/refreshes per-package baselines at **`packages/<pkg>/.api-baseline/<pkg>.json`** (the established 2.15/6.8/7.4 convention — see **D1**; this story's path of record overrides the epic AC's loose `_bmad-output/api-baselines/<package>-<version>.json` wording, which no prior story implemented), **and** it covers the **9 surface-bearing release packages** (`koel`, `koel_core`, `koel_http`, `koel_test`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`), explicitly **excluding `koel_lints`** which ships no Dart public API (see **D4**).

**AC2 — `api-diff.yml` runs the per-package diff on every PR; breaking blocks merge, additions warn.**
**Given** `.github/workflows/api-diff.yml` (now complete from the Story 1.5 skeleton), **when** the workflow runs on every PR + push to main, **then** it extracts each package's current public surface + diffs against the committed `.api-baseline/<pkg>.json`, **and** any **breaking** change (symbol removal, signature/type change, required-param addition) blocks merge with a clear diff surfaced in the job log/PR, **and** **additive** changes (new public symbols) pass through with a **warning** logged (not a failure), per AR-12 / NFR-14.

**AC3 — v1.x baseline set captured + committed for every surface-bearing package.**
**Given** baseline capture, **when** this story runs, **then** the baseline JSON files are committed under `packages/<pkg>/.api-baseline/` for **every** surface-bearing package — all regenerated through the **same pinned `dart_apitool 0.23.1`** via the new wrapper so the committed set is mutually self-consistent (identical tool-version + entry ordering ⇒ the AC2 diff produces zero spurious churn — see **D2**, **D3**), **and** the design supports refreshing a baseline as a separate, reviewable PR step on subsequent v1.x publishes (the `--update` mode, consumed at v1.0.0 publish in Story 9.9).

## Tasks / Subtasks

> Run all Flutter/Dart work under the `/agent-flutter-engineer` persona (CLAUDE.md mandate). This story is tooling/CI; the persona still governs the Dart in `tool/verify_api_surface.dart`.

- [x] **Task 0 — Verify the `dart_apitool 0.23.1` CLI surface before writing the wrapper** (AC1, D7) — **do this first; don't assume the flag shape.**
  - [x] `dart pub global activate dart_apitool 0.23.1` (global → its own pubspec; the AI-5.9 analyzer-12/freezed workspace pins do NOT constrain it — proven by 2.15/6.8/7.4). Confirm the executable name on PATH (`dart-apitool` vs `dart pub global run dart_apitool`).
  - [x] Capture `dart-apitool extract --help` and `dart-apitool diff --help` for **0.23.1 specifically** (the CLI has shifted across minors). Record the exact flags for: (a) extracting a local package dir to a JSON file, (b) diffing a stored baseline JSON against a current local package, (c) the report format + the **exit-code / breaking-vs-non-breaking** semantics (how the tool signals a breaking change vs an addition). Project rule: *confirmed needs adversarial evidence* — wire the wrapper to what the help text actually says, not to the assumed shape in D7.
  - [x] Confirm extraction works on a **Flutter** package (`koel_flutter` or `koel_widgets`) with **no `--force-use-flutter`** flag (6.8/7.4 proved this on SDK 3.12 — re-confirm on the current toolchain). If 0.23.1 now needs a flag for Flutter packages, record it and use it in Task 3's CI job.

- [x] **Task 1 — Write `tool/verify_api_surface.dart`: the per-package wrapper** (AC1, AC2, AC3, D1, D3, D4, D6, D7)
  - [x] Create `tool/verify_api_surface.dart` (repo-root `tool/`, sibling of `capture_fixtures.dart` — architecture.md:736). It runs under the **workspace pub** (`dart run tool/verify_api_surface.dart`), so it **must NOT import `package:dart_apitool`** (that package pulls a recent analyzer incompatible with the pinned analyzer 12.1.0 / AI-5.9). Instead it **shells out** (`dart:io` `Process.run`) to the **globally-activated `dart-apitool` CLI** (D3). Zero new workspace dependency — pure `dart:io` + `dart:convert`, mirroring how `tool/capture_fixtures.dart` is structured.
  - [x] Hard-code the surface-bearing package list (D4): `koel`, `koel_core`, `koel_http`, `koel_test`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`. **Exclude `koel_lints`** (no Dart barrel — `lib/koel.yaml` + `lib/koel_flutter.yaml` analysis profiles + the asp plugin `lib/main.dart`; nothing for `dart_apitool` to extract). Excluded packages must be **named in a comment** with the reason (memory: *no silent caps* — a reader must see koel_lints was deliberately skipped, not forgotten).
  - [x] Two modes (behaviors are the contract; flag names are dev latitude — but honor the epic AC's `--extract` wording where natural):
    - **Diff / verify mode (default, the CI gate):** per package, extract the current surface to a temp JSON, then `dart-apitool diff` it against the committed `packages/<pkg>/.api-baseline/<pkg>.json`. A **breaking** delta → record it and exit **non-zero** with a clear per-package report (which package, which symbol, what changed). An **additive** delta (new public symbol) → log a **warning** and keep going (does NOT fail) per AC2. A missing baseline for a listed package → fail with "run --update first" (don't silently pass).
    - **Update / capture mode (`--update`):** per package, extract + overwrite the committed `packages/<pkg>/.api-baseline/<pkg>.json`. This is what Task 2 runs now and what Story 9.9 reruns at publish.
  - [x] **Pin the tool version inside the wrapper** — assert (or document at the top) that the global `dart-apitool` is `0.23.1`; a version drift silently reshapes the JSON (entry ordering, `version:` field) and corrupts diffs (the deferred-work.md:441 churn warning). If feasible, the wrapper checks `dart-apitool --version` and fails fast on a mismatch.
  - [x] Keep the output **deterministic + reviewable**: the committed baseline JSON should be stable across reruns of the same tool version (the `packagePath` field in the current baselines is an absolute temp path like `/tmp/claude-501/aaqBxf` — if 0.23.1 still emits a machine-specific path, normalize/strip it in the wrapper so re-extraction on a different machine/CI doesn't produce a spurious diff. Verify whether 0.23.1's extract embeds an absolute path; if so, neutralize it).

- [x] **Task 2 — Regenerate the full baseline set through the wrapper** (AC1, AC3, D1, D2)
  - [x] Run `dart run tool/verify_api_surface.dart --update` (or `melos run api-diff -- --update` once Task 4 wires the script). This produces a baseline for **all 9** surface-bearing packages in one consistent pass.
  - [x] **Regenerate the 3 existing baselines too** (`koel_core`, `koel_flutter`, `koel_widgets`) — do NOT preserve their old bytes. They were extracted at three different sealing times; regenerating all 9 through the single pinned wrapper is what makes the AC2 diff clean (D2). Expect:
    - **`koel_core`**: the regenerated surface now includes the `Context` symbol and `RunAgentInput.context: List<Context>` (Story 2.16 shipped this; the committed baseline is **stale** — `grep '"name": "Context"'` → 0 hits, `context` still typed `Map<String, dynamic>`, per deferred-work.md:441). This is the intended capture of current v1.0.0 truth, **not** a regression — the change is already in `lib/`. Sanity-check the regenerated `koel_core` baseline DOES contain `Context` and the `List<Context>` typing.
    - **`koel_flutter` / `koel_widgets`**: surfaces are frozen (11 / 8 symbols). The regenerated baselines should differ from the old only in tool-run incidentals (ordering / `packagePath`), not in the symbol set. Confirm the symbol set is unchanged.
  - [x] **Create the 6 missing baselines**: `koel` (meta — the re-export surface = the union of `koel_core` + `koel_http` + `koel_flutter`; confirm `dart_apitool` follows the `export` re-exports and emits a non-empty surface), `koel_http`, `koel_test`, `koel_agno`, `koel_langgraph`, `koel_runtime`. Each barrel is already final (Epics 2/4/5). Commit each `packages/<pkg>/.api-baseline/<pkg>.json`.
  - [x] If extraction **fails** for any package (verify, don't assume — meta-package re-export following, or an adapter package's transitive Flutter/HTTP deps may trip 0.23.1): capture the **exact** error, do NOT fabricate a baseline, and either fix the invocation (Task 0 flags) or — if genuinely blocked — record a precise hand-off in `deferred-work.md` and surface the blocker to Si with the exact failure (memory: *own gate failures, no blame*; *confirmed needs adversarial evidence*).

- [x] **Task 3 — Wire `.github/workflows/api-diff.yml`** (AC2, D3, D5)
  - [x] Replace the placeholder body. Single job, `ubuntu-latest`. Because two packages (`koel_flutter`, `koel_widgets`) pull the Flutter SDK, the job needs **`flutter` on PATH** to extract them (D5): use **`subosito/flutter-action@v2`** (`channel: stable`, `flutter-version: 3.44.0`, `cache: true` — the `.tool-versions` pin, identical to ci.yml's `flutter-smoke`/`example-build` lanes; it provides both `dart` and `flutter`). Then `dart pub global activate dart_apitool 0.23.1`, `dart pub global activate melos 7.8.0`, `melos bootstrap`, `melos run build` (codegen for `koel_core`'s `*.freezed.dart` so the surface extracts cleanly — mirror codegen-drift.yml / example-build).
  - [x] Run the gate: `melos run api-diff` (Task 4) — i.e. `dart run tool/verify_api_surface.dart` in **diff mode**. Breaking → non-zero exit blocks the PR; the per-package report is visible in the job log. (PR-comment posting is a nice-to-have; the **merge block** is the required mechanism — a failed required check already blocks. If a clean inline PR comment is cheap, add it; otherwise the failing log satisfies "clear diff" — note the choice.)
  - [x] Update the top-of-file banner comment to describe the real body + its origin (Story 9.3), matching the codebase convention (every workflow documents each lane's origin story — see ci.yml's banner, codegen-drift.yml's header).
  - [x] Keep `on:` = PR + push to main (the skeleton already has this). **Do NOT touch** `perf-bench.yml` (Story 9.4), `conformance.yml` / `publish-dry-run.yml` (Story 9.5), or `ci.yml`.

- [x] **Task 4 — Add the `melos run api-diff` script** (AC2, architecture.md:1129)
  - [x] In the root `pubspec.yaml` `melos.scripts:` block (the registry — melos 7 reads scripts from `pubspec.yaml > melos.scripts`, NOT `melos.yaml`), add an `api-diff` script mirroring the existing `verify:versioning` / `conformance` entries: a one-line `description:` + `run: dart run "$MELOS_ROOT_PATH/tool/verify_api_surface.dart"`. Document that `--update` refreshes baselines and the default verifies (matches architecture.md:1129 "`melos run api-diff` runs `dart_apitool` per package").
  - [x] Confirm the script is discoverable: `melos run --help` (or the script list) shows `api-diff`.

- [x] **Task 5 — Gate verification** (all ACs)
  - [x] `git diff pubspec.lock` (root) → **0 drift**. `dart_apitool` is a **global** activation, never a workspace dep; AI-5.9 pins (`analyzer 12.1.0` / `freezed 3.2.6-dev.1`) MUST NOT move (SCP-2026-05-29-B). The only `pubspec.yaml` edit is the melos `api-diff` script line (no dependency change).
  - [x] `melos run api-diff` (diff mode) on the freshly-regenerated baselines → **green** (current surface == committed baseline for all 9; zero diff because Task 2 just captured them with the same tool). This proves the gate is wired correctly and self-consistent.
  - [x] **Negative check (prove the gate bites):** temporarily add a throwaway public symbol to one barrel (e.g. `koel_core`) → `melos run api-diff` logs an **additive warning** but exits **0**; then temporarily remove/retype an existing public symbol → it exits **non-zero** (breaking). Revert both. Record the observed behavior in the Dev Agent Record (memory: a gate that can't fail is a silent no-op — codegen-drift.yml's retro-D1 lesson).
  - [x] `melos run analyze` (all pkgs + asp plugin) clean — the new `tool/verify_api_surface.dart` is under `tool/` (not a melos package); analyze it directly via `dart analyze tool/verify_api_surface.dart` (or confirm `tool/` is swept). NOTE (9.1/9.2 harness finding): `melos exec` parallel fan-out can crash the asp plugin on this machine (env resource limit, not a code defect) — run per-package `dart analyze` sequentially if so.
  - [x] `dart format` the new `tool/verify_api_surface.dart` (note: `tool/format.sh` formats `packages/` only — the repo-root `tool/` Dart is checked by `dart format --set-exit-if-changed` directly, like `example/` in 9.2; ensure the file is formatted so no future format gate trips).
  - [x] `melos run test` SUCCESS (unchanged — this story adds no library test; existing suites stay green) + `melos run format:check` 0-changed. `melos run verify:versioning` still green (no release-set change).

## Dev Notes

### Locked decisions

- **D1 — Baseline path = `packages/<pkg>/.api-baseline/<pkg>.json`, NOT the epic AC's `_bmad-output/api-baselines/<package>-<version>.json`.** *(Parity/consistency decides — FYI→Si.)* The epic AC1 names `_bmad-output/api-baselines/<package>-<version>.json`, but **no prior story implemented that path**. Stories 2.15, 6.8, and 7.4 each extracted to and committed `packages/<pkg>/.api-baseline/<pkg>.json`, and the 2.15 hand-off (deferred-work.md:277) explicitly records this as "the exact path Epic 9 `9-3` must diff against." Three baselines already live there. Moving them + breaking the documented, three-times-established convention to satisfy the epic's loose phrasing is the wrong trade — the convention is the source of truth (memory: *parity decides ambiguous API calls*; the implemented reality beats the planning-doc's casual path). Keep per-package `.api-baseline/<pkg>.json`. (If Si later wants a flat `_bmad-output/api-baselines/` mirror for release-artifact convenience, that's a deliberate add in 9.9, not a churn of three sealed baselines here.)

- **D2 — Regenerate ALL 9 baselines through the single pinned wrapper; do not preserve old bytes.** The 3 existing baselines were each extracted at a different sealing time (2.15, 6.8, 7.4). `koel_core`'s is additionally **stale** (Story 2.16 retyped `RunAgentInput.context` → `List<Context>` + added the `Context` symbol; deferred-work.md:441 flagged the sealed snapshot no longer matches and told 9-3 to "pin the tool version and regenerate … so the `Context`/`context` change lands as a clean, reviewable diff"). Regenerating all 9 through one `dart_apitool 0.23.1` run via `tool/verify_api_surface.dart` makes the committed set **mutually self-consistent** — identical tool-version + entry ordering — so the AC2 diff (same tool, same wrapper) yields **zero spurious churn** and only genuine semantic deltas ever fail. The regenerated `koel_core` surface captures the `Context` change as the **v1.0.0 truth** (it's already in `lib/` — not a regression; the "clean reviewable diff" is the baseline-update diff in *this* PR: old sealed snapshot → new pinned-tool snapshot). `koel_flutter`/`koel_widgets` symbol sets must be unchanged (only incidentals differ).

- **D3 — `tool/verify_api_surface.dart` shells out to the GLOBAL `dart-apitool` CLI; it never imports `package:dart_apitool`.** `dart_apitool` depends on a recent `analyzer` that conflicts with the workspace's pinned `analyzer 12.1.0` (AI-5.9 / SCP-2026-05-29-B). The wrapper runs under the workspace pub solve (`dart run tool/...`), so importing the package would either fail to resolve or force an analyzer bump — both forbidden. All three prior baseline gens used `dart pub global activate dart_apitool 0.23.1` (global activation carries its **own** pubspec, fully isolated from the workspace hold). The wrapper therefore `Process.run`s the globally-activated `dart-apitool` binary — pure `dart:io`, zero workspace dependency, `pubspec.lock` 0-drift. This is the only design consistent with the AI-5.9 pins.

- **D4 — `koel_lints` is EXCLUDED from the gate (no Dart public API).** `koel_lints` ships analysis-profile YAML (`lib/koel.yaml`, `lib/koel_flutter.yaml`) + the `analysis_server_plugin` bootstrap (`lib/main.dart`) + internal rules under `lib/src/rules/`. There is **no `lib/koel_lints.dart` barrel** and no consumable Dart symbol surface — `dart_apitool` would extract nothing meaningful (or error). Its "contract" is the lint profile, version-gated by `verify:versioning` (9.1), not by API diff. The gate covers the **9** surface-bearing release packages; `koel_lints` is named-and-skipped in the wrapper's package list (no silent omission). The release set stays **ten** packages (9.1) — this is purely about which have a *Dart* surface to diff.

- **D5 — The `api-diff.yml` job needs Flutter on PATH (for `koel_flutter` + `koel_widgets`).** Those two packages pull the Flutter SDK; extracting their surface needs `flutter` available. 6.8/7.4 proved `dart_apitool 0.23.1` extracts a Flutter package with **no `--force-use-flutter`** on SDK 3.12 — re-confirm on the current toolchain (Task 0). Use `subosito/flutter-action@v2` (channel stable, `flutter-version: 3.44.0`, `cache: true`) — the `.tool-versions` pin used by ci.yml's `flutter-smoke`/`example-build` lanes; it provides both `dart` and `flutter`, so all 9 packages extract in one ubuntu job. Then global-activate `dart_apitool 0.23.1` + `melos` and `melos run build` before the gate (codegen first, mirroring codegen-drift.yml).

- **D6 — Pre-1.0 the gate diffs against the COMMITTED in-repo baseline, not a pub.dev-published version.** Nothing is published yet (`publish_to:` is still `none` until 9.9). The epic AC's "published v1.x.y baseline" becomes literal only **post-1.0**: at the v1.0.0 publish (Story 9.9) the committed `.api-baseline/<pkg>.json` files **are** the published surface, and the AC's "subsequent v1.x publishes update the baseline as a separate PR step" = a `--update` run reviewed in its own PR. So 9.3's gate contract is precise: **current extract vs the committed baseline**, breaking→block / additive→warn. Don't try to fetch from pub.dev — there's nothing there.

- **D7 — `dart_apitool 0.23.1` CLI flag shape is VERIFY-don't-assume (Task 0 gates Task 1).** The most-likely 0.23.1 invocations are `dart-apitool extract --input <pkg-dir> --output <baseline.json>` and `dart-apitool diff --old <baseline.json|ref> --new <pkg-dir>` with a report/exit-code controlling breaking-vs-additive — **but the CLI has shifted across minors**, so capture `extract --help` / `diff --help` for 0.23.1 specifically and wire to the actual flags (incl. how the tool signals breaking vs non-breaking, and whether a stored JSON baseline is passed as `--old <file>` vs a package ref). Project rule: *confirmed needs adversarial evidence* — don't hard-code the assumed shape; prove it. The current baselines embed an absolute `packagePath` (`/tmp/claude-501/aaqBxf`) — check whether 0.23.1's extract still does and, if so, normalize it in the wrapper so re-extraction on CI/another machine isn't a spurious diff.

### Current state of files being modified/created (read before editing)

- **`tool/verify_api_surface.dart`** — **does NOT exist** (architecture.md:736 names it; this story creates it). Model its structure on `tool/capture_fixtures.dart` (the only existing repo-root Dart orchestrator: `dart:io` `Process.run`, arg parsing, no exotic deps). It runs via `dart run "$MELOS_ROOT_PATH/tool/verify_api_surface.dart"` like `capture_fixtures.dart` does (root `pubspec.yaml` melos `capture-fixtures` script).
- **`.github/workflows/api-diff.yml`** — current body is the Story 1.5 placeholder (`placeholder` job, `run: echo "Wired in Epic 9"`). Banner already says "dart_apitool public-surface diff per package against published baseline (D7 / N-14)". Replace the job; mirror codegen-drift.yml (setup, melos bootstrap, melos run build) + example-build (flutter-action). [Source: .github/workflows/api-diff.yml, codegen-drift.yml, ci.yml example-build]
- **`packages/koel_core/.api-baseline/koel_core.json`** — **STALE** (907 KB; `Context` absent, `context: Map<String, dynamic>`). Regenerate (D2). [Source: deferred-work.md:441]
- **`packages/koel_flutter/.api-baseline/koel_flutter.json`** (35 KB, 11 symbols) + **`packages/koel_widgets/.api-baseline/koel_widgets.json`** (51 KB, 8 symbols) — current; regenerate through the wrapper but the **symbol set must not change** (D2).
- **6 packages with NO baseline yet**: `koel` (meta-barrel re-exporting core+http+flutter), `koel_http`, `koel_test`, `koel_agno`, `koel_langgraph`, `koel_runtime` — barrels all final from Epics 2/4/5. Create their baselines.
- **Root `pubspec.yaml`** — `melos.scripts:` block holds `analyze`/`test`/`test:coverage`/`build`/`format`/`format:check`/`conformance`/`verify:versioning`/`capture-fixtures`. Add `api-diff` in the same shape (`description:` + `run: dart run "$MELOS_ROOT_PATH/tool/verify_api_surface.dart"`). [Source: pubspec.yaml melos.scripts]
- **Baseline JSON shape** (match it): `{"version": 3, "packageApi": {"packageName": "<pkg>", "packageVersion": "0.0.1", "packagePath": "<abs-temp>", "interfaceDeclarations": [...]}}`. [Source: packages/koel_core/.api-baseline/koel_core.json head]

### What must keep working (regression guards)

- **AI-5.9 pins held** — `analyzer 12.1.0` / `freezed 3.2.6-dev.1` no drift in root `pubspec.lock`. This story adds **no workspace dependency** (`dart_apitool` is a global; the wrapper is pure `dart:io`). The only `pubspec.yaml` edit is the melos `api-diff` script line.
- **No new public symbol in any package** — 9.3 is tooling/CI. The baseline regeneration captures the *existing* surface (incl. the already-shipped `koel_core` `Context` change); it adds nothing.
- **`koel_flutter` / `koel_widgets` symbol sets unchanged** — regenerated baselines differ only in tool incidentals, never in the symbol set (D2). `koel_widgets` was frozen by 9.2 D5 expressly for this story.
- **The gate is GREEN on main after this lands** — because Task 2 captures the baselines and Task 5 verifies current==committed. A red api-diff on the introducing PR would mean the wrapper isn't deterministic (likely an un-normalized `packagePath` — D7).
- **Other five workflows untouched** — only `api-diff.yml` changes. `ci.yml`/`conformance.yml`/`perf-bench.yml`/`codegen-drift.yml`/`publish-dry-run.yml` unchanged.
- **`verify:versioning` + the ten-package release set unchanged** — `koel_lints` stays a release package; it's only excluded from *API diff* (D4), not from versioning/publish.

### Scope boundaries (explicitly OUT of 9.3)

- Perf baselines / `BENCHMARKS.md` / `perf-bench.yml` → **Story 9.4**.
- `conformance.yml` / `publish-dry-run.yml` → **Story 9.5**.
- Docs site + per-package README §13 D-1 polish → **Story 9.6**.
- PRD/Addendum reconciliation (AR-24/25/26) → **Story 9.7**.
- Trademark / `ag_ui` license → **Story 9.8**.
- The actual v1.0.0 publish + removing `publish_to: none` + the post-publish "diff against the *published* surface" → **Story 9.9** (9.3 ships the committed-baseline gate the publish then promotes to the published surface — D6).
- Any `lib/` behavior change — 9.3 touches no `lib/src/**`; the only Dart it adds is `tool/verify_api_surface.dart`.

### Testing standards

- This is **tooling/CI**: the deliverable is verified by *running the gate*, not by a unit-test suite. Task 5's positive (current==committed → green) + negative (inject an additive symbol → warn/exit-0; inject a breaking change → exit-non-zero; revert both) checks are the acceptance evidence — record the observed output in the Dev Agent Record (codegen-drift.yml's retro-D1 proved a gate that can't fail is worthless; *prove this one bites*).
- `tool/verify_api_surface.dart` must pass `dart analyze` (0) + `dart format --set-exit-if-changed` (it's repo-root `tool/`, checked directly, not via `tool/format.sh` which is `packages/`-only).
- Determinism is the load-bearing property: the same tool version + same wrapper must reproduce a byte-stable baseline across machines (normalize machine-specific fields — D7). If it isn't byte-stable, the gate false-fails on every PR from a different runner.

### Project Structure Notes

- `tool/verify_api_surface.dart` matches architecture.md:734–736 (repo-level scripts, not part of any package). Baselines at `packages/<pkg>/.api-baseline/<pkg>.json` match the 2.15/6.8/7.4 convention (D1) — a per-package sibling of `lib/`, gitignored-exempt (committed artifacts). No structural variance.
- `api-diff.yml` is one of the six release-gate workflows (architecture.md:726–733); this story completes it from skeleton, leaving the other five as-is.

### References

- [Source: epics/epic-9-meta-package-sample-app-v100-release-gates.md#Story 9.3 (lines 66–87)] — AC1–AC3 verbatim (incl. the `_bmad-output/api-baselines/...` path the D1 decision overrides to the implemented `.api-baseline/` convention, and the `--extract`/diff/PR-comment wording).
- [Source: architecture.md#D7 (lines 370–379)] — `dart_apitool: ^0.23.1`, run per-package in CI, diff against baseline, diff-failure-blocks-merge.
- [Source: architecture.md (lines 726–736, 1129)] — `api-diff.yml` workflow + `tool/verify_api_surface.dart` wrapper + `melos run api-diff` script.
- [Source: implementation-artifacts/2-15-perf-baselines-dartdoc-barrel.md (Task 6, lines 79–82; Dev Notes 213; Completion 253)] — global-activate `dart_apitool 0.23.1` (isolated from analyzer-12 hold), extract-after-barrel, `.api-baseline/<pkg>.json` path, "verify don't fabricate", extracts cleanly on SDK 3.12.
- [Source: implementation-artifacts/6-8-memory-streaming-jank-baselines.md (Task 5 / D8, lines 67–70, 102)] — Flutter-package extract with NO `--force-use-flutter`; same `.api-baseline/` convention "the path Epic 9 9-3 reads".
- [Source: implementation-artifacts/7-4-widget-tests-goldens-barrel-example.md (Task 6 / D5, lines 59–61, 183)] — koel_widgets baseline (8 symbols), global 0.23.1, no flag; "the diff gate (`api-diff.yml`) stays Epic 9's (9-3)".
- [Source: implementation-artifacts/deferred-work.md (lines 171, 277, 441)] — placeholder-workflow caution; koel_core baseline path hand-off to 9-3; **koel_core baseline STALE after 2-16 `Context` retype → 9-3 must pin tool + regenerate as a clean diff**.
- [Source: implementation-artifacts/9-2-repo-root-sample-app.md (D5; scope boundaries)] — koel_widgets surface frozen "precisely so 9.3 owns the gate"; `dart_apitool` wiring explicitly deferred from 9.2 → 9.3.
- [Source: implementation-artifacts/9-1-koel-meta-package-versioning.md] — ten-package release set + hybrid versioning; `koel` meta-barrel re-exports core+http+flutter (the surface the `koel` baseline captures).
- [Source: .github/workflows/api-diff.yml (skeleton) + codegen-drift.yml + ci.yml example-build] — workflow body templates (setup-dart 3.12.0 / flutter-action 3.44.0, melos bootstrap, melos run build, banner convention).
- [Source: pubspec.yaml melos.scripts (verify:versioning / conformance / capture-fixtures)] — melos script shape for the new `api-diff` entry.
- [Source: packages/koel_lints/lib/] — `koel.yaml`/`koel_flutter.yaml`/`main.dart`/`src/rules/` — no Dart barrel ⇒ excluded from the gate (D4).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8) — under the `/agent-flutter-engineer` persona (CLAUDE.md mandate).

### Debug Log References

Task 0 (verify-don't-assume — the load-bearing finding):

- `dart-apitool --version` → `0.23.1` (already globally activated at `~/.pub-cache/bin/dart-apitool`; isolated from the workspace analyzer-12/freezed pins as 2.15/6.8/7.4 proved).
- `extract --help`: `--input <pkg-dir|pub://|git://>` (mandatory), `--output <file>` (JSON; stdout if omitted), `--force-use-flutter` (NOT needed — see below).
- `diff --help`: `--old`/`--new` are **package refs** (dir / `pub://` / `git://`), `--version-check-mode [none, fully, onlyBreakingChanges]` drives the exit code, `--report-format [cli, markdown, json]`.
- **CRITICAL — `diff` cannot consume a stored extract JSON.** Empirically `dart-apitool diff --old <baseline.json> --new packages/koel_http` → `Error: Invalid argument(s): Unknown package ref: …koel_http.json`. Source-confirmed: `package_ref.dart` (`PackageRef` is only dir/pub/git) + `command_mixin.dart` `prepare`/`analyze` (both `--old` and `--new` are **re-analyzed from package SOURCES**, never loaded from an extract). dart_apitool-0.23.1 `lib/src/cli/commands/diff_command.dart:165-186`. → **D7's assumed `diff --old <baseline.json>` invocation does not exist.** Prior stories (2.15/6.8/7.4) only ever ran `extract`; nobody had wired the *diff*, so the gap was never hit. Resolution recorded in Completion Notes (FYI #1).
- Flutter packages extract with **NO `--force-use-flutter`** on the 3.44.0 / Dart 3.12.0 toolchain (koel_widgets → 8 symbols, koel_flutter → 11 — re-confirms 6.8/7.4 on the current toolchain).
- **Determinism:** extracting koel_http twice is **byte-identical after stripping `packagePath`** (the only machine-specific field — an absolute temp dir); list order preserved. So neutralizing `packagePath` is the whole determinism fix (D7).
- **Meta-package `koel` extracts 0 symbols** — `_isInternalRef` (package_api_analyzer.dart:429-439) follows a re-export only when `origPackageName == refPackageName`, so `koel`'s cross-`package:` re-exports of core/http/flutter are **not** followed. No flag changes this. Resolution: FYI #2 below.
- All 8 non-meta surface packages extract cleanly (koel_core 160 incl. `Context`; koel_test 12, koel_agno 4, koel_langgraph 3, koel_runtime 3).

Task 5 (gate proof):

- `melos run api-diff` (VERIFY) → green, all 9 packages "no change", exit 0 (self-consistent after Task 2 `--update`).
- **Negative check (gate bites)** on `koel_http`: injected a throwaway public class → `WARNING additive: type ApiDiffNegativeCheckProbe`, exit **0**; removed an existing `export` (drops `SseParser`) → `BREAKING removed: type SseParser … blocked`, exit **1**; both reverted → green again, barrel clean.
- pubspec.lock **0-drift**; AI-5.9 pins held (`analyzer 12.1.0`, `freezed 3.2.6-dev.1`). `melos run analyze` SUCCESS (11 pkgs + asp plugin, no exec crash this run). `melos run test` SUCCESS (koel_flutter 74 unchanged — no new lib test). `melos run format:check` 0-changed + `dart format --set-exit-if-changed tool/verify_api_surface.dart` 0-changed. `melos run verify:versioning` OK.

### Completion Notes List

Wired the NFR-14 breaking-change gate: `tool/verify_api_surface.dart` (the architecture.md:736 wrapper), a complete self-consistent 9-package baseline set at `packages/<pkg>/.api-baseline/<pkg>.json`, the real `api-diff.yml` body, and the `melos run api-diff` script. Tooling/CI only — **no `lib/src/**` change, no new public symbol, no new workspace dependency** (`dart_apitool` is a global activation; the wrapper is pure `dart:io`/`dart:convert`). pubspec.lock 0-drift; AI-5.9 pins held.

**FYI #1 — design correction to D7 (decided + recorded, not bounced — memory: *confirmed needs adversarial evidence*, *no CYA open questions*).** D7 assumed `dart-apitool diff --old <baseline.json>`. Task 0 disproved it from source: 0.23.1's `diff` re-analyzes both refs from package **sources** and rejects a stored extract JSON ("Unknown package ref"). The committed-JSON baseline model (D1/D2/D6) is kept fully intact; the wrapper uses the CLI **only for `extract`** and computes the breaking-vs-additive classification itself by comparing the fresh extract against the committed baseline at the **symbol level** — which maps exactly onto AC2 (removed/changed = breaking, added = additive-warn). Member granularity means a new method on an existing class reads as additive, a removed/retyped one as breaking. *Conservative edge:* any change to an existing symbol's serialized declaration is treated as breaking — including the technically-additive optional-param-add — which for a 1.0.0 freeze is the safe direction (such a change must go through an explicit `--update` baseline-refresh PR, the Story 9.9 flow). Full rationale + source citations are in the `tool/verify_api_surface.dart` header.

**FYI #2 — `koel` meta-package has a legitimately empty surface.** dart_apitool scopes a surface to its defining package and does not follow cross-`package:` re-exports (`_isInternalRef`), so `koel` (a pure re-export barrel) extracts 0 own symbols. It stays in the gate with its empty baseline, which guards the real invariant "the meta-package introduces **no own symbol** (stays a pure barrel)"; its *transitive* surface is gated by the `koel_core`/`koel_http`/`koel_flutter` baselines, and its re-export integrity by `koel`'s barrel-resolve test. The wrapper logs `koel: OK (0 symbols)` (visible, not silent). `koel_lints` (no Dart barrel, D4) and `koel_devtools` (Epic-8 WIP, not in the ten-package release set) are the only hard-excluded packages, each named in the wrapper.

**D2 captured as designed.** All 9 baselines regenerated through the single pinned wrapper (old bytes not preserved). `koel_core` baseline now contains `Context` and `RunAgentInput.context: List<Context>` (the stale 2.16 snapshot updated — a clean reviewable diff, not a regression). `koel_flutter` (11) / `koel_widgets` (8) symbol **sets** verified unchanged vs the old committed baselines (only tool incidentals + `packagePath` differ).

Other five workflows untouched (only `api-diff.yml` changed); the ten-package release set + `verify:versioning` unchanged.

### File List

- `tool/verify_api_surface.dart` — **new.** The per-package breaking-change wrapper (extract via global dart-apitool, symbol-level diff vs committed baseline, `--update` capture mode, version pin, `packagePath` neutralization).
- `.github/workflows/api-diff.yml` — **modified.** Real body replacing the Story 1.5 placeholder (flutter-action 3.44.0, global-activate dart_apitool 0.23.1 + melos, bootstrap, build, `melos run api-diff`).
- `pubspec.yaml` — **modified.** Added the `api-diff` melos script (no dependency change).
- `packages/koel/.api-baseline/koel.json` — **new** (empty surface — pure barrel, FYI #2).
- `packages/koel_core/.api-baseline/koel_core.json` — **modified** (regenerated; now includes `Context` / `List<Context>` — D2).
- `packages/koel_http/.api-baseline/koel_http.json` — **new.**
- `packages/koel_test/.api-baseline/koel_test.json` — **new.**
- `packages/koel_agno/.api-baseline/koel_agno.json` — **new.**
- `packages/koel_langgraph/.api-baseline/koel_langgraph.json` — **new.**
- `packages/koel_runtime/.api-baseline/koel_runtime.json` — **new.**
- `packages/koel_flutter/.api-baseline/koel_flutter.json` — **modified** (regenerated; symbol set unchanged — D2).
- `packages/koel_widgets/.api-baseline/koel_widgets.json` — **modified** (regenerated; symbol set unchanged — D2).
- `_bmad-output/implementation-artifacts/9-3-dart-apitool-baselines-ci-gate.md` — story (frontmatter `baseline_commit`, task checkboxes, Dev Agent Record, Status).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — story status tracking (ready-for-dev → in-progress → review).

### Change Log

- 2026-06-07 — Story 9.3 implemented (dev-story). NFR-14 breaking-change gate wired: `tool/verify_api_surface.dart` wrapper + `api-diff.yml` body + `melos run api-diff` script + full 9-package self-consistent baseline set. Design correction to D7 (dart_apitool 0.23.1 `diff` cannot consume a stored extract JSON → wrapper computes the symbol-level classification itself; committed-JSON model intact). All gates green; pubspec.lock 0-drift; AI-5.9 pins held. Status → review.

### Review Findings

_Code review 2026-06-07 — 3-layer adversarial (Blind Hunter / Edge Case Hunter / Acceptance Auditor). Auditor: all 3 ACs, 7 locked decisions, 6 regression guards VERIFIED (live-ran the gate green + the negative break/restore; no spec violations). Findings below are gate-robustness hardening, all grounded against the real extract data. 0 decision-needed, 3 patch, 2 defer, 4 dismissed._

- [x] [Review][Patch] Symbol key drops the member `type` (kind) discriminator → latent FALSE-GREEN [tool/verify_api_surface.dart:342,356] — `executableDeclarations` carry a `type` field (`method`/`getter`/`setter`/`constructor`/`operator`), but the key uses `m['name']` only. A getter+setter (or named-ctor vs same-named method, or a top-level getter+setter) of the same name collapse to one `symbols` map entry — the later one overwrites the earlier. Removing the overwritten member then goes UNDETECTED (the surviving entry's canonical JSON still matches the baseline) → a breaking removal passes green. Confirmed via the extract shape; currently DORMANT (koel's surface is all-immutable/freezed — scanned all 9 baselines, zero co-named collisions), but the gate's core promise (catch removals) has a blind spot for any future read/write property. Fix: include the kind in the key, e.g. `'type $name.${m['type']} ${m['name']}'` (and the top-level `fn` key). Self-contained — keys are recomputed at verify time on both sides, so no baseline regeneration. Aligns with the story's own "prove the gate bites" principle (Task 5 / codegen-drift retro-D1).
- [x] [Review][Patch] Incidental-field strip is shallow but canonicalization is deep → parameter-level `relativePath` survives → FALSE-RED on a file move [tool/verify_api_surface.dart:387-404] — `_without(m, {entryPoints, relativePath})` drops those keys only at depth 1, but each parameter nested under a member carries its own `relativePath` (verified present at depth 3 `exec/parameters`), and `_canonicalize` serializes it verbatim. Moving a parameter type's source file (internal reorg, no signature change) changes the member's canonical JSON → `changed` → BREAKING. Directly contradicts the file's own documented invariant (lines 323-327: "moving a symbol to a different file… is not an API change"). Safe direction (false-red, recoverable via `--update`), but bites on a routine refactor. Fix: strip `entryPoints`/`relativePath` recursively inside `_canonicalize`. No baseline regen (both sides recompute). NB the declaration-level `relativePath` IS already stripped — this is the nested-parameter oversight only.
- [x] [Review][Patch] Version check assumes single-line `--version` output → FALSE-RED on the documented fallback path [tool/verify_api_surface.dart:416] — `_apiToolVersion` returns `stdout.trim()`; when `dart-apitool` is NOT on PATH the wrapper falls back to `dart pub global run dart_apitool --version`, which on a fresh activation can print a precompile notice before the version line. `trim()` doesn't remove interior newlines → `version != '0.23.1'` → gate refuses to run. Not biting in the wired CI (pub-cache `bin` is on PATH → bare exe → single line), but it defeats the explicitly-coded local-dev fallback. Fix: extract the semver (last non-empty line, or a regex) instead of `trim()`.
- [x] [Review][Defer] Top-level declaration arrays cast unguarded `as List` while nested arrays use `as List? ?? const []` [tool/verify_api_surface.dart:311-314,334,355,359,365] — deferred, unreachable under the pinned 0.23.1 (empirically emits `[]` for empty arrays — the empty `koel` surface extracts green). A consistency nit vs the author's own nested-array guard; harmless under the version pin.
- [x] [Review][Defer] `--update` writes baselines incrementally — a mid-loop extraction failure leaves a half-updated baseline set [tool/verify_api_surface.dart:151-161] — deferred, mitigated: `--update` is a human-run capture reviewed as a git diff in its own PR (Story 9.9 flow), so a partial write is visible and revertable, never reaching the CI gate. Robustness-only (extract-all-then-write-all would make it transactional).

_Dismissed (4): (1) member method↔field reclassification reads as removed+added → false-red — the conservative-breaking direction is the documented intent (FYI #1) + version-pinned. (2) corrupt/missing-`packageApi` baseline → uncaught exception — fails loud, files are tool-generated, negligible likelihood. (3) `koel_devtools` excluded alongside `koel_lints` — honest, correct (Epic-8 WIP, not in the ten-package set), named-with-reason. (4) `_surfaceOf` returns `topLevel: 0` placeholder — no bug, that field is never read on the baseline path._

**Review patches applied (2026-06-07, all 3):** (1) symbol keys now embed the declaration kind (`type X.${type} name`, top-level `${type} name`) so co-named getter/setter/constructor members can't collide → closes the false-green. (2) `_canonicalize` drops `entryPoints`/`relativePath` at every depth (hoisted `_incidentalKeys` const) → parameter-level file moves no longer false-red; the now-redundant shallow `_without(_, incidental)` calls removed. (3) `_apiToolVersion` takes the last non-empty stdout line → the `dart pub global run` fallback's precompile notice no longer false-fails the version pin. Re-verified: `dart analyze` + `dart format` clean, gate GREEN on all 9 baselines (no regeneration — keys/values recompute on both sides), negative bite-check still fires (`BREAKING removed: type HttpAgent` → exit 1; constructor keys now show `.constructor` kind), `pubspec.lock` 0-drift, AI-5.9 pins held.
