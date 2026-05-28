# Epic List

## Epic 1: Workspace Foundation & Lint Profile

**Goal:** Developer can `git clone koel && melos bootstrap` and have every package compile + `dart analyze` clean against `package:koel_lints/koel.yaml`. CI skeleton (6 workflow files) and brand/license/MIT scaffolding ship together so subsequent epics inherit a green baseline. Stories: workspace pubspec + Melos config; `koel_lints` package + principal rule (`exhaustive_switch_must_have_default`); per-package scaffold via `dart create`/`flutter create`; CI workflow skeleton; brand reservation + license placement.

**FRs covered:** F-A12, F-H1, F-H4, F-H5, F-I1 (skeleton)

## Epic 2: Protocol Kernel — `koel_core`

**Goal:** Developer can construct a `KoelClient` wrapping a programmatic `MockAgent`, drive a `ChatSession`, and observe a fully-typed `Stream<AgUiEvent>` covering all ~28 AG-UI event types through the 4-stage pipeline. Sealed `KoelError` + `AgentSubscriber` + vendor-inline RFC 6902 + `InMemorySessionStorage` ship. Reducer purity verified. Coverage ≥ 90%. Perf baselines for reducer + cold-start captured.

**FRs covered:** F-A1, F-A2, F-A3, F-A4, F-A5, F-A6, F-A7, F-A8, F-A9, F-A10, F-A11, F-D1 (interface + `InMemorySessionStorage`), F-D2, F-D3

## Epic 3: Test Harness & Conformance — `koel_test`

**Goal:** Developer (and every subsequent epic) can write tests using `MockAgent.fromFixture(name)` against synthesized fixtures covering every AG-UI event type and key flows. `ToolHandlerTestHarness` cuts test boilerplate to ~5 lines per case; `ConformanceRunner` skeleton ready for backend adapters to plug into. Fixture-capture pipeline scaffold exists; real backend captures land in Epic 5. `koel_core/CONFORMANCE.md` records the AG-UI spec commit SHA.

**FRs covered:** F-G1 (synthesized fixtures + storage layout + capture pipeline scaffold), F-G2, F-G3, F-G4 (skeleton)

## Epic 4: HTTP Transport — `koel_http`

**Goal:** Developer can connect a `KoelClient` to any AG-UI-compliant SSE endpoint over both native (`dart:io`) and web (`package:web` fetch + ReadableStream + AbortController) transport. Six built-in interceptors compose into the chain — Logging/EventTrace/Retry/Auth ship default-ON, Sentry/PII default-OFF. Cancellation propagates < 50 ms. Reconnect with exponential backoff + jitter (max 5 attempts). Chunk synthesis ON by default. Coverage ≥ 90%. SSE parse-throughput baseline captured.

**FRs covered:** F-B1, F-B2, F-B3, F-B4, F-B5, F-B6, F-I2

## Epic 5: Backend Bridges — `koel_agno` + `koel_langgraph` + `koel_runtime`

**Goal:** Developer can `dart pub add koel_agno` (or `_langgraph` / `_runtime`) and connect to a real backend out-of-the-box with the right auth interceptor and error classifier wired. `koel_runtime` uses hand-rolled multipart GraphQL parser (no GraphQL client dependency). Real captured fixtures from all four reference backends (dojo + agno + langgraph + CopilotKit Next.js runtime) populate `koel_test/lib/src/fixtures/`. `ConformanceRunner` runs green against every adapter. Coverage ≥ 80%. Stories partition cleanly per backend (3 sets of stories — Agno first, then LangGraph, then CopilotKit runtime, in independent order).

**FRs covered:** F-C1, F-C2, F-C3, F-G1 (real captured fixtures), F-G4 (complete green)

## Epic 6: Flutter Glue & Persistence — `koel_flutter`

**Goal:** Developer can wrap a `ChatSession` in `KoelChatController extends ChangeNotifier` and integrate into any state-management framework (Bloc/Riverpod/GetX/Provider/setState) with one line. `KoelClientScope` publishes the client down the widget tree. `HiveSessionStorage` + `SecureSessionStorage` persist + restore conversations including partial messages (`isComplete: false`). `MessageContentParser` splits assistant strings into `TextSegment | CodeBlockSegment`. `WidgetResolver` hosts generative UI on `TOOL_CALL_*` events. Verified across all six Flutter platforms. Memory + streaming-jank baselines captured. Coverage ≥ 90%.

**FRs covered:** F-D1 (Hive + Secure storages), F-D4, F-D5, F-E1, F-E2

## Epic 7: Widget Primitives & Theming — `koel_widgets`

**Goal:** Developer can drop in `MessageBubble` (Material 3 + Cupertino variants), `ChatInput` (auto-grow + attachment slot), `FollowUpList` and customize via `KoelTheme extends ThemeExtension<KoelTheme>`. UI is opt-in — `koel_widgets` is never required to use `koel_flutter`. Coverage ≥ 80%.

**FRs covered:** F-E3, F-E4

## Epic 8: DevTools Extension — `koel_devtools`

**Goal:** Developer opens Flutter DevTools and sees a live `AgUiEvent` stream, time-travel replay through a configurable ring buffer (default 1000), tool-call inspector, network panel, and JSON Lines trace export/import. `DevToolsObserver implements AgentSubscriber`, never mutates `KoelClient` state. Replay re-folds the reducer; tool handlers no-op via `ToolReplayContext.isReplaying`. Flutter web extension UI under `tool/extension_ui/` builds via `melos run build:devtools` and ships in the package. Coverage ≥ 80%.

**FRs covered:** F-F1, F-F2, F-F3, F-F4, F-F5, F-F6, F-F7

## Epic 9: Meta-Package, Sample App & v1.0.0 Release Gates

**Goal:** `dart pub add koel` produces the working quickstart path (re-exports `koel_core` + `koel_http` + `koel_flutter`). A sample app at the repo root demonstrates the end-to-end flow across all six platforms via the meta-package, generic chat scenarios only. All six CI workflows run green: `ci.yml` (analyze + test + coverage), `conformance.yml`, `perf-bench.yml` (regression-relative SLOs against published baseline), `api-diff.yml` (`dart_apitool` against baseline), `codegen-drift.yml`, `publish-dry-run.yml`. Per-package READMEs meet PRD §13 D-1 bar. PRD reconciliation tasks (AR-24, AR-25, AR-26) committed. Trademark + `ag_ui` license gates resolved. v1.0.0 published lock-step on `koel_core` + `koel_http` + `koel_lints`; other packages versioned independently against `^1.0.0` ranges. Baseline perf artifacts published as release assets.

**FRs covered:** F-H2, F-H3, F-H6, F-I1 (complete green), F-I3

---
