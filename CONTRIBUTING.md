# Contributing to koel

koel is a Melos-managed Dart pub workspace: a single git repo holding eleven
independently publishable `koel_*` packages under `packages/`. Thanks for
helping build it.

## Toolchain

- **Dart 3.9.0+** is the SDK floor (architectural decision D1 / NFR-9). The repo
  pins the exact version in [`.tool-versions`](.tool-versions) — install
  [asdf](https://asdf-vm.com) + the Dart plugin and run `asdf install`, or match
  `dart 3.9.0` with your version manager of choice. CI pins the same `3.9.0` via
  `dart-lang/setup-dart`.
- **Flutter 3.35.0+** for the Flutter packages (`koel_flutter`, `koel_widgets`,
  `koel_devtools`) — this is the Flutter release that first ships Dart 3.9.0.
- **Melos 7.8.0** orchestrates the workspace.

## Workflow

```bash
dart pub global activate melos 7.8.0   # one-time
melos bootstrap                        # link the workspace
melos run analyze                      # dart analyze . per package (must be clean)
melos run format:check                 # dart format check (read-only)
melos run test                         # per-package tests
```

`melos run format` applies formatting in place; `melos run format:check` is the
read-only CI gate — run it before pushing.

### Codegen drift

Generated files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`) are gitignored
and produced by `build_runner`. After changing any source that feeds codegen,
run `melos run build` and confirm `git diff` is clean — CI enforces this via the
`codegen-drift` workflow.

### House patterns

Reusable idioms that recur across packages live in [`docs/patterns/`](docs/patterns/).
Reach for them before reinventing transport/stream plumbing:

- [Cancel-correct stream teardown](docs/patterns/stream-cancellation.md) — the
  `StreamController + watchdog Timer + fire-and-forget teardown` shape for any
  `async*` run a consumer can `cancel()` mid-stream (NFR-8 sub-50 ms budget).

## Commits & PRs

- Conventional, story-scoped subjects: `chore(story-1.6): …`, `feat(koel_core): …`.
- Keep PRs green: `melos run analyze`, `melos run format:check`, and
  `melos run test` must all pass. The six `.github/workflows/` checks gate every PR.
- Every package follows the README quality bar (one-paragraph intro, quickstart,
  docs link, changelog link, MIT note) and ships its own `CHANGELOG.md`.

## License

By contributing you agree your contributions are licensed under the MIT License
([LICENSE](LICENSE)).
