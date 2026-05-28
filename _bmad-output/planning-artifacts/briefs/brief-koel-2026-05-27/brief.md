---
title: "Product Brief — koel"
status: final
created: 2026-05-27
updated: 2026-05-27
purpose: Input for downstream PRD workflow
---

# Product Brief: koel

## Executive Summary

koel is a modular Dart/Flutter SDK that implements the AG-UI agent-UI protocol end-to-end — AG-UI SSE streaming and the CopilotKit GraphQL runtime — with the production infrastructure community packages omit: interceptor chain, sealed error hierarchy, DevTools extension, conformance fixtures. It ships as nine coordinated packages on pub.dev: deep on cross-cutting concerns (auth, retry, logging, state reduction, persistence), surgically out of business logic (tool-call safety, domain rules, UI policy).

## The Problem

The AG-UI agent-UI protocol — and the broader CopilotKit runtime ecosystem it speaks to — is well-served on the web (React, Next.js) but underserved on Flutter. The community `ag_ui` v0.1.0 Dart package on pub.dev is roughly eight months stale, missing newer event types (`THINKING_*`, `ACTIVITY_*`, `TOOL_CALL_CHUNK`), and ships without the production-grade infrastructure Flutter devs expect: no interceptor framework, no sealed error hierarchy, no DevTools support, no conformance fixtures, no observability tooling.

Flutter teams that want to integrate agents today face three bad choices:

1. Accept `ag_ui` 0.1.0's gaps and rewrite the missing infrastructure in every consumer codebase.
2. Embed a WebView around a JavaScript chat client — paying the performance cost, the bundle cost, and losing native state binding and debugging.
3. Build their own AG-UI client from the protocol spec — duplicating work that should belong in a single, well-maintained library.

The cost of the status quo is not catastrophe; it is friction. Each team rebuilds the same auth interceptor, the same retry loop, the same SSE parser, the same error mapping. The Flutter AG-UI ecosystem is held back not by missing capability but by missing foundation.

## The Solution

koel implements the full AG-UI event taxonomy (all ~24 event types including `THINKING_*`, `ACTIVITY_*`, `TOOL_CALL_CHUNK`) over both wire protocols — AG-UI SSE primary, CopilotKit GraphQL runtime as bridge — with a hybrid public API: power users consume raw `Stream<AgUiEvent>`; application code consumes a reduced `Stream<ChatState>` from a built-in `ChatStateReducer`. Sessions are first-class: multi-client, multi-session, swappable storage. Errors arrive as first-class events in the stream, mapped to Dart 3 sealed classes (`TransportError | ProtocolError | AgentError | BusinessError`) for compile-time exhaustive handling.

### Package Inventory

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

## What Makes This Different

The design DNA: *"Infra deep, business out. Modular by discipline, opinionated about cross-cutting craftsmanship, agnostic about everything else."*

- **Interceptor chain from v1.** Composable pipeline (dio-style) for auth, retry, logging, tracing, DevTools instrumentation. Any cross-cutting concern becomes a one-class addition, not a breaking change. Most AG-UI clients do not ship this.
- **Sealed error hierarchy + first-class error events.** `RunErrorEvent` arrives in the stream and is mapped to a Dart 3 sealed class hierarchy. The compiler enforces exhaustive handling at the app layer — no silently swallowed protocol errors.
- **Time-travel replay in DevTools.** The pattern from Redux/Bloc/Riverpod devtools, applied to agent streams: step backward through events, inspect tool calls, export traces. Rare in the SDK space.
- **Conformance test fixtures.** Real captured SSE traffic ships as structured test data; consumers (and koel itself) validate protocol behavior offline.
- **Discriminated unions for protocol evolution.** Event taxonomy is sealed; unknown future events surface as `UnknownAgUiEvent` for forward compatibility without breaking switch exhaustiveness on known types.
- **State-management agnostic.** `ChangeNotifier` is the lowest-common-denominator binding; raw `Stream<ChatState>` is the escape hatch. No assumption of Bloc, Riverpod, GetX, or Provider — consumers wire whatever they use.

Honest about what is not a moat: koel is not faster than `ag_ui` because `ag_ui` is fast — it is faster because it is more complete. The "unfair advantage" is willingness to spend craft time on infrastructure others skipped, not a technical trade secret.

## Who This Serves

koel is built in priority order: when API design tradeoffs surface, they resolve in P1's favor.

**P1 — The author, and the author six months later.** koel is a passion project; the first reader of every public class is Si Huynh. The success bar is "open the source in six months and every line still earns its place." This sets the tone: API surface matches the author's mental model of how agent runtimes should be shaped; DevTools time-travel is the marquee debugging affordance because it is what the author wants to use; the code reads like a maintained library because the maintainer is the audience.

**P2 — The Flutter dev integrating agents into a real app.** Mobile or desktop. Familiar with `dio`, `firebase_*`, `supabase_flutter`, and one of Bloc / Riverpod / Provider / `setState`. They are evaluating koel against three alternatives — accepting the community `ag_ui` 0.1.0 gaps, embedding a WebView, or rolling their own. Success for them: replace whichever fallback they are using inside one sprint, with sensible defaults and example apps that work end-to-end without surgery.

**P3 — The contributor or downstream library author.** Opens a PR against koel, builds `koel_riverpod` or `koel_bloc`, forks for an experimental adapter, or implements a new protocol surface. The 9-package modular shape, the public adapter interfaces (`AbstractAgent`, `SessionStorage`, `ErrorClassifier`, `Interceptor`), and the conformance test fixtures exist for them. Earned via API discipline, not dedicated extension hooks — the contract is the source.

## Success Criteria

koel is a passion project. Adoption metrics — pub.dev downloads, GitHub stars, contributor counts, production deployments — are explicitly **not** success criteria. Success is measured along three lenses.

### Code-quality bar (v1 ship gates)

These are the testable conditions for shipping v1. They flow directly into PRD epic acceptance criteria.

- **`dart analyze` clean** across all 9 packages: zero warnings, zero infos, strict lint rules enforced (`package:lints/recommended.yaml` minimum, likely stricter).
- **Test coverage ≥ 90%** on `koel_core`, `koel_http`, `koel_flutter`; ≥ 80% on adapter packages (`koel_agno`, `koel_langgraph`, `koel_runtime`). Coverage is measured against meaningful behavior, not statement count.
- **Conformance fixture pass = 100%** of the ~24 AG-UI event types, including `THINKING_*`, `ACTIVITY_*`, `TOOL_CALL_CHUNK`. Fixtures are captured from real wire traffic, not synthesized.
- **Public API stability:** zero breaking changes from `1.0.0` through the `1.x` cycle. Every export is a long-term contract.
- **No vestigial code in v1.0.0:** no commented-out blocks, no "just in case" parameters, no unused exports, no `TODO` markers in the published surface.

### Self-judgment bar (qualitative)

These are not gates; they are how the author calibrates pride in the work.

- **The six-month re-read test:** open any class six months after v1.0.0 ships and feel that every line earns its place. No regret, no "what was I thinking."
- **The API reads as the author thinks about agent runtimes.** Mental model and surface are aligned; a new user told "open `koel_core` and start with `AbstractAgent`" sees the path forward immediately.
- **DevTools debugging feels better than Bloc debugging.** Time-travel replay and tool inspector make agent debugging a thing the author looks forward to, not a chore.

### Learning bar

The build itself is the goal. These are the deliberate learning targets baked into the project.

- **Protocol design intuition:** AG-UI event taxonomy mastered; sealed-type vs. open-extension tradeoffs internalized; backward-compat strategies for evolving protocols designed and validated.
- **Dart 3 advanced features:** sealed classes, pattern matching, records, exhaustive switching — used idiomatically, not performatively.
- **DevTools extension authoring:** end-to-end build of a Flutter DevTools extension, including time-travel state capture and exportable traces.
- **SSE parser internals:** low-level streaming protocol implementation — byte buffers, chunked frames, reconnect/backpressure — built from primitives, not glued from a library.
- **API design discipline across package boundaries:** nine-package monorepo with clean semver — what each export costs, what each abstraction earns.

## Scope

**In for v1:**

- Both wire protocols: AG-UI SSE (primary) + CopilotKit GraphQL runtime bridge
- All ~24 AG-UI event types (including `THINKING_*`, `ACTIVITY_*`, `TOOL_CALL_CHUNK`)
- Interceptor framework + 6 built-in interceptors (Auth, Retry, Logging, EventTrace, Sentry [OFF by default], PIIRedaction)
- Sealed error hierarchy + compile-time exhaustive handling
- `ChatStateReducer` + hybrid `Stream<AgUiEvent>` / `Stream<ChatState>` dual API
- `SessionStorage` adapter with three defaults (InMemory, Hive, Secure)
- Multi-client + multi-session (non-singleton)
- `ChangeNotifier` Flutter binding + `MessageContentParser`
- Basic Material 3 + Cupertino widgets
- DevTools extension fully production-grade (live event stream, time-travel replay, tool inspector, network panel, exportable traces)
- Conformance fixtures from real captured wire traffic + `MockAgent` + tool handler harness
- Production-ready quality bar (not MVP/preview)

**Out of v1 (deferred):**

- Protobuf binary encoding (post-v1)
- Generative UI / A2UI declarative rendering (future `koel_a2ui` package; v1 = text + markdown code blocks)
- Tool-call confirmation middleware (app owns tool-call safety via handler gating)
- Background isolate support (v2)
- Bloc / Riverpod / GetX direct bindings (future `koel_bloc`, `koel_riverpod`)
- LangGraph interrupt-resume deep integration (future `koel_langgraph_deep`)

Note: koel artifacts contain zero references to specific downstream consumer codebases, business domains, or app-layer policy. Example apps are generic chat scenarios. Domain integration is downstream consumer work, not koel's concern.

## Open Questions

These are explicitly unresolved, not fabricated certainty. PRD epics depending on them carry spike work as prerequisites.

- **OQ-Agno-Auth:** Does Agno's `/agno-chat` endpoint require independent authentication, or is it protected only by the CopilotKit runtime layer upstream? Spike required; affects `koel_agno` interceptor wiring.
- **OQ-Fixtures:** How to capture authoritative wire traffic for `koel_test` fixtures? Likely Charles/mitmproxy on AG-UI reference apps. Spike required.

## Vision

In two to three years, koel is the package Flutter devs reach for when integrating any agent runtime — not because it markets best, but because the source reads cleanly, the DevTools experience makes agent debugging feel like state debugging, and the adapter strategy slots new protocols in without rewriting consumer code. The 9-package shape has grown: `koel_bloc`, `koel_riverpod`, `koel_a2ui` exist as community-maintained adapters or in-tree additions. The conformance fixtures are referenced by other AG-UI client implementations across languages as the canonical "does it actually conform" test suite. The DevTools extension has been the model others copy.

Success is not "everyone uses koel." Success is that the people who use it use it because they understand why it was built the way it was — and recognize the craft.
