---
title: PRD ↔ Brainstorming Reconciliation
status: audit
created: 2026-05-27
authoritative_source: _bmad-output/brainstorming/brainstorming-session-2026-05-27-1736.md
target: prd.md + addendum.md
---

# Reconciliation — koel PRD vs Brainstorming Session

The brainstorming session is the authoritative design reference per user memory. This audit confirms the PRD faithfully carries every committed idea and surfaces any drift.

## 1. Idea-by-Idea Mapping (20 ideas)

| # | Brainstorming Idea | PRD Feature ID(s) | Verdict |
|---|---|---|---|
| 1 | Two-Method Atomic Client (`run` + cancel) | **F-A1** | Faithful. `AbstractAgent.run() → Stream<AgUiEvent>` + cancellation per F-B3. |
| 2 | Three-Layer Public API (Client / Session / Raw) | **F-A2**, §9 (`KoelClient` / `ChatSession` / `client.run`) | Faithful. Raw escape hatch in `KoelClient.run` (addendum A.1). |
| 3 | Hybrid Event Stream + Opt-In Reducer | **F-A3**, **F-D2** | Faithful. Pure-function reducer, `ComposedReducer` available. |
| 4 | Interceptor Chain (dio-style) | **F-A4**, **F-B2** | Faithful. 6 built-in interceptors; `AuthInterceptor` for token providers. |
| 5 | App Owns Business-Logic Safety | **NG6**, prose in §1 "infra deep, business out" | Faithful. No tool-confirmation middleware in v1. |
| 6 | Modular Multi-Package (9 packages) | **F-H1**, §7 architecture table | Faithful. 9 packages + `koel` meta. |
| 7 | Brand-New Name, No Protocol Prefix | **NG2**, **F-H4** | Faithful. Explicit non-goal on SEO naming. |
| 8 | Brand: `koel` | **F-H4** | Faithful. Hindi/cuckoo etymology preserved. |
| 9 | Rewrite Clean Slate + Inspired-By Credit | **NG8**, **F-H4**, **F-I3** (`OQ-AGUI-License`) | Faithful. One-line README credit, no migration path. |
| 10 | SessionStorage Adapter + Partial Persistence | **F-D1** | Faithful. 3 implementations; `isComplete: false` on interrupted messages. |
| 11 | MessageContentParser + Deferred A2UI | **F-E1**, **NG5** | Faithful. Segments shipped; `koel_a2ui` explicitly deferred. |
| 12 | Sealed Error Hierarchy via RunErrorEvent | **F-A5**, addendum A.1 (`KoelError`) | Faithful. 4 sealed subtypes, ride RunErrorEvent. **Minor drift:** brainstorming mentioned `KoelErrorCode` enum + `ErrorClassifier`; PRD uses `BusinessError(details: Map)` instead — looser typing than promised. |
| 13 | Interceptor + DevTools Extension Combo | **F-F1–F-F7**, **F-B2** | Faithful. All 5 DevTools tabs (Stream/History/Inspector/Network/Export) preserved. |
| 14 | ChangeNotifier Universal Glue | **F-D4**, **G5** | Faithful. Per-state-mgmt adapters deferred to community. |
| 15 | Hybrid Versioning (foundation lock-step + adapters independent) | **F-H2**, **R-2**, **R-3** | Faithful. |
| 16 | Multi-Session Multi-Client, No Isolate v1 | **F-D3**, **NG6** (isolate deferred) | Faithful. Non-singleton `KoelClient`. |
| 17 | V1 Quality Bar: Production-Ready, Not Preview | **§5.1 ship gates**, **R-4**, **R-5** | Faithful. v1 ships only when SC-1–SC-5 green. |
| 18 | Passion-Driven Craft (adoption ≠ success) | **§1 Vision**, **NG1**, **§5.4 non-criteria** | Faithful. Zero adoption is a "valid outcome." |
| 19 | Mitigations Reframed as Engineering Hygiene | **F-A6** (`UnknownAgUiEvent`), **F-I2** (default-OFF telemetry), **F-H3** (meta-package), **F-I1** (CI matrix), **F-G4** (conformance suite) | Faithful. All 5 mitigations present as hygiene baseline, not risk language. |
| 20 | OSS-Pure Boundary (no downstream-consumer leakage) | **§3 P1**, **NG3**, **D-5** (generic chat scenarios only) | Faithful. PRD body contains zero domain references. |

**Unmapped ideas:** none.
**Diluted ideas:** #12 (sealed errors lost the `KoelErrorCode` enum + overridable `ErrorClassifier` mechanism — replaced with raw `Map<String, dynamic>` on `BusinessError`).

## 2. Package Responsibility Drift (9 packages)

Brainstorming Stage 2–5 checklist defines per-package responsibilities. Comparing line-by-line against PRD §7:

| Package | Brainstorming Owns | PRD §7 Owns | Drift |
|---|---|---|---|
| `koel_core` | Event types, Message types, Tool/Context/RunAgentInput, AbstractAgent, Interceptor framework, SessionStorage interface + InMemorySessionStorage, ChatStateReducer, sealed KoelError, UnknownAgUiEvent | Same set verbatim. | **None.** |
| `koel_http` | HttpAgent, SSE parser, 6 built-in interceptors (Auth, Retry, Logging, EventTrace, Sentry OFF, PIIRedaction) | Same set + cancellation propagation + chunk synthesis added. | **None** — additions are pipeline-stage refinements, not scope shift. |
| `koel_agno` | AgnoAgent, Agno message conversion, conformance tests | Same + default-ON `AgnoAuthInterceptor`. | **None** — auth interceptor is a refinement, not new scope. |
| `koel_langgraph` | LangGraph deployment URL, LangGraphAgent, interrupt resume via MetaEvent echoback | Same. | **None.** |
| `koel_runtime` | GraphQL bridge, `generateCopilotResponse`, AG-UI ↔ GraphQL translation | Same. | **None.** |
| `koel_flutter` | KoelChatController, Hive + Secure session storage, MessageContentParser, InheritedWidget/Provider injection | Same + adds `WidgetResolver` (F-E2). | **Addition** — `WidgetResolver` belongs to ideas not numbered in brainstorming but consistent with #11's segment-based contract. Acceptable. |
| `koel_widgets` | MessageBubble (M3+Cupertino), ChatInput, FollowUpList, theming hooks | Same + "generative UI host widgets." | **None.** |
| `koel_devtools` | DevTools extension (5 tabs) | Same 5 tabs. | **None.** |
| `koel_test` | Recorded SSE fixtures, MockAgent, tool handler test harness | Same + `ConformanceRunner` (formalizes F-G4). | **None** — runner formalizes the brainstorming "cross-impl conformance tests" line in idea #19. |

No package owns something in brainstorming but not in PRD. No package owns something in PRD but not in brainstorming (additions are within-scope refinements).

## 3. Five Unresolved Decisions

| # | Brainstorming Item | PRD Status | Verdict |
|---|---|---|---|
| 1 | **Spike A fixtures** (capture wire traffic; OQ-7) | **RESOLVED** in §15 as `OQ-Fixtures-Source — RESOLVED` and **F-G1** (3 backends: dojo + agno + langgraph). | Resolved, captured. |
| 2 | **Spike B agno auth** (OQ-3) | **RESOLVED** in §15 as `OQ-Agno-Auth — RESOLVED` and **F-C1** (default-ON `AgnoAuthInterceptor`). | Resolved, captured. |
| 3 | **Spike C protobuf** (OQ-8) | **OQ-Protobuf-Codegen** (open) + **NG4** (deferred to v1.5/v2). | Faithfully deferred. |
| 4 | **Docs toolchain** | **OQ-Docs-Framework** (open, owner P1). | Faithfully surfaced. |
| 5 | **State-mgmt governance** | **OQ-State-Mgmt-Governance** (open, owner P1) + **NG7**. | Faithfully surfaced. |

All 5 accounted for.

**Bonus — PRD added 4 new OQs not in brainstorming:** `OQ-Koel-Trademark` (blocks v1.0.0 publish), `OQ-AGUI-License`, `OQ-LangGraph-Graduation`, `OQ-Replay-Side-Effects`. These are net additions, consistent with brainstorming idea #19 "engineering hygiene baseline."

## 4. Philosophy / Voice Preservation

Brainstorming Design DNA quote: *"Infra deep, business out. Modular by discipline, opinionated about cross-cutting craftsmanship, agnostic about everything else."*

- **§1 Vision** reproduces the DNA verbatim as a blockquote. ✓
- "Passion-driven" framing (idea #18) preserved in §1 paragraph 2 and §5.4. ✓
- "Built by someone who reads framework source, not docs" — original-to-PRD but consistent with brainstorming "read framework source, not just docs" CLAUDE.md principle. ✓
- "Slow path to v1 is the chosen path" — captures brainstorming's "v1 = production-ready, not preview" stance. ✓

Voice is preserved; not generic.

## 5. Reference Comparables (Addendum §E)

Brainstorming references and their addendum §E coverage:

| Reference | In Addendum §E? |
|---|---|
| `dio` | ✓ |
| `graphql_flutter` | ✓ |
| `langchain_dart` | ✓ |
| `firebase_*` | ✓ |
| `supabase_flutter` | ✓ |
| `anthropic_sdk_dart` | ✓ |
| community `ag_ui` 0.1.0 | ✓ |
| `openai_dart` (mentioned in brainstorming Phase 1) | **MISSING** from §E — minor gap; covered implicitly by `anthropic_sdk_dart` row. |
| `riverpod` (mentioned in brainstorming Phase 1) | **MISSING** from §E — minor gap. |
| `freezed` (mentioned in brainstorming Phase 1) | Covered in addendum §B.2 (tech choice), not §E (correct location). |
| `bloc` / `Riverpod DevTools` (DevTools idiom inspiration) | **MISSING** from §E — minor gap; covered conceptually by CopilotKit web-inspector row. |
| Kotlin Multiplatform SDK (Spike D source-read inspiration) | **MISSING** from §E — Spike D in brainstorming Stage 1 specifies reading Kotlin SDK source; addendum §E doesn't credit it. |

Net: 7/7 primary OSS comparables covered; 4 secondary/inspirational references not in the §E table (acceptable since they're either tech-choice citations or non-comparables).

## Overall Faithfulness Verdict

**The PRD is a faithful, near-loss-less projection of the brainstorming session into a production-grade requirements document.** All 20 ideas mapped, all 9 package responsibilities preserved, all 5 unresolved decisions surfaced (3 explicitly carried forward as OQs, 2 resolved). One minor design dilution in F-A5 (loss of `KoelErrorCode` enum + `ErrorClassifier` mechanism) and four minor reference omissions in §E warrant follow-up but do not change scope.
