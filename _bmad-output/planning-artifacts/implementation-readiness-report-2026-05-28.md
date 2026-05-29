---
project: koel
date: 2026-05-28
stepsCompleted:
  - step-01-document-discovery
  - step-02-prd-analysis
  - step-03-epic-coverage-validation
  - step-04-ux-alignment
  - step-05-epic-quality-review
  - step-06-final-assessment
overallStatus: READY — major-issue remediations (M1/M2/M3) applied 2026-05-28
assessor: Product Manager (BMAD bmad-check-implementation-readiness)
remediations:
  applied:
    - id: M1
      story: Epic 3 / Story 3.4
      change: added "Cross-epic anchor" callout noting FR-F7 full validation defers to Story 8.7
    - id: M2
      story: Epic 2 / Story 2.1
      change: added Given/When/Then AC for Message type (id, role MessageRole, content, timestamp, optional toolCallId + name)
    - id: M3
      story: Epic 5 overview
      change: replaced "Agno first, then..." ordering wording with explicit "three independent story groups, any order" clarification
documentsIncluded:
  prd:
    - _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md
    - _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md
  architecture:
    - _bmad-output/planning-artifacts/architecture.md
  epics:
    - _bmad-output/planning-artifacts/epics/index.md
    - _bmad-output/planning-artifacts/epics/overview.md
    - _bmad-output/planning-artifacts/epics/epic-list.md
    - _bmad-output/planning-artifacts/epics/requirements-inventory.md
    - _bmad-output/planning-artifacts/epics/epic-1-workspace-foundation-lint-profile.md
    - _bmad-output/planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md
    - _bmad-output/planning-artifacts/epics/epic-3-test-harness-conformance-koeltest.md
    - _bmad-output/planning-artifacts/epics/epic-4-http-transport-koelhttp.md
    - _bmad-output/planning-artifacts/epics/epic-5-backend-bridges-koelagno-koellanggraph-koelruntime.md
    - _bmad-output/planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md
    - _bmad-output/planning-artifacts/epics/epic-7-widget-primitives-theming-koelwidgets.md
    - _bmad-output/planning-artifacts/epics/epic-8-devtools-extension-koeldevtools.md
    - _bmad-output/planning-artifacts/epics/epic-9-meta-package-sample-app-v100-release-gates.md
  ux: embedded-in-requirements-inventory
  brief:
    - _bmad-output/planning-artifacts/briefs/brief-koel-2026-05-27/brief.md
---

# Implementation Readiness Assessment Report

**Date:** 2026-05-28
**Project:** koel

## Step 1 — Document Discovery ✅

### Inventory

**PRD (sharded):** `prds/prd-koel-2026-05-27/`
- `prd.md` (52 KB) — main PRD
- `addendum.md` (33 KB) — PRD addendum
- Discovery / reconcile / review artifacts present (not duplicate PRDs)

**Architecture (whole):** `architecture.md` (64 KB) — single source of truth

**Epics & Stories (sharded):** `epics/`
- `index.md`, `overview.md`, `epic-list.md`, `requirements-inventory.md` (28 KB)
- 9 epic files (Epic 1 → Epic 9), each containing embedded stories (1.1 → 9.9)

**UX:** No standalone UX document. UX requirements embedded in `requirements-inventory.md` under "UX Design Requirements" — accepted for an SDK with minimal UI surface (only `koelwidgets`, covered by Epic 7).

**Brief:** `briefs/brief-koel-2026-05-27/brief.md` (12 KB)

### Issues Resolved
- ✅ No whole/sharded duplicates
- ✅ Stories present (embedded in epic files)
- ✅ UX strategy confirmed: requirements embedded in inventory + Epic 7 covers widget UI (acceptable for SDK)

---

## Step 2 — PRD Analysis ✅

Sources read in full: `prd.md` (52 KB, 17 sections) + `addendum.md` (33 KB, sections A–H). Canonical FR/NFR/AR inventory cross-checked against `epics/requirements-inventory.md`.

### Functional Requirements

**Total: 50 FRs across 9 groups.** Each FR carries a stable global ID (`F-{group}-{n}` from PRD, mirrored as `FR-{group}{n}` in the inventory).

**Group A — Protocol Foundation (`koel_core`) — 12 FRs**
- FR-A1: `AbstractAgent.run(RunAgentInput) → Stream<AgUiEvent>` two-method atomic kernel
- FR-A2: Three-layer public API (`KoelClient` → `ChatSession` → `runRaw`)
- FR-A3: Hybrid event stream + opt-in `ChatStateReducer`
- FR-A4: dio-style `Interceptor` chain with explicit ordering
- FR-A5: Sealed `KoelError` hierarchy (`TransportError | ProtocolError | AgentError | BusinessError`); errors emitted as `RunErrorEvent`, never thrown
- FR-A6: `UnknownAgUiEvent` forward-compat fallback for unrecognized event types
- FR-A7: Full ~28 AG-UI event types (release/2026-05-26 baseline), `freezed` sealed union
- FR-A8: RFC 6902 JSON-Patch state delta (vendor-inline) + `StateConflict` hook + pluggable resolver
- FR-A9: Reasoning `encryptedValue` opaque round-trip (`Uint8List` + base64 sibling)
- FR-A10: `AgentSubscriber` callback bag (passive observation, multi-subscriber compose)
- FR-A11: 4-stage event pipeline (chunks → verify → apply → transform), pure functions
- FR-A12: `koel_lints` analyzer profile with `exhaustive_switch_must_have_default` principal rule

**Group B — HTTP Transport (`koel_http`) — 6 FRs**
- FR-B1: `HttpAgent` + framework-free `SseParser`
- FR-B2: Six built-in interceptors (Logging, EventTrace, Retry, Auth, Sentry-OFF, PIIRedaction-OFF)
- FR-B3: Cancellation → HTTP abort (TCP close) < 50 ms; silent-drop fallback
- FR-B4: Reconnect & exponential backoff (1s→30s, ±20% jitter, max 5 attempts) + `ConnectionResumed` MetaEvent
- FR-B5: Chunk synthesis (`TOOL_CALL_CHUNK` / `TEXT_MESSAGE_CHUNK` → START/CONTENT/END), default ON
- FR-B6: Connection lifecycle hooks (`onConnect`, `onDisconnect`, `onReconnectAttempt`)

**Group C — Backend Adapters — 3 FRs**
- FR-C1: `koel_agno` — `AgnoAgent` + default-ON `AgnoAuthInterceptor` + agno fixtures
- FR-C2: `koel_langgraph` — `LangGraphAgent` + surface-level `resume(threadId, value)` + LangGraph fixtures
- FR-C3: `koel_runtime` — `CopilotRuntimeAgent` + hand-rolled `MultipartGraphQLStreamParser` (independent of `koel_http`)

**Group D — State, Session & Flutter Glue — 5 FRs**
- FR-D1: `SessionStorage` (interface + InMemory + Hive + Secure), partial-message persistence
- FR-D2: `ChatStateReducer` pure function + `DefaultChatStateReducer` + `ComposedReducer`
- FR-D3: Non-singleton `KoelClient`, multi-client + multi-session
- FR-D4: `KoelChatController extends ChangeNotifier` (LCD Flutter binding)
- FR-D5: `KoelClientScope extends InheritedWidget` (no service locator)

**Group E — Message Content & Generative UI — 4 FRs**
- FR-E1: `MessageContentParser` → `List<MessageSegment>` (`TextSegment | CodeBlockSegment`)
- FR-E2: `WidgetResolver` for generative UI v1 over `TOOL_CALL_*`
- FR-E3: `koel_widgets` — `MessageBubble` (M3 + Cupertino) + `ChatInput` + `FollowUpList`
- FR-E4: `KoelTheme extends ThemeExtension<KoelTheme>`

**Group F — Observability & DevTools (`koel_devtools`) — 7 FRs**
- FR-F1: Flutter DevTools extension (5 tabs: Stream · History · Inspector · Network · Export)
- FR-F2: Live event stream (filter + search + jump-to)
- FR-F3: Time-travel replay (default 1000-event ring buffer, configurable, cached per N)
- FR-F4: Tool-call inspector (tree view per session)
- FR-F5: Network panel (HTTP-level inspector)
- FR-F6: JSON Lines trace export + re-import (`_session` header + per-event timestamp+payload)
- FR-F7: Replay safety (`ToolReplayContext` `InheritedWidget`, no re-execution of tool handlers)

**Group G — Testing & Conformance (`koel_test`) — 4 FRs**
- FR-G1: Captured fixtures from 4 backends (dojo + agno + langgraph + CopilotKit Next.js runtime) covering full event taxonomy + key flows; synthesized fixtures (`synthesized: true`) for un-emitted events
- FR-G2: `MockAgent` — `.fromFixture` / `.fromEvents` / `.programmatic()`
- FR-G3: `ToolHandlerTestHarness` (~5 lines per case)
- FR-G4: `ConformanceRunner.runAgainst(AbstractAgent) → ConformanceReport`

**Group H — Distribution & Versioning — 6 FRs**
- FR-H1: 10-package Melos 7.8.0 monorepo
- FR-H2: Hybrid versioning (foundations lock-step; adapters + Flutter pkgs ranged `^X.Y.0`)
- FR-H3: `koel` meta-package re-exports (`koel_core` + `koel_http` + `koel_flutter`)
- FR-H4: Brand "koel" + 10 pub.dev slots reserved + `ag_ui` 0.1.0 credit
- FR-H5: MIT License per package + repo root
- FR-H6: Docs toolchain (`dart doc` + dedicated docs site framework TBD per OQ-Docs-Framework)

**Group I — Cross-Cutting Hygiene — 3 FRs**
- FR-I1: CI/CD matrix (10 pkgs × 6 platforms, analyze+test+coverage+conformance+publish-dry-run)
- FR-I2: Default-OFF telemetry (Sentry + PII interceptors ship but never auto-register)
- FR-I3: Trademark check ("koel" beyond pub.dev) + `ag_ui` license verification

### Non-Functional Requirements

**Total: 18 NFRs across 5 categories.**

**Performance (regression-relative SLOs) — 5 NFRs**
- NFR-1: SSE parse throughput — ≤ 10% regression vs v1.0.0 baseline
- NFR-2: Reducer p99 latency per event — ≤ 10% regression
- NFR-3: Memory RSS delta — ≤ 10% regression
- NFR-4: Cold-start time — ≤ 10% regression
- NFR-5: Frame budget — no sync UI-thread protocol work; <16 ms streaming jank on CI reference device

**Reliability — 3 NFRs**
- NFR-6: Backpressure — bounded buffer (default 1000), policies `pauseUpstream` (default) | `dropOldest` | `dropNewest`
- NFR-7: Reconnect & retry — exponential backoff w/ jitter, max 5 attempts
- NFR-8: Cancellation determinism — < 50 ms HTTP-abort propagation

**Compatibility — 3 NFRs**
- NFR-9: Dart SDK floor **3.9.0+** (per architecture D1; raised from PRD's original 3.0+; reconciliation tracked as AR-24)
- NFR-10: Flutter SDK floor — first Flutter that ships Dart 3.9 (≈ 3.27+, exact TBD via AR-25; PRD §10.3 says 3.33.0+)
- NFR-11: Six Flutter platforms (iOS, Android, web, macOS, Windows, Linux); web uses hand-rolled fetch+ReadableStream (not `EventSource`)

**Quality & Discipline — 5 NFRs**
- NFR-12: Coverage tiers — foundations (`koel_core`, `koel_http`, `koel_flutter`, `koel_lints`) ≥ 90% line+branch; others ≥ 80%; patch ≥ 85%
- NFR-13: `dart analyze` zero warnings (default + strict + koel_lints) — CI gate
- NFR-14: Zero breaking changes to 1.x public surface — `dart_apitool: ^0.23.1` per-package diff
- NFR-15: Surface minimalism — no public export without `/example` use
- NFR-16: No comments stating code; doc comments explain *why*

**Forward-Compatibility — 2 NFRs**
- NFR-17: New AG-UI event type = minor bump on lock-step foundations (safe iff consumers use `koel_lints`)
- NFR-18: AG-UI breaking protocol change = major bump on foundations; minor/patch on adapters

### Additional Requirements (Architectural)

26 Architectural Requirements (AR-1 → AR-26) from `architecture.md` distilled into the inventory. Categories:

- **Scaffolding (AR-1, AR-2, AR-3):** pub workspace + Melos 7.8.0; `dart create --template=package` / `flutter create --template=package`; `koel_lints` non-standard `custom_lint` structure; bootstrap order pinned.
- **Pinned tech (AR-4 → AR-13):** `freezed: ^3.2.5`; `custom_lint: 0.8.1`; vendor-inline RFC 6902; `package:http`; hand-rolled `SseParser` + web transport (D4 — `package:web` fetch+ReadableStream, not `EventSource`) + multipart GraphQL parser (D5); `devtools_extensions: 0.5.1`; `dart_apitool: ^0.23.1`; bundled JSONL fixtures inside `koel_test/lib/src/fixtures/`.
- **Cross-cutting (AR-14 → AR-23):** fixture-capture pipeline `tool/capture_fixtures.dart`; perf benchmark harness + `BENCHMARKS.md`; AG-UI conformance pin in `koel_core/CONFORMANCE.md`; CI matrix shape (6 workflows); codegen-drift gate (`melos run build && git diff --exit-code`); pipeline boundary discipline (pure `StreamTransformer<AgUiEvent, AgUiEvent>`); adapter boundary (no `src/` imports); documentation contract; sample app at repo root; gap addendums (G-1: AbortController on web; G-2: `melos run build:devtools`; G-3: `koel_lints` self-include exception).
- **PRD reconciliation (AR-24, AR-25, AR-26):** parallel housekeeping to update PRD N-9 (Dart floor), N-10 (Flutter floor), Addendum B.3 (RFC 6902 vendor-inline rationale).

### Constraints & Assumptions

- **AG-UI baseline:** `release/2026-05-26`. Specific commit SHA pinned in `koel_core/CONFORMANCE.md` at v1.0.0 publish.
- **Open Questions (12):** 2 RESOLVED (OQ-Agno-Auth, OQ-Fixtures-Source); 3 block v1.0.0 publish (OQ-Koel-Trademark, OQ-AGUI-License, OQ-Perf-Baseline, OQ-Conformance-Equivalence); rest are v1.x or v2 considerations.
- **Assumptions (7) tracked in `prd.md §16`:** chunk synthesis ON, debug warning on abort drop, time-travel buffer 1000, JSON Lines export shape, `WidgetResolver` signature, `ToolReplayContext` flag sufficiency, regression-relative SLOs need baselines.
- **No UX spec required:** the requirements-inventory.md explicitly states "Not applicable — koel is a technical SDK". Visual surface in `koel_widgets` inherits Material 3 / Cupertino semantics.

### PRD Completeness Assessment

**Strengths:**
- Every FR has a stable global ID (`F-{group}-{n}`) survival-tested across renumbering.
- Every public API symbol is pinned at the type-signature level in `addendum.md §A` — one-way-door contracts are explicit.
- NFRs are CI-enforceable (regression-relative SLOs, coverage tiers, lint gates, API-diff gate) — not vague aspirations.
- Non-goals (NG1–NG8) are enumerated; future work (Future-1 → Future-7) is captured so it isn't rediscovered.
- Assumption ledger + Open Questions both tagged with falsifier/owner/resolution path.
- Counter-metrics (CM-1 → CM-6) catch silent drift.
- Forward-compat policy (FC-1 → FC-4) is principled, not ad-hoc.

**Gaps / Items to verify against epics in next step:**
- 3 OQs block v1.0.0 publish (Trademark, Ag-UI license, Perf baseline, Conformance equivalence) — must surface as concrete stories in Epic 9.
- AR-24/25/26 (PRD reconciliation) — Epic 9 Story 9.7 already mentions them; verify scope coverage.
- G-1, G-2, G-3 gap addendums — should land as stories in respective epics (4, 8, 1).

---

## Step 3 — Epic Coverage Validation ✅

All 9 epic files read in full (~115 stories across 9 epics, story IDs `1.1`–`9.9`). Coverage verified at the *story* level — not just at the inventory's claimed `epic` level.

### Coverage Matrix (FR → Epic → Story)

| FR | Epic | Story | PRD Requirement (summary) | Status |
|---|---|---|---|---|
| FR-A1 | Epic 2 | 2.1 | `AbstractAgent.run()` two-method kernel | ✓ |
| FR-A2 | Epic 2 | 2.14 | Three-layer API (`KoelClient`/`ChatSession`/`runRaw`) | ✓ |
| FR-A3 | Epic 2 | 2.12, 2.14 | Hybrid event stream + opt-in reducer | ✓ |
| FR-A4 | Epic 2 | 2.9 | Interceptor framework (built-ins ship in Epic 4) | ✓ |
| FR-A5 | Epic 2 | 2.3 | Sealed `KoelError` + `KoelErrorCode` + `DefaultErrorClassifier` | ✓ |
| FR-A6 | Epic 2 | 2.2 | `UnknownAgUiEvent` forward-compat fallback | ✓ |
| FR-A7 | Epic 2 | 2.2, 2.5, 2.6, 2.7, 2.8 | All ~28 AG-UI event types + 28-type integration sweep | ✓ |
| FR-A8 | Epic 2 | 2.4, 2.13 | RFC 6902 vendor-inline + `StateConflict` + resolver | ✓ |
| FR-A9 | Epic 2 | 2.7 | Reasoning `encryptedValue` bit-exact opaque round-trip | ✓ |
| FR-A10 | Epic 2 | 2.10 | `AgentSubscriber` callback bag + isolation contract | ✓ |
| FR-A11 | Epic 2 | 2.11 | 4-stage pipeline (chunks → verify → apply → transform) | ✓ |
| FR-A12 | Epic 1 | 1.3, 1.4 | `koel_lints` analyzer profile + adoption across packages | ✓ |
| FR-B1 | Epic 4 | 4.1, 4.2 | `SseParser` + `HttpAgent` native transport | ✓ |
| FR-B2 | Epic 4 | 4.4, 4.5, 4.6, 4.7 | All 6 built-in interceptors (Retry/Auth/Logging/EventTrace/Sentry-OFF/PII-OFF) | ✓ |
| FR-B3 | Epic 4 | 4.3 | Cancellation → HTTP abort < 50 ms + silent-drop fallback | ✓ |
| FR-B4 | Epic 4 | 4.4 | Reconnect + exponential backoff + `ConnectionResumed` | ✓ ⚠️ |
| FR-B5 | Epic 4 | 4.8 | Chunk synthesis ON by default | ✓ |
| FR-B6 | Epic 4 | 4.9 | Connection lifecycle hooks (`onConnect`/`onDisconnect`/`onReconnectAttempt`) | ✓ |
| FR-C1 | Epic 5 | 5.1, 5.2, 5.3 | `AgnoAgent` + `AgnoAuthInterceptor` + agno fixtures + conformance green | ✓ |
| FR-C2 | Epic 5 | 5.4, 5.5, 5.6 | `LangGraphAgent` + surface-level resume + fixtures + classifier + conformance | ✓ |
| FR-C3 | Epic 5 | 5.7, 5.8, 5.9 | `CopilotRuntimeAgent` + hand-rolled multipart GraphQL parser + dojo fallback + conformance | ✓ |
| FR-D1 | Epic 2 + Epic 6 | 2.13 (interface + InMemory) + 6.3 (Hive) + 6.4 (Secure) | `SessionStorage` + 3 implementations + partial-message persistence | ✓ |
| FR-D2 | Epic 2 | 2.12 | `ChatStateReducer` + `Default` + `Composed` + purity test | ✓ |
| FR-D3 | Epic 2 | 2.14 | Non-singleton multi-client + multi-session, no global state | ✓ |
| FR-D4 | Epic 6 | 6.1 | `KoelChatController extends ChangeNotifier` + 5-framework integration | ✓ |
| FR-D5 | Epic 6 | 6.2 | `KoelClientScope extends InheritedWidget` | ✓ |
| FR-E1 | Epic 6 | 6.5 | `MessageContentParser` + sealed `MessageSegment` | ✓ |
| FR-E2 | Epic 6 | 6.6 | `WidgetResolver` + `ToolReplayContext` `InheritedWidget` | ✓ |
| FR-E3 | Epic 7 | 7.2, 7.3 | `MessageBubble` (M3+Cupertino) + `ChatInput` + `FollowUpList` | ✓ |
| FR-E4 | Epic 7 | 7.1 | `KoelTheme extends ThemeExtension<KoelTheme>` | ✓ |
| FR-F1 | Epic 8 | 8.1, 8.2 | `DevToolsObserver` + extension registration + UI skeleton (5 tabs) | ✓ |
| FR-F2 | Epic 8 | 8.3 | Stream panel (live, filter, search, jump-to) | ✓ |
| FR-F3 | Epic 8 | 8.1, 8.4 | Time-travel replay + ring buffer + cached fold | ✓ |
| FR-F4 | Epic 8 | 8.5 | Tool-call inspector | ✓ |
| FR-F5 | Epic 8 | 8.5 | Network panel | ✓ |
| FR-F6 | Epic 8 | 8.6 | JSON Lines export+import + `_session` header round-trip | ✓ |
| FR-F7 | Epic 8 + Epic 6 | 8.7 (logic) + 6.6 (`ToolReplayContext` type) | Replay safety + handler no-op + recorded-result stub | ✓ |
| FR-G1 | Epic 3 + Epic 5 | 3.2 (synth + storage) + 5.3/5.6/5.9 (real captured) | Fixtures from 4 backends + synthesized fallback | ✓ |
| FR-G2 | Epic 3 | 3.1, 3.3 | `MockAgent` — `.fromEvents()`/`.programmatic()`/`.fromFixture()` | ✓ |
| FR-G3 | Epic 3 | 3.4 | `ToolHandlerTestHarness` (~5 lines/case) | ✓ |
| FR-G4 | Epic 3 + Epic 5 | 3.5 (skeleton + `CONFORMANCE.md`) + 5.3/5.6/5.9 (green per adapter) | `ConformanceRunner.runAgainst()` | ✓ |
| FR-H1 | Epic 1 | 1.1, 1.2, 1.6 | 10-package Melos monorepo + `CONTRIBUTING.md` | ✓ |
| FR-H2 | Epic 9 | 9.1, 9.9 | Hybrid versioning + `^X.Y.0` ranges + publish orchestration | ✓ |
| FR-H3 | Epic 9 | 9.1 | `koel` meta-package re-exports | ✓ |
| FR-H4 | Epic 1 | 1.6 | Brand + 11 pub.dev slots + `ag_ui` credit-line stub | ✓ |
| FR-H5 | Epic 1 | 1.6 | MIT License — every package + repo root | ✓ |
| FR-H6 | Epic 9 | 9.6 | Docs site scaffold + per-package READMEs + `dart doc` | ✓ |
| FR-I1 | Epic 1 + Epic 9 | 1.5 (skeleton) + 9.3 (api-diff) + 9.4 (perf-bench) + 9.5 (conformance+publish-dry-run) | All 6 CI workflows green | ✓ |
| FR-I2 | Epic 4 | 4.7 | Default-OFF Sentry + PII interceptors | ✓ |
| FR-I3 | Epic 9 | 9.8 | Trademark check + `ag_ui` license verification | ✓ |

### NFR Coverage Matrix

| NFR | Epic | Story | Status |
|---|---|---|---|
| NFR-1 (SSE parse throughput baseline + ≤10% regression) | Epic 4 | 4.10 (sse_parse_bench) | ✓ |
| NFR-2 (reducer p99 ≤10% regression) | Epic 2 | 2.15 (reducer_bench) | ✓ |
| NFR-3 (memory RSS ≤10% regression) | Epic 6 | 6.8 (chat_session_memory_bench) | ✓ |
| NFR-4 (cold-start ≤10% regression) | Epic 2 | 2.15 (cold_start_bench) | ✓ |
| NFR-5 (frame budget / streaming jank) | Epic 6 | 6.8 (streaming_jank_bench) | ✓ |
| NFR-6 (backpressure: pause/dropOldest/dropNewest) | Epic 2 | 2.14 (KoelClient constructor accepts param) | ⚠️ partial |
| NFR-7 (reconnect+retry + exponential backoff) | Epic 4 | 4.4 | ✓ |
| NFR-8 (cancellation < 50 ms) | Epic 4 | 4.3 | ✓ |
| NFR-9 (Dart 3.9+ floor) | Epic 1 + Epic 9 | 1.1 (pubspec constraint) + 9.7 (AR-24 PRD reconcile) | ✓ |
| NFR-10 (Flutter floor) | Epic 1 + Epic 9 | 1.2 (`flutter: ">=3.27.0"`) + 9.7 (AR-25 reconcile) | ✓ |
| NFR-11 (six platforms) | Epic 4 + Epic 6 | 4.10 (web transport) + 6.7 (six-platform CI smoke) | ✓ |
| NFR-12 (coverage tiers) | every package's final-step story | 1.4, 2.15, 3.5, 4.10, 5.3/5.6/5.9, 6.8, 7.4, 8.7 | ✓ |
| NFR-13 (`dart analyze` clean) | Epic 1 + every package's final story | as above | ✓ |
| NFR-14 (zero breaking → `dart_apitool`) | Epic 9 | 9.3 | ✓ |
| NFR-15 (surface minimalism — CI diff symbols vs `/example`) | Epic 9 | — (NOT EXPLICITLY TRACED) | ⚠️ gap |
| NFR-16 (no comments stating code) | Epic 1 (convention) + every dartdoc story | 1.6, 2.15, 6.8, 9.6 | ✓ |
| NFR-17 (new event = lock-step minor bump, lints-enforced) | Epic 1 + Epic 9 | 1.7 (asp lints; supersedes 1.3/1.4) + 9.6 (migration guide doc) | ✓ |
| NFR-18 (AG-UI breaking = major bump) | Epic 9 | 9.7, 9.9 (release discipline) | ✓ |

### Architectural Requirement (AR) Coverage

26/26 architectural requirements traceable. Highlights:

> _Erratum (SCP-2026-05-29): AR-5 reversed `custom_lint 0.8.1` → `analysis_server_plugin: ^0.3.15`; the lint mechanism of Stories 1.3/1.4 is superseded by re-scoped **Story 1.7**. See `sprint-change-proposal-2026-05-29.md`._

| AR | Story |
|---|---|
| AR-1 → AR-3 (workspace+Melos, scaffold, bootstrap order) | 1.1, 1.2 |
| AR-4 (`freezed: ^3.2.5`) | 2.1 |
| AR-5 (`analysis_server_plugin: ^0.3.15` — was `custom_lint: 0.8.1`) | 1.7 (re-scoped; SCP-2026-05-29) |
| AR-6 (vendor-inline RFC 6902) | 2.4 |
| AR-7 (`package:http`) | 4.2 |
| AR-8 (hand-rolled `SseParser`) | 4.1 |
| AR-9 (web transport via `package:web` fetch+ReadableStream+AbortController) | 4.10 |
| AR-10 (hand-rolled `MultipartGraphQLStreamParser`) | 5.7 |
| AR-11 (`devtools_extensions: 0.5.1`) | 8.2 |
| AR-12 (`dart_apitool: ^0.23.1`) | 9.3 |
| AR-13 (bundled fixtures in `koel_test/lib/src/fixtures/`) | 3.2 |
| AR-14 (fixture-capture pipeline) | 3.5 (scaffold) + 5.3/5.6/5.9 (execution) |
| AR-15 (perf bench harness) | 2.15, 4.10, 6.8 + 9.4 (release artifacts) |
| AR-16 (AG-UI conformance pin) | 3.5 + 9.9 (finalize SHA) |
| AR-17 (CI matrix shape — 6 workflows) | 1.5 (skeleton) + complete in 4.10, 5.3, 6.7, 9.3, 9.4, 9.5 |
| AR-18 (codegen orchestration + drift gate) | 1.5 (codegen-drift.yml) + 2.1 (`build.yaml`) |
| AR-19 (pipeline boundary discipline) | 2.11 |
| AR-20 (adapter boundary contract — no `src/` imports + per-adapter classifier) | 5.2, 5.6, 5.7+5.8 (no koel_http dep) |
| AR-21 (documentation contract — README/CHANGELOG/LICENSE) | 1.6 + 9.6 |
| AR-22 (sample app at repo root) | 9.2 |
| AR-23 G-1 (AbortController on web) | 4.10 |
| AR-23 G-2 (`melos run build:devtools`) | 8.2 + 8.7 |
| AR-23 G-3 (`koel_lints` self-include exception) | 1.3 |
| AR-24 → AR-26 (PRD reconciliation) | 9.7 |

### Missing / Partial Coverage (require attention)

#### ⚠️ Minor gap — NFR-6 (Backpressure policy) — partial coverage
**PRD says:** Three policies (`pauseUpstream` default, `dropOldest`, `dropNewest`) with loss counter logged at warning level (Addendum C.5).
**Epic coverage:** Story 2.14 wires `BackpressurePolicy backpressure = BackpressurePolicy.pauseUpstream` as a constructor param. **No story has explicit acceptance criteria that exercises all three policies under buffer-overflow conditions or verifies the loss counter.**
**Recommendation:** Add an explicit AC bullet to Story 2.14 (preferred) or Story 4.x — e.g. "Given a `KoelClient.backpressure = dropOldest`, when the buffer fills mid-stream, then oldest events are evicted and a warning log emits with a monotonic loss counter."

#### ⚠️ Minor gap — NFR-15 (Surface Minimalism CI script) — NOT TRACED
**PRD §10.4 N-15 + §5.1 SC-5 say:** "A CI script diffs `package:koel_*` public symbols against `/example` usage and the dartdoc cross-reference graph."
**Epic coverage:** Story 9.6 covers per-package READMEs + `dart doc`. Story 9.3 covers `dart_apitool` for breaking-change diff (NFR-14, different concern). **The vestigial-export detection script is not traced to any story.**
**Recommendation:** Either (a) add a story to Epic 9 ("Vestigial-export detector CI step") or (b) demote the SC-5 enforcement from "ship gate" to "post-v1 hygiene" if the script proves infeasible in the v1 timeframe — surfaced as a decision for P1.

#### ℹ️ Design clarification — `ConnectionResumed` `MetaEvent`
**PRD F-B4 + N-7:** "Emits a `ConnectionResumed` `MetaEvent` on reconnect."
**Story 4.4 chooses:** model it as `CustomEvent(name: "koel.connection_resumed")` — pragmatic because Addendum A.1 has no `MetaEvent` class; reuses the existing sealed-union surface. Reasonable engineering call; **suggest a one-line note in PRD §F-B4 or Addendum to lock the design** so it isn't relitigated later.

#### ℹ️ Open Questions still flagged in PRD (3 v1-blocking) — all traced to Epic 9
- OQ-Koel-Trademark → Story 9.8 ✓
- OQ-AGUI-License → Story 9.8 ✓
- OQ-Perf-Baseline → Story 9.4 ✓
- OQ-Conformance-Equivalence → Story 3.5 (rule documented) + Story 9.9 (final SHA) ✓
- OQ-Docs-Framework → Story 9.6 (resolved as part of docs scaffold) ✓

### Coverage Statistics

- **Total PRD FRs:** 50
- **FRs covered in epics (story-level traceable):** 50
- **FR coverage:** **100%** ✅
- **Total PRD NFRs:** 18
- **NFRs fully traceable:** 16
- **NFRs partial/gap:** 2 (NFR-6 partial; NFR-15 not traced)
- **NFR coverage:** **89%** (16/18 unambiguous; 2 with notes)
- **Total Architectural Requirements:** 26
- **ARs traceable to specific stories:** 26
- **AR coverage:** **100%** ✅

### Verdict

Coverage is **exceptionally rigorous** for an SDK plan: every FR has a story-level home (often several), every backbone AR maps to a concrete pubspec/script/file location, and the OQ-Resolution-by-Epic chain closes the v1.0.0 publish gates. Two small documentation/test gaps (NFR-6 explicit overflow tests; NFR-15 vestigial-export CI script) are worth threading into Stories 2.14 / 9.x respectively, but neither blocks epic execution.

---

## Step 4 — UX Alignment ✅

### UX Document Status

**Not found** as a standalone artifact. No `ux.md`, `ux/` folder, `ui-spec.md`, or `wireframes/` directory exists under `_bmad-output/planning-artifacts/`. The `requirements-inventory.md §"UX Design Requirements"` section explicitly states:

> *Not applicable. koel is a technical SDK — no UI/UX specification document. Visual design surface (`koel_widgets` M3 + Cupertino bubble, ChatInput, FollowUpList, `KoelTheme`) is owned by Group E features (FR-E3, FR-E4) and inherits Material 3 / Cupertino design system semantics without a dedicated UX spec.*

### Assessment: Is UX Implied?

**Partially.** Two distinct UI surfaces exist within koel:

1. **`koel_widgets` (Epic 7) — consumer-facing chat UI primitives.**
   - Surfaces: `MessageBubble` (M3 + Cupertino), `ChatInput`, `FollowUpList`, `KoelTheme`.
   - PRD §F-E3 + §F-E4 specify these as opt-in widgets; design intent = inherit platform design language (Material 3 / Cupertino) rather than impose a koel-specific visual identity.
   - Epic 7 Story 7.4 includes **4 golden tests** (material-light, material-dark, cupertino-light, cupertino-dark) — visual contract is *executable*, not paper.
   - This is an acceptable substitute for a UX spec **because** the design language is intentionally borrowed from the host platform; koel does not define a brand-level visual system. The token surface (`KoelColors`, `KoelTextStyles`, `KoelSpacing` in Story 7.1) is the structural contract; semantics are platform-conventional.

2. **`koel_devtools` extension UI (Epic 8) — developer-facing DevTools panel.**
   - 5 tabs: Stream · History · Inspector · Network · Export.
   - PRD §F-F1 + Addendum §G specify the panel taxonomy (referenced from CopilotKit `@copilotkit/web-inspector`).
   - Epic 8 stories 8.3, 8.4, 8.5, 8.6 each include acceptance criteria for **what each panel renders** (filter chips, timeline scrubbing, tree views, download flow) but **do not include visual mockups or layout specs**.
   - Risk: open-ended visual decisions during implementation could drift between panels. **Mitigatable** by accepting CopilotKit's `@copilotkit/web-inspector` as the reference comparable (PRD Addendum §E lists it as the design source).

### UX ↔ PRD Alignment

| UX Surface | PRD FR | Coverage |
|---|---|---|
| `MessageBubble` M3 + Cupertino variants | FR-E3 | ✓ explicit |
| `ChatInput` auto-grow + attachment slot | FR-E3 | ✓ explicit |
| `FollowUpList` suggested-prompts row | FR-E3 | ✓ explicit |
| `KoelTheme` token surface | FR-E4 | ✓ explicit |
| DevTools 5-tab panel taxonomy | FR-F1, F-F2..F-F6 | ✓ structural (per-tab features named) |
| Light + dark theme variants | inferred from `KoelTheme.light()`/`KoelTheme.dark()` factories in Story 7.1 | ✓ inferred, not in PRD body |

### UX ↔ Architecture Alignment

| Architecture concern | UX implication | Coverage |
|---|---|---|
| `koel_widgets` opt-in (never required by `koel_flutter`) | Consumers can replace widgets entirely | ✓ Epic 7 overview |
| Theming via `ThemeExtension<KoelTheme>` (Story 7.1) | Native Flutter pattern, M3 + Cupertino-friendly | ✓ |
| DevTools = Flutter web app under `tool/extension_ui/` (Story 8.2) | Visual constraints inherit from `devtools_extensions: 0.5.1` package (iFrame-embedded) | ✓ structurally |
| Streaming UI — frame budget < 16 ms (NFR-5) | UX-quality concern (jank perception) | ✓ enforced via `streaming_jank_bench` (Story 6.8) |

### Alignment Issues

1. **DevTools panel visual specs are functional, not visual.** The acceptance criteria for Stories 8.3–8.6 describe *behavior* (filters work, timeline scrubs, tree expands) but not *layout* (where do filter chips live? what's the column ratio?). For a one-developer passion project, this is fine — implementation produces visual decisions inline, judged by the six-month re-read test. For a third-party consumer of `koel_devtools`, mild risk of inconsistency. **Recommend:** add a single screenshot or wireframe to `_bmad-output/` referencing CopilotKit's `@copilotkit/web-inspector` as the visual benchmark, OR explicitly call this out as "visual implementation decided during Epic 8" in the epic overview.

2. **`koel_widgets` golden tests are the visual contract.** Story 7.4's 4 goldens (material-light, material-dark, cupertino-light, cupertino-dark) are the de-facto UX spec. **No misalignment** — but worth recognizing as such so future contributors don't expect a separate UX doc.

### Warnings

- ⚠️ **Low-severity warning:** DevTools panel layout/visual decisions are not pre-specified. Acceptable given the project shape (passion SDK, single maintainer, design DNA = "infra deep, business out") but should be acknowledged in Epic 8 overview.
- ✅ **No-blocker:** absence of standalone UX doc is correctly justified by SDK-nature and the surface-by-tokens approach in `koel_widgets`.

### Verdict

UX strategy is **internally consistent with project shape**: an SDK whose only consumer-facing visual surface (`koel_widgets`) borrows host-platform design languages and ships golden-tested tokens. The DevTools UI inherits its taxonomy from a named reference (CopilotKit web-inspector) but its visual specifics defer to implementation. **No standalone UX doc required for v1.**

---

## Step 5 — Epic Quality Review ✅

Each epic and story evaluated against create-epics-and-stories best practices, calibrated for an SDK (where "user" = Flutter/Dart developer consuming the SDK per PRD §3 personas P1/P2/P3).

### Best-Practices Compliance — Per Epic

| Epic | Delivers user value | Independent | Stories sized | No forward deps | Clear ACs | FR traceable |
|---|---|---|---|---|---|---|
| Epic 1 — Workspace Foundation | ✓ (clone→bootstrap→compile green; serves P3 contributor) | ✓ | ✓ | ✓ | ✓ | ✓ |
| Epic 2 — `koel_core` | ✓ (KoelClient + 28-event sweep against MockAgent) | needs Epic 1 (workspace + lints) — ✓ backward | ✓ | ✓ | ✓ | ✓ |
| Epic 3 — `koel_test` | ✓ (`MockAgent.fromFixture()`) | needs Epic 1, 2 — ✓ backward | ✓ | ⚠️ 1 soft fwd dep (see below) | ✓ | ✓ |
| Epic 4 — `koel_http` | ✓ (connect to any AG-UI SSE endpoint) | needs Epic 1–3 — ✓ backward | ✓ | ✓ | ✓ | ✓ |
| Epic 5 — Backend Bridges | ✓ (`AgnoAgent` / `LangGraphAgent` / `CopilotRuntimeAgent` one-liner) | needs Epic 1–4 — ✓ backward | ✓ | ✓ | ✓ | ✓ |
| Epic 6 — `koel_flutter` | ✓ (`KoelChatController`, six-platform integration) | needs Epic 1–3 — ✓ backward | ✓ | ✓ | ✓ | ✓ |
| Epic 7 — `koel_widgets` | ✓ (drop-in MessageBubble + ChatInput + theme) | needs Epic 6 — ✓ backward | ✓ | ✓ | ✓ | ✓ |
| Epic 8 — `koel_devtools` | ✓ (DevTools panel with live event stream + replay) | needs Epic 1, 2, 6 — ✓ backward | ✓ | ✓ | ✓ | ✓ |
| Epic 9 — Meta + Sample + Release Gates | ✓ (`dart pub add koel` quickstart + v1.0.0 publish) | needs Epic 1–8 — ✓ backward | ✓ | ✓ | ✓ | ✓ |

### Specific Findings

#### 🔴 Critical Violations
**None.** No technical-milestone epic without user-developer outcome, no broken epic-independence, no story sized as an epic.

#### 🟠 Major Issues

**M1. Soft forward dependency in Epic 3 Story 3.4 (`ToolHandlerTestHarness` + replay path).**
- **Issue:** Story 3.4 exercises a replay scenario using a "stub flag" because `ToolReplayContext` doesn't exist until Epic 6 Story 6.6. The story explicitly says: *"the type is defined in Story 6.6 — Epic 6; this Epic 3 story ships only the harness scaffold and exercises the replay path via a stub flag"*.
- **Why this is borderline OK:** The story is *completable* with the stub and the cross-epic deferral is openly acknowledged (good engineering hygiene). FR-F7 full validation lands in Epic 8 Story 8.7.
- **Why it's still worth a note:** Reviewers should not interpret a green Story 3.4 as full FR-F7 coverage. Traceability matrix already encodes this (FR-F7 = Epic 8 Story 8.7 + Epic 6 Story 6.6 for the type).
- **Recommendation:** Add a one-line cross-reference to Story 8.7 in Story 3.4's acceptance criteria header so the deferral is documented in the story's success contract, not just its prose.

**M2. `Message` type defined in user-story but missing from acceptance criteria — Epic 2 Story 2.1.**
- **Issue:** Story 2.1's user-story names four contracts: *"`AbstractAgent.run()`, `RunAgentInput`, `ToolDefinition`, `Message`"*. The acceptance criteria explicitly cover `AbstractAgent`, `RunAgentInput`, `ToolDefinition`, and `build.yaml` — but **no AC bullet enforces the existence/shape of the `Message` class**. `Message` is referenced downstream (`ChatState.messages`, `RunAgentInput.messages: List<Message>`).
- **Recommendation:** Add an AC bullet to Story 2.1: *"Given `koel_core/lib/src/message/message.dart`, when I inspect it, then `Message` is a freezed type with role / content / id / timestamp fields per AG-UI spec, and is the type used by `RunAgentInput.messages` and `ChatState.messages`."*

**M3. Story 5.1–5.9 partitioning by backend — clarify ordering freedom.**
- **Issue:** Epic 5 overview says *"Stories partition cleanly per backend (3 sets of stories — Agno first, then LangGraph, then CopilotKit runtime, in independent order)."* The phrasing "Agno first" appears to dictate order, then "in independent order" contradicts it. In practice the three groups (5.1–5.3 agno; 5.4–5.6 langgraph; 5.7–5.9 CopilotKit) are mutually independent — execution order can flex with backend availability.
- **Recommendation:** Reword overview to: *"Three independent story groups — 5.1–5.3 (agno), 5.4–5.6 (langgraph), 5.7–5.9 (CopilotKit runtime). Groups can be scheduled in any order; numbering preserves a default reading order, not an execution requirement."*

#### 🟡 Minor Concerns

**N1. `MESSAGES_SNAPSHOT` reducer behavior not explicitly enumerated in Story 2.12 AC.**
- The AC lists reducer handling for `RUN_*`, `TEXT_MESSAGE_*`, `TOOL_CALL_*`, `STATE_*`, `REASONING_ENCRYPTED_VALUE`, `RunErrorEvent`, `UnknownAgUiEvent` — but `MESSAGES_SNAPSHOT` (which replaces the full message list per AG-UI spec) is not named.
- Likely covered under the catch-all, but worth one extra AC bullet for completeness.

**N2. NFR-15 vestigial-export CI script — not traced (already flagged in Step 3).**
- PRD SC-5 / N-15 says a CI script diffs `package:koel_*` public symbols against `/example` usage. Not in Epic 9 stories.
- If SC-5 is a v1.0.0 ship gate (PRD §5.1), this needs a story. Otherwise demote to post-v1 hygiene.

**N3. NFR-6 (Backpressure policy) — no story explicitly tests all three policies (already flagged in Step 3).**
- `BackpressurePolicy` enum constructed in Story 2.14, but no AC exercises `dropOldest` / `dropNewest` overflow paths or the loss counter.

**N4. Story 9.1 — `koel` meta-package barrel is `≤ 6 LOC` per AC.**
- Constraint is precise and verifiable. Reasonable but inflexible — if a single optional re-export gets added later, the constraint forces a story-revision rather than a metric update. Not a blocker; flagging the rigidity.

**N5. Story 4.4 — `ConnectionResumed` modeled as `CustomEvent(name: "koel.connection_resumed")`.**
- PRD §F-B4 says *"emits a `ConnectionResumed` `MetaEvent`"*. No `MetaEvent` type is defined in Addendum A.1. Story 4.4 pragmatically reframes this as a `CustomEvent`.
- This is a sensible design call; suggest landing a PRD touchpoint (one-line in §F-B4 or Addendum) so the choice is recorded canonically rather than only in the story.

**N6. Story 1.6 brand-reservation AC depends on external pub.dev state.**
- *"All eleven names are reserved to the owner account ahead of pre-publish"* — not CI-enforceable; relies on `_bmad-output/planning-artifacts/brand-reservation.md` as evidence.
- Acceptable for a passion-project SDK; flagging as a non-mechanical AC.

**N7. Story 9.6 still has an open decision — OQ-Docs-Framework.**
- *"OQ-Docs-Framework resolved (Docusaurus vs Nextra vs alternative — decision committed)"* — the AC requires resolution but does not name a candidate. PRD confirms this does not block code work, only the docs site deploy.
- Acceptable; flagged as a known pre-condition for Story 9.6.

### Story Quality — Sampling Observations

**Strengths consistently observed:**
- ACs use rigorous Given/When/Then with exact file paths (`packages/koel_core/lib/src/event/run_events.dart`), exact API signatures (often referencing Addendum §A line numbers), exact LOC targets (`< 250 LOC`, `~150 LOC`), exact coverage thresholds (`≥ 90% per NFR-12`), exact perf gates (`> 10% regression blocks merge`).
- Property-based tests appear in multiple stories (2.3 error classifier, 2.7 reasoning round-trip, 6.5 markdown parser, 8.1 ring buffer invariants). This is unusually mature for an SDK plan.
- Dependency hygiene is **explicitly stated** in stories that ship out-of-order types: Story 2.3 says *"This story ships error types BEFORE event subtypes because `RunErrorEvent.error: KoelError` (Story 2.5) depends on them"*. Story 2.4 has the analogous note for `JsonPatchOp` vs `StateDeltaEvent`. This kind of explicit dependency awareness is exemplary.
- Cross-epic anchors are explicit: Story 8.7 says *"using the InheritedWidget from Story 6.6"*. Story 5.3 references *"`conformance.yml` (extended here from Story 1.5's skeleton)"*. This makes story-graph navigation tractable.

**One pattern worth recognizing:**
- Final-step package stories (2.15, 3.5, 4.10, 6.7+6.8, 7.4, 8.7, 9.x) bundle multiple concerns (perf baselines + dartdoc + barrel + coverage gate). For an SDK, this "package finalize" bundling is appropriate — these concerns are read together by the publisher. The alternative (4 sub-stories per package finalize) would inflate the story count without operational benefit.

### Special Implementation Checks

- **Starter template?** No — architecture (AR-1, AR-2) deliberately rejects starter templates (`very_good_cli` conflicts with `koel_lints`). Epic 1 Stories 1.1 + 1.2 correctly hand-author the workspace + use `dart create --template=package` / `flutter create --template=package` per package. ✓
- **Database table creation?** N/A — no database.
- **Greenfield indicators?** Epic 1 ships workspace setup, dev environment config (Dart 3.9.0+, Melos 7.8.0), and the 6-workflow CI skeleton. ✓
- **Brownfield indicators?** N/A — clean-slate rewrite per PRD NG8 ("no migration tooling from `ag_ui` 0.1.0").

### Best-Practices Compliance Verdict

- **Critical violations:** 0
- **Major issues:** 3 (M1 soft forward dep; M2 missing `Message` AC; M3 Epic 5 ordering phrasing)
- **Minor concerns:** 7 (N1 reducer family; N2 vestigial export script; N3 backpressure policies; N4 6-LOC rigidity; N5 ConnectionResumed type; N6 manual brand-reservation; N7 docs framework)

**All findings are remediable with small edits.** None blocks epic execution. Aggregate plan quality is **well above typical SDK-readiness baseline** — explicit story-level dependency awareness, property-based test asks, exact-spec acceptance criteria, and cross-epic anchors are unusually rigorous.

---

## Summary and Recommendations

### Overall Readiness Status

# ✅ READY — with 3 minor remediations recommended pre-Epic-1-start

The plan is implementation-ready. Phase 4 can commence on Epic 1 immediately. Three small story-level edits are recommended to close minor traceability and AC gaps, but none blocks epic execution. The remediations can land as the first PR inside Epic 1 if desired.

### Scorecard

| Dimension | Result | Notes |
|---|---|---|
| Document set complete | ✅ | PRD + Addendum + Architecture + Epics-with-Stories + Requirements Inventory all present and consistent |
| FR coverage | **50 / 50** | 100% traceable to story-level homes |
| NFR coverage | **16 / 18 unambiguous** | 2 partial (NFR-6 backpressure policies; NFR-15 vestigial-export script) |
| AR coverage | **26 / 26** | every architectural requirement maps to a specific file/script/story |
| Epic independence | ✅ | All 9 epics use backward dependencies only |
| Story sizing | ✅ | Stories scoped to file+test units; bundled finalization stories appropriate for SDK |
| Acceptance criteria quality | ✅ exceptional | Given/When/Then with exact paths, signatures, LOC targets, perf gates |
| UX | ✅ justified absence | SDK with platform-conventional widget surface (M3 + Cupertino, golden-tested) |
| Critical violations | **0** | — |
| Major issues | **3** | M1 soft fwd dep; M2 missing `Message` AC; M3 Epic 5 ordering wording |
| Minor concerns | **7** | N1–N7 — see Step 5 |

### Critical Issues Requiring Immediate Action

**None.** No critical violations were found.

### Recommended Next Steps (in priority order)

**Pre-Epic-1 major remediations — ✅ APPLIED 2026-05-28**

1. ~~**Fix M2 — add `Message` AC to Epic 2 Story 2.1.**~~ ✅ **DONE** — Story 2.1 now has an explicit Given/When/Then bullet pinning `Message` as freezed with `id` / `role: MessageRole` (enum: user/assistant/system/tool) / `content` / `timestamp` plus optional `toolCallId` + `name`, used by `RunAgentInput.messages` and `ChatState.messages`.

2. ~~**Fix M3 — reword Epic 5 overview to clarify story-group ordering freedom.**~~ ✅ **DONE** — Epic 5 overview now reads: *"Three independent story groups — 5.1–5.3 (agno), 5.4–5.6 (langgraph), 5.7–5.9 (CopilotKit runtime) — can be scheduled in any order. Story numbering preserves a default reading order, not an execution requirement; pick the group whose backend is easiest to deploy locally first."*

3. ~~**Fix M1 — add cross-epic anchor to Epic 3 Story 3.4 AC.**~~ ✅ **DONE** — Story 3.4 now opens with a callout block: *"This story exercises the replay path via a stub flag because `ToolReplayContext` does not exist until Epic 6 Story 6.6 ... full FR-F7 contract validation defers to Story 8.7."*

**During Epic 2 (when finalizing Story 2.12):**

4. **Address N1 — add `MESSAGES_SNAPSHOT` to Story 2.12 reducer AC list.**

5. **Address N3 — add an AC in Story 2.14 that exercises all three `BackpressurePolicy` values under buffer-overflow conditions.**

**During Epic 9 (release-gate planning):**

6. **Decide on N2 — NFR-15 vestigial-export CI script.** Either add a story to Epic 9 ("Vestigial-export detector CI step"), or formally demote SC-5 from ship-gate to post-v1 hygiene with a PRD note.

7. **Resolve N7 — OQ-Docs-Framework decision** (Docusaurus vs Nextra vs alternative). Required before Story 9.6 can complete. Does not block code work.

**Anytime before Epic 4 implementation:**

8. **Address N5 — land a one-line PRD touchpoint** clarifying that `ConnectionResumed` rides as `CustomEvent(name: "koel.connection_resumed")` rather than a new `MetaEvent` class. Either PRD §F-B4 or Addendum A.1 is a reasonable home.

### Strengths Worth Preserving

The following plan characteristics are unusually strong and should be maintained as the codebase grows:

- **Stable global FR IDs (`F-{group}-{n}`)** survive renumbering across documents.
- **Story-level dependency awareness** is explicit (Story 2.3 notes why errors ship before events; Story 2.4 notes why JsonPatchOp ships before StateDeltaEvent).
- **Property-based tests are first-class** in ACs (Story 2.3 error classifier, Story 2.7 reasoning round-trip, Story 6.5 markdown parser, Story 8.1 ring buffer).
- **Perf gates are regression-relative** with v1.0.0 baselines published as release artifacts — enforceable without aspirational absolute numbers.
- **Cross-epic anchors** are written into ACs (Story 8.7 references the Story 6.6 InheritedWidget; Story 5.3 references the Story 1.5 conformance.yml skeleton). The story graph is navigable.
- **OQ → Epic resolution map** is closed: every v1-blocking OQ has a Story 9.x with a verification artifact.

### Final Note

This assessment identified **10 findings across 3 severity tiers** (0 critical, 3 major, 7 minor). None of the findings blocks epic execution. The recommended remediations are small AC edits — actionable within minutes, ideally batched as a single "pre-flight cleanup" commit before Epic 1 Story 1.1 begins. The plan, taken as a whole, demonstrates rigor consistent with the project's stated design DNA — *"infra deep, business out; modular by discipline; opinionated about cross-cutting craftsmanship."* You can proceed to Phase 4 implementation.

**Report generated:** 2026-05-28
**Assessor:** Product Manager (BMAD bmad-check-implementation-readiness workflow)
**Output file:** [_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-28.md](_bmad-output/planning-artifacts/implementation-readiness-report-2026-05-28.md)

