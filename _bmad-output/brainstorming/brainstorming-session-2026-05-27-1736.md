---
stepsCompleted: [1, 2, 3, 4]
inputDocuments: []
session_topic: 'Design dataset for `koel` — a premium OSS Flutter/Dart SDK implementing the AG-UI agent-UI protocol'
session_goals: 'Understand CopilotKit + AG-UI deeply enough to design a production-grade Dart client; resolve architectural, modular packaging, naming, and scope decisions for a passion-driven OSS package'
selected_approach: 'progressive-flow'
techniques_used: ['first-principles-thinking', 'cross-pollination', 'morphological-analysis', 'scamper-eliminate', 'failure-analysis-pre-mortem', 'decision-tree-mapping']
ideas_generated: 20
context_file: ''
session_active: false
workflow_completed: true
brand_chosen: 'koel'
package_count: 9
---

# Brainstorming Session Results

**Facilitator:** CPAgent
**Date:** 2026-05-27

## Session Overview

**Topic:** Build a high-quality CopilotKit Dart client for Flutter

The TPS mobile app currently embeds the `tps-ai-fe` Next.js chatbot inside a WebView. The web app uses CopilotKit 1.50 + Agno/LangGraph agent. To replace the WebView with native Flutter, the blocking dependency is the CopilotKit runtime protocol — there is no Dart client today. This session aims to extract enough technical understanding to design and scope a first-class Dart client.

**Goals:**
- Map the CopilotKit runtime ↔ client protocol end to end (transport, framing, message types, lifecycle).
- Map the AG-UI agent protocol (Agno/LangGraph adapter) and how CopilotKit consumes its events.
- Identify the minimum viable surface area for a Dart client to support the tps-ai-fe use cases (streaming chat, threads, follow-up questions, chat modes, tickers metadata, feedback to Langfuse, optional generative UI / chart cards).
- Identify higher-tier capabilities that would make the Dart client "cao cấp" (advanced) — reconnection, backpressure, offline queue, tool registration, generative UI, state sharing, observability.
- Surface unknowns and open questions that must be resolved before committing to implementation.

### Context Guidance

Out of scope for this session (per user direction):
- Time/effort estimates
- Go/no-go decision on the broader port
- Implementation of the Dart client itself

In scope:
- Deep technical research on CopilotKit + AG-UI + Agno
- Brainstorming the design surface, capabilities, and open questions of a Dart client

### Session Setup

Selected approach: TBD (after research findings are surfaced, user will pick technique).

---

## Research Synthesis (Pre-Ideation)

Three parallel research agents ran on (a) `@copilotkit/runtime` + `@copilotkit/react-core` source, (b) public CopilotKit & AG-UI documentation, (c) `@ag-ui/client` + `@ag-ui/agno` source. Direct verification reads on the installed packages confirmed the wire reality at the version tps-ai-fe ships (`@copilotkit/runtime@1.50.0`).

### The two-protocol reality at v1.50

The system has **two distinct wire protocols** stitched end-to-end:

```
+---------------------+       Protocol #1: GraphQL              +-------------------------+       Protocol #2: AG-UI SSE          +-------------------+
|  Flutter / React    |  POST /api/copilotkit                   |  CopilotRuntime          |  POST ${baseURL}/agno-chat            |  Agno Python      |
|  client (target     |  Content-Type: application/json         |  (Next.js handler at     |  Content-Type: application/json       |  agent backend    |
|  for the Dart       |  Body: GraphQL mutation                 |  src/app/api/copilotkit/ |  Body: RunAgentInput                  |  (or LangGraph)   |
|  client)            |  Response: chunked NDJSON of            |  route.ts) hosts the     |  Accept: text/event-stream             |                   |
|                     |  generateCopilotResponse                 |  GraphQL runtime AND     |  Response: AG-UI SSE event stream     |                   |
|                     |                                          |  speaks AG-UI upstream   |                                        |                   |
+---------------------+                                          +-------------------------+                                        +-------------------+
```

- **Wire #1 (client ↔ Next.js runtime):** Despite docs saying "GraphQL removed in v1.50", the installed `@copilotkit/runtime@1.50.0` bundle still contains the GraphQL `generateCopilotResponse` mutation (`grep` confirms it in `node_modules/@copilotkit/runtime/dist/index.mjs`, and also in `@copilotkit/react-core`). The Next.js route at `src/app/api/copilotkit/route.ts:28-32` mounts `copilotRuntimeNextJSAppRouterEndpoint` → which is a Hono + GraphQL handler.
- **Wire #2 (Next.js runtime ↔ Agno Python):** `new AgnoAgent({ url: ${baseURL}/agno-chat })` (route.ts:17–19) is an `HttpAgent` from `@ag-ui/client` that POSTs `RunAgentInput` JSON and consumes a `text/event-stream` of AG-UI events.

Public docs describe a v1.50+ future where wire #1 also becomes AG-UI. That migration is partly in-flight (the bundle ships AG-UI primitives alongside the GraphQL stack), but the *deployed shape today* is two-protocol.

### Wire #1 — GraphQL surface (from runtime source)

- **Endpoint:** `POST /api/copilotkit`, `Content-Type: application/json`
- **Request body:** standard GraphQL envelope. Operation: `generateCopilotResponse`. Variables: `GenerateCopilotResponseInput { metadata, threadId?, runId?, messages[], frontend, agentSession?, agentState?, agentStates?, extensions?, metaEvents?, context?, cloud?, forwardedParameters? }`
- **Response framing:** chunked HTTP body, newline-delimited GraphQL responses (the `@stream` and `@defer` directives on `messages` / `metaEvents` cause GraphQL to deliver partial frames as separate JSON objects, one per line). Server code: `streaming.ts → writeJsonLineResponseToEventStream`. Client code: `CopilotRuntimeClient.asStream` wraps it in a `ReadableStream`.
- **Message types in `messages` stream:**
  - `TextMessageOutput` (id, role, createdAt, parentMessageId, content[]) — content streams chunk by chunk
  - `ActionExecutionMessageOutput` (id, parentMessageId, name, arguments[]) — args streamed as JSON fragments
  - `ResultMessageOutput` (id, actionExecutionId, actionName, result)
  - `AgentStateMessageOutput` (threadId, agentName, role, state, running, nodeName, runId, active)
  - `ImageMessageOutput` (base64)
- **Meta-events:** `LangGraphInterruptEvent`, `CopilotKitLangGraphInterruptEvent`
- **Headers:** `Authorization` passed through (no built-in auth), `x-copilotcloud-public-api-key` for guardrails, `X-CopilotKit-Runtime-Client-GQL-Version` from client, `X-CopilotKit-Runtime-Version` echoed from server for SemVer mismatch warnings
- **Auth in tps-ai-fe:** Next.js middleware (`src/proxy.ts`) reads `auth_token` cookie set via `/api/auth/callback` and forwards as `X-Auth-Token` header on the proxied calls. The CopilotKit mutation itself does not validate tokens — auth happens at the Hono/Next layer surrounding the runtime mount.
- **Cancellation:** standard fetch `AbortController` from client closes the stream.
- **Versioning:** SemVer header exchange; no formal protocol version field.

### Wire #2 — AG-UI surface (from @ag-ui/client + @ag-ui/agno source and ag-ui.com)

- **Endpoint pattern (Agno):** `POST ${baseURL}/agno-chat` (configurable per-agent in CopilotKitRemoteEndpoint Python; LangGraph adapter uses LangGraph deployment URL instead)
- **Request body:** `RunAgentInput { threadId, runId, parentRunId?, state, messages[], tools[], context[], forwardedProps }`
- **Response framing:** SSE (`text/event-stream`) is default; binary `application/vnd.ag-ui.event+proto` is supported with a 4-byte big-endian length-prefix protobuf frame.
- **Event taxonomy (24+ events, all discriminated by `type`):**
  - Lifecycle: `RUN_STARTED`, `RUN_FINISHED`, `RUN_ERROR`, `STEP_STARTED`, `STEP_FINISHED`
  - Text: `TEXT_MESSAGE_START / CONTENT / END / CHUNK`
  - Thinking (extended reasoning): `THINKING_START / END`, `THINKING_TEXT_MESSAGE_START / CONTENT / END / CHUNK`
  - Tools: `TOOL_CALL_START / ARGS / END / CHUNK / RESULT`
  - State: `STATE_SNAPSHOT`, `STATE_DELTA` (RFC 6902 JSON Patch), `MESSAGES_SNAPSHOT`
  - Activity (structured progress): `ACTIVITY_SNAPSHOT`, `ACTIVITY_DELTA`
  - Extension: `RAW`, `CUSTOM`
  - All events: optional `timestamp` (Unix ms), optional `rawEvent` opaque metadata
- **Message model:** OpenAI-compatible roles `user | assistant | system | tool | developer`; messages reconstructed client-side from event streams by `messageId` / `toolCallId`.
- **Tools:** `Tool { name, description, parameters: JSON Schema }`. Tool result returned to next run as a `ToolMessage` (role:"tool", toolCallId, content).
- **State sync:** snapshots + RFC 6902 patches; last-writer-wins, no protocol-level locking.
- **Errors:** terminal `RUN_ERROR` event; no built-in retry / reconnection semantics in the protocol itself.

### Pre-existing community Dart implementation

- **Package**: `ag_ui` on pub.dev (v0.1.0), source at `github.com/ag-ui-protocol/ag-ui/tree/main/sdks/community/dart`
- **Coverage**: all ~16 core event types, `HttpAgent` with SSE parsing, JSON Patch state delta, tool calls, message buffer assembly
- **Limits**: published ~8 months ago; newer event types (`THINKING_*`, `ACTIVITY_*`, possibly `TOOL_CALL_CHUNK`) likely missing; Dart ≥ 3.3; deps `http ^1.1.0` + `meta ^1.17.0`. No `proto` binary encoding.
- **Kotlin Multiplatform SDK** is more mature and production-tested; reading its source is a strong reference for what a top-tier Dart port should cover.

### What "cao cấp" (advanced) means for a Dart client

Distilled from the research, an advanced Dart client should cover:

- **Both transports**: SSE (text/event-stream) and protobuf binary (`application/vnd.ag-ui.event+proto`) with content-negotiation
- **All ~24 event types**, including newer reasoning/activity/chunk variants
- **Strict event grammar validation** (`verifyEvents` parity — START must precede CONTENT, IDs must match, etc.)
- **Message + state reducers** that produce immutable updates suitable for BLoC integration
- **RFC 6902 JSON Patch** state-delta application (Dart's `json_patch` package qualifies)
- **Tool registration** with declarative parameter schemas + handler invocation
- **CoAgent state binding** with diff-aware emission
- **Frontend `Context` and `Readable`** semantics
- **Mid-stream abort & cancellation tokens**, integrated with Dart `StreamSubscription`
- **Resilience**: reconnect-with-resume (where the spec allows), backpressure on slow consumers, structured error mapping
- **Observability**: subscriber hooks parity (`onEvent`, `onTextMessageStartEvent`, etc.) for Bloc/analytics integration
- **Wire #1 (GraphQL) bridge** to also talk to the existing Next.js runtime (so we don't *have* to bypass the runtime layer)
- **Type-safe, Freezed-friendly models** for every event and message
- **Test fixtures** captured from real traffic (Charles/mitmproxy on existing webview)

### Strategic choice exposed by research

The Dart client can target **one of three architecture postures**. Each has different implications for the mobile project:

1. **A. Bypass-the-runtime, pure AG-UI**: Talk Dart ↔ Agno Python directly. Skip Next.js entirely. Simpler wire, leverages community `ag_ui` package. Loses CopilotKit Runtime middleware (auth header injection, multi-agent routing, guardrails, telemetry).
2. **B. Speak GraphQL to existing Next.js route**: Implement a Dart GraphQL streaming client + `generateCopilotResponse` mutation + message-shape converters. Keeps all existing Next.js value (auth middleware, Langfuse logging, rate-limit, follow-up questions service, market-snapshot proxy, chat-modes endpoint). Heaviest implementation.
3. **C. Dual-mode client**: Same Dart client speaks AG-UI to Agno directly *and* GraphQL to the Next.js runtime (selectable per init). Highest ceiling, also highest surface; matches what the upstream CopilotKit codebase is doing during their AG-UI migration.

### Open questions surfaced by research

These are unresolved after the research pass and worth ideation:

- `OQ-1` Does the Next.js runtime in v1.50 also expose a non-GraphQL AG-UI endpoint, or only `generateCopilotResponse`? (Code suggests dual surfaces exist but only the GraphQL one is mounted by `copilotRuntimeNextJSAppRouterEndpoint`.)
- `OQ-2` How does LangGraph interrupt resume work on the wire? (No second mutation found; likely encoded in next `generateCopilotResponse` call via `metaEvents` echoback.)
- `OQ-3` Are the Python `/agno-chat` URLs authenticated independently, or does the runtime layer enforce auth that wouldn't apply if Dart talks to Agno directly? (Critical for posture A.)
- `OQ-4` Will CopilotKit drop GraphQL in a near-future minor (1.6x?) and break a Dart client built against wire #1? (Roadmap signal vs. risk to lock in.)
- `OQ-5` What tps-ai-fe features rely on Next.js-only code paths and would break in posture A? Follow-up questions, market snapshots, chat-modes, feedback-to-Langfuse, rate-limit are all in `/api/proxy/*` — independent of CopilotKit; they'd need separate Dart clients regardless.
- `OQ-6` Does the existing `ag_ui` pub.dev package cover enough of the modern event set, or do we fork/rewrite?
- `OQ-7` How do we capture authoritative wire traffic to seed test fixtures? (Charles/mitmproxy against the live webview during a known interaction.)
- `OQ-8` Do we need protobuf binary encoding in v1 of the Dart client, or only SSE?
- `OQ-9` Will the Dart client need to host *backend-emitted* generative-UI directives (A2UI `createSurface` etc.) or stay chat-only initially?
- `OQ-10` Tool-call security: when Agno asks the client to invoke a tool, does TPS want a confirmation layer (especially for any tool that could touch order placement / money movement)?

---

## Technique Selection

**Approach:** Progressive Technique Flow (Deep Dive, target 100+ ideas, ~1h25–1h30)

**Progressive Techniques:**

- **Phase 1 — Expansive Exploration:** First Principles Thinking (primary) + Cross-Pollination (5-min sprint)
- **Phase 2 — Pattern Recognition:** Morphological Analysis (parameter × option matrix)
- **Phase 3 — Idea Development:** SCAMPER + Pre-mortem / Failure Analysis
- **Phase 4 — Action Planning:** Decision Tree Mapping + concrete checklist (no time estimates per user)

**Journey Rationale:** Topic is technical-deep with high-stakes architecture choices. Start by stripping the problem to first principles so the AG-UI "received wisdom" and the existing `ag_ui` pub.dev package don't anchor us into a local-maximum design. Cross-pollination injects ideas from sibling protocols (gRPC, GraphQL streaming, OpenAI Realtime, Anthropic SDK). Morphological analysis maps the orthogonal axes into a combination space so we can spot synergies and contradictions. SCAMPER refines top concepts; pre-mortem stress-tests them. Decision tree closes the loop by turning open questions into concrete branches and next actions.

---

## Technique Execution Results

### Strategic Anchor Established Mid-Session

**The Dart client ships as a standalone Flutter package** (likely OSS / pub.dev), then is *consumed* by TPS mobile — not built into TPS folders. The TPS codebase exploration done earlier in this session is context for the AI facilitator, not a design constraint for the package. All subsequent ideation evaluates choices against "what would a top-tier reusable Flutter package look like" first, with TPS fit as a downstream consumer concern.

### Phase 1 — First Principles Thinking

**Approach:** First Principles + organic Cross-Pollination (folded into each prompt by referencing dio, langchain_dart, openai_dart, firebase_*, riverpod, freezed, supabase_flutter, Apollo, GraphQL Flutter, graphql_flutter, bloc DevTools, Riverpod DevTools).

**Facilitation style:** Adapted mid-session per user feedback — each prompt now leads with concept explanation, Flutter-side analogy, code sketches for each option, and an opinionated recommendation before asking for gut feeling. Captured 13 substantial architectural decisions (vs raw 100-idea quantity target — depth-over-breadth was the right trade-off for this user and topic).

#### Captured Ideas

**[Phase 1 · Foundations #1] Two-Method Atomic Client**
- _Concept_: At its irreducible core, an AI client only needs `send(intent) → Stream<Event>` and `cancel()`. Everything else — auth, retries, tool registries, UI, persistence — is ergonomic layering on top of that primitive.
- _Novelty_: Most SDKs (OpenAI, Anthropic, ag_ui) ship a fat surface (15+ methods, dozens of types) from day one. Treating those as decorators on a 2-method core forces every API addition to justify why it can't be expressed as `send/cancel + Stream transforms`, which keeps the kernel testable and the public API negotiable.

**[Phase 1 · Foundations #2] Three-Layer Public API (Client / Session / Raw)**
- _Concept_: Public surface is layered explicitly — `KoelClient` holds config + auth, `ChatSession` is the ergonomic 80% path with `threadId`+messages held for you, and a raw `client.run(RunAgentInput)` stream is exposed for power users. Matches `firebase_firestore` / `supabase_flutter` / `openai_dart` idioms.
- _Novelty_: The community `ag_ui` v0.1.0 package collapses Client + Session into a single `HttpAgent`. The 3-layer split makes "config", "session", and "raw protocol access" three distinct package surfaces a Flutter dev can pick from based on what they're building.

**[Phase 1 · Foundations #3] Hybrid Event Stream + Opt-In Reducer**
- _Concept_: Package returns `Stream<AgUiEvent>` as the canonical low-level API, and ships a `ChatStateReducer` helper that turns events into a higher-level `Stream<ChatState>`. Dev picks per use case; reducer is a pure function (testable, swappable, customizable).
- _Novelty_: Existing chat-AI Dart packages (`langchain_dart`, `openai_dart`) only ship the raw stream and let every consumer reinvent assembly — which has produced repeated bug reports. Pre-built reducer levels up DX without losing low-level control; making it pure & pluggable also leaves room for domain reducers without forking.

**[Phase 1 · Foundations #4] Interceptor Chain From v1 (dio-style)**
- _Concept_: Auth + retry + logging + error handling all flow through a composable `Interceptor` pipeline rather than fixed config flags. Default constructor wires `AuthInterceptor(tokenProvider:)`, but users can chain custom interceptors (logging, Sentry, 401 retry, header rewriting, request signing).
- _Novelty_: Most AI SDKs hardcode auth as a constructor param and bake retry into the client itself. Borrowing `dio`'s interceptor model into an AI SDK future-proofs the package: any cross-cutting concern becomes a 1-class addition, not a breaking change to the client surface.

**[Phase 1 · Foundations #5] App Owns Business-Logic Safety; Package Stays Out**
- _Concept_: Tool handlers execute directly when the agent calls them — the package provides no built-in confirmation layer, no risk middleware, no domain rules. App developer registers the handler and is responsible for any business-side gating *inside* the handler.
- _Novelty_: Combined with the ambitious interceptor decision in #4, an emerging philosophy: **the package goes deep on infra concerns (auth, retry, logging, transport) but stays surgically out of business logic (tool safety, domain rules, financial guardrails).** That separation is unusual and more honest about where each side has authority.

**[Phase 1 · Foundations #6] Modular Multi-Package Distribution (Premium Positioning)**
- _Concept_: Ship as 7–9 small focused packages instead of a monolith. Mirrors `langchain_dart` / `firebase_*` / `riverpod` ecosystems where each package owns a single responsibility (protocol, transport, adapter, Flutter integration, widgets, devtools, test helpers). Consumer composes only what they need.
- _Novelty_: Starting modular from v1 signals "premium" to OSS users (proven by `langchain_dart`'s adoption), but raises upfront engineering cost (Melos monorepo, versioning strategy, cross-package CI). User explicitly accepted this trade-off.

**[Phase 1 · Foundations #7] Brand-New Name, Quality-First Distribution**
- _Concept_: The package ships under a brand-new, distinctive name with no protocol-prefix piggybacking (no `agui_*`, no `copilotkit_*`). Philosophy: a great package earns its audience — SEO and pub.dev score are downstream of quality.
- _Novelty_: Inverts the "premium" instinct seen in most modern OSS launches. Treats naming as identity work, not search work — like `riverpod`, `dio`, `freezed`, `bloc`.

**[Phase 1 · Foundations #8] Brand: `koel`**
- _Concept_: Package family named `koel` (Hindi for the singing cuckoo bird) — distinctive, no protocol-prefix piggyback, room to grow beyond AG-UI if ecosystem evolves. All `koel_*` variants verified available on pub.dev.
- _Novelty_: Brand doesn't lexically reveal what the package does, forcing the README and demos to do the storytelling — consistent with the quality-over-discoverability philosophy.

**[Phase 1 · Foundations #9] Rewrite Clean Slate, Inspired-By Credit**
- _Concept_: `koel_core` is written from scratch rather than forking the existing community `ag_ui` v0.1.0 package. A single line in the README credits the original community SDK as inspiration. No code inheritance, no migration path obligation to v0.1.0 users.
- _Novelty_: Most OSS projects either fork (inheriting structural debt) or compete silently. Explicit "inspired-by" credit threads the needle: respects the community origin, but reserves design freedom for premium positioning. Same model Riverpod used vs Provider.

**[Phase 1 · Foundations #10] Optional SessionStorage Adapter + Persist-and-Show Partial**
- _Concept_: `koel_core` defines a `SessionStorage` interface. `koel_flutter` ships three built-in implementations (`InMemorySessionStorage`, `HiveSessionStorage`, `SecureSessionStorage`). Default behavior persists all messages including in-progress partial responses; on app reopen the user sees their previous chat including the half-completed AI message marked `incomplete`.
- _Novelty_: Most chat SDKs either skip persistence entirely or hardcode one storage choice. The adapter pattern lets the package stay agnostic while shipping batteries-included defaults. "Persist partial messages" matches user mental model (they remember what the AI started to say).

**[Phase 1 · Foundations #11] MessageContentParser Helper + Deferred A2UI Module**
- _Concept_: `koel_flutter` ships a `MessageContentParser` that splits assistant messages into a `List<MessageSegment>` (text segments + custom code blocks tagged by name). The app renders each segment with its own Flutter widget. A2UI declarative rendering is deferred to a future `koel_a2ui` package, shipped only when the upstream A2UI spec stabilizes. Implicit: wire format = markdown code blocks (pragmatic, matches tps-ai-fe).
- _Novelty_: The segment-based contract is the sweet spot — package owns parsing, app owns rendering. Deferring A2UI to a separate package demonstrates modular discipline: speculative features get their own package so v1 doesn't carry their risk.

**[Phase 1 · Foundations #12] Sealed Error Hierarchy via RunErrorEvent**
- _Concept_: Errors are first-class events in the stream. `RUN_ERROR` (already in AG-UI spec) is delivered as a `RunErrorEvent` whose `error` field is a Dart 3 sealed class (`TransportError | ProtocolError | AgentError | BusinessError(code: KoelErrorCode)`). Consumer handles via exhaustive `switch` — compile-time guarantees every error type is addressed.
- _Novelty_: Reuses an AG-UI primitive instead of inventing parallel exception hierarchy. Combined with Dart 3 sealed classes + pattern matching, gives compile-time exhaustiveness guarantees most Dart SDKs can't offer. Business error codes are standardized via a `KoelErrorCode` enum + overridable `ErrorClassifier`.

**[Phase 1 · Foundations #13] Interceptor + DevTools Extension Combo at v1**
- _Concept_: Observability ships in two layers from day one — `koel_core` includes built-in `LoggingInterceptor`, `EventTraceInterceptor` (ring buffer), and `SentryBreadcrumbInterceptor` (no hard dep); `koel_devtools` is a separate package that adds a Flutter DevTools extension with live event stream view, time-travel replay, tool call inspector, network panel, and exportable trace JSON.
- _Novelty_: Time-travel replay for AI streams is rare — most chat SDKs offer logging at best. Applying the time-travel + inspector idiom to *agent event streams* directly addresses the hardest debugging case in agentic apps ("why did the agent emit this?").

#### Phase 1 — Emerging Design Philosophy

Reading across all 13 ideas, a coherent worldview emerges that should anchor every subsequent decision:

> **"Infra deep, business out. Modular by discipline, opinionated about cross-cutting craftsmanship, agnostic about everything else."**

- Deep on infra: interceptors (auth/retry/log), reducer, sealed error hierarchy, devtools, storage adapter
- Out of business: tool handler safety, UI rendering, domain rules, auxiliary REST endpoints
- Modular: 9 packages with clear single-responsibility boundaries
- Premium positioning: brand-new name, DevTools extension, time-travel replay, conformance test fixtures
- Forward-compatible: discriminated unions for protocol evolution, semver discipline, adapter interfaces

---

### Phase 2 — Morphological Analysis

**Approach:** Plotted 15 design dimensions against their option spaces; mapped Phase 1 decisions to specific cells; identified synergies, tensions, and gaps. The matrix made the design's coherence visible at a glance — most Phase 1 decisions cluster around a "composable layered swappable" DNA.

#### Phase 2 — Key Synergies Identified

- **Interceptor mechanism + Observability tier**: Single composable cross-cutting pattern serves auth, retry, logging, tracing, and devtools instrumentation.
- **Storage adapter + Modular packaging**: "Swappable everything" — adapter pattern at persistence layer mirrors modular pattern at distribution layer.
- **Sealed error + Hybrid stream**: Errors are first-class events in the stream — no special exception channel; pattern-match-exhaustive via Dart 3 sealed.
- **3-tier API + 8+ packages**: Layering is nominally consistent at both API and package level.
- **Brand new + App gates**: Premium identity independence + responsibility independence — focused, not bloated.

#### Phase 2 — Tensions Surfaced (to address in Phase 3)

- **Interceptor (package opinion) vs Tool handler (app opinion)** — execution order matters. Resolution: interceptor pre-hook → app handler → interceptor post-hook (to be specified in Phase 3 SCAMPER).
- **Adapter overload at onboarding** — app picks storage + safety + parser tags + state mgmt binding on first init. Mitigation: `koel_flutter` ships sensible defaults so the zero-config path "just works."
- **Modular 8+ + Inspired-by rewrite** — v1 ship surface is large. Mitigation: phased release (`koel_core`+`koel_http` first, then `koel_agno`+`koel_flutter`, then full 8 packages).

#### Phase 2 — Captured Ideas (Gap Resolutions)

**[Phase 2 · Gap Resolution #14] ChangeNotifier Universal Glue**
- _Concept_: `koel_flutter` ships `KoelChatController extends ChangeNotifier` as the universal Flutter binding for `Stream<ChatState>`. Works with Bloc (via `Listenable`), Riverpod (via `ChangeNotifierProvider`), GetX (via `Obx`), and plain `setState` (via `AnimatedBuilder`). Per-state-mgmt adapter packages (`koel_bloc`, `koel_riverpod`) deferred to community contributions.
- _Novelty_: ChangeNotifier as the LCD baseline + raw `Stream<ChatState>` for power users is the agnostic sweet spot proven by `firebase_*` and `connectivity_plus`. Most premium Flutter packages either pick one state mgmt (locking adopters out) or skip Flutter integration entirely.

**[Phase 2 · Gap Resolution #15] Hybrid Versioning (Foundation Lock-Step + Adapters Independent)**
- _Concept_: `koel_core` and `koel_http` release lock-step (always same version, foundation is one unit). Adapter packages (`koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`, `koel_devtools`, `koel_test`) version independently with declared `^X.Y.0` ranges on foundation.
- _Novelty_: Pure lock-step (`langchain_dart`) churns unrelated versions; pure independent (`firebase_*`) requires a compatibility doc. Hybrid threads the needle — foundation stability + adapter velocity.

**[Phase 2 · Gap Resolution #16] Multi-Session Multi-Client, No Isolate v1**
- _Concept_: `KoelClient` is non-singleton — multiple instances co-exist with different `baseUrl`/auth. Each client spawns multiple `ChatSession` instances with independent `threadId`/state. Background isolate support for long tools deferred to v2.
- _Novelty_: Most chat SDKs default to singleton client (`OpenAI.instance`, `FirebaseAuth.instance`) which boxes consumers into one backend. Multi-client from v1 anticipates multi-agent UIs and multi-tenant apps. Skipping isolate v1 keeps API simple without compromising the 99% case.

---

### Phase 3 — SCAMPER + Pre-mortem (Stress-Test)

**Approach:** SCAMPER Eliminate lens to find dead-weight ideas (none cut — user committed to full premium v1 scope). Pre-mortem with 5 failure scenarios (solo-maintainer burnout, adoption ceiling, protocol drift, security incident, DevX backfire). User explicitly rejected the "risk-mitigation" framing in favor of "craft for its own sake" — mitigations re-cast as engineering hygiene baseline.

#### Phase 3 — Captured Ideas

**[Phase 3 · Refinement #17] V1 Quality Bar: Production-Ready, Not Preview**
- _Concept_: User explicitly rejects all 4 candidate cuts (`SessionStorage` adapter, `MessageContentParser`, `koel_devtools`, multi-client). v1 ships the full premium surface. The quality bar for v1 is "có thể sử dụng được trong production" — not MVP. Phased package release is OK, but inside each shipped package the surface must be feature-complete.
- _Novelty_: Most premium OSS packages start as preview/beta to gather feedback, then iterate. The "v1 = production-ready" stance accepts a slower path to first ship in exchange for premium signal on launch day. Mirrors Riverpod v1 launch model.

**[Phase 3 · Refinement #18] Passion-Driven Craft Project — Adoption Is Not Success Metric**
- _Concept_: The project's success criteria is craftsmanship and personal learning, explicitly NOT adoption, contributor count, downloads, or stars. User accepts that even total non-adoption is a successful outcome ("không ai sử dụng hoặc không ai đóng góp thì mình cũng học được nhiều thứ").
- _Novelty_: Most OSS planning slips into "risk-avoidance" mindset. This project explicitly inverts: risk-avoidance pressures don't apply. That gives unusual design freedom — DevTools extension, modular 9 packages, brand-new name, full rewrite, multi-client v1 — all are pure craft decisions. Premium here means *premium for its own sake*, not premium-as-positioning.

**[Phase 3 · Refinement #19] Mitigations Reframed as Engineering Hygiene Baseline**
- _Concept_: All 5 pre-mortem mitigations accepted not as "risk mitigations" but as "premium engineering hygiene" that lives in the codebase regardless of outcome: CI/CD automation; `UnknownAgUiEvent` fallback + Protobuf-generated types + cross-impl conformance tests; `SentryBreadcrumbInterceptor` default OFF + built-in `PIIRedactionInterceptor`; `koel` meta-package re-exporting `koel_core`+`koel_http`+`koel_flutter` for quickstart; README quality bar including comparison post + demo apps + upstream contribution.
- _Novelty_: Mitigations divorced from fear-driven origins become a positive checklist — "what does a well-crafted premium package do?" rather than "what could go wrong?"

**[Phase 4 · Scope #20] Hard Boundary: koel is OSS-Pure, TPS Integration is Downstream Work**
- _Concept_: The koel project (repo, packages, docs, examples, fixtures) contains zero TPS branding, zero finance domain references, zero Vietnamese-stock-market themes. Example apps cover generic chat scenarios. TPS replacing the WebView with koel happens entirely in the TPS repo as a downstream consumer task — not part of koel's monorepo or roadmap.
- _Novelty_: Many OSS-spinoff projects subtly leak parent-company DNA into examples/docs. Drawing the boundary hard from day 0 keeps koel attractive to all AG-UI users, not just TPS-adjacent ones. Forces example apps to demonstrate the SDK on its own merits, not a specific business domain.

---

### Phase 4 — Decision Tree + Action Planning

#### Phase 4 — 10 Open Questions Resolution

| OQ | Question | Resolution | Reference |
|---|---|---|---|
| OQ-1 | Next.js runtime expose AG-UI endpoint song song? | N/A for koel — `koel_agno` direct + `koel_runtime` separate for GraphQL bridge | Phase 1 #6 |
| OQ-2 | LangGraph interrupt resume on wire? | Defer to `koel_langgraph` when user demand surfaces; model as resume token in metaEvents echoback | Phase 1 #6 #8 |
| OQ-3 | Agno `/agno-chat` independent auth? | **Spike A required** | Action item |
| OQ-4 | CopilotKit drops GraphQL → koel_runtime dies? | Acceptable risk; foundation core/http/agno survives | Phase 3 #18 |
| OQ-5 | TPS features needing Next.js? | Out of scope — TPS app wires aux endpoints itself in downstream task | Phase 1 #5, Phase 4 #20 |
| OQ-6 | `ag_ui` v0.1.0 sufficient? | No — full rewrite with inspired-by credit | Phase 1 #9 |
| OQ-7 | Capture authoritative wire traffic? | **Spike B required** | Action item |
| OQ-8 | Protobuf binary v1? | Defer post-v1; SSE primary | Phase 2 matrix |
| OQ-9 | Generative UI A2UI v1? | Defer; `MessageContentParser` v1, `koel_a2ui` later | Phase 1 #11 |
| OQ-10 | Tool-call confirmation v1? | App owns; package has no safety layer | Phase 1 #5 |

#### Phase 4 — Concrete Action Checklist

**Stage 0 — Setup**
- Create Melos-managed monorepo `koel/` (independent of TPS, fresh repo)
- Init 9 package skeletons: `koel_core`, `koel_http`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`, `koel_devtools`, `koel_test`, plus `koel` meta-package re-export
- CI: GitHub Actions (test, format, analyze, publish dry-run)
- LICENSE: MIT
- CONTRIBUTING.md: response-time SLA, code of conduct
- Versioning policy doc: lock-step foundation + independent adapters

**Stage 1 — Research spikes (parallel)**
- **Spike A**: Capture wire traffic from any AG-UI backend (e.g., Charles/mitmproxy a working AG-UI sample). Save SSE traces → seed fixtures for `koel_test`. *(Note: traffic capture can use AG-UI sample apps — does not require TPS context.)*
- **Spike B**: Verify Agno `/agno-chat` auth posture by calling sample server directly
- **Spike C**: Generate Dart types from AG-UI Protobuf schema (or hand-write from TypeScript reference if protoc Dart codegen fails)
- **Spike D**: Read Kotlin Multiplatform SDK source — borrow design ideas, note pitfalls

**Stage 2 — Foundation build (`koel_core` + `koel_http` lock-step)**
- `koel_core`: Event types (24+ AG-UI events as sealed/discriminated union), Message types (OpenAI-compatible roles), Tool/Context/RunAgentInput data classes, AbstractAgent base class, Interceptor framework, SessionStorage interface + InMemorySessionStorage, ChatStateReducer, Sealed KoelError hierarchy, UnknownAgUiEvent fallback
- `koel_http`: HttpAgent extending AbstractAgent, SSE stream parser, Built-in interceptors (Auth, Retry, Logging, EventTrace, Sentry [OFF default], PIIRedaction)
- Tests using Spike A fixtures

**Stage 3 — Agent adapters**
- `koel_agno`: AgnoAgent (POST `/agno-chat`), Agno message conversion, conformance tests
- `koel_runtime`: GraphQL bridge to CopilotKit Next.js runtime, `generateCopilotResponse` mutation client, AG-UI ↔ GraphQL translation, conformance tests

**Stage 4 — Flutter integration**
- `koel_flutter`: `KoelChatController extends ChangeNotifier`, `HiveSessionStorage` + `SecureSessionStorage`, `MessageContentParser`, InheritedWidget/Provider for client injection
- `koel_widgets`: Basic `MessageBubble` (Material 3 + Cupertino), `ChatInput`, `FollowUpList`, theming hooks

**Stage 5 — Polish & launch**
- `koel_devtools`: DevTools extension (live event stream, time-travel, inspector, network panel, export trace JSON)
- `koel_test`: Recorded SSE fixtures, MockAgent, tool handler test harness
- Documentation: README per package, 10-minute quickstart guide
- **3 generic example apps** (no domain branding):
  - `examples/cli_chat/`: pure Dart terminal chatbot
  - `examples/mobile_chat/`: basic Flutter mobile chat app with Agno backend
  - `examples/desktop_inspector/`: Flutter desktop showcasing `koel_devtools` extension
- Comparison post: "koel vs ag_ui" on Medium/dev.to
- Contributing guide
- Release prep: publish dry-run, pre-launch announcement, reach out to CopilotKit + Agno teams

**Note on TPS integration (out of scope for koel project):** Replacing the WebView in the TPS mobile codebase with `koel` is a separate downstream task that lives in the TPS repo. Once `koel` v1 ships, the TPS team consumes `koel_core` + `koel_http` + `koel_runtime` + `koel_flutter` like any other OSS user, then wires app-specific concerns (follow-up questions API, rate-limit display, feedback to Langfuse, market snapshot widgets, AI insight cards) at the TPS app layer. No TPS-specific code goes into koel.

---

## Idea Organization and Prioritization

### Thematic Clustering

**Theme 1 — Public API & Architecture (ideas #1, #2, #3)**
Two-Method Atomic Client → Three-Layer API (Client/Session/Raw) → Hybrid Event Stream + Opt-In Reducer. Pattern: layered explicit surface, stateless transport + stateful ergonomics.

**Theme 2 — Cross-Cutting Infrastructure (ideas #4, #12, #13)**
Interceptor Chain → Sealed Error Hierarchy → Interceptor + DevTools combo. Pattern: composable cross-cutting layer for auth, retry, error, observability — single mental model.

**Theme 3 — Domain Boundaries (ideas #5, #11)**
App Owns Business Logic → MessageContentParser segments. Pattern: package owns parsing/protocol, app owns rendering/safety/business rules.

**Theme 4 — Modularity & Distribution (ideas #6, #10, #14, #15, #16)**
Modular 8+ packages → SessionStorage adapter → ChangeNotifier glue → Hybrid versioning → Multi-session multi-client. Pattern: swappable everything; foundation lock-step, adapters independent.

**Theme 5 — Identity & Provenance (ideas #7, #8, #9, #20)**
Brand-new name → `koel` → Clean rewrite + credit → Hard OSS-pure boundary. Pattern: distinct identity, no piggybacking, no parent-company leakage.

**Theme 6 — Philosophy (ideas #17, #18, #19)**
V1 production-ready quality bar → Passion-driven craft → Hygiene baseline. Pattern: craftsmanship over adoption metrics; mitigations are best-practices, not risk responses.

**Theme 7 — Resilience & Forward Compat (cross-cutting #4, #12, #15, #19)**
UnknownAgUiEvent fallback, sealed errors, lock-step foundation, conformance tests. Pattern: protocol evolution survivable.

### Prioritization Notes

Because every idea here represents a *committed* design decision (not a candidate among many), traditional prioritization (high/medium/low impact) doesn't apply — all 20 ideas are part of the final v1 design. What does need ordering is **execution sequence**, which is captured fully in the Action Checklist (Stages 0–5).

The "research spikes" (Stage 1) are the only ideas requiring active resolution before code begins — everything else is execution.

### Breakthrough Concepts

Three ideas stand out as the most distinctive design moves for this kind of SDK:

1. **#13 Interceptor + DevTools time-travel for AI streams** — applying state-mgmt devtools idioms to agent event streams is rare in the SDK space and would be a strong "premium signal."
2. **#12 Sealed error hierarchy in RunErrorEvent** — combining an AG-UI protocol primitive with Dart 3 sealed/exhaustive-switch gives compile-time error coverage no other Dart AI SDK currently offers.
3. **#5 + #6 "Infra deep, business out" philosophy made explicit** — most SDK design articulates this implicitly; making it the project's guiding worldview produces consistent boundary decisions across persistence, tool safety, UI, and analytics.

---

## Session Summary and Insights

### Key Achievements

- **20 design decisions** captured across 4 brainstorming phases, each with concept + novelty rationale
- **Coherent design DNA articulated**: *"Infra deep, business out. Modular by discipline, opinionated about cross-cutting craftsmanship, agnostic about everything else."*
- **Naming, branding, license, and scope boundary** all explicitly settled (koel, MIT, no TPS branding)
- **10 open questions resolved**, with only 2 (OQ-3 Agno auth posture; OQ-7 wire fixtures) requiring research spikes before implementation
- **Stage-by-stage action checklist** from monorepo setup through release prep
- **Two new memory entries persisted** for cross-session continuity (`project-copilotkit-dart-package-strategy`, `feedback-brainstorming-explain-deeply`)

### Creative Breakthroughs

- **Resolving the protocol ambiguity early** (GraphQL still ships in `@copilotkit/runtime@1.50.0` alongside AG-UI) prevented the entire design from anchoring to the wrong wire format. The two-protocol reality directly informed `koel_runtime` vs `koel_agno` package split.
- **The interceptor-everywhere insight** (auth → retry → log → observability → devtools all use the same composable layer) reduced cognitive surface despite the design's breadth.
- **The shift from "risk-driven mitigations" to "engineering hygiene baseline"** unlocked by the user's passion-driven framing reframed the entire pre-mortem output without losing any of its content.

### Session Reflections

**User Creative Strengths:** Decisive judgment under uncertainty (consistent ability to make a gut call when given trade-offs); willingness to accept ambitious surface (Option C interceptor, b-tier devtools, full modular); clear value-based reasoning (positioning > metrics, passion > adoption); strong instinct for OSS hygiene (immediately surfaced trademark and naming concerns).

**AI Facilitation Adaptation:** Initial format was too quiz-like ("agree or not?") given user's stated lack of domain expertise. Mid-session pivot to *explain → analogy → code sketch → opinion → ask* dramatically improved engagement quality. Pacing also slowed (depth over the 100+ idea quantity goal) to match user preference; final 20 ideas are all *substantial* design decisions rather than ephemeral brainstorming output.

**What Made This Session Valuable:** The session combined deep research (3 parallel agents on CopilotKit source, official docs, AG-UI source) with creative facilitation, producing both a complete protocol map *and* a coherent design philosophy in one continuous flow. The structured 4-phase progression (First Principles → Morphological → SCAMPER+Pre-mortem → Decision Tree) was the right scaffold for a technical-deep brainstorm with stakes (premium OSS launch).

**Energy Flow:** Steady throughout. User stayed engaged with short, deliberate answers ("a", "d", "all agree") that signaled efficient absorption rather than disengagement. The two longest user messages came at moments of pivot — context shifts about OSS-package framing and passion-driven motivation — both of which reshaped the design center of gravity.



