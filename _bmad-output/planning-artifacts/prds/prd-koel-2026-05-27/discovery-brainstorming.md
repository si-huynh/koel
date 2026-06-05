# Brainstorming extract — koel v1

## Source

- `/Users/sihuynh/Developer/Personal/koel/_bmad-output/brainstorming/brainstorming-session-2026-05-27-1736.md`
- Session date: 2026-05-27
- Facilitator: CPAgent (BMad CIS Brainstorming)
- Techniques: first-principles-thinking, cross-pollination, morphological-analysis, scamper-eliminate, failure-analysis-pre-mortem, decision-tree-mapping
- Ideas generated: 20 (depth-over-breadth — each is a committed design decision)

## Session framing

**Topic (as stated):** "Build a high-quality CopilotKit Dart client for Flutter."

**Real underlying question:** How do we design a production-grade, premium OSS Dart/Flutter SDK for the CopilotKit + AG-UI agent-UI protocol — resolving architecture, modular packaging, naming, and scope before any code is written?

**Goals declared at session open:**
- Map the CopilotKit runtime ↔ client protocol end-to-end (transport, framing, message types, lifecycle).
- Map the AG-UI agent protocol (Agno / LangGraph adapter) and how CopilotKit consumes its events.
- Identify the minimum viable surface area for a Dart client.
- Identify higher-tier capabilities that would make the Dart client *cao cấp* (advanced) — reconnection, backpressure, offline queue, tool registration, generative UI, state sharing, observability.
- Surface unknowns and open questions before committing to implementation.

**Mid-session reframes (load-bearing):**
1. The Dart client ships as a standalone Flutter package (OSS / pub.dev), then is *consumed* by TPS mobile — not built into TPS folders. All design evaluated against "what would a top-tier reusable Flutter package look like" first.
2. Success criteria is craftsmanship and personal learning, explicitly NOT adoption / contributor count / downloads / stars. Even total non-adoption is a successful outcome.

**Out of scope (explicit):** time/effort estimates, go/no-go decisions, implementation itself.

## Design DNA & philosophy

The session crystallised one anchoring sentence that should govern every downstream decision:

> **"Infra deep, business out. Modular by discipline, opinionated about cross-cutting craftsmanship, agnostic about everything else."**

Unpacked:

- **Deep on infra:** interceptors (auth / retry / log), reducer, sealed error hierarchy, devtools, storage adapter — the SDK takes strong positions on cross-cutting concerns.
- **Out of business:** tool handler safety, UI rendering, domain rules, auxiliary REST endpoints — the SDK refuses to legislate business logic.
- **Modular:** 9 packages with clear single-responsibility boundaries; foundation lock-step, adapters independent.
- **Premium positioning:** brand-new name, DevTools extension, time-travel replay, conformance test fixtures.
- **Forward-compatible:** discriminated unions for protocol evolution, semver discipline, adapter interfaces, `UnknownAgUiEvent` fallback.

Supporting tenets surfaced in the session:

- **Passion-driven craft, not adoption-driven.** Quote: *"không ai sử dụng hoặc không ai đóng góp thì mình cũng học được nhiều thứ."*
- **v1 = production-ready, not preview.** Riverpod v1 launch model — slower path to first ship in exchange for premium signal on launch day.
- **Mitigations recast as engineering hygiene.** Pre-mortem outputs are accepted not as risk responses but as "what does a well-crafted premium package do?"
- **Hard OSS-pure boundary.** Zero TPS branding, zero finance domain references, zero Vietnamese-stock-market themes in koel.

## The 20 ideas — grouped

### Group A — Public API & Architecture (Theme 1)

**#1 — Two-Method Atomic Client**
- *Concept:* Irreducible core = `send(intent) → Stream<Event>` and `cancel()`. Everything else (auth, retries, tools, UI, persistence) is ergonomic layering.
- *Novelty:* Most SDKs (OpenAI, Anthropic, ag_ui) ship a 15+ method surface from day one. A 2-method kernel forces every API addition to justify why it isn't `send/cancel + Stream transforms`.
- *Action:* Define `AbstractAgent.run(RunAgentInput) → Stream<BaseEvent>` + cancel in `koel_core`.

**#2 — Three-Layer Public API (Client / Session / Raw)**
- *Concept:* `KoelClient` holds config + auth. `ChatSession` is the ergonomic 80% path with `threadId`+messages held for you. Raw `client.run(RunAgentInput)` is exposed for power users.
- *Novelty:* Community `ag_ui` v0.1.0 collapses Client + Session into one `HttpAgent`. Splitting them mirrors `firebase_firestore` / `supabase_flutter` / `openai_dart` idioms.
- *Action:* Three concrete public types in `koel_core` + `koel_flutter`.

**#3 — Hybrid Event Stream + Opt-In Reducer**
- *Concept:* Canonical low-level API is `Stream<AgUiEvent>`. Ship a `ChatStateReducer` helper producing `Stream<ChatState>`. Reducer is a pure function — testable, swappable, customizable.
- *Novelty:* `langchain_dart` / `openai_dart` only ship the raw stream — every consumer reinvents assembly (repeated bug reports). Pre-built reducer levels up DX without locking control away.
- *Action:* `ChatStateReducer` in `koel_core`, documented as overridable.

### Group B — Cross-Cutting Infrastructure (Theme 2)

**#4 — Interceptor Chain From v1 (dio-style)**
- *Concept:* Auth + retry + logging + error handling flow through a composable `Interceptor` pipeline rather than fixed config flags. Default ctor wires `AuthInterceptor(tokenProvider:)`; users chain custom interceptors (logging, Sentry, 401 retry, header rewriting, signing).
- *Novelty:* Most AI SDKs hardcode auth as a ctor param and bake retry into the client. Borrowing `dio`'s interceptor model into an AI SDK makes any cross-cutting concern a 1-class addition, not a breaking change.
- *Action:* Interceptor framework in `koel_core`; built-ins in `koel_http`.

**#12 — Sealed Error Hierarchy via `RunErrorEvent`**
- *Concept:* Errors are first-class events. `RUN_ERROR` is delivered as `RunErrorEvent` whose `error` field is a Dart 3 sealed class (`TransportError | ProtocolError | AgentError | BusinessError(code: KoelErrorCode)`). Consumer handles via exhaustive `switch`.
- *Novelty:* Reuses an AG-UI primitive instead of inventing a parallel exception hierarchy. Dart 3 sealed + pattern matching gives compile-time exhaustiveness most Dart SDKs can't offer. `KoelErrorCode` enum + overridable `ErrorClassifier`.
- *Action:* Sealed `KoelError` hierarchy in `koel_core`.

**#13 — Interceptor + DevTools Extension Combo at v1**
- *Concept:* Two layers from day one. `koel_core` includes built-in `LoggingInterceptor`, `EventTraceInterceptor` (ring buffer), `SentryBreadcrumbInterceptor` (no hard dep). `koel_devtools` is a separate package with a Flutter DevTools extension: live event stream view, time-travel replay, tool call inspector, network panel, exportable trace JSON.
- *Novelty:* Time-travel replay for AI streams is rare — most chat SDKs offer logging at best. Time-travel + inspector applied to agent event streams directly addresses the hardest debugging case in agentic apps.
- *Action:* Ship `koel_devtools` at v1.

### Group C — Domain Boundaries (Theme 3)

**#5 — App Owns Business-Logic Safety; Package Stays Out**
- *Concept:* Tool handlers execute directly when the agent calls them. Package provides no confirmation layer, no risk middleware, no domain rules. App developer is responsible for any business gating *inside* the handler.
- *Novelty:* Combined with #4 — "deep on infra (auth, retry, logging, transport), surgically out of business logic (tool safety, domain rules, financial guardrails)." Unusual and more honest about authority.
- *Action:* Document boundary in CONTRIBUTING.md; no safety hooks in `koel_core`.

**#11 — `MessageContentParser` Helper + Deferred A2UI Module**
- *Concept:* `koel_flutter` ships a `MessageContentParser` that splits assistant messages into a `List<MessageSegment>` (text segments + custom code blocks tagged by name). App renders each segment with its own widget. Wire format = markdown code blocks (matches tps-ai-fe). A2UI declarative rendering deferred to a future `koel_a2ui` package once the upstream spec stabilises.
- *Novelty:* Segment-based contract is the sweet spot — package owns parsing, app owns rendering. Deferring A2UI to its own package demonstrates modular discipline.
- *Action:* `MessageContentParser` in `koel_flutter`; `koel_a2ui` reserved on pub.dev.

### Group D — Modularity & Distribution (Theme 4)

**#6 — Modular Multi-Package Distribution (Premium Positioning)**
- *Concept:* Ship as 7–9 small focused packages instead of a monolith. Mirrors `langchain_dart` / `firebase_*` / `riverpod`. Consumer composes only what they need.
- *Novelty:* Starting modular from v1 signals "premium" but raises upfront cost (Melos monorepo, versioning strategy, cross-package CI). User explicitly accepted the trade-off.
- *Action:* Melos monorepo, 9 packages + 1 meta-package.

**#10 — Optional `SessionStorage` Adapter + Persist-and-Show Partial**
- *Concept:* `koel_core` defines a `SessionStorage` interface. `koel_flutter` ships three built-in impls (`InMemorySessionStorage`, `HiveSessionStorage`, `SecureSessionStorage`). Default behavior persists *all* messages including in-progress partial responses; on reopen the user sees the half-completed AI message marked `incomplete`.
- *Novelty:* Most chat SDKs skip persistence or hardcode one storage. Adapter pattern + persist-partial matches user mental model.
- *Action:* Interface in `koel_core`; impls in `koel_flutter`.

**#14 — `ChangeNotifier` Universal Glue**
- *Concept:* `koel_flutter` ships `KoelChatController extends ChangeNotifier` as the universal Flutter binding for `Stream<ChatState>`. Works with Bloc (via `Listenable`), Riverpod (via `ChangeNotifierProvider`), GetX (via `Obx`), plain `setState`. Per-state-mgmt adapter packages (`koel_bloc`, `koel_riverpod`) deferred to community.
- *Novelty:* ChangeNotifier-as-LCD + raw `Stream<ChatState>` for power users is the agnostic sweet spot proven by `firebase_*` and `connectivity_plus`.
- *Action:* `KoelChatController` in `koel_flutter`.

**#15 — Hybrid Versioning (Foundation Lock-Step + Adapters Independent)**
- *Concept:* `koel_core` and `koel_http` release lock-step. Adapters (`koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`, `koel_devtools`, `koel_test`) version independently with `^X.Y.0` ranges on foundation.
- *Novelty:* Pure lock-step (`langchain_dart`) churns unrelated versions; pure independent (`firebase_*`) requires a compat doc. Hybrid threads the needle — foundation stability + adapter velocity.
- *Action:* Versioning policy doc; Melos config enforces.

**#16 — Multi-Session Multi-Client, No Isolate v1**
- *Concept:* `KoelClient` is non-singleton. Multiple instances co-exist with different `baseUrl`/auth. Each spawns multiple `ChatSession` instances with independent `threadId`/state. Background isolate support for long tools deferred to v2.
- *Novelty:* Most chat SDKs default to singleton (`OpenAI.instance`, `FirebaseAuth.instance`). Multi-client from v1 anticipates multi-agent and multi-tenant apps.
- *Action:* Non-singleton `KoelClient` API; document isolate deferral.

### Group E — Identity & Provenance (Theme 5)

**#7 — Brand-New Name, Quality-First Distribution**
- *Concept:* Ship under a distinctive new name with no protocol-prefix piggybacking (no `agui_*`, no `copilotkit_*`). A great package earns its audience — SEO and pub.dev score are downstream of quality.
- *Novelty:* Inverts the "discoverability-first" instinct in modern OSS launches. Treats naming as identity work, not search work — like `riverpod`, `dio`, `freezed`, `bloc`.
- *Action:* Confirm trademark / name availability before publish.

**#8 — Brand: `koel`**
- *Concept:* Package family named `koel` (Hindi for the singing cuckoo bird) — distinctive, no protocol-prefix piggyback, room to grow beyond AG-UI. All `koel_*` variants verified available on pub.dev.
- *Novelty:* Brand doesn't lexically reveal what the package does — forces README and demos to do the storytelling.
- *Action:* Reserve `koel`, `koel_core`, `koel_http`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`, `koel_devtools`, `koel_test`, `koel_a2ui` on pub.dev.

**#9 — Rewrite Clean Slate, Inspired-By Credit**
- *Concept:* `koel_core` written from scratch, not forked from community `ag_ui` v0.1.0. README has a single line crediting the original SDK as inspiration. No code inheritance, no migration-path obligation to v0.1.0 users.
- *Novelty:* Most OSS projects fork (inheriting structural debt) or compete silently. Explicit "inspired-by" threads the needle — same model Riverpod used vs Provider.
- *Action:* README credit line; no migration tooling shipped.

**#20 — Hard Boundary: koel is OSS-Pure, TPS Integration is Downstream Work**
- *Concept:* The koel project (repo, packages, docs, examples, fixtures) contains zero TPS branding, zero finance domain references, zero Vietnamese-stock-market themes. Examples cover generic chat scenarios. TPS replacing the WebView with koel happens entirely in the TPS repo as a downstream consumer task.
- *Novelty:* Many OSS-spinoff projects subtly leak parent-company DNA into examples/docs. Drawing the boundary hard from day 0 keeps koel attractive to all AG-UI users and forces examples to demonstrate the SDK on its own merits.
- *Action:* Examples must be generic (`cli_chat`, `mobile_chat`, `desktop_inspector`).

### Group F — Philosophy & Quality Bar (Theme 6)

**#17 — V1 Quality Bar: Production-Ready, Not Preview**
- *Concept:* All 4 SCAMPER-eliminate candidates (SessionStorage adapter, MessageContentParser, koel_devtools, multi-client) rejected. v1 ships the full premium surface. Quality bar = *"có thể sử dụng được trong production"*. Phased package release OK, but within each shipped package the surface must be feature-complete.
- *Novelty:* Most premium OSS starts as preview/beta. "v1 = production-ready" accepts a slower path to first ship in exchange for premium signal on launch day. Mirrors Riverpod v1 launch model.
- *Action:* No package ships until its surface is feature-complete.

**#18 — Passion-Driven Craft Project — Adoption Is Not Success Metric**
- *Concept:* Success = craftsmanship and personal learning. Explicitly NOT adoption, contributor count, downloads, or stars. Even total non-adoption is a successful outcome.
- *Novelty:* Inverts the risk-avoidance mindset of most OSS planning. Risk-avoidance pressures don't apply — DevTools extension, modular 9 packages, brand-new name, full rewrite, multi-client v1 are all pure craft decisions. Premium *for its own sake*, not premium-as-positioning.
- *Action:* Document philosophy in `STRATEGY.md` / README.

**#19 — Mitigations Reframed as Engineering Hygiene Baseline**
- *Concept:* All 5 pre-mortem mitigations accepted as "premium engineering hygiene" rather than risk responses. Concretely: CI/CD automation; `UnknownAgUiEvent` fallback + Protobuf-generated types + cross-impl conformance tests; `SentryBreadcrumbInterceptor` default OFF + built-in `PIIRedactionInterceptor`; `koel` meta-package re-exporting `koel_core`+`koel_http`+`koel_flutter` for quickstart; README quality bar including comparison post + demo apps + upstream contribution.
- *Novelty:* Mitigations divorced from fear become a positive checklist — "what does a well-crafted premium package do?"
- *Action:* Ship all hygiene items at v1.

## Decision tree / dependencies between ideas

The session resolved 10 open research questions (OQ-1 through OQ-10) into design decisions:

| OQ | Question | Resolution | Ref |
|----|----------|-----------|-----|
| OQ-1 | Next.js runtime exposes AG-UI endpoint in parallel? | N/A for koel — `koel_agno` direct + `koel_runtime` separate for GraphQL bridge | #6 |
| OQ-2 | LangGraph interrupt resume on wire? | Defer to `koel_langgraph` when demand surfaces; model as resume token in metaEvents echoback | #6 #8 |
| OQ-3 | Agno `/agno-chat` independent auth? | **Spike A required** | Action item |
| OQ-4 | CopilotKit drops GraphQL → `koel_runtime` dies? | **RESOLVED (SCP-2026-06-05):** confirmed live — CopilotKit ≥1.52 (v2) is native AG-UI over SSE; GraphQL multipart is EOL at ≤1.8.14. `koel_runtime` does NOT die — repurposed as the v2 adapter (`CopilotRuntimeAgent extends HttpAgent`, full event matrix); lossy GraphQL bridge removed (D5 reversed). | #18 |
| OQ-5 | TPS features needing Next.js? | Out of scope — TPS app wires aux endpoints itself downstream | #5 #20 |
| OQ-6 | `ag_ui` v0.1.0 sufficient? | No — full rewrite with inspired-by credit | #9 |
| OQ-7 | Capture authoritative wire traffic? | **Spike B required** | Action item |
| OQ-8 | Protobuf binary v1? | Defer post-v1; SSE primary | Morphological matrix |
| OQ-9 | Generative UI A2UI v1? | Defer; `MessageContentParser` v1, `koel_a2ui` later | #11 |
| OQ-10 | Tool-call confirmation v1? | App owns; package has no safety layer | #5 |

**Cross-cutting dependency chains:**

- Foundation must ship first: `koel_core` + `koel_http` (lock-step) → enables every other package.
- Adapters are independent siblings: `koel_agno`, `koel_runtime`, `koel_langgraph` depend only on foundation.
- Flutter layer depends on foundation + at least one adapter for examples to run.
- `koel_devtools` depends on `koel_flutter` (DevTools extension is a Flutter app).
- `koel_test` is depended-on by every other package's test suite.
- `koel` meta-package re-exports `koel_core` + `koel_http` + `koel_flutter` (quickstart path).

## Packaging architecture

The 9 packages (+ 1 meta) and their responsibilities:

| Package | Layer | Responsibilities |
|---------|-------|------------------|
| `koel_core` | Foundation (lock-step with `koel_http`) | Event types (24+ AG-UI events as sealed/discriminated union); Message types (OpenAI-compatible roles); Tool / Context / RunAgentInput data classes; `AbstractAgent` base class; Interceptor framework; `SessionStorage` interface + `InMemorySessionStorage`; `ChatStateReducer`; Sealed `KoelError` hierarchy; `UnknownAgUiEvent` fallback for forward-compat. No HTTP. |
| `koel_http` | Foundation (lock-step with `koel_core`) | `HttpAgent extends AbstractAgent`; SSE stream parser; Built-in interceptors (`AuthInterceptor`, `RetryInterceptor`, `LoggingInterceptor`, `EventTraceInterceptor`, `SentryBreadcrumbInterceptor` default OFF, `PIIRedactionInterceptor`). |
| `koel_agno` | Adapter | `AgnoAgent` (POST `${baseURL}/agno-chat`); Agno message-shape conversion; conformance tests against captured fixtures. |
| `koel_langgraph` | Adapter | LangGraph deployment URL adapter; interrupt resume via metaEvents echoback (deferred surface — ships when demand surfaces). |
| `koel_runtime` | Adapter | GraphQL bridge to CopilotKit Next.js runtime; `generateCopilotResponse` mutation client; AG-UI ↔ GraphQL translation; conformance tests. |
| `koel_flutter` | Flutter integration | `KoelChatController extends ChangeNotifier`; `HiveSessionStorage` + `SecureSessionStorage`; `MessageContentParser` (text + tagged code-block segments); `InheritedWidget` / Provider for client injection. |
| `koel_widgets` | Flutter UI primitives | Basic `MessageBubble` (Material 3 + Cupertino); `ChatInput`; `FollowUpList`; theming hooks. No business styling. |
| `koel_devtools` | Tooling | Flutter DevTools extension: live event stream view, time-travel replay, tool call inspector, network panel, export trace JSON. |
| `koel_test` | Testing | Recorded SSE fixtures (from Spike A); `MockAgent`; tool handler test harness; depended-on by every other package's test suite. |
| `koel` (meta) | Convenience | Re-exports `koel_core` + `koel_http` + `koel_flutter` for the quickstart path. No types of its own. |
| `koel_a2ui` (future) | Deferred | A2UI declarative rendering — ships only when upstream A2UI spec stabilises. Name reserved. |

## Reference comparables

The session explicitly cross-pollinated from these projects (organic during prompts):

- **`dio`** — interceptor chain model (idea #4); the primary pattern koel imports wholesale into the AI-SDK space.
- **`graphql_flutter`** — streaming HTTP framing reference (informed `koel_runtime` design for chunked NDJSON over GraphQL).
- **`langchain_dart`** — modular multi-package distribution model (#6); also a *negative example* on the raw-stream-only DX (informed #3 hybrid stream + reducer).
- **`firebase_*`** — singleton-style client (rejected in favor of multi-client #16); independent versioning (informed hybrid versioning #15); ChangeNotifier-as-LCD precedent (#14).
- **`supabase_flutter`** — three-layer Client / Session / Raw idiom (#2); generic Flutter binding hooks.
- **`anthropic_sdk_dart` / `openai_dart`** — fat-surface day-one SDKs (anti-pattern; informed #1 two-method kernel); also negative example on raw-stream-only.
- **Community `ag_ui` (pub.dev v0.1.0)** — collapsed Client + Session into one `HttpAgent`; covers ~16 core event types, no `THINKING_*` / `ACTIVITY_*` / protobuf. koel rewrites clean-slate with inspired-by credit (#9).
- **Kotlin Multiplatform AG-UI SDK** — more mature, production-tested reference; Spike D explicitly reads its source for design ideas and pitfalls.
- **`riverpod` vs `provider`** — the model for "inspired-by clean rewrite" (#9), brand-new name (#7), and v1 production-ready bar (#17).
- **`freezed`** — Dart 3 sealed / pattern-matching idiom that #12 (sealed error hierarchy) leans on.
- **Bloc / Riverpod DevTools** — time-travel + inspector idioms applied to AI streams in `koel_devtools` (#13).

## Verbatim quotes worth preserving

> *"Infra deep, business out. Modular by discipline, opinionated about cross-cutting craftsmanship, agnostic about everything else."* — The design DNA. Must survive into the PRD's "Principles" section.

> *"có thể sử dụng được trong production"* — The v1 quality bar (idea #17). Vietnamese for "usable in production." Worth preserving in original form as a touchstone.

> *"không ai sử dụng hoặc không ai đóng góp thì mình cũng học được nhiều thứ"* — The passion-driven craft stance (#18). "Even if no one uses it or contributes, I'll have learned a lot." Anchors why adoption isn't the success metric.

> *"Premium here means premium for its own sake, not premium-as-positioning."* — From #18 commentary.

> *"The package goes deep on infra concerns (auth, retry, logging, transport) but stays surgically out of business logic (tool safety, domain rules, financial guardrails)."* — From #5 commentary.

> *"Brand-new, distinctive name with no protocol-prefix piggybacking."* — Naming principle (#7).

> *"Inspired-by credit threads the needle: respects the community origin, but reserves design freedom for premium positioning."* — On the relationship to community `ag_ui` (#9).

## Open questions / unresolved decisions from the session

Despite resolving the 10 protocol-level OQs, the following remain open after the session and need closure before / during PRD finalisation:

1. **Spike A (wire fixtures):** Capture authoritative AG-UI SSE traffic from a sample backend to seed `koel_test` fixtures. Charles / mitmproxy method confirmed; specific sample backend not yet picked.
2. **Spike B (Agno auth posture):** Verify whether Agno's `/agno-chat` enforces auth independent of the CopilotKit runtime layer. Outcome shapes whether `koel_agno` needs its own auth-interceptor defaults distinct from `koel_runtime`.
3. **Spike C (Protobuf codegen):** Decide whether to use `protoc` Dart codegen for AG-UI Protobuf types or hand-write from the TypeScript reference. Result determines whether binary transport is reachable in v1.5/v2.
4. **Spike D (Kotlin SDK reading):** Read the Kotlin Multiplatform AG-UI SDK source for design ideas and pitfalls. No specific design questions queued — exploratory.
5. **Phased release sequence within Stage 5:** Order of `koel_devtools` → `koel_test` → examples → comparison post is not strictly sequenced; needs PRD-level milestone definition.
6. **State-mgmt adapter packages (`koel_bloc`, `koel_riverpod`):** Explicitly deferred to community contributions — but no policy yet for accepting / governing such contributions.
7. **`koel_langgraph` surface depth:** Deferred until "user demand surfaces" — no concrete trigger criteria defined.
8. **Trademark / name clearance:** "koel" availability on pub.dev confirmed for the `koel_*` family, but no broader trademark search has been performed.
9. **Documentation toolchain:** README quality bar accepted (#19) but no decision on docs site framework (`dart doc` only? mkdocs? Docusaurus? Nextra?).
10. **License-compatible inspiration tracing:** "Inspired-by" credit accepted (#9), but no formal review of whether any of koel's design moves require explicit attribution under `ag_ui`'s license.
