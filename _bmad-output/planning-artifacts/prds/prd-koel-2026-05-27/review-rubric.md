# PRD Quality Review — koel v1 (2026-05-27)

## Overall verdict

This PRD holds up unusually well as a *capability-spec for a single-operator passion project*: thesis is sharp, scope is honest, non-goals do real work, and the API surface is bound to a 1.x contract with concrete signatures in the addendum. The structural risks are concentrated in **Done-ness clarity for NFRs** (most performance bounds are `[ASSUMPTION]`-tagged without a resolution gate) and **Success Criteria measurement methodology** (coverage tiers and conformance percentages name a target but not how it is computed). Decision-readiness, strategic coherence, and shape fit are strong; the remaining findings are tightenings, not blockers — verdict is **PASS WITH CONDITIONS**.

## 1. Decision-readiness — strong

The PRD repeatedly states decisions *as* decisions and names what was given up. §3 explicitly orders personas by binding priority ("API tradeoffs resolve in P1's favor first"). §4 NG1–NG8 each say what was rejected and why (e.g., NG4 protobuf: "underdocumented … deferred to v1.5/v2"). §5 explicitly separates a ship gate (5.1) from values (5.2, 5.3) from non-criteria (5.4) — a stronger trade-off articulation than most PRDs achieve. Addendum §D enumerates 7 rejected alternatives with rationale.

The Open Questions block (§15) is genuinely open — none are rhetorical; two are marked RESOLVED inline with provenance, two block v1 publish (OQ-Koel-Trademark, OQ-AGUI-License), three are explicitly out-of-scope-for-v1, demonstrating the author actually distinguishes blockers from deferrals.

No `[NOTE FOR PM]` callouts appear, but the PRD is self-authored for a solo maintainer; the convention has nothing to attach to. This is shape-appropriate, not a gap.

### Findings
- None at high or above.
- **low** Counter-metrics are quarterly-reviewed but reviewer is unnamed (§14) — for a solo maintainer this is implicit but worth one line confirming P1 owns the review cadence. *Fix:* add "Owner: P1, quarterly self-audit" to §14 preamble.

## 2. Substance over theater — strong

No persona theater (3 personas, ordered by binding weight, with P3 explicitly told "gets API discipline … not dedicated hooks"). No innovation theater — §2 makes the differentiation claim concrete (single-package community SDK, 8 months stale, missing event families) rather than abstract. Vision (§1) is unmistakably koel-specific: it could not swap into another PRD without obvious nonsense ("a Flutter developer landing on `koel_core`…"). NFR section avoids most boilerplate — performance budgets cite a reference device class (Pixel 4a) and specific thresholds (10k events/sec, p99 <1ms, <50MB, <100ms cold-start), not "scalable / fast / reliable."

The Design DNA epigraph in §1 ("Infra deep, business out. Modular by discipline …") does load-bearing work later in §3 (no business-domain references in koel), §4 (NG3), §6.1 (sample app: generic chat scenarios only), and §13 D-5.

### Findings
- **low** F-E3 carries `*(idea — implicit)*` as provenance — slightly weaker than the other `*(idea #n)*` cites; cosmetic. *Fix:* either remove the parenthetical or replace with the actual idea ID.

## 3. Strategic coherence — strong

There is a thesis and it is bet on: *premium technical OSS SDK that prioritizes craftsmanship over adoption*. §1 names it, §5.4 makes it falsifiable ("Zero adoption is a valid outcome and not a failure"), §4 NG1 codifies it as a non-goal, and every Feature Group serves it (Group A protocol depth, Group F devtools, Group G conformance — all signals of "framework, not shim"). Feature prioritization follows the thesis: F-A1 atomic kernel is listed first; cross-cutting infra (G4) is shipped at v1, not deferred. MVP scope kind is unambiguously *platform* — and the 9-package split (§7) follows from the platform framing.

Counter-metrics (§14) are present and bite: CM-1 (surface bloat), CM-4 (conformance drift), CM-6 (doc-comment density) directly defend the thesis. Success metrics avoid activity-vanity (no DAU, no downloads) — instead 100% conformance, coverage tiers, zero `dart analyze` warnings, no vestigial code (§5.1).

### Findings
- None at medium or above. The PRD's coherence is one of its strongest dimensions.

## 4. Done-ness clarity — thin

This is the weakest dimension. The PRD body has 11+ NFRs and several SCs that target measurable thresholds without nailing *how* the measurement is performed or *what gate* unblocks the `[ASSUMPTION]` markers. The PRD is not vague (no "graceful" / "reasonable" / "user-friendly"), but it leans heavily on assumptions for the v1 ship gate.

Specific issues:

- **§5.1 SC-1** "100% AG-UI protocol conformance — every event in the captured fixture suite (3 backends × all event types) round-trips … without loss." *Done-ness:* what defines "round-trip without loss"? Byte-equal serialization? Reducer-equivalent ChatState? `==`-equal `AgUiEvent` objects? Specify the equivalence relation.
- **§5.1 SC-2** Coverage tiers named (90% / 80% line coverage) — but no methodology: which tool (`dart test --coverage`? `coverage` package?), branch vs line, generated-file exclusions, fixture-data exclusions. CI gate exists (§N-12) but the measurement contract is implicit.
- **§5.1 SC-5** "No vestigial code" — operationalized as "no TODO, no commented-out blocks, no `just in case` parameters, no exports that no example uses." First three are grep-checkable; fourth is not — what tool enforces "exports that no example uses"? This is exactly the kind of bar that downstream story work cannot close without specification.
- **§10.1 N-1..N-4** All four perf NFRs are `[ASSUMPTION]`-marked; no resolution gate. When does the assumption flip to a confirmed bound? Before v1.0.0? Before alpha? The PRD does not say.
- **§10.2 N-6** Backpressure default `pause_upstream` `[ASSUMPTION]` — same resolution-gate gap.
- **§10.3 N-9, N-10** Dart 3.0+ and Flutter 3.10+ floor are `[ASSUMPTION]` — these are exactly the kind of decision that should be a *decision* before v1.0.0; the assumption tag is right for now but needs an OQ to track it.
- **§F-B3 / N-8** "Cancellation propagates within < 50 ms to HTTP abort" — measurable, but the measurement harness is unspecified. Where does the 50 ms clock start and stop?
- **§F-F3** "Bounded ring buffer (default 1000 events …)" `[ASSUMPTION]` — same gap.
- **§F-F7** Replay safety semantics is `[ASSUMPTION]`-marked; OQ-Replay-Side-Effects exists but does not gate `koel_devtools` v1 ship.

The addendum §C.2 cancellation matrix and §C.5 backpressure narrative help, but neither closes the measurement-methodology gap for SC.

### Findings
- **critical** §5.1 SC-1 conformance equivalence undefined — "without loss" admits four reasonable interpretations. *Fix:* state the equivalence relation explicitly (e.g., "round-trip means `event == AgUiEvent.fromJson(event.toJson())` for all events, plus `reducer.fold(events) == reducer.fold(events.map(roundtrip))`").
- **critical** §5.1 SC-2 coverage measurement methodology absent. *Fix:* name the tool, branch-vs-line policy, generated-file exclusion globs, and minimum patch coverage.
- **high** §5.1 SC-5 fourth clause ("no exports that no example uses") has no enforcement mechanism. *Fix:* either remove this clause or define the tool (e.g., a Melos script that greps `/example` for every public export and fails CI on orphans).
- **high** §10.1 N-1..N-4 all `[ASSUMPTION]` with no resolution gate. *Fix:* add an OQ-Perf-Bounds entry to §15 with explicit "blocks alpha" or "blocks v1.0.0" tag, and a benchmark harness commitment.
- **high** §10.3 N-9, N-10 SDK floor `[ASSUMPTION]` should be a decision before alpha. *Fix:* either resolve in-document (Dart 3.0 is already the project's stated baseline per addendum §B.1) or add OQ-SDK-Floor.
- **medium** §10.2 N-6 backpressure default `[ASSUMPTION]` with no resolution gate. *Fix:* OQ entry or in-doc resolution.
- **medium** §F-B3 cancellation latency measurement harness unspecified. *Fix:* add one sentence pointing to the test in `koel_http/test/cancellation_test.dart` and how the 50ms is measured.
- **medium** §F-F3 / §F-F6 devtools `[ASSUMPTION]`s lack resolution gate; defer to `koel_devtools` implementation but say so. *Fix:* mark each `[ASSUMPTION]` with "resolved during `koel_devtools` v1 implementation."

## 5. Scope honesty — strong

Non-goals do real work. §4 NG1–NG8 are not generic ("not boiling the ocean") but specific, with rationale and pointers to deferred home (v1.5/v2/community). `[NON-GOAL for MVP]` callouts are not used explicitly, but §6.2 functions as a compact omission ledger pointing back to §4.

`[ASSUMPTION]` tags appear inline at F-B3, F-B5, F-E2, F-F3, F-F6, F-F7, and N-1..N-4, N-6, N-9, N-10 — at least 11 inline. There is **no Assumptions Index** at end-of-doc; this is a mechanical gap (see Mechanical Notes) but also a scope-honesty gap because un-indexed assumptions are easier to forget. Roundtrip-failure risk is real.

`[NOTE FOR PM]` convention not used — shape-appropriate for a self-authored solo-maintainer PRD, see Decision-readiness section.

Open-items density relative to stakes: 9 OQs, 11+ inline `[ASSUMPTION]`s, on a launch-tier PRD that gates v1.0.0 publish. Two OQs explicitly block publish (OQ-Koel-Trademark, OQ-AGUI-License). This is honest and proportionate for a passion-project SDK where slow path is chosen — high counts are appropriate because the cost of being wrong is craftsmanship-reputational rather than business-financial.

### Findings
- **high** No Assumptions Index at end-of-PRD. ~11 inline `[ASSUMPTION]` tags exist with no roundtrip aggregator. *Fix:* add §17 Assumptions Index listing each tag, its location, owner, and resolution gate.

## 6. Downstream usability — adequate

Glossary present (§16, 10 entries) and used consistently — AG-UI, Adapter, AgentSubscriber, ChatSession, ChatStateReducer, Generative UI, Interceptor, RunAgentInput, threadId/runId, WidgetResolver all appear identically across §6, §7, §8, §9, §10. Spot-checks: "interceptor" / "Interceptor" appear in mixed case in §10 N-15 doc comments vs §8 F-A4 — acceptable, the term is grammatically used both as a class and a concept.

Feature IDs (`F-A1..A11`, `F-B1..B6`, `F-C1..C3`, `F-D1..D5`, `F-E1..E4`, `F-F1..F7`, `F-G1..G4`, `F-H1..H6`, `F-I1..I3`) — contiguous within each group, globally unique via the `F-{group}-{n}` scheme as documented in §8 preamble. NFR IDs N-1..N-16, SC-1..SC-5, FC-1..FC-4, R-1..R-5, D-1..D-5, CM-1..CM-6, OQ-* all parse cleanly. No collisions detected.

Cross-references resolve. §3 → §1 (Design DNA), §6.1 → OQ-Docs-Framework (§15), §5.1 SC-4 → §13 (note: §13 is Documentation Policy, not Versioning — the cross-ref says "Hybrid versioning (§13)" but Hybrid Versioning is F-H2 in §8 and §R-3 in §12 — **broken cross-ref**).

No User Journeys at all — explicitly justified in §3 ("No user-journey section: koel is a pure technical SDK"). Shape-appropriate. UJ-protagonist guidance doesn't apply.

Each top-level section can be source-extracted alone: §8 Features can be lifted into a backlog generator; §9 API Surface is its own contract; §10 NFRs are independent. The capability-spec shape makes this work.

### Findings
- **high** §5.1 SC-4 cross-references "Hybrid versioning (§13)" but §13 is Documentation Policy. Hybrid versioning lives at F-H2 (§8 Group H) and R-3 (§12). *Fix:* change to "Hybrid versioning (§12 R-2/R-3, F-H2)".
- **low** Mixed-case "interceptor" vs "Interceptor" across §8 / §10 / §16. Not blocking; pick one for non-class-name prose.

## 7. Shape fit — strong

This PRD is correctly shaped as a *capability spec for a multi-package platform SDK*. §3 declares "No user-journey section: koel is a pure technical SDK" — the right call, justified by the audience reading docs and writing code against APIs rather than user-experience flows. The shape fit checklist:

- Consumer product / B2B UX → UJs would be load-bearing. **N/A** — koel has no end-user UX; consumers are developers reading APIs.
- Internal tool / single-operator → capability-spec shape, SMs operational. **Match** — P1 is the single primary operator; SMs are code-quality + conformance, not user-facing.
- Regulatory / compliance → constraint traceability non-negotiable. **N/A**.
- Hobby / solo → rigor light, substance bar still applies. **Partial match** — passion-project framing in §1, but rigor is *high* (launch-tier scaffolding, full API surface contract). This is unusual but legitimate; the PRD is overscoped relative to "hobby" but the author has explicitly chosen launch-tier rigor as part of the craftsmanship thesis.
- Brownfield → existing-code refs accurate. **N/A** — clean-slate rewrite per NG8.
- Chain-top (feeds UX → arch → stories) → downstream usability matters more. **Partial match** — addendum.md is the architecture-detail companion; story creation will lean on §8 Features and §9 API Surface. The capability-spec shape supports this well.

No over-formalization (no fake UJs forced in). No under-formalization (substance bar met). The decision to elide UX section is explicit and justified.

### Findings
- None at medium or above. Shape fit is one of this PRD's quiet strengths — it correctly refuses to follow templates that don't serve the product.

## Mechanical notes

- **Assumptions Index roundtrip.** Inline `[ASSUMPTION]` tags appear at F-B3, F-B5, F-E2, F-F3, F-F6, F-F7, N-1, N-2, N-3, N-4, N-6, N-9, N-10 (13 tags). **No Assumptions Index section exists.** Roundtrip is broken — already raised as a high finding in §5 above.
- **Glossary drift.** Spot-checked: AG-UI, Interceptor, ChatSession, RunAgentInput, threadId/runId, WidgetResolver consistent across all references. Minor case drift on "interceptor" as concept vs class (§10 N-15) — low.
- **ID continuity.** Feature IDs `F-{A..I}{n}` contiguous within group, no gaps. NFR `N-1..N-16` contiguous. SC `SC-1..SC-5` contiguous. FC, R, D, CM, OQ all clean. **No ID collisions or gaps detected.**
- **Cross-references.** §5.1 SC-4 → "(§13)" should be "(§12)" or "(§8 F-H2, §12 R-2/R-3)" — broken cross-ref (already raised as high in §6).
- **UJ protagonist naming.** N/A — no UJs by design.
- **Required sections for launch-tier capability spec.** Present: Vision, Problem, Audience, Goals/Non-Goals, Success Criteria, Scope, Architecture, Features, API Surface, NFRs, Forward-Compat, Release, Docs, Counter-metrics, Open Questions, Glossary. Missing: Assumptions Index (mechanical, raised). Optional and absent: Risks, Timeline, Dependencies — all defensible to omit for a solo-maintainer passion project.

---

*End of review. Verdict: PASS WITH CONDITIONS — resolve the two `critical` Done-ness findings (SC-1 equivalence + SC-2 measurement methodology), add Assumptions Index (high), and fix the §13/§12 broken cross-ref before downstream epics consume this PRD.*
