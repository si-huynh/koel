# koel_lints

Analyzer plugin enforcing koel's mandatory rules. Consumed via
`include: package:koel_lints/koel.yaml` in any package's
`analysis_options.yaml`. Adoption across the koel monorepo is wired in
Story 1.4; pre-publish consumers reference `koel_lints` as a workspace
dependency.

## Rules

- `exhaustive_switch_must_have_default` (error) — switches over
  `AgUiEvent`, `KoelError`, or `MessageSegment` must declare a `default:`
  branch. Adding a new subtype to any of these sealed unions is then a
  semver-minor bump (FR-A12 / FC-2 / NFR-17).

## Note: self-include exception (G-3)

`koel_lints` itself cannot include its own profile — a package cannot
lint itself. Its local `analysis_options.yaml` extends only
`package:lints/recommended.yaml`. Every other koel package extends
`package:koel_lints/koel.yaml`.

## License

MIT. Full text added in Story 1.6.
