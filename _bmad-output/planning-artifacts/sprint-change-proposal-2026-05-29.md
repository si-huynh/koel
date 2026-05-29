# Sprint Change Proposal — `custom_lint` → `analysis_server_plugin` pivot

- **Proposal ID:** SCP-2026-05-29
- **Date:** 2026-05-29
- **Author:** Amelia (Developer) — driven via `bmad-correct-course`
- **Approver:** Si Huynh (Project Lead)
- **Scope classification:** **Moderate** (architecture-decision reversal + story re-scope + enforcement-mechanism change; no PRD requirement or epic structure changes substantively)
- **Trigger source:** Epic-1 retrospective spike (committed in `0feb93d`)
- **Status:** Proposed → awaiting approval

---

## Section 1 — Issue Summary

### Problem statement

The lint-enforcement tool chosen at planning time — `custom_lint` (`AR-5: custom_lint: 0.8.1`;
architecture `D3`) — is **non-viable** on two independent grounds:

1. **Dead upstream.** `invertase/dart_custom_lint` was **archived 2026-03-24** (the 8-month
   staleness was a leading indicator). No first-party maintenance path.
2. **Structurally broken on koel's native pub workspace.** `custom_lint`'s CLI/IDE plugin
   path resolves rules through a per-member `.dart_tool/package_config.json`, which a Dart
   **pub workspace does not create** (the single real `package_config.json` lives only at the
   workspace root; pub deletes per-member ones on every `pub get`). Net: the principal rule
   `exhaustive_switch_must_have_default` — *the entire reason `koel_lints` exists* (FR-A12 /
   FC-2 / NFR-17) — does **not fire on consumer source in any tool** (CLI or IDE), only inside
   `koel_lints`'s own unit tests.

The official first-party replacement is **`analysis_server_plugin`** (Dart team), which runs
inside the analysis server, is **workspace-native by construction**, and integrates directly
into `dart analyze` + IDEs.

### Discovery context & evidence (already validated — not re-investigated)

Full forensic trail: `_bmad-output/implementation-artifacts/deferred-work.md` → Story 1.4 entry
→ "SPIKE FINAL VERDICT" points 1–7. Retro summary:
`_bmad-output/implementation-artifacts/epic-1-retro-2026-05-29.md` (Challenge 2 + Action #1).

Evidence grounded in **what was actually run** (per lesson A2 "verify by running" — source-based
predictions were falsified 3× this session):

- ✅ Rule ports cleanly to the asp API and **fires 2/2** via the official `analyzer_testing`
  harness (`AnalysisRuleTest`, server-free): fires on a no-`default:` switch over sealed
  `AgUiEvent` (statement + expression form), silent when `default:` present.
- ✅ Version reality on our toolchain: requires `analysis_server_plugin: ^0.3.15` +
  `analyzer: ^13.0.0`, which resolve **only after** `custom_lint`/`custom_lint_builder` are
  removed workspace-wide (`custom_lint` pins `analyzer 8.4.0`). Proven to install on Dart 3.12.
- ✅ Wiring is workspace-native: asp `plugins:` **must** live at the workspace-root
  `analysis_options.yaml` (analyzer rejects it in member files with `plugins_in_inner_options`);
  rules are off-by-default → enabled via `diagnostics: { exhaustive_switch_must_have_default: true }`.
  One root file enables it for all members — this also closes Story 1.1's deferred
  "no root `analysis_options.yaml`".
- ⚠️ **NOT yet proven:** the full `dart analyze` / IDE **server-plugin** integration in our
  workspace (the `analyzer_testing` proof is rule-logic only). This is the **first
  implementation task** of the re-scoped work, with `analyzer_testing` as the unit-test backbone
  + a dedicated `dart analyze` integration check.

### Working-tree state (verified clean at proposal time)

The spike's half-migration was **reverted**; `git status` is clean and the committed state is
fully `custom_lint`-based: no root `analysis_options.yaml`; each consumer carries
`include: package:koel_lints/koel.yaml`; `koel_lints` ships the `custom_lint` plugin layout
(`lib/koel_lints.dart` + `lib/src/rules/`). The migration is therefore a **clean forward
re-implementation**, not a patch of partial work.

---

## Section 2 — Impact Analysis

### Epic impact

| Epic | Impact |
|---|---|
| **Epic 1** (done + retro'd) | Re-opens to `in-progress` to absorb one corrective story (**Story 1.7**). Stories 1.3 + 1.4 stay `done` but are annotated **superseded-by-1.7** (their ACs mandate `custom_lint`, `strict.yaml`, and per-package `include:` — all now invalid). |
| **Epic 2** (`koel_core`) | **Gated** on Story 1.7. Epic 2 defines exactly the sealed unions the rule protects; FC-2 (adding a subtype = semver-minor) is not auto-enforced until the rule fires on consumer source. Do **not** start Epic 2 stories until 1.7 lands. |
| **Epic 9** (release gates) | Inherits one new verification task: confirm `lib/koel.yaml`'s `include:`-based distribution carries asp `plugins:` for **external** consumers (fold into Story 9-5 publish-dry-run). Story 9-7 (PRD reconciliation) absorbs the F-A12 mechanism-wording erratum. |
| Epics 3–8 | No impact. |

No epic is obsoleted; no new epic is needed; epic ordering is unchanged.

### Story impact

- **New: Story 1.7 — "Migrate `koel_lints` to `analysis_server_plugin`"** (Epic 1). Carries the
  corrected asp ACs. Becomes the critical-path gate before Epic 2 Story 2.1.
- **Story 1.3 / 1.4** — superseded-by-1.7 annotation; ACs left in place as historical record.

### Artifact conflicts (what must change)

| Artifact | Conflict | Resolution |
|---|---|---|
| `architecture.md` **D3** | Pins `custom_lint 0.8.1` | Rewrite → `analysis_server_plugin: ^0.3.15` + `analyzer: ^13.0.0` |
| `architecture.md` **D1** | Dart floor `3.9.0+` | Raise → `3.10.0+` (asp needs analyzer ≥10 → Dart 3.10; `pubspec.lock` already forces `>=3.10.0`) |
| `architecture.md` Convention §2 | "single barrel `lib/<pkg>.dart`" conflicts with asp's mandatory `lib/main.dart` plugin entry | Add `koel_lints` exception note (already non-standard via AR-2 / G-3) |
| `architecture.md` koel_lints layout (L800-818) | custom_lint tree | Rewrite to asp tree (`lib/main.dart`, `lib/koel.yaml`, `analyzer_testing`) |
| `architecture.md` `strict.yaml` (L229, L1163, L1261) | `package:lints/strict.yaml` never shipped | Erratum → `recommended.yaml` |
| `architecture.md` validation refs (L362, L691, L1093, L1132) | custom_lint mentions | Update to asp |
| `requirements-inventory.md` **AR-5** (L132) + AR-2 (L126) | custom_lint | Rewrite to asp |
| `implementation-readiness-report` (L312) | `AR-5 (custom_lint) → 1.3` | Re-trace `AR-5 (asp) → 1.7`; add SCP banner |
| `prd.md` **SC-3** (L65) + **N-13** (L314) | `package:lints/strict.yaml` | Erratum → `recommended.yaml` (same class as architecture erratum) |
| `prd.md` **F-A12** mechanism sentence | "one line `include: package:koel_lints/koel.yaml`" is mechanism-bound under asp | Route wording reconciliation to Epic 9 / Story 9-7 (intent is tool-agnostic; only the cited mechanism is stale) |
| `epic-1-...md` | Stories 1.3/1.4 ACs stale | Annotate superseded + append Story 1.7 |
| `deferred-work.md` | custom_lint saga open | Close with "RESOLVED via SCP-2026-05-29"; close Discovery-D4 |
| `sprint-status.yaml` | no 1.7; epic-1 done | Add `1-7-...: backlog`; flip `epic-1 → in-progress` |
| **Code** (`koel_lints` + 10 consumers + toolchain pins) | custom_lint everywhere | **Story 1.7 implementation deliverable** (not landed by this correction) |

### Technical impact (toolchain — Discovery-D4 reconciliation)

- **Declared floor:** Dart `>=3.10.0` across all 11 pubspecs (resolves the long-standing
  `pubspec.lock >=3.10.0` vs `.tool-versions 3.9.0` contradiction, retro Discovery-D4). Flutter
  floor rises to the release carrying Dart ≥3.10 (≈ **3.38.0** per spike; exact mapping confirmed
  in Story 1.7) on the 3 Flutter packages.
- **Contributor/CI pin:** `.tool-versions` → **Dart 3.12 / Flutter 3.44** (the versions the spike
  actually ran asp `0.3.15` + analyzer `13.0.0` on — resolution-proven). CI `setup-dart` pin
  bumps `3.9.0` → match.
- **Dependency churn:** remove `custom_lint` + `custom_lint_builder` from `koel_lints` and all 10
  consumers; add `analysis_server_plugin` + `analyzer ^13.0.0` to `koel_lints`; `pubspec.lock`
  re-resolves.

> **ID disambiguation (to prevent cross-doc confusion):** "D4" in `architecture.md` is the **SSE
> web-transport** decision and is **untouched**. The toolchain-floor item the trigger refers to is
> the **retrospective's Discovery-D4** (Dart-floor contradiction); the floor *decision* in
> `architecture.md` is **D1**. This proposal edits **D1** + closes **Discovery-D4**, and leaves
> architecture-D4 alone.

---

## Section 3 — Recommended Approach

**Selected path: Direct Adjustment (Hybrid).** Add one corrective story (**Story 1.7**) within the
existing Epic 1 structure; update the conflicting planning artifacts in place; defer external-
consumer distribution verification + PRD mechanism wording to Epic 9.

### Options considered

| Option | Verdict |
|---|---|
| **Direct Adjustment** (new Story 1.7 + artifact updates) | ✅ **Selected.** Lowest risk; pivot is pre-validated; keeps Epic-1 history intact; unblocks Epic 2 cleanly. |
| **Rollback** (revert Story 1.1's pub-workspace decision to legacy Melos bootstrap so custom_lint works) | ❌ Rejected. Resurrects a dead tool; reverses a sound architectural choice; superseded by the asp verdict (deferred-work point 6). |
| **PRD MVP review** (drop the lint guarantee) | ❌ Rejected. FR-A12 / FC-2 is load-bearing for the hybrid-versioning forward-compat policy (F-H2). The guarantee stays; only the tool changes. |

### Rationale

- asp is **first-party and workspace-native** — it removes the entire failure mode rather than
  working around it. No vendor fork, no IDE-only DX, no Melos downgrade.
- The rule logic is **proven to fire** under asp (`analyzer_testing`, 2/2). The only open risk —
  production server-plugin loading in our workspace — is isolated as Story 1.7's **first task**,
  with the test harness as backbone.
- Effort: **Medium** (one focused story; rule logic already ported in spike). Risk: **Low-Medium**
  (single unproven integration step, de-risked by the analyzer_testing backbone). Timeline:
  blocks only Epic 2 kickoff, which is already gated by the retro's critical path.

### Decisions confirmed with Project Lead (2026-05-29)

1. **Mode:** Batch.
2. **Re-scope mechanism:** new **Story 1.7** (1.3/1.4 stay `done`, annotated superseded). *(Not
   a re-open.)*
3. **`lib/koel.yaml` fate:** **Keep**; workspace-internal adoption uses the root
   `analysis_options.yaml`; verify the `include:`-based external distribution at **Epic 9**
   (external consumers do not exist pre-v1.0.0).
4. **Toolchain pin:** **Dart 3.12 / Flutter 3.44**; declared floor `>=3.10.0`.

---

## Section 4 — Detailed Change Proposals

### 4.1 — New Story 1.7 (appended to `epic-1-workspace-foundation-lint-profile.md`)

> **Story 1.7: Migrate `koel_lints` to `analysis_server_plugin`**
>
> As an OSS contributor, I want `koel_lints` rebuilt on the first-party `analysis_server_plugin`
> API and wired through a single workspace-root `analysis_options.yaml`, so that
> `exhaustive_switch_must_have_default` actually fires on consumer source under `dart analyze` +
> IDEs in our native pub workspace — delivering the FR-A12 / FC-2 guarantee that `custom_lint`
> could not.
>
> **Supersedes the lint *mechanism* of Stories 1.3 + 1.4** (their `custom_lint` / `strict.yaml` /
> per-package-`include:` ACs are retired). Reverses AR-5 + architecture D3.
>
> **AC1 — Server-plugin integration fires (THE unproven piece; do first).** With the asp plugin
> wired at the workspace-root `analysis_options.yaml`, `dart analyze` on a member package
> containing a `switch` over sealed `AgUiEvent` without `default:` reports
> `exhaustive_switch_must_have_default` as **ERROR**; the IDE surfaces the same. Silent when
> `default:` present.
>
> **AC2 — asp plugin layout.** `lib/main.dart` is a `Plugin` subclass whose
> `register(PluginRegistry)` calls `registry.registerLintRule(...)`; the rule extends
> `AnalysisRule` with `LintCode(name, msg, severity: DiagnosticSeverity.ERROR)`, overrides
> `registerNodeProcessors` → `registry.addSwitchStatement` / `addSwitchExpression`, reports via
> `reportAtToken`. The old `custom_lint` entrypoint `lib/koel_lints.dart` is removed.
>
> **AC3 — Dependencies.** `koel_lints/pubspec.yaml` declares `analysis_server_plugin: ^0.3.15` +
> `analyzer: ^13.0.0`; `custom_lint` + `custom_lint_builder` are removed from `koel_lints` **and**
> all 10 consumer pubspecs.
>
> **AC4 — Unit tests + integration check.** Rule unit tests use `analyzer_testing`
> (`AnalysisRuleTest`): fire on no-`default:` switch over sealed `AgUiEvent` (statement +
> expression form), silent with `default:`. A dedicated `dart analyze` integration check covers
> AC1.
>
> **AC5 — Toolchain.** `.tool-versions` pins Dart `3.12` / Flutter `3.44`; declared floor raised to
> Dart `>=3.10.0` across all 11 pubspecs + Flutter `>=3.38.0` (exact mapping confirmed) on the 3
> Flutter packages; `pubspec.lock` re-resolves clean; CI `setup-dart` pin bumped. Resolves retro
> Discovery-D4.
>
> **AC6 — Workspace-root wiring.** A single repo-root `analysis_options.yaml` declares asp
> `plugins:` + `diagnostics: { exhaustive_switch_must_have_default: true }` and enables the rule
> for all members; per-member `include: package:koel_lints/koel.yaml` lines are removed/reconciled.
> Closes Story 1.1's deferred "no root `analysis_options.yaml`".
>
> **AC7 — Docs.** `koel_lints/README.md` updated (custom_lint → asp; opt-out via
> `diagnostics: { exhaustive_switch_must_have_default: false }`; the pub-workspace-bug caveat
> removed — asp is workspace-native). `lib/koel.yaml` retained as the external-consumer profile
> with a note that its `include:`-based distribution is verified at Epic 9 (Story 9-5).
>
> **AC8 — Green baseline.** `melos run analyze` exits 0 across all 11 packages with the rule live.

### 4.2 — `architecture.md`

**D1 (L258-264) — raise floor.** `Dart 3.9.0+` → `Dart 3.10.0+`; rationale notes asp/analyzer-13
requirement + the already-forced `pubspec.lock >=3.10.0` (closes Discovery-D4); contributor pin =
Dart 3.12 / Flutter 3.44 (spike-validated). PRD update note → "§10.3 N-9 changes to Dart 3.10.0+".

**D3 (L273-281) — full rewrite (custom_lint → asp).** New decision: build `koel_lints` on
`analysis_server_plugin: ^0.3.15` + `analyzer: ^13.0.0`. Rationale: custom_lint archived
2026-03-24 and structurally fails on native pub workspaces; asp is first-party, workspace-native,
integrates into `dart analyze` + IDEs; rule logic proven via `analyzer_testing`. Affects:
`koel_lints` layout (`lib/main.dart` plugin entry), consumer wiring (workspace-root
`analysis_options.yaml`, not per-package include), toolchain floor (D1). Note the `lib/main.dart`
requirement conflicts with Convention §2 barrel rule → see §2 exception note.

**Critical-path note (L362).** "D3 (custom_lint)" → "D3 (analysis_server_plugin)".

**Convention §2 (after L447) — add exception note.** `koel_lints` is an analyzer-plugin package,
not a consumable Dart library; its plugin entry **must** be `lib/main.dart` (asp discovery
convention) and its consumer surface is `lib/koel.yaml`, not a Dart barrel. It is exempt from the
single-barrel rule (already non-standard per AR-2 / G-3).

**koel_lints layout (L800-818) — rewrite tree:** `lib/main.dart` (Plugin entry), `lib/koel.yaml`
(profile), `lib/src/rules/exhaustive_switch_must_have_default.dart`; tests under
`test/` using `analyzer_testing` (`AnalysisRuleTest`) + a `dart analyze` integration check. Drop
custom_lint fixture-harness mentions.

**Repo-layout comments.** L666 `analysis_options.yaml` comment → "workspace-root asp `plugins:` +
`diagnostics:` (enables koel rule for all members)"; L691 "(custom_lint based)" → "(analysis_server_plugin based)".

**Validation refs.** L1093 (D3 custom_lint→asp), L1132 (D3 version string → asp 0.3.15 + analyzer
13; D1 → Dart 3.10.0+), L229 / L1163 / L1261 `strict.yaml` → `recommended.yaml`.

### 4.3 — `requirements-inventory.md`

**AR-5 (L132) — rewrite:**
> **AR-5. `analysis_server_plugin: ^0.3.15` + `analyzer: ^13.0.0`** as foundation for `koel_lints`.
> First-party (Dart team), workspace-native, integrates into `dart analyze` + IDEs. Replaces the
> originally-planned `custom_lint 0.8.1` (archived 2026-03-24; fails on native pub workspace).
> Reversed via correct-course SCP-2026-05-29.

**AR-2 (L126):** "non-standard structure (`custom_lint` + `custom_lint_builder` … under
`lib/src/rules/`)" → "asp conventions: plugin entry at `lib/main.dart`, rules under `lib/src/rules/`".

### 4.4 — `prd.md` (errata only; mechanism wording → Epic 9)

- **SC-3 (L65)** + **N-13 (L314):** `package:lints/strict.yaml` → `package:lints/recommended.yaml`.
- **F-A12 (L141):** the cited "one line `include: package:koel_lints/koel.yaml`" mechanism is now
  asp-dependent — flagged for reconciliation in **Story 9-7** (intent unchanged; only the cited
  enablement mechanism is stale).

### 4.5 — `implementation-readiness-report-2026-05-28.md`

- L312: `AR-5 (custom_lint: 0.8.1) | 1.3` → `AR-5 (analysis_server_plugin: ^0.3.15) | 1.7 (re-scoped; SCP-2026-05-29)`.
- Add a one-line erratum banner at the AR-coverage section head pointing to SCP-2026-05-29.

### 4.6 — `deferred-work.md`

Append a **closure note** to the Story 1.4 custom_lint saga + Discovery-D4:
> **RESOLVED via correct-course SCP-2026-05-29.** The custom_lint enforcement gap is closed by
> pivoting to `analysis_server_plugin` (Story 1.7). All custom_lint fix-candidates (A–E, M) are
> retired. Discovery-D4 (Dart-floor contradiction) is resolved by the Story 1.7 floor raise to
> `>=3.10.0` + pin to Dart 3.12.

### 4.7 — `sprint-status.yaml`

- Under Epic 1: add `1-7-migrate-koel-lints-to-asp: backlog`.
- Flip `epic-1: done` → `epic-1: in-progress` (a backlog story re-opens it; retrospective entry
  stays `done`). Returns to `done` when 1.7 completes.

### 4.8 — Story 1.7 implementation deliverables (DEV, post-approval — NOT landed by this correction)

The `koel_lints` code migration, root `analysis_options.yaml`, consumer-pubspec dep removal,
toolchain pin bumps, and `koel_lints/README.md` rewrite are executed under Story 1.7 (they move
with the code; landing them now would desync docs from the still-custom_lint tree).

---

## Section 5 — Implementation Handoff

- **Scope:** Moderate → route to **Product Owner / Developer**.
- **Immediate (lands this correction, on approval):** §4.2–4.7 planning-artifact edits +
  sprint-status update + this proposal. Owner: Amelia (Developer).
- **Next step:** `create-story` for **Story 1.7** → `bmad-dev-story` to implement (§4.1 ACs + §4.8
  deliverables). Gate Epic 2 Story 2.1 on 1.7 `done`.
- **Epic 9 carry-forward:** external `koel.yaml` distribution verification (Story 9-5); F-A12
  mechanism wording (Story 9-7).

### Success criteria

1. `dart analyze` reports `exhaustive_switch_must_have_default` as ERROR on a real consumer
   package with a no-`default:` sealed switch (the thing custom_lint never achieved).
2. `melos run analyze` exits 0 across all 11 packages with the rule live.
3. `pubspec.lock` resolves clean against the raised Dart `>=3.10.0` floor with `.tool-versions`
   pinned to Dart 3.12 / Flutter 3.44.
4. No `custom_lint` / `custom_lint_builder` / `strict.yaml` references remain in code or the
   updated planning artifacts.
