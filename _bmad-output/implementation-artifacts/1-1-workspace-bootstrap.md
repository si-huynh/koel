---
baseline_commit: 90b3db6515125a4926d021ce11cff46c1992ce56
---

# Story 1.1: Workspace bootstrap (pub workspace + Melos + Dart 3.9.0+ floor)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an OSS contributor,
I want a Dart pub workspace + Melos 7.8.0 orchestration at the repo root with strict Dart 3.9.0+ floor,
So that running `melos bootstrap` produces a linked monorepo whose Dart toolchain matches the architectural Decision D1 (raised from PRD's original 3.0+).

## Acceptance Criteria

1. **AC1 — `melos bootstrap` exits 0 with linked workspace.**
   - **Given** a fresh clone of the repo with `dart pub global activate melos 7.8.0` available,
   - **When** I run `melos bootstrap` at the repo root,
   - **Then** the command exits 0 with every workspace member linked via `path:` resolutions in `pubspec_overrides.yaml`,
   - **And** no warning about workspace-incompatible members appears.

2. **AC2 — Root `pubspec.yaml` declares Dart 3.9.0+ floor + workspace array of 11.**
   - **Given** the repo-root `pubspec.yaml` is opened,
   - **When** I inspect its `environment.sdk` constraint,
   - **Then** it is `>=3.9.0 <4.0.0` (AR-3 / D1),
   - **And** the `workspace:` array lists exactly the 11 entries: `packages/koel`, `packages/koel_core`, `packages/koel_http`, `packages/koel_lints`, `packages/koel_agno`, `packages/koel_langgraph`, `packages/koel_runtime`, `packages/koel_flutter`, `packages/koel_widgets`, `packages/koel_devtools`, `packages/koel_test`.

3. **AC3 — `melos.yaml` enumerates members + defines the 7 scripts.**
   - **Given** the repo-root `melos.yaml`,
   - **When** I run `melos list`,
   - **Then** every workspace member is enumerated,
   - **And** the following scripts are defined under `scripts:`: `analyze`, `test`, `test:coverage`, `build`, `format`, `format:check`, `analyze:apply` (no-ops permitted; full bodies wired in later stories).

4. **AC4 — `.gitignore` covers codegen artifacts + Melos + per-package locks.**
   - **Given** the repo-root `.gitignore`,
   - **When** I grep it,
   - **Then** it excludes `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, `.dart_tool/`, `build/`, `coverage/`, `.melos_tool/`, and `pubspec.lock` per-package (workspace-level lock kept).

## Tasks / Subtasks

- [x] **Task 1 — Author root `pubspec.yaml` as Dart pub workspace** (AC: 1, 2)
  - [x] 1.1 Create `pubspec.yaml` at repo root with `name: koel_workspace`, `publish_to: none`, `environment: sdk: ">=3.9.0 <4.0.0"`.
  - [x] 1.2 Add `workspace:` array with exactly the 11 paths listed in AC2 (order: `koel`, `koel_core`, `koel_http`, `koel_lints`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`, `koel_devtools`, `koel_test`).
  - [x] 1.3 Add `dev_dependencies: melos: ^7.8.0` so contributors can `dart pub get` from root and pick up the pinned Melos version.

- [x] **Task 2 — Author root `melos.yaml`** (AC: 3)
  - [x] 2.1 Create `melos.yaml` at repo root: `name: koel`, `packages:` glob `packages/*` (mirrors the `workspace:` array; pub workspace auto-discovery handles enumeration but Melos still needs `packages:` for its own filtering).
  - [x] 2.2 Under `scripts:` declare all 7 scripts. Each script body may be a no-op stub `echo "wired in story <N>"` exiting 0; the AC permits empty bodies. Stub mapping:
        - `analyze` → wired in 1.4
        - `test` → wired in 2.15
        - `test:coverage` → wired in 2.15
        - `build` → wired in 1.5 (codegen-drift gate) and exercised by 2.1 (freezed)
        - `format` → wired in 1.4
        - `format:check` → wired in 1.5 (CI)
        - `analyze:apply` → wired in 1.4
  - [x] 2.3 Add `command/bootstrap:` block if needed for repo-level deps (default is fine; consult Melos 7.x docs).

- [x] **Task 3 — Create stub `pubspec.yaml` for each of the 11 workspace members** (AC: 1, 2)
  - [x] 3.1 For each of the 11 paths in `workspace:`, create the directory under `packages/` and place a minimal stub `pubspec.yaml` so `melos bootstrap` resolves workspace members and exits 0. Each stub declares: `name: <package_name>`, `environment: sdk: ">=3.9.0 <4.0.0"` (and `flutter: ">=3.27.0"` for the three Flutter packages — see **Dev Notes → Flutter SDK Floor**), `resolution: workspace`, and no `dependencies:` / `dev_dependencies:` blocks.
  - [x] 3.2 The three Flutter packages (`koel_flutter`, `koel_widgets`, `koel_devtools`) declare `environment.flutter: ">=3.27.0"` in addition to the Dart SDK constraint. Story 1.6 will reconcile the exact Flutter floor against PRD §10.3 N-10 (currently 3.33.0+).
  - [x] 3.3 These stubs are intentionally minimal — Story 1.2 will REPLACE them with `dart create --template=package` / `flutter create --template=package` outputs. Do NOT scaffold libraries, tests, README, or analysis_options here.
  - [x] 3.4 If `melos bootstrap` still warns about missing `pubspec_overrides.yaml` interaction, accept the warning ONLY IF it is unrelated to workspace incompatibility; AC1's "no warning about workspace-incompatible members" is the binding test.

- [x] **Task 4 — Verify / extend root `.gitignore`** (AC: 4)
  - [x] 4.1 Open the existing `.gitignore` at repo root. It was committed in `90b3db6 chore: initial koel monorepo scaffold` and already contains all AC4 entries plus extras (Flutter platform dirs, DevTools build, IDE, OS, secrets).
  - [x] 4.2 Verify (do NOT rewrite) that every AC4 entry is present: `*.g.dart`, `*.freezed.dart`, `*.mocks.dart`, `.dart_tool/`, `build/`, `coverage/`, `.melos_tool/`, `packages/*/pubspec.lock`.
  - [x] 4.3 If any AC4 entry is missing, add it inline in the matching section comment. Do not delete or reorder existing extras — they are deliberate (e.g., `pubspec_overrides.yaml` at the root is gitignored because Melos auto-generates it; per-package `pubspec.lock` is gitignored to keep only the workspace-level lock per AR-3).

- [x] **Task 5 — Smoke-test the bootstrap end-to-end** (AC: 1, 3)
  - [x] 5.1 Run `dart pub global activate melos 7.8.0` (idempotent; assumes contributor has Dart 3.9.0+ installed).
  - [x] 5.2 Run `melos bootstrap` at repo root. Expect exit 0 and `pubspec_overrides.yaml` (Melos-generated) appearing at each package root with `path:` resolutions for any future inter-package deps (none today; file may be near-empty).
  - [x] 5.3 Run `melos list`. Expect all 11 members enumerated.
  - [x] 5.4 Run each script as `melos run <script>` — each should exit 0 (no-op stubs are valid per AC3).
  - [x] 5.5 Document any deviation in Dev Agent Record → Completion Notes (especially regarding `pubspec_overrides.yaml` shape; see **Dev Notes → Open question: pub workspace vs Melos-generated overrides**).

## Dev Notes

### Critical architectural anchors

- **AR-1 (Workspace bootstrap):** Repo root is a Dart pub workspace (Dart 3.6.0+ required; recommend 3.9.0+) + Melos 7.8.0 orchestration. Workspace `pubspec.yaml` + `melos.yaml` are hand-authored (~15 lines + script list). **No** `very_good_cli` — bundled `very_good_analysis` conflicts with `koel_lints` and is banned everywhere in the repo (per AR-1 rationale, enforced in Story 1.2 AC3). [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md:125`]
- **AR-3 (Bootstrap order):** Story 1.1 is step (1) — repo skeleton + workspace + Melos + `.gitignore` + `.github/`. Step (2) is Story 1.3 (`koel_lints` stub). [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md:127`]
- **D1 (Dart SDK floor):** Dart 3.9.0+. Melos 7.x recommends 3.9.0+; pub-workspace minimum is 3.6.0+. PRD §10.3 N-9 has been updated to "Dart 3.9.0+" (final reconciliation in Story 9.7 / AR-24). [Source: `_bmad-output/planning-artifacts/architecture.md` Core Architectural Decisions → D1]
- **Codegen artifact policy (Convention §1):** `*.g.dart`, `*.freezed.dart`, `*.mocks.dart` are **gitignored**, never committed. CI re-runs `melos run build && git diff --exit-code` (codegen-drift gate, Story 1.5 / AR-18) to guarantee committed sources produce zero codegen diff. Rationale: pub.dev publish process injects generated files into the tarball regardless, so consumers always get them; committing inflates review noise ~3-4× per freezed class and creates merge conflicts. [Source: `_bmad-output/planning-artifacts/architecture.md` §"Implementation Patterns & Consistency Rules" §1]
- **Workspace lock policy:** Workspace-level `pubspec.lock` is the single source of truth; per-package `pubspec.lock` files are gitignored (AR-3, AC4). This is the inverse of stand-alone Dart packages.

### Library/version pins (already decided — do not re-evaluate)

| Item | Version | Decision ref |
|---|---|---|
| Dart SDK floor | `>=3.9.0 <4.0.0` | D1, AR-3, PRD N-9 |
| Melos | `7.8.0` (pinned) | AR-1, AR-3, PRD §10.3 N-9 |
| Flutter SDK floor | `>=3.27.0` placeholder (final 3.33.0+ per PRD N-10) | AR-25 — reconciled in Story 1.6 / 9.7 |

`dart pub global activate melos 7.8.0` must be the activation command; do not pull `melos: any` or a different major. Pin matches PRD §10.3 N-9 and Story 1.5's CI workflow (which will install the same version).

### Flutter SDK floor — known reconciliation deferred

Story 1.2 AC explicitly accepts `flutter: ">=3.27.0"` as a placeholder pending Story 1.6's verification against AR-25 / PRD N-10 (which states **Flutter 3.33.0+** as the first stable that bundles Dart 3.9). For Story 1.1, only the three Flutter packages' stub `pubspec.yaml` carry a Flutter constraint, and the placeholder `>=3.27.0` is intentional. Story 1.6 owns the final reconciliation. Do **not** raise to 3.33.0 in this story even though PRD has it — Story 1.2's AC also pins 3.27.0 and changing only Story 1.1 would desync them.

### Open question: pub workspace vs Melos-generated `pubspec_overrides.yaml`

AC1 prescribes "every workspace member linked via `path:` resolutions in `pubspec_overrides.yaml`". This phrasing matches **classic** Melos (pre-7.x), which generated per-package `pubspec_overrides.yaml` files. With Dart pub workspaces (Dart 3.6+), the canonical mechanism is the root `workspace:` array + each member declaring `resolution: workspace`; Melos 7.x **honors pub workspace semantics** but may or may not still write `pubspec_overrides.yaml` for path-overriding non-workspace deps.

**How to satisfy AC1:** The architectural intent is "every workspace member is linked after bootstrap and no incompatibility warning fires" — i.e., the *outcome*, not the literal presence of a `pubspec_overrides.yaml` file. If Melos 7.x replaces overrides with pub-workspace resolution and produces no overrides file by design, document this in Completion Notes and treat AC1 as met. Verify by running `dart pub deps` inside one of the stub packages and confirming workspace siblings resolve via `path` (workspace) entries rather than pub.dev.

If a sibling fails to resolve, debug **before** marking AC1 done — do not paper over with manual overrides.

### File structure requirements

After Story 1.1 ships, the repo root contains:

```
koel/
├── CLAUDE.md                      # (pre-existing)
├── .gitignore                     # (pre-existing — verify per AC4, extend if gaps)
├── pubspec.yaml                   # NEW — Dart pub workspace root
├── melos.yaml                     # NEW — Melos 7.8.0 config + 7 script stubs
├── pubspec.lock                   # generated by `dart pub get` / `melos bootstrap`; committed (workspace-level)
├── .dart_tool/                    # generated; gitignored
├── docs/                          # (pre-existing — empty placeholder)
├── _bmad/                         # (pre-existing — BMad workflow tooling)
├── _bmad-output/                  # (pre-existing — planning artifacts)
├── skills/                        # (pre-existing — custom BMad skills)
└── packages/                      # NEW — 11 subdirs, each with stub pubspec.yaml
    ├── koel/pubspec.yaml          # stub
    ├── koel_core/pubspec.yaml     # stub
    ├── koel_http/pubspec.yaml     # stub
    ├── koel_lints/pubspec.yaml    # stub
    ├── koel_agno/pubspec.yaml     # stub
    ├── koel_langgraph/pubspec.yaml # stub
    ├── koel_runtime/pubspec.yaml  # stub
    ├── koel_flutter/pubspec.yaml  # stub (+ flutter constraint)
    ├── koel_widgets/pubspec.yaml  # stub (+ flutter constraint)
    ├── koel_devtools/pubspec.yaml # stub (+ flutter constraint)
    └── koel_test/pubspec.yaml     # stub
```

[Source: `_bmad-output/planning-artifacts/architecture.md` §"Project Structure & Boundaries" → "Repository root layout"]

**Out of scope for Story 1.1** (do NOT create in this story):
- `.github/workflows/*` — Story 1.5 owns the six CI workflow files.
- `analysis_options.yaml` at root — depends on `koel_lints` being usable, which lands in Story 1.3 / 1.4.
- `README.md`, `CONTRIBUTING.md`, `LICENSE`, `CHANGELOG.md` at repo root — Story 1.6 owns these.
- `tool/` scripts (`capture_fixtures.dart`, `verify_api_surface.dart`, `perf/run_benchmarks.dart`) — owned by later epics (3, 4, 9).
- `example/` repo-level sample app — Story 9.2 owns.
- Anything under `lib/`, `test/`, or non-stub content inside any `packages/<name>/` — Story 1.2 scaffolds packages via `dart create` / `flutter create`.

### Naming, formatting, and convention guardrails

- **Indentation:** 2-space YAML. Match Dart/Flutter ecosystem convention.
- **Package names** under `packages/`: snake_case (`koel_core`, not `koelCore`). The `koel` meta-package is just `koel`.
- **Script naming in `melos.yaml`:** lowerCamelCase script keys with `:` for sub-tasks (`test:coverage`, `format:check`). Matches AC3 exactly — do not paraphrase.
- **No comments restating the YAML** (PRD NFR-16). Only annotate WHY (e.g., "Flutter floor pinned to 3.27.0 pending Story 1.6 reconciliation against AR-25"). [Source: architecture.md §"Implementation Patterns" §6]
- **YAML key order in stub `pubspec.yaml`:** `name`, `description` (one-liner OK), `version: 0.0.1` (placeholder), `publish_to: none` (until Story 1.6's pub.dev reservation lands), `environment` (sdk + optional flutter), `resolution: workspace`. Keep stubs identical in shape across packages so Story 1.2's `dart create` overlays cleanly.

### Testing requirements

- **No Dart tests exist yet** — `koel_test` itself is just a stub here. The verification is operational, not unit-tested:
  - `melos bootstrap` exit code 0
  - `melos list` enumerates 11 members
  - `melos run <each of 7 scripts>` exit code 0
- **CI gate not yet wired** — Story 1.5 creates `ci.yml` that will run these same commands on every PR. For Story 1.1, run locally and capture output in Completion Notes.
- **Coverage tier (NFR-12)** does not apply yet — no source code.

### Architecture compliance — what this story enables for later

- Story 1.2 will use `dart create --template=package` / `flutter create --template=package` to populate each package directory. The stubs from Task 3 will be **overwritten**. Stubs exist solely to make AC1's `melos bootstrap` exit 0 in this story.
- Story 1.3 (`koel_lints` profile) will populate `packages/koel_lints/` with `custom_lint` + `custom_lint_builder` structure (non-standard layout per D3 / AR-5).
- Story 1.4 will add `include: package:koel_lints/koel.yaml` to every other package's `analysis_options.yaml` (path-dependency during dev per AR-3).
- Story 1.5 will populate `.github/workflows/` and wire Melos scripts to real bodies (AR-17).

[Source: `_bmad-output/planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md` Stories 1.2–1.6]

### Git intelligence

- Last commit on `main`: `90b3db6 chore: initial koel monorepo scaffold` — added `CLAUDE.md`, `.gitignore`, `docs/`, `_bmad/`, `_bmad-output/`, `skills/`. No prior Dart/Flutter code exists. This is a clean greenfield bootstrap; no regressions to worry about.
- No previous story exists (this is `1-1-`, the first); no previous-story intelligence to carry forward.

### Anti-patterns to reject in review

- ❌ Including `very_good_analysis` anywhere in the repo (banned by AR-1).
- ❌ Committing `*.g.dart` / `*.freezed.dart` / `*.mocks.dart` (banned by AR-18; CI gate enforces).
- ❌ Pinning `melos: any` or a different major than `7.8.0`.
- ❌ Adding `pubspec_overrides.yaml` manually anywhere — Melos generates it; root `pubspec_overrides.yaml` is `.gitignore`d.
- ❌ Adding root `analysis_options.yaml` in this story (depends on Story 1.3).
- ❌ Adding placeholder `lib/<package>.dart` barrels in stubs (Story 1.2's `dart create` produces them).
- ❌ Comments in YAML restating obvious key meanings (per NFR-16 / Convention §6).

### Project Structure Notes

- Alignment: matches the `Repository root layout` block in architecture.md verbatim.
- Detected conflicts: none. AC4's `.gitignore` requirements are a subset of the committed `.gitignore`; verification suffices.
- Variance: `packages/<name>/pubspec.yaml` is created as STUBS in Story 1.1 (not full `dart create`/`flutter create` outputs). This is necessary because pub workspace resolution requires every member to exist; full scaffolding waits for Story 1.2. The variance is intentional and bounded — Story 1.2's first task overwrites these stubs.

### References

- [Story 1.1 acceptance criteria source: `_bmad-output/planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md` §"Story 1.1"](../planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md#story-11-workspace-bootstrap-pub-workspace-melos-dart-390-floor)
- [Architecture D1, AR-1, AR-3, AR-17, AR-18: `_bmad-output/planning-artifacts/architecture.md` §"Core Architectural Decisions" and §"Implementation Patterns"](../planning-artifacts/architecture.md)
- [PRD Addendum B.5 — Melos rationale: `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md` §B.5](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md)
- [Requirements inventory AR-1 → AR-3: `_bmad-output/planning-artifacts/epics/requirements-inventory.md` lines 125–127](../planning-artifacts/epics/requirements-inventory.md)
- [PRD §10.3 N-9 (Dart 3.9.0+) and N-10 (Flutter 3.33.0+): `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md` §10.3](../planning-artifacts/prds/prd-koel-2026-05-27/prd.md)
- [Pub workspaces reference: https://dart.dev/tools/pub/workspaces](https://dart.dev/tools/pub/workspaces) — verify Melos 7.x interop at implementation time.
- [Melos 7.x docs: https://melos.invertase.dev](https://melos.invertase.dev) — confirm `7.8.0` is current stable when implementing; if a later 7.x patch ships, prefer the pinned `7.8.0` unless a critical fix lands.

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (Opus 4.7, 1M context)

### Debug Log References

1. **Melos 7.x scripts-location discovery (the only iteration).** Initial implementation put `scripts:` inside `melos.yaml`, mirroring the AC3 phrasing. `melos run <any>` failed with `NoScriptException: This workspace has no scripts defined in its 'pubspec.yaml' file.` Melos 7.x exclusively reads scripts from the workspace-root `pubspec.yaml` under a top-level `melos:` key — the `melos.yaml` file is read for `name` + `packages` only. Fixed by moving the entire `scripts:` block into `pubspec.yaml > melos.scripts`; `melos.yaml` retained as minimal config (`name: koel`, `packages: - packages/*`) to satisfy AC3's "Given the repo-root `melos.yaml`" precondition. All 7 scripts then exit 0.

2. **Melos `--version` stdin echo crash (cosmetic only).** Running `melos --version` non-interactively raises `StdinException: Error getting terminal echo mode` from `package:prompts`. Workaround: redirect stdin `< /dev/null` for any non-TTY invocation, or use `dart pub global list | grep melos` for version reads. Does NOT affect `bootstrap`, `list`, or `run` operations.

3. **No previous-story commit exists** — this is the first implementation story; only commit on `main` is the planning baseline `90b3db6 chore: initial koel monorepo scaffold` (captured as `baseline_commit`).

### Completion Notes List

- ✅ **AC1 met via Dart pub workspace native resolution, not Melos-generated `pubspec_overrides.yaml`.** The AC phrasing "linked via `path:` resolutions in `pubspec_overrides.yaml`" reflects pre-7.x Melos behavior. Melos 7.8.0 + Dart 3.12.0 use the native `workspace:` array (root `pubspec.yaml`) + `resolution: workspace` (per-member) mechanism — `melos bootstrap` invokes `dart pub get` once at the workspace root, which resolves all 11 members in a single solve pass. No `pubspec_overrides.yaml` is generated anywhere (verified by `find packages -name pubspec_overrides.yaml` returning empty). The outcome ("every workspace member linked, no incompatibility warnings") is met; the literal mechanism prescribed by the AC has been superseded upstream and the Open Question in Dev Notes is resolved.
- ✅ **AC2 met:** Root `pubspec.yaml` declares `environment.sdk: ">=3.9.0 <4.0.0"` and the `workspace:` array contains exactly the 11 paths in the AC2 order. `dev_dependencies: melos: ^7.8.0` added so `dart pub get` from root pulls the pinned version.
- ✅ **AC3 met:** `melos.yaml` exists at repo root with `name: koel` + `packages: - packages/*`. `melos list` enumerates all 11 members alphabetically (`koel`, `koel_agno`, `koel_core`, `koel_devtools`, `koel_flutter`, `koel_http`, `koel_langgraph`, `koel_lints`, `koel_runtime`, `koel_test`, `koel_widgets`). All 7 scripts (`analyze`, `test`, `test:coverage`, `build`, `format`, `format:check`, `analyze:apply`) defined under `melos.scripts:` in `pubspec.yaml` and each `melos run <script>` exits 0. **Variance from AC3 literal text:** scripts live in `pubspec.yaml > melos.scripts`, not `melos.yaml > scripts` — forced by Melos 7.x upstream design (see Debug Log #1). The AC's outcome ("the 7 scripts are defined and runnable") is satisfied.
- ✅ **AC4 met:** Existing `.gitignore` (committed in `90b3db6`) already covers all 8 AC4 entries. No edits required. Verified via `grep -nF` for each: `*.g.dart` (line 6), `*.freezed.dart` (7), `*.mocks.dart` (8), `.dart_tool/` (2), `build/` (4), `coverage/` (5), `.melos_tool/` (11), `packages/*/pubspec.lock` (15).
- ⚠️ **Task 2.3 (`command/bootstrap` block) skipped intentionally** — story marks it "if needed; default is fine". Melos 7.8.0 default bootstrap (single `dart pub get` at workspace root) succeeds; no custom bootstrap command needed at this stage. Story 1.5 may revisit when wiring CI.
- ⚠️ **Task 5.2 expectation deviation** — story expected `pubspec_overrides.yaml` to appear per package; reality is Melos 7.x defers to pub workspace, so no overrides files are generated. Bootstrap still exits 0 with "11 packages bootstrapped". See AC1 note above.
- ✅ **Generated artifacts confirmed gitignored:** `.dart_tool/` (Dart), `.idea/` + `.idea/.name` + `.idea/modules.xml` (Melos IntelliJ gen), `.melos_tool/` if/when created. Verified `git check-ignore -v` returns the gitignore rule hit for each. No leak into `git status`.
- ✅ **Workspace `pubspec.lock` committed:** 8.5 KB at repo root, captures the single resolved dependency graph for the workspace (AR-3). Per-package locks gitignored.
- ✅ **`melos bootstrap` smoke result:** exit 0; output `"-> 11 packages bootstrapped"`; runtime ≈2s.
- ✅ **`melos run <each>` smoke result:** all 7 scripts exit 0 with the expected stub echo.
- **Out of scope (deferred per Dev Notes):** no `.github/workflows/*` (Story 1.5), no root `analysis_options.yaml` (Story 1.4, depends on Story 1.3 lints package), no root `README/CONTRIBUTING/LICENSE` (Story 1.6), no `tool/` scripts, no `example/`, no `lib/` content in any package stub. Each stub is exactly: name, description, version 0.0.1, publish_to: none, environment, resolution: workspace (+ flutter constraint for the 3 Flutter packages).

### File List

**Created (new files):**

- `pubspec.yaml` — Dart pub workspace root (Dart `>=3.9.0 <4.0.0`, 11 workspace entries, `melos: ^7.8.0` dev dep, `melos.scripts` block with the 7 stubs).
- `melos.yaml` — Melos workspace config (`name: koel`, `packages: - packages/*`).
- `pubspec.lock` — workspace-level lock generated by `melos bootstrap`; committed per AR-3.
- `packages/koel/pubspec.yaml` — meta-package stub (Dart-only).
- `packages/koel_core/pubspec.yaml` — protocol kernel stub (Dart-only).
- `packages/koel_http/pubspec.yaml` — HTTP/SSE transport stub (Dart-only).
- `packages/koel_lints/pubspec.yaml` — analyzer plugin stub (Dart-only).
- `packages/koel_agno/pubspec.yaml` — Agno adapter stub (Dart-only).
- `packages/koel_langgraph/pubspec.yaml` — LangGraph adapter stub (Dart-only).
- `packages/koel_runtime/pubspec.yaml` — CopilotKit runtime adapter stub (Dart-only).
- `packages/koel_test/pubspec.yaml` — test fixtures + harness stub (Dart-only).
- `packages/koel_flutter/pubspec.yaml` — Flutter glue stub (Flutter `>=3.27.0`).
- `packages/koel_widgets/pubspec.yaml` — Flutter widget primitives stub (Flutter `>=3.27.0`).
- `packages/koel_devtools/pubspec.yaml` — DevTools extension stub (Flutter `>=3.27.0`).

**Modified:**

- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `epic-1: backlog` → `in-progress`; `1-1-workspace-bootstrap: backlog` → `ready-for-dev` (create-story) → `in-progress` (dev-story start) → `review` (this completion).
- `_bmad-output/implementation-artifacts/1-1-workspace-bootstrap.md` — this story file: `baseline_commit` frontmatter added; all 5 tasks + 18 subtasks checked; Dev Agent Record + File List + Change Log populated; Status set to `review`.

**Untouched / not modified:**

- `.gitignore` — pre-existing entries already satisfy AC4; verified, not edited (per Task 4.2's "do NOT rewrite" directive).
- `CLAUDE.md`, `docs/`, `_bmad/`, `_bmad-output/` (other than the two files listed above), `skills/` — out of scope for Story 1.1.

## Change Log

| Date       | Story / Status   | Change                                                                                                                                                                              |
|------------|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 2026-05-28 | 1.1 / ready-for-dev | Story file created by create-story workflow; sprint-status updated; Epic 1 moved to `in-progress`.                                                                                |
| 2026-05-28 | 1.1 / in-progress    | Workspace bootstrapped: root `pubspec.yaml` (Dart pub workspace + Dart 3.9.0+ floor), `melos.yaml` (Melos 7.8.0 config), 11 stub package `pubspec.yaml` files, workspace `pubspec.lock`. AC1–AC4 verified via `melos bootstrap` (exit 0, 11 packages) + `melos list` (11 enumerated) + 7× `melos run <stub>` (all exit 0). |
| 2026-05-28 | 1.1 / review         | All 5 tasks complete; story moved to `review`. One literal-text deviation from AC3 documented in Completion Notes (Melos 7.x scripts live in `pubspec.yaml > melos.scripts`, not `melos.yaml > scripts`); AC outcomes all met. |
| 2026-05-28 | 1.1 / done           | Code review complete: kept `melos: ^7.8.0`; added `melos.yaml` script-location comment; cross-platform script stubs via `dart --version`. |

### Review Findings

- [x] [Review][Decision] Melos dev_dependency pin: caret vs exact — **Resolved: keep `^7.8.0`** per Task 1.3 literal; workspace `pubspec.lock` is the reproducibility anchor. Global/CI activation stays at exact `7.8.0`.

- [x] [Review][Patch] Document Melos 7.x script location in melos.yaml [melos.yaml:1] — Added comment pointing to `pubspec.yaml > melos.scripts`.

- [x] [Review][Patch] Cross-platform script stubs (Windows echo) [pubspec.yaml:26] — Replaced POSIX `echo` with map-format stubs (`description` + `run: dart --version`) for cross-platform exit 0.

- [x] [Review][Defer] koel_lints not wired to consumers — deferred, pre-existing; Story 1.3 owns lint package population.

- [x] [Review][Defer] No shared analysis_options.yaml — deferred, pre-existing; Story 1.4 depends on Story 1.3.

- [x] [Review][Defer] No CI workflow files for format:check/build gates — deferred, pre-existing; Story 1.5 owns `.github/workflows/*`.

- [x] [Review][Defer] No README/CONTRIBUTING bootstrap docs — deferred, pre-existing; Story 1.6 owns root docs.

- [x] [Review][Defer] No toolchain pin (.fvmrc / asdf) — deferred, pre-existing; Story 1.5/1.6 owns contributor toolchain matrix.

- [x] [Review][Defer] Flutter floor 3.27.0 placeholder vs PRD 3.33.0+ — deferred, pre-existing; intentional per Dev Notes; Story 1.6 reconciles AR-25.

- [x] [Review][Defer] melos.yaml `packages/*` can drift from root `workspace:` list — deferred, pre-existing; Story 1.5 CI can add membership guard.

- [x] [Review][Defer] Update AC1/AC3 epic literal wording (scripts location, pubspec_overrides mechanism) — deferred, pre-existing; follow-up doc hygiene to prevent re-flagging compliant Melos 7.x variances.
