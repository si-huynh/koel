---
title: Brief → PRD Reconciliation — koel v1
status: review
created: 2026-05-27
purpose: Catalog gaps where the PRD silently dropped, weakened, or rephrased brief commitments
brief: ../../briefs/brief-koel-2026-05-27/brief.md
prd: ./prd.md
addendum: ./addendum.md
---

# Reconciliation: Brief → PRD

The brief is binding upstream. This document catalogs places where the PRD body and addendum diverged from the brief — silently dropped commitments, softened constraints, lost qualitative phrasing, missing non-goals, and tonal shifts. Each gap cites brief location, PRD location, severity, and a suggested fix.

Severities:

- **Critical** — a brief commitment that the PRD contradicts or drops outright; ship gate or persona-binding is affected.
- **Major** — a brief constraint or qualitative directive that the PRD diluted, softened, or rephrased in a way that changes meaning.
- **Minor** — voice/tone slip, numerical drift, or missing framing that doesn't change scope but loses character.

---

## Gap 1 — Event-count drift: brief says ~24, PRD says ~28

- **Brief location.** §The Solution: *"koel implements the full AG-UI event taxonomy (all ~24 event types including `THINKING_*`, `ACTIVITY_*`, `TOOL_CALL_CHUNK`)…"* Reaffirmed in §Scope In-for-v1 and §Success Criteria.
- **PRD location.** §1 Problem ("~28 SSE event types"), §4 G1 ("all ~28 event types"), §9 (~28 concrete subtypes), F-A7 (~28).
- **Gap.** Hard-coded numerical commitment differs by 4. Either the brief undercounted or the PRD overcounted from the spec discovery (`discovery-ag-ui-spec.md`). Either way, the PRD silently overrode a brief number without an entry in the PRD decision log explaining the change.
- **Severity.** Major. The conformance fixture pass criterion (SC-1) hangs on this number. If the brief was wrong, the brief should be updated and cross-referenced; if the PRD discovered new events, the PRD decision log must record the override.
- **Suggested fix.** Add a decision-log entry in `prds/prd-koel-2026-05-27/.decision-log.md` recording "AG-UI spec discovery raised event count from ~24 (brief estimate) to ~28 (verified against release/2026-05-26 baseline)." Add inline footnote in PRD §1 pointing to that entry.

## Gap 2 — `THINKING_*` event family vanished from PRD

- **Brief location.** §The Problem: *"missing newer event types (`THINKING_*`, `ACTIVITY_*`, `TOOL_CALL_CHUNK`)…"* Repeated in §The Solution and §Scope In-for-v1.
- **PRD location.** F-A7 enumerates `RUN_*`, `STEP_*`, `TEXT_MESSAGE_*`, `TOOL_CALL_*`, `STATE_*`, `MESSAGES_SNAPSHOT`, `ACTIVITY_*`, `REASONING_*` (incl. `REASONING_ENCRYPTED_VALUE`), `RAW`, `CUSTOM`. **No `THINKING_*`.** Addendum §A.1 lists `ReasoningStartEvent`, `ReasoningEndEvent`, etc., but no `Thinking*Event`.
- **Gap.** The brief calls out `THINKING_*` three times as a specific marker of `ag_ui` 0.1.0's staleness — *the gap koel exists to close*. PRD appears to have either (a) decided `THINKING_*` was renamed to `REASONING_*` in the upstream spec and silently substituted, or (b) dropped it.
- **Severity.** Critical. If `THINKING_*` and `REASONING_*` are distinct event families in the spec, the PRD has silently removed a marquee differentiator. If they are the same family that was renamed, the brief's `THINKING_*` references are stale and need a reconciliation note.
- **Suggested fix.** Verify against `discovery-ag-ui-spec.md`. If renamed: PRD §1 + §4 G1 add a footnote: *"AG-UI's `THINKING_*` family (called out in the brief) is the same wire family the current spec names `REASONING_*`; koel ships it as `Reasoning*Event`."* If distinct: add `Thinking*Event` subtypes to F-A7 and addendum §A.1.

## Gap 3 — Coverage tier for `koel_flutter` dropped from ≥90% to ≥80%

- **Brief location.** §Success Criteria > Code-quality bar: *"Test coverage ≥ 90% on `koel_core`, `koel_http`, `koel_flutter`; ≥ 80% on adapter packages."*
- **PRD location.** §5.1 SC-2 and §10.4 N-12: *"`koel_core` and `koel_http` ≥ 90% line coverage; all other packages ≥ 80%."*
- **Gap.** `koel_flutter` silently dropped from the 90% tier into the 80% bucket. This is a measurable ship-gate weakening that the PRD does not explain or attribute.
- **Severity.** Critical. Direct contradiction of a brief-declared ship-gate threshold.
- **Suggested fix.** Restore `koel_flutter` to the 90% tier in §5.1 SC-2 and §10.4 N-12. If the PRD genuinely believes 90% is unreasonable for `koel_flutter` (e.g., because widget tests are coverage-noisy), record an override in the PRD decision log with explicit rationale and surface it to user.

## Gap 4 — P1 persona binding loses the "author six months later" framing

- **Brief location.** §Who This Serves: *"P1 — The author, and the author six months later. koel is a passion project; the first reader of every public class is Si Huynh. The success bar is 'open the source in six months and every line still earns its place.'"*
- **PRD location.** §3: *"P1 — Self (Si Huynh). Primary user; consumes koel from a downstream app. Every API choice is gated by 'do I want to use this.'"*
- **Gap.** The brief's P1 has *two* people in it — present-Si and future-Si — and the binding test is the **six-month re-read**. PRD reduces this to "Self (Si Huynh)" with a "do I want to use this" present-tense test. The future-self half — which is what motivates SC-5 (no vestigial code), N-15 (surface minimalism), and N-16 (no comments stating code) — is silently dropped. The "six-month re-read test" appears once in §5.2 as an unattributed single bullet, severed from the persona binding.
- **Severity.** Major. The future-self binding is the *psychological mechanism* behind every craft-over-adoption decision. Without it, P1 reads as a generic "primary user" and loses the temporal-discipline edge.
- **Suggested fix.** Rewrite §3 P1 bullet: *"P1 — Self today, and self six months from now. Primary user; consumes koel from a downstream app. Every API choice is gated by 'do I want to use this' (today-Si) and 'will this line still earn its place when I re-read it in six months' (future-Si). P1's app lives outside the koel repo; nothing about that app appears in koel."* Cross-link to §5.2.

## Gap 5 — "Honest about what is not a moat" self-appraisal cut

- **Brief location.** §What Makes This Different: *"Honest about what is not a moat: koel is not faster than `ag_ui` because `ag_ui` is fast — it is faster because it is more complete. The 'unfair advantage' is willingness to spend craft time on infrastructure others skipped, not a technical trade secret."*
- **PRD location.** No equivalent passage. §2 ("The opportunity is not market share. It is the existence of a Flutter SDK that future Flutter developers can hold up as a reference…") gestures toward the right tone but misses the self-aware concession.
- **Gap.** A distinctive voice marker — the deliberate *anti-marketing*, *no-secret-sauce* candor — is gone. The brief explicitly names what koel is not, and the PRD only describes what it is.
- **Severity.** Minor (voice/tone) but it's the single most distinctive paragraph in the brief.
- **Suggested fix.** Add a §2 closing paragraph: *"What koel is not: koel is not faster than `ag_ui` 0.1.0 because the protocol implementation is clever — it is faster because it is more complete. The unfair advantage is willingness to spend craft time on infrastructure others skipped. No moat, no trade secret; just the choice to ship the work."*

## Gap 6 — SSE primary / GraphQL bridge relative status flattened

- **Brief location.** §The Solution: *"over both wire protocols — AG-UI SSE primary, CopilotKit GraphQL runtime as bridge."* Reinforced in §Scope: *"Both wire protocols: AG-UI SSE (primary) + CopilotKit GraphQL runtime bridge."* Also D-RUN-7 in the brief decision log explicitly preserves this hierarchy.
- **PRD location.** §6.1: *"Both transports production-grade: SSE-over-HTTP (`koel_http`) and GraphQL-bridge-over-CopilotKit-Next.js-runtime (`koel_runtime`)."* §4 G1 and the package table treat them as peers.
- **Gap.** The brief asserts a relative status — SSE is primary; GraphQL is a bridge for a specific deployment topology. The PRD flattens them to co-equal "both production-grade" without preserving the primacy. This matters for documentation prioritization, quickstart path, and the meta-package export choice.
- **Severity.** Major. The brief's hierarchy informs which transport gets the documentation polish, the quickstart, and the example app's default. PRD §F-H3 *does* preserve it implicitly (meta-package re-exports `koel_core` + `koel_http` + `koel_flutter`, not `koel_runtime`), but the §6.1 phrasing contradicts that.
- **Suggested fix.** Update §6.1: *"Both transports production-grade. **AG-UI SSE (`koel_http`) is the primary transport** — the meta-package quickstart and example app target it. **GraphQL bridge (`koel_runtime`) is the secondary transport** for consumers whose backend is the CopilotKit Next.js runtime."* Mirror the hierarchy in §4 G1.

## Gap 7 — The "three bad choices" framing dropped from problem statement

- **Brief location.** §The Problem enumerates three concrete alternatives Flutter teams face today: (1) accept `ag_ui` 0.1.0's gaps, (2) embed a WebView, (3) build their own. *"The cost of the status quo is not catastrophe; it is friction."*
- **PRD location.** §2 mentions `ag_ui` 0.1.0 but does not enumerate the three alternatives or articulate the friction-not-catastrophe framing.
- **Gap.** The brief grounds the problem in the *consumer's actual decision space* (three bad choices). The PRD describes the spec gap abstractly. The empathetic / concrete framing is lost.
- **Severity.** Minor. Doesn't change scope, but the brief's framing is what makes the problem feel real.
- **Suggested fix.** Expand §2 with a short paragraph: *"Flutter teams integrating agents today face three bad choices — accept `ag_ui` 0.1.0's gaps and rebuild missing infrastructure per app, embed a WebView around a JS chat client (paying performance, bundle, and debuggability cost), or build their own AG-UI client from the spec. The cost of the status quo is not catastrophe; it is friction. koel removes the friction by being the foundation."*

## Gap 8 — Brief's OQs converted to RESOLVED without spike work surfacing

- **Brief location.** §Open Questions: *"These are explicitly unresolved, not fabricated certainty. PRD epics depending on them carry spike work as prerequisites."* Lists OQ-Agno-Auth (Spike required) and OQ-Fixtures (Spike required).
- **PRD location.** §15: *"OQ-Agno-Auth — RESOLVED. Default-ON `AgnoAuthInterceptor` per §6.1 / F-C1."* and *"OQ-Fixtures-Source — RESOLVED. Capture from AG-UI dojo + agno + langgraph per §6.1 / F-G1."*
- **Gap.** The brief said these required spike work as PRD-epic prerequisites. The PRD declares them RESOLVED without surfacing the spike work as an epic, a prerequisite, or a discovery task. The Agno-Auth resolution is a single sentence ("default-ON interceptor") that picks an answer; the brief's framing implied empirical verification was needed first. The Fixtures resolution names sources but does not name the *capture pipeline* (Charles/mitmproxy was the brief's hypothesis).
- **Severity.** Major. The brief flagged these as "not fabricated certainty" — the PRD silently fabricated certainty.
- **Suggested fix.** Either (a) add an "Epic-0: Spikes" section to the PRD listing the two spikes (Agno auth verification against a live backend; fixture capture pipeline setup) with explicit acceptance criteria, then mark the OQs "RESOLVED pending spike completion," or (b) downgrade both to "PROVISIONALLY RESOLVED" with a note that the resolution is the planned default and the spike verifies before the affected epic ships.

## Gap 9 — "Slow path to v1 is the chosen path" — brief tempo signal carried but isolated

- **Brief location.** §Success Criteria > Self-judgment bar: *"The six-month re-read test"* and Vision: *"…not because it markets best, but because the source reads cleanly, the DevTools experience makes agent debugging feel like state debugging, and the adapter strategy slots new protocols in without rewriting consumer code."*
- **PRD location.** §1: *"Slow path to v1 is the chosen path."* This sentence lands without a connection to release planning, decision-log discipline, or scope-cut criteria.
- **Gap.** The brief's tempo signal (passion project; production-ready bar; no MVP) maps to several concrete behaviors that the PRD doesn't operationalize: when do we cut scope rather than slip? what is the scope-cut decision rule? The brief implies "slip, don't cut" because passion projects don't have a deadline. The PRD doesn't say it.
- **Severity.** Minor. The phrase is in the PRD but isn't load-bearing.
- **Suggested fix.** Add a §12 R-6: *"Scope-cut policy. v1 has no deadline. When a feature in §6.1 is at risk, the default decision is **slip the date, keep the scope**. Cutting from §6.1 requires a decision-log entry citing why the feature failed to earn its v1 slot."*

## Gap 10 — Vision: cross-language conformance suite ambition lost in PRD body

- **Brief location.** §Vision: *"The conformance fixtures are referenced by other AG-UI client implementations across languages as the canonical 'does it actually conform' test suite. The DevTools extension has been the model others copy."*
- **PRD location.** §1 mentions "multi-source conformance fixtures" but no cross-language ambition. Addendum §H Future-7 *does* capture it as future work, but the PRD body Vision (§1) does not.
- **Gap.** The brief's vision has koel's conformance suite becoming the *cross-language reference*. That ambition is downgraded to a "future work, not v1" item in the addendum. Vision should carry the long arc.
- **Severity.** Minor. The ambition is captured *somewhere*; it is just severed from the §1 Vision where the brief placed it.
- **Suggested fix.** Add to PRD §1: *"The long arc: in 2-3 years, the conformance fixtures are the cross-language reference for AG-UI compliance, the DevTools extension is the pattern others copy, and the 9-package shape has grown with community-maintained adapters (`koel_bloc`, `koel_riverpod`, `koel_a2ui`). Success is not adoption; success is that the people who use koel use it because they understand why it was built the way it was."*

## Gap 11 — Brief's quickstart line-count not specified; PRD picks "10-line"

- **Brief location.** §Vision and §Solution imply a meta-package quickstart but do not specify line count.
- **PRD location.** §13 D-1: *"10-line quickstart."*
- **Gap.** Not a brief violation — but a PRD-introduced commitment that should be flagged for P1 confirmation. The brief was silent; the PRD added a constraint.
- **Severity.** Minor. Flag, don't fix.
- **Suggested fix.** Leave "10-line quickstart" but add a decision-log note: "PRD introduces ≤10-line quickstart commitment as a documentation discipline target; brief was silent."

## Gap 12 — "koel = Hindi for the singing cuckoo" — brief naming lore demoted

- **Brief location.** D-PRIOR-1 (brief decision log): *"Brand = `koel`. Hindi for the singing cuckoo. Chosen explicitly over SEO-friendly names like `agui_*`. Marketing investment is acceptable cost for the right brand."*
- **PRD location.** F-H4: *"Brand: `koel` (Hindi for the singing cuckoo)."* §4 NG2 carries the anti-SEO choice.
- **Gap.** The brief's *marketing-investment-is-acceptable-cost-for-the-right-brand* assertion is dropped. The naming lore survives but the principle behind it (we knowingly chose the harder discovery path) is gone.
- **Severity.** Minor. Voice.
- **Suggested fix.** Expand §4 NG2: *"NG2. SEO-friendly naming. We chose `koel` (Hindi for the singing cuckoo) over `agui_*` deliberately. Marketing investment is the acceptable cost of the right brand."*

## Gap 13 — V1 "production-ready, not MVP" — Vietnamese assertion lost

- **Brief location.** D-PRIOR-4 (brief decision log): *"V1 = production-ready, not MVP. 'Có thể sử dụng được trong production.'"*
- **PRD location.** §6.1 mentions "production-grade" three times. No equivalent of the "not MVP, not preview" emphatic framing.
- **Gap.** The brief draws an explicit line: *not an MVP, not a preview.* PRD says "production-grade" but doesn't say what production-grade *rejects*. The negation is the binding part.
- **Severity.** Major. The brief uses the negation to keep scope honest; without it, "production-grade" becomes a generic engineering label.
- **Suggested fix.** Add to §5.1 a leading sentence: *"v1 ships production-ready. Not MVP, not preview, not beta. Every package surface that ships at 1.0.0 is a long-term contract; nothing carries a 'will stabilize later' caveat."*

## Gap 14 — "Hàng tốt thì user sẽ biết đến thôi" framing carried but de-fanged

- **Brief location.** D-PRIOR-5 (brief decision log): *"Passion project. Success criteria = craftsmanship and learning, NOT downloads, stars, contributors, or production usage. 'Hàng tốt thì user sẽ biết đến thôi.'"*
- **PRD location.** §1 ("Adoption metrics — downloads, stars, contributors, production usage — are not success criteria. Success is craftsmanship and the personal learning produced by building it correctly.") and §5.4.
- **Gap.** The PRD nails the structural commitment but the brief's *voice* — the Vietnamese folk-wisdom assertion that good craft finds its audience — is reduced to an English declarative sentence. This is the koel project speaking in Si Huynh's voice; PRD makes it a generic non-criteria bullet.
- **Severity.** Minor. The commitment is preserved; the character is muted.
- **Suggested fix.** Optional. If the PRD body wants to keep an English-only register, leave it. If a single Vietnamese-original sentence is acceptable in the §1 Vision, restore: *"The working principle behind this is 'hàng tốt thì user sẽ biết đến thôi' — good craft finds its readers. The corollary: zero readers is a valid outcome and does not retroactively make the craft worse."*

## Gap 15 — Brief's "first reader of every public class is Si Huynh" — API surface principle lost

- **Brief location.** §Who This Serves: *"the first reader of every public class is Si Huynh."*
- **PRD location.** §3 P1 bullet (re-read above), §5.2 ("The API feels right when P1 uses it in a downstream app").
- **Gap.** The brief states a documentation/API-design principle: *every public class is written for one person to read first.* This is the operational form of P1 binding. PRD's §3 says "every API choice is gated by 'do I want to use this'" — close but different. "Do I want to use this" is a use-test; "first reader of every public class" is a *naming and shape* test. They produce different design decisions.
- **Severity.** Major. The brief's framing produces decisions about *what to name things* and *what doc comments look like*; the PRD's framing only produces decisions about *what to include*.
- **Suggested fix.** Add to §3 P1: *"The operational form: the first reader of every public class is Si Huynh, six months after writing it. Names, doc comments, and API shape are gated by that reader."*

## Gap 16 — Brief Vision: "the people who use it use it because they understand why" — closing line dropped

- **Brief location.** §Vision (final sentence): *"Success is that the people who use it use it because they understand why it was built the way it was — and recognize the craft."*
- **PRD location.** No equivalent. §1 ends on "Slow path to v1 is the chosen path."
- **Gap.** The brief's closing line is the *human* version of the non-adoption commitment: success is not "many users" but "the right users, for the right reason." PRD ends on tempo, not on the human reader.
- **Severity.** Minor. Voice/closing.
- **Suggested fix.** Replace PRD §1 closing sentence with: *"Slow path to v1 is the chosen path. Success is that the people who use koel use it because they understand why it was built the way it was — and recognize the craft."*

## Gap 17 — Non-goal: "zero references to consumer codebase" missing as explicit NG

- **Brief location.** §Scope (closing note): *"Note: koel artifacts contain zero references to specific downstream consumer codebases, business domains, or app-layer policy. Example apps are generic chat scenarios. Domain integration is downstream consumer work, not koel's concern."* Reinforced by D-PRIOR-6 in the brief decision log.
- **PRD location.** §4 NG3: *"A reference for any specific downstream consumer codebase. koel-facing artifacts contain zero references to any business domain."* §13 D-5 ("Generic chat scenarios only — zero business domain"). §6.1 ("generic chat scenarios only").
- **Gap.** Largely carried — NG3 + D-5 + §6.1 cover it. But the brief's framing as a *binding rule across all koel artifacts* (not just sample apps) is split across three places in the PRD without a single load-bearing statement.
- **Severity.** Minor. Captured, just diluted by being scattered.
- **Suggested fix.** Strengthen NG3 to: *"NG3. References to any specific downstream consumer codebase. **This is a binding rule across all koel artifacts — repo, packages, docs, examples, fixtures, decision logs.** koel-facing artifacts contain zero references to any business domain. Example apps use generic chat scenarios only."*

## Gap 18 — Brief's Tone: "passion project" vs PRD's "premium"

- **Brief location.** §Executive Summary opens with "modular Dart/Flutter SDK that implements the AG-UI agent-UI protocol end-to-end." Brief never uses the word "premium." Brief decision-log D-RUN-9 explicitly says *"dropped 'premium' puffery"* in the polish pass.
- **PRD location.** §1: *"A premium, open-source, multi-package Dart implementation…"* The brief explicitly cut "premium." The PRD re-introduced it.
- **Gap.** The PRD silently reverted a brief polish decision. "Premium" is the exact word the brief polish reviewer flagged as puffery and cut.
- **Severity.** Major. The brief decision log records the cut as a deliberate choice; the PRD ignoring it is an upstream-binding violation.
- **Suggested fix.** Remove "premium" from §1. Replace *"A premium, open-source, multi-package Dart implementation"* with *"An open-source, multi-package Dart implementation, built with the rigor of a framework, not the velocity of a shim."*

---

## Summary

| # | Gap | Severity |
|---|---|---|
| 1 | Event-count drift (~24 → ~28) without decision-log entry | Major |
| 2 | `THINKING_*` events vanished from PRD | Critical |
| 3 | `koel_flutter` coverage tier dropped from ≥90% to ≥80% | Critical |
| 4 | P1 persona binding loses "author six months later" framing | Major |
| 5 | "Honest about what is not a moat" self-appraisal cut | Minor |
| 6 | SSE-primary / GraphQL-bridge hierarchy flattened to "both" | Major |
| 7 | "Three bad choices" framing dropped from §2 | Minor |
| 8 | Brief OQs converted to RESOLVED without spike work surfacing | Major |
| 9 | "Slow path to v1" sentence isolated; no scope-cut policy | Minor |
| 10 | Vision: cross-language conformance ambition demoted to addendum | Minor |
| 11 | PRD-introduced "10-line quickstart" commitment not in brief | Minor |
| 12 | Brand-investment principle behind "koel" name demoted | Minor |
| 13 | "Production-ready, not MVP" negation framing lost | Major |
| 14 | "Hàng tốt thì user sẽ biết đến thôi" voice de-fanged | Minor |
| 15 | "First reader of every public class is Si Huynh" lost | Major |
| 16 | Brief Vision closing line ("…recognize the craft") dropped | Minor |
| 17 | "Zero references to consumer codebase" rule scattered, not load-bearing | Minor |
| 18 | "Premium" re-introduced in §1 after brief polish explicitly cut it | Major |

**Critical:** 2 · **Major:** 7 · **Minor:** 9.

**Verdict.** Significant divergence — not in scope (PRD scope tracks brief scope closely) but in **voice, persona binding, and ship-gate fidelity**. The PRD reads more like a generic engineering doc than a Si-Huynh-authored passion-project PRD. The two critical gaps (`koel_flutter` coverage drop, `THINKING_*` events) are objectively wrong against the brief and must be reconciled before PRD finalizes.

---

*End of reconciliation. Resolve each gap by either (a) updating the PRD to match the brief, or (b) recording an explicit override in `.decision-log.md` with rationale.*
