---
baseline_commit: e97bd3c0d85216ababa3c8d0a19edba1b1195117
---

# Story 9.8: Trademark check + `ag_ui` license verification

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a release manager,
I want the "koel" trademark searched across the public registries (USPTO, EU IPO, India IP) scoped to the software / developer-tools classes, the community `ag_ui` 0.1.0 license verified MIT-compatible, both recorded as committed audit-trail files, and the `koel_core` README credit-line finalized,
so that the brand + credit-line release gates (FR-I3 / OQ-Koel-Trademark / OQ-AGUI-License) are cleared and recorded as truthful evidence ahead of the v1.0.0 publish.

## Acceptance Criteria

1. **OQ-AGUI-License — license verification recorded.** `_bmad-output/legal/ag_ui-license-verification.md` exists and confirms the community `ag_ui` 0.1.0 package is **MIT-licensed** (compatible with koel's MIT — FR-H5). The record cites **primary evidence**: the pub.dev license tab for `ag_ui` 0.1.0 *and* the LICENSE in the package's published archive / source repo, each with a verifiable URL and the verification date. It states the conclusion (MIT, compatible, no attribution obligation beyond the existing credit) and notes any nuance found (e.g. the upstream LICENSE copyright line). The file is non-stub (real evidence, not a placeholder).

2. **OQ-Koel-Trademark — search audit trail recorded.** `_bmad-output/legal/trademark-search-koel.md` exists and documents trademark searches against **USPTO + EUIPO + India IP**, each scoped to the relevant goods/services classes for an SDK / developer tool — **Nice Class 9** (software) and **Nice Class 42** (SaaS / software design & development). For each registry the file records: the portal queried (with URL), the query term(s), the search date, and the findings — explicitly distinguishing **conflicts in the relevant class** from the many unrelated-class "koel" marks (the word is the Asian koel bird — expect hits in apparel, food, etc.; those are *not* conflicts). The file states a clear finding (no conflicting mark in Class 9/42, **or** a flagged conflict) and an **honest method/scope note**: this is a public registered-mark database search, not legal clearance — final go/no-go is the owner's (P1, per `brand-reservation.md`). Where a registry portal is not machine-accessible, that limitation is documented honestly (not papered over with a fabricated clean result).

3. **`koel_core` README credit finalized.** In `packages/koel_core/README.md`, the `> **Tracking:** this credit is pending OQ-AGUI-License verification …` blockquote (currently lines ~41–43) is **removed**, leaving the one-line `ag_ui` 0.1.0 credit paragraph (FR-H4) standing as final. No other README content (badges, prose, links) changes.

4. **PRD §15 Open Questions flipped — truthfully.** In `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md` §15, `OQ-AGUI-License` is marked **RESOLVED** linking `_bmad-output/legal/ag_ui-license-verification.md`, following the existing `— RESOLVED.` line format. `OQ-Koel-Trademark` is marked **RESOLVED** linking `_bmad-output/legal/trademark-search-koel.md` **only if** the search (AC #2) is clean in the relevant class; if a conflict surfaced, it stays **OPEN** and is surfaced to Si as a release-blocker. This is the flip Story 9.7 deferred here ("both flip together when Story 9.8 lands its legal artifacts") and keeps the repo self-consistent — the README no longer says "pending."

5. **Scope + gates.** Only these files change: the two new `_bmad-output/legal/*.md` files, `packages/koel_core/README.md`, and `prd.md` §15. **No** Dart source, **no** `pubspec.yaml`, **no** `pubspec.lock` drift, **no** `architecture.md`, **no** `koel_devtools`, **no** other package README. `melos run format:check` is 0-changed, `melos run analyze` is SUCCESS, and the Story-9.6 docs gate `melos run docs` (`dart doc`) is green (a `koel_core` file is touched — run it to confirm the README edit doesn't perturb the build). AI-5.9 pins (analyzer 12.1.0 / freezed 3.2.6-dev.1 / asp 0.3.14) hold trivially (no pubspec/lock change). Report actual gate output, don't assert.

## Tasks / Subtasks

- [x] **Task 0 — Read the current state before editing.** (AC: #1, #2, #3, #4)
  - [x] Re-read the targets so edits are precise: `packages/koel_core/README.md` (credit blockquote at ~41–43, credit paragraph at ~37–39); `prd.md` §15 `OQ-Koel-Trademark` + `OQ-AGUI-License` (lines ~366–367 — current text already names "Resolver: Story 9.8 (→ …); still open"); `brand-reservation.md` "Release blockers (FR-I3)" + the provenance caveat (owner-task framing); PRD FR-I3 (prd.md:205) + FR-H4 (prd.md:197).
  - [x] Confirm `_bmad-output/legal/` does not exist yet — create it as part of this story (both files are net-new).
  - [x] Unlike Story 9.7 (which forbade web research because the version numbers were project-internal), this story **requires real external verification** — these are real-world legal facts (a registry record, a LICENSE file). Use `WebFetch` / `WebSearch` and record evidence URLs + dates.
- [x] **Task 1 — OQ-AGUI-License: verify + record (do this first, it is fully verifiable).** (AC: #1)
  - [x] Confirm `ag_ui` 0.1.0 is MIT from **two** primary sources: the pub.dev license tab (`https://pub.dev/packages/ag_ui` → License) and the LICENSE in the published archive / source repo (`https://github.com/mattsp1290/ag-ui` `LICENSE`). Re-fetch live; record each URL + the fetch date.
  - [x] Write `_bmad-output/legal/ag_ui-license-verification.md`: state package + version (`ag_ui` 0.1.0), the license (MIT), the evidence (both URLs, fetch date, and that the text is the standard unmodified MIT boilerplate), the compatibility conclusion (MIT ⊆ koel's MIT — no copyleft, no extra attribution obligation beyond the existing courtesy credit), and any nuance (the upstream LICENSE copyright line reads "Copyright (c) 2025" with no holder named — note it; it does not affect MIT-compatibility). Cross-reference FR-H4 (the credit) + FR-H5 (MIT) + this story.
- [x] **Task 2 — OQ-Koel-Trademark: search + record.** (AC: #2)
  - [x] Search each public registry for "koel" **scoped to Nice Class 9 (software) + Class 42 (software design/development, SaaS)** — the only classes where a conflict would block an SDK brand:
    - **USPTO** — the Trademark Search system at `https://tmsearch.uspto.gov` (the legacy TESS was retired; use the current search) — note: TSDR/search portals are JS-heavy and may not be `WebFetch`-able directly; attempt, and if blocked, document the limitation + record what is reachable (e.g. a public search-result page, or a `WebSearch` corroboration).
    - **EUIPO** — eSearch plus at `https://euipo.europa.eu/eSearch/`.
    - **India IP** — the Trade Marks public search at `https://ipindiaonline.gov.in/tmrpublicsearch/`.
  - [x] Write `_bmad-output/legal/trademark-search-koel.md`: for each registry record the portal URL, query, date, and findings; **separate relevant-class conflicts from unrelated-class noise** ("koel" is a common word — the Asian koel bird; expect apparel/food/other-class marks that are *not* conflicts). State the finding per registry + an overall conclusion. Include the **honest method/scope note**: this is a registered-mark public-database search (not common-law/unregistered clearance, not a legal opinion); final clearance is the owner's call (P1, per `brand-reservation.md`'s provenance caveat — names were reserved ahead of clearance as an accepted squatting-protection trade-off, forfeit if trademark fails).
  - [x] If a **Class 9/42 conflict** surfaces: do NOT declare clean — record it prominently and surface it to Si as a v1.0.0 release-blocker (this gates the publish, FR-I3).
- [x] **Task 3 — Finalize the `koel_core` README credit.** (AC: #3)
  - [x] Remove the `> **Tracking:** this credit is pending OQ-AGUI-License verification …` blockquote (the "pending verification" note from Story 1.6, preserved by Story 9.6). Leave the `## Credits` paragraph crediting `ag_ui` 0.1.0 intact as the finalized credit. Do not touch badges, other sections, or any other package README.
- [x] **Task 4 — Flip the PRD §15 OQs (truthfully).** (AC: #4)
  - [x] Mark `OQ-AGUI-License` **RESOLVED** linking `_bmad-output/legal/ag_ui-license-verification.md`, matching the existing `— RESOLVED.` format used by `OQ-Perf-Baseline` / `OQ-Docs-Framework` / `OQ-Agno-Auth`.
  - [x] Mark `OQ-Koel-Trademark` **RESOLVED** linking `_bmad-output/legal/trademark-search-koel.md` **only if Task 2 is clean in Class 9/42**. If a conflict surfaced, leave it OPEN (keep the "Resolver: Story 9.8 … still open" wording) and note the blocker. Do not flip an OQ whose evidence does not support it — the 9.7 truthful-claim guardrail.
  - [x] Touch only these two §15 lines. Leave every other OQ (`OQ-Perf-Baseline` already RESOLVED by 9.7, `OQ-Conformance-Equivalence` open-until-v1.0.0, and the v1.x/v2 placeholders) unchanged.
- [x] **Task 5 — Verify gates + scope.** (AC: #5)
  - [x] `git status` shows only: `_bmad-output/legal/ag_ui-license-verification.md` (new), `_bmad-output/legal/trademark-search-koel.md` (new), `packages/koel_core/README.md`, `prd.md`. No Dart / pubspec / lock / architecture / koel_devtools / other-README edits.
  - [x] Run `melos run format:check` (expect 0-changed), `melos run analyze` (expect SUCCESS), `melos run docs` (the 9.6 `dart doc` gate — a `koel_core` file changed; confirm green). Confirm `pubspec.lock` 0-drift + AI-5.9 pins held. `melos run test` is provably inert (no `lib/`/`test/` change) — may be skipped with that justification; report what was run. Report actual results, do not assert green.

## Dev Notes

### What this story IS (and is NOT)

A **legal-audit-trail + documentation** story, the brand/credit-line release gate before the v1.0.0 publish (Story 9.9). It produces two evidence files under `_bmad-output/legal/`, finalizes one README credit, and flips up to two PRD Open Questions. There is **no Dart code, no codegen, no public API surface, no pubspec, and no lock-file** impact — the only pub-workspace file touched is a README (markdown). Resist any urge to change package code, pubspecs, or the brand itself. [Source: epics/epic-9-meta-package-sample-app-v100-release-gates.md#story-98]

The two halves are **asymmetric in verifiability** — sequence accordingly:
- **`ag_ui` license (AC #1)** is *fully verifiable from primary sources* — a published MIT LICENSE. Do it first; it is the clean, high-confidence half.
- **"koel" trademark (AC #2)** is *partially an owner/counsel task*. The dev-agent deliverable is the **public-registry search audit trail + a clearly-scoped finding** — not a legal clearance. `brand-reservation.md` is the precedent: the actual clearance is "Owner: project lead / P1," and the pub.dev name reservation itself was an out-of-band human act the agent could not perform. So produce the searchable evidence honestly, flag the limits, and surface any real conflict to Si rather than rubber-stamping.

### Pre-verified facts (re-confirm + record evidence; do not just copy)

These were checked during story creation (2026-06-08) to de-risk the story. **Re-fetch live and record the URLs + date in the evidence file** — do not cite this story file as the source of truth:
- `ag_ui` latest/only version is **0.1.0** (published ~8 months ago), **MIT**, source repo `https://github.com/mattsp1290/ag-ui`. [pub.dev/packages/ag_ui]
- The repo `LICENSE` is the **standard, unmodified MIT** text; its copyright line reads **"Copyright (c) 2025"** with **no holder named** — an upstream quirk worth noting in the record, but it does not affect MIT-compatibility. [raw.githubusercontent.com/mattsp1290/ag-ui/main/LICENSE]
- **Adversarial check to perform:** the pub.dev *license tab* renders the LICENSE bundled in the *published 0.1.0 archive*, which is the authoritative artifact for the credit (not necessarily `main` of the repo). Confirm the archive's LICENSE is MIT, using the repo as corroboration. If the archive's LICENSE differs from `main`, the archive wins.

### The "koel" common-word trap — the discriminating filter is the class, not the word

"Koel" is the Asian koel (a cuckoo) and a common given name — the public registries **will** return many "koel" marks. A hit is only a **conflict** if it is in/overlapping the SDK's goods/services: **Nice Class 9** (downloadable software) and **Class 42** (software design & development / SaaS). An apparel "Koel," a restaurant "Koel," a cosmetics "Koel" are *not* conflicts and must not be reported as one — nor used to declare the search "clean" without actually checking Class 9/42. Scope every query to those classes and report relevant-class results specifically.

### Truthful-claim guardrail (carried from Story 9.7)

Marking an OQ RESOLVED when its evidence doesn't support it is a false claim. `OQ-AGUI-License` resolves cleanly (MIT verified). `OQ-Koel-Trademark` resolves **only if** the Class 9/42 search is genuinely clean; otherwise it stays OPEN and the conflict is escalated to Si. Flipping the PRD while the README still said "pending" would be self-contradictory — Story 9.6 preserved the README note *because* 9.8 owns the clearing, and Story 9.7 deferred the PRD flip here for the same reason; this story removes the README stub **and** flips the PRD in the same commit so the repo stays self-consistent. [Source: 9-7-prd-addendum-reconciliation.md#why-the-two-trademarklicense-oqs-stay-pending]

### Previous-story intelligence (Story 9.7)

- 9.7 (PRD/Addendum reconcile, `done`) left `OQ-Koel-Trademark` + `OQ-AGUI-License` OPEN with the exact wording "Resolver: Story 9.8 (→ `_bmad-output/legal/…`); still open" at prd.md:366–367 — this story finishes that thread. Match the existing `— RESOLVED.` line format (used by `OQ-Perf-Baseline`, `OQ-Docs-Framework`, `OQ-Agno-Auth`). [Source: 9-7-prd-addendum-reconciliation.md#completion-notes]
- 9.6/9.7 gate discipline (the auto-commit memory): confirm `analyze` / `test` / `format:check` green **before** committing. Here they are trivially green (markdown + README only) but still run + report — never assert green without running. The 9.6 `dart doc` gate is the one that *could* bite (a `koel_core` file is touched), so run `melos run docs` explicitly.
- Path discipline: legal artifacts live under `_bmad-output/legal/` (outside the pub-workspace, like the prd edits); only the README sits inside `packages/`.

### Testing standards

No automated tests apply (markdown + README only, no `lib/`/`test/` change). "Verification" = the gate suite is unchanged-green, `git status` shows only the four intended files, each evidence file is non-stub with live-fetched citations, and each flipped OQ is backed by a finding that actually supports it. Do not flip an OQ you could not substantiate.

### Project Structure Notes

- New directory `_bmad-output/legal/` (net-new) holds both audit-trail files — outside the pub-workspace, excluded from `dart format`/`analyze`, so they cannot regress those gates.
- `packages/koel_core/README.md` is the *only* file touched inside `packages/`. README content is not analyzed and is not a `///` doc comment, so it won't trip `public_member_api_docs`; `dart doc` renders it as the package landing page but won't fail on removing a blockquote — still run `melos run docs` to confirm.
- The repo-root `README.md` carries **no** `ag_ui` credit (the credit lives only in `koel_core/README.md`), so it is not in scope. [verified: `grep ag_ui README.md` → no match]

### References

- [Source: epics/epic-9-meta-package-sample-app-v100-release-gates.md#story-98-trademark-check--ag_ui-license-verification] — the three ACs (trademark audit trail → `_bmad-output/legal/trademark-search-koel.md`; `ag_ui` MIT → `_bmad-output/legal/ag_ui-license-verification.md`; README credit finalized, Story-1.6 pending note removed)
- [Source: prds/prd-koel-2026-05-27/prd.md#8] FR-I3 (prd.md:205 — trademark + license hygiene) + FR-H4 (prd.md:197 — brand & naming, the `ag_ui` credit) + FR-H5 (prd.md:198 — MIT)
- [Source: prds/prd-koel-2026-05-27/prd.md#15] §15 Open Questions — `OQ-Koel-Trademark` + `OQ-AGUI-License` at lines ~366–367 (resolver pointers set by Story 9.7)
- [Source: brand-reservation.md] — FR-I3 release blockers (both OQs "still open"), the owner-task provenance caveat (clearance is P1, not a dev-agent deliverable), names-reserved-ahead-of-clearance trade-off
- [Source: 9-7-prd-addendum-reconciliation.md] — the deferred PRD-OQ flip handed to this story + the truthful-claim guardrail
- [Source: packages/koel_core/README.md] — `## Credits` paragraph (~37–39) + the pending-verification blockquote (~41–43) to remove
- [Source: _bmad-output/implementation-artifacts/deferred-work.md:195–196] — OQ-Koel-Trademark / OQ-AGUI-License "Cleared in Epic 9 (FR-I3)"
- External (re-fetch + record in the evidence files): `https://pub.dev/packages/ag_ui` (license tab), `https://github.com/mattsp1290/ag-ui` (LICENSE); `https://tmsearch.uspto.gov`, `https://euipo.europa.eu/eSearch/`, `https://ipindiaonline.gov.in/tmrpublicsearch/`

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context). Legal-audit + docs story (only `.md`/README, no `.dart`) → `/agent-flutter-engineer` persona not required.

### Debug Log References

- **Scope** (`git status --short`): only `prd.md` + `packages/koel_core/README.md` modified, `_bmad-output/legal/` (2 new files) + the story file untracked, `sprint-status.yaml` (in-scope tracking). No Dart / `pubspec.yaml` / `pubspec.lock` / `architecture.md` / `koel_devtools` / other-README change.
- **Link resolution:** both `../../../legal/*.md` relative links from `prd.md` resolve (`test -f` OK) — consistent with the existing `../../../../docs/` repo-root links (legal/ is one level shallower at `_bmad-output/legal/`).
- **Gates:** `melos run format:check` → **210 files, 0 changed**. `melos run docs` (the 9.6 `dart doc` gate, NFR-16) → **PASS all 10 release packages** (0 warnings/0 errors — the `koel_core` README edit did not perturb the build). `melos run analyze` → **SUCCESS** all packages + `koel_widgets_example`. `pubspec.lock` 0-drift (not modified); AI-5.9 pins (analyzer 12.1.0 / freezed 3.2.6-dev.1 / asp 0.3.14) held trivially. `melos run test` deliberately **not** run — provably inert: the diff is a README + `_bmad-output/` markdown, no `lib/`/`test/` change, so no test target is affected.

### Completion Notes List

- **Task 1 — OQ-AGUI-License CLEARED (high-confidence).** `ag_ui` 0.1.0 verified **MIT** from two primary sources: the pub.dev license tab (the LICENSE bundled in the **published 0.1.0 archive** — the authoritative artifact for the credit) and the source-repo LICENSE (`github.com/mattsp1290/ag-ui`). **Adversarial cross-check performed:** archive LICENSE ≡ repo LICENSE — both standard, unmodified MIT boilerplate, agree. Recorded in `_bmad-output/legal/ag_ui-license-verification.md` with URLs + verification date (2026-06-08). Nuance noted (does not affect compatibility): upstream copyright line is `Copyright (c) 2025` with **no holder named**; koel copies no `ag_ui` source so no notice-retention obligation attaches. MIT ⊆ koel's MIT (F-H5).
- **Task 2 — OQ-Koel-Trademark left OPEN (truthful-claim guardrail bit).** A clean Class 9/42 result could **not** be honestly asserted. (a) All three authoritative portals (USPTO `tmsearch.uspto.gov`, EUIPO `eSearch plus`, India IP public search) are JS/CAPTCHA-gated single-page apps — **not agent-fetchable**; aggregators (Trademarkia, Justia) returned **HTTP 403**. (b) Web-search corroboration surfaced a **same-name FOSS software project** — "Koel", a music-streaming server (koel.dev / github.com/koel/koel / "Koel Player" App Store): unregistered + different product domain, so **not a registered-mark conflict on the evidence**, but a real naming/common-law consideration. (c) India's "KOEL"/"Koel Care" (Kirloskar Oil Engines) is **Class ~7 engines, not software** → not a conflict. Net: **no registered software-class "koel" mark found in reachable sources, but absence-of-evidence ≠ clearance.** Recorded the full attempt + a P1 owner-action plan in `_bmad-output/legal/trademark-search-koel.md`. Final legal go/no-go is the owner's call per `brand-reservation.md` (clearance was always "Owner: project lead / P1").
- **Task 3 — `koel_core` README credit finalized.** Removed the Story-1.6 "pending verification" blockquote (was gated on `OQ-AGUI-License`, now cleared); the one-line `ag_ui` 0.1.0 credit paragraph stands as final (FR-H4). No badge/prose/link change. Repo-root README carries no `ag_ui` credit → not in scope.
- **Task 4 — PRD §15: flipped only the substantiated OQ.** `OQ-AGUI-License → RESOLVED` (links the verification file; matches the existing `— RESOLVED.` format). `OQ-Koel-Trademark` kept **OPEN** with tightened wording (links the search record, names the portal-inaccessibility + the FOSS-name signal, states the owner-clearance blocker). This is the AC #4 conditional path: the trademark flip is gated on a clean search, which was not achievable — flipping would be a false claim. The README ("pending" removed) and the PRD (`OQ-AGUI-License` RESOLVED) are now self-consistent.
- **⚠️ FYI-to-Si — v1.0.0 release-blocker still OPEN.** `OQ-Koel-Trademark` blocks the publish (FR-I3). Before Story 9.9 publish, you (P1) need to: (1) run the three portal searches manually filtered to **Nice Class 9 + 42** and append the authoritative records to `trademark-search-koel.md`; (2) weigh the **Koel music-app** name overlap (different domain, unregistered — likely acceptable, but your call); (3) on a clean result, flip `OQ-Koel-Trademark → RESOLVED`. This was always an owner/counsel task, not a dev-agent deliverable (same boundary as the pub.dev name reservation in `brand-reservation.md`).

### File List

**New**
- `_bmad-output/legal/ag_ui-license-verification.md` — OQ-AGUI-License audit trail (MIT verified, evidence + date)
- `_bmad-output/legal/trademark-search-koel.md` — OQ-Koel-Trademark search audit trail (attempt + limitations + owner-action plan)

**Modified**
- `packages/koel_core/README.md` — removed the "pending verification" credit blockquote (credit paragraph finalized)
- `_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md` — §15 `OQ-AGUI-License` → RESOLVED; `OQ-Koel-Trademark` wording tightened (stays OPEN)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — 9-8 status tracking

## Change Log

| Date | Change |
|---|---|
| 2026-06-08 | dev-story 9.8: brand/credit-line release gate. **OQ-AGUI-License CLEARED** — `ag_ui` 0.1.0 verified **MIT** from the published-archive license tab + source-repo LICENSE (adversarial cross-check: archive ≡ repo, standard boilerplate; upstream copyright `(c) 2025` no-holder noted as harmless); recorded in `legal/ag_ui-license-verification.md`. `koel_core/README.md` "pending verification" blockquote removed (credit finalized). PRD §15 `OQ-AGUI-License → RESOLVED`. **OQ-Koel-Trademark left OPEN** (truthful-claim guardrail): the three authoritative portals (USPTO/EUIPO/India IP) are JS/CAPTCHA-gated + aggregators 403 → no agent-completable Class 9/42 query; web-search surfaced a same-name FOSS project ("Koel" music server, unregistered/different domain — flagged, not a registered conflict) + Kirloskar "KOEL" (engines, wrong class); recorded the attempt + P1 owner-action plan in `legal/trademark-search-koel.md`; PRD wording tightened, stays OPEN as a v1.0.0 release-blocker for the owner. Scope: `prd.md` + `koel_core/README.md` + 2 new `_bmad-output/legal/` files. Gates: format:check 210/0, docs PASS all 10 (NFR-16), analyze SUCCESS, lock 0-drift, AI-5.9 pins held; test inert (README + md only). Status → review. |
| 2026-06-08 | Story 9.8 drafted (create-story): Trademark check + `ag_ui` license verification. Two asymmetric halves — `ag_ui` license fully verifiable (pre-checked MIT), "koel" trademark partly an owner/P1 task (audit-trail deliverable). Guardrails: common-word/class-scope filter (Nice 9 + 42), truthful-claim flip-only-if-clean, README+PRD self-consistency. Status → ready-for-dev. |

## Review Findings

_Code review 2026-06-08 (bmad-code-review): 3 layers (Blind Hunter / Edge Case Hunter / Acceptance Auditor), no layer failed. All 5 ACs verified SATISFIED; the key judgment call (keeping `OQ-Koel-Trademark` OPEN) is correct on the evidence. 3 patch (doc-correctness) + 1 defer + 5 dismissed (incl. Blind Hunter's "brand-reservation.md missing" — false-positive, file exists at `_bmad-output/planning-artifacts/`)._

- [x] [Review][Patch] Dangling requirement IDs — both legal files cited `FR-H4`/`FR-H5`/`FR-I3` but the PRD uses the `F-` prefix exclusively (68× `F-`, 0× `FR-`); the in-diff PRD edit itself correctly writes `F-H5`. **Fixed:** `FR-`→`F-` across both `_bmad-output/legal/*.md` (verified: 0 residual `FR-`). [_bmad-output/legal/*.md]
- [x] [Review][Patch] "unregistered" overclaim contradicted the doc's own un-queryable-register disclaimer. **Fixed:** Koel music-server reworded to "surfaced no trademark registration in reachable sources"; the two owner-action mentions softened to "no registration found/surfaced". [_bmad-output/legal/trademark-search-koel.md: Findings #1 + owner-action #2]
- [x] [Review][Patch] Imprecise `brand-reservation.md` cross-reference — bare filename implied a `legal/` sibling; file actually at `_bmad-output/planning-artifacts/`. **Fixed:** Cross-reference entries now use `../planning-artifacts/brand-reservation.md` (inline prose mention left as-is, disambiguated by the cross-ref). [_bmad-output/legal/ag_ui-license-verification.md:51; trademark-search-koel.md:85]
- [x] [Review][Defer] Stale OQ status in out-of-scope planning docs — `deferred-work.md:195-196` and `implementation-readiness-report-2026-05-28.md` still describe `OQ-AGUI-License` as pending/"cleared in Epic 9" and the README credit as a "pending stub"; now stale (License RESOLVED, README note removed). Out of this story's AC#5 scope (4 files only) — deferred, pre-existing.
