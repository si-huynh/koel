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
