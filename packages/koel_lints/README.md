# koel_lints

Analyzer plugin enforcing koel's mandatory rules, built on the first-party
[`analysis_server_plugin`][asp] (asp) — in-SDK since Dart 3.10 / Flutter 3.38, so
it runs inside the analysis server and reports under `dart analyze` and IDEs
alike, with no separate process. (koel itself floors at Dart 3.11 — `analyzer 13`
pulls `_fe_analyzer_shared`, which requires `^3.11`.)

Inside the koel monorepo the plugin is enabled **centrally**, once, at the
workspace-root `analysis_options.yaml`:

```yaml
plugins:
  koel_lints:
    path: packages/koel_lints
    diagnostics:
      exhaustive_switch_must_have_default: true
```

`plugins:` may only appear in the workspace (or package) **root** options file —
the analyzer rejects it in any nested file. One root entry enables the rule for
every workspace member, so members carry no `analysis_options.yaml` of their own.

## Rules

- `exhaustive_switch_must_have_default` (error) — switches over
  `AgUiEvent`, `KoelError`, or `MessageSegment` must declare a `default:`
  branch. Adding a new subtype to any of these sealed unions is then a
  semver-minor bump (FR-A12 / FC-2 / NFR-17).

`koel_lints` v1.0.0 ships this single rule; more may follow.

### Profile semver policy

The plugin and the `koel.yaml` profile are part of koel's public contract, so
changes follow semver:

- **Adding a new rule → minor bump.** Consumers gain enforcement; existing
  compliant code is unaffected (the new rule targets patterns the prior version
  did not flag).
- **Tightening an existing rule's severity** (e.g. `warning` → `error`) or
  broadening what it flags **→ major bump.** Previously-clean code can start
  failing `dart analyze`, so it is a breaking change.

### Opting a consumer out of a rule

Set the rule to `false` under the plugin's `diagnostics:` in the root
`analysis_options.yaml`:

```yaml
plugins:
  koel_lints:
    path: packages/koel_lints
    diagnostics:
      exhaustive_switch_must_have_default: false
```

A single source line can also be suppressed with
`// ignore: koel_lints/exhaustive_switch_must_have_default`.

## Note: self-include exception (G-3)

`koel_lints` cannot enable its own plugin — a package cannot lint itself, and
asp would try to load the package as a plugin of its own analysis context. Its
local `analysis_options.yaml` extends only `package:lints/recommended.yaml`.
Every other koel package inherits the rule from the workspace-root options.

## External consumers

`lib/koel.yaml` is the profile for **external** consumers (those depending on a
published `koel_lints`, outside this workspace) to `include:`. External
consumers don't exist before v1.0.0, so that distribution path is verified at
Epic 9 (Story 9-5), not here.

## Documentation

See the repo-root [README](../../README.md) for the package map. Changelog:
[CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).

[asp]: https://pub.dev/packages/analysis_server_plugin
