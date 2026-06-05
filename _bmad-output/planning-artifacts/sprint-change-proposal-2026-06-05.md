# Sprint Change Proposal — CopilotKit v2 transport (SCP-2026-06-05)

- **Date:** 2026-06-05
- **Author:** Amelia (Developer) + Si Huynh (Project Lead)
- **Trigger:** Epic-5 retrospective follow-up — *"CopilotKit có 2 giao thức, sao ta làm cái cũ?"*
- **Evidence:** [spike-copilotkit-v2-2026-06-05.md](spike-copilotkit-v2-2026-06-05.md) (live-probed) + reference backend `../koel_backend/backends/copilotkit_v2/`
- **Scope class:** **Moderate–Major** (replace an adapter's transport + reverse an architecture decision; pre-v1.0.0, no published API)
- **Decision:** Path **D — Remove Legacy.** Delete the GraphQL bridge entirely; repurpose `koel_runtime` as the v2 native-AG-UI/SSE adapter. Home: **Reopen Epic 5 + gate Epic 9.**

## 1. Issue Summary

`koel_runtime` (Epic 5, 9 stories) bridges the CopilotKit **GraphQL multipart** transport (`≤1.8.14`) — a **lossy 7/28** AG-UI surface and the only sub-par adapter (hand-rolled `MultipartGraphQLStreamParser` + stateful converter + the AI-5.1 ordering buffer + a 7/28 conformance partition). A live spike (2026-06-05) proved CopilotKit **`≥1.52` (v2)** speaks **native AG-UI over SSE** at **full fidelity**, served by the existing `koel_http` `HttpAgent` with a thin agent.

CopilotKit has **dropped** the GraphQL transport (v2 since `1.52`; `2.0.0-next` is v2-only). Maintaining a lossy adapter for a **dead** transport contradicts koel's premium "craft over adoption" DNA. This is the realization of pre-identified risk **PRD OQ-4** (*"CopilotKit drops GraphQL → koel_runtime dies? Acceptable risk"*) — Project Lead invokes that pre-authorization: **remove the legacy bridge entirely** rather than carry it as "legacy."

## 2. Impact Analysis

- **PRD** — OQ-4 open → **RESOLVED (removal)**. The discovery-brief value-prop (*full event matrix incl. `THINKING_*`/`ACTIVITY`/`*_CHUNK`*) becomes **deliverable** for CopilotKit (impossible via the 7/28 bridge). Addendum constructor `CopilotRuntimeAgent({required Uri graphqlEndpoint})` changes (no GraphQL).
- **Architecture — D5 REVERSED.** D5 made `koel_runtime` independent of `koel_http` because *GraphQL ≠ SSE*. v2 **is** SSE → `CopilotRuntimeAgent extends HttpAgent`, so `koel_runtime` **now depends on `koel_http`** like `koel_agno`/`koel_langgraph`. Net simplification (one less special case). AR-20/A.5 updated; AR-10 (hand-rolled GraphQL parser) retired.
- **Epic 5** — `done`; **reopen** to swap the adapter's transport (precedent: Epic 1 reopened for 1.7). The GraphQL stories 5.7–5.9 are **superseded** (their parser/converter/agent are removed); 5.1–5.6 (agno/langgraph) unaffected.
- **Epic 9** — 9.2 sample-app README + 9.5 conformance now reference the v2 `CopilotRuntimeAgent` (full matrix). v1.0.0 ships CopilotKit support at full fidelity, no lossy adapter.
- **Code removed** — `MultipartGraphQLStreamParser`, `graphql_event_conversion`, GraphQL `CopilotRuntimeAgent`, GraphQL specifics of `CopilotRuntimeErrorClassifier`, `copilotkit_runtime` GraphQL fixtures + conformance lane, the `koel_backend/backends/copilotkit` GraphQL Next.js backend. **Preserved** as `git tag archive/koel-runtime-graphql` before deletion (craft artifact).
- **Debt-pass supersession** — AI-5.1/5.4/5.5/5.7 retire with the GraphQL code (bug-classes vanish). **Survive:** AI-5.2 (koel_core timestamp, unblocks 6.3) + AI-5.8 (cancel-teardown doc). **AI-5.3** timeout is auto-satisfied — the v2 agent inherits `HttpAgent.connectTimeout`/`readTimeout`.

## 3. Recommended Approach (chosen)

**Path D — Remove Legacy.** Replace, don't keep two implementations. `koel_runtime` keeps its name and role ("CopilotKit runtime adapter") but its transport flips GraphQL → v2 native SSE, joining agno/langgraph as a thin `HttpAgent` subclass at full fidelity.

- **Effort:** small for the agent (agno/langgraph shape); modest cleanup to remove GraphQL code + backend + fixtures.
- **Risk:** low — additive agent reuses battle-tested `HttpAgent`/`SseParser` (Epic 4); the v2 wire is live-verified; nothing published to break.
- **Why removal over "legacy":** pre-v1.0.0 = zero deprecation cost; dead upstream transport = zero new users; eliminates the 7/28 quality outlier entirely; OQ-4 pre-authorized it.

## 4. Detailed Change Proposals

### 4.1 PRD
- `discovery-brainstorming.md` OQ-4 → **RESOLVED (SCP-2026-06-05):** CopilotKit dropped GraphQL (v2 since 1.52); `koel_runtime` repurposed as the v2 native-AG-UI/SSE adapter (full matrix). GraphQL bridge removed.
- `addendum.md` / `prd.md` `CopilotRuntimeAgent` constructor: `{required Uri graphqlEndpoint}` → `{required Uri endpoint, required String agentName, String? authToken, ...}` (SSE, `extends HttpAgent`).

### 4.2 Architecture
- **D5 → REVERSED (SCP-2026-06-05):** `koel_runtime` now depends on `koel_http`; `CopilotRuntimeAgent extends HttpAgent`. Retire AR-10 (hand-rolled multipart GraphQL parser). Update AR-20/A.5 wording (native SSE, not GraphQL).

### 4.3 Epic 5 — reopen, swap transport
- **Story 5.10 — `CopilotRuntimeAgent` v2 (native AG-UI over SSE), replacing the GraphQL agent.** `extends HttpAgent`; URL `{endpoint}/agent/{agentName}/run`; POST the **complete** `RunAgentInput` (runtime 500s on a partial one); inherits SSE parse + timeouts + adapter-never-throw. Auth + error-classifier seam parity with agno/langgraph. **AC:** full AG-UI matrix passes (incl. `STATE_DELTA`/`RUN_ERROR`/`STEP_*`/`CUSTOM`) — no 7/28.
- **Story 5.11 — Remove GraphQL bridge + v2 backend/fixtures/conformance.** `git tag archive/koel-runtime-graphql`; delete `MultipartGraphQLStreamParser` + `graphql_event_conversion` + GraphQL fixtures + GraphQL conformance lane + `koel_backend/backends/copilotkit`. Harden `copilotkit_v2` backend (Docker + compose profile + `Makefile up-copilotkit-v2`); `capture_fixtures.dart --backend=copilotkit` (v2) full-matrix fixtures; conformance lane green. Update `koel_runtime` README/dartdoc (native SSE, full matrix). Reconcile `deferred-work.md` (AI-5.1/5.4/5.5/5.7 retired).

### 4.4 Epic 9 — gates
- 9.2 sample-app README references the v2 `CopilotRuntimeAgent` (full fidelity).
- 9.5 conformance-publish includes the v2 lane; v1.0.0 publish gated on 5.10–5.11.

### 4.5 sprint-status.yaml
- `epic-5: done → in-progress` (reopen; → done when 5.11 completes).
- `5-7-multipart-graphql-stream-parser`, `5-8-copilot-runtime-agent`, `5-9-...` → annotate **superseded by 5.10/5.11 (SCP-2026-06-05)** (kept for history; their work shipped, now retired).
- Add `5-10-copilot-runtime-v2-agent: backlog`, `5-11-remove-graphql-bridge-v2-backend-conformance: backlog`.

## 5. Implementation Handoff

**Moderate–Major scope → PO/DEV (architecture decision recorded; no PM replan needed — pre-authorized by OQ-4).**

1. Apply 4.1–4.5 edits (PRD OQ-4 + addendum constructor, D5 reversal note, epic-5 story stubs + supersede annotations, epic-9 gates, sprint-status reopen).
2. `git tag archive/koel-runtime-graphql` (preserve the parser) **before** removal.
3. `create-story 5.10` → `dev-story` → `code-review`; then 5.11.
4. **Success criteria:** `CopilotRuntimeAgent` passes the full AG-UI matrix against captured v2 fixtures; GraphQL code/backend/fixtures removed; D5 reversal recorded; v1.0.0 ships CopilotKit support at full fidelity with zero lossy adapters.
