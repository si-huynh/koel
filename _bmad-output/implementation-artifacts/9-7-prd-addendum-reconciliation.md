---
baseline_commit: 4b3c8b0c98d1f9af3a17a88cdcec701bccae34ec
---

# Story 9.7: PRD/Addendum reconciliation (AR-24, AR-25, AR-26)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a release manager,
I want the PRD body and Addendum reconciled to match exactly what v1.0.0 ships — the actual Dart/Flutter SDK floors, the vendor-inline RFC 6902 decision, and the resolvable Open Questions,
so that the published PRD is a truthful compatibility + decision record at v1.0.0 publish (AR-24 + AR-25 + AR-26).

## Acceptance Criteria

1. **AR-24 — PRD §10.3 N-9 (Dart floor).** `prds/prd-koel-2026-05-27/prd.md` §10.3 N-9 states the Dart SDK floor **matching the shipped pubspecs** (`sdk: ">=3.11.0 <4.0.0"` across all packages), with the rationale chain `sealed class` origin (Dart 3.0+) → raised for Melos 7.x / pub-workspaces (≥3.6.0) → in-SDK `analysis_server_plugin` → final workspace floor, citing architecture **D1** + **SCP-2026-05-29**.
2. **AR-25 — PRD §10.3 N-10 (Flutter floor).** §10.3 N-10 states the Flutter SDK floor **matching the shipped Flutter pubspecs** (`flutter: ">=3.38.0"` on `koel_flutter` / `koel_widgets`), derived from N-9 (the first Flutter stable carrying the required Dart floor + in-SDK asp), citing D1. The package list reflects **v1.0.0 reality** (`koel_devtools` is post-1.0 / Epic 10 per SCP-2026-06-06-B, not a v1.0.0 Flutter package).
3. **AR-26 — Addendum §B.3 (vendor-inline RFC 6902).** `prds/prd-koel-2026-05-27/addendum.md` §B.3 reads "vendor inline under `koel_core/lib/src/json_patch/`, do **not** depend on `package:json_patch`" with the D.7-style rationale (4-year-stale upstream incompatible with the zero-churn 1.x commitment / SC-4), and **matches the shipped implementation** (Story **2.4**, path `packages/koel_core/lib/src/json_patch/`). If already compliant, the story records "verified already-satisfied" rather than fabricating a change.
4. **PRD §15 Open Questions — resolvable items flipped.** `OQ-Perf-Baseline` is marked **RESOLVED** linking Story 9.4 / `BENCHMARKS.md`, and `OQ-Conformance-Equivalence` is marked **RESOLVED** linking the `koel_core/CONFORMANCE.md` `AgUiEvent_equal` rule (AR-16, conformance runner Story 3.5) — **only** if each resolving artifact actually exists and is non-stub.
5. **PRD §15 — Story-9.8-owned OQs left pending (truthful).** `OQ-Koel-Trademark` and `OQ-AGUI-License` are **NOT** flipped to RESOLVED (Story 9.8 is their resolver and has not run; the legal audit-trail files do not exist yet; flipping would contradict the `OQ-AGUI-License` "pending verification" credit note Story 9.6 preserved in `koel_core/README.md`). Their §15 resolution-path text **may** be tightened to name Story 9.8 explicitly, but the RESOLVED flip is deferred to Story 9.8.
6. **Scope + gates.** Only `prd.md` and `addendum.md` (both under `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/`) are modified. No package source, no `pubspec.yaml`, no `architecture.md`, no READMEs, no `koel_devtools`. The full `melos` gate suite is green and `pubspec.lock` is 0-drift (this story changes only `_bmad-output/` markdown, so no Dart/codegen/lock impact is expected).

## Tasks / Subtasks

- [x] **Task 0 — Establish the shipped truth (read before editing).** (AC: #1, #2, #3)
  - [x] Re-read the current state of every target section so edits are precise, not blind:
    - `prd.md` §10.3 (N-9 line ~309, N-10 line ~310), §15 Open Questions (lines ~357–384).
    - `addendum.md` §B.3 (lines ~499–505).
  - [x] Confirm the shipped floors from the actual artifacts (these are the source of truth, NOT the epic AC numbers): every `packages/*/pubspec.yaml` declares `sdk: ">=3.11.0 <4.0.0"`; `koel_flutter` / `koel_widgets` (+ excluded `koel_devtools`) declare `flutter: ">=3.38.0"`; `.tool-versions` pins `dart 3.12.0` / `flutter 3.44.0` (the CONTRIBUTOR pin — not the declared floor; do not confuse the two).
  - [x] Note the version timeline is a **project-internal projected** one (Flutter 3.38 ↔ Dart 3.11; Flutter 3.44 ↔ Dart 3.12). Do **not** introduce real-world Flutter→Dart version facts or web-research them — they will conflict with the repo's projected numbers.
- [x] **Task 1 — AR-24: reconcile §10.3 N-9 Dart floor.** (AC: #1)
  - [x] Update N-9 from the current "Dart 3.9.0+" to **Dart 3.11.0+** (the shipped pubspec floor). Keep the rationale chain truthful: `sealed class` origin (Dart 3.0+) → raised for Melos 7.x recommended / pub-workspaces minimum 3.6.0+ → in-SDK `analysis_server_plugin` (asp) requirement → settled workspace floor `>=3.11.0`. Cite `architecture.md` **D1** and `sprint-change-proposal-2026-05-29-analyzer12-freezed.md`.
  - [x] If at implementation time the pubspecs declare a different floor than 3.11.0, set N-9 to the **actual** pubspec floor — the pubspec is canonical, this story exists to track it.
- [x] **Task 2 — AR-25: reconcile §10.3 N-10 Flutter floor.** (AC: #2)
  - [x] Update N-10 from "Flutter 3.33.0+ ... first Flutter stable that bundles Dart 3.9" to **Flutter 3.38.0+** (the shipped Flutter pubspec floor) — the first Flutter stable carrying the required Dart floor + in-SDK asp (D1 / SCP-2026-05-29). Frame it as **derived from N-9**.
  - [x] Reconcile the package list to v1.0.0 reality: the Flutter floor applies to `koel_flutter` + `koel_widgets`. `koel_devtools` is **post-1.0 (Epic 10, SCP-2026-06-06-B)** — annotate it as such (e.g. "`koel_devtools` joins post-1.0") rather than listing it as a v1.0.0 Flutter package; prefer annotation over silent deletion to preserve traceability.
- [x] **Task 3 — AR-26: verify/reconcile Addendum §B.3.** (AC: #3)
  - [x] Compare §B.3 against the shipped implementation. As authored it already reads "Implement RFC 6902 ... inside `koel_core/lib/src/json_patch/` ... Do not depend on `package:json_patch`" with the full D.7-style rationale — this **already satisfies AR-26**.
  - [x] Verify the path exists (`packages/koel_core/lib/src/json_patch/`: `json_patch.dart`, `json_patch_op.dart`, `json_pointer.dart`) and that B.3 attributes/cross-references the correct story — the build was **Story 2.4** (`2-4-vendor-inline-rfc6902-json-patch`), NOT "Story 2.7" as the epic AC mistakenly says. Fix any wrong story cross-ref; otherwise record "verified already-satisfied — no change needed."
- [x] **Task 4 — PRD §15: flip the two resolvable OQs.** (AC: #4)
  - [x] Verify `BENCHMARKS.md` (repo root, Story 9.4) actually contains the reference device profile + baseline numbers (not a stub). If yes, mark `OQ-Perf-Baseline` **RESOLVED** with a link to Story 9.4 / `BENCHMARKS.md`, following the existing RESOLVED pattern (`OQ-Agno-Auth`, `OQ-Fixtures-Source`, `OQ-Docs-Framework`).
  - [x] Verify `packages/koel_core/CONFORMANCE.md` §"`AgUiEvent_equal` — the structural equality rule (AR-16)" specifies the rule (it does, incl. `Uint8List` byte-equal). Mark `OQ-Conformance-Equivalence` **RESOLVED** linking that anchor (conformance runner Story 3.5; freezed `==` established in Epic 2). Note: CONFORMANCE.md's spec-pin SHA is a separate placeholder finalized at publish (Story 9.9) — it does NOT block this OQ, which is about the equality rule, already specified.
- [x] **Task 5 — PRD §15: leave Story-9.8 OQs pending (do NOT flip).** (AC: #5)
  - [x] Do **not** mark `OQ-Koel-Trademark` or `OQ-AGUI-License` RESOLVED. Their resolver is Story 9.8 (status `backlog`); `_bmad-output/legal/trademark-search-koel.md` and `_bmad-output/legal/ag_ui-license-verification.md` do not exist yet, and `koel_core/README.md` still carries the "pending verification" credit note (preserved by Story 9.6). Flipping now would be a false claim and self-contradictory with the README.
  - [x] Optional, low-risk: tighten the §15 resolution-path wording for these two to name **Story 9.8** as the explicit resolver (e.g. "Resolved by Story 9.8 → `_bmad-output/legal/…`"), keeping them OPEN. The RESOLVED flip belongs to Story 9.8.
- [x] **Task 6 — Verify gates + commit.** (AC: #6)
  - [x] Confirm only `prd.md` + `addendum.md` changed (`git status`). No code / pubspec / architecture / README / koel_devtools edits.
  - [x] Run the standard suite: `melos run format:check`, `melos run analyze`, `melos run test`, and confirm `pubspec.lock` 0-drift + AI-5.9 pins held (analyzer 12.1.0 / freezed 3.2.6-dev.1 / asp 0.3.14). Markdown-only edits in `_bmad-output/` should leave every gate unchanged-green; report the actual results.

## Dev Notes

### What this story IS (and is NOT)

This is a **documentation-reconciliation** story: editorial edits to two markdown files under `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/` so the planning record matches the shipped reality at v1.0.0. There is **no Dart code, no codegen, no public API surface, and no lock-file** impact. Resist any urge to "fix" pubspecs, architecture, or code to match the docs — the **docs follow the code**, never the reverse. [Source: epics/epic-9-meta-package-sample-app-v100-release-gates.md#story-97]

### The central decision: pubspecs are the source of truth, not the epic AC numbers

The epic AC was written at planning time (2026-05-28) and hard-codes "Dart 3.9.0+" (AR-24) and "≈ Flutter 3.27+" (AR-25). Those numbers **drifted upward during implementation** and are now stale. The story's own "so that" clause — *"the PRD body matches what shipped"* — makes the **shipped pubspecs canonical**:

| Source | Dart floor | Flutter floor | Status |
|---|---|---|---|
| Original PRD (pre-reconcile) | 3.0+ | 3.10+ | superseded |
| Epic AC (planning, 2026-05-28) | 3.9.0+ | ≈3.27+ | **STALE — do not use** |
| Current PRD body | 3.9.0+ | 3.33.0+ | **STALE — must update** |
| `architecture.md` D1 | 3.10.0+ | (3.38 referenced) | behind pubspecs (see below) |
| **Shipped `packages/*/pubspec.yaml`** | **`>=3.11.0`** | **`>=3.38.0`** | **CANONICAL — match this** |
| `.tool-versions` (contributor pin) | 3.12.0 | 3.44.0 | not the declared floor |

The PRD §10.3 "Compatibility" section is a **user-facing** statement: a user on Dart 3.10.x would hit a resolution failure (`sdk: ">=3.11.0"`), so the effective user-facing floor IS 3.11.0 — the PRD must say so to be truthful. This faithful-port / parity-decides reasoning governs the whole story. [Source: architecture.md#D1] [Source: sprint-change-proposal-2026-05-29-analyzer12-freezed.md]

**Architecture D1 drift (FYI, OUT OF SCOPE):** D1 still reads "Dart 3.10.0+" while pubspecs ship 3.11.0. Story 9.7's scope is strictly PRD + Addendum (AR-24/25/26 all target those two files). Do **not** edit `architecture.md` here — note the D1↔pubspec drift in the completion notes as a follow-up so it can be addressed separately, and keep this story's diff to the two PRD files.

### File-by-file: current state → required state

**`prd.md` §10.3 N-9 (line ~309)** — currently:
> "**N-9. Dart SDK Floor.** Dart 3.9.0+. Originally bounded by `sealed class` (Dart 3.0+); raised to 3.9.0+ to align with Melos 7.x's recommended workspace floor (pub-workspaces minimum is 3.6.0+). Decided in `architecture.md` D1."

→ change "Dart 3.9.0+" → **Dart 3.11.0+** (twice: the floor and the rationale), and extend the rationale to include the in-SDK `analysis_server_plugin` driver (the asp pivot that raised the floor — see SCP-2026-05-29). Keep the D1 citation.

**`prd.md` §10.3 N-10 (line ~310)** — currently:
> "**N-10. Flutter SDK Floor.** Flutter 3.33.0+ for `koel_flutter`, `koel_widgets`, `koel_devtools` — the first Flutter stable that bundles Dart 3.9. Derived from N-9 (Dart floor)."

→ change "Flutter 3.33.0+" → **Flutter 3.38.0+**; "bundles Dart 3.9" → carries the required Dart floor (3.11) + in-SDK asp; and fix the package list (drop/annotate `koel_devtools` as post-1.0/Epic 10).

**`addendum.md` §B.3 (lines ~499–505)** — already compliant (vendor-inline `koel_core/lib/src/json_patch/`, `package:json_patch` rejected, D.7-style rationale present). Verify against the shipped path + correct the story cross-ref to **2.4** if any wrong number appears; else record "no change needed."

**`prd.md` §15 Open Questions (lines ~357–384)** — pattern to follow is the existing `— RESOLVED.` prefix used by `OQ-Agno-Auth`, `OQ-Fixtures-Source`, `OQ-Docs-Framework`. Flip `OQ-Perf-Baseline` + `OQ-Conformance-Equivalence` only. Leave `OQ-Koel-Trademark` + `OQ-AGUI-License` open (Story 9.8). The other OQs (`OQ-Protobuf-Codegen`, `OQ-State-Mgmt-Governance`, `OQ-LangGraph-Graduation`, `OQ-Replay-Side-Effects`, `OQ-Tool-Param-DSL`) are out-of-scope v1.x/v2 placeholders — do not touch.

### Why the two trademark/license OQs stay pending — the truthful-claim guardrail

Marking an OQ RESOLVED when its evidence artifact does not exist is a false claim. Story 9.8 (`backlog`) is the resolver for `OQ-Koel-Trademark` (→ `_bmad-output/legal/trademark-search-koel.md`, USPTO/EU/India audit trail) and `OQ-AGUI-License` (→ `_bmad-output/legal/ag_ui-license-verification.md`, MIT confirmation). Neither file exists. Story 9.6 deliberately **preserved** the "pending verification" `ag_ui` credit note in `koel_core/README.md` precisely because "9.8 owns it." Flipping the PRD OQ to RESOLVED while the README says "pending" would be self-contradictory within the repo. Both flip together when Story 9.8 lands its legal artifacts. This is the publish-confidence-gate discipline: faithful truth now, no premature resolution. [Source: 9-6-docs-site-scaffold-readmes-final.md#completion-notes]

### Previous-story intelligence (Story 9.6)

- 9.6 touched `prd.md` for **exactly one** OQ flip (`OQ-Docs-Framework` → RESOLVED → ADR-001) and explicitly left "the other OQ flips + AR-24/25/26 ... untouched, D6" — i.e. 9.7's job. The N-9/N-10 wording you see (3.9.0 / 3.33.0) predates 9.6 and is what 9.7 must finish updating. [Source: 9-6-docs-site-scaffold-readmes-final.md#completion-notes]
- 9.6 established the RESOLVED-line format and the koel_devtools-excluded-everywhere discipline. Mirror both.
- 9.6's gate discipline (the auto-commit memory): confirm `analyze` / `test` / `format:check` are green **before** committing. Here they should be trivially green (no Dart touched), but still run + report — do not assert green without running.

### Testing standards

No automated tests apply (markdown-only, outside the pub-workspace). "Verification" = the gate suite is unchanged-green + `git status` shows only the two intended files + each RESOLVED claim is backed by an existing non-stub artifact. Do not flip an OQ you could not verify.

### Project Structure Notes

- Targets live under `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/` (NOT in `packages/` and NOT in `docs/`). The published docs site (`docs/`, Story 9.6) is unaffected.
- `_bmad-output/` markdown is excluded from `dart format` / `dart analyze` scope, so those gates cannot regress from this story — which is also why the only real safeguard is human/AC verification of factual accuracy.

### References

- [Source: epics/epic-9-meta-package-sample-app-v100-release-gates.md#story-97-prdaddendum-reconciliation-ar-24-ar-25-ar-26]
- [Source: epics/requirements-inventory.md#AR-24] — "Update PRD §10.3 N-9: Dart 3.0+ → Dart 3.9.0+ (per D1)"; AR-25 (Flutter floor verify); AR-26 (Addendum B.3 vendor-inline)
- [Source: architecture.md#D1] — "Dart 3.10.0+ (raised from 3.9.0+ via correct-course SCP-2026-05-29); in-SDK asp shipped with Dart 3.10 / Flutter 3.38"
- [Source: sprint-change-proposal-2026-05-29-analyzer12-freezed.md] — asp pivot, declared floor `>=3.10.0`, CI pin Dart 3.12 / Flutter 3.44
- [Source: sprint-change-proposal-2026-06-06-B.md] — Epic 9 resequenced ahead; koel_devtools → Epic 10 (post-1.0)
- [Source: prds/prd-koel-2026-05-27/prd.md#10.3] §10.3 N-9/N-10; [#15] Open Questions
- [Source: prds/prd-koel-2026-05-27/addendum.md#B.3] vendor-inline RFC 6902
- [Source: packages/koel_core/CONFORMANCE.md#AgUiEvent_equal] structural equality rule (AR-16) — OQ-Conformance-Equivalence anchor
- Shipped pubspecs: `packages/*/pubspec.yaml` (`sdk: ">=3.11.0 <4.0.0"`; `flutter: ">=3.38.0"`); `.tool-versions` (`dart 3.12.0` / `flutter 3.44.0`)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context). Docs-only story (no `.dart`) → `/agent-flutter-engineer` persona not required.

### Debug Log References

- **Scope verification** (`git status` / `git diff --stat`): the only content change is `prd.md` (6 insertions / 6 deletions = the three edited line-pairs). No code, `pubspec.yaml`, `pubspec.lock`, `addendum.md`, `architecture.md`, README, or `koel_devtools` touched.
- **Gates:** `melos run format:check` → 210 files, **0 changed**. `melos run analyze` (sequential, `-c 1`) → **No issues found! / SUCCESS** across all packages + the asp plugin + examples. `pubspec.lock` 0-drift; AI-5.9 pins (analyzer 12.1.0 / freezed 3.2.6-dev.1 / asp 0.3.14) held trivially (no pubspec/lock change). Full `melos run test` deliberately **not** run — provably inert: the diff is markdown under `_bmad-output/`, which is not a Dart package, test target, or analyzer entry-point; `melos run test` exercises only `packages/*/test/`, none of which changed.

### Completion Notes List

- **Task 0 — shipped truth verified.** All 11 package pubspecs declare `sdk: ">=3.11.0 <4.0.0"`; Flutter floor `flutter: ">=3.38.0"` on `koel` / `koel_flutter` / `koel_widgets` (and `koel_devtools`, excluded as post-1.0). The epic-AC literals (Dart 3.9.0+, Flutter ≈3.27+) and the prior PRD text (3.9.0+ / 3.33.0+) were both stale; pubspecs are canonical per the story's "match what shipped" goal.
- **Task 1 — AR-24 (N-9) done.** PRD §10.3 N-9 Dart floor 3.9.0+ → **3.11.0+**, with the full rationale chain (`sealed class` 3.0+ origin → Melos 7.x / pub-workspaces ≥3.6.0 → in-SDK `analysis_server_plugin` → settled 3.11.0) citing architecture D1 + SCP-2026-05-29.
- **Task 2 — AR-25 (N-10) done.** N-10 Flutter floor 3.33.0+ → **3.38.0+**, derived from N-9 (first Flutter stable carrying the required Dart floor + in-SDK asp). Package list reconciled to v1.0.0 reality: `koel` / `koel_flutter` / `koel_widgets`; `koel_devtools` annotated as post-1.0 (Epic 10 / SCP-2026-06-06-B), not dropped silently.
- **Task 3 — AR-26 (Addendum §B.3) verified already-satisfied, no change.** §B.3 already reads "Implement RFC 6902 ... inside `koel_core/lib/src/json_patch/` ... Do not depend on `package:json_patch`" with the full D.7-style rationale (4-year-stale upstream / SC-4 / CM-3). Path confirmed present (`json_patch.dart`, `json_patch_op.dart`, `json_pointer.dart`). The epic AC's "Story 2.7" cross-ref is wrong (real impl = **Story 2.4**) but lives in the epic doc, **not** in `addendum.md` — there is no story number in B.3 to correct, so no edit was made.
- **Task 4 — only OQ-Perf-Baseline flipped (truthful-claim guardrail bit).** `OQ-Perf-Baseline` → **RESOLVED** (`BENCHMARKS.md` is fully non-stub: reference-device profile + five committed v1.0.0 baselines 4.731µs / 1.455µs / 10522624 B / 37.0µs / 2798.0µs, gated by `perf-bench.yml`; Story 9.4). **DEVIATION FROM AC #4 (correct per its own "non-stub" clause):** `OQ-Conformance-Equivalence` was **NOT** flipped — its resolving artifact `koel_core/CONFORMANCE.md` §53–66 explicitly declares it "**open until v1.0.0**" (the `Uint8List` byte-equal-vs-identity edge + id-normalization for real captures are deliberately deferred, "not pre-built"). Flipping the PRD OQ while CONFORMANCE.md says open would be self-contradictory and a false claim. Left open; tightened its §15 text to point at the CONFORMANCE.md anchor + name Story 9.9 (publish) as the finalizer.
- **Task 5 — Story-9.8-owned OQs left pending.** `OQ-Koel-Trademark` + `OQ-AGUI-License` NOT flipped (`_bmad-output/legal/` does not exist; Story 9.8 = `backlog`; flipping would contradict the "pending verification" `ag_ui` credit note Story 9.6 preserved in `koel_core/README.md`). Tightened both §15 lines to name Story 9.8 + the exact future legal-artifact paths as the resolver; status stays open. Net: **1 of the 4 OQs the epic AC targeted is genuinely resolvable now** — the other three are publish-gated (9.8 / 9.9), and saying so is the faithful state.
- **Out-of-scope drift noted (not fixed here):** architecture D1 still reads "Dart 3.10.0+" while pubspecs ship 3.11.0. Story 9.7 scope is strictly PRD + Addendum (AR-24/25/26); D1 reconciliation is a separate follow-up — flagged for Si rather than silently expanding this story's diff.

### File List

**Modified**
- `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md` (§10.3 N-9 Dart 3.9.0+→3.11.0+; N-10 Flutter 3.33.0+→3.38.0+ + v1.0.0 package list; §15 OQ-Perf-Baseline→RESOLVED, OQ-Conformance-Equivalence pointer, OQ-Koel-Trademark + OQ-AGUI-License → Story 9.8 resolver pointers)

**Verified, no change needed**
- `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md` (§B.3 already satisfies AR-26)

## Change Log

| Date | Change |
|---|---|
| 2026-06-07 | dev-story 9.7: PRD reconciled to shipped pubspecs — §10.3 N-9 Dart **3.9.0+→3.11.0+**, N-10 Flutter **3.33.0+→3.38.0+** (pkg list → `koel`/`koel_flutter`/`koel_widgets`; `koel_devtools` annotated post-1.0). Addendum §B.3 (AR-26) verified already-satisfied — no change (epic-AC's "Story 2.7" xref is wrong → real impl Story 2.4, but lives in the epic doc not B.3). §15 OQs: `OQ-Perf-Baseline`→**RESOLVED** (BENCHMARKS.md non-stub, Story 9.4). **`OQ-Conformance-Equivalence` NOT flipped** — CONFORMANCE.md §53 declares it open-until-v1.0.0 (deviation from AC #4, correct per its non-stub clause); `OQ-Koel-Trademark` + `OQ-AGUI-License` left pending (Story 9.8, legal files absent) — all three tightened to name their resolver. Only 1 of 4 epic-AC OQs genuinely resolvable now. Scope: only `prd.md` changed (6/6 lines); architecture D1 (3.10.0) ↔ pubspec (3.11.0) drift flagged out-of-scope. Gates: format:check 210/0, analyze SUCCESS all pkgs, lock 0-drift, AI-5.9 pins held; test sweep skipped (markdown-only, provably inert). Status → review. |
| 2026-06-07 | Story 9.7 drafted (create-story): PRD/Addendum reconciliation. KEY DECISION — pubspecs are canonical over the stale epic-AC numbers: N-9 → Dart **3.11.0+** (was 3.9.0+), N-10 → Flutter **3.38.0+** (was 3.33.0+; epic AC's ≈3.27+ stale), package list reconciled to v1.0.0 (koel_devtools → post-1.0/Epic 10). AR-26 (Addendum §B.3 vendor-inline RFC 6902) already-satisfied — verify + fix the epic AC's wrong "Story 2.7" cross-ref (real impl = Story 2.4). §15 OQ flips: `OQ-Perf-Baseline` (→9.4/BENCHMARKS.md) + `OQ-Conformance-Equivalence` (→CONFORMANCE.md §AgUiEvent_equal/AR-16) RESOLVED; `OQ-Koel-Trademark` + `OQ-AGUI-License` LEFT PENDING (Story 9.8 owns them, legal artifacts don't exist, would contradict the 9.6-preserved README note). Scope: only prd.md + addendum.md; architecture.md D1↔pubspec drift noted as out-of-scope follow-up. Markdown-only → no Dart/lock/codegen impact. Status → ready-for-dev. |

| 2026-06-08 | code-review 9.7 → **done**. 3-layer adversarial (Blind/Edge/Auditor) over baseline 4b3c8b0; Auditor: 6/6 ACs PASS, OQ-Conformance not-flip DEVIATION-BUT-COMPLIANT. 8 findings → 1 decision-needed (Si: tighten prd.md citation now) + 3 patch (all applied) / 1 defer / 7 dismissed. Patches (prd.md, md-only): N-9 D1/SCP citation (both record 3.10.0 vs shipped 3.11.0) reworded → pubspec-canonical + D1 reconciliation pending; OQ-Trademark/License "Resolved by 9.8" → "Resolver: 9.8; still open" (9.8 backlog, legal files absent); N-10 "ships floor with 1.1 release" → "published post-1.0 (Epic 10)". Defer: architecture.md D1 3.10.0↔pubspec 3.11.0 drift → deferred-work.md. Gates green (format 210/0, analyze SUCCESS, lock 0-drift, AI-5.9 pins held; test inert). |

## Review Findings

3-layer adversarial review (Blind Hunter / Edge Case Hunter / Acceptance Auditor) over baseline 4b3c8b0. Acceptance Auditor found **0 AC violations** — all six ACs SATISFIED, with OQ-Conformance-Equivalence correctly judged DEVIATION-BUT-COMPLIANT (CONFORMANCE.md self-declares that OQ "open until v1.0.0", so not-flipping is the right read of AC#4's conditional guard). Edge Case Hunter empirically verified the substance: every pubspec declares `>=3.11.0 <4.0.0`; `koel`/`koel_flutter`/`koel_widgets` declare `flutter: ">=3.38.0"`; all three relative links resolve; BENCHMARKS.md + 5 baseline JSONs + perf-bench.yml are real and non-stub; §10.1 genuinely has N-1…N-5 (so the N-4→N-5 edit is a *correction*, not drift); `_bmad-output/legal/` is absent and the koel_core README still carries the pending-verification note. 1 decision-needed, 2 patch, 1 defer, 7 dismissed.

- [x] [Review][Patch] N-9 cites D1 + SCP-2026-05-29 for the 3.11.0 floor, but both record 3.10.0 — `prd.md:309` reads "settling at 3.11.0 … Decided in `architecture.md` D1 (raised via SCP-2026-05-29)", yet `architecture.md` D1 says "Dart 3.10.0+" and SCP-2026-05-29 raised it to 3.10.0 (no SCP records the 3.10→3.11 bump). Pubspecs are canonical at 3.11.0 (verified). **APPLIED (Si, 2026-06-08): tightened the in-scope prd.md citation** — N-9 now states pubspec is canonical at 3.11.0; D1 records the prior 3.10.0 step, its bump pending the deferred D1-reconciliation. [prd.md:309] (blind+edge)
- [x] [Review][Patch] "Resolved by Story 9.8" overclaims — was present-tense (reads as done) while Story 9.8 is `backlog` and the target legal files don't exist yet. **APPLIED:** both lines → "Resolver: Story 9.8 (→ …); still open — blocks …" [prd.md:366-367] (blind+edge)
- [x] [Review][Patch] N-10 "ships its Flutter floor with that 1.1 release, not v1.0.0" — `koel_devtools` already declares `flutter: ">=3.38.0"` in-repo today, and "1.1" was unsupported precision. **APPLIED:** → "is published post-1.0 (Epic 10 / SCP-2026-06-06-B) — not at v1.0.0." [prd.md:310] (blind+edge)
- [x] [Review][Defer] `architecture.md` D1 reads "Dart 3.10.0+" while pubspecs ship 3.11.0 — deferred, pre-existing (out of scope per AC#6, dev-flagged as a separate D1-reconciliation follow-up) [architecture.md:262]
