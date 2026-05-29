# Requirements Inventory

## Functional Requirements

> Naming preserves the PRD's stable global IDs (`F-{group}-{n}`). Each FR carries its package home so story decomposition is mechanical.

**Group A — Protocol Foundation (`koel_core`)**

- **FR-A1.** `AbstractAgent.run(RunAgentInput) → Stream<AgUiEvent>` is the irreducible kernel; every other capability is a decorator on `run()` plus stream-cancellation semantics. *(F-A1)*
- **FR-A2.** Three-layer public API: `KoelClient` (configuration/auth/lifecycle) → `ChatSession` (ergonomic 80% path: send/cancel/state/history) → `client.runRaw(RunAgentInput)` (power-user raw event stream). *(F-A2)*
- **FR-A3.** Consumers may subscribe to the canonical low-level `Stream<AgUiEvent>` directly, or opt into a pure `ChatStateReducer` that produces `Stream<ChatState>`; reducer is composable (`ComposedReducer`) and replaceable. *(F-A3)*
- **FR-A4.** dio-style `Interceptor` chain registered on `KoelClient`; each interceptor wraps `Future<Stream<AgUiEvent>>` with explicit ordering. *(F-A4)*
- **FR-A5.** Sealed `KoelError` hierarchy with `TransportError | ProtocolError | AgentError | BusinessError`; adapters emit `RunErrorEvent(error)`, never `throw`. Errors ride the event stream. *(F-A5)*
- **FR-A6.** Unknown event types deserialize into `UnknownAgUiEvent(type, rawJson)`; surfaced via `AgentSubscriber.onUnknownEvent`. SDK never crashes on forward-compat events. *(F-A6)*
- **FR-A7.** Full AG-UI event coverage (`release/2026-05-26`): all ~28 event types — `RUN_*`, `STEP_*`, `TEXT_MESSAGE_*` (incl. CHUNK), `TOOL_CALL_*` (START/ARGS/END/RESULT/CHUNK), `STATE_SNAPSHOT`, `STATE_DELTA`, `MESSAGES_SNAPSHOT`, `ACTIVITY_*`, `REASONING_*` (incl. `REASONING_ENCRYPTED_VALUE`), `RAW`, `CUSTOM`. Each typed via a `freezed` sealed union. No `THINKING_*` aliases. *(F-A7)*
- **FR-A8.** `STATE_DELTA` events carry RFC 6902 patches; `koel_core` applies them strict-mode via vendor-inline implementation under `koel_core/lib/src/json_patch/`. Last-writer-wins default; `StateConflict` hook + pluggable `StateConflictResolver`. *(F-A8)*
- **FR-A9.** Reasoning `encryptedValue` round-trips opaquely as `Uint8List` + base64 string sibling; never inspected. Echoed in subsequent `RunAgentInput.reasoningEcho` for Anthropic/OpenAI replay compliance. *(F-A9)*
- **FR-A10.** `AgentSubscriber` callback bag (passive observation): `onRunStart`, `onRunFinish`, `onRunError`, `onStepStart`/`Finish`, `onTextChunk`, `onToolCall`, `onToolResult`, `onStateDelta`, `onReasoning`, `onActivity`, `onUnknownEvent`. Multiple subscribers compose. *(F-A10)*
- **FR-A11.** 4-stage pure-function event pipeline in fixed order: **chunks** (synthesize START/CONTENT/END from CHUNK) → **verify** (cross-event sanity per Addendum F.1) → **apply** (fold into `ChatState` via reducer) → **transform** (consumer transformers). Wire-format sanity stays in `koel_http` SseParser. *(F-A11)*
- **FR-A12.** `koel_lints` ships `lib/koel.yaml` analyzer profile with principal rule `exhaustive_switch_must_have_default` (fires on `switch` over `AgUiEvent | KoelError | MessageSegment` without `default:`). Built on `analysis_server_plugin` (per AR-5; reversed from `custom_lint` by SCP-2026-05-29). Makes sealed-union evolution semver-minor-safe. *(F-A12)*

**Group B — HTTP Transport (`koel_http`)**

- **FR-B1.** `HttpAgent implements AbstractAgent` — production-grade SSE consumer over `package:http`. Streaming JSON-per-event parsed into typed `AgUiEvent` via testable framework-free `SseParser`. *(F-B1)*
- **FR-B2.** Six built-in interceptors: `LoggingInterceptor`, `EventTraceInterceptor`, `RetryInterceptor` (exponential backoff + jitter + max-attempts), `AuthInterceptor` (Bearer + custom headers), `SentryBreadcrumbInterceptor` (default-OFF), `PIIRedactionInterceptor` (default-OFF, regex + JSONPath). *(F-B2)*
- **FR-B3.** `StreamSubscription.cancel()` propagates to HTTP-level abort (TCP close) — AG-UI's only cancellation mechanism. < 50 ms latency. Falls back to silent drop + one debug warning per process if abort not honored. Verified against `package:http` default client + `dart:io` client + browser client. *(F-B3)*
- **FR-B4.** Mid-stream connection loss triggers exponential backoff (default 1s → 30s, ±20% jitter, max 5 attempts, configurable per `KoelClient`). Emits `ConnectionResumed` `MetaEvent` on reconnect. *(F-B4)*
- **FR-B5.** Chunk synthesis: `HttpAgent.synthesizeChunks` default ON, synthesizes START/CONTENT/END triplets from `TOOL_CALL_CHUNK` / `TEXT_MESSAGE_CHUNK` per Addendum F.2. *(F-B5)*
- **FR-B6.** Connection lifecycle hooks on `HttpAgent`: `onConnect`, `onDisconnect`, `onReconnectAttempt`. Used internally by `koel_devtools`. *(F-B6)*

**Group C — Backend Adapters**

- **FR-C1.** `koel_agno`: `AgnoAgent extends HttpAgent` targeting `POST baseURL/agno-chat`. Default-ON `AgnoAuthInterceptor` (Bearer; nullable token for open dev). Conformance fixtures captured from a real agno backend. *(F-C1)*
- **FR-C2.** `koel_langgraph`: `LangGraphAgent extends HttpAgent` targeting LangGraph deployment URL. Surface-level interrupt-resume — `resume(threadId, resumeValue)` POSTs and reopens SSE; no client-side state reconstruction. Conformance fixtures from a real LangGraph deployment. *(F-C2)*
- **FR-C3.** `koel_runtime`: `CopilotRuntimeAgent implements AbstractAgent` for the CopilotKit Next.js runtime. Hand-rolled `MultipartGraphQLStreamParser` (no GraphQL client library) over HTTP @defer/multipart streaming. Independent of `koel_http`. *(F-C3)*

**Group D — State, Session & Flutter Glue (`koel_flutter`)**

- **FR-D1.** `abstract class SessionStorage` with `save`/`load`/`delete`/`listThreads`; 3 implementations — `InMemorySessionStorage` (in `koel_core`), `HiveSessionStorage`, `SecureSessionStorage` (both in `koel_flutter`). Partial messages persist with `isComplete: false`. *(F-D1)*
- **FR-D2.** `ChatStateReducer` pure function `(ChatState, AgUiEvent) → ChatState` produces `messages`, `pendingMessage`, `pendingToolCalls`, `state`, `error`, `phase`. `DefaultChatStateReducer` ships; `ComposedReducer([base, custom])` composes. Replaceable via `KoelClient.reducer`. Reducer purity verified by test. *(F-D2)*
- **FR-D3.** `KoelClient` is non-singleton; multiple clients + multiple sessions per client are first-class. Each session owns its own `threadId`, `runId`, reducer, storage binding. No global state. *(F-D3)*
- **FR-D4.** `KoelChatController extends ChangeNotifier` wraps a `ChatSession`; exposes sync `state` getter + `send(String)`/`cancel()`/`clear()`; calls `notifyListeners()` on state change. Works unmodified with Bloc, Riverpod, GetX, Provider, plain `setState`. *(F-D4)*
- **FR-D5.** `KoelClientScope extends InheritedWidget` publishes a `KoelClient` down the tree; `KoelClientScope.of(context)` retrieves it. No magic, no service locator. *(F-D5)*

**Group E — Message Content & Generative UI**

- **FR-E1.** `MessageContentParser.parse(String) → List<MessageSegment>` (sealed `TextSegment | CodeBlockSegment(language, code)`). Markdown-fenced code blocks split out. Rich content defers to v2. *(F-E1)*
- **FR-E2.** `WidgetResolver` for generative UI v1: `Map<String, Widget Function(BuildContext, ToolCallEvent)>` + optional `onUnknown` fallback. Resolves tool-call name → Flutter Widget. *(F-E2)*
- **FR-E3.** `koel_widgets` ships `MessageBubble` (M3 + Cupertino variants), `ChatInput` (auto-grow text + attachment slot), `FollowUpList`. Themed; opt-in. *(F-E3)*
- **FR-E4.** `KoelTheme extends ThemeExtension<KoelTheme>` — color slots, text styles, spacing tokens. Every `koel_widgets` widget reads via `Theme.of(context).extension<KoelTheme>()`. *(F-E4)*

**Group F — Observability & DevTools (`koel_devtools`)**

- **FR-F1.** Flutter DevTools extension via `devtools_extensions` (Flutter web, iFrame-embedded). Auto-discovered when `koel_devtools` is in pubspec. Tabs: Stream · History · Inspector · Network · Export. *(F-F1)*
- **FR-F2.** Live event stream panel: real-time tail of all `AgUiEvent`s. Filter by event type, search by text, jump-to-event. *(F-F2)*
- **FR-F3.** Time-travel replay panel: bounded ring buffer (default 1000 events, `KoelClient.devtoolsBufferSize` configurable). Step backwards/forwards; re-fold reducer over `events[0..N]`, cached per N. *(F-F3)*
- **FR-F4.** Tool-call inspector: tree view per session — name, args (pretty JSON), result, latency, error. Drill-down per call. *(F-F4)*
- **FR-F5.** Network panel: HTTP-level inspector — request headers, response headers, connection lifecycle, retries. *(F-F5)*
- **FR-F6.** JSON Lines trace export: first line `_session` header (threadId, runId, koelVersion, adapter, captured-at); subsequent lines one event each with `timestamp` (ISO 8601) + `payload`. Re-importable via "Load Trace". *(F-F6)*
- **FR-F7.** Replay safety: replay re-applies events through the reducer; never re-executes tool handlers. `ToolReplayContext` `InheritedWidget` propagates `isReplaying: true`; handlers consult it to no-op side effects. *(F-F7)*

**Group G — Testing & Conformance (`koel_test`)**

- **FR-G1.** Captured fixtures from four backends — AG-UI dojo (`integrations/server-starter-all-features`), agno, langgraph, CopilotKit Next.js runtime — covering every AG-UI event type and key flows (text-only run, run with tool call, run with state delta, run with reasoning + `encryptedValue` round-trip, error path, cancellation). Stored as JSON Lines bundled inside `koel_test/lib/src/fixtures/<backend>/*.jsonl` (per D8). Hand-synthesized fixtures (`synthesized: true` in header) for events no backend emits. *(F-G1)*
- **FR-G2.** `MockAgent`: `MockAgent.fromFixture(name)` returns an `AbstractAgent` replaying the named fixture. `MockAgent.fromEvents(list)` and `MockAgent.programmatic()` builder variant. *(F-G2)*
- **FR-G3.** `ToolHandlerTestHarness` — register tool handlers under test, drive via `MockAgent`, assert on args/responses/replay behavior. ~5 lines per case. *(F-G3)*
- **FR-G4.** `ConformanceRunner.runAgainst(AbstractAgent) → ConformanceReport`. Takes any `AbstractAgent`, asserts it correctly handles every event type from fixtures. Used internally to verify `koel_agno`, `koel_langgraph`, `koel_runtime` parity; publicly runnable for community adapters. *(F-G4)*

**Group H — Distribution & Versioning**

- **FR-H1.** 10-package Melos monorepo (Melos 7.8.0); each package independently publishable; shared dev deps, lints (via `koel_lints`), CI. `CONTRIBUTING.md` documents the workflow. *(F-H1)*
- **FR-H2.** Hybrid versioning: `koel_core` + `koel_http` + `koel_lints` lock-step (identical semver). Backend bridges + Flutter packages depend via `^X.Y.0` ranges; version independently against each other. *(F-H2)*
- **FR-H3.** `koel` meta-package re-exports `koel_core` + `koel_http` + `koel_flutter`. `dart pub add koel` produces the working SDK quickstart path. *(F-H3)*
- **FR-H4.** Brand "koel" (Hindi for the singing cuckoo). All ten `koel_*` slots reserved on pub.dev pre-publish. No `agui_*`/`copilotkit_*` piggyback. One-line credit to community `ag_ui` 0.1.0 in `koel_core` README. *(F-H4)*
- **FR-H5.** MIT License — all 10 packages. License file in every package root + repo root. *(F-H5)*
- **FR-H6.** Docs toolchain: `dart doc` for pub.dev API tab. Dedicated docs site (framework = OQ-Docs-Framework, deferred). Per-package READMEs follow PRD §13 D-1 quality bar. *(F-H6)*

**Group I — Cross-Cutting Hygiene**

- **FR-I1.** CI/CD matrix across all 10 packages × 6 platforms — per-PR runs `dart analyze` + `dart test` + coverage threshold + conformance + `dart pub publish --dry-run` per package. Per-package coverage gates enforced. *(F-I1)*
- **FR-I2.** Default-OFF telemetry: `SentryBreadcrumbInterceptor` + `PIIRedactionInterceptor` ship but are not registered by default. Consumers opt in. No silent telemetry. *(F-I2)*
- **FR-I3.** Trademark check on "koel" beyond pub.dev (OQ-Koel-Trademark, blocks v1.0.0); license-compatibility verification of `ag_ui` 0.1.0 (OQ-AGUI-License, blocks first README crediting it). *(F-I3)*

## NonFunctional Requirements

**Performance (regression-relative SLOs, gated per PR)**

- **NFR-1.** SSE parse throughput — no regression > 10% vs v1.0.0 baseline (`koel_http/test/perf/sse_parse_bench.dart`, events/sec, single-stream, CI reference device profile). *(N-1)*
- **NFR-2.** Reducer latency — no regression > 10% vs v1.0.0 baseline (`koel_core/test/perf/reducer_bench.dart`, p99 reduce time per event). *(N-2)*
- **NFR-3.** Memory footprint — no regression > 10% vs v1.0.0 baseline RSS delta (`chat_session_memory_bench`, single active session over fixed event sequence). *(N-3)*
- **NFR-4.** Cold-start time — no regression > 10% vs baseline (`cold_start_bench`, `KoelClient(...)` ctor return to first event subscription readiness against `MockAgent.empty`). *(N-4)*
- **NFR-5.** Frame budget — no protocol work runs synchronously on UI thread; streaming jank stays below 16 ms on CI reference device under `streaming_jank_bench`. No auto-isolate spawn; consumers wrap `KoelClient` in `Isolate.run` themselves. *(N-5)*

**Reliability**

- **NFR-6.** Backpressure — bounded buffer (default 1000 events) with configurable overflow policy: `dropOldest | dropNewest | pauseUpstream`. Default `pauseUpstream` propagates TCP-window close. Loss policies log at warning level with counter. *(N-6)*
- **NFR-7.** Reconnect & retry — exponential backoff with jitter (max 5 attempts; transient → retry; permanent → `TransportError`). *(N-7)*
- **NFR-8.** Cancellation determinism — cancellation propagates to HTTP abort within < 50 ms. If abort not honored, silent drop + one debug warning. *(N-8)*

**Compatibility**

- **NFR-9.** Dart SDK floor: **Dart 3.9.0+** (raised from PRD's original 3.0+ per architecture D1 — Melos 7.x recommends 3.9.0+; pub-workspace minimum 3.6.0+). PRD §10.3 N-9 reconciliation pending. *(N-9 + D1)*
- **NFR-10.** Flutter SDK floor: Flutter version that ships Dart 3.9+ (approximately Flutter 3.27+ — exact version verified during reconciliation). PRD §10.3 N-10 reconciliation pending. *(N-10)*
- **NFR-11.** Six Flutter platforms (iOS, Android, web, macOS, Windows, Linux). Web uses hand-rolled fetch + ReadableStream (per D4) — not `EventSource` (which forbids custom headers). CI exercises both native + web transport paths. *(N-11)*

**Quality & Discipline**

- **NFR-12.** Coverage tiers — `koel_core`, `koel_http`, `koel_flutter`, `koel_lints` ≥ 90% line + branch. Adapter and tooling packages ≥ 80%. Per-PR patch coverage ≥ 85%. Generated files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`) excluded. Aggregated via Melos. *(N-12 + SC-2)*
- **NFR-13.** `dart analyze` zero warnings across every package — default lint set + `package:lints/recommended.yaml` overrides + `package:koel_lints/koel.yaml` mandatory rules. CI gate. *(N-13 + SC-3)*
- **NFR-14.** Semver discipline — zero breaking changes to 1.x public surface after v1.0.0. Enforced by `dart_apitool: ^0.23.1` (per D7) per-package CI step diffed against published baseline. *(N-14 + SC-4)*
- **NFR-15.** Surface minimalism — no public export without a corresponding example in `/example` or documented use case in a guide. CI diffs `package:koel_*` public symbols against `/example` usage + dartdoc cross-reference graph. *(N-15 + SC-5)*
- **NFR-16.** No comments stating code — doc comments explain *why* + contract, never *what*. Inline comments only for non-obvious workarounds. *(N-16)*

**Forward-Compatibility (FC-1..FC-4 from PRD §11)**

- **NFR-17.** Adding a new AG-UI event type to `koel_core` is a minor bump (lock-step `koel_core` + `koel_http` + `koel_lints`). Safe only because `koel_lints` enforces consumer-side `default:` branches. Documented in migration guide. *(FC-2)*
- **NFR-18.** AG-UI breaking protocol changes (new mandatory fields, removed events, changed semantics) trigger a major bump on lock-step foundations; adapters receive minor/patch on dep-range. *(FC-4)*

## Additional Requirements

> Architectural decisions from `architecture.md` that shape epic/story scope beyond the FR/NFR text. Each is a binding implementation requirement, not optional guidance.

**Project scaffolding (no starter template; manual + Melos)**

- **AR-1. Workspace bootstrap.** Repo root is a Dart pub workspace (Dart 3.6.0+ required for workspaces; recommend 3.9.0+) + Melos 7.8.0 orchestration. Workspace `pubspec.yaml` + `melos.yaml` hand-authored (~15 lines + script list). No `very_good_cli` (conflicts with `koel_lints`; bundled `very_good_analysis` cannot coexist).
- **AR-2. Per-package scaffold.** Dart-only packages via `dart create --template=package`; Flutter packages via `flutter create --template=package`. `koel_lints` uses non-standard structure (`analysis_server_plugin` conventions: plugin entry at `lib/main.dart`, rules under `lib/src/rules/`; per SCP-2026-05-29). No mason brick at v1 (conventions not yet stable; over-engineering for 10-package one-off).
- **AR-3. Bootstrap order.** (1) repo skeleton + workspace + Melos + `.gitignore` + `.github/`; (2) `koel_lints` stub (every other package's `analysis_options.yaml` includes it from day one — path-dep during dev, package-dep at first publish); (3) `koel_core`; (4) `koel_test` (MockAgent + synthesized fixture); (5) `koel_http`; (6) backend bridges (`koel_agno`, `koel_langgraph`, `koel_runtime` in any order); (7) `koel_flutter` → `koel_widgets` → `koel_devtools` → `koel` meta.

**Pinned tech & implementation choices**

- **AR-4. `freezed: ^3.2.5`** (build_runner-based; Dart macros stalled). All immutable data classes across `koel_core` + `koel_flutter` use freezed.
- **AR-5. `analysis_server_plugin: ^0.3.15` + `analyzer: ^13.0.0`** as foundation for `koel_lints` analyzer plugin. First-party (Dart team), workspace-native, integrates into `dart analyze` + IDEs. _Reversed from the originally-planned `custom_lint: 0.8.1` via correct-course SCP-2026-05-29 — custom_lint was archived 2026-03-24 and fails to enforce on native pub workspaces. Implemented in re-scoped Story 1.7._
- **AR-6. Vendor-inline RFC 6902.** No `package:json_patch` dependency. ~300 LOC strict-mode implementation under `koel_core/lib/src/json_patch/` (`JsonPatch.apply`, `JsonPatchOp` types). Internal RFC 6902 test suite. PRD Addendum B.3 reconciliation pending.
- **AR-7. `package:http`** (official) for HTTP. Injectable `http.Client`. No Dio dependency.
- **AR-8. Hand-rolled SSE parser** (~150 LOC, framework-free). No `package:sse`, no `package:eventsource` — both unmaintained or wrong-target.
- **AR-9. Hand-rolled web transport (D4).** `package:web` fetch + ReadableStream on Flutter web — **not** browser `EventSource` (which forbids custom request headers, would silently break `AuthInterceptor`). Shares `SseParser` with native `dart:io` socket transport. CI matrix exercises both paths. Cancellation on web uses `AbortController` (G-1).
- **AR-10. Hand-rolled multipart GraphQL parser (D5)** for `koel_runtime`. No `package:graphql` or `package:gql` dependencies. ~200 LOC POST + multipart-stream parse + AG-UI event translation. `MultipartGraphQLStreamParser` analog to `koel_http`'s `SseParser`.
- **AR-11. `devtools_extensions: 0.5.1`** for `koel_devtools` — Flutter web extension only (forced by upstream; no HTML+CSS option). DevTools UI lives under `tool/extension_ui/` (Flutter web app); built output ships in `extension/devtools/build/`.
- **AR-12. `dart_apitool: ^0.23.1`** for API surface diff (per D7). Per-package CI step diffs against published v1.x.y baseline. Diff failure blocks merge.
- **AR-13. Bundled fixtures (D8).** JSONL fixtures inside `koel_test/lib/src/fixtures/<backend>/*.jsonl` as package assets (~50 KB compressed; well under pub.dev 10 MB limit). `FixtureLoader` reads via `package:` asset URI. Fixture-capture pipeline (`tool/capture_fixtures.dart`) emits directly into this location.

**Cross-cutting concerns (architectural artifacts, not just code)**

- **AR-14. Fixture-capture pipeline.** `tool/capture_fixtures.dart` deploys each of the 4 reference backends locally (AG-UI dojo + agno + langgraph + CopilotKit Next.js runtime), captures every event type at least once, codifies the capture script. Unblocks every other package's test suite. Maintainable; re-runnable when AG-UI spec releases. *(OQ-Fixtures-Source spike)*
- **AR-15. Perf benchmark harness.** Per-package `test/perf/*_bench.dart` files: `sse_parse_bench`, `reducer_bench`, `cold_start_bench`, `chat_session_memory_bench`, `streaming_jank_bench`. Reference device profile (CPU, RAM, Dart VM flags) lives in `BENCHMARKS.md`. v1.0.0 publishes baseline numbers as artifacts (OQ-Perf-Baseline). CI gates per-PR at >10% regression.
- **AR-16. AG-UI conformance pin.** `koel_core/CONFORMANCE.md` pins specific commit SHA of AG-UI `release/2026-05-26` at v1.0.0 publish. `AgUiEvent_equal` structural equality (freezed-generated `==`) covers every field — OQ-Conformance-Equivalence resolves before v1.0.0 (Uint8List byte-equal vs identity).
- **AR-17. CI matrix shape.** GitHub Actions workflows: `ci.yml` (10 pkgs × 6 platforms × analyze+test+coverage), `conformance.yml`, `perf-bench.yml`, `api-diff.yml` (dart_apitool per package), `codegen-drift.yml` (`melos run build && git diff --exit-code`), `publish-dry-run.yml`. CI runtime tracked as CM-5.
- **AR-18. Codegen orchestration.** `freezed` + `json_serializable` + `koel_lints` (custom analyzer plugin) compose cleanly via Melos build pipeline. Generated files (`*.g.dart`, `*.freezed.dart`, `*.mocks.dart`) gitignored repo-wide; CI runs `melos run build && git diff --exit-code` to guarantee no drift.
- **AR-19. Pipeline boundary discipline.** 4 stages are pure `StreamTransformer<AgUiEvent, AgUiEvent>` defined in `koel_core/lib/src/pipeline/`; wired by `koel_http`; observed by `koel_devtools`; exercised by `koel_test`. Stage order locked. No I/O inside stages — errors surface in-stream as `RunErrorEvent(KoelError)`.
- **AR-20. Adapter boundary contract.** Backend bridges never import `koel_core/src/` paths — only the barrel `koel_core.dart`. Each adapter subclasses `DefaultErrorClassifier` to map backend-specific error shapes to `KoelErrorCode`. Per AR-9 + AR-10, `koel_runtime` is independent of `koel_http`.
- **AR-21. Documentation contract.** `koel_core/CONFORMANCE.md` (spec pin) + `BENCHMARKS.md` (reference device profile) at repo root. Every package: `README.md` + `CHANGELOG.md` + `LICENSE` per PRD §13 D-1. Repo-root `CONTRIBUTING.md` documents monorepo workflow.
- **AR-22. Sample app at repo root.** `example/` directory (depends on `koel` meta-package). Demonstrates quickstart end-to-end. Generic chat scenario only — zero business domain.
- **AR-23. Gap addendums.** Three documentation gaps identified in architecture validation (G-1: AbortController on web; G-2: `melos run build:devtools` script; G-3: `koel_lints` self-include exception) land as edits during first implementation PR — not blockers.

**PRD/Addendum reconciliation tasks** *(parallel to implementation)*

- **AR-24.** Update PRD §10.3 N-9: "Dart 3.0+" → "Dart 3.9.0+" (per D1).
- **AR-25.** Update PRD §10.3 N-10: Flutter SDK floor to version that ships Dart 3.9+ (verify exact number, ≈ Flutter 3.27+).
- **AR-26.** Update PRD Addendum B.3 from "Use existing `package:json_patch`" to "Vendor inline under `koel_core/lib/src/json_patch/`" using D.7-style rationale.

## UX Design Requirements

*Not applicable.* koel is a technical SDK — no UI/UX specification document. Visual design surface (`koel_widgets` M3 + Cupertino bubble, ChatInput, FollowUpList, `KoelTheme`) is owned by Group E features (FR-E3, FR-E4) and inherits Material 3 / Cupertino design system semantics without a dedicated UX spec.

## FR Coverage Map

> Every PRD functional requirement maps to exactly one shipping epic (some FRs split where the work cleanly partitions across packages, noted inline).

| FR | Epic | Notes |
|---|---|---|
| F-A1 | Epic 2 | `AbstractAgent.run()` kernel in `koel_core` |
| F-A2 | Epic 2 | 3-layer API: `KoelClient` + `ChatSession` + `runRaw` |
| F-A3 | Epic 2 | Hybrid event-stream + opt-in reducer |
| F-A4 | Epic 2 | Interceptor chain framework (built-ins ship in Epic 4) |
| F-A5 | Epic 2 | Sealed `KoelError` + `KoelErrorCode` + `ErrorClassifier` |
| F-A6 | Epic 2 | `UnknownAgUiEvent` forward-compat fallback |
| F-A7 | Epic 2 | Full ~28 AG-UI event types via `freezed` |
| F-A8 | Epic 2 | RFC 6902 vendor-inline + `StateConflict` hook |
| F-A9 | Epic 2 | Reasoning `encryptedValue` opaque round-trip |
| F-A10 | Epic 2 | `AgentSubscriber` callback bag |
| F-A11 | Epic 2 | 4-stage event pipeline (chunks → verify → apply → transform) |
| F-A12 | Epic 1 | `koel_lints` analyzer profile + principal rule (path-dep for every other pkg) |
| F-B1 | Epic 4 | `HttpAgent` + `SseParser` |
| F-B2 | Epic 4 | 6 built-in interceptors (Logging/EventTrace/Retry/Auth/Sentry-OFF/PII-OFF) |
| F-B3 | Epic 4 | Cancellation → HTTP abort < 50 ms |
| F-B4 | Epic 4 | Reconnect & exponential-backoff policy |
| F-B5 | Epic 4 | Chunk synthesis (default ON) |
| F-B6 | Epic 4 | Connection lifecycle hooks |
| F-C1 | Epic 5 | `koel_agno`: AgnoAgent + AgnoAuthInterceptor + fixtures |
| F-C2 | Epic 5 | `koel_langgraph`: LangGraphAgent + surface-level interrupt-resume |
| F-C3 | Epic 5 | `koel_runtime`: CopilotRuntimeAgent + hand-rolled multipart GraphQL parser |
| F-D1 | Epic 2 (interface + InMemory) + Epic 6 (Hive + Secure) | Storage interface lives with core; Flutter-bound impls with `koel_flutter` |
| F-D2 | Epic 2 | `ChatStateReducer` + `DefaultChatStateReducer` + `ComposedReducer` |
| F-D3 | Epic 2 | Multi-client multi-session, non-singleton |
| F-D4 | Epic 6 | `KoelChatController extends ChangeNotifier` |
| F-D5 | Epic 6 | `KoelClientScope` `InheritedWidget` |
| F-E1 | Epic 6 | `MessageContentParser` + sealed `MessageSegment` |
| F-E2 | Epic 6 | `WidgetResolver` generative UI v1 |
| F-E3 | Epic 7 | `MessageBubble` (M3 + Cupertino) + `ChatInput` + `FollowUpList` |
| F-E4 | Epic 7 | `KoelTheme extends ThemeExtension<KoelTheme>` |
| F-F1 | Epic 8 | Flutter DevTools extension entrypoint + 5 tabs |
| F-F2 | Epic 8 | Live event stream panel |
| F-F3 | Epic 8 | Time-travel replay + bounded ring buffer |
| F-F4 | Epic 8 | Tool-call inspector |
| F-F5 | Epic 8 | Network panel |
| F-F6 | Epic 8 | JSON Lines trace export/import |
| F-F7 | Epic 8 | Replay safety + `ToolReplayContext` |
| F-G1 | Epic 3 (synthesized) + Epic 5 (real captured) | Fixture storage + scaffold first; real captures from 4 backends land with adapters |
| F-G2 | Epic 3 | `MockAgent.fromFixture` / `.fromEvents` / `.programmatic()` |
| F-G3 | Epic 3 | `ToolHandlerTestHarness` |
| F-G4 | Epic 3 (skeleton) + Epic 5 (complete green) | `ConformanceRunner` defined in Epic 3; backends pass in Epic 5 |
| F-H1 | Epic 1 | Melos monorepo + workspace + `CONTRIBUTING.md` |
| F-H2 | Epic 9 | Hybrid versioning + `^X.Y.0` dependency ranges enforced at release |
| F-H3 | Epic 9 | `koel` meta-package re-exports |
| F-H4 | Epic 1 | Brand + pub.dev slot reservation (10 packages) |
| F-H5 | Epic 1 | MIT License per package + repo root |
| F-H6 | Epic 9 | Docs toolchain (`dart doc` + dedicated docs site — framework TBD per OQ-Docs-Framework) |
| F-I1 | Epic 1 (skeleton) + Epic 9 (all 6 workflows green) | CI/CD matrix |
| F-I2 | Epic 4 | Default-OFF Sentry + PII interceptors ship in `koel_http` |
| F-I3 | Epic 9 | Trademark check + `ag_ui` license verification (v1.0.0 publish gates) |

**Coverage: 50/50 FRs mapped, no orphans.**

**NFR coverage:**
- NFR-1 → Epic 4 · NFR-2 → Epic 2 · NFR-3 → Epic 6 · NFR-4 → Epic 2 · NFR-5 → Epic 6
- NFR-6, NFR-7, NFR-8 → Epic 4
- NFR-9 → Epic 1 (pubspec constraint) + Epic 9 (reconciliation AR-24)
- NFR-10 → Epic 6 (Flutter packages) + Epic 9 (reconciliation AR-25)
- NFR-11 → Epic 4 (web transport) + Epic 6 (six platforms verified)
- NFR-12 → every epic that ships a package (tier per package per architecture)
- NFR-13 → Epic 1 (baseline) + every subsequent epic (CI gate)
- NFR-14 → Epic 9 (dart_apitool baseline + diff gate)
- NFR-15 → Epic 9 (CI check)
- NFR-16 → Epic 1 (convention) + every subsequent epic
- NFR-17, NFR-18 → Epic 1 (lint enforcement) + Epic 9 (release discipline)

**AR coverage:**
- AR-1, AR-2, AR-3, AR-5, AR-17 (skeleton), AR-18, AR-23 (G-3) → Epic 1
- AR-4, AR-6, AR-15 (reducer_bench + cold_start_bench), AR-16, AR-19 → Epic 2
- AR-13, AR-14 (scaffold), AR-16 (CONFORMANCE.md pin) → Epic 3
- AR-7, AR-8, AR-9, AR-15 (sse_parse_bench), AR-23 (G-1) → Epic 4
- AR-10, AR-14 (full execution), AR-20 → Epic 5
- AR-15 (chat_session_memory_bench + streaming_jank_bench) → Epic 6
- AR-11, AR-23 (G-2) → Epic 8
- AR-12, AR-15 (publish baselines), AR-17 (complete), AR-21, AR-22, AR-24, AR-25, AR-26 → Epic 9
