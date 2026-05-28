# Brief extract — koel v1

## Source
- `/Users/sihuynh/Developer/Personal/koel/_bmad-output/planning-artifacts/briefs/brief-koel-2026-05-27/brief.md` (canonical, status: final)
- `/Users/sihuynh/Developer/Personal/koel/_bmad-output/planning-artifacts/briefs/brief-koel-2026-05-27/.decision-log.md` (audit trail; carries binding priors)
- Per D-RUN-8: no `addendum.md`. The brainstorming session at `_bmad-output/brainstorming/brainstorming-session-2026-05-27-1736.md` is the canonical architecture-detail reference for downstream PRD work.

## Problem statement / motivation

The AG-UI agent-UI protocol and the broader CopilotKit runtime ecosystem are well-served on the web (React, Next.js) but **underserved on Flutter**. The community `ag_ui` v0.1.0 Dart package on pub.dev is roughly eight months stale, missing newer event types (`THINKING_*`, `ACTIVITY_*`, `TOOL_CALL_CHUNK`), and ships without production-grade infrastructure Flutter devs expect: no interceptor framework, no sealed error hierarchy, no DevTools support, no conformance fixtures, no observability tooling.

Flutter teams integrating agents today face three bad choices:
1. Accept `ag_ui` 0.1.0's gaps and rewrite missing infrastructure in every consumer codebase.
2. Embed a WebView around a JavaScript chat client — paying performance cost, bundle cost, losing native state binding and debugging.
3. Build their own AG-UI client from the protocol spec — duplicating work.

> "The cost of the status quo is not catastrophe; it is friction. Each team rebuilds the same auth interceptor, the same retry loop, the same SSE parser, the same error mapping. The Flutter AG-UI ecosystem is held back not by missing capability but by missing foundation."

## Target users / consumers

Strict priority order (per D-RUN-3): when API tradeoffs conflict, resolve in P1's favor first; only escalate to P2 when P1 is satisfied; P3 is enabled by good API discipline rather than dedicated hooks.

- **P1 — The author, and the author six months later (Si Huynh + future-Si).** koel is a passion project; the first reader of every public class is the author. Success bar: "open the source in six months and every line still earns its place." API surface matches the author's mental model of how agent runtimes should be shaped. DevTools time-travel is the marquee debugging affordance because it is what the author wants to use.
- **P2 — The Flutter dev integrating agents into a real app (mobile or desktop).** Familiar with `dio`, `firebase_*`, `supabase_flutter`, and one of Bloc / Riverpod / Provider / `setState`. Evaluating koel against three alternatives: accepting `ag_ui` 0.1.0 gaps, embedding a WebView, or rolling their own. Success for them: replace whichever fallback they are using inside one sprint, with sensible defaults and example apps that work end-to-end without surgery.
- **P3 — The contributor or downstream library author.** Opens a PR against koel, builds `koel_riverpod` or `koel_bloc`, forks for an experimental adapter, or implements a new protocol surface. The 9-package modular shape, public adapter interfaces (`AbstractAgent`, `SessionStorage`, `ErrorClassifier`, `Interceptor`), and conformance fixtures exist for them. **Earned via API discipline, not dedicated extension hooks — the contract is the source.**

## Vision & differentiation

**Design DNA:** *"Infra deep, business out. Modular by discipline, opinionated about cross-cutting craftsmanship, agnostic about everything else."*

**Vision (2–3 years):** koel is the package Flutter devs reach for when integrating any agent runtime — not because it markets best, but because the source reads cleanly, the DevTools experience makes agent debugging feel like state debugging, and the adapter strategy slots new protocols in without rewriting consumer code. The 9-package shape has grown: `koel_bloc`, `koel_riverpod`, `koel_a2ui` exist as community-maintained adapters or in-tree additions. Conformance fixtures are referenced by other AG-UI client implementations across languages as the canonical "does it actually conform" test suite.

**Differentiation vs. community `ag_ui` v0.1.0, raw HTTP, or rolling-your-own:**
- **Interceptor chain from v1.** Composable pipeline (dio-style) for auth, retry, logging, tracing, DevTools instrumentation. Any cross-cutting concern becomes a one-class addition, not a breaking change. Most AG-UI clients do not ship this.
- **Sealed error hierarchy + first-class error events.** `RunErrorEvent` arrives in the stream and is mapped to a Dart 3 sealed class hierarchy (`TransportError | ProtocolError | AgentError | BusinessError`). The compiler enforces exhaustive handling at the app layer — no silently swallowed protocol errors.
- **Time-travel replay in DevTools.** The pattern from Redux/Bloc/Riverpod devtools, applied to agent streams: step backward through events, inspect tool calls, export traces. Rare in the SDK space.
- **Conformance test fixtures.** Real captured SSE traffic ships as structured test data; consumers (and koel itself) validate protocol behavior offline.
- **Discriminated unions for protocol evolution.** Event taxonomy is sealed; unknown future events surface as `UnknownAgUiEvent` for forward compatibility without breaking switch exhaustiveness on known types.
- **State-management agnostic.** `ChangeNotifier` is the lowest-common-denominator binding; raw `Stream<ChatState>` is the escape hatch. No assumption of Bloc, Riverpod, GetX, or Provider — consumers wire whatever they use.

**Honest non-moat:** "koel is not faster than `ag_ui` because `ag_ui` is fast — it is faster because it is more complete. The 'unfair advantage' is willingness to spend craft time on infrastructure others skipped, not a technical trade secret."

## In-scope for v1

- **Both wire protocols:** AG-UI SSE (primary, via `koel_http`) **and** CopilotKit GraphQL runtime bridge (`koel_runtime`, `generateCopilotResponse` mutation). Both production-grade at v1.0.0 (per D-RUN-7).
- **All ~24 AG-UI event types** including `THINKING_*`, `ACTIVITY_*`, `TOOL_CALL_CHUNK`. Full protocol — no subsets.
- **Interceptor framework + 6 built-in interceptors:** Auth, Retry, Logging, EventTrace, Sentry (OFF by default), PIIRedaction.
- **Sealed error hierarchy** + compile-time exhaustive handling.
- **`ChatStateReducer`** + hybrid dual API: raw `Stream<AgUiEvent>` (power users) / `Stream<ChatState>` (application code).
- **`SessionStorage` adapter with three defaults:** InMemory, Hive, Secure.
- **Multi-client + multi-session** (non-singleton).
- **`ChangeNotifier` Flutter binding** + `MessageContentParser`.
- **Basic Material 3 + Cupertino widgets:** `MessageBubble`, `ChatInput`, `FollowUpList`.
- **`koel_devtools` fully production-grade** (per D-RUN-5): live event stream, time-travel replay, tool inspector, network panel, exportable traces. No "beta" markers in v1.0.0.
- **`koel_test`** (per D-RUN-6): real captured SSE fixtures (not synthesized), `MockAgent`, tool handler harness.
- **Both adapter packages:** `koel_agno` (direct POST to Agno/LangGraph backends) and `koel_langgraph` (LangGraph deployment endpoint adapter).
- **`koel` meta-package** re-exporting the common surface.
- **Production-ready quality bar** — not MVP/preview (per D-PRIOR-4: *"Có thể sử dụng được trong production."*).

### Package inventory (9 packages + meta)

| Package | Purpose |
|---|---|
| `koel_core` | Event types, message models, tool contracts, abstract agent base, interceptor framework, sealed error hierarchy, session storage interface |
| `koel_http` | `HttpAgent` with SSE parser, built-in interceptors (Auth, Retry, Logging, EventTrace, Sentry, PIIRedaction) |
| `koel_agno` | `AgnoAgent` for direct POST to Agno/LangGraph backends |
| `koel_runtime` | GraphQL bridge to CopilotKit Next.js runtime (`generateCopilotResponse` mutation) |
| `koel_langgraph` | LangGraph deployment endpoint adapter |
| `koel_flutter` | `KoelChatController`, `HiveSessionStorage`, `SecureSessionStorage`, `MessageContentParser` |
| `koel_widgets` | Material 3 + Cupertino UI components (`MessageBubble`, `ChatInput`, `FollowUpList`) |
| `koel_devtools` | Flutter DevTools extension: live event stream, time-travel replay, tool inspector, network panel, exportable traces |
| `koel_test` | Recorded SSE fixtures, `MockAgent`, tool handler test harness |

Plus a `koel` meta-package re-exporting the common surface.

## Out-of-scope / deferred

- **Protobuf binary encoding** (post-v1).
- **Generative UI / A2UI declarative rendering** — future `koel_a2ui` package; v1 = text + markdown code blocks only.
- **Tool-call confirmation middleware** — app owns tool-call safety via handler gating. koel deliberately does not police business rules.
- **Background isolate support** (v2).
- **Bloc / Riverpod / GetX direct bindings** — future `koel_bloc`, `koel_riverpod` packages. v1 ships only `ChangeNotifier` lowest-common-denominator binding and raw `Stream<ChatState>` escape hatch.
- **LangGraph interrupt-resume deep integration** — future `koel_langgraph_deep` package.

**Binding constraint (D-PRIOR-6, reinforced by D-RUN-2):** koel artifacts contain **zero references** to specific downstream consumer codebases, business domains, or app-layer policy. Example apps are generic chat scenarios — no TPS, no Vietnamese stock market, no securities domain. Domain integration is downstream consumer work, not koel's concern. This is binding across repo, packages, docs, examples, fixtures, **and planning artifacts including this PRD**.

## Success criteria

Per D-PRIOR-5 and D-RUN-4: **adoption metrics (pub.dev downloads, GitHub stars, contributor counts, production deployments) are explicitly NOT success criteria.** *"Hàng tốt thì user sẽ biết đến thôi."*

Three lenses (per D-RUN-4):

### Code-quality bar (v1 ship gates — testable, become PRD epic acceptance criteria)

- **`dart analyze` clean** across all 9 packages: zero warnings, zero infos, strict lint rules enforced (`package:lints/recommended.yaml` minimum, likely stricter).
- **Test coverage ≥ 90%** on `koel_core`, `koel_http`, `koel_flutter`; **≥ 80%** on adapter packages (`koel_agno`, `koel_langgraph`, `koel_runtime`). Coverage measured against meaningful behavior, not statement count.
- **Conformance fixture pass = 100%** of the ~24 AG-UI event types, including `THINKING_*`, `ACTIVITY_*`, `TOOL_CALL_CHUNK`. Fixtures captured from real wire traffic, not synthesized.
- **Public API stability:** zero breaking changes from `1.0.0` through the `1.x` cycle. Every export is a long-term contract.
- **No vestigial code in v1.0.0:** no commented-out blocks, no "just in case" parameters, no unused exports, no `TODO` markers in the published surface.

### Self-judgment bar (qualitative — not gates; calibrate pride)

- **The six-month re-read test:** open any class six months after v1.0.0 ships and feel that every line earns its place. No regret, no "what was I thinking."
- **The API reads as the author thinks about agent runtimes.** Mental model and surface aligned; a new user told "open `koel_core` and start with `AbstractAgent`" sees the path forward immediately.
- **DevTools debugging feels better than Bloc debugging.** Time-travel replay and tool inspector make agent debugging a thing the author looks forward to, not a chore.

### Learning bar (deliberate skill targets)

- **Protocol design intuition:** AG-UI event taxonomy mastered; sealed-type vs. open-extension tradeoffs internalized; backward-compat strategies for evolving protocols designed and validated.
- **Dart 3 advanced features:** sealed classes, pattern matching, records, exhaustive switching — used idiomatically, not performatively.
- **DevTools extension authoring:** end-to-end build of a Flutter DevTools extension, including time-travel state capture and exportable traces.
- **SSE parser internals:** low-level streaming protocol implementation — byte buffers, chunked frames, reconnect/backpressure — built from primitives, not glued from a library.
- **API design discipline across package boundaries:** nine-package monorepo with clean semver — what each export costs, what each abstraction earns.

## Constraints & assumptions

- **No deadline.** Passion-project tempo. v1 ships when v1 is v1, not on a calendar.
- **Brand = `koel`** (per D-PRIOR-1). Hindi for the singing cuckoo. Chosen explicitly over SEO-friendly names like `agui_*`. Marketing investment is acceptable cost for the right brand.
- **9-package monorepo architecture** (per D-PRIOR-2), decided in brainstorming.
- **Persona priority is strict:** P1 → P2 → P3 (per D-RUN-3). API tradeoffs resolve in P1's favor first.
- **Semver discipline:** every public export is a long-term contract; zero breaking changes through 1.x. Discriminated unions designed so unknown future events do not break exhaustive switching.
- **Dart 3 baseline assumed** (sealed classes, pattern matching, records used idiomatically).
- **Wire protocol assumptions:** SSE primary, GraphQL bridge to CopilotKit Next.js runtime via `generateCopilotResponse` mutation.
- **No business-domain leakage** (D-PRIOR-6, D-RUN-2): planning artifacts, repo, packages, docs, examples, and fixtures all stay generic.
- **`koel_devtools` and `koel_runtime` both production-grade at v1.0.0** — explicit scope risks accepted (D-RUN-5, D-RUN-7).

## Risks / open questions

The brief lists these as explicitly unresolved (PRD epics depending on them carry spike work as prerequisites):

- **OQ-Agno-Auth:** Does Agno's `/agno-chat` endpoint require independent authentication, or is it protected only by the CopilotKit runtime layer upstream? Spike required; affects `koel_agno` interceptor wiring.
- **OQ-Fixtures:** How to capture authoritative wire traffic for `koel_test` fixtures? Likely Charles/mitmproxy on AG-UI reference apps. Spike required. **`koel_test` v1 depends on this spike** (D-RUN-6).

Additional implicit risks the PRD should track:
- `koel_devtools` production-grade scope in v1 is acknowledged as scope risk (D-RUN-5).
- Both transports (`koel_http` + `koel_runtime`) production-grade at v1.0.0 doubles the conformance surface.

## PRD-relevant quotes (preserve tone/voice/qualitative ideas)

- *"Infra deep, business out. Modular by discipline, opinionated about cross-cutting craftsmanship, agnostic about everything else."* — Design DNA.
- *"The cost of the status quo is not catastrophe; it is friction."*
- *"koel is a passion project; the first reader of every public class is Si Huynh."*
- *"open the source in six months and every line still earns its place."* — six-month re-read test.
- *"koel is not faster than `ag_ui` because `ag_ui` is fast — it is faster because it is more complete. The 'unfair advantage' is willingness to spend craft time on infrastructure others skipped, not a technical trade secret."*
- *"DevTools debugging feels better than Bloc debugging."*
- *"Success is not 'everyone uses koel.' Success is that the people who use it use it because they understand why it was built the way it was — and recognize the craft."*
- *"Earned via API discipline, not dedicated extension hooks — the contract is the source."* — on P3 (contributor) enablement.
- *"Hàng tốt thì user sẽ biết đến thôi."* (D-PRIOR-5) — explicit rejection of adoption metrics as success.
- *"Có thể sử dụng được trong production."* (D-PRIOR-4) — v1 quality bar.
- *"No vestigial code: no 'just in case' parameters, no commented-out blocks, no comments restating code."* (from CLAUDE.md, reinforced by brief's no-vestigial-code ship gate).

## Gaps the brief leaves for the PRD to resolve

The brief is strong on **what** ships and **why it matters**; it leaves the PRD to specify **how it decomposes into work**:

1. **Epic decomposition & sequencing.** The brief lists 9 packages and a feature set but does not order them. PRD must decide: build core-first then radiate (likely `koel_core` → `koel_http` → `koel_flutter` → adapters → DevTools → test fixtures → widgets → meta), or some other shape. Spike sequencing for OQ-Fixtures and OQ-Agno-Auth must be slotted before dependent epics.
2. **Functional requirements (FR) granularity per package.** The brief enumerates capabilities; the PRD must turn each into testable FRs with acceptance criteria. Example: "interceptor framework" needs FRs for interceptor lifecycle, ordering semantics, error propagation, async behavior, cancellation.
3. **Non-functional requirements (NFRs) beyond the coverage/analyze gates.** Performance budgets (SSE parse throughput, event-to-state-reduce latency, memory ceiling on long sessions), backpressure semantics, reconnect/retry policy details, isolate-safety constraints, supported Dart/Flutter SDK version floor.
4. **Public API surface specification.** The brief names key types (`AbstractAgent`, `SessionStorage`, `ErrorClassifier`, `Interceptor`, `ChatStateReducer`, `KoelChatController`, `RunErrorEvent`, `UnknownAgUiEvent`) but does not specify their signatures. PRD or downstream spec must define the contract that becomes the long-term 1.x guarantee.
5. **Conformance fixture scope & capture pipeline.** OQ-Fixtures spike output must define which AG-UI reference apps to record against, fixture file format, replay harness shape, and how new event types get added to the fixture set without breaking existing tests.
6. **DevTools extension feature decomposition.** Live event stream, time-travel replay, tool inspector, network panel, exportable traces — each is an epic-sized chunk needing FRs (e.g., time-travel buffer size, replay semantics for tool calls with side effects, trace export format).
7. **Widget scope precision.** Brief lists `MessageBubble`, `ChatInput`, `FollowUpList` as "basic Material 3 + Cupertino" — PRD must define what "basic" excludes (theming surface, customization hooks, accessibility floor).
8. **Documentation & example-app deliverables.** Brief mentions "example apps that work end-to-end without surgery" for P2 but does not enumerate which examples ship in v1 or what platforms they target.
9. **Release & semver mechanics.** "Zero breaking changes from `1.0.0` through the `1.x` cycle" — PRD must specify the deprecation policy, pre-1.0 versioning during dev, and how additive changes flow through the 9-package version graph.
10. **CI/CD & quality-gate enforcement.** The code-quality bar is stated; PRD should define how gates are mechanically enforced (CI matrix, coverage tooling, analyzer config location, conformance test invocation).
