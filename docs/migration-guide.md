---
id: migration-guide
title: Migration Guide
---

# Migration Guide

koel follows **semantic versioning** with a hybrid, lock-step strategy across the
ten release packages: the foundation packages share one version, and intra-repo
dependencies are ranged (`^X.Y.Z`). This page is the forward-compatibility
contract — what a minor upgrade may and may not do to your code.

## The 1.x compatibility promise

Within the `1.x` line:

- **No public symbol is removed or has its signature changed.** The public API
  is a one-way door, enforced in CI by the `dart_apitool` breaking-change gate
  (`melos run api-diff`): a removed or changed symbol fails the build. Additive
  changes (new symbols) are allowed and surface as a minor bump.
- **New event families are additive.** A future minor may add an `AgUiEvent`
  subtype. Because every `switch` over the sealed union carries a `default:`
  branch (the `exhaustive_switch_must_have_default` lint), your code keeps
  compiling — the new family routes to your default arm. This is the one place
  where the forced default pays off: you opt in to handling the new family when
  you are ready, not when the SDK ships it.
- **The session JSON wire shape is stable.** A `ChatState` persisted by `1.a` is
  readable by `1.b`. New optional fields default to their empty value on read.

## What a minor bump can change

- **Add** new public symbols, new event families, new optional parameters (with
  defaults), new interceptors and bridges.
- **Tighten internal behavior** that is not part of the public contract
  (performance, logging text, internal pipeline ordering).

A change that would break any of the promises above is a **major** bump (`2.0.0`)
— and the `api-diff` gate forces that classification rather than letting it slip
into a minor.

## Upgrading

```bash
dart pub upgrade koel koel_core koel_http koel_flutter koel_widgets
# bridges, if you use them:
dart pub upgrade koel_agno koel_langgraph koel_runtime
```

Because the foundations are lock-step versioned, upgrade them together. The
ranged (`^`) intra-repo constraints let pub resolve a consistent set; you rarely
need to pin exact versions.

## Lint profile changes

`koel_lints` is part of the public contract, so its rules follow semver too:

- **Adding a new rule → minor bump.** Existing compliant code is unaffected (the
  new rule targets patterns the prior version did not flag).
- **Tightening a rule's severity** (e.g. `warning` → `error`) or broadening what
  it flags **→ major bump**, because previously-clean code can start failing
  `dart analyze`.

To opt a consumer out of a rule, set it `false` under the plugin's
`diagnostics:` in your root `analysis_options.yaml`, or suppress a single line
with `// ignore: koel_lints/<rule>`.

## Pre-1.0 history

There is no pre-1.0 public release to migrate from — `1.0.0` is the first
published version. koel is a clean-slate implementation with no migration
obligation to any earlier package (including the community `ag_ui` 0.1.0, which it
credits but does not derive from).
