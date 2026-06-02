# Epic 5 Handoff — reference-backend findings (from `../koel_backend`)

- **Created:** 2026-06-01 (as a prep plan) · **Reframed:** 2026-06-02 (backends built)
- **Owner:** Si Huynh (Project Lead)
- **Status:** reference backends **DONE + docker-verified** in the sibling project `../koel_backend`
  (5 epics / 27 stories / 4 backends). **koel Epic 5** (Dart adapters + fixture capture) **not started.**

> **Why this doc:** the reference-backend + auth-spike work Epic 5 depends on was built as the sibling
> project `../koel_backend` (not koel stories — it produces no Dart artifact). This file is the koel-side
> breadcrumb: the findings + the koel-side build sequence. **Authoritative** wire contracts live in
> `../koel_backend/backends/<x>/CONTRACT.md` + `../koel_backend/_bmad-output/implementation-artifacts/koel-backend-retro-2026-06-02.md`.

---

## Findings handed off (all resolved in `koel_backend`, source-verified + docker-probed)

- **Q1 — agno auth (OQ-Agno-Auth → RESOLVED):** agno's AG-UI route enforces **zero auth** (verified in
  `agno==2.6.10` source `attach_routes`: CORS only). → **`AgnoAuthInterceptor` stays default-ON** — a
  harmless client convention: open agno ignores the `Authorization` header (token optional). ⚠️ Stock
  agno does **not verify** the token unless the deployment adds an opt-in check.
- **Q2 — agno `/agno-chat` contract (confirmed):** koel POSTs `jsonEncode(encodeRunAgentInput(input))`
  (camelCase `{threadId, runId, state, messages[], tools[], context[], forwardedProps}`),
  `Content-Type: application/json` + `Accept: text/event-stream`; response AG-UI SSE
  (`RUN_STARTED → TEXT_MESSAGE_* → RUN_FINISHED`). agno's real route is hardcoded `/agui`; koel_backend
  exposes a bare `POST /agno-chat` reusing agno's `run_agent()` + `EventEncoder`, so koel's `/agno-chat` holds.
- **Q3 — agno error envelope (partial):** auth errors = `401`/`403` via the opt-in middleware; native
  *agent-error* envelope NOT characterized (agno ran text-only under the mock-llm). → `AgnoErrorClassifier`
  treats non-2xx as `TransportError` by default; refine agent-error mapping once a real error fixture is captured.
- **Story 5.5 (langgraph interrupt→resume):** same `/agent` route, same `threadId`, resume value at
  `forwardedProps.command.resume` (camelCase); interrupt surfaces as a `CUSTOM` event `{name: "on_interrupt"}`.
- **Story 5.7/5.8 (CopilotKit runtime) — ⚠️ significant:** `@copilotkit/runtime` **≥ 1.52.0 dropped the
  GraphQL multipart/@defer transport** (rewrote the App Router endpoint to a v2 Hono JSON `agent/run` + SSE).
  The multipart transport `MultipartGraphQLStreamParser` (5.7) targets exists only at **runtime ≤ 1.8.14**
  → koel must **pin ≤ 1.8.14** or **adapt 5.7/5.8 to the v2 Hono protocol**. Mutation `generateCopilotResponse`;
  multipart boundary `"-"`, part delim `\r\n---\r\n`, terminator `-----\r\n`, GraphQL Incremental Delivery
  (`{incremental:[{items|data,path}],hasNext}`); Story 5.8 POSTs `application/json` + `Accept: multipart/mixed`,
  `data.metaEvents=[]` required (else 500).
- **Story 5.9 (dojo):** 25/28 AG-UI event types (3 chunk-variants synthesizable koel-side); **avoid
  `/predictive_state_updates` for golden fixtures** (content-nondeterministic).

---

## koel-side build sequence (Epic 5, Dart)

1. **Story 5.1 — `AgnoAgent`.** First task = the `HttpAgent` `@protected`/override extension surface
   (Epic 4 retro Discovery 1) so `AgnoAgent extends HttpAgent` can reach the transport seam; then
   `AgnoAgent` + message conversion, baking in the confirmed `/agno-chat` contract (Q2) — not the vague
   "per agno backend docs". `/create-story 5.1` → `/dev-story 5.1` → `/bmad-code-review`.
2. **Story 5.2** — `AgnoAuthInterceptor extends AuthInterceptor` (default-ON per Q1) +
   `AgnoErrorClassifier extends DefaultErrorClassifier` (401 → `businessAuth`; refine per Q3).
3. **Story 5.3** — fill `tool/capture_fixtures.dart --backend=agno`; **Si runs the agno backend**
   (`make up-agno` in `../koel_backend`); capture → `packages/koel_test/lib/src/fixtures/agno/*.jsonl`
   (`adapter: koel_agno@0.1.0`, `synthesized: false`); `ConformanceRunner` replays **offline** via
   `MockHttpClient` (backend not needed in CI). Fold the corrupt-line → fixture-naming `FormatException`
   guard here (closes the 3.3/3.5 deferral cluster, trigger now active).
4. **Stories 5.4–5.9 (langgraph / copilotkit groups)** — build per the findings above; the CopilotKit
   runtime ≤ 1.8.14-vs-v2 decision is a prerequisite for Story 5.7/5.8.

## Si runs a koel_backend backend only at capture time
The agno auth spike is already done (in koel_backend). The remaining keyboard touch is **Story 5.3+**:
`make up-<backend>` in `../koel_backend` so `capture_fixtures.dart` can record live fixtures. Everything
else (all Dart, the capture tool) is Claude's work.
