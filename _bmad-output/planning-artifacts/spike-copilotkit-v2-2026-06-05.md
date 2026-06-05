# SPIKE — CopilotKit v2 transport (native AG-UI over SSE)

- **Date:** 2026-06-05
- **Trigger:** Epic-5 retro follow-up (Si's question: *"CopilotKit có 2 giao thức, sao ta làm cái cũ?"*). Drives a correct-course on the `koel_runtime` scope.
- **Method:** live-probed a real CopilotKit runtime **1.59.4** (`@copilotkit/runtime/v2`) reference backend (`../koel_backend/backends/copilotkit_v2/`, node single-route + the same `@ag-ui/client` scripted agent), captured the wire.

## Background — the two CopilotKit transports

| | GraphQL multipart (≤1.8.14) | v2 (≥1.52, current stable) |
|---|---|---|
| What koel built | `koel_runtime` — `MultipartGraphQLStreamParser` + stateful converter + D5 package (Epic 5, 9 stories) | nothing |
| Transport | `multipart/mixed` GraphQL `@defer`/`@stream` | single-route HTTP, `text/event-stream` (SSE) |
| Wire frame | GraphQL Incremental Delivery patches | `data: {<canonical AG-UI event>}` |

The Epic-5 architecture (D5) committed to the GraphQL premise; SPIKE-CK-FRAMING (2026-06-02) discovered mid-Epic-5 that GraphQL is the **legacy** transport, but the package was already designed around it. v2 was never elevated to a roadmap item.

## Findings (live evidence)

1. **v2 is native AG-UI over SSE.** `POST {base}/agent/{agentName}/run`, `Accept: text/event-stream` → each frame is `data: {type:…, …}`, a canonical AG-UI event. Byte-shape identical to what agno/langgraph emit and what koel_http's `SseParser`/`HttpAgent` already parse.

2. **Full fidelity — the matrix, not 7/28.** A rich scripted run emitted 13 distinct types incl. the exact ones the GraphQL bridge **drops**, all delivered verbatim:

   | scenario | GraphQL 1.8.14 (7/28) | v2 SSE |
   |---|---|---|
   | state | `STATE_SNAPSHOT` only (DELTA collapsed) | **`STATE_SNAPSHOT` + `STATE_DELTA`** |
   | error | `RUN_ERROR` **swallowed** (ends Success) | **`RUN_ERROR` delivered** |
   | step / custom | dropped | **`STEP_STARTED/FINISHED`, `CUSTOM` pass through** |
   | run lifecycle | agent **synthesizes** RUN_STARTED/FINISHED | **on the wire** |

   The runtime is a **transparent AG-UI passthrough** (like agno/langgraph), not a lossy re-framer.

3. **Adapter cost is small.** A `CopilotRuntimeV2Agent extends HttpAgent` — build URL `{base}/agent/{agentName}/run`, POST the full `RunAgentInput`, inherit SSE parsing. **No GraphQL parser, no stateful converter, no ordering buffer (AI-5.1), no 7/28 partition.** The agno/langgraph shape.

4. **One request gotcha (already a free win):** v2's `parseRunRequest` requires a **complete** `RunAgentInput` (`tools`/`context`/`forwardedProps` present, else HTTP 500). koel_http's `HttpAgent` already serializes the full input.

## Implication for `koel_runtime`

koel invested a 9-story D5 package + the only lossy adapter on the **superseded** transport, while the **current** transport is supported at full fidelity by the **existing** koel_http stack with a thin agent. Options for correct-course:

- **(A)** Add a v2 path (thin `HttpAgent` subclass) as the **recommended** CopilotKit integration; keep the GraphQL bridge as the documented **legacy** (≤1.8.14) option. Net-additive, low cost, high fidelity.
- **(B)** Same as A but also re-scope/relabel `koel_runtime` so v1.0.0 does not imply "CopilotKit support = the lossy 7/28 bridge."
- **(C)** Defer v2 to post-1.0.0 (status quo) — but then v1.0.0 ships CopilotKit support as lossy-only, which the spike shows is avoidable.

**Recommendation:** A/B before v1.0.0 (Epic 9). The legacy bridge is not wasted (real ≤1.8.14 installed base; craft showcase), but it should not be the *only* or *headline* CopilotKit path.

## Reference backend

`../koel_backend/backends/copilotkit_v2/` — runnable (`npm i && npm start`, :8005), 4 scenarios (text/tool/state/error) mirroring the GraphQL backend for direct fixture comparison. Docker + a `capture_fixtures` lane are follow-ups for the formal v2 story.
