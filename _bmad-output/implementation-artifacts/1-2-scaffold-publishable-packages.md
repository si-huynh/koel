---
baseline_commit: 2b4b250826a7a0e467fd0d1c0c2d48549da30889
---

# Story 1.2: Scaffold the ten publishable packages

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an OSS contributor,
I want all ten `koel_*` packages plus the `koel` meta-package scaffolded under `packages/` with the official Dart/Flutter package templates and a single `lib/<package_name>.dart` barrel file each,
So that each package is a publishable skeleton ready for FRs to land in subsequent epics.

## Acceptance Criteria

1. **AC1 — All 11 directories scaffolded via the official templates.**
   - **Given** the `packages/` directory after Story 1.1,
   - **When** I list its children,
   - **Then** I see exactly: `koel`, `koel_core`, `koel_http`, `koel_lints`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`, `koel_devtools`, `koel_test`,
   - **And** each Dart-only package (`koel`, `koel_core`, `koel_http`, `koel_lints`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_test`) was created via `dart create --template=package`,
   - **And** each Flutter package (`koel_flutter`, `koel_widgets`, `koel_devtools`) was created via `flutter create --template=package`.

2. **AC2 — Single barrel + `lib/src/` privacy convention.**
   - **Given** any package directory,
   - **When** I open `lib/<package_name>.dart`,
   - **Then** the file exists as the single barrel and re-exports nothing yet (placeholder OK),
   - **And** all source code is constrained to live under `lib/src/` per architecture Convention §2.

3. **AC3 — Pubspec hygiene: no `very_good_analysis`, correct SDK floors.**
   - **Given** any package's `pubspec.yaml`,
   - **When** I inspect dependencies,
   - **Then** no `very_good_analysis` package appears anywhere (per AR-1 rationale),
   - **And** Dart packages declare `environment.sdk: ">=3.9.0 <4.0.0"`,
   - **And** Flutter packages declare both Dart sdk constraint and `flutter: ">=3.27.0"` (verified during Story 1.6 reconciliation against AR-25).

4. **AC4 — Placeholder docs + license per package.**
   - **Given** any package directory,
   - **When** I list its root,
   - **Then** it contains placeholder `README.md`, `CHANGELOG.md`, and `LICENSE` files (content finalized in Story 1.6).

## Tasks / Subtasks

- [x] **Task 1 — Pre-flight toolchain check + workspace snapshot** (AC: 1)
  - [x] 1.1 Verify `dart --version` reports `>=3.9.0` and `flutter --version` reports `>=3.27.0`. If either is missing, halt and surface the discrepancy in Completion Notes — do not proceed with stale toolchains.
  - [x] 1.2 Capture the current descriptions from the 11 stub `packages/*/pubspec.yaml` files (left by Story 1.1) so they can be re-applied after scaffolding overwrites pubspecs. Mapping (verbatim, do not paraphrase):
        - `koel` → `Meta-package re-exporting koel_core + koel_http + koel_flutter (the quickstart path).`
        - `koel_core` → `AG-UI protocol kernel for Dart — events, errors, pipeline, reducer, JSON Patch.`
        - `koel_http` → `HTTP/SSE transport for AG-UI agents — HttpAgent, SseParser, interceptors.`
        - `koel_lints` → `Analyzer plugin enforcing koel's mandatory rules (custom_lint based).`
        - `koel_agno` → `AG-UI adapter for Agno backends.`
        - `koel_langgraph` → `AG-UI adapter for LangGraph backends.`
        - `koel_runtime` → `AG-UI adapter for the CopilotKit Next.js runtime — multipart GraphQL streaming.`
        - `koel_flutter` → `Flutter glue for koel — controller, scope, session storage, generative UI.`
        - `koel_widgets` → `Material 3 + Cupertino chat UI primitives (theme, bubble, input, follow-up list).`
        - `koel_devtools` → `Flutter DevTools extension — observer, time-travel replay, JSONL trace export.`
        - `koel_test` → `Test fixtures, MockAgent, and ConformanceRunner for koel adapters.`
  - [x] 1.3 Confirm `melos bootstrap` is currently green (`melos bootstrap` → "11 packages bootstrapped"). This is the baseline you must restore after scaffolding.

- [x] **Task 2 — Scaffold the 8 Dart-only packages** (AC: 1, 2, 3, 4)
  - [x] 2.1 For each of `koel`, `koel_core`, `koel_http`, `koel_lints`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_test`, run from the **repo root**:
        ```bash
        dart create --template=package --force --no-pub packages/<name>
        ```
        `--force` overwrites the Story 1.1 stub; `--no-pub` skips the implicit `dart pub get` (would fail inside a workspace until all 11 packages are re-resolved together via `melos bootstrap` in Task 5).
  - [x] 2.2 After each `dart create` completes, **immediately re-write `packages/<name>/pubspec.yaml`** to the workspace-aware shape below. The generated pubspec drops `publish_to: none` + `resolution: workspace` + the description from §1.2 — those MUST be restored or the workspace breaks.
        ```yaml
        name: <name>
        description: <verbatim from §1.2 mapping>
        version: 0.0.1
        publish_to: none

        environment:
          sdk: ">=3.9.0 <4.0.0"

        resolution: workspace
        ```
        Key order matches the Story 1.1 stubs (see **Dev Notes → Pubspec key order**). Do NOT add any `dependencies:` / `dev_dependencies:` blocks in this story — later stories add them per-package.
  - [x] 2.3 **Sanitize the barrel:** open the generated `lib/<name>.dart` and remove the `export 'src/<name>_base.dart';` line. The file must remain (AC2 requires its existence) but have **zero `export` directives** in this story. Acceptable final shape:
        ```dart
        /// {one-line package summary — copy from pubspec description}
        library;
        ```
  - [x] 2.4 **Delete the generated sample source:** remove `lib/src/<name>_base.dart`. There is no symbol to export until later stories; per Convention §2 the barrel is the only public contract, and a sample class is dead weight. The empty `lib/src/` directory will be repopulated by the package's owning epic — git will not track it until then; that is correct.
  - [x] 2.5 **Delete the generated stub test:** remove `test/<name>_test.dart`. It references the deleted `_base.dart`, and koel rejects "fake tests" (per §6 + Story 1.1 anti-patterns). The `test/` directory becomes empty; later stories add real tests.
  - [x] 2.6 **Add a placeholder `LICENSE` file** at the package root containing exactly one line:
        ```
        MIT — full license text added in Story 1.6 (FR-H5).
        ```
        `dart create` does not generate a `LICENSE`. Story 1.6 owns the byte-identical MIT copies attributed to "2026 Si Huynh"; this placeholder satisfies AC4 ("placeholder ... content finalized in Story 1.6").
  - [x] 2.7 **Leave generated `README.md` and `CHANGELOG.md` as-is.** They are placeholder content from `dart create` and satisfy AC4 ("placeholder ... content finalized in Story 1.6"). Do NOT hand-edit them in this story — Story 1.6 owns the README quality bar (PRD §13 D-1).
  - [x] 2.8 **Leave generated `analysis_options.yaml` as-is.** It will include `package:lints/recommended.yaml` (Dart team default, NOT `very_good_analysis` — verify via §3.x). Story 1.4 replaces every non-lints package's `analysis_options.yaml` with `include: package:koel_lints/koel.yaml`; do not pre-empt that work here.
  - [x] 2.9 **Leave the per-package `.gitignore`** generated by `dart create` (covers `.dart_tool/`, `pubspec.lock`, `build/`). It is redundant with the root `.gitignore` (Story 1.1) but harmless; deleting it is acceptable cleanup but not required.

- [x] **Task 3 — Scaffold the 3 Flutter packages** (AC: 1, 2, 3, 4)
  - [x] 3.1 For each of `koel_flutter`, `koel_widgets`, `koel_devtools`, run from the **repo root**:
        ```bash
        flutter create --template=package --org dev.koel --no-pub packages/<name>
        ```
        `flutter create` does not expose a `--force` flag — if it refuses because the directory is non-empty, **delete only the stub `pubspec.yaml`** (`rm packages/<name>/pubspec.yaml`) before re-running, then proceed to §3.2. **Do not delete `.gitignore`d state like `.dart_tool/`.** `--no-pub` skips the implicit `flutter pub get` for the same reason as §2.1.
  - [x] 3.2 Re-write `packages/<name>/pubspec.yaml` to the Flutter-aware workspace shape. Note the additional `flutter: ">=3.27.0"` constraint (placeholder pending Story 1.6 reconciliation against AR-25 / PRD N-10):
        ```yaml
        name: <name>
        description: <verbatim from §1.2 mapping>
        version: 0.0.1
        publish_to: none

        environment:
          sdk: ">=3.9.0 <4.0.0"
          flutter: ">=3.27.0"

        resolution: workspace
        ```
        Do NOT add `dependencies: flutter: sdk: flutter` in this story — that lands when the package starts importing Flutter symbols (Epic 6 for `koel_flutter`, Epic 7 for `koel_widgets`, Epic 8 for `koel_devtools`). Pure-skeleton stage stays dependency-free.
  - [x] 3.3 Sanitize the barrel `lib/<name>.dart` exactly as in §2.3 — remove the auto-generated `export 'src/<name>_base.dart';` and any sample widget code. Final shape: `library;` declaration with a one-line dartdoc summary; zero exports.
  - [x] 3.4 Delete `lib/<name>.dart`'s generated boilerplate body if `flutter create --template=package` emitted a sample class instead of the `_base.dart` export pattern (Flutter SDK version may vary). The contract is: barrel exists, no exports, no sample symbols.
  - [x] 3.5 Delete `lib/src/<name>_base.dart` if present (same rationale as §2.4).
  - [x] 3.6 Delete `test/<name>_test.dart` (same rationale as §2.5).
  - [x] 3.7 Add the placeholder `LICENSE` file per §2.6.
  - [x] 3.8 **Do NOT delete platform stub directories** that `flutter create --template=package` may emit (`android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/`). The package template generally does NOT create these (that is `--template=plugin`), but if any appear they are no-ops at the package level and safe to leave; later epics decide platform inclusion per AR-25 / NFR-11.
  - [x] 3.9 **`koel_devtools` deferred structure note:** Epic 8 introduces a nested `extension/devtools/` directory + `tool/extension_ui/` Flutter web app (per architecture §"koel_devtools — package + nested DevTools extension UI"). For Story 1.2, the package is a plain `flutter create --template=package` output; do NOT create the `extension/` or `tool/` subtrees here.

- [x] **Task 4 — `koel_lints` special-case note** (AC: 1, 2)
  - [x] 4.1 `koel_lints` IS scaffolded in this story via `dart create --template=package` per AC1 (not skipped). Treat it identically to the other Dart-only packages in Task 2.
  - [x] 4.2 Story 1.3 will restructure `koel_lints` into the `custom_lint` plugin shape — adding `custom_lint: ^0.8.1`, `analyzer`, `custom_lint_builder` deps; replacing `lib/koel_lints.dart` with the plugin entrypoint; introducing `lib/koel.yaml` (the analyzer profile = the public API); and creating `lib/src/rules/exhaustive_switch_must_have_default.dart` + fixture tests. **Do NOT do any of that in this story.**
  - [x] 4.3 The generated `analysis_options.yaml` for `koel_lints` will include `package:lints/recommended.yaml` (the Dart default). Story 1.3 will REPLACE it with the self-include exception G-3 (extends only `package:lints/strict.yaml` because a package cannot lint itself). Leave it alone here.

- [x] **Task 5 — Re-bootstrap workspace + verify** (AC: 1, 3)
  - [x] 5.1 Run `melos bootstrap` at the repo root. Expected: exit 0, output line `"-> 11 packages bootstrapped"`, no warnings about workspace-incompatible members. If any package fails to resolve, the most likely cause is a missing `resolution: workspace` line in its rewritten pubspec (Task §2.2 / §3.2) — fix the pubspec, do not paper over with `pubspec_overrides.yaml`.
  - [x] 5.2 Run `melos list` → all 11 members enumerated (alphabetical via Melos; matches Story 1.1 baseline).
  - [x] 5.3 In each package directory, run `dart analyze` (manually, since the `melos run analyze` script is still a stub per Story 1.1 — Story 1.4 wires it). Expected: 0 errors / 0 warnings on every package. Document any analyzer output in Completion Notes — generated `dart create` / `flutter create` skeletons are clean against `package:lints/recommended.yaml`.
  - [x] 5.4 Verify AC3 hygiene rules with a single grep from repo root: `grep -rn very_good_analysis packages/` MUST return zero matches. If a hit appears, find which `dart create` template injected it and remove the line from that package's `pubspec.yaml` — this is the AR-1 ban.
  - [x] 5.5 Verify AC4 file presence with a shell loop from repo root:
        ```bash
        for p in koel koel_core koel_http koel_lints koel_agno koel_langgraph koel_runtime koel_flutter koel_widgets koel_devtools koel_test; do
          for f in pubspec.yaml README.md CHANGELOG.md LICENSE lib/$p.dart; do
            test -f packages/$p/$f || echo "MISSING: packages/$p/$f"
          done
        done
        ```
        Expected: zero `MISSING:` lines.
  - [x] 5.6 Verify AC2 ("re-exports nothing yet") with: `grep -nE "^\s*export\s" packages/*/lib/*.dart`. Expected: zero matches.
  - [x] 5.7 Verify the `_base.dart` sample files were deleted: `find packages -path '*lib/src/*_base.dart'`. Expected: empty output.

## Dev Notes

### Critical architectural anchors

- **AR-2 (Per-package scaffold):** Dart-only packages via `dart create --template=package`; Flutter packages via `flutter create --template=package`. `koel_lints` uses non-standard structure (`custom_lint` + `custom_lint_builder` conventions under `lib/src/rules/`) — but that restructure lands in Story 1.3, NOT here. No mason brick at v1 (conventions not yet stable; over-engineering for a 10-package one-off). [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md:126`]
- **AR-1 (very_good_analysis ban):** Bundled `package:very_good_analysis` conflicts with `koel_lints` and is banned everywhere in the repo. The Dart team's `package:lints` (`recommended.yaml` / `strict.yaml`) is fine and is what `dart create` ships by default. [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md:125` + Story 1.1 Dev Notes]
- **D1 (Dart SDK floor):** Dart 3.9.0+. Story 1.1 set this in the workspace root + 11 stub pubspecs; this story preserves it in every regenerated pubspec. [Source: `_bmad-output/planning-artifacts/architecture.md` §"D1 — Dart SDK floor"]
- **AR-25 (Flutter SDK floor deferral):** Story 1.2's AC pins `flutter: ">=3.27.0"` as a placeholder, identical to Story 1.1's stubs. PRD §10.3 N-10 will be reconciled to Flutter 3.33.0+ (first stable that bundles Dart 3.9) in Story 1.6 / 9.7. Do NOT raise to 3.33.0 in this story — keep desynced from PRD intentionally until 1.6 owns the reconciliation. [Source: `_bmad-output/planning-artifacts/epics/requirements-inventory.md:158` + Story 1.1 Dev Notes §"Flutter SDK floor"]
- **Convention §2 (barrel = 1.x contract):** Every package has exactly one barrel at `lib/<package_name>.dart` that re-exports the public API. Nothing outside the barrel is public. `lib/src/` is private by convention. For Story 1.2, every barrel is **empty** (no exports) because no public symbols exist yet. [Source: `_bmad-output/planning-artifacts/architecture.md` §"Implementation Patterns" §2]
- **Codegen artifact policy (Convention §1):** `*.g.dart`, `*.freezed.dart`, `*.mocks.dart` are gitignored, never committed. Story 1.1 set this up at repo root; this story does not generate any of these artifacts (no `freezed` types yet). [Source: `_bmad-output/planning-artifacts/architecture.md` §"Implementation Patterns" §1]
- **Foundation lock-step boundary:** `koel_core` + `koel_http` + `koel_lints` ship together with identical semver. Backend bridges / Flutter packages range-depend on these (`^X.Y.0`). For Story 1.2 this is not yet exercised (no dependencies declared), but the package SET created here is the ship surface for v1.0.0. [Source: `_bmad-output/planning-artifacts/architecture.md` §"Architectural boundaries"]

### Library/version pins (already decided — do not re-evaluate)

| Item | Version | Decision ref |
|---|---|---|
| Dart SDK floor | `>=3.9.0 <4.0.0` | D1, AR-3, PRD N-9 |
| Flutter SDK floor (story-1.2 placeholder) | `>=3.27.0` | Story 1.1 / 1.2 ACs — reconciled in Story 1.6 / 9.7 per AR-25 (final 3.33.0+ per PRD N-10) |
| Melos | `7.8.0` (pinned, dev-dep `^7.8.0`) | AR-1, AR-3, PRD §10.3 N-9 — already set by Story 1.1 |
| Analyzer profile (transient) | `package:lints/recommended.yaml` (default from `dart create`) | Story 1.4 replaces with `package:koel_lints/koel.yaml` per AR-3 |

**No runtime / dev dependencies are added in this story.** Skeletons stay dep-free. Later stories declare deps as they introduce code:

- Story 1.3 → `koel_lints`: `custom_lint`, `analyzer`, `custom_lint_builder`
- Story 1.4 → every non-lints package: dev-dep `koel_lints` (path), `custom_lint`
- Story 2.1+ → `koel_core`: `freezed`, `freezed_annotation`, `json_annotation`, `json_serializable`, `build_runner`, `test`, `coverage`, `meta`
- Story 4.x → `koel_http`: `http`, `web`, transport-specific deps
- Story 6.x → `koel_flutter`: `flutter` sdk, `hive`, `flutter_secure_storage`
- etc.

### Existing repo state (verified before story creation)

After Story 1.1 (commit `2b4b250`), `packages/` contains 11 directories, each with **only** a stub `pubspec.yaml`:

```
packages/
├── koel/                    (Dart-only meta)
├── koel_agno/               (Dart-only)
├── koel_core/               (Dart-only)
├── koel_devtools/           (Flutter)
├── koel_flutter/            (Flutter)
├── koel_http/               (Dart-only)
├── koel_langgraph/          (Dart-only)
├── koel_lints/              (Dart-only)
├── koel_runtime/            (Dart-only)
├── koel_test/               (Dart-only)
└── koel_widgets/            (Flutter)
```

Each stub `pubspec.yaml` declares: `name`, `description`, `version: 0.0.1`, `publish_to: none`, `environment.sdk: ">=3.9.0 <4.0.0"` (+ `flutter: ">=3.27.0"` for the 3 Flutter pkgs), `resolution: workspace`. **The descriptions are the canonical source** — preserve them verbatim per Task §1.2's mapping when rewriting pubspecs after scaffolding.

The workspace `pubspec.yaml` lists all 11 paths in the `workspace:` array. No `pubspec_overrides.yaml` files exist anywhere (Dart pub workspace native resolution per Story 1.1 finding). The `melos.yaml` config + 7 script stubs (in `pubspec.yaml > melos.scripts`) are untouched by this story.

There is one IntelliJ `melos_<name>.iml` file in each package directory (Melos auto-generated for IDE integration). They are gitignored (`*.iml` in root `.gitignore`) and harmless. Do not delete; they will regenerate.

### `dart create --template=package` — what it produces (verify against your toolchain)

For Dart SDK 3.9.0+, `dart create --template=package <name>` typically emits:

```
<name>/
├── .gitignore                  # per-package; redundant with root .gitignore (harmless)
├── CHANGELOG.md                # boilerplate ("## 0.0.1 - Initial version")
├── README.md                   # boilerplate ("A starter Dart package...")
├── analysis_options.yaml       # include: package:lints/recommended.yaml
├── pubspec.yaml                # name, description, version, environment, dev_deps (lints, test)
├── lib/
│   ├── <name>.dart             # library declaration + `export 'src/<name>_base.dart';`
│   └── src/
│       └── <name>_base.dart    # sample class (`class Calculator { ... }` historically)
└── test/
    └── <name>_test.dart        # sample test against the sample class
```

**What the AC requires you to remove or modify:**
- `pubspec.yaml` — rewrite per Task §2.2 (preserve description, add `publish_to: none` + `resolution: workspace`, strip the `dev_dependencies: lints / test` block that `dart create` adds — Story 1.4 / 2.1 add real dev deps).
- `lib/<name>.dart` — strip the `export 'src/<name>_base.dart';` line (Task §2.3); the file remains as an empty placeholder barrel.
- `lib/src/<name>_base.dart` — delete (Task §2.4).
- `test/<name>_test.dart` — delete (Task §2.5).

**What you keep as-is (Story 1.6 owns finalization):**
- `README.md`, `CHANGELOG.md`, `analysis_options.yaml`, per-package `.gitignore`.

**What you add:**
- `LICENSE` placeholder file (Task §2.6).

### `flutter create --template=package` — what it produces

Similar to `dart create --template=package` but Flutter-flavored. Differences to be aware of:

- `pubspec.yaml` declares `flutter: ">=X.Y.Z"` env constraint and `dependencies: flutter: sdk: flutter` + `dev_dependencies: flutter_test: sdk: flutter`. **You strip both** in Task §3.2 — pure skeleton in this story has no Flutter dependency yet.
- `lib/<name>.dart` may directly contain a sample widget class instead of the `_base.dart` export pattern. Sanitize identically (Task §3.3 / §3.4): keep the file, remove all sample symbols, leave one-line dartdoc + `library;` declaration only.
- `--template=package` does NOT generate platform stub directories (`android/`, `ios/`, etc.) — those are for `--template=plugin`. If your Flutter SDK version emits them anyway, leave them; later epics decide platform support per AR-25 / NFR-11.
- `--org` flag: pass `--org dev.koel` for consistency (only affects platform stub bundle IDs if generated, irrelevant for pure package template — but Flutter sometimes warns without it).

### Pubspec key order (matches Story 1.1 stubs — keep identical across all 11)

```yaml
name: <package_name>
description: <one-line summary, snake_case package name embedded if natural>
version: 0.0.1
publish_to: none

environment:
  sdk: ">=3.9.0 <4.0.0"
  # Flutter packages only — placeholder pending Story 1.6 / AR-25 reconciliation:
  flutter: ">=3.27.0"

resolution: workspace
```

Blank line between `publish_to:` and `environment:`. Blank line between `environment:` block and `resolution:`. No `dependencies:` or `dev_dependencies:` blocks in this story. 2-space indentation. No comments restating keys (per NFR-16 / Convention §6).

### File structure requirements

After Story 1.2 ships, each Dart-only package looks like:

```
packages/<name>/
├── .gitignore                  # per-package, from `dart create` (redundant w/ root, harmless)
├── CHANGELOG.md                # placeholder, finalized in Story 1.6
├── LICENSE                     # NEW — one-line placeholder, finalized in Story 1.6
├── README.md                   # placeholder, finalized in Story 1.6
├── analysis_options.yaml       # include: package:lints/recommended.yaml (replaced in Story 1.4)
├── pubspec.yaml                # workspace-aware, no deps
├── lib/
│   └── <name>.dart             # empty barrel: dartdoc + `library;` only, zero exports
└── test/                       # empty (sample test deleted)
```

Each Flutter package looks identical, with `flutter: ">=3.27.0"` added to `environment:`. **No `dependencies: flutter: sdk: flutter` block yet.**

The `lib/src/` directory does NOT exist after this story (its sample `_base.dart` was deleted and git does not track empty directories). The package's owning epic will populate `lib/src/` when real source lands.

**Out of scope for Story 1.2** (do NOT create / modify in this story):
- Any file under `lib/src/` of any package (later stories).
- Any `koel_lints` custom_lint structure (Story 1.3).
- Any `analysis_options.yaml` change to include `package:koel_lints/koel.yaml` (Story 1.4).
- Any `koel_devtools/extension/` or `koel_devtools/tool/extension_ui/` directory (Epic 8).
- Any `example/` directory (later epics + Story 9.2 sample app).
- Repo-root `README.md` / `CONTRIBUTING.md` / `LICENSE` / `CHANGELOG.md` (Story 1.6).
- Repo-root `analysis_options.yaml` (Story 1.4 — depends on Story 1.3).
- `.github/workflows/*` (Story 1.5).
- `koel` meta-package barrel re-exports (Story 9.1; for now it is an empty barrel).
- Any `dependencies:` / `dev_dependencies:` in any pubspec (later stories).
- Reserving the 11 `koel*` names on pub.dev (Story 1.6 / FR-H4).

### `koel_lints` is a normal `dart create` in this story — DO NOT pre-empt Story 1.3

`koel_lints` AC1 explicitly enumerates it in the `dart create --template=package` list. The non-standard `custom_lint` plugin shape (`lib/koel.yaml` profile, `lib/koel_lints.dart` entrypoint, `lib/src/rules/`, fixture tests, the self-include G-3 analysis_options exception) lands entirely in Story 1.3. Touching any of it here creates merge conflicts when 1.3 runs and violates story boundary discipline.

What you produce for `koel_lints` in this story:
- `dart create --template=package --force --no-pub packages/koel_lints`
- Apply Task §2.2 – §2.7 identically to other Dart-only packages.
- The empty barrel `lib/koel_lints.dart` (no exports) is correct for now. Story 1.3 replaces it with the `custom_lint` plugin entrypoint.

### `koel` meta-package — empty barrel for now

The `koel` meta-package's job is to re-export `koel_core` + `koel_http` + `koel_flutter` as a 1-stop quickstart import (per architecture §"`koel` meta-package"). That barrel content lands in **Story 9.1** (`9-1-koel-meta-package-versioning`). For Story 1.2:

- `dart create --template=package --force --no-pub packages/koel`
- Apply Task §2.2 – §2.7 identically.
- `lib/koel.dart` final shape: one-line dartdoc + `library;`. Zero exports. Same as every other package's barrel in this story.

### Anti-patterns to reject in review

- ❌ Including `very_good_analysis` anywhere (banned by AR-1; CI grep will catch).
- ❌ Adding `dependencies:` or `dev_dependencies:` to any pubspec in this story (later stories own per-package deps).
- ❌ Adding `include: package:koel_lints/koel.yaml` to any `analysis_options.yaml` (Story 1.4 owns this).
- ❌ Adding custom_lint deps or restructuring `koel_lints` (Story 1.3 owns this).
- ❌ Hand-editing `README.md` or `CHANGELOG.md` content beyond what `dart create` generated (Story 1.6 owns quality bar).
- ❌ Adding a real MIT `LICENSE` text (Story 1.6 owns the byte-identical copies attributed to "2026 Si Huynh").
- ❌ Leaving the `lib/src/<name>_base.dart` sample file in place (defeats AC2's "barrel re-exports nothing yet" intent; samples are dead weight).
- ❌ Leaving the `test/<name>_test.dart` sample in place (koel rejects fake tests; the test will fail once the `_base.dart` it tests is deleted).
- ❌ Adding `export 'src/<name>_base.dart';` back to any barrel (AC2 explicitly mandates no exports yet).
- ❌ Pinning Flutter to 3.33.0+ in this story (AR-25 reconciliation belongs to Story 1.6).
- ❌ Adding `pubspec_overrides.yaml` to any package — Dart pub workspace handles resolution natively (Story 1.1 finding).
- ❌ Committing the `melos_<name>.iml` IDE files if they regenerate post-bootstrap (already gitignored; verify `git status` is clean).
- ❌ Raising the Dart SDK floor above `>=3.9.0 <4.0.0` (locked by D1).
- ❌ Removing `resolution: workspace` from any package's pubspec (breaks workspace resolution).
- ❌ Removing `publish_to: none` from any pubspec (would mark packages publishable before Story 1.6's pub.dev reservation).
- ❌ Multi-paragraph comments in YAML or dart files restating obvious key meanings (NFR-16 / Convention §6).

### Testing requirements

This story is structural scaffolding; verification is operational, not unit-tested:

- `melos bootstrap` exit code 0 + "11 packages bootstrapped" output (Task §5.1).
- `melos list` enumerates all 11 members (Task §5.2).
- `dart analyze` clean on every package (Task §5.3) — `dart create`'s `package:lints/recommended.yaml` baseline + an empty barrel + empty `lib/src/` + empty `test/` should produce zero diagnostics.
- `grep -rn very_good_analysis packages/` returns zero matches (Task §5.4).
- File-presence loop returns zero `MISSING:` lines (Task §5.5).
- Zero `export` directives in any `packages/*/lib/*.dart` barrel (Task §5.6).
- Zero `*_base.dart` files anywhere under `packages/*/lib/src/` (Task §5.7).

No Dart unit tests are added in this story (no source to test). The `melos run test` script is still a `dart --version` stub from Story 1.1 — Story 2.15 wires the real test runner.

### Architecture compliance — what this story enables for later

- Story 1.3 will populate `packages/koel_lints/` with the `custom_lint` plugin structure, replacing the empty barrel and adding the principal `exhaustive_switch_must_have_default` rule. Without Story 1.2's `koel_lints` scaffold landing first, 1.3 has no package to modify.
- Story 1.4 will add `include: package:koel_lints/koel.yaml` to every non-lints package's `analysis_options.yaml` and add `koel_lints` as a path-dependency in dev_dependencies. This depends on every package having an `analysis_options.yaml` (✅ generated here by `dart create`) and a `pubspec.yaml` with a `dev_dependencies:` block to extend.
- Story 2.1+ (Epic 2) populates `koel_core/lib/src/` with the sealed `AgUiEvent` root, the 4-stage pipeline, the reducer, etc. The empty barrel + empty `lib/src/` left by this story is the canvas.
- Story 4.1+ (Epic 4) populates `koel_http/lib/src/` with the SSE parser + HTTP transport + interceptors.
- Story 6.1+ (Epic 6) adds the real Flutter dependency block (`flutter: sdk: flutter`) to `koel_flutter/pubspec.yaml` when the `KoelChatController` lands.
- Story 9.1 fills `koel/lib/koel.dart` with the 3 re-exports (`koel_core`, `koel_http`, `koel_flutter`) and finalizes meta-package versioning lock-step.

### Git intelligence

- Last commit on `main`: `2b4b250 chore(story-1.1): bootstrap Dart pub workspace + Melos 7.8.0` — set up workspace root + 11 stub `pubspec.yaml` files + workspace `pubspec.lock`. No source code anywhere. This is the baseline for Story 1.2.
- Working tree is clean as of story creation (`git status` reports nothing to commit).
- Previous story (1.1) Completion Notes documented the Melos 7.x scripts-location quirk (scripts live in `pubspec.yaml > melos.scripts`, not `melos.yaml > scripts`). That quirk is irrelevant to this story — you do not touch `melos.scripts` here — but worth noting if `melos run` invocations behave unexpectedly during verification.
- Previous story Review Findings deferred `koel_lints` wiring (Story 1.3), shared `analysis_options.yaml` (Story 1.4), CI workflows (Story 1.5), root docs (Story 1.6), and Flutter floor reconciliation (Story 1.6) — same boundary discipline applies here.

### Latest tech notes (verify at implementation time)

- **`dart create --template=package`:** Dart SDK 3.9+ produces the structure described in §"`dart create --template=package` — what it produces". If your toolchain emits a slightly different shape (e.g., sample class is `<name>_base.dart` vs inline in `<name>.dart`), the sanitization rules in Tasks §2.3 – §2.5 still apply: barrel exists with zero exports; `lib/src/` sample removed; stub test removed.
- **`flutter create --template=package`:** Flutter 3.27+ produces a Dart-package-like structure (no platform dirs). Confirm `flutter --version` reports `>=3.27.0` before scaffolding (Task §1.1).
- **Melos 7.8.0 workspace interaction:** `dart create` / `flutter create` with `--no-pub` does not invoke `dart pub get` or interact with workspace resolution. Re-bootstrap is one `melos bootstrap` at the end (Task §5.1). If you forget `--no-pub`, the implicit `dart pub get` may fail or warn about workspace mismatch — re-running `melos bootstrap` after the fact corrects the lock state.
- **Pub workspace docs:** https://dart.dev/tools/pub/workspaces — the `resolution: workspace` line on each member is the contract.

### Project Structure Notes

- **Alignment:** Matches architecture §"Project Structure & Boundaries" — 11 packages under `packages/`, each a publishable skeleton with the single barrel at `lib/<name>.dart`. Conventions §1 (snake_case filenames) and §2 (barrel = public contract, `lib/src/` private) are satisfied.
- **Detected conflicts:** None. AC1's enumeration of 11 names matches the workspace array in root `pubspec.yaml` and Story 1.1's stubs.
- **Variances from architecture target state** (intentional, bounded — closed by later stories):
  - `lib/src/` directories are empty / non-existent after this story. Closed as each owning epic populates source.
  - `analysis_options.yaml` includes `package:lints/recommended.yaml`, not `package:koel_lints/koel.yaml`. Closed by Story 1.4.
  - `koel_lints` is a plain `dart create` skeleton, not the custom_lint plugin shape. Closed by Story 1.3.
  - `koel` meta-package barrel has zero exports. Closed by Story 9.1.
  - No `LICENSE` content (just placeholder line). Closed by Story 1.6.
  - Flutter floor is `>=3.27.0`, not the PRD N-10 target `>=3.33.0`. Closed by Story 1.6 / 9.7 per AR-25.

### References

- [Story 1.2 acceptance criteria source: `_bmad-output/planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md` §"Story 1.2"](../planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md#story-12-scaffold-the-ten-publishable-packages)
- [Architecture §"Project Scaffolding Approach" — Option 4 rationale + initialization commands: `_bmad-output/planning-artifacts/architecture.md` lines 131-242](../planning-artifacts/architecture.md)
- [Architecture §"Implementation Patterns" §1 (naming/layout), §2 (barrel/private discipline), §6 (docs/tests): `_bmad-output/planning-artifacts/architecture.md` lines 386-649](../planning-artifacts/architecture.md)
- [Architecture §"Project Structure & Boundaries" — repo layout + per-package variations: `_bmad-output/planning-artifacts/architecture.md` lines 651-930](../planning-artifacts/architecture.md)
- [Requirements inventory AR-1, AR-2, AR-3, AR-25: `_bmad-output/planning-artifacts/epics/requirements-inventory.md` lines 125-158](../planning-artifacts/epics/requirements-inventory.md)
- [PRD §10.3 N-9 (Dart 3.9.0+) and N-10 (Flutter 3.33.0+ — placeholder 3.27.0 here): `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md`](../planning-artifacts/prds/prd-koel-2026-05-27/prd.md)
- [Story 1.1 implementation record (workspace baseline this story builds on): `_bmad-output/implementation-artifacts/1-1-workspace-bootstrap.md`](./1-1-workspace-bootstrap.md)
- [Deferred work tracking (cross-story scope boundaries): `_bmad-output/implementation-artifacts/deferred-work.md`](./deferred-work.md)
- [Dart `dart create` reference: https://dart.dev/tools/dart-create](https://dart.dev/tools/dart-create)
- [Flutter `flutter create` reference: https://docs.flutter.dev/reference/flutter-cli](https://docs.flutter.dev/reference/flutter-cli)
- [Pub workspaces: https://dart.dev/tools/pub/workspaces](https://dart.dev/tools/pub/workspaces)

## Dev Agent Record

### Agent Model Used

claude-opus-4-7 (Claude Code, `/bmad-dev-story` workflow + `/agent-flutter-engineer` specialist)

### Debug Log References

- **Toolchain at scaffold time:** Dart SDK 3.12.0 (stable, macos_arm64) + Flutter 3.44.0 (channel stable, framework 559ffa3f75). Both clear the AC3/§1.1 floors (`>=3.9.0` Dart, `>=3.27.0` Flutter).
- **Baseline `melos bootstrap` (pre-scaffold):** exit 0, `"-> 11 packages bootstrapped"`. Workspace confirmed green before any `dart create` / `flutter create` ran.
- **Post-scaffold `melos bootstrap`:** exit 0, `"-> 11 packages bootstrapped"`. No workspace warnings; native pub workspace resolution intact.
- **`melos list`:** 11 members alphabetical (koel, koel_agno, koel_core, koel_devtools, koel_flutter, koel_http, koel_langgraph, koel_lints, koel_runtime, koel_test, koel_widgets) — matches AC1 enumeration.
- **§5.4 `grep -rn very_good_analysis packages/`:** zero matches. AR-1 ban holds.
- **§5.5 file-presence loop:** zero `MISSING:` lines across all 11 packages × 5 required files.
- **§5.6 `grep -nE '^\s*export\s' packages/*/lib/*.dart`:** zero matches. All 11 barrels are `library;`-only.
- **§5.7 `find packages -path '*lib/src/*_base.dart'`:** empty. No `lib/src/` directory exists in any package post-scaffold.
- **Pubspec round-trip:** All 11 `pubspec.yaml` files were rewritten verbatim to the §1.2 description mapping + §2.2 / §3.2 workspace shape. Result: byte-identical to the Story 1.1 commit (`2b4b250`), so `git status` shows pubspecs unmodified — the round-trip is the point, not a regression.

### Completion Notes List

- **§5.3 `dart analyze` per package — one expected warning each, documented per §5.3 contract.** Every Dart-only package emits exactly one `include_file_not_found` warning against `package:lints/recommended.yaml`; every Flutter package emits the same against `package:flutter_lints/flutter.yaml`. Root cause: §2.2 / §3.2 mandate stripping the `dev_dependencies` block (`lints` / `flutter_test` / `flutter_lints`) — so the analyzer cannot resolve the include the generated `analysis_options.yaml` still references. The story author's §5.3 expectation of "0 errors / 0 warnings" assumed dev_dependencies were preserved; that expectation conflicts with §2.2's hard ban ("Do NOT add any `dependencies:` / `dev_dependencies:` blocks in this story"). I honored §2.2 (explicit, AC-grade) and documented the warning per §5.3's escape hatch ("Document any analyzer output in Completion Notes"). Closed by Story 1.4, which replaces every `analysis_options.yaml` with `include: package:koel_lints/koel.yaml` per AR-3.
- **Flutter `LICENSE` overwrite, not append.** `flutter create --template=package` (unlike `dart create`) emits a `LICENSE` file with content `TODO: Add your license here.`. Per §3.7 → §2.6 the placeholder content is the one-line `MIT — full license text added in Story 1.6 (FR-H5).` — so the 3 Flutter packages' `LICENSE` files were overwritten (not skipped) to match the 8 Dart packages byte-for-byte. Story 1.6 owns the byte-identical MIT replacement.
- **Flutter `--no-pub` still emits `pubspec.lock`.** Confirmed for all 3 Flutter packages. `pubspec.lock` is gitignored at repo root via `packages/*/pubspec.lock` (Story 1.1), so it does not enter version control. Left in place — `melos bootstrap` regenerates it from workspace state.
- **Flutter `.metadata` file kept.** `flutter create --template=package` emits `.metadata` (declared "version controlled" in its own header) for `koel_flutter`, `koel_widgets`, `koel_devtools`. Story is silent; left in place under "Flutter-specific generated artifact is safe to leave" precedent from §3.8.
- **Flutter `.idea/` directories kept (gitignored).** Each `flutter create` emits a `.idea/` directory with IntelliJ scaffolding. Root `.gitignore` excludes `.idea/`, so they do not enter version control — left in place.
- **`example/` directory deleted (Dart 3.12 emits one).** Dart 3.12.0's `dart create --template=package` adds `example/<name>_example.dart` referencing the sample `_base.dart`. Story Dev Notes explicitly list `example/` as Out of scope ("Any `example/` directory — later epics + Story 9.2 sample app"). All 8 Dart packages had `example/` removed after scaffolding. Flutter templates did not emit `example/`.
- **`flutter create --org dev.koel`.** Passed per §3.1 for consistency; package-template output emits no platform stub dirs so the org flag affects nothing at this stage. Confirmed `android/`, `ios/`, etc. are absent post-scaffold (matches §3.8 "package template does NOT create these").
- **`koel_lints` handled identically to other Dart packages (Task 4 ACs).** No `custom_lint` deps added, no `lib/koel.yaml` profile created, no rule files written, `analysis_options.yaml` left as generated. Story 1.3 owns all of that.
- **`koel` meta-package barrel left empty (Task 4 / Dev Notes §"koel meta-package").** Zero exports per AC2; Story 9.1 will populate with `koel_core` + `koel_http` + `koel_flutter` re-exports.

### File List

**New files (69 total — 8 Dart packages × 6 files + 3 Flutter packages × 7 files; Flutter pkgs include `.metadata`):**

- `packages/koel/.gitignore` (from `dart create`; redundant with root `.gitignore`, harmless)
- `packages/koel/CHANGELOG.md` (placeholder, from `dart create`)
- `packages/koel/LICENSE` (one-line placeholder, written by this story)
- `packages/koel/README.md` (placeholder, from `dart create`)
- `packages/koel/analysis_options.yaml` (from `dart create`; includes `package:lints/recommended.yaml`)
- `packages/koel/lib/koel.dart` (empty barrel: dartdoc + `library;`)
- `packages/koel_core/.gitignore`
- `packages/koel_core/CHANGELOG.md`
- `packages/koel_core/LICENSE`
- `packages/koel_core/README.md`
- `packages/koel_core/analysis_options.yaml`
- `packages/koel_core/lib/koel_core.dart`
- `packages/koel_http/.gitignore`
- `packages/koel_http/CHANGELOG.md`
- `packages/koel_http/LICENSE`
- `packages/koel_http/README.md`
- `packages/koel_http/analysis_options.yaml`
- `packages/koel_http/lib/koel_http.dart`
- `packages/koel_lints/.gitignore`
- `packages/koel_lints/CHANGELOG.md`
- `packages/koel_lints/LICENSE`
- `packages/koel_lints/README.md`
- `packages/koel_lints/analysis_options.yaml`
- `packages/koel_lints/lib/koel_lints.dart`
- `packages/koel_agno/.gitignore`
- `packages/koel_agno/CHANGELOG.md`
- `packages/koel_agno/LICENSE`
- `packages/koel_agno/README.md`
- `packages/koel_agno/analysis_options.yaml`
- `packages/koel_agno/lib/koel_agno.dart`
- `packages/koel_langgraph/.gitignore`
- `packages/koel_langgraph/CHANGELOG.md`
- `packages/koel_langgraph/LICENSE`
- `packages/koel_langgraph/README.md`
- `packages/koel_langgraph/analysis_options.yaml`
- `packages/koel_langgraph/lib/koel_langgraph.dart`
- `packages/koel_runtime/.gitignore`
- `packages/koel_runtime/CHANGELOG.md`
- `packages/koel_runtime/LICENSE`
- `packages/koel_runtime/README.md`
- `packages/koel_runtime/analysis_options.yaml`
- `packages/koel_runtime/lib/koel_runtime.dart`
- `packages/koel_test/.gitignore`
- `packages/koel_test/CHANGELOG.md`
- `packages/koel_test/LICENSE`
- `packages/koel_test/README.md`
- `packages/koel_test/analysis_options.yaml`
- `packages/koel_test/lib/koel_test.dart`
- `packages/koel_flutter/.gitignore` (from `flutter create`)
- `packages/koel_flutter/.metadata` (from `flutter create`; Flutter tool-tracked, intentionally version-controlled per its own header)
- `packages/koel_flutter/CHANGELOG.md`
- `packages/koel_flutter/LICENSE` (overwritten over `flutter create`'s `TODO:` placeholder)
- `packages/koel_flutter/README.md`
- `packages/koel_flutter/analysis_options.yaml` (includes `package:flutter_lints/flutter.yaml`)
- `packages/koel_flutter/lib/koel_flutter.dart`
- `packages/koel_widgets/.gitignore`
- `packages/koel_widgets/.metadata`
- `packages/koel_widgets/CHANGELOG.md`
- `packages/koel_widgets/LICENSE`
- `packages/koel_widgets/README.md`
- `packages/koel_widgets/analysis_options.yaml`
- `packages/koel_widgets/lib/koel_widgets.dart`
- `packages/koel_devtools/.gitignore`
- `packages/koel_devtools/.metadata`
- `packages/koel_devtools/CHANGELOG.md`
- `packages/koel_devtools/LICENSE`
- `packages/koel_devtools/README.md`
- `packages/koel_devtools/analysis_options.yaml`
- `packages/koel_devtools/lib/koel_devtools.dart`

**Modified files (1):**

- `_bmad-output/implementation-artifacts/sprint-status.yaml` — `1-2-scaffold-publishable-packages`: `ready-for-dev` → `in-progress` → `review`; header comment + `last_updated`.

**Round-tripped pubspecs (11 — written by this story, byte-identical to Story 1.1 commit `2b4b250`, no git diff):**

- `packages/koel/pubspec.yaml`, `packages/koel_core/pubspec.yaml`, `packages/koel_http/pubspec.yaml`, `packages/koel_lints/pubspec.yaml`, `packages/koel_agno/pubspec.yaml`, `packages/koel_langgraph/pubspec.yaml`, `packages/koel_runtime/pubspec.yaml`, `packages/koel_test/pubspec.yaml`, `packages/koel_flutter/pubspec.yaml`, `packages/koel_widgets/pubspec.yaml`, `packages/koel_devtools/pubspec.yaml`

**Gitignored generated artifacts present in working tree (NOT committed; listed for traceability):**

- `packages/*/.dart_tool/` (workspace-internal pub state; root `.gitignore` excludes `.dart_tool/`)
- `packages/koel_flutter/pubspec.lock`, `packages/koel_widgets/pubspec.lock`, `packages/koel_devtools/pubspec.lock` (root `.gitignore` excludes `packages/*/pubspec.lock`)
- `packages/koel_flutter/.idea/`, `packages/koel_widgets/.idea/`, `packages/koel_devtools/.idea/` (root `.gitignore` excludes `.idea/`)
- `packages/*/melos_*.iml` (root `.gitignore` excludes `*.iml`)

### Review Findings

Reviewed 2026-05-28 via `bmad-code-review` (Blind Hunter + Edge Case Hunter + Acceptance Auditor, parallel). Acceptance Auditor: **all ACs and tasks pass clean** — verified on working tree: 0 `export` directives in any barrel, 0 `_base.dart`, 0 `very_good_analysis`, all 11 pubspecs byte-identical to baseline `2b4b250`, file-presence loop returns 0 `MISSING:` lines, `dart analyze` produces exactly the 1 expected `include_file_not_found` warning per package documented in Completion Notes.

- [x] [Review][Patch] File-List arithmetic — line 425 said "66 total — 8 Dart × 6 files + 3 Flutter × 6 files" but the list itself shows Flutter packages with 7 files each (`.metadata` included). Corrected to `8×6 + 3×7 = 69`. [`1-2-scaffold-publishable-packages.md:425`]
- [x] [Review][Defer] CHANGELOG version header drift — 8 Dart packages ship `## 1.0.0` while pubspec versions are `0.0.1` (Dart 3.12's template default); 3 Flutter packages ship `## 0.0.1` (matches pubspec). Story Task §2.7 mandates "leave as-is" → dev correctly followed spec, but the resulting artifact contradicts itself. Story 1.6 owns CHANGELOG quality (PRD §13 D-1) and should normalize. [`packages/{koel,koel_core,koel_http,koel_lints,koel_agno,koel_langgraph,koel_runtime,koel_test}/CHANGELOG.md`]
- [x] [Review][Defer] CHANGELOG bullet-style drift — Dart pkgs use `- ` bullets, Flutter pkgs use `* `. Same root cause (template difference) — Story 1.6 normalizes. [`packages/*/CHANGELOG.md`]
- [x] [Review][Defer] Story 1.4 wording: `koel_lints` cannot be added as `path:` dev-dep — Dart pub workspace rejects path-dependencies targeting workspace members; siblings must declare a bare `koel_lints:` entry that workspace resolves. Dev Notes line 171 says "dev-dep `koel_lints` (path)" — update Story 1.4 spec wording before its implementation. [`1-2-scaffold-publishable-packages.md:171`]
- [x] [Review][Defer] Empty `test/` and absent `lib/src/` dirs are not tracked by git — a fresh clone before Story 2.x lands real tests/source has no `test/` directory. Consider `.gitkeep` per pkg to lock the directory contract, or accept the gap and let Story 2.x create on first write. Not blocking — `dart test` on a missing `test/` just outputs "No tests found." [`packages/*/test/`, `packages/*/lib/src/`]
- [x] [Review][Defer] Per-pkg Dart `.gitignore` lacks `doc/api/` — a contributor running `dart doc .` inside a Dart pkg produces untracked HTML output; Flutter pkgs already cover via `**/doc/api/`. Fold into Story 1.6 docs polish or first dev-tooling story. [`packages/{koel,koel_core,koel_http,koel_lints,koel_agno,koel_langgraph,koel_runtime,koel_test}/.gitignore`]
- [x] [Review][Defer] Scaffold-time Dart version drift — story used Dart 3.12.0 but SDK floor is 3.9.0; a contributor re-running `dart create` on Dart 3.9 may produce a different template (e.g. no `example/`, `_base.dart` shape variance). Pin scaffold-time Dart somewhere (`.tool-versions` / `.fvmrc` / `melos.yaml`) if re-scaffolding becomes a workflow. [`packages/*/`]

**Dismissed (noise / spec-compliant / handled-elsewhere):** 30+ findings, including: Flutter pkgs include `package:flutter_lints/flutter.yaml` (Task §2.8 mandates leave-as-is; Story 1.4 replaces with `koel.yaml`), `dart analyze` `include_file_not_found` warnings (Completion Notes §5.3 escape hatch + Story 1.4 swap), pubspecs absent from `git diff HEAD` (byte-identical round-trip is the point), README TODOs and sample code (Task §2.7 + Story 1.6 ownership), `LICENSE` placeholder vs pub.dev scanners (`publish_to: none` shields + Story 1.6 lands MIT), `.metadata` revision pin behavior (Flutter convention + Completion Notes line 417), commented-out lint examples in `analysis_options.yaml` (Task §2.8 + Story 1.4), bare `library;` (Task §2.3 explicit), redundant per-pkg `.gitignore` (Task §2.9 "harmless"), workspace root lacking reciprocal `resolution: workspace` (false positive — root is not a member), AC2 wording vacuously satisfied (no source yet), `koel_test` description vs empty barrel (entire story is skeleton-promises-future-content, by design).

## Change Log

| Date       | Story / Status         | Change                                                                                                                                              |
|------------|------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| 2026-05-28 | 1.2 / ready-for-dev    | Story file created by create-story workflow; sprint-status updated.                                                                                 |
| 2026-05-28 | 1.2 / review           | Scaffolded 11 publishable packages: 8 via `dart create --template=package`, 3 via `flutter create --template=package --org dev.koel`. Empty barrels (`library;` only), no `lib/src/`, no tests, no `example/`. Placeholder `LICENSE` per package. `melos bootstrap` clean (11 bootstrapped); AC1-AC4 verified. |
| 2026-05-28 | 1.2 / review           | Code review run (Blind Hunter + Edge Case Hunter + Acceptance Auditor). Auditor: all ACs pass. 1 patch (file-list arithmetic), 6 defer (Story 1.4 & 1.6 follow-ups), 30+ dismissed (spec-compliant / handled-elsewhere).                                          |
