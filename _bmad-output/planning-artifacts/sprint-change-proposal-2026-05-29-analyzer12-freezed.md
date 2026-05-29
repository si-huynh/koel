# Sprint Change Proposal — Analyzer 12 stopgap to reconcile `freezed` ↔ `analysis_server_plugin`

- **ID:** SCP-2026-05-29-B (analyzer-freezed)
- **Date:** 2026-05-29
- **Author:** Amelia (Dev) · approved by Si Huynh
- **Trigger story:** Story 2.1 — Foundation contracts (`koel_core`), Task 1 (codegen toolchain)
- **Status:** Approved → Option B
- **Scope classification:** Moderate (amends pinned architecture decisions D1/D2/D3 + Story 2.1; no epic replan)
- **Supersedes the lint-pivot version pins set in:** SCP-2026-05-29 (custom_lint → analysis_server_plugin)

---

## 1. Issue Summary

Story 2.1 is the **first story to introduce `freezed`/`build_runner` codegen**. Its Task 1 (codegen toolchain for `koel_core`) is **blocked at `melos bootstrap`** by an unresolvable `analyzer` version conflict inside the shared pub-workspace resolution:

```
Because freezed >=3.2.5 depends on analyzer >=9.0.0 <11.0.0 ... and
koel_lints depends on analyzer ^13.0.0, version solving failed.
```

**Root cause.** A pub workspace resolves **all members against one `analyzer` version**. The prior correct-course (SCP-2026-05-29, the lint pivot) raised the workspace to `analyzer 13` (D3: `analysis_server_plugin 0.3.15`) to make `koel_lints` fire, but **D2 (`freezed ^3.2.5`) caps `analyzer` at `<11`** and was never reconciled. The two pinned decisions are mutually exclusive in one resolution. Story 2.1 is simply the first story that exercises `freezed`, so the latent **D2 ↔ D3 conflict** surfaces now. This is the exact failure mode retro lesson A1 warned about (verify the toolchain before relying on pinned versions).

**Evidence (empirically verified, not assumed).** Four resolution strategies were prototyped end-to-end against the real Dart 3.12 toolchain:

| Option | Bootstrap | freezed/codegen | asp lint fires on member | koel_lints own tests | Verdict |
|---|---|---|---|---|---|
| **A** — freezed stable 3.2.5, `koel_lints` out of pub workspace | ✓ | ✓ (`*.freezed.dart`+`*.g.dart`) | ✓ (root-options path plugin loads standalone koel_lints) | ✓ (analyzer 13) | viable; **reintroduces isolated resolution that D3 deliberately abandoned** + monorepo surgery |
| **B (chosen)** — freezed `3.2.6-dev.1` + asp `0.3.14`, both at `analyzer 12`, workspace intact | ✓ | ✓ | ✓ (asp-12 plugin fires on the Dart 3.12 / analyzer-13 server) | ✓ (analyzer 12, **no code changes**) | viable; **preserves D3 workspace-native model**; cost = temporary pre-release pin |
| **C** — drop freezed, hand-write contracts | n/a | n/a (no codegen) | ✓ | ✓ | viable but heavy; reverses D2; boilerplate at Epic-2 scale (~25 event subtypes in 2.2) |
| **D/B-classic** — analyzer 12 **but** forced Dart 3.9 | — | — | — | — | **moot** — testing showed asp-12 fires on Dart **3.12** (no downgrade needed) |

> Correction on the record: an initial assessment called Option B infeasible ("requires Dart 3.9"). Direct testing disproved this — `asp 0.3.14` (analyzer 12) loads and fires inside the Dart 3.12 analysis server, and the full workspace bootstraps at analyzer 12 with no SDK downgrade. The "dead" call was an untested assertion; the experiment reversed it.

---

## 2. Impact Analysis

- **Epic Impact:** Epic 2 only. No scope change to any epic. Epic 2 remains `in-progress`, Story 2.1 remains the gating story.
- **Story Impact:**
  - **Story 2.1** — Task 1 + AC5 amended (exact dependency pins). Implementation approach (freezed-based) is **unchanged** — this is the key benefit of B over F/C.
  - **Stories 2.2–2.15** — unaffected; they continue to build on `freezed` exactly as written.
- **Artifact Conflicts (require edits):**
  - `architecture.md` — **D1** (CI resolution note), **D2** (freezed version), **D3** (asp + analyzer versions), Decision-Completeness summary (§ line ~1164).
  - `2-1-foundation-contracts.md` — Task 1 pins + AC5; two side-findings (below).
- **Technical Impact:**
  - `packages/koel_lints/pubspec.yaml` — asp `^0.3.15`→`0.3.14`, analyzer `^13.0.0`→`^12.0.0`, analyzer_testing `^0.2.6`→`0.2.5`. **Rule source unchanged** (analyzer 12/13 API-compatible; all 5 koel_lints tests pass).
  - `packages/koel_core/pubspec.yaml` — new freezed/json toolchain at the dev pin.
  - **No workspace-structure change**, no CI topology change, no `melos` script topology change. (CI codegen-aware tasks in Story 2.1 Task 7 stand as written.)
  - **Two side-findings discovered during validation (apply in Story 2.1):**
    1. `json_annotation` must be `^4.12.0` (not `^4.9.0`) — `json_serializable 6.14` requires `>=4.12.0`, else a build warning.
    2. `dart run build_runner build --delete-conflicting-outputs` — the `--delete-conflicting-outputs` flag is **removed / now a no-op** in the resolved `build_runner`. Drop it from the documented command.

---

## 3. Recommended Approach — Option B (Direct Adjustment)

**Adopt analyzer 12 workspace-wide as a documented, temporary stopgap**, keeping `freezed` as the codegen tool and `koel_lints` workspace-native:

- `freezed: 3.2.6-dev.1` + `freezed_annotation: ^3.1.0`
- `analysis_server_plugin: 0.3.14` + `analyzer: ^12.0.0` (+ `analyzer_testing: 0.2.5`)
- Dart/Flutter CI pin **unchanged** (3.12 / 3.44).

**Rationale.** B is the only validated option that (a) keeps `freezed` (honoring D2's intent and leaving Stories 2.2–2.15 untouched), (b) keeps `koel_lints` **inside the pub workspace** — preserving the "workspace-native by construction" property that the lint pivot fought to obtain, which Option A would undo — and (c) needs **no monorepo surgery and no Dart downgrade**.

**Upgrade trigger (exit condition).** When a **stable** `freezed` publishes support for `analyzer >= 13`, bump in lockstep: `freezed → stable`, `analysis_server_plugin → 0.3.15`, `analyzer → ^13.0.0`, `analyzer_testing → 0.2.6`. Re-run `melos bootstrap` + `dart test` in `koel_lints`. This reverts the workspace to all-stable, all-latest with zero structural debt.

**Effort:** ~1 hour of pubspec + architecture-doc edits; then Story 2.1 implementation proceeds as originally planned.

**Risk & mitigation:**
- *Pre-release `freezed` dependency* — pinned to an exact version; `3.2.6-dev.1` is a forward-compat (analyzer-12) build of mature `freezed`; documented stopgap with a clear exit. **Low.**
- *Version skew (analyzer-12 plugin on analyzer-13 analysis server)* — proven working on Dart 3.12 and controlled by the Dart CI pin. Flagged in D1 as a thing to re-verify on any Dart bump. **Low, controlled.**
- *Silent lint regression* — guarded by the existing `koel_lints` integration test (`dart analyze` fires on a fixture) which runs in CI.

---

## 4. Detailed Change Proposals

### 4.1 `architecture.md` — D2 (freezed major version)

```
OLD:
**Decision:** `freezed: ^3.2.5` (current stable, build_runner-based)

NEW:
**Decision:** `freezed: 3.2.6-dev.1` (pre-release stopgap; build_runner-based)
_(amended from `^3.2.5` via SCP-2026-05-29-B — see "analyzer-12 stopgap" below)_
```
Append to D2 rationale: the stopgap note + the upgrade trigger (lockstep with D3 → analyzer 13 when stable freezed supports it).

### 4.2 `architecture.md` — D3 (koel_lints plugin tech)

```
OLD:
**Decision:** Build `koel_lints` on `analysis_server_plugin: ^0.3.15` +
`analyzer: ^13.0.0` _(reversed from `custom_lint 0.8.1` ...)_.

NEW:
**Decision:** Build `koel_lints` on `analysis_server_plugin: 0.3.14` +
`analyzer: ^12.0.0` (analyzer_testing 0.2.5) _(reversed from `custom_lint 0.8.1`
via SCP-2026-05-29; analyzer 13→12 stopgap via SCP-2026-05-29-B to share one
workspace resolution with `freezed` — rule source unchanged, API-compatible)_.
```

### 4.3 `architecture.md` — D1 (CI resolution note, line ~271)

```
OLD:
**Contributor / CI pin:** `.tool-versions` pins **Dart 3.12 / Flutter 3.44** — the
versions the asp spike actually resolved `analysis_server_plugin 0.3.15` +
`analyzer 13.0.0` on (resolution-proven; declared floor stays `>=3.10.0`).

NEW:
**Contributor / CI pin:** `.tool-versions` pins **Dart 3.12 / Flutter 3.44**
(unchanged). Per SCP-2026-05-29-B the workspace resolves at **`analyzer 12.1.0`**
(`analysis_server_plugin 0.3.14` + `freezed 3.2.6-dev.1`) so codegen and the
analyzer plugin coexist in one resolution; the analyzer-12 plugin is verified to
load+fire on the Dart-3.12 (analyzer-13) analysis server. Re-verify this skew on
any Dart SDK bump. Declared floor stays `>=3.10.0`.
```

### 4.4 `architecture.md` — Decision-Completeness summary (line ~1164)

```
OLD: ... D2: freezed 3.2.5; D3: analysis_server_plugin 0.3.15 + analyzer 13.0.0; ...
NEW: ... D2: freezed 3.2.6-dev.1 (stopgap); D3: analysis_server_plugin 0.3.14 + analyzer 12.0.0 (stopgap, → 13 when stable freezed supports it); ...
```

### 4.5 `2-1-foundation-contracts.md` — Task 1 + AC5

- Task 1 dependency line: `freezed: ^3.2.5` → `freezed: 3.2.6-dev.1`; `freezed_annotation` → `^3.1.0`; `json_annotation` → `^4.12.0` (was `^4.9.0`).
- Add Task 1 subtask: bump `koel_lints/pubspec.yaml` to asp `0.3.14` + analyzer `^12.0.0` + analyzer_testing `0.2.5`; confirm `melos bootstrap` resolves and `dart test` in `koel_lints` stays green.
- AC5 text: `freezed: ^3.2.5 (per AR-4 / D2)` → `freezed: 3.2.6-dev.1 (per D2, SCP-2026-05-29-B stopgap)`.
- Task 8 / AC5 command: drop `--delete-conflicting-outputs` (removed/no-op in current build_runner).

### 4.6 PRD

No PRD change. D1's SDK-floor PRD update (§10.3 N-9/N-10) is independent of this SCP and remains as previously tracked.

---

## 5. Implementation Handoff

- **Scope:** Moderate → handled directly by the Developer agent (Amelia), continuing the in-flight Story 2.1 dev-story run.
- **Deliverables:**
  1. This Sprint Change Proposal (recorded).
  2. Architecture amendments §4.1–4.4 applied.
  3. Story 2.1 amendments §4.5 applied to the story file.
  4. Story 2.1 implemented under Option B (TDD), CI codegen-aware tasks per Task 7.
- **Success criteria:** `melos bootstrap` green; `koel_core` freezed codegen green; `koel_lints` tests green; `dart analyze` fires the koel rule; all Story 2.1 ACs satisfied.
- **Next step:** resume `bmad-dev-story` for Story 2.1 from Task 1.
