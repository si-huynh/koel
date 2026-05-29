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

`koel_lints` v1.0.0 ships this single rule; more may follow.

### Profile semver policy

The `koel.yaml` profile is part of koel's public contract, so changes to it
follow semver:

- **Adding a new rule → minor bump.** Consumers gain enforcement; existing
  compliant code is unaffected (the new rule targets patterns the prior version
  did not flag).
- **Tightening an existing rule's severity** (e.g. `warning` → `error`) or
  broadening what it flags **→ major bump.** Previously-clean code can start
  failing `dart analyze`, so it is a breaking change.

### Opting a consumer out of a rule

A consumer can disable a rule in its own `analysis_options.yaml`:

```yaml
include: package:koel_lints/koel.yaml

custom_lint:
  rules:
    - exhaustive_switch_must_have_default: false
```

> **Caveat:** `custom_lint` 0.8.1 has a pub-workspace-mode bug where a
> `package:`-URI include chain does not resolve for workspace members, so the
> rule does not yet fire on consumer source under `melos run analyze` (this is
> tracked; `dart analyze` still exits 0). The opt-out above takes effect once
> the rule actually fires on consumers — i.e. after the upstream `custom_lint`
> workspace fix, or when consuming `koel_lints` as a published (non-workspace)
> dependency.

## Note: self-include exception (G-3)

`koel_lints` itself cannot include its own profile — a package cannot
lint itself. Its local `analysis_options.yaml` extends only
`package:lints/recommended.yaml`. Every other koel package extends
`package:koel_lints/koel.yaml`.

## Documentation

See the repo-root [README](../../README.md) for the package map. Changelog:
[CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
