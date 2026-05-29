---
baseline_commit: 77482ada9c4f98c933ddf6f1ecd52e91e25c98e4
---

# Story 1.7: Migrate `koel_lints` to `analysis_server_plugin`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Why this story exists (one-paragraph context).** The lint engine chosen at planning time —
> `custom_lint` (AR-5, architecture D3) — is **dead** (`invertase/dart_custom_lint` archived
> 2026-03-24) **and** structurally incompatible with koel's native Dart pub workspace: it resolves
> rules through a per-member `.dart_tool/package_config.json` that pub workspaces never create, so
> the principal rule `exhaustive_switch_must_have_default` fired **only inside `koel_lints`' own unit
> tests — never on consumer source, in CLI or IDE**. A spike (committed `0feb93d`, full trail in
> [deferred-work.md](deferred-work.md) → Story 1.4 entry → "SPIKE FINAL VERDICT" points 1–7) proved
> the first-party **`analysis_server_plugin`** (asp; Dart team, ships in-SDK with Dart 3.10 / Flutter
> 3.38) is workspace-native by construction and the rule logic ports cleanly. This story executes the
> migration. **Supersedes the lint *mechanism* of Stories 1.3 + 1.4** (those stay `done` as historical
> record); reverses AR-5 + architecture D3; raises the Dart floor (D1); resolves retro Discovery-D4.
> **Critical-path gate: do not start Epic 2 (Story 2.1) until this is `done`.**
> Authoritative spec: [sprint-change-proposal-2026-05-29.md](../planning-artifacts/sprint-change-proposal-2026-05-29.md) §4.1.

## Story

As an OSS contributor,
I want `koel_lints` rebuilt on the first-party `analysis_server_plugin` API and wired through a
single workspace-root `analysis_options.yaml`,
so that `exhaustive_switch_must_have_default` actually fires on consumer source under `dart analyze`
+ IDEs in our native pub workspace — delivering the FR-A12 / FC-2 guarantee that `custom_lint`
(archived 2026-03-24) could not.

## Acceptance Criteria

**AC1 — Server-plugin integration fires (THE unproven piece; do this FIRST).**
**Given** the asp plugin wired at the workspace-root `analysis_options.yaml`,
**When** I run `dart analyze` on a member package containing a `switch` over a sealed `AgUiEvent`
without a `default:` branch,
**Then** `exhaustive_switch_must_have_default` is reported as an **ERROR** (and the IDE surfaces the
same diagnostic),
**And** it stays silent when a `default:` branch is present.
_The `analyzer_testing` proof (Story 1.3 spike) covers rule **logic** only; the production
server-plugin **loading** path in our workspace is the single piece not yet proven — isolate and
solve it before touching anything else. `dart analyze` (CLI) and IDE share the same enablement gate,
so proving CLI is the primary bar; IDE confirmation is a manual sanity check (restart the analysis
server first)._

**AC2 — asp plugin layout.**
**Given** `packages/koel_lints/`,
**When** I inspect the source tree,
**Then** `lib/main.dart` is a `Plugin` subclass whose `register(PluginRegistry registry)` calls
`registry.registerLintRule(ExhaustiveSwitchMustHaveDefault())`,
**And** the rule in `lib/src/rules/exhaustive_switch_must_have_default.dart` extends `AnalysisRule`
with a `LintCode(name, problemMessage, severity: DiagnosticSeverity.ERROR)`, overrides
`registerNodeProcessors` to call `registry.addSwitchStatement(this, visitor)` /
`registry.addSwitchExpression(this, visitor)`, and reports via `reportAtToken`,
**And** the old `custom_lint` entrypoint `lib/koel_lints.dart` is **removed**.

**AC3 — Dependencies.**
**Given** `packages/koel_lints/pubspec.yaml` and the 10 consumer pubspecs,
**When** I inspect dependencies,
**Then** `koel_lints` declares `analysis_server_plugin: ^0.3.15` + `analyzer: ^13.0.0`,
**And** `custom_lint` + `custom_lint_builder` are removed from `koel_lints` **and** from all 10
consumer pubspecs,
**And** no `custom_lint` / `custom_lint_builder` / `custom_lint_core` / `custom_lint_visitor` entries
remain in `pubspec.lock`.

**AC4 — Unit tests + integration check.**
**Given** the test suite,
**When** I run `dart test` in `koel_lints`,
**Then** rule unit tests via `analyzer_testing` (`AnalysisRuleTest`) fire on a no-`default:` switch
over sealed `AgUiEvent` in **both** statement and expression form and stay silent when the
`default:` / `_` arm is present,
**And** a dedicated `dart analyze` integration check covers AC1 (a fixture consumer package that
must report exactly one error).

**AC5 — Toolchain.**
**Given** the toolchain pins,
**When** I inspect `.tool-versions`, the 11 pubspecs, and CI,
**Then** `.tool-versions` pins Dart `3.12` / Flutter `3.44`,
**And** the declared floor is raised to Dart `>=3.10.0` across all 11 pubspecs and Flutter
`>=3.38.0` on the 3 Flutter packages,
**And** `pubspec.lock` re-resolves clean,
**And** the `setup-dart` `sdk:` pin in `ci.yml` and `codegen-drift.yml` is bumped to `3.12`.
_(Resolves retro Discovery-D4.)_

**AC6 — Workspace-root wiring.**
**Given** the workspace,
**When** I inspect `analysis_options.yaml` files,
**Then** a single repo-root `analysis_options.yaml` declares asp `plugins:` + `diagnostics:
{ exhaustive_switch_must_have_default: true }`, enabling the rule for all members,
**And** the per-member `include: package:koel_lints/koel.yaml` lines are removed/reconciled.
_(Closes Story 1.1's deferred "no root `analysis_options.yaml`".)_

**AC7 — Docs.**
**Given** `koel_lints/README.md` and `lib/koel.yaml`,
**When** I inspect docs,
**Then** the README reflects asp (not custom_lint), documents the opt-out via `diagnostics:
{ exhaustive_switch_must_have_default: false }`, and drops the pub-workspace-bug caveat,
**And** `lib/koel.yaml` is retained as the external-consumer profile with a note that its
`include:`-based distribution is verified at Epic 9 (Story 9-5).

**AC8 — Green baseline.**
**Given** the workspace bootstrapped,
**When** I run `melos run analyze`,
**Then** it exits 0 across all 11 packages with the rule live.

## Tasks / Subtasks

- [x] **Task 1 — Prove the server-plugin loading path (AC1, AC6). DO THIS FIRST; it gates everything.**
  - [x] 1.1 Author the repo-root `analysis_options.yaml` (see [Workspace-root wiring](#workspace-root-wiring-the-ac1ac6-crux)) with `plugins: { koel_lints: { path: packages/koel_lints } }` + `diagnostics: { exhaustive_switch_must_have_default: true }`.
  - [x] 1.2 Port `lib/main.dart` + the rule to asp (Task 2) **far enough to compile** — AC1 cannot fire without the plugin entry. (Tasks 1 and 2 interleave; this checklist orders by priority, not strict sequence.)
  - [x] 1.3 Create a throwaway probe in a real member (e.g. `packages/koel_core/lib/_probe.dart`) with a `sealed class AgUiEvent` + 3 subtypes + a `switch` lacking `default:` (mirror [missing_default.dart](../../packages/koel_lints/test/rules/fixtures/violations/missing_default.dart)). Run `dart analyze packages/koel_core` and confirm **exactly one** `exhaustive_switch_must_have_default` ERROR.
  - [x] 1.4 If it does not fire: the spike got the plugin *wired* but the rule *silent* via the server path (deferred-work point 7 ⚠️). Likely culprits — confirm each: (a) the plugin's `name` getter / package resolution; (b) `pubspec.lock` still pinning `analyzer 8.4.0` because custom_lint is not yet removed (Task 3 must land first — asp `^0.3.8`+ needs analyzer ≥10); (c) a stale analyzer/plugin cache (`dart pub get` + restart); (d) `diagnostics:` key spelling / rule name mismatch. **Do not log via `dart:io` inside the plugin isolate — it crashes the sandboxed isolate** (spike finding).
  - [x] 1.5 Add a `default:` to the probe; confirm the error clears. Delete the probe; confirm `git status` is clean of it.
- [x] **Task 2 — Rebuild `koel_lints` on the asp API (AC2).**
  - [x] 2.1 Rewrite [lib/src/rules/exhaustive_switch_must_have_default.dart](../../packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart): `extends AnalysisRule`; `LintCode` with `severity: DiagnosticSeverity.ERROR`; `registerNodeProcessors` registers a `SimpleAstVisitor` for switch statement + expression; preserve the existing `_sealedNames` type-name keying and the `_isOpenWildcard` expression-arm logic verbatim (logic is correct — see [Critical: preserve this logic](#critical-preserve-the-existing-rule-logic-verbatim)).
  - [x] 2.2 Create `lib/main.dart`: `Plugin` subclass with `String get name => 'koel_lints'` + `register(PluginRegistry registry) => registry.registerLintRule(const ExhaustiveSwitchMustHaveDefault())`.
  - [x] 2.3 Delete `lib/koel_lints.dart` (the old `createPlugin()` / `PluginBase` entry).
- [x] **Task 3 — Dependency churn (AC3). Must precede AC1 success (frees the analyzer pin).**
  - [x] 3.1 `koel_lints/pubspec.yaml`: deps `analysis_server_plugin: ^0.3.15` + `analyzer: ^13.0.0`; dev_deps `analyzer_testing: ^0.2.6` + `test: ^1.20.2` + `lints: ^6.0.0` (for the self `recommended.yaml` include); **remove** `custom_lint` + `custom_lint_builder`. Update `description` (drop "custom_lint based").
  - [x] 3.2 In all 10 consumer pubspecs (`koel`, `koel_core`, `koel_http`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`, `koel_devtools`, `koel_test`): remove the `custom_lint: ^0.8.1` dev-dep line. **Keep** the bare `koel_lints:` dev-dep (still needed as the path/workspace plugin source). _(Note: consumers no longer need any analyzer dev-dep — the rule is enabled centrally at the root.)_
  - [x] 3.3 `dart pub get` (or `melos bootstrap`); verify `pubspec.lock` drops all `custom_lint*` entries and resolves `analyzer 13.0.0` + `analysis_server_plugin 0.3.15`.
- [x] **Task 4 — Toolchain pins (AC5). Resolves Discovery-D4.**
  - [x] 4.1 `.tool-versions`: `dart 3.12` / `flutter 3.44`.
  - [x] 4.2 All 11 `packages/*/pubspec.yaml` + root `pubspec.yaml`: `environment.sdk: ">=3.10.0 <4.0.0"`.
  - [x] 4.3 The 3 Flutter pubspecs (`koel_flutter`, `koel_widgets`, `koel_devtools`): `flutter: ">=3.38.0"` (Flutter 3.38 is the release that ships Dart 3.10 — confirmed, see [Latest Tech](#latest-technical-information)).
  - [x] 4.4 `ci.yml` + `codegen-drift.yml`: `setup-dart` `sdk: 3.12`.
  - [x] 4.5 Re-`melos bootstrap`; confirm clean resolve against the raised floor.
- [x] **Task 5 — Unit tests on `analyzer_testing` (AC4).**
  - [x] 5.1 Replace [test/rules/exhaustive_switch_test.dart](../../packages/koel_lints/test/rules/exhaustive_switch_test.dart) with an `AnalysisRuleTest` subclass (see [Testing](#testing-requirements)). Use `test_reflective_loader`; set `rule` in `setUp`; register it via `Registry.ruleRegistry.registerLintRule(rule)`; assert with `assertDiagnostics(content, [lint(offset, length)])` / `assertNoDiagnostics(content)`.
  - [x] 5.2 Cover all four cases the current suite covers: statement-fires, statement-silent, expression-fires, expression-silent. Inline the fixture source as test strings (the asp harness uses in-memory content, not the `test/rules/fixtures/*.dart` files — those were custom_lint's `testAnalyzeAndRun` inputs).
  - [x] 5.3 Decide the fate of `test/rules/fixtures/*.dart`: either delete them (no longer referenced) or repurpose one pair as the AC1 `dart analyze` integration fixture. Document the choice in Completion Notes.
  - [x] 5.4 Author the AC1 integration check (Task 1.3 made permanent): a small fixture consumer + a script/test asserting `dart analyze` reports exactly one error. Wire it so CI exercises it (the `melos run analyze` green-baseline in AC8 already does, if a permanent fixture with a `default:` is used — prefer the **negative** fixture live only under the integration check, not under the green baseline, or it will fail `melos run analyze`).
- [x] **Task 6 — Docs (AC7).**
  - [x] 6.1 Rewrite `koel_lints/README.md`: custom_lint → asp; opt-out snippet `diagnostics: { exhaustive_switch_must_have_default: false }` (root or consumer options); **delete** the pub-workspace-bug caveat block. Keep the profile-semver policy + self-include note (update self-include to reflect the root-options model). Note the consumer enablement is now central (root `analysis_options.yaml`), not per-package `include:`.
  - [x] 6.2 `koel_lints/lib/koel.yaml`: retain as the **external-consumer** profile. Rewrite its `analyzer.plugins` / `custom_lint.rules` block to the asp shape (`plugins: { koel_lints: ... }` + `diagnostics:`), and add a header comment that its `include:`-based external distribution is verified at Epic 9 / Story 9-5 (external consumers don't exist pre-v1.0.0).
  - [x] 6.3 `koel_lints/CHANGELOG.md`: add a `0.0.1` note line for the asp migration (or keep "Initial scaffold." — it is still pre-publish; document choice).
  - [x] 6.4 `.github/dependabot.yml`: update the comment referencing `custom_lint ^0.8.1` (lines 2 + 4) to reference the asp deps instead. (No functional change — the `pub` ecosystem watch is generic.)
- [x] **Task 7 — Green baseline + verification (AC8, all ACs).**
  - [x] 7.1 `melos run analyze` exits 0 across all 11 packages.
  - [x] 7.2 `melos run format:check` exits 0 (run `melos run format` first if needed; Dart 3.12 formatter may reflow — expected).
  - [x] 7.3 `dart test` in `koel_lints` passes (AC4).
  - [x] 7.4 The AC1 integration check passes (rule fires on the negative fixture).
  - [x] 7.5 Grep the whole repo: zero `custom_lint`, `custom_lint_builder`, `strict.yaml`, `PluginBase`, `createPlugin`, `DartLintRule` references remain in code or `pubspec.lock`.
  - [x] 7.6 Update [sprint-status.yaml](sprint-status.yaml): `1-7-migrate-koel-lints-to-asp: review` (dev sets `review`; code-review flips to `done`, which then returns `epic-1` to `done`).

## Dev Notes

### Critical: preserve the existing rule logic verbatim

The current rule in [exhaustive_switch_must_have_default.dart](../../packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart) is **logically correct** (proven 4/4 under the old harness and 2/2 under the spike's `analyzer_testing` port). The spike confirmed the custom_lint→asp port is **mechanical** — same AST, same type-name keying, same `reportAtToken`. Carry these over **unchanged**:

- `_sealedNames = {'AgUiEvent', 'KoelError', 'MessageSegment'}` — the rule keys off the switch
  subject's **static type name** (string), deliberately, so fixtures can declare a local
  `sealed class AgUiEvent` that name-collides with `koel_core`'s future type (Story 1.3 §5.1). This
  is why the rule works today even though `koel_core`'s real `AgUiEvent` doesn't exist yet (Epic 2).
- `_isKoelSealedSwitch`: `expr.staticType?.element?.name` membership in `_sealedNames`. (`DartType.element.name` is the analyzer-13 element-model API; the spike confirmed it resolves.)
- Switch **statement**: fire if no member `is SwitchDefault`.
- Switch **expression**: fire if no case is an "open wildcard" — `_isOpenWildcard` = `WildcardPattern` with `type == null` **and** `whenClause == null` (an untyped, unguarded `_ =>` arm — the expression analog of `default:`). A guarded or typed wildcard does **not** count as the catch-all.
- Report at `node.switchKeyword` via `reportAtToken`. (Reporting at the keyword has no IDE quick-fix; that's a known v1.x polish item, intentionally out of scope — see deferred-work 1.3 review.)

### The asp API shape (grounded in the installed packages)

`analysis_server_plugin 0.3.15` + `analyzer 13.0.0` are already in pub-cache and were the
spike-proven versions. Verified API surface:

**`lib/main.dart`** — the plugin entry (asp discovers `lib/main.dart` by convention; this is why
`koel_lints` is exempt from the single-barrel rule, architecture §2 / G-3):

```dart
import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/exhaustive_switch_must_have_default.dart';

/// The asp entry point. The analysis server instantiates this and calls
/// [register] once per analysis context.
final class KoelLintsPlugin extends Plugin {
  @override
  String get name => 'koel_lints';

  @override
  void register(PluginRegistry registry) {
    registry.registerLintRule(const ExhaustiveSwitchMustHaveDefault());
  }
}
```

- `Plugin` is `abstract class Plugin` in `package:analysis_server_plugin/plugin.dart` with
  `String get name`, `FutureOr<void> register(PluginRegistry)`, optional `start()` / `shutDown()`.
- `registerLintRule(AbstractAnalysisRule)` is available on `PluginRegistry` (via `RegistryBase`/
  `RegistryMixin`). It takes the rule instance directly.
- **Confirm the exact symbol the server looks for in `main.dart`** as part of AC1 — the doc convention
  is a `Plugin` subclass discovered by the asp server; the spike used `lib/main.dart → Plugin.register`.
  If the server expects a specific top-level (e.g. a `plugin` getter or a named class), Task 1.4 surfaces it.
  Reference: the asp `writing_a_plugin` / `using_plugins` docs ([README](https://pub.dev/packages/analysis_server_plugin)).

**The rule** (`AnalysisRule`, analyzer 13):

```dart
import 'package:analyzer/analysis_rule/analysis_rule.dart';      // AnalysisRule, RuleContext
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart'; // RuleVisitorRegistry
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';                 // SimpleAstVisitor
import 'package:analyzer/error/error.dart';                      // LintCode, DiagnosticSeverity

class ExhaustiveSwitchMustHaveDefault extends AnalysisRule {
  ExhaustiveSwitchMustHaveDefault()
      : super(
          name: 'exhaustive_switch_must_have_default',
          description:
              'Switches over koel sealed unions must include a `default:` branch.',
        );

  static const _code = LintCode(
    'exhaustive_switch_must_have_default',
    'switch over sealed koel type must include a `default:` branch '
        '(adding a new subtype is a semver-minor bump per FR-A12).',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _sealedNames = {'AgUiEvent', 'KoelError', 'MessageSegment'};

  @override
  DiagnosticCode get diagnosticCode => _code;

  @override
  void registerNodeProcessors(RuleVisitorRegistry registry, RuleContext context) {
    final visitor = _Visitor(this);
    registry.addSwitchStatement(this, visitor);
    registry.addSwitchExpression(this, visitor);
  }

  // _isKoelSealedSwitch / _isOpenWildcard — carry over verbatim from the current file.
}

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);
  final ExhaustiveSwitchMustHaveDefault rule;

  @override
  void visitSwitchStatement(SwitchStatement node) { /* check + rule.reportAtToken(node.switchKeyword) */ }

  @override
  void visitSwitchExpression(SwitchExpression node) { /* check + rule.reportAtToken(node.switchKeyword) */ }
}
```

- Key API differences from custom_lint: **`AnalysisRule` requires `name` + `description`** in its
  super-ctor (custom_lint's `DartLintRule` only took a `code`); the report code is exposed via the
  `diagnosticCode` getter; `LintCode`'s ctor is **positional** `(name, problemMessage, {severity, ...})`
  with `severity` (default `INFO`) — not custom_lint's `errorSeverity:` named arg; node processing is
  a **registered visitor object** (`add*(this, visitor)`), not custom_lint's inline closures
  (`context.registry.addSwitchStatement((node) {...})`).
- `reportAtToken(Token token, {arguments, contextMessages})` is on `AnalysisRule` and uses
  `diagnosticCode` implicitly — call `rule.reportAtToken(node.switchKeyword)`.
- `LintCode` and `DiagnosticSeverity` are exported from `package:analyzer/error/error.dart`.

### Workspace-root wiring (the AC1/AC6 crux)

asp `plugins:` **must** live in the **pub-workspace-root** `analysis_options.yaml` (the analyzer
rejects `plugins:` in member options with `plugins_in_inner_options`). Confirmed parsing form
(analyzer 13 `analysis_options_provider.dart:183-201` — `plugins:` is a YamlMap of
`name → { path: ... }`, path is relative to the options file's directory):

```yaml
# /analysis_options.yaml  (repo root)
plugins:
  koel_lints:
    path: packages/koel_lints
diagnostics:
  exhaustive_switch_must_have_default: true
```

- The map **key** is the plugin package name (`koel_lints`); the **value** carries `path:` (relative
  to repo root → `packages/koel_lints`). A published plugin would use `version:` instead — that's the
  Epic 9 external-distribution path.
- asp lint rules are **off by default** → enabled via the top-level `diagnostics:` map. One root file
  turns the rule on for **every** workspace member. This is strictly cleaner than custom_lint's
  per-package `include:` and it **closes Story 1.1's deferred "no root `analysis_options.yaml`"**.
- **No per-member `package_config.json` is involved** → the entire custom_lint failure mode is
  structurally gone.
- The root file may also want the baseline lints for the workspace (the per-member `include:
  package:koel_lints/koel.yaml` previously chained `recommended.yaml`). Decide whether the root file
  also `include:`s `package:lints/recommended.yaml` so the workspace keeps a baseline after removing
  the per-member includes — **this is a behavior-preservation requirement, not optional** (see
  [Project Structure Notes](#project-structure-notes)).

### Existing code to read before editing (UPDATE files)

| File | Current state | What 1.7 changes | Must preserve |
|---|---|---|---|
| `koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart` | custom_lint `DartLintRule`, inline-closure visitors | → `AnalysisRule` + visitor object | the `_sealedNames` keying + statement/expression detection logic |
| `koel_lints/lib/koel_lints.dart` | custom_lint `createPlugin()` / `PluginBase` | **deleted**; replaced by `lib/main.dart` | nothing |
| `koel_lints/lib/koel.yaml` | `analyzer.plugins: [custom_lint]` + `custom_lint.rules:` | → asp `plugins:`+`diagnostics:`; kept as external profile | the `recommended.yaml` include |
| `koel_lints/analysis_options.yaml` | `include: package:lints/recommended.yaml` (self-include G-3) | likely unchanged (self can't load itself as a plugin) | the self-include exception |
| `koel_lints/pubspec.yaml` | `analyzer ^8.0.0` + `custom_lint_builder ^0.8.1` + dev `custom_lint` | → asp+analyzer13; add `analyzer_testing` dev-dep | `resolution: workspace`, `publish_to: none` |
| `koel_lints/test/rules/exhaustive_switch_test.dart` | `rule.testAnalyzeAndRun(File(...))` over fixture files | → `AnalysisRuleTest` + in-memory content | the 4 covered cases |
| 10 consumer `pubspec.yaml` | `koel_lints:` (bare) + `custom_lint: ^0.8.1` | drop `custom_lint` line | the bare `koel_lints:` dev-dep |
| 10 consumer `analysis_options.yaml` | `include: package:koel_lints/koel.yaml` | remove (rule now enabled at root) | — |
| root `pubspec.yaml`, 11 `pubspec.yaml`, `.tool-versions`, `ci.yml`, `codegen-drift.yml` | Dart 3.9.0 floor/pin | → Dart 3.10/3.12 per AC5 | — |
| `.github/dependabot.yml` | comments mention `custom_lint ^0.8.1` | comment-only update | the generic pub watch |

**Leave system working end-to-end:** removing per-member `include:` lines drops not just the koel
rule but the baseline `package:lints/recommended.yaml` those includes transitively pulled in. The
root `analysis_options.yaml` must restore that baseline (include `recommended.yaml`) or every package
silently loses standard lints — a regression that `melos run analyze` (AC8) would pass while quality
degrades. This is the kind of "required for correctness even if not in the ACs" obligation the dev owns.

### Project Structure Notes

- Target `koel_lints` tree (architecture L833-848): `lib/koel.yaml`, `lib/main.dart`, `lib/src/rules/exhaustive_switch_must_have_default.dart`, `test/exhaustive_switch_asp_test.dart` (+ a `dart analyze` integration check dir). Architecture is **already updated** for asp (D1, D3, §2 exception, layout, repo-root `analysis_options.yaml` comment) — no architecture edits in this story; it's the code catching up to the already-corrected design.
- `koel_lints` is an analyzer-plugin package, **not** a consumable library — nobody `import`s it. Its plugin entry **must** be `lib/main.dart` (asp discovery). It is exempt from the single-barrel-file convention (architecture §2 / AR-2 / G-3).
- The root `analysis_options.yaml` is a **new file** (Story 1.1 deferred it). Architecture L666/697 already document its intended content.
- `resolution: workspace` is declared on every member; the workspace has one root `package_config.json`. Do not hand-create per-member ones — pub deletes them on every `pub get`.

### Anti-patterns to avoid (carried from CLAUDE.md + architecture review gates)

- No `print(...)`, no `catch (_) {}`, no `late` outside init-once, no multi-paragraph doc comments restating code, no vestigial "just in case" params.
- Do **not** re-introduce `flutter_lints` or `very_good_analysis` (AR-1: one lint baseline). _(Note: the Flutter-rule-loss item from the 1.4 review still rides to Epic 4 — unchanged by this pivot; out of scope here.)_
- Do **not** add `custom_lint` back in any form.
- Do **not** use `dart:io` logging inside the plugin isolate (crashes it — spike finding).

## Previous Story Intelligence

From Stories 1.3 / 1.4 (the superseded lint stories) and the spike:

- **Verify by running, not by reading source** (retro lesson A2 — load-bearing here). The spike's
  source-based predictions were **falsified 3×**: "IDE will work" (wrong — IDE failed too),
  "2-function vendor patch fixes custom_lint" (wrong — ≥2 broken layers), and the rule's enforcement
  reach. AC1 is explicitly the "prove it by running `dart analyze`" gate. Treat every "this should
  work" as a hypothesis until a command confirms it.
- **`strict.yaml` never existed.** `package:lints` ships only `core.yaml` + `recommended.yaml` (1.0.1
  → 6.1.0). Story 1.3 already corrected `koel.yaml` + the self `analysis_options.yaml` to
  `recommended.yaml`. Keep `recommended.yaml`; never write `strict.yaml`.
- **Dart 3.12 formatter reflows older source.** `melos run format` may reformat files authored under
  an earlier formatter (trailing-comma vertical layout). Expected; run format before `format:check`.
- **The `koel_lints` test fixtures already encode the name-collision trick** — a local `sealed class
  AgUiEvent` is what makes the rule fire without `koel_core` existing. Reuse this in the
  `analyzer_testing` in-memory sources and the AC1 integration fixture.
- **`pubspec.lock` already forces `dart >=3.10.0`** (a transitive dep raised it) — this is exactly
  why AC5 raises the declared floor to 3.10.0; it removes the long-standing `.tool-versions 3.9.0` vs
  lock `>=3.10.0` contradiction (Discovery-D4), not just an asp requirement.
- **custom_lint pinned `analyzer 8.4.0`** — that's why asp/analyzer-13 won't resolve until
  custom_lint is removed **workspace-wide** (Task 3 gates Task 1's success).

## Git Intelligence Summary

Recent commits confirm the lint history and the pivot trail:
- `fa0f25d chore(story-1.3)` — wired the custom_lint plugin + principal rule (the code 1.7 replaces).
- `2ef0a5f chore(story-1.4)` — adopted the profile across packages (the per-member `include:` 1.7 removes).
- `0feb93d docs(epic-1)` — retrospective + the asp pivot **spike** (rule already ported once; reverted, not committed as code).
- `77482ad docs(epic-1)` — correct-course: epic-1 reopened, Story 1.7 appended, architecture/requirements updated.

The working tree is clean and **fully custom_lint-based** (the spike's half-migration was reverted):
no root `analysis_options.yaml`; each consumer carries `include: package:koel_lints/koel.yaml`;
`koel_lints` ships the custom_lint layout. This is a **clean forward re-implementation**, not a patch
of partial work — start from the committed custom_lint state.

Commit convention: `chore(story-1.7): <summary>` (matches `chore(story-1.x):` history). Code-review
auto-commits on flip to `done` (per project feedback).

## Latest Technical Information

- **asp + analyzer versions are spike-resolution-proven on Dart 3.12:** `analysis_server_plugin:
  ^0.3.15` + `analyzer: ^13.0.0` + `analyzer_testing: ^0.2.6`. All three are already in pub-cache.
- **Flutter↔Dart mapping confirmed (AC5 "exact mapping" task):**
  - **Flutter 3.38 ships Dart 3.10** (announced Nov 2025) → Flutter floor `>=3.38.0` matches the Dart `>=3.10.0` floor.
  - **Flutter 3.44 ships Dart 3.12** (Google I/O 2026, May 2026) → the `.tool-versions` pin Dart `3.12` / Flutter `3.44` is a real, shipped pairing.
- **asp is in-SDK from Dart 3.10 / Flutter 3.38** — workspace-native by construction (runs inside the
  analysis server; no separate process, no temp `custom_lint_client` + `pub get` hack). Production-proven
  (`many_lints`, `saropa_lints`). Only documented gap: no "assists" yet — irrelevant to a pure lint rule.
- **`analyzer_testing` harness:** `AnalysisRuleTest extends PubPackageResolutionTest`, uses
  `test_reflective_loader`; set `rule` in `setUp` before `super.setUp`, register via
  `Registry.ruleRegistry.registerLintRule(rule)` (from `package:analyzer/src/lint/registry.dart`),
  assert with `await assertDiagnostics(content, [lint(offset, length)])` and
  `await assertNoDiagnostics(content)`. `lint(...)` and `error(...)` expectation helpers are exported
  from `package:analyzer_testing/analysis_rule/analysis_rule.dart`. Always `await` the assertions
  (stale-result hazard noted in the harness docs).

Sources for the version mapping:
- [Announcing Flutter 3.38 & Dart 3.10 (blog.flutter.dev)](https://blog.flutter.dev/announcing-flutter-3-38-dart-3-10-building-the-future-of-apps-503429eeb685)
- [Flutter 3.44 & Dart 3.12 — Google I/O 2026](https://docs.flutter.dev/release/release-notes/release-notes-3.44.0)
- [analysis_server_plugin on pub.dev](https://pub.dev/packages/analysis_server_plugin)

## Testing Requirements

- **Unit (rule logic):** `dart test` in `koel_lints`, on the `analyzer_testing` `AnalysisRuleTest`
  harness. Cover the four cases (statement fire/silent, expression fire/silent) using in-memory source
  strings that declare a local `sealed class AgUiEvent` + subtypes. This is the server-free backbone.
- **Integration (AC1 — the new, essential coverage):** a `dart analyze` run over a real fixture
  consumer that must report **exactly one** `exhaustive_switch_must_have_default` ERROR. This is the
  proof custom_lint never achieved. Make it permanent and CI-exercised, but keep the *failing* fixture
  out of the `melos run analyze` green-baseline path (or that baseline fails) — scope it to the
  integration check (e.g. a dedicated dir excluded from the workspace analyze, run by a script that
  asserts a non-zero `dart analyze` + the expected message).
- **Green baseline (AC8):** `melos run analyze` exits 0 across all 11 packages with the rule live;
  `melos run format:check` exits 0; `melos run test` unaffected (still the `dart --version` stub until
  Story 2.15).
- **Standards:** test files mirror source (architecture review gate). Always `await` `analyzer_testing`
  assertions.

### References

- [Source: sprint-change-proposal-2026-05-29.md §4.1](../planning-artifacts/sprint-change-proposal-2026-05-29.md) — authoritative AC list + impact analysis.
- [Source: epic-1-workspace-foundation-lint-profile.md#story-17](../planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md) — epic story spec + BDD ACs.
- [Source: deferred-work.md → Story 1.4 entry → SPIKE FINAL VERDICT points 1–7](deferred-work.md) — full forensic trail; point 7 = the validation-spike results (asp API shape, what's proven vs not).
- [Source: architecture.md D1 (L260-273), D3 (L284-302), §2 exception (L490-494), koel_lints layout (L833-848), repo-root analysis_options (L666/697)](../planning-artifacts/architecture.md) — already updated for asp.
- [Source: requirements-inventory.md AR-2, AR-5](../planning-artifacts/requirements-inventory.md) — already updated for asp.
- [Source: epic-1-retro-2026-05-29.md](epic-1-retro-2026-05-29.md) — Challenge 2 + Action #1 (the spike driver), lesson A2.
- Installed package sources (ground truth for the API): `~/.pub-cache/hosted/pub.dev/analysis_server_plugin-0.3.15/lib/{plugin,registry}.dart`; `analyzer-13.0.0/lib/src/analysis_rule/analysis_rule.dart` (AnalysisRule/reportAtToken), `lib/analysis_rule/rule_visitor_registry.g.dart` (add* signatures), `lib/src/dart/error/lint_codes.dart` (LintCode ctor); `analyzer_testing-0.2.6/lib/analysis_rule/analysis_rule.dart` (AnalysisRuleTest).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (dev-story workflow; `/agent-flutter-engineer` specialist loaded per CLAUDE.md before writing Dart).

### Debug Log References

- **AC1 proof (the unproven piece).** Root `analysis_options.yaml` + throwaway probe in
  `koel_core/lib/_probe.dart`; `dart analyze packages/koel_core` → exactly one
  `exhaustive_switch_must_have_default` ERROR via the production server-plugin path (~5s first
  load). Adding `default:` cleared the rule error (only `unreachable_switch_default` remained); probe
  deleted, `git status` clean of it.
- **Unit-test offsets** (`switch`-keyword token) recovered from the `analyzer_testing` harness'
  "To accept the current state" output: statement-fires → `lint(205, 6)`, expression-fires →
  `lint(204, 6)`.
- `melos run analyze` → SUCCESS across all 11 packages; `melos run format:check` → SUCCESS;
  `dart test` in `koel_lints` → 5/5 pass; `melos run test` stub unaffected.

### Completion Notes List

- **Two corrections to the Dev Notes API shape, confirmed against the asp `using_plugins.md` /
  `writing_a_plugin.md` docs and proven by running (retro lesson A2):**
  1. asp requires a **top-level `plugin` variable** in `lib/main.dart` (the server generates code that
     imports `lib/main.dart` and references `plugin`) — a `Plugin` subclass alone is not discovered.
  2. `diagnostics:` **nests under the plugin entry** in `analysis_options.yaml`, not as a separate
     top-level section as the Dev Notes sketch showed.
- **`ExhaustiveSwitchMustHaveDefault` is not `const`** — analyzer 13's `AnalysisRule` ctor is
  non-const (unlike custom_lint's `DartLintRule`), so `main.dart` constructs it without `const`.
- **Member `analysis_options.yaml` files deleted (10), not edited.** `plugins:` is legal only in the
  workspace-root options (`plugins_in_inner_options`), and the analyzer walks up to the root for
  members that carry no own options file — proven by the per-package `melos run analyze`. The root
  file re-`include`s `package:lints/recommended.yaml` so the baseline the per-member includes used to
  chain is preserved (behaviour-preservation requirement, AC6/Dev Notes).
- **Task 5.3 fixture fate:** the four `test/rules/fixtures/*.dart` files were custom_lint
  `testAnalyzeAndRun` inputs and are now unreferenced — **deleted** (no vestigial code). Unit tests
  inline their source as in-memory strings; the AC1 integration check generates its own fixture.
- **Task 5.4 integration check design:** a Dart test (`test/integration/dart_analyze_fires_test.dart`)
  builds a self-contained consumer in a **temp dir outside the workspace** (nested `plugins:` would be
  rejected), enables the plugin by absolute path, runs real `dart analyze`, and asserts exactly one
  error. It is CI-exercised by `dart test` and kept out of the `melos run analyze` green-baseline path,
  so the negative fixture never fails AC8.
- **Test file renamed** `exhaustive_switch_test.dart` → `exhaustive_switch_must_have_default_test.dart`
  to mirror the source file name (test-mirrors-source gate).
- **CHANGELOG:** kept `0.0.1` (still pre-publish) and added an asp-migration note line.
- Removed stale untracked `packages/*/custom_lint.log` run artifacts. Repo grep is clean of
  `custom_lint` / `custom_lint_builder` / `strict.yaml` / `PluginBase` / `createPlugin` /
  `DartLintRule` across code, config, and `pubspec.lock`.
- **Out of scope / follow-ups:** IDE confirmation is a manual sanity check (CLI shares the same
  enablement gate, proven). `koel.yaml`'s `include:`-based external distribution is verified at Epic 9
  (Story 9-5). Reporting at `switchKeyword` has no IDE quick-fix (known v1.x polish, per Dev Notes).

### File List

**Added**
- `analysis_options.yaml` (repo-root: asp `plugins:` + `diagnostics:` + baseline `recommended.yaml`)
- `packages/koel_lints/lib/main.dart` (asp `Plugin` entry + top-level `plugin`)
- `packages/koel_lints/test/rules/exhaustive_switch_must_have_default_test.dart` (`analyzer_testing`)
- `packages/koel_lints/test/integration/dart_analyze_fires_test.dart` (AC1 integration check)

**Modified**
- `packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart` (port to `AnalysisRule`)
- `packages/koel_lints/pubspec.yaml` (asp + analyzer 13; dev: analyzer_testing, test_reflective_loader)
- `packages/koel_lints/lib/koel.yaml` (asp-shaped external-consumer profile)
- `packages/koel_lints/README.md`, `packages/koel_lints/CHANGELOG.md`
- `packages/{koel,koel_core,koel_http,koel_agno,koel_langgraph,koel_runtime,koel_flutter,koel_widgets,koel_devtools,koel_test}/pubspec.yaml` (drop `custom_lint`; raise SDK floor; Flutter floor on the 3 Flutter pkgs)
- `pubspec.yaml` (root SDK floor), `pubspec.lock` (re-resolved)
- `.tool-versions` (dart 3.12.0 / flutter 3.44.0)
- `.github/workflows/ci.yml`, `.github/workflows/codegen-drift.yml` (`setup-dart` sdk 3.12.0)
- `.github/dependabot.yml` (comment refresh: asp deps)

**Deleted**
- `packages/koel_lints/lib/koel_lints.dart` (old custom_lint `createPlugin` entry)
- `packages/koel_lints/test/rules/exhaustive_switch_test.dart` (replaced)
- `packages/koel_lints/test/rules/fixtures/{ok,violations}/*.dart` (4 unreferenced fixtures)
- `packages/{koel,koel_core,koel_http,koel_agno,koel_langgraph,koel_runtime,koel_flutter,koel_widgets,koel_devtools,koel_test}/analysis_options.yaml` (10 per-member includes; rule now enabled at root)

### Change Log

| Date | Change |
|---|---|
| 2026-05-29 | Migrated `koel_lints` from `custom_lint` to first-party `analysis_server_plugin`; wired root `analysis_options.yaml`; raised toolchain to Dart 3.12/Flutter 3.44 (floor 3.10/3.38). AC1 proven via `dart analyze` + integration check. All 8 ACs satisfied; status → review. |

## Review Findings

_Code review 2026-05-29 (3 layers: Blind Hunter, Edge Case Hunter, Acceptance Auditor). Reviewer re-ran `dart test` (5/5 pass incl. AC1 integration), verified the `// ignore:` opt-out string, and confirmed the lock-vs-declared SDK floor mismatch by running. All 8 ACs MET as literally written. 1 decision-needed, 0 patch, 4 deferred, 17 dismissed as noise/by-design/falsified-by-running._

- [x] **[Review][Patch] Declared SDK floor `>=3.10.0` is below the true resolvable floor `>=3.11.0`** — AC5 mandated `>=3.10.0` (and README/CHANGELOG advertise "in-SDK from Dart 3.10"), but `pubspec.lock` resolves `sdks: dart: ">=3.11.0"`. Root cause: `_fe_analyzer_shared 100.0.0` (transitive of `analyzer 13.0.0`) requires `sdk: ^3.11`. A contributor on Dart 3.10.x passes the pubspec constraint check yet cannot resolve against the committed lock. **Resolved (option 1):** bumped the declared floor to `>=3.11.0` across all 12 pubspecs (root + 11 packages), the AC1 integration-test fixture, the README, and the CHANGELOG; re-resolved (`dart pub get`) — declared floor now matches lock; `melos run analyze` SUCCESS (11 pkgs) + `dart test` 5/5 green after the change. _(This refines AC5's literal `>=3.10.0` to the honest resolvable floor; asp itself remains in-SDK since Dart 3.10.)_

- [x] **[Review][Defer] Rule keys off static type *name* only (no library/URI scoping)** [packages/koel_lints/lib/src/rules/exhaustive_switch_must_have_default.dart:44-47] — `_isKoelSealedSwitch` matches `expr.staticType?.element?.name` against `_sealedNames` with no library check, so any foreign type named `AgUiEvent`/`KoelError`/`MessageSegment` (incl. via typedef alias) triggers a false-positive ERROR. **Intentional per Dev Notes** (the name-collision trick lets fixtures fire before `koel_core` exists). Deferred — revisit at Epic 2 when the real `koel_core.AgUiEvent` lands and library scoping becomes meaningful. (sources: edge)

- [x] **[Review][Defer] Brittle hardcoded test offsets** [packages/koel_lints/test/rules/exhaustive_switch_must_have_default_test.dart] — `lint(205, 6)` / `lint(204, 6)` are absolute character offsets into the shared `_sealed` literal; any whitespace/format edit silently breaks them with no symbolic anchor. Deferred — test-internal maintainability, not a correctness bug; the harness regenerates offsets on demand. (sources: blind+edge)

- [x] **[Review][Defer] A future member-local `analysis_options.yaml` silently shadows the root plugin wiring** [analysis_options.yaml] — `plugins:` is legal only at the workspace root; if any member later re-adds its own options file, the analyzer stops inheriting the root and the rule goes dark for that package with no error. Deferred — future-maintenance gotcha; consider a CI guard or doc note. (sources: edge)

- [x] **[Review][Defer] Integration-test environment robustness** [packages/koel_lints/test/integration/dart_analyze_fires_test.dart] — `dart pub get` needs network (offline CI → flaky); `deleteSync(recursive: true)` tear-down can throw on Windows if the analyzer holds handles. Deferred — current CI is online macOS/Linux and the test passes; harden if Windows CI is added. (sources: edge)
