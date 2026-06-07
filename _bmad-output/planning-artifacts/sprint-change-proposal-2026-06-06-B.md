# Sprint Change Proposal — Ship v1.0.0 before DevTools (SCP-2026-06-06-B)

- **Date:** 2026-06-06
- **Author:** Amelia (Developer) + Si Huynh (Project Lead)
- **Trigger:** Epic-7 retrospective. With `koel_widgets` (Epic 7) sealed, Si elected to **run the release epic (Epic 9) next, before the DevTools epic (Epic 8)** — ship v1.0.0 on the runtime+UI SDK and treat DevTools as a post-1.0 feature.
- **Scope class:** **Minor–Moderate** (roadmap resequence + planning-prose edits; **zero code**, pre-v1.0.0, no published API). No architecture reversal.
- **Decision:** **Direct Adjustment** — Epic 9 runs next and publishes the **ten** packages that exist at release. `koel_devtools` is deferred **post-1.0 (target 1.1)** and renumbered **Epic 10**. Epic 9's prose is corrected to the ten-package release set; the layout-polish item carried out of the Epic-7 retro (AI-7.1) is folded into Story 9.2.

## 1. Issue Summary

Epic 9 ("Meta-Package, Sample App & v1.0.0 Release Gates") was authored assuming all
eleven packages — including `koel_devtools` — exist at v1.0.0. Resequencing Epic 9 ahead
of the DevTools epic means **v1.0.0 publishes before `koel_devtools` is built**, so every
Epic-9 reference to devtools (publish list, package counts, docs concept page, the meta /
convention assertions) must be struck to the release set that actually exists.

## 2. Why the reorder is architecturally clean (no re-architecture)

- **Lock-step is narrow.** v1.0.0 lock-step is only on `koel_core` + `koel_http` +
  `koel_lints` (Story 9.9 AC). The other packages version **independently** against
  `^1.0.0` ranges (FR-H2, PRD §12 R-3).
- **The meta-barrel never included devtools.** `koel/lib/koel.dart` re-exports exactly
  three packages — `koel_core`, `koel_http`, `koel_flutter` (Story 9.1 AC). The
  `dart pub add koel` quickstart path is unaffected by devtools' absence.
- **DevTools is a leaf dependent.** `koel_devtools` depends on `koel_core` (AgentSubscriber,
  reducer) + the 6.6 `ToolReplayContext` (already shipped, Epic 6) + `devtools_extensions`.
  Nothing in v1.0.0 depends on `koel_devtools`. It therefore ships later as a
  `^1.0.0`-ranged dependent at 1.1 without breaking the foundation lock-step.
- **Zero functional dependency in Epic 9.** No Epic-9 story imports or tests devtools
  behavior; every reference was prose/packaging (count "eleven", a publish-list entry, a
  docs concept page, a convention-assertion clause).

## 3. Impact Analysis & Edits Applied

**`epics/epic-9-meta-package-sample-app-v100-release-gates.md`** (this batch):

| Story | Was | Now |
|---|---|---|
| Header | (no resequence note) | `> Resequence (SCP-2026-06-06-B)` blockquote — ten-package release, devtools → Epic 10 |
| 9.1 | "backend bridges + Flutter + widgets + **devtools** + test packages" | devtools clause removed from the `^1.0.0`-convention CI assertion |
| 9.2 | sample-app demo ACs | **+ AI-7.1**: `MessageBubble` width-capped + long-code no-clip across six platforms (the `ConstrainedBox(maxWidth)` deferred from Story 7.2 lands here) |
| 9.5 | "across all **eleven** packages" | "across all **ten** packages (`koel_devtools` deferred post-1.0)" |
| 9.6 | concept list "…sessions, **devtools**"; "all **eleven** packages meet…" | devtools concept page → "lands with Epic 10 post-1.0"; "**ten** packages" |
| 9.9 | "**seven** dependent packages … `koel_widgets`, **`koel_devtools`**, then `koel`" | "**six** dependent packages … `koel_widgets`, then `koel`" (`koel_devtools` joins in Epic 10) |

**`epics/epic-list.md`:** Epic 8 header gains a `> RESEQUENCED post-1.0` blockquote
(renumber → Epic 10 at kickoff; story keys stay `8-x` until devtools work starts).

**`implementation-artifacts/sprint-status.yaml`:** `epic-7 → done`,
`epic-7-retrospective → done`; the `epic-8` block annotated as resequenced post-1.0
(renumber → Epic 10 at kickoff); header note records this SCP. **No `8-x` story keys are
renamed** — a mass renumber across the epic file, epic-list, index, and status keys is
churn with no benefit until devtools starts; the conceptual "Epic 10" is recorded and the
rename is a one-shot mechanical task at kickoff.

## 4. Carried action items (from the Epic-7 retro)

- **AI-7.1** — bubble max-width cap + long-code horizontal → **folded into Story 9.2** (done, this batch).
- **AI-7.2** — `TextStyle.lerp` inherit-parity dartdoc note → **Story 9.6** (docs-final).
- **AI-7.4** — vet `devtools_extensions: 0.5.1` vs the AI-5.9 analyzer/freezed pin (the same
  transitive-analyzer risk that made Story 7.4 refuse `alchemist`) → **demoted to Epic 10
  kickoff prep** (no longer Epic-9 prep).

## 5. Open product sub-decision (defaulted, Si may override)

v1.0.0 release notes mention **"DevTools coming in 1.1"** so pub.dev visitors know the
observability story is planned. Default chosen; reversible at release time.

## 6. Verification

Planning-artifact edits only — no gates run (no code touched). `grep -nE 'eleven|seven
dependent|koel_devtools' epic-9*.md` after the batch returns only the intentional
"deferred post-1.0 / Epic 10" references; the publish list, counts, and docs concept set
are the ten-package release set.
