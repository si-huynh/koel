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
