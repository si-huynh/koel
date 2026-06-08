---
title: koel — Flutter/Dart SDK for AG-UI Protocol (v1 PRD)
status: final
created: 2026-05-27
updated: 2026-05-28
project: koel
author: Si Huynh
---

# koel v1 — Product Requirements Document

## 1. Vision

**koel is the best AG-UI protocol SDK on Flutter.** An open-source, multi-package Dart implementation of the AG-UI agent-UI protocol — built with the rigor of a framework, not the velocity of a shim. Within thirty minutes of reading the public API, a Flutter developer landing on `koel_core` should feel: *this was built by someone who reads framework source, not docs.*

koel is a passion-driven project. Adoption metrics — downloads, stars, contributors, production usage — are not success criteria. Success is craftsmanship and the personal learning produced by building it correctly. Slow path to v1 is the chosen path; v1 ships production-ready, not as an MVP, and rejects scope cuts that would weaken that bar.

> Design DNA: *"Infra deep, business out. Modular by discipline, opinionated about cross-cutting craftsmanship, agnostic about everything else."*

## 2. Problem & Opportunity

AG-UI is CopilotKit's open protocol for streaming agent runs between a frontend and an agent backend (LangGraph, agno, custom). It defines ~28 SSE event types covering text streaming, tool calls, JSON-Patch state sync, reasoning blobs, and lifecycle. The TypeScript reference implementation is mature. Flutter has only `ag_ui` 0.1.0 on pub.dev — single-package, eight months stale, missing reasoning/activity events, no widgets, no devtools, no conformance suite. The slot is wide open.

**The opportunity is not market share.** It is the existence of a Flutter SDK that future developers can point to as a reference for what "well-built" looks like in this domain — sealed errors, interceptor chains, time-travel devtools, multi-source conformance fixtures, semver-disciplined 1.x.

## 3. Audience

Three personas, ordered by binding priority. API tradeoffs resolve in P1's favor first.

- **P1 — Self, today and six months from now (Si Huynh).** Primary user; consumes koel from a downstream app. Every API choice is gated by two questions: "do I want to use this *today*?" and "would I still understand and respect this choice when I open the codebase cold six months from now?" The six-month re-read test is the discipline that prevents clever-but-fragile design. P1's app lives outside the koel repo; nothing about that app appears in koel.
- **P2 — Flutter app developer.** Third-party consumer building agent-UI features. Indie or enterprise. Wants a premium developer experience: discoverable API surface, no magic, clear error messages, real examples, working devtools, semver-stable contracts.
- **P3 — OSS contributor.** Cares about test fixtures, modular boundaries, conformance, contribution clarity. Gets API discipline and an inspectable codebase — not dedicated hooks or affordances.

P2 and P3 are served by serving P1 well first. No user-journey section: koel is a technical SDK; the user is a developer reading docs and writing code against APIs.

## 4. Goals & Non-Goals

### Goals

- **G1.** Implement the full AG-UI protocol — all ~28 event types, primary SSE-over-HTTP transport plus the CopilotKit-Next.js-runtime backend bridge, with conformance verified against captured fixtures from four backends (dojo + agno + langgraph + CopilotKit Next.js runtime).
- **G2.** Ship a 10-package monorepo with single-responsibility boundaries. Every public export is a long-term 1.x contract.
- **G3.** Make the API one-way-door safe — design surfaces users *cannot* misuse, not surfaces they *should* use carefully.
- **G4.** Ship cross-cutting infrastructure (interceptors, sealed errors, devtools, session storage adapter, reducer) at v1, not as a v2 aspiration.
- **G5.** Stay state-management agnostic — work with Bloc, Riverpod, GetX, Provider, plain `setState`. The Flutter glue is one `ChangeNotifier` subclass; per-framework adapters defer to the community.

### Non-Goals

- **NG1.** Adoption metrics. We do not optimize for downloads, stars, pub.dev score, or contributor count.
- **NG2.** SEO-friendly naming. We chose `koel` over `agui_*` deliberately.
- **NG3.** A reference for any specific downstream consumer codebase. koel-facing artifacts contain zero references to any business domain.
- **NG4.** Protobuf binary transport in v1. AG-UI's `@ag-ui/proto` exists but is underdocumented. Deferred to v1.5 / v2 (Spike C — Protobuf codegen path is open).
- **NG5.** A2UI / first-class generative UI as a dedicated package (`koel_a2ui`). v1 ships generative UI as a `WidgetResolver` pattern riding on `TOOL_CALL_*` per the AG-UI convention.
- **NG6.** Tool-call confirmation middleware, isolate-backed long tools, deep LangGraph interrupt-resume. All deferred to v2.
- **NG7.** Direct state-management bindings (`koel_bloc`, `koel_riverpod`, `koel_getx`). Deferred to community contributions post-v1.
- **NG8.** Wrapping or migrating the existing community `ag_ui` 0.1.0 package. koel is a clean-slate rewrite. One-line credit in README; zero migration obligation.

## 5. Success Criteria

Success operates on three lenses. Only the code-quality bar is a v1 ship gate. The other two shape day-to-day decisions but do not block release.

### 5.1 Code-quality bar (ship gate — all must hold)

- **SC-1. 100% AG-UI protocol conformance.** Anchored to AG-UI release `release/2026-05-26` (specific commit SHA pinned in `koel_core/CONFORMANCE.md` at v1.0.0 publish). Round-trip equivalence: `wire_bytes → AgUiEvent → canonical_wire_bytes → AgUiEvent_equal`, where `AgUiEvent_equal` is the structural equality generated by `freezed`. Every spec event type maps to ≥ 1 captured fixture per emitting backend (dojo + agno + langgraph + CopilotKit Next.js runtime); event types no backend currently emits use hand-synthesized fixtures with a `synthesized: true` marker in the metadata header.
- **SC-2. Coverage tiers.** Foundation packages — `koel_core`, `koel_http`, `koel_flutter`, `koel_lints` — ≥ 90% line + branch coverage. Adapter and tooling packages — `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_widgets`, `koel_devtools`, `koel_test` — ≥ 80%. Measurement methodology: `package:coverage` aggregated via Melos; generated files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`) excluded; per-PR patch-coverage ≥ 85% enforced by CI.
- **SC-3.** `dart analyze` zero warnings across every package, default lint set + `package:lints/recommended.yaml` overrides + `package:koel_lints/koel.yaml` mandatory rules (see §11 / F-A12).
- **SC-4.** Zero breaking changes to the 1.x public surface after v1.0.0 publish. Hybrid versioning (§12) constrains how packages evolve. Sealed-union additions remain minor bumps only because `koel_lints` enforces consumer-side default branches (see §11).
- **SC-5.** No vestigial code. No `TODO`, no commented-out blocks, no "just in case" parameters, no exports that no example uses. A CI script diffs `package:koel_*` public symbols against `/example` usage and the dartdoc cross-reference graph.

### 5.2 Self-judgment (value, not gate)

- The API feels right when P1 uses it in a downstream app. If it doesn't, we redesign — even after publish.

### 5.3 Learning (value, not gate)

- The build itself produces compounding insight into Flutter framework internals, Dart language design choices, OSS package craft, and protocol implementation patterns.

### 5.4 Explicit non-criteria

- Adoption (downloads, GitHub stars, contributors, production deployments, pub.dev score) is not evaluated. Zero adoption is a valid outcome and not a failure.

## 6. Scope

### 6.1 In-scope for v1

- All 10 packages publishable to pub.dev: `koel_core`, `koel_http`, `koel_lints`, `koel_agno`, `koel_langgraph`, `koel_runtime`, `koel_flutter`, `koel_widgets`, `koel_devtools`, `koel_test`, plus the `koel` meta-package.
- SSE-over-HTTP (`koel_http`) is the **primary** protocol transport. `koel_runtime` is a second-class backend bridge for consumers whose backend is the CopilotKit Next.js runtime (which speaks streaming GraphQL rather than direct AG-UI SSE). Both ship production-grade in v1.
- All three backend bridges production-grade: `koel_agno`, `koel_langgraph`, `koel_runtime`.
- Sealed Dart 3 error hierarchy with `UnknownAgUiEvent` forward-compat fallback and `KoelErrorCode` typed-vocabulary enum.
- Interceptor chain at v1 — built-in `Logging`, `EventTrace`, `Retry`, `Auth`, `Sentry` (default-OFF), `PIIRedaction` (default-OFF).
- Session storage adapter — `InMemory` in `koel_core`, `Hive` + `Secure` in `koel_flutter`.
- `KoelChatController extends ChangeNotifier` as the LCD Flutter binding.
- DevTools extension at v1 — live event stream, time-travel replay, tool-call inspector, network panel, JSON Lines trace export.
- `koel_test` v1 — captured fixtures from four backends (AG-UI dojo, agno, langgraph, CopilotKit Next.js runtime) covering the full event taxonomy; `MockAgent`; tool-handler test harness; `ConformanceRunner`.
- `koel_lints` v1 — mandatory analyzer rules (e.g., `exhaustive_switch_must_have_default`) that make sealed-union evolution semver-minor-safe. See §11 / F-A12.
- Sample app demonstrating the quickstart path via the `koel` meta-package (generic chat scenarios only).
- Docs site (framework TBD — see OQ-Docs-Framework) + `dart doc` reference + README quality bar.

v1 ships production-ready, not as an MVP. Scope cuts that would weaken the production-ready bar (dropping devtools, dropping fixtures, dropping `koel_lints`) are off the table.

### 6.2 Out-of-scope for v1 (see Non-Goals for full rationale)

Protobuf transport · `koel_a2ui` first-class generative UI package · tool-call confirmation middleware · isolate-backed long tools · LangGraph deep interrupt-resume · direct state-management bindings · migration tooling from `ag_ui` 0.1.0.

## 7. Architecture overview

Ten focused packages, hard responsibility boundaries. Foundations (`koel_core` + `koel_http` + `koel_lints`) release lock-step; backend bridges and Flutter packages version independently against ranged dependencies on the foundations.

| Package | Layer | Owns | Depends on |
|---|---|---|---|
| `koel_core` | Foundation (lock-step) | Event/Message/Tool/Context types · `AbstractAgent` · interceptor framework · `SessionStorage` interface + `InMemorySessionStorage` · `ChatStateReducer` · sealed `KoelError` + `KoelErrorCode` enum + `ErrorClassifier` · `UnknownAgUiEvent` · `ToolDefinition` · `StateConflict` hook · no HTTP. | — |
| `koel_http` | Foundation (lock-step) | `HttpAgent` · SSE parser · built-in interceptors (Auth, Retry, Logging, EventTrace, Sentry, PIIRedaction) · cancellation propagation · chunk synthesis. | `koel_core` |
| `koel_lints` | Foundation (lock-step) | Mandatory analyzer rules that make sealed-union evolution semver-minor-safe — most importantly `exhaustive_switch_must_have_default` on `AgUiEvent`. Distributed as `package:koel_lints` with a `koel.yaml` analyzer profile. | — |
| `koel_agno` | Backend bridge | `AgnoAgent` → `POST ${baseURL}/agno-chat` · Agno message conversion · default-ON `AgnoAuthInterceptor` · agno conformance fixtures. | `koel_core`, `koel_http` |
| `koel_langgraph` | Backend bridge | LangGraph deployment URL · `LangGraphAgent` · surface-level interrupt-resume (POST resume value + reopen SSE) · langgraph conformance fixtures. | `koel_core`, `koel_http` |
| `koel_runtime` | Backend bridge | GraphQL bridge to the CopilotKit Next.js runtime · `generateCopilotResponse` streaming client · AG-UI ↔ GraphQL translation · CopilotKit-runtime conformance fixtures. | `koel_core` |
| `koel_flutter` | Flutter glue | `KoelChatController extends ChangeNotifier` · `HiveSessionStorage` · `SecureSessionStorage` · `MessageContentParser` · `KoelClientScope` (`InheritedWidget`) · `WidgetResolver`. | `koel_core`, `koel_http` |
| `koel_widgets` | UI primitives | `MessageBubble` (M3 + Cupertino) · `ChatInput` · `FollowUpList` · theming hooks · generative UI host widgets. | `koel_flutter` |
| `koel_devtools` | Tooling | Flutter DevTools extension — live event stream, time-travel replay, tool-call inspector, network panel, JSON Lines trace export. | `koel_core`, `koel_flutter` |
| `koel_test` | Testing | Recorded fixtures from four backends (dojo + agno + langgraph + CopilotKit Next.js runtime) · `MockAgent` · tool-handler test harness · `ConformanceRunner`. | `koel_core` |
| `koel` (meta) | Convenience | Re-exports `koel_core` + `koel_http` + `koel_flutter` for the quickstart path. Does not re-export `koel_lints` (consumed via analyzer config). | the above |

Implementation-level architecture decisions (Melos, pipeline stages, `AgentSubscriber`, JSON Patch library, …) live in `addendum.md`.

## 8. Features

Features are grouped by domain. Each has a stable globally-unique ID (`F-{group}-{n}`) that survives renumbering. Brainstorming idea provenance appears in parens where applicable.

### Group A — Protocol Foundation (`koel_core`)

- **F-A1. Two-Method Atomic Client** *(idea #1)* — The irreducible kernel of the client surface is `AbstractAgent.run(RunAgentInput) → Stream<AgUiEvent>` plus stream-cancellation semantics. Every additional capability is a decorator on these two operations, never a replacement.
- **F-A2. Three-Layer Public API** *(idea #2)* — Public surface stratified into: (1) `KoelClient` — configuration, auth, lifecycle; (2) `ChatSession` — the ergonomic 80% path with message-list state, send/cancel, persistence; (3) raw `client.run(RunAgentInput)` — power-user access to the unprocessed event stream.
- **F-A3. Hybrid Event Stream + Opt-In Reducer** *(idea #3)* — Consumers subscribe to the canonical low-level `Stream<AgUiEvent>` directly, or opt in to a pure-function `ChatStateReducer` that produces a `Stream<ChatState>` from the same source. The reducer is composable and replaceable.
- **F-A4. Interceptor Chain** *(idea #4)* — dio-style composable `Interceptor` pipeline registered on `KoelClient`. Each interceptor wraps `Future<Stream<AgUiEvent>>` execution. Any cross-cutting concern (auth, retry, logging, telemetry) becomes a one-class addition. Ordering is explicit.
- **F-A5. Sealed Error Hierarchy via `RunErrorEvent`** *(idea #12)* — Dart 3 `sealed class KoelError` with subtypes `TransportError | ProtocolError | AgentError | BusinessError`. Sealed enables compile-time exhaustive `switch` in consumer code. Errors surface through the protocol's own `RUN_ERROR` event, so error flow rides the event stream — not a separate channel.
- **F-A6. `UnknownAgUiEvent` Forward-Compat Fallback** *(idea #19)* — Any event type the current `koel_core` does not recognize deserializes into `UnknownAgUiEvent(rawJson: …, type: String)`. Consumers ignore, log, or pattern-match; koel does not crash. Required by AG-UI's no-version-negotiation reality.
- **F-A7. Full AG-UI Event Coverage.** All ~28 event types from the AG-UI spec (release/2026-05-26 baseline): `RUN_*`, `STEP_*`, `TEXT_MESSAGE_*` (incl. CHUNK), `TOOL_CALL_*` (START / ARGS / END / RESULT / CHUNK), `STATE_SNAPSHOT`, `STATE_DELTA`, `MESSAGES_SNAPSHOT`, `ACTIVITY_*`, `REASONING_*` (incl. `REASONING_ENCRYPTED_VALUE`), `RAW`, `CUSTOM`. Each typed via a `freezed` sealed union. The legacy `THINKING_*` family from earlier drafts is deprecated in `release/2026-05-26`; koel ships only the `REASONING_*` names and maintains no `THINKING_*` alias.
- **F-A8. JSON-Patch State Sync (RFC 6902, Last-Writer-Wins).** `STATE_DELTA` events carry RFC 6902 patches; `koel_core` applies them strict-mode via a vendor-inline RFC 6902 implementation under `koel_core/lib/src/json_patch/` (see Addendum B.3 for the rationale). No CRDT, no merge resolution. Concurrent mutation is the consumer's problem; a `StateConflict` hook is exposed for consumers who care.
- **F-A9. Reasoning `encryptedValue` Opaque Round-Trip.** `REASONING_ENCRYPTED_VALUE` and `encryptedValue` fields ride verbatim as opaque `String`/`Uint8List`, never inspected or modified, and echo back on subsequent runs to satisfy provider replay requirements (Anthropic, OpenAI).
- **F-A10. AgentSubscriber Callback Bag.** A passive observation pattern lifted from CopilotKit: consumers register `AgentSubscriber` instances that receive granular callbacks (`onRunStart`, `onToolCall`, `onStateDelta`, `onError`, …) without touching the main event stream. Used by devtools, analytics, custom telemetry. Multiple subscribers compose.
- **F-A11. 4-Stage Event Pipeline.** Before events reach consumers, they pass through pure-function stages in order: **chunks** (synthesize `START` / `CONTENT` / `END` events from `CHUNK` shorthand so the rest of the pipeline only sees the long form) → **verify** (structural and cross-event sanity — every `TOOL_CALL_END` must have a matching `TOOL_CALL_START` with the same id; `STATE_DELTA` must contain valid RFC 6902 ops) → **apply** (fold the event into `ChatState` via the registered reducer, if any) → **transform** (consumer-supplied `StreamTransformer<AgUiEvent, AgUiEvent>` instances). Wire-format sanity (the JSON shape of the raw event itself) lives inside the SSE parser in `koel_http`, not in this pipeline; the pipeline operates only on already-typed `AgUiEvent` instances. Malformed agents fail at the boundary.
- **F-A12. `koel_lints` Mandatory Rules.** A foundation package shipping analyzer rules that make sealed-union evolution semver-minor-safe. The principal rule, `exhaustive_switch_must_have_default`, fires on any `switch` whose subject is `AgUiEvent`, `KoelError`, or `MessageSegment`. Consumers add one line to `analysis_options.yaml` (`include: package:koel_lints/koel.yaml`) and gain protection from future minor-bump sealed-subtype additions, because every `switch` they write must include `default:` (or the linter complains). Without `koel_lints`, consumers writing exhaustive switches hit compile errors on koel minor upgrades; this trade-off is documented in `koel_lints/README.md` and `koel`'s migration guide. See §11 for the formal forward-compat policy.

  > _Erratum (SCP-2026-05-29): `koel_lints` is built on `analysis_server_plugin`, not `custom_lint`. The "one line `include: package:koel_lints/koel.yaml`" enablement above is the `custom_lint` mechanism; under asp the rule is enabled via `plugins:` + `diagnostics:` at the analysis root. The **intent** (a mandatory rule making sealed-union evolution semver-minor-safe) is unchanged and tool-agnostic; the exact external-consumer enablement wording is reconciled in Story 9-7 after the Epic-9 distribution verification (Story 9-5)._

### Group B — HTTP Transport (`koel_http`)

- **F-B1. `HttpAgent` with SSE Parser.** Production-grade SSE consumer over `package:http`. Streaming JSON-per-event parsed into typed `AgUiEvent` objects, surfaced as a back-pressured `Stream`.
- **F-B2. Built-in Interceptors.** Six interceptors ship in `koel_http`: `LoggingInterceptor`, `EventTraceInterceptor`, `RetryInterceptor` (exponential backoff, jitter, configurable max attempts), `AuthInterceptor` (Bearer + custom headers), `SentryBreadcrumbInterceptor` (default-OFF), `PIIRedactionInterceptor` (default-OFF, regex + JSONPath configurable).
- **F-B3. Cancellation Propagation.** `StreamSubscription.cancel()` on the event stream propagates to an HTTP-level abort that closes the underlying TCP connection — AG-UI's only cancellation mechanism. Verified against both `package:http`'s default client and the `dart:io` client. If the underlying client does not honor abort, koel falls back to a silent drop with one debug-level warning per process. `[ASSUMPTION]`
- **F-B4. Reconnect & Backoff Policy.** Mid-stream connection loss triggers exponential backoff (default 1s → 30s, ±20% jitter, max 5 attempts, all configurable per `KoelClient`). On reconnect, the stream emits a `ConnectionResumed` `MetaEvent` so consumers can render UI accordingly.
- **F-B5. Chunk Synthesis.** AG-UI optionally allows `TOOL_CALL_CHUNK` shorthand (combined start+content+end). `HttpAgent` synthesizes the three canonical events from chunks by default (toggleable per-client). Halves wire weight without burdening backend implementers. `[ASSUMPTION]`
- **F-B6. Connection Lifecycle Hooks.** `onConnect`, `onDisconnect`, `onReconnectAttempt` callbacks on `HttpAgent` for consumers needing transport-level visibility. Used internally by `koel_devtools`.

### Group C — Backend Adapters

- **F-C1. `koel_agno` — `AgnoAgent`.** POST endpoint `${baseURL}/agno-chat`. Translates agno's chat message shape to `RunAgentInput.messages`. Ships default-ON `AgnoAuthInterceptor` — consumers pass `AgnoAgent(baseURL: …, token: …)` and a Bearer header attaches on every request. Token field is optional (set to `null` to disable for open dev deployments). Conformance fixtures captured live from a real agno backend.
- **F-C2. `koel_langgraph` — `LangGraphAgent`.** Targets a LangGraph deployment URL. Maps AG-UI events to/from LangGraph's protocol. Interrupt-resume is implemented at the surface level — the consumer POSTs a `resumeValue` to the deployment and koel reopens the SSE stream against the same `threadId` / `runId`. There is no stateful sub-tree resumption from the client; LangGraph reconstructs state server-side. Deep interrupt semantics (client-driven graph traversal) defer to v2. Conformance fixtures captured against a real LangGraph deployment.
- **F-C3. `koel_runtime` — GraphQL Bridge.** Adapter for consumers whose backend is the CopilotKit Next.js runtime, which speaks GraphQL rather than direct AG-UI SSE. Implements the `generateCopilotResponse` streaming client and translates between GraphQL response shapes and AG-UI events. Independent of `koel_http`; uses `package:graphql` or equivalent.

### Group D — State, Session & Flutter Glue

- **F-D1. `SessionStorage` Adapter + Partial Persistence** *(idea #10)* — `abstract class SessionStorage` defines `save(threadId, ChatState)` / `load(threadId)` / `delete(threadId)`. Three implementations ship: `InMemorySessionStorage` (in `koel_core`), `HiveSessionStorage`, `SecureSessionStorage` (both in `koel_flutter`). Partial in-progress messages persist with `isComplete: false` so a reopened session shows interrupted output as such.
- **F-D2. `ChatStateReducer`.** Pure function `(ChatState, AgUiEvent) → ChatState`. Reduces the event stream into a renderable state shape (`messages`, `pendingMessage`, `pendingToolCalls`, `state`, `error`). Replaceable via `KoelClient.reducer = MyReducer()`. Composable via `ComposedReducer([base, custom])`.
- **F-D3. Multi-Session Multi-Client** *(idea #16)* — `KoelClient` is non-singleton. One app may instantiate multiple clients (e.g., different agents) and multiple `ChatSession` instances per client. No global state. Each session has its own `threadId`, `runId`, reducer, storage binding.
- **F-D4. `KoelChatController extends ChangeNotifier`** *(idea #14)* — The lowest-common-denominator Flutter binding. Wraps a `ChatSession`; exposes synchronous reads of `ChatState` and calls `notifyListeners()` on every state change. Works unmodified with Bloc (`BlocProvider.value`), Riverpod (`ChangeNotifierProvider`), GetX (`Get.put`), Provider (`ChangeNotifierProvider`), and plain `setState` (via `AnimatedBuilder`). Per-state-management adapter packages defer to community contributions; the controller's API is the integration contract they must respect.
- **F-D5. `KoelClientScope` `InheritedWidget`.** A Flutter widget that publishes a `KoelClient` instance down the tree. `KoelClientScope.of(context)` for descendant widgets. No magic, no service locator, no `get_it` dependency.

### Group E — Message Content & Generative UI

- **F-E1. `MessageContentParser`** *(idea #11)* — Parses an assistant message string into `List<MessageSegment>` where each segment is `TextSegment` or `CodeBlockSegment(language: String, code: String)`. Markdown-fenced code blocks split out. Image embeds and rich content defer to A2UI (v2).
- **F-E2. `WidgetResolver` (Generative UI v1).** AG-UI's generative-UI convention rides on `TOOL_CALL_*` events — the agent invokes a "render X" tool, the frontend treats it as a render directive. `koel_flutter` ships `WidgetResolver`: `Map<String, Widget Function(BuildContext, ToolCallEvent)>` resolves a tool name to a `Widget`. Unresolved tool names render via a fallback `UnknownGenerativeUI` placeholder (consumer-overridable). `[ASSUMPTION]` — exact signature pending review; intent locked.
- **F-E3. Widget Primitives** *(idea — implicit)* — `koel_widgets` ships `MessageBubble` (Material 3 + Cupertino variants), `ChatInput` (auto-grow text field with attachment slot), `FollowUpList` (suggested-prompts row). Themed via the package's theming hooks; opt-in, not required.
- **F-E4. Theming Hooks.** `KoelTheme` extends `ThemeExtension<KoelTheme>`. Consumers attach it to their `MaterialApp`/`CupertinoApp` theme. Every `koel_widgets` widget reads `Theme.of(context).extension<KoelTheme>()`.

### Group F — Observability & DevTools (`koel_devtools`)

- **F-F1. Flutter DevTools Extension** *(idea #13)* — Ships as a DevTools extension package, discovered automatically when `koel_devtools` appears in pubspec. Tabs: Stream · History · Inspector · Network · Export.
- **F-F2. Live Event Stream View.** Real-time tail of all `AgUiEvent`s flowing through `KoelClient`. Filter by event type, search by text, jump-to-event.
- **F-F3. Time-Travel Replay.** Bounded ring buffer (default 1000 events, configurable per `KoelClient.devtoolsBufferSize`) of recent events. Step backwards/forwards in dev mode to inspect state at any point. `[ASSUMPTION]` — buffer default 1000 events.
- **F-F4. Tool-Call Inspector.** Tree view of all tool calls in the current session: name, args (pretty JSON), result, latency, error. Drill-down per call.
- **F-F5. Network Panel.** HTTP-level inspector for the underlying SSE connection — request headers, response headers, connection lifecycle, retries.
- **F-F6. JSON Lines Trace Export.** Exports the current session's event log as JSON Lines (one event per line, with a `_session` header containing `threadId`, `runId`, timestamps, koel version, adapter version). Re-importable into the extension for offline inspection. `[ASSUMPTION]` — format detail.
- **F-F7. Replay Safety Semantics.** Time-travel replay re-applies events through the reducer; it does not re-execute tool handlers. A `ToolReplayContext` flag (`replayed: true`) passes to any handler that registers a replay observer, so handlers with side effects can no-op during replay. `[ASSUMPTION]`.

### Group G — Testing & Conformance (`koel_test`)

- **F-G1. Captured Fixtures from Four Backends.** Real protocol traces captured live from four reference backends — AG-UI dojo (`integrations/server-starter-all-features`), agno, langgraph, and the CopilotKit Next.js runtime — covering every AG-UI event type and key flows (text-only run, run with tool call, run with state delta, run with reasoning incl. `encryptedValue` round-trip, error path, cancellation). Stored as JSON Lines with metadata header (see F-F6). Event types no backend emits today use hand-synthesized fixtures with `synthesized: true` in the metadata header. Updated when AG-UI spec releases.
- **F-G2. `MockAgent`.** `MockAgent.fromFixture(name)` returns an `AbstractAgent` that replays the named fixture — deterministic widget and integration tests in consumer apps and in koel's own test suite.
- **F-G3. Tool-Handler Test Harness.** Utilities to register tool handlers under test, drive them through a `MockAgent` flow, assert on tool args / responses / replay behavior. Reduces test boilerplate to ~5 lines per case.
- **F-G4. Conformance Test Suite.** Runner that takes any `AbstractAgent` implementation and asserts it correctly handles every event type from the fixtures. Used internally to verify `koel_agno`, `koel_langgraph`, `koel_runtime` parity. Publicly runnable so community adapter authors can verify their work.

### Group H — Distribution & Versioning

- **F-H1. 10-Package Melos Monorepo** *(idea #6, extended)* — Single git repo, Melos-managed, each package independently publishable. Shared dev dependencies, lints (via `koel_lints`), CI. `CONTRIBUTING.md` documents the monorepo workflow.
- **F-H2. Hybrid Versioning** *(idea #15, extended)* — `koel_core` + `koel_http` + `koel_lints` release lock-step (same semver number, released together). Backend bridges (`koel_agno`, `koel_langgraph`, `koel_runtime`) and Flutter packages declare `^X.Y.0` ranged dependencies on foundations so foundation patch/minor bumps don't cascade-force a backend-bridge republish. Backend bridges version independently against each other. Foundation minor bumps that add sealed subtypes are safe under this scheme only because consumers respect the `koel_lints` mandatory default-branch rule (see F-A12 + §11); without it, a consumer's exhaustive switch becomes a compile error on a koel minor upgrade.
- **F-H3. `koel` Meta-Package.** Re-exports `koel_core` + `koel_http` + `koel_flutter`. The quickstart path: `dart pub add koel` produces a working SDK for the 80% case.
- **F-H4. Brand & Naming** *(ideas #7, #8, #9)* — Brand: `koel` (Hindi for the singing cuckoo). All nine `koel_*` slots reserved on pub.dev pre-publish. No `agui_*` / `copilotkit_*` piggyback. One-line credit in `koel_core` README to the community `ag_ui` 0.1.0 package as the genre's first attempt.
- **F-H5. MIT License.** All ten packages MIT-licensed. Matches AG-UI (MIT), CopilotKit (MIT), and Dart/Flutter ecosystem norm. License file in every package root.
- **F-H6. Docs Toolchain.** `dart doc` produces API reference for the pub.dev "API" tab. A dedicated docs site (framework deferred — see OQ-Docs-Framework) hosts guides, concept docs, tutorials, migration notes, and adapter cookbooks. Every package README follows the [koel README quality bar](#13-documentation-policy).

### Group I — Cross-Cutting Hygiene

- **F-I1. CI/CD Across 9 Packages.** GitHub Actions matrix: every PR runs `dart analyze`, `dart test`, coverage threshold check, conformance runner, `dart pub publish --dry-run` on every package. Per-package coverage gates enforced.
- **F-I2. Default-OFF Telemetry.** `SentryBreadcrumbInterceptor` ships in `koel_http` but is not registered by default. Same for `PIIRedactionInterceptor`. Consumers opt in explicitly. No silent telemetry, ever.
- **F-I3. Trademark & License Hygiene.** Trademark check on "koel" beyond pub.dev pre-publish (tracked as OQ-Koel-Trademark). License-compatibility review of `ag_ui` 0.1.0 (MIT verification before crediting; tracked as OQ-AGUI-License).

## 9. Public API Surface — the long-term 1.x contract

The signatures below are the principal exports each package commits to from v1.0.0 forward. Every public name listed here is a one-way door: addition is allowed in 1.x minor releases; modification requires 2.0.0. Full type-level signatures, error tables, and method-level semantics live in `addendum.md` §A.

### `koel_core`

- `class KoelClient` — top-level configuration object; non-singleton. Provides `newSession(...)` and the raw escape hatch `runRaw(RunAgentInput)`.
- `interface class AbstractAgent` — SPI for backend bridges only (not for direct consumer use). Single method: `Stream<AgUiEvent> run(RunAgentInput input)`. The `interface class` marker prevents accidental instance construction; consumers reach for `KoelClient` instead.
- `sealed class AgUiEvent` with ~28 concrete subtypes (one per AG-UI event type) plus `UnknownAgUiEvent`. Consumer code switching on it must include `default:` (enforced by `koel_lints`).
- `class RunAgentInput` — `threadId`, `runId`, `state`, `messages`, `tools`, `context`, `forwardedProps`, `reasoningEcho` (round-tripped from prior runs).
- `class ChatSession` — three-layer middle: send, cancel, current state, history.
- `class ChatState` — immutable (built with `freezed`): `messages`, `pendingMessage`, `pendingToolCalls`, `state` (JSON), `reasoningEcho` (Map<String, Uint8List>?), `error`, `phase`. All collections are unmodifiable views; mutation requires `copyWith`.
- `abstract class ChatStateReducer` with `ChatState reduce(ChatState s, AgUiEvent e)`.
- `class ComposedReducer` — composes multiple reducers in order.
- `abstract class Interceptor` with `Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input)`.
- `class InterceptorChain` — `proceed(input)`.
- `sealed class KoelError implements Exception` — `TransportError | ProtocolError | AgentError | BusinessError`. Adapters never throw `KoelError`; they emit `RunErrorEvent` carrying it. The `Exception` marker exists only so `Future.catchError` can intercept programmer-error paths (e.g. invalid argument to `KoelClient(...)`).
- `enum KoelErrorCode` — typed vocabulary for `KoelError.code`: `transportTimeout`, `transportClosed`, `protocolUnknownEvent`, `protocolMalformed`, `agentRefused`, `agentToolFailed`, `businessQuotaExceeded`, `businessRateLimited`, `businessAuth`, etc. Extensible via subclass for adapter-specific codes; non-exhaustive in consumer code.
- `abstract class ErrorClassifier` — `KoelError classify(Object raw, RunAgentInput input)`. The default implementation maps common HTTP/network/JSON failures to `KoelErrorCode` values; consumers install a custom classifier on `KoelClient` to handle backend-specific error shapes.
- `abstract class SessionStorage` — `save`, `load`, `delete`, `listThreads`.
- `class InMemorySessionStorage implements SessionStorage`.
- `class StateConflict` — passed to a consumer-supplied `StateConflictResolver` when a `STATE_DELTA` arrives whose patches reference paths the local state has mutated since the last `STATE_SNAPSHOT`. Default policy is last-writer-wins (apply the delta verbatim); consumers install a custom resolver for app-specific reconciliation.
- `class ToolDefinition` — name, description, parameter schema. v1 ships parameter schemas as `Map<String, dynamic>` JSON Schema (OQ-Tool-Param-DSL tracks the typed-DSL alternative for v1.x).
- `abstract class AgentSubscriber` — callback bag: `onRunStart`, `onRunFinish`, `onRunError`, `onStepStart`, `onStepFinish`, `onTextChunk`, `onToolCall`, `onToolResult`, `onStateDelta`, `onReasoning`, `onActivity`, `onUnknownEvent`. All methods have empty defaults; consumers override only what they need.

### `koel_http`

- `class HttpAgent implements AbstractAgent` — constructor takes `Uri url`, `http.Client? client`, `List<Interceptor>? interceptors`, lifecycle hooks. Wire-format sanity (JSON shape of each SSE event) is enforced inside this class before events reach the `koel_core` pipeline.
- `class LoggingInterceptor`, `EventTraceInterceptor`, `RetryInterceptor`, `AuthInterceptor`, `SentryBreadcrumbInterceptor`, `PIIRedactionInterceptor`.
- `class SseParser` — testable, framework-free SSE chunk parser.

### `koel_lints`

- Provides `lib/koel.yaml` — the canonical analyzer profile. Consumers include it via `include: package:koel_lints/koel.yaml` in their `analysis_options.yaml`.
- Principal rule: `exhaustive_switch_must_have_default` — flags any `switch` whose subject is `AgUiEvent`, `KoelError`, or `MessageSegment` without a `default:` arm. Lower-level rule: `prefer_named_constructors_on_sealed_subtypes` (optional). No runtime API; pure analyzer plugin.

### `koel_agno`

- `class AgnoAgent extends HttpAgent` — `AgnoAgent({required Uri baseURL, String? token, ...})`.
- `class AgnoAuthInterceptor extends AuthInterceptor` — default-ON.

### `koel_langgraph`

- `class LangGraphAgent extends HttpAgent` — `LangGraphAgent({required Uri deploymentUrl, ...})`.

### `koel_runtime`

- `class CopilotRuntimeAgent extends AbstractAgent` — `CopilotRuntimeAgent({required Uri graphqlEndpoint, ...})`.

### `koel_flutter`

- `class KoelChatController extends ChangeNotifier` — wraps a `ChatSession`; `state` getter, `send(String)`, `cancel()`, `clear()`.
- `class KoelClientScope extends InheritedWidget` — `.of(context)`.
- `class HiveSessionStorage implements SessionStorage`.
- `class SecureSessionStorage implements SessionStorage`.
- `class MessageContentParser` — `List<MessageSegment> parse(String)`.
- `sealed class MessageSegment` — `TextSegment | CodeBlockSegment`.
- `class WidgetResolver` — `Widget resolve(BuildContext, ToolCallEvent, {Widget Function()? onUnknown})`.

### `koel_widgets`

- `class MessageBubble extends StatelessWidget`.
- `class ChatInput extends StatefulWidget`.
- `class FollowUpList extends StatelessWidget`.
- `class KoelTheme extends ThemeExtension<KoelTheme>`.

### `koel_devtools`

- DevTools extension entrypoint (`devtools_options.yaml` registration).
- `class DevToolsObserver implements AgentSubscriber` — hooks into the live `KoelClient`.

### `koel_test`

- `class MockAgent extends AbstractAgent` — `MockAgent.fromFixture(String name)`, `MockAgent.fromEvents(List<AgUiEvent>)`.
- `class FixtureLoader` — `loadDojo(eventType)`, `loadAgno(scenario)`, `loadLangGraph(scenario)`.
- `class ToolHandlerTestHarness` — fluent test builder.
- `class ConformanceRunner` — `runAgainst(AbstractAgent agent)`.

## 10. Non-Functional Requirements

Cross-cutting requirements across packages. `[ASSUMPTION]` markers indicate parent-proposed values awaiting P1 review.

### 10.1 Performance — regression-relative SLOs

koel commits to regression-relative performance, not absolute numbers. A reference benchmark suite (in `koel_http/test/perf/` and `koel_core/test/perf/`) records baseline latency, throughput, and memory metrics on the v1.0.0 commit. Subsequent commits gate against the baseline. Absolute numbers can land in v1.x once real data exists; speculating them now would be aspirational.

- **N-1. SSE Parse Throughput.** No regression > 10% vs the v1.0.0 baseline `koel_http/test/perf/sse_parse_bench.dart` measurement (events/sec, single-stream, on the CI reference device profile). Tracked per-PR in CI; > 10% regression blocks merge.
- **N-2. Reducer Latency.** No regression > 10% vs the v1.0.0 baseline `koel_core/test/perf/reducer_bench.dart` p99 reduce time per event.
- **N-3. Memory Footprint.** No regression > 10% vs the v1.0.0 baseline RSS delta when running the `chat_session_memory_bench` script (single active session over a fixed event sequence). Excludes consumer-held message history.
- **N-4. Cold-Start Time.** No regression > 10% vs the v1.0.0 baseline `cold_start_bench` measurement (time from `KoelClient(...)` constructor return to first event subscription readiness against `MockAgent.empty`).
- **N-5. Frame Budget.** No protocol work runs synchronously on the UI thread. SSE parsing runs on the `Stream` it produces (event-loop async, single isolate); the reducer runs on the caller's isolate when subscribers consume `ChatSession.stream`. koel does not auto-spawn isolates for the reducer or parser; consumers who want isolate isolation wrap their `KoelClient` in `Isolate.run` themselves. Frame jank during continuous streaming stays below the 16 ms budget when measured on the CI reference device profile under the `streaming_jank_bench` workload.

The reference device profile (CPU, RAM, Dart VM flags) lives in `BENCHMARKS.md` and is tracked in OQ-Perf-Baseline until v1.0.0 publishes the baseline numbers as an artifact.

### 10.2 Reliability

- **N-6. Backpressure.** Event stream uses a bounded buffer (default 1000 events) with configurable overflow policy: `drop_oldest` | `drop_newest` | `pause_upstream`. Default: `pause_upstream`. `[ASSUMPTION]`
- **N-7. Reconnect & Retry.** Exponential backoff with jitter as specified in F-B4. Maximum 5 reconnect attempts on transient failure; permanent failure surfaces as `TransportError`.
- **N-8. Cancellation Determinism.** Cancellation propagates within < 50 ms to HTTP abort. If abort is not honored, silent drop with single debug warning (F-B3).

### 10.3 Compatibility

- **N-9. Dart SDK Floor.** Dart 3.11.0+ — the floor every published `pubspec.yaml` declares (`sdk: ">=3.11.0 <4.0.0"`). Originally bounded by `sealed class` (Dart 3.0+); raised first to align with Melos 7.x's recommended workspace floor (pub-workspaces minimum is 3.6.0+), then to carry the in-SDK `analysis_server_plugin` the lint pivot adopted, settling at 3.11.0 for the workspace — the canonical floor every published `pubspec.yaml` declares. `architecture.md` D1 records the prior 3.10.0 step (raised from 3.9.0+ via SCP-2026-05-29); aligning D1 to the shipped 3.11.0 is a pending reconciliation.
- **N-10. Flutter SDK Floor.** Flutter 3.38.0+ for the Flutter-dependent packages (`koel`, `koel_flutter`, `koel_widgets`) — the floor those `pubspec.yaml`s declare, the first Flutter stable carrying the required Dart floor (N-9) plus the in-SDK `analysis_server_plugin`. Derived from N-9 (Dart floor). (`koel_devtools` is published post-1.0 — Epic 10 / SCP-2026-06-06-B — not at v1.0.0.)
- **N-11. Platform Support.** Flutter packages support all six Flutter platforms (iOS, Android, web, macOS, Windows, Linux) with documented per-platform caveats. Web support uses SSE-over-XHR fallback if `dart:io` is unavailable — verified in CI.

### 10.4 Quality & Discipline

- **N-12. Coverage Tiers.** `koel_core` ≥ 90% line coverage; `koel_http` ≥ 90%; all other packages ≥ 80%. Enforced in CI.
- **N-13. `dart analyze` Clean.** Zero warnings on default lint set plus `package:lints/recommended.yaml` overrides. CI gate.
- **N-14. Semver Discipline.** Zero breaking changes to any public symbol after 1.0.0 within 1.x. A CI API-surface diff flags any removal or signature change.
- **N-15. Surface Minimalism.** No public export without a corresponding example in `/example` or a documented use case in a guide. Vestigial exports are bugs.
- **N-16. No Comments Stating Code.** Doc comments explain *why* and *contract*, never *what*. Inline comments only for non-obvious workarounds.

## 11. Forward-Compatibility Policy

AG-UI has no version negotiation, no version header, and no deprecation policy. koel adopts a defensive posture derived from that reality.

- **FC-1.** Every wire event is checked against the current `koel_core` event registry. Recognized events deserialize into typed `AgUiEvent` subtypes. Unrecognized events deserialize into `UnknownAgUiEvent(type: String, rawJson: Map<String, dynamic>)` and surface via `AgentSubscriber.onUnknownEvent` (F-A6).
- **FC-2.** Adding a new AG-UI event type to `koel_core` is a minor version bump on `koel_core` + `koel_http` + `koel_lints` (lock-step). Safe only because `koel_lints` (F-A12) enforces a mandatory `default:` branch on every `switch` over `AgUiEvent` in consumer code; without that rule, the new sealed subtype would cause compile errors in consumer exhaustive switches. Consumers who decline the `koel_lints` profile accept that koel minor upgrades can introduce compile-time breakage in their switch statements — documented prominently in `koel`'s migration guide.
- **FC-3.** koel tracks the upstream AG-UI TypeScript SDK release stream manually. Maintainer responsibility: read release notes, update `koel_core` event registries when new events ship, and ship a matching `koel_lints` minor when needed.
- **FC-4.** When AG-UI introduces breaking protocol changes (new mandatory fields, removed events, changed semantics), koel issues a major version bump on `koel_core` + `koel_http` + `koel_lints`. Backend-bridge packages receive a minor or patch bump on their dependency range.

## 12. Release & Versioning

- **R-1.** All ten packages publish to pub.dev under a single GitHub org / repo.
- **R-2.** `koel_core`, `koel_http`, and `koel_lints` release in lock-step with identical semver numbers. Changelogs are mirrored.
- **R-3.** Adapter packages (`koel_agno`, `koel_langgraph`, `koel_runtime`) and Flutter packages (`koel_flutter`, `koel_widgets`, `koel_devtools`, `koel_test`) version independently against `^X.Y.0` foundation dependency ranges.
- **R-4.** Pre-v1 (alpha/beta) releases use `0.Y.Z` tagging with explicit `pub.dev` channel labels. No "production-ready" claim before v1.0.0.
- **R-5.** v1.0.0 ships only when every Success Criteria gate in §5.1 is green.

## 13. Documentation Policy

- **D-1.** Every package ships a `README.md` containing: one-paragraph "what is this," 10-line quickstart, link to the docs site, link to changelog, MIT license note.
- **D-2.** Every public symbol has a doc comment stating (a) what it represents, (b) when to use it / when not, (c) error cases, (d) one example or a link to one.
- **D-3.** The docs site (framework TBD — see OQ-Docs-Framework) contains: Getting Started · Concepts (one page each per major idea: events, interceptors, reducer, sessions, devtools) · Recipes (10+ working examples) · API Reference (auto-generated from `dart doc`) · Migration Guide (across minor versions) · Adapter Cookbook (how to write your own backend adapter).
- **D-4.** `/example` directory in each package contains runnable Dart/Flutter sample code. CI runs every example as a smoke test.
- **D-5.** Sample app at the repo root demonstrates the quickstart path end-to-end via the `koel` meta-package. Generic chat scenarios only — zero business domain.

## 14. Counter-metrics

Things to watch and treat as regressions even when no test fails. Reviewed quarterly by P1.

- **CM-1. API Surface Bloat.** Total count of public exports across the 10 packages. Steady growth without new use cases is a vestigial-API smell.
- **CM-2. Cold-Start Regression.** N-4 measured automatically in CI on every PR; regressions > 10% block merge.
- **CM-3. Dependency Weight.** Total transitive dependency count for the `koel` meta-package. Each new dependency added to `koel_core` or `koel_http` requires justification in the PR description.
- **CM-4. Conformance Drift.** Percentage of fixture events that produce different downstream `ChatState` between releases. Non-zero requires a release-note callout.
- **CM-5. Build Time Growth.** Total CI runtime. Watch for slow accretion.
- **CM-6. Doc Comment Density.** Ratio of doc-comment lines to public-symbol count. Falling ratio = drift toward undocumented surface.

## 15. Open Questions

Items the PRD does not close. Each is tagged for downstream resolution. None block PRD finalization; some block downstream epics.

- **OQ-Agno-Auth — RESOLVED.** Default-ON `AgnoAuthInterceptor` per §6.1 / F-C1. *Downstream epic prerequisite:* the `koel_agno` v1 epic begins with a one-week spike that verifies an actual production agno deployment honors the Bearer-token assumption; if not, the default-ON behavior changes before v1 ships.
- **OQ-Fixtures-Source — RESOLVED.** Capture fixtures from four backends (AG-UI dojo + agno + langgraph + CopilotKit Next.js runtime) per §6.1 / F-G1. *Downstream epic prerequisite:* the `koel_test` v1 epic begins with a fixture-capture pipeline spike (deploy each backend locally, capture every event type at least once, codify the capture script). This spike unblocks every other package's test suite.
- **OQ-Docs-Framework — RESOLVED.** Docusaurus 3.x, with its Node/JS toolchain isolated under `docs/` (outside the pub-workspace → 0 lock-drift, AI-5.9 pins held). Decision committed in [`docs/ADR-001-docs-framework.md`](../../../../docs/ADR-001-docs-framework.md) (Story 9.6); Nextra is the recorded runner-up, Dart-native (Jaspr) rejected as immature for a versioned multi-section site. *Site deploy (GitHub Pages) is Story 9.9.* Owner: P1.
- **OQ-Protobuf-Codegen.** Whether v1.5/v2 protobuf transport uses `protoc` Dart codegen or hand-written codec mirrored from `@ag-ui/proto`. *Out-of-scope for v1; placeholder for v2 planning.*
- **OQ-State-Mgmt-Governance.** Policy for accepting community `koel_bloc` / `koel_riverpod` / `koel_getx` contributions. *Resolve before first such contribution arrives; does not block v1.* Owner: P1.
- **OQ-Koel-Trademark — RESOLVED (owner risk-acceptance).** Trademark search for "koel" in the software classes (Nice 9 + 42), recorded in [`trademark-search-koel.md`](../../../legal/trademark-search-koel.md) (Story 9.8). The authoritative register portals were not agent-completable, so this is **not** a clean-clearance claim; instead the owner (P1) has **accepted the residual trademark risk** for v1.0.0 — koel is free, non-commercial OSS (no goods in commerce), and the one material signal, the same-name [`koel/koel`](https://koel.dev) music-streaming server, is a *different product domain* and *unregistered*. Documented as a known/accepted risk; **no longer blocks v1.0.0 publish.** Owner: P1.
- **OQ-AGUI-License — RESOLVED.** Community `ag_ui` 0.1.0 verified **MIT** (standard unmodified boilerplate; compatible with koel's MIT per F-H5) from the pub.dev license tab (LICENSE in the published 0.1.0 archive) + the source-repo LICENSE; koel depends on no `ag_ui` source, so no MIT notice-retention obligation attaches. Recorded in [`ag_ui-license-verification.md`](../../../legal/ag_ui-license-verification.md) (Story 9.8); the `koel_core` README credit is finalized (the Story-1.6 "pending verification" note removed). Owner: P1.
- **OQ-LangGraph-Graduation.** Trigger criteria for `koel_langgraph` to graduate from "surface-level interrupt-resume" (POST resume value + reopen SSE) to "deep interrupt-resume" (client-driven graph state). *Out-of-scope for v1; placeholder for v2 planning.*
- **OQ-Replay-Side-Effects.** Whether tool-handler side effects need a stronger isolation guarantee than the `replayed: true` flag (F-F7). *Resolve during `koel_devtools` v1 implementation; affects DevTools time-travel semantics but not the core protocol.* Owner: P1.
- **OQ-Tool-Param-DSL.** Tool parameter schemas are `Map<String, dynamic>` JSON Schema in v1 (per `ToolDefinition` in §9). A typed-DSL alternative (`freezed`-generated schema classes, codegen from JSON Schema, or runtime builder) is open for v1.x. *Resolve once enough adapter and consumer-side experience exists to know what shape pays.* Owner: P1.
- **OQ-Perf-Baseline — RESOLVED.** The reference device profile, benchmark workloads, and v1.0.0 baseline numbers for §10.1 N-1 through N-5 are captured, committed, and gated in [`BENCHMARKS.md`](../../../../BENCHMARKS.md) + the five baseline JSONs (Story 9.4); `perf-bench.yml` enforces regression-relative SLOs against them. Release-artifact attachment runs at publish (Story 9.9). Owner: P1.
- **OQ-Conformance-Equivalence.** The precise structural-equality rule for `AgUiEvent_equal` in SC-1 — does `freezed`-generated `==` cover every field (incl. `Uint8List` byte-equal vs identity)? The rule is specified in [`koel_core/CONFORMANCE.md`](../../../../packages/koel_core/CONFORMANCE.md) §`AgUiEvent_equal` (AR-16); the `Uint8List` byte-equal-vs-identity edge + id-normalization for real backend captures are tracked there as deliberately deferred. *Resolve before v1.0.0 publish (Story 9.9) — SC-1 is not CI-enforceable without it.* Owner: P1.

## 16. Assumptions Index

Every `[ASSUMPTION]` tag in this PRD with its resolution path. Each row tracks the parent-proposed inference, where it appears, what would falsify it, and which OQ (if any) tracks its resolution.

| Location | Assumption | Falsifier | Resolution path |
|---|---|---|---|
| F-B3 | Silent drop with single debug warning when underlying `http.Client` does not honor abort | A targeted user request for noisier or quieter behavior | P1 review |
| F-B5 | Chunk synthesis defaults ON in `HttpAgent.synthesizeChunks` | Backends emit START/CONTENT/END trios consistently → no need to synthesize | P1 review |
| F-E2 | `WidgetResolver` signature `Map<String, Widget Function(BuildContext, ToolCallEvent)>` with fallback `UnknownGenerativeUI` widget | Real generative-UI use cases require richer context (e.g., session state) at resolve time | First A2UI consumer prototype |
| F-F3 | Time-travel buffer default 1000 events, configurable | Real session traces exceed 1000 events between scrub points; consumers complain about lost history | First `koel_devtools` user feedback |
| F-F6 | JSON Lines trace export format with `_session` header line | Format proves clumsy to re-import or doesn't compress well | First export round-trip in `koel_devtools` v1 |
| F-F7 | Tool-handler side effects gated by `ToolReplayContext.isReplaying` flag (no isolate sandbox) | Real handlers can't reliably check the flag (e.g., handler delegates to a library that doesn't propagate context) | OQ-Replay-Side-Effects |
| §10.1 N-1..N-4 | Regression-relative SLOs against a v1.0.0 baseline yet to be captured | Baseline numbers are absurd in either direction once measured | OQ-Perf-Baseline |

## 17. Glossary

- **AG-UI** — CopilotKit's open agent-UI protocol. Defines SSE event types for streaming agent runs between frontends and agent backends.
- **`AgentSubscriber`** — Passive observation callbacks attached to a `KoelClient` for cross-cutting concerns (telemetry, devtools).
- **Backend bridge** — A koel package bridging a specific backend (agno, LangGraph, CopilotKit Next.js runtime) to the AG-UI event stream. Peers in conformance contract; differ in wire shape.
- **`ChatSession`** — The ergonomic three-layer middle of the API surface: send, cancel, current state, history.
- **`ChatStateReducer`** — Pure function `(ChatState, AgUiEvent) → ChatState`.
- **`ErrorClassifier`** — Pluggable mapping from raw failures (HTTP/network/JSON errors) to typed `KoelError` instances with `KoelErrorCode` vocabulary.
- **Generative UI** — Convention of having an agent render frontend widgets by emitting `TOOL_CALL_*` events that the frontend resolves to widget builders.
- **Interceptor** — Composable wrapper around the run pipeline; cross-cutting concerns (auth, retry, logging) live here.
- **`koel_lints`** — Foundation package shipping mandatory analyzer rules (notably `exhaustive_switch_must_have_default`) that make sealed-union evolution semver-minor-safe.
- **`KoelErrorCode`** — Typed enum vocabulary for `KoelError.code`. Extensible per-adapter via subclass.
- **`RunAgentInput`** — Payload posted to the agent backend to start a run; contains `threadId`, `runId`, `state`, `messages`, `tools`, `context`, `forwardedProps`, `reasoningEcho`.
- **`StateConflict`** — Hook fired when a `STATE_DELTA` arrives whose patches reference paths the local state has mutated since the last `STATE_SNAPSHOT`. Default: last-writer-wins.
- **`threadId` / `runId`** — Identifiers for conversation thread (long-lived) and one agent execution within it (per-POST).
- **`ToolDefinition`** — Name + description + parameter schema (`Map<String, dynamic>` JSON Schema in v1; see OQ-Tool-Param-DSL).
- **`WidgetResolver`** — Maps tool-call names to `Widget` builders for generative-UI rendering.

---

*End of PRD body. See `addendum.md` for tech choices, mechanism rationales, options-considered comparisons, and full type-level API signatures. See `.decision-log.md` for the canonical audit trail.*
