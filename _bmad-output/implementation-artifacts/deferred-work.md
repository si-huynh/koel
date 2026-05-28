# Deferred Work

Items deferred during BMAD workflows. Each entry records why the work was postponed.

## Deferred from: code review of 1-1-workspace-bootstrap (2026-05-28)

- **koel_lints not wired to consumers** — Story 1.3 owns lint package population.
- **No shared analysis_options.yaml** — Story 1.4 depends on Story 1.3.
- **No CI workflow files for format:check/build gates** — Story 1.5 owns `.github/workflows/*`.
- **No README/CONTRIBUTING bootstrap docs** — Story 1.6 owns root docs.
- **No toolchain pin (.fvmrc / asdf)** — Story 1.5/1.6 owns contributor toolchain matrix.
- **Flutter floor 3.27.0 placeholder vs PRD 3.33.0+** — Intentional per Dev Notes; Story 1.6 reconciles AR-25.
- **melos.yaml `packages/*` can drift from root `workspace:` list** — Story 1.5 CI can add membership guard.
- **Update AC1/AC3 epic literal wording (scripts location, pubspec_overrides mechanism)** — Follow-up doc hygiene to prevent re-flagging compliant Melos 7.x variances.

## Deferred from: code review of 1-2-scaffold-publishable-packages (2026-05-28)

- **CHANGELOG version header drift** — 8 Dart packages ship `## 1.0.0` while pubspec versions are `0.0.1` (Dart 3.12 template default); 3 Flutter packages ship `## 0.0.1`. Spec mandated leave-as-is; Story 1.6 (CHANGELOG quality bar per PRD §13 D-1) should normalize headers to `0.0.1` across all 11.
- **CHANGELOG bullet-style drift** — Dart `- `, Flutter `* `. Pair into Story 1.6 normalization.
- **Story 1.4 wording: `koel_lints` cannot be added as `path:` dep across siblings** — Dart pub workspace rejects path-deps targeting workspace members; siblings must declare bare `koel_lints:`. Update Story 1.4 Dev Notes (currently line 171 of 1.2 spec mirrors a "(path)" phrasing) before 1.4 implementation.
- **Empty `test/` and absent `lib/src/` dirs not tracked by git** — fresh-clone contributors won't have `test/` until Story 2.x. Consider `.gitkeep` per pkg before Story 2.1 ships, or accept the gap.
- **Per-pkg Dart `.gitignore` lacks `doc/api/`** — `dart doc .` inside a Dart pkg generates untracked HTML; Flutter pkgs already cover via `**/doc/api/`. Fold into Story 1.6 docs polish or a dev-tooling story.
- **Scaffold-time Dart version drift** — story used Dart 3.12.0 to scaffold; SDK floor is 3.9.0. Contributor on 3.9 re-running `dart create` may produce different template output. Pin scaffold-time Dart in `.tool-versions` / `.fvmrc` / `melos.yaml` if re-scaffolding becomes a workflow.

## Deferred from: code review of 1-3-build-koel-lints-profile (2026-05-28)

- **Architecture + spec text reference nonexistent `package:lints/strict.yaml`** — file never shipped in any `lints` version (1.0.1 → 6.1.0); only `core.yaml` and `recommended.yaml` exist. AC1, AC4, Task 3.1, Task 6.1, and `architecture.md:1163` all need erratum to `recommended.yaml`. Story 1.3 Deviation 2 closed in-place.
- **AC2 enumeration missing `lints` dev_dep** — Story 1.3 AC2 listed `custom_lint_builder` + `analyzer` + `custom_lint` + `test` but not `lints`; needed to resolve the `include:` in both `analysis_options.yaml` and `koel.yaml`. Without it `dart analyze` emits `include_file_not_found` and breaks NFR-13. Deviation 1 closed in-place; spec erratum pending.
- **AC3 vs Task 8.4 wording contradiction on `// expect_lint:` signal source** — AC3 mandates `// expect_lint:` "as the test signal source"; Task 8.4 says "Pick ONE" between CLI subprocess and analyzer-driven harness. `// expect_lint:` is actually `custom_lint`'s suppression marker, not a positive-assertion convention. Story 1.3 chose `testAnalyzeAndRun` (typed `Diagnostic` list); AC text needs reconciliation.
- **`koel_lints` README oversells "Rules" (plural) for single-rule v1.0.0 + missing profile-semver policy** — defer to Story 1.6 README polish per PRD §13 D-1. Document: adding a rule = minor bump; tightening severity = major bump.
- **Caret pin `^0.8.1` on `custom_lint` / `custom_lint_builder` (0.x footgun) + no renovate/dependabot config** — 0.x minors are allowed to break; no CI matrix proving the floor. Defer to Story 1.5 CI / Story 1.6 toolchain matrix.
- **Severity downgrade + per-consumer rule-disable path not documented** — Rule hardcoded ERROR; consumers have no documented override snippet for `analysis_options.yaml`. Story 1.4 adoption docs should ship the snippet.
- **`analyzer.plugins:` merge vs override semantics for consumers unverified** — Consumer-declared `analyzer.plugins:` may silently overwrite `custom_lint` from `koel.yaml`. Story 1.4 adoption integration test should surface.
- **Diagnostic reports at `switchKeyword` (head of switch) — no IDE quick-fix** — Better UX: report at `rightBracket`/last member + ship a `DartFix` injecting `default: throw StateError(...)` (statement) / `_ => throw StateError(...)` (expression). Defer to v1.x rule polish.
- **Edge-case AST handling not covered (intentional per Dev Notes 412-416, accumulate for v1.x)** — nullable `AgUiEvent?`, typedef alias, extension type with colliding name, upcast to `Object?`, parenthesized wildcard `(_)`, `case _:` and `case Object():` catch-alls in statement form, typed wildcard `Object _` / `dynamic _` as default analog. v1.x rule refinement.
- **Fixture coverage gaps** — only `AgUiEvent` + switch-statement form + ungarded patterns covered. Missing: `KoelError`, `MessageSegment`, switch-expression form (Story 1.3 reviewer surfaced this as decision-pending; resolution flows here if deferred), nested switches in lambdas, single-file element resolution, guarded wildcard arm. v1.x test expansion.
- **Transitive `lints` dep resolution for downstream consumers** — `lints` is dev-only in `koel_lints`; downstream packages extending `package:koel_lints/koel.yaml` may not resolve `package:lints/recommended.yaml` outside the workspace. Story 1.4 adoption + Story 9.5 publish dry-run will surface.
- **`custom_lint.rules:` YAML syntax for 0.8.1 not end-to-end verified via consumer plugin path** — `testAnalyzeAndRun` bypasses plugin discovery; profile only exercised end-to-end when a consumer includes `koel.yaml` and runs `dart analyze`. Story 1.4 adoption is the integration test.
- **Diagnostic `problemMessage` hardcodes `FR-A12` jargon opaque to consumers** — rephrase in user-facing terms + move FR ref to `correctionMessage` / doc URL. v1.x rule polish.
