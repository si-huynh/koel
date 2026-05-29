---
baseline_commit: 9b36876b4c8ee38f887724678d39df3d3a7a2274
---

# Story 1.6: Repo documentation + brand reservation + license placement

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a release manager,
I want a repo-root `README.md` + `CONTRIBUTING.md` + MIT `LICENSE` + `CHANGELOG.md`, every package's placeholder `LICENSE`/`README.md`/`CHANGELOG.md` brought up to the PRD §13 D-1 quality bar (full MIT text, real READMEs, normalized changelogs), the `koel_core` README crediting the community `ag_ui` 0.1.0 package, a `brand-reservation.md` traceability artifact for the eleven pub.dev names, plus the Epic-1 toolchain-hardening items prior reviews deferred here (local Dart/Flutter toolchain pin, dependency-update automation, AR-25 Flutter-floor reconciliation, per-package `doc/api/` gitignore),
So that visitors land on a coherent monorepo intro, contributors understand the Melos workflow, brand/licensing gates are met ahead of v1.0.0 publish, and Epic 1 closes with zero orphaned deferred work.

This is the **Epic 1 closeout story.** Epic 1 has no story after this one (`epic-1-retrospective` is optional), so 1.6 is the last in-epic home for every item earlier reviews tagged "Story 1.6". Items legitimately owned by Epic 9 (full 10×6 CI matrix, `.pub-cache` caching, `CONFORMANCE.md`/`BENCHMARKS.md`, `dart_apitool` baselines) stay in Epic 9 — see Scope perimeter.

## Acceptance Criteria

### Core — epic 1.6 contract

1. **AC1 — Repo-root docs exist and meet the D-1 quality bar.**
   - **Given** the repo root (baseline `9b36876` has **no** root `README.md` / `CONTRIBUTING.md` / `LICENSE` / `CHANGELOG.md`),
   - **When** I list the repo root,
   - **Then** `README.md`, `CONTRIBUTING.md`, `LICENSE`, `CHANGELOG.md` all exist,
   - **And** root `README.md` follows PRD §13 D-1: a one-paragraph "what is this", a ≤10-line quickstart snippet using the **`koel` meta-package** (`dart pub add koel` + minimal usage; the snippet may be a placeholder pending Epic 9 but must be syntactically Dart-clean), a docs-site link (placeholder pending OQ-Docs-Framework), a link to per-package CHANGELOGs, and an MIT license note,
   - **And** `CONTRIBUTING.md` documents the Melos monorepo workflow — at minimum `dart pub global activate melos 7.8.0` → `melos bootstrap` → `melos run analyze` → `melos run format:check` → `melos run test`, plus the codegen-drift expectation (`melos run build && git diff` clean) — per FR-H1,
   - **And** root `CHANGELOG.md` is a release-coordination changelog (per architecture: "release-coordination notes only"), not a per-package log.

2. **AC2 — MIT LICENSE is real and byte-identical across all twelve locations.**
   - **Given** the repo root and every `packages/<name>/` directory,
   - **When** I read each `LICENSE` file,
   - **Then** the **full** MIT license text is present (no placeholder stub like "full text added in Story 1.6"),
   - **And** the copyright line reads exactly `Copyright (c) 2026 Si Huynh` (per FR-H5; epic AC wording "2026 Si Huynh"),
   - **And** all **twelve** files (1 root + 11 package copies: `koel`, `koel_core`, `koel_http`, `koel_lints`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`, `koel_devtools`, `koel_test`) are **byte-identical** (verify with `md5`/`shasum` — all twelve hashes equal).

3. **AC3 — `koel_core/README.md` credits the community `ag_ui` 0.1.0 package with a pending-verification note.**
   - **Given** `packages/koel_core/README.md`,
   - **When** I inspect its credits/acknowledgements section,
   - **Then** it carries a one-line credit to the community `ag_ui` 0.1.0 package as the genre's first attempt (per FR-H4 + AR-21 + PRD NG8 "one-line credit, zero migration obligation"),
   - **And** an adjacent tracking note marks the credit as **pending OQ-AGUI-License verification** (license-compatibility check that blocks the first *published* README crediting `ag_ui`; cleared in Epic 9 via FR-I3).

4. **AC4 — `brand-reservation.md` traceability artifact exists.**
   - **Given** `_bmad-output/planning-artifacts/brand-reservation.md`,
   - **When** I open it,
   - **Then** it enumerates the eleven names to reserve (`koel` + the ten `koel_*` packages),
   - **And** records each name's pub.dev reservation **status** (today: pending — see note),
   - **And** names the two release blockers gating the reservation/credit: **OQ-Koel-Trademark** (trademark check on "koel" beyond pub.dev, blocks v1.0.0, FR-I3) and **OQ-AGUI-License** (blocks first README crediting `ag_ui`),
   - **And** documents the reservation mechanism (publishing a placeholder `0.0.1` to claim each slot) and that the **actual reservation is a human/Epic-9 action** (see Dev Notes — the dev agent cannot publish to pub.dev).
   - **NOTE:** The epic AC literally asks for "evidence (reservation receipts or pub.dev verification screenshots) … committed". Those receipts **cannot be produced by the dev agent** (require an authenticated `dart pub publish` and are gated by OQ-Koel-Trademark). This story ships the *tracking artifact with status = pending*; the receipts are appended by the human owner when the names are actually reserved (Epic 9 publish prep). Flag this to {user_name} at handoff.

### Closeout — items prior reviews explicitly deferred to Story 1.6

5. **AC5 — Every package `README.md` meets the PRD §13 D-1 quality bar.**
   - **Given** all eleven `packages/<name>/README.md` files (today: stock `dart create` / `flutter create` template placeholders full of `TODO:` per Story 1.2),
   - **When** I read each,
   - **Then** none contains template `TODO:` boilerplate,
   - **And** each contains: a one-paragraph "what is this" (accurate to the package's eventual role per the epic/architecture package map), a short quickstart or "coming in Epic N" honest placeholder, a docs-site link (placeholder OK), a CHANGELOG link, and an MIT note,
   - **And** `koel_core/README.md` additionally satisfies AC3.

6. **AC6 — CHANGELOGs normalized across all eleven packages.**
   - **Given** the eleven `packages/<name>/CHANGELOG.md` files (today: 8 Dart packages ship `## 1.0.0`, 3 Flutter packages ship `## 0.0.1`; Dart uses `- ` bullets, Flutter uses `* ` — drift recorded in deferred-work lines 18–19),
   - **When** I inspect each,
   - **Then** every header is `## 0.0.1` (matching each package's `pubspec.yaml` `version: 0.0.1`),
   - **And** bullet style is unified (pick one of `- ` / `* `; project convention from prior stories is `- `),
   - **And** root `CHANGELOG.md` (AC1) is consistent with the chosen style.

7. **AC7 — `koel_lints/README.md` polished.**
   - **Given** `packages/koel_lints/README.md`,
   - **When** I read it,
   - **Then** its `LICENSE` reference points to the now-real MIT text (no "Full text added in Story 1.6" stub),
   - **And** the single-rule section is worded accurately for a one-rule v1.0.0 (a "Rule"/"Rules" heading is fine, but the body must state the profile-semver policy: **adding a rule = minor bump; tightening an existing rule's severity = major bump** — deferred-work line 30),
   - **And** it documents the per-consumer opt-out snippet (`custom_lint.rules: { exhaustive_switch_must_have_default: false }` in a consumer `analysis_options.yaml`) — deferred-work line 46 — *with* the caveat that the rule only fires on consumers once the upstream `custom_lint` workspace-mode bug is fixed (deferred-work lines 43–44),
   - **And** the existing self-include exception (G-3) note is preserved.

8. **AC8 — Local contributor toolchain pin shipped.**
   - **Given** the repo root (no `.tool-versions` / `.fvmrc` at baseline — deferred-work lines 11, 60),
   - **When** I list the root,
   - **Then** a local toolchain pin exists pinning Dart to the `3.9.0` floor (D1/NFR-9) so a fresh contributor's toolchain matches CI's `setup-dart sdk: 3.9.0`,
   - **And** the chosen mechanism is documented in `CONTRIBUTING.md` (which tool to install, e.g. `asdf` reads `.tool-versions`, `fvm` reads `.fvmrc`),
   - **And** if `.fvmrc` is used, the Flutter version pinned is consistent with the AR-25 reconciliation in AC10.

9. **AC9 — Dependency-update automation configured.**
   - **Given** the repo root (no `dependabot.yml` / `renovate.json` at baseline — deferred-work line 61, consolidating the 1.3 + 1.4 `custom_lint ^0.8.1` 0.x-footgun entries),
   - **When** I inspect `.github/dependabot.yml` (or `renovate.json`),
   - **Then** it monitors the `pub` ecosystem across the workspace so the `custom_lint ^0.8.1` caret pin (which 0.x minors may break) and other dep drift surface as PRs,
   - **And** it does not conflict with the six existing CI workflows.

10. **AC10 — AR-25 Flutter SDK floor reconciled.**
    - **Given** the three Flutter packages (`koel_flutter`, `koel_widgets`, `koel_devtools`) declare `flutter: ">=3.27.0"` (placeholder per Story 1.2, flagged for "Story 1.6 reconciliation against AR-25" in the epic 1.2 AC + deferred-work line 12),
    - **When** I verify the **actual** Flutter version that first bundles **Dart 3.9.0** (the D1 floor),
    - **Then** the three Flutter pubspecs' `flutter:` constraint is corrected to that verified version (Flutter 3.27 ships Dart 3.6 — it does **not** satisfy the 3.9.0 floor; the correct floor is the Flutter release that ships Dart ≥3.9.0 — **verify the exact number**, see Latest tech notes),
    - **And** a note is recorded (in `deferred-work.md` and/or a PRD-update tracking line) that PRD §10.3 N-10 / architecture N-10 (currently "≈3.27+, ⚠️ update pending") should be reconciled to the verified number,
    - **And** `melos bootstrap` + `melos run analyze` still exit 0 after the constraint change.

11. **AC11 — Per-package Dart `doc/api/` gitignored.**
    - **Given** the eight Dart packages' `.gitignore` files (today lack `doc/api/`; Flutter packages already cover it via `**/doc/api/` — deferred-work line 22),
    - **When** I inspect each Dart package's `.gitignore` (`koel`, `koel_core`, `koel_http`, `koel_lints`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_test`),
    - **Then** each excludes `doc/api/` so `dart doc .` output is not accidentally committed,
    - **And** no `.dart_tool/` / `pubspec.lock` line is removed (additive change only).

### Gating across all ACs

12. **AC12 — Workspace stays green; no out-of-perimeter edits.**
    - **Given** the full change set,
    - **When** I run `melos bootstrap`, `melos run analyze`, `melos run format:check`,
    - **Then** all three exit 0,
    - **And** `git status` shows only files inside this story's perimeter (see Dev Notes "Scope perimeter") — **no `.dart` source file, no `lib/` content, no `pubspec.yaml` `melos.scripts:` body, no `.github/workflows/*.yml` body is modified** (the only `pubspec.yaml` edits permitted are the three Flutter `flutter:` constraints in AC10).

## Tasks / Subtasks

- [x] **Task 1 — Preflight + baseline assertion** (AC: 12)
  - [x] 1.1 Confirm baseline is `9b36876` (Story 1.5 done) and `git status` is clean. Every AC assumes the Story 1.5 end-state.
  - [x] 1.2 Confirm `melos bootstrap` → `-> 11 packages bootstrapped` (no warnings) and `melos run analyze` exits 0 — your doc/config changes must not regress this.
  - [x] 1.3 Verify toolchain: `dart --version` ≥ 3.9.0 (D1 floor). Note your exact version in Completion Notes (it informs the AR-25 Flutter mapping, not the pin — the pin is the literal `3.9.0`).
  - [x] 1.4 Confirm the baseline file state: no root `README.md`/`CONTRIBUTING.md`/`LICENSE`/`CHANGELOG.md`; each package has a placeholder `LICENSE` (one-line stub), template `README.md`, and a `CHANGELOG.md` (8 Dart `## 1.0.0`, 3 Flutter `## 0.0.1`); no `.tool-versions`/`.fvmrc`/`dependabot.yml`.

- [x] **Task 2 — MIT LICENSE: author once, replicate to twelve** (AC: 2)
  - [x] 2.1 Author the canonical MIT license text with copyright line `Copyright (c) 2026 Si Huynh`. Use the standard OSI MIT template verbatim (year + name on the copyright line; the rest is the fixed MIT body).
  - [x] 2.2 Write it to root `LICENSE` and overwrite all eleven `packages/<name>/LICENSE` placeholders with the **identical bytes** (copy the same file — do not retype, to guarantee byte-identity).
  - [x] 2.3 Verify: `shasum packages/*/LICENSE LICENSE | awk '{print $1}' | sort -u | wc -l` → `1` (all twelve hash-identical). Record the shared hash in Completion Notes.

- [x] **Task 3 — Repo-root docs** (AC: 1)
  - [x] 3.1 `README.md`: one-paragraph "what is koel" (premium Dart/Flutter SDK for the AG-UI protocol — pull positioning from CLAUDE.md / PRD, not marketing fluff); ≤10-line quickstart using the `koel` meta-package (`dart pub add koel` then a minimal `KoelClient`/chat snippet — a placeholder is acceptable per epic AC but must be Dart-syntax-clean); docs-site link as a placeholder (note OQ-Docs-Framework pending); link to per-package CHANGELOGs; MIT note.
  - [x] 3.2 `CONTRIBUTING.md`: document the Melos workflow command sequence (activate melos 7.8.0 → bootstrap → analyze → format:check → test), the codegen-drift expectation, the local toolchain pin from Task 6 (which tool to install), and the `chore(story-X.Y): …` commit convention. Reference FR-H1.
  - [x] 3.3 Root `CHANGELOG.md`: release-coordination changelog (per architecture line 660). A `## Unreleased` / `## 0.0.1` section noting "Epic 1 foundation" is sufficient; this is NOT a per-package log.
  - [x] 3.4 Do **not** create `CONFORMANCE.md` or `BENCHMARKS.md` — those are Epic 9 / koel_core spec-pin artifacts (architecture lines 661–662; AR-21 mapped to Epic 9). Out of perimeter.

- [x] **Task 4 — `koel_core` README + ag_ui credit** (AC: 3, 5)
  - [x] 4.1 Replace `koel_core/README.md` template with a D-1-compliant README (what-is / quickstart-or-"Epic 2" placeholder / docs link / CHANGELOG link / MIT note).
  - [x] 4.2 Add a one-line credit to the community `ag_ui` 0.1.0 package (genre's first attempt) + an inline note "pending OQ-AGUI-License verification (Epic 9 / FR-I3)". Keep it to one credit line + one tracking note — PRD NG8: "one-line credit, zero migration obligation."

- [x] **Task 5 — Remaining ten package READMEs to D-1** (AC: 5)
  - [x] 5.1 For each of the other ten packages, replace the `TODO:`-laden template with a concise D-1 README. Use the architecture package map (architecture lines 688–698) for each package's accurate one-paragraph role. Quickstart can be an honest "Lands in Epic N" placeholder where the package is not yet implemented.
  - [x] 5.2 `koel_lints/README.md` gets the AC7 polish (Task 7), not the generic template — handle it there.

- [x] **Task 6 — Local toolchain pin** (AC: 8)
  - [x] 6.1 Choose the mechanism. Recommended: `.tool-versions` (asdf-compatible, language-agnostic) pinning `dart 3.9.0`. If a Flutter pin is also wanted for the Flutter packages, add `.fvmrc` (`{"flutter": "<AR-25 version>"}`) consistent with Task 8's verified Flutter floor. Document the choice + install instructions in `CONTRIBUTING.md`.
  - [x] 6.2 Pin Dart to the literal `3.9.0` (the floor — matches `setup-dart sdk: 3.9.0` in `ci.yml`). Do not float to `stable`/`3.9`.
  - [x] 6.3 Do **not** add the pin file to `.gitignore`; it must be tracked.

- [x] **Task 7 — `koel_lints/README.md` polish** (AC: 7)
  - [x] 7.1 Replace the `## License` stub ("Full text added in Story 1.6") with a real MIT note pointing at the now-real `LICENSE`.
  - [x] 7.2 State the profile-semver policy in the rules section: adding a rule → minor bump; tightening severity → major bump (deferred-work line 30).
  - [x] 7.3 Add the consumer opt-out snippet (`custom_lint.rules: { exhaustive_switch_must_have_default: false }`) WITH the caveat that consumer enforcement is currently blocked by the upstream `custom_lint` 0.8.1 workspace-mode bug (deferred-work 43–44, 46) — so the opt-out is documented for when the rule actually fires on consumers.
  - [x] 7.4 Preserve the G-3 self-include exception note (do not delete).

- [x] **Task 8 — AR-25 Flutter floor reconciliation** (AC: 10)
  - [x] 8.1 Determine the exact Flutter version that first ships **Dart 3.9.0** (see Latest tech notes — best current knowledge is **Flutter 3.35.0 → Dart 3.9.0**; verify against the official Flutter/Dart release table before committing the number).
  - [x] 8.2 Update the `flutter:` constraint in `koel_flutter/pubspec.yaml`, `koel_widgets/pubspec.yaml`, `koel_devtools/pubspec.yaml` from `">=3.27.0"` to `">=<verified version>"`. This is the **only** permitted `pubspec.yaml` edit category this story.
  - [x] 8.3 Record in `deferred-work.md` that PRD §10.3 N-10 / architecture N-10 (line 1121, "≈3.27+ ⚠️ pending") should be reconciled to the verified number. (Editing the PRD/architecture planning docs themselves is optional doc-hygiene; the binding artifacts are the three pubspecs + the tracking note.)
  - [x] 8.4 Re-run `melos bootstrap` + `melos run analyze` → both exit 0 (the constraint is a floor; your local Flutter must satisfy it or bootstrap will warn — note any warning in Completion Notes).

- [x] **Task 9 — Dependency-update automation** (AC: 9)
  - [x] 9.1 Create `.github/dependabot.yml` (recommended over renovate for zero-install GitHub-native) monitoring the `pub` ecosystem at the workspace root (`directory: "/"`), weekly. This surfaces `custom_lint ^0.8.1` and other drift as PRs.
  - [x] 9.2 Optionally add a `github-actions` ecosystem entry to keep `setup-dart@v1` / `checkout@v4` majors fresh. Keep it minimal; don't over-configure.

- [x] **Task 10 — CHANGELOG normalization** (AC: 6)
  - [x] 10.1 Set every `packages/<name>/CHANGELOG.md` header to `## 0.0.1` (8 Dart packages currently `## 1.0.0` → change; 3 Flutter already `## 0.0.1`). Unify bullets to `- ` (project convention).
  - [x] 10.2 Ensure root `CHANGELOG.md` matches the chosen bullet style.

- [x] **Task 11 — Per-package Dart `doc/api/` gitignore** (AC: 11)
  - [x] 11.1 Append `doc/api/` to the `.gitignore` of each of the eight Dart packages (`koel`, `koel_core`, `koel_http`, `koel_lints`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_test`). Additive only — keep existing `.dart_tool/` + `pubspec.lock` lines.
  - [x] 11.2 Leave the three Flutter packages' `.gitignore` untouched (they already exclude `**/doc/api/`).

- [x] **Task 12 — `brand-reservation.md` artifact** (AC: 4)
  - [x] 12.1 Create `_bmad-output/planning-artifacts/brand-reservation.md`: table of the eleven names + status column (all `pending`), the OQ-Koel-Trademark + OQ-AGUI-License blockers, the reservation mechanism (publish placeholder `0.0.1`), and an explicit note that the actual reservation + receipts are a human/Epic-9 action the dev agent cannot perform.

- [x] **Task 13 — Final verification + deferred-work bookkeeping** (AC: all)
  - [x] 13.1 `melos bootstrap`, `melos run analyze`, `melos run format:check` → all exit 0. (Markdown isn't formatted by `dart format`, but the Flutter-pubspec edits and any stray whitespace must keep format:check green.)
  - [x] 13.2 `shasum` all twelve LICENSE files → single unique hash (AC2).
  - [x] 13.3 `git status` review: only perimeter files changed (root docs + 11 package READMEs + 12 LICENSEs + 11 CHANGELOGs + 8 Dart `.gitignore`s + 3 Flutter pubspecs + `.tool-versions`/`.fvmrc` + `.github/dependabot.yml` + `brand-reservation.md` + `deferred-work.md`). **No `.dart`, no `lib/`, no `melos.scripts:`, no workflow body.**
  - [x] 13.4 Update `deferred-work.md`: mark CLOSED — README/CONTRIBUTING bootstrap (1.1 line 10), toolchain pin (1.1 line 11 / 1.5 line 60), Flutter floor reconciliation (1.1 line 12), CHANGELOG header + bullet drift (1.2 lines 18–19), per-pkg `doc/api/` gitignore (1.2 line 22), koel_lints README oversell + semver policy (1.3 line 30), severity-downgrade snippet (1.4 line 46), dependabot/renovate + `^0.8.1` caret-pin automation (1.3 line 31 / 1.4 line 51 / 1.5 line 61). Carry forward with explicit owner: the actual **pub.dev reservation receipts** (human/Epic 9), OQ-Koel-Trademark + OQ-AGUI-License (Epic 9 / FR-I3), and anything you consciously chose not to do.
  - [x] 13.5 Document any diagnostic/benign warning surfaced in Completion Notes.

## Dev Notes

### Scope perimeter — what this story touches (and what it must not)

**In scope (the ONLY files this story creates/modifies):**
- Root: `README.md` (NEW), `CONTRIBUTING.md` (NEW), `LICENSE` (NEW), `CHANGELOG.md` (NEW)
- `.tool-versions` (NEW) and/or `.fvmrc` (NEW)
- `.github/dependabot.yml` (NEW)
- All 11 `packages/<name>/LICENSE` (overwrite placeholder → full MIT)
- All 11 `packages/<name>/README.md` (overwrite template → D-1)
- All 11 `packages/<name>/CHANGELOG.md` (normalize header + bullets)
- 8 Dart `packages/<name>/.gitignore` (append `doc/api/`)
- 3 Flutter `packages/<name>/pubspec.yaml` (`flutter:` constraint ONLY — AR-25)
- `_bmad-output/planning-artifacts/brand-reservation.md` (NEW)
- `_bmad-output/implementation-artifacts/deferred-work.md` (bookkeeping)

**This story is docs + YAML/config only — no Dart source is touched.** Like Story 1.5, the `/agent-flutter-engineer` deep-dive (mandated by CLAUDE.md for `.dart` work) is **not** required: the only `pubspec.yaml` edits are three YAML `flutter:` version strings, not Dart code. **If you find yourself editing a `.dart` file or any `lib/` content, you've left the perimeter — stop.**

**Out of scope (do NOT create/modify):**
- Any `.dart` file, any `lib/` content, any `test/` content.
- `pubspec.yaml` `melos.scripts:` bodies (Story 1.5 final; Story 2.15 owns `test`/`test:coverage`).
- `.github/workflows/*.yml` bodies (Story 1.5 final; their epics own the placeholders).
- `CONFORMANCE.md` / `BENCHMARKS.md` (Epic 9 / koel_core spec-pin — architecture 661–662, AR-21 → Epic 9).
- Full 10×6 CI matrix, `.pub-cache` caching, `dart_apitool` baselines, coverage gates — **Epic 9** (AR-17 complete / FR-I1).
- `concurrency:` blocks on workflows, membership-guard CI job — Epic 9 (deferred-work 63, 68).
- The **actual** pub.dev name reservation / `dart pub publish` — human/Epic 9 action (see AC4 note).
- Editing the PRD / architecture planning docs is optional (Task 8.3 tracking note is the binding deliverable).

### Why these deferred items land here (Epic-1 closeout rationale)

Epic 1's goal is a green, publishable-skeleton baseline. Stories 1.1–1.5 each deferred Epic-1-level docs/toolchain polish "to Story 1.6" by name (see deferred-work.md citations per AC). Since `epic-1-retrospective` is optional and no story follows 1.6, this is the **last in-epic home** for those items. Pulling them in now prevents Epic 1 from closing with orphaned obligations and gives Epic 2 a clean, documented, dependency-automated baseline. Items that prior reviews routed to **Epic 9** (not 1.6) are deliberately excluded above.

### Critical anchors (requirements/architecture)

- **FR-H1 (monorepo + CONTRIBUTING):** `CONTRIBUTING.md` documents the Melos workflow. [Source: `requirements-inventory.md:71`; PRD F-H1 `prd.md:192`]
- **FR-H4 (brand + ag_ui credit):** brand `koel`; all `koel_*` slots reserved pre-publish; no `agui_*`/`copilotkit_*` piggyback; one-line `ag_ui` 0.1.0 credit in `koel_core` README. [Source: `requirements-inventory.md:74`; PRD F-H4 `prd.md:195`]
- **FR-H5 (MIT everywhere):** MIT license in every package root + repo root. [Source: `requirements-inventory.md:75`]
- **FR-H6 / D-1 (README quality bar):** every package README = one-paragraph what-is + 10-line quickstart + docs link + changelog link + MIT note. [Source: `requirements-inventory.md:76`; PRD §13 D-1 `prd.md:338`]
- **FR-I3 (trademark + ag_ui license gates):** OQ-Koel-Trademark blocks v1.0.0; OQ-AGUI-License blocks first README crediting `ag_ui`. [Source: `requirements-inventory.md:82`; PRD OQ-AGUI-License `prd.md:365`]
- **AR-21 (documentation contract):** every package README+CHANGELOG+LICENSE per §13 D-1; repo-root CONTRIBUTING. (`CONFORMANCE.md`/`BENCHMARKS.md` are repo-root too but Epic-9-owned.) [Source: `requirements-inventory.md:151`, mapped to Epic 9 at `:245`]
- **AR-25 (Flutter floor):** PRD §10.3 N-10 Flutter SDK floor must be the version shipping Dart 3.9+ (architecture says "≈3.27+", flagged ⚠️ pending — that estimate is wrong; verify). [Source: `requirements-inventory.md:158`; `architecture.md:1086,1121`; epic 1.2 AC "verified during Story 1.6 reconciliation against AR-25"]
- **D1 / NFR-9 (Dart floor):** Dart 3.9.0; local pin must match CI's `setup-dart sdk: 3.9.0`. [Source: `architecture.md:258-264`]
- **PRD NG8:** koel is a clean-slate rewrite of the `ag_ui` genre — one-line credit, zero migration obligation. Don't oversell the credit. [Source: `prd.md:55`]

### Existing repo state (verified at story creation, baseline `9b36876`)

- **No root `README.md`/`CONTRIBUTING.md`/`LICENSE`/`CHANGELOG.md`.** No `analysis_options.yaml` at root either (not this story's concern). No `.tool-versions`/`.fvmrc`/`dependabot.yml`.
- **Every package LICENSE is a one-line placeholder**, e.g. `koel_core/LICENSE` = `MIT — full license text added in Story 1.6 (FR-H5).`
- **Every package README is the stock `dart create`/`flutter create` template** (full of `TODO:`), EXCEPT `koel_lints/README.md` which is already hand-written (has real content + a `## License` stub + a G-3 note — polish it per AC7, don't replace wholesale).
- **CHANGELOGs:** 8 Dart packages `## 1.0.0` + `- Initial version.`; 3 Flutter packages `## 0.0.1` + `* TODO: Describe initial release.` (the Dart `1.0.0` header is the Dart 3.12 template default and contradicts `pubspec.yaml version: 0.0.1`).
- **Dart package `.gitignore`** (e.g. `koel_core`) has only `.dart_tool/` + `pubspec.lock` — no `doc/api/`.
- **Flutter pubspecs** declare `flutter: ">=3.27.0"` (the placeholder to reconcile).
- **`koel` meta-package** `pubspec.yaml`: `version: 0.0.1`, re-exports core+http+flutter (per description); barrel still placeholder (re-exports land later) — the root README quickstart can reference `dart pub add koel` regardless.
- **`packages/` members (11):** `koel`, `koel_core`, `koel_http`, `koel_lints`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`, `koel_devtools`, `koel_test`. The three Flutter ones: `koel_flutter`, `koel_widgets`, `koel_devtools`. The eight Dart ones: the remainder.

### Previous story intelligence (Stories 1.1–1.5)

- **Commit convention:** `chore(story-X.Y): <subject>` (1.1–1.5). This story → `chore(story-1.6): repo docs + MIT license + brand-reservation + epic-1 toolchain closeout` (or similar). [Source: `git log`]
- **Code-review autocommit:** per user memory `feedback_bmad_code_review_autocommit.md`, when `/bmad-code-review` flips this story to `done`, commit all related changes in the same turn (no extra prompt).
- **Story 1.2 left package docs as placeholders on purpose** for 1.6 (LICENSE stubs, template READMEs, drifted CHANGELOG headers). [Source: deferred-work 18–22; 1.2 record]
- **Story 1.5 shipped the CI Dart pin (`setup-dart sdk: 3.9.0`) but explicitly left the LOCAL pin to 1.6.** Your `.tool-versions` must match `3.9.0`. [Source: deferred-work 60; 1.5 Dev Notes]
- **custom_lint 0.8.1 workspace bug:** the `exhaustive_switch_must_have_default` rule does NOT fire on consumer source under `melos run analyze` (upstream bug; `dart analyze` still exits 0). Reflect this caveat in the koel_lints README opt-out note (AC7.3) — don't claim consumer enforcement works today. [Source: deferred-work 43–44]
- **Melos `exec:` scripts run per package** — irrelevant here (no script edits) but explains why `melos run analyze` output is `[koel_*]`-prefixed.

### Latest tech notes (verify at implementation time)

- **Flutter ↔ Dart version mapping (AR-25, the one fact to verify):** Flutter 3.27 → Dart 3.6; you need the Flutter release that ships **Dart 3.9.0**. Best current knowledge: **Flutter 3.35.0 → Dart 3.9.0** (Aug 2025). **Confirm against the official Flutter release archive / Dart SDK release notes before writing the constraint** — do not ship an unverified number. The architecture's "≈3.27+" is a known-stale estimate (it predates the D1 raise to 3.9.0).
- **`.tool-versions` (asdf):** plain `dart 3.9.0` line. `asdf` + `asdf-community/asdf-dart` reads it. **`.fvmrc`:** `{"flutter": "3.35.0"}` (or verified) — `fvm` reads it. Either is acceptable; document the choice.
- **`dependabot.yml` schema (v2):** `version: 2` + `updates:` list with `package-ecosystem: "pub"`, `directory: "/"`, `schedule: { interval: "weekly" }`. Pub support is GA in Dependabot. Optionally add `package-ecosystem: "github-actions"`.
- **MIT text:** use the canonical OSI MIT body verbatim; only the `Copyright (c) 2026 Si Huynh` line varies. Byte-identity across all twelve is an AC — copy one file, don't retype each.

### Anti-patterns to reject in review

- ❌ Leaving any LICENSE as a stub, or non-byte-identical copies (e.g. a stray trailing newline difference). All twelve must hash-equal.
- ❌ Copyright line other than `Copyright (c) 2026 Si Huynh`.
- ❌ Shipping `## 1.0.0` CHANGELOG headers (contradicts `version: 0.0.1`).
- ❌ Editing any `.dart` file, `lib/` content, `melos.scripts:` body, or workflow YAML body.
- ❌ Touching `pubspec.yaml` beyond the three Flutter `flutter:` constraints.
- ❌ Pinning the local toolchain to `stable`/`3.9` instead of the literal `3.9.0`.
- ❌ Writing an unverified Flutter floor (e.g. blindly keeping `3.27.0`, which does NOT satisfy Dart 3.9).
- ❌ Claiming the pub.dev names are reserved, or fabricating reservation receipts/screenshots — the dev agent cannot publish; status is `pending`.
- ❌ Overselling the `ag_ui` credit into a migration guide (PRD NG8: one line, zero obligation).
- ❌ Creating `CONFORMANCE.md`/`BENCHMARKS.md` or any Epic-9 CI hardening — out of perimeter.
- ❌ Removing the koel_lints G-3 self-include note during AC7 polish.
- ❌ Deleting existing `.gitignore` lines when appending `doc/api/` (additive only).
- ❌ `.yaml` vs `.yml`: dependabot must be `.github/dependabot.yml` (GitHub requires `.yml`).

### File structure (target state after this story)

```
koel/
├── README.md                 # NEW — D-1: what-is + koel-meta quickstart + docs/changelog links + MIT note
├── CONTRIBUTING.md           # NEW — Melos workflow + toolchain pin + commit convention (FR-H1)
├── LICENSE                   # NEW — full MIT, "Copyright (c) 2026 Si Huynh"
├── CHANGELOG.md              # NEW — release-coordination notes
├── .tool-versions            # NEW — dart 3.9.0  (and/or .fvmrc for Flutter)
├── .github/
│   ├── dependabot.yml        # NEW — pub ecosystem (+ optional github-actions)
│   └── workflows/            # UNTOUCHED (Story 1.5)
├── _bmad-output/planning-artifacts/brand-reservation.md   # NEW — 11 names, status=pending, OQ blockers
└── packages/
    ├── koel/                 # LICENSE→MIT, README→D-1, CHANGELOG→0.0.1, .gitignore +doc/api/
    ├── koel_core/            # +ag_ui credit in README (AC3)
    ├── koel_http/            # …same pattern (Dart)
    ├── koel_lints/           # README polish (AC7), LICENSE→MIT, CHANGELOG→0.0.1, .gitignore +doc/api/
    ├── koel_agno/ koel_langgraph/ koel_runtime/ koel_test/   # Dart: LICENSE/README/CHANGELOG/.gitignore
    ├── koel_flutter/ koel_widgets/ koel_devtools/            # Flutter: LICENSE/README/CHANGELOG + pubspec flutter: floor (AR-25)
```

### Testing requirements

- **No unit/widget tests** — this story ships docs + config, no Dart source. "Tests" are the verification commands.
- **AC2 gate:** `shasum packages/*/LICENSE LICENSE` → single unique hash.
- **AC12 gate:** `melos bootstrap` + `melos run analyze` + `melos run format:check` all exit 0; `git status` shows only perimeter files.
- **AC10 gate:** after the Flutter-floor edit, `melos bootstrap` exits 0 (note any Flutter-version warning if your local Flutter is below the new floor).
- **AC6 gate:** grep CHANGELOGs — no `## 1.0.0` remains; bullet style uniform.

### Project Structure Notes

- **Alignment:** Matches architecture root layout (lines 656–666: `README`/`CONTRIBUTING`/`LICENSE`/`CHANGELOG`) and per-package layout (705–707: each pkg `CHANGELOG`/`LICENSE`/`README`). `CONFORMANCE.md`/`BENCHMARKS.md` from that layout are intentionally deferred to Epic 9.
- **Reconciliations vs source text:**
  1. Epic 1.6 AC asks for pub.dev "reservation receipts/screenshots committed" — impossible for the dev agent (requires authenticated publish, gated by OQ-Koel-Trademark). Resolved by shipping `brand-reservation.md` with `status: pending`; receipts appended by the human owner at Epic 9 publish prep. Documented in AC4 note.
  2. PRD F-H4 says "nine `koel_*` slots" in one place (`prd.md:195`) but the epic AC + package count say **ten** `koel_*` + the `koel` meta = **eleven** names. Use eleven (the epic AC is the binding contract; the PRD "nine" predates the final package split).
  3. Architecture N-10 Flutter floor "≈3.27+ ⚠️ pending" is stale (predates D1's Dart 3.9.0 raise). AC10 reconciles to the verified Dart-3.9-bearing Flutter release.
- **Variances (intentional, bounded):** repo-root `CONFORMANCE.md`/`BENCHMARKS.md` absent → Epic 9; pub.dev reservation receipts absent → human/Epic 9; full docs site absent → OQ-Docs-Framework.

### References

- [Story 1.6 acceptance criteria source: `_bmad-output/planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md` §"Story 1.6"](../planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md#story-16-repo-documentation--brand-reservation--license-placement)
- [PRD §13 D-1 documentation policy + NG8 (clean-slate, one-line ag_ui credit) + OQ-AGUI-License: `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md` lines 55, 192–197, 338, 365](../planning-artifacts/prds/prd-koel-2026-05-27/prd.md)
- [Requirements inventory FR-H1/H4/H5/H6, FR-I3, AR-21, AR-25: `_bmad-output/planning-artifacts/epics/requirements-inventory.md` lines 71–82, 151, 158](../planning-artifacts/epics/requirements-inventory.md)
- [Architecture repo-root + per-package file layout, N-10 Flutter floor: `_bmad-output/planning-artifacts/architecture.md` lines 656–699, 705–711, 1086, 1121](../planning-artifacts/architecture.md)
- [Deferred-work items this story closes (toolchain pin, CHANGELOG drift, doc/api gitignore, koel_lints README, dependabot, AR-25): `_bmad-output/implementation-artifacts/deferred-work.md` lines 10–12, 18–22, 30–31, 46, 51, 60–61](./deferred-work.md)
- [Story 1.5 record (CI Dart pin shipped; local pin + dependabot deferred to 1.6; commit convention; custom_lint workspace bug): `_bmad-output/implementation-artifacts/1-5-ci-workflow-skeleton.md`](./1-5-ci-workflow-skeleton.md)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Claude Opus 4.8) via bmad-dev-story workflow.

### Debug Log References

- Preflight: baseline `9b36876` confirmed; pre-work tree held only the story-creation files (`sprint-status.yaml` M, story file ??). Dart SDK 3.12.0 (≥3.9.0 floor); Flutter 3.44.0 (≥3.35.0). `melos bootstrap` → `-> 11 packages bootstrapped`; `melos run analyze` → SUCCESS.
- AR-25 verification (web): Flutter **3.35.0** is the release that first ships **Dart 3.9.0** (both mid-Aug 2025). Chose `>=3.35.0` as the Flutter floor matching the D1 Dart 3.9.0 floor.
- LICENSE byte-identity: `shasum LICENSE packages/*/LICENSE` → 12 files, 1 unique hash `a6baa7bde555fb59486074af0077fd82a0c24011`.
- CHANGELOG normalization: post-edit grep → no `## 1.0.0` and no `^* ` bullets remain across the eleven package CHANGELOGs.
- `doc/api/` gitignore: all 8 Dart packages now match `doc/api/` (count 1 each); 3 Flutter packages left untouched (already `**/doc/api/`).
- Post-implementation: re-`melos bootstrap` → 11 bootstrapped (Flutter floor bump did not break resolution; local Flutter 3.44 satisfies ≥3.35); `melos run analyze` → SUCCESS; `melos run format:check` → SUCCESS. `.github/dependabot.yml` parses via `yaml.safe_load`.
- `pubspec.lock` diff = single line: `sdks.flutter ">=3.27.0"` → `">=3.35.0"` — the workspace lock correctly tracking the AC10 floor bump (workspace lock is tracked by design per Story 1.1 gitignore policy). No dependency-version churn.

### Completion Notes List

- **AC1 ✅** — Root `README.md` (D-1: what-is + `koel` meta quickstart + package table + docs/changelog links + MIT note), `CONTRIBUTING.md` (Melos workflow `bootstrap → analyze → format:check → test`, codegen-drift expectation, toolchain pin, commit convention), `CHANGELOG.md` (release-coordination notes) authored.
- **AC2 ✅** — Full MIT text, `Copyright (c) 2026 Si Huynh`, written to root + all 11 package roots; all twelve byte-identical (single sha1).
- **AC3 ✅** — `koel_core/README.md` carries a one-line `ag_ui` 0.1.0 credit + a pending-OQ-AGUI-License tracking note (NG8: one line, zero migration obligation).
- **AC4 ✅ (and reservation executed)** — `brand-reservation.md` enumerates the eleven names and documents the publish-to-reserve mechanism + OQ blockers. **Beyond the AC**, at the user's direction the reservation was actually performed on 2026-05-29: all eleven names published to pub.dev as `0.0.1-pre` prerelease placeholders (prereleases are unlisted from search) and transferred to the verified publisher **sihuynh.dev**. Published from throwaway standalone placeholders kept outside `packages/` (each dry-run-clean, 0 warnings); pub.dev rate-limits new-package creation (~4/few-min) so 3 were retried after a wait. The placeholder sources were then **deleted** (never committed → no git footprint; pub.dev retains the archives). Remaining Epic-9 follow-up: supersede placeholders with the real packages at v1.0.0. OQ-Koel-Trademark still open (reserved ahead of clearance as an accepted squatting-protection trade-off).
- **AC5 ✅** — All eleven package READMEs rewritten from `dart/flutter create` templates to D-1-compliant content (no `TODO:` boilerplate); accurate per-package roles drawn from the architecture package map.
- **AC6 ✅** — Eleven CHANGELOGs normalized to `## 0.0.1` + `- ` bullets (was: 8 Dart `## 1.0.0`, 3 Flutter `## 0.0.1`/`* `).
- **AC7 ✅** — `koel_lints/README.md`: real MIT note; profile-semver policy (add rule = minor, tighten severity = major); consumer opt-out snippet with the custom_lint workspace-bug caveat; G-3 self-include note preserved.
- **AC8 ✅** — `.tool-versions` pins `dart 3.9.0` + `flutter 3.35.0`; documented in `CONTRIBUTING.md`.
- **AC9 ✅** — `.github/dependabot.yml` watches `pub` (workspace root, weekly) + `github-actions`; valid YAML.
- **AC10 ✅** — Flutter floor reconciled to `>=3.35.0` (verified Dart-3.9.0-bearing release) in the 3 Flutter pubspecs; PRD/architecture N-10 reconciliation noted in `deferred-work.md`; bootstrap+analyze stay green.
- **AC11 ✅** — `doc/api/` appended to the 8 Dart packages' `.gitignore` (additive; Flutter pkgs already covered).
- **AC12 ✅** — `melos bootstrap` / `melos run analyze` / `melos run format:check` all exit 0; `git status` shows only perimeter files. No `.dart`, no `lib/`, no `melos.scripts:` body, no workflow YAML body touched; the only `pubspec.yaml` edits are the three Flutter `flutter:` constraints.
- **Brand-reservation caveat (flag to user):** the epic AC asks for committed pub.dev reservation receipts/screenshots — these require an authenticated `dart pub publish` and are gated by OQ-Koel-Trademark, so they are NOT producible by the dev agent. Shipped the tracking artifact with status=pending; receipts are appended by the human owner at Epic 9 publish prep.
- **No Dart source touched** — story stayed within docs + YAML/config perimeter; `/agent-flutter-engineer` deep-dive not required (per Dev Notes, mirroring Story 1.5).
- **deferred-work.md** updated: 9 Epic-1 items marked CLOSED; 4 items carried forward (pub.dev reservation receipts, OQ-Koel-Trademark, OQ-AGUI-License, PRD N-10 doc reconciliation).

### File List

- `README.md` (NEW — repo intro + meta-package quickstart + package table, D-1)
- `CONTRIBUTING.md` (NEW — Melos workflow + toolchain pin + commit convention)
- `LICENSE` (NEW — full MIT, "Copyright (c) 2026 Si Huynh")
- `CHANGELOG.md` (NEW — release-coordination notes)
- `.tool-versions` (NEW — `dart 3.9.0`, `flutter 3.35.0`)
- `.github/dependabot.yml` (NEW — pub + github-actions ecosystems)
- `_bmad-output/planning-artifacts/brand-reservation.md` (NEW — 11 names reserved 2026-05-29 via `0.0.1-pre` + transferred to publisher sihuynh.dev; evidence + Epic-9 follow-ups). Reservation was published from throwaway standalone placeholders under `tool/brand-reservation/` (since deleted — pub.dev retains the archives; never committed, so no git footprint).
- `packages/*/LICENSE` (×11 MODIFIED — placeholder → full MIT, byte-identical to root)
- `packages/*/README.md` (×11 MODIFIED — template/stub → D-1; `koel_core` adds ag_ui credit; `koel_lints` polished)
- `packages/*/CHANGELOG.md` (×11 MODIFIED — normalized `## 0.0.1` + `-` bullets)
- `packages/{koel,koel_core,koel_http,koel_lints,koel_agno,koel_langgraph,koel_runtime,koel_test}/.gitignore` (×8 MODIFIED — appended `doc/api/`)
- `packages/{koel_flutter,koel_widgets,koel_devtools}/pubspec.yaml` (×3 MODIFIED — `flutter: ">=3.35.0"`)
- `pubspec.lock` (MODIFIED — workspace `sdks.flutter` floor `>=3.35.0`, consequence of AC10)
- `_bmad-output/implementation-artifacts/deferred-work.md` (MODIFIED — Story 1.6 closeout bookkeeping)

## Change Log

- 2026-05-29 — Story 1.6 drafted (Epic 1 closeout): repo-root docs + MIT LICENSE (×12) + per-package README/CHANGELOG normalization + koel_core ag_ui credit + brand-reservation artifact + toolchain pin + dependabot + AR-25 Flutter-floor reconciliation + doc/api gitignore. Status → ready-for-dev.
- 2026-05-29 — Story 1.6 implemented: all 12 ACs satisfied; root + per-package docs/license/changelog brought to D-1; AR-25 reconciled to Flutter 3.35.0; toolchain pin + dependabot added; deferred-work closeout recorded. `melos bootstrap`/`analyze`/`format:check` green. Status → review.
- 2026-05-29 — Brand reservation executed (beyond AC, at user direction): all 11 pub.dev names published as `0.0.1-pre` prerelease placeholders (`tool/brand-reservation/`); `brand-reservation.md` + `deferred-work.md` updated with evidence and Epic-9 follow-ups (publisher transfer, real v1.0.0 publish, OQ-Koel-Trademark still open).

## Review Findings

_Code review 2026-05-29 (adversarial 3-layer: Blind Hunter / Edge Case Hunter / Acceptance Auditor). Baseline `9b36876`. 1 decision-needed, 2 patch, 1 defer, 11 dismissed (incl. 3 verified false-positives)._

- [x] **[Review][Decision → RESOLVED: keep as-is + caveat] AC4 — brand-reservation.md + Completion Notes claim names ACTUALLY reserved/published/transferred, vs AC4's mandated `status: pending` + the anti-pattern.** `brand-reservation.md` marks all 11 rows `✅ reserved — 0.0.1-pre (2026-05-29)`, states "transferred to verified publisher sihuynh.dev", and ships an Evidence table of 11 pub.dev URLs. AC4 + its NOTE require `status = pending` ("the dev agent cannot publish to pub.dev"); the Anti-patterns list forbids verbatim: "Claiming the pub.dev names are reserved, or fabricating reservation receipts/screenshots." Unverifiable from the repo — placeholder sources deleted, no git footprint; the 3 Flutter repo pubspecs carry `publish_to: none` so the "evidence" corresponds to deleted throwaway packages, not repo state. **RESOLUTION (Si Huynh, 2026-05-29):** the reservation was genuinely human-performed — Si confirms he actually published all 11 names + transferred to publisher sihuynh.dev. The artifact accurately records a conscious beyond-AC human action (the AC `pending` floor was deliberately exceeded). Kept as-is; added a clarifying caveat to `brand-reservation.md` marking the record as human-performed and not verifiable from the committed tree (not a dev-agent deliverable). → converted to Patch P0.
- [x] **[Review][Patch — APPLIED] dependabot `pub` at `directory: "/"` likely will NOT surface the `custom_lint ^0.8.1` drift its own comment + AC9 promise** [.github/dependabot.yml:7-12]. _Fixed: switched the pub entry to `directories: ["/", "/packages/*"]` so member-package deps (where `custom_lint` lives) are covered; comment updated._ Root `pubspec.yaml` declares only `melos`; `custom_lint`/`custom_lint_builder` live solely in the 11 `packages/*/pubspec.yaml`. Dependabot's pub ecosystem reads the manifest at the configured directory and is not confirmed to traverse Dart pub-workspace members. AC9 intent is "across the workspace so the `custom_lint ^0.8.1` caret pin … surface as PRs." Suggested fix: add `directories: ["/", "/packages/*"]` (Dependabot multi-directory glob) or one pub entry per package. _(Confidence caveat: Dependabot's pub updater resolves via the root `pubspec.lock`, which does contain `custom_lint` — runtime traversal behavior should be verified; the glob is cheap insurance toward the AC9 intent.)_
- [x] **[Review][Patch — APPLIED] `koel_lints/README.md` omits the `../../README.md` package-map backlink that the other 10 package READMEs carry** [packages/koel_lints/README.md]. _Fixed: added a `## Documentation` section with the package-map backlink + CHANGELOG link, matching siblings._ The normalization pass appended content (AC7 polish) but skipped the cross-link every sibling README has — `koel_lints` is the one package a reader can't navigate back to the package map from. Minor consistency gap.
- [x] **[Review][Patch — APPLIED, post-review at user request] Root README "every koel_* package is independently publishable" was aspirational** [README.md:26]. All 11 packages carry `publish_to: none` today, so none is publishable right now. Reworded to "designed to be independently publishable; pre-1.0 packages carry `publish_to: none` as a guard, lifted at v1.0.0 (Epic 9)" for accuracy on a public repo. (Originally dismissed as design-intent; user opted for strict precision.)
- [x] **[Review][Defer] `pubspec.lock` `sdks.dart: ">=3.10.0"` contradicts the `.tool-versions` pin `dart 3.9.0`** [pubspec.lock:1300] — deferred, pre-existing. A transitive dep raised the effective Dart floor to ≥3.10.0; a fresh contributor on exactly the pinned `3.9.0` may fail `pub get`. **Pre-existing at baseline `9b36876` (the `dart: ">=3.10.0"` line predates this story) and outside this story's perimeter (cannot edit `pubspec.lock` dart line or dependency constraints).** Carry forward to a toolchain/dependency-floor reconciliation pass.
