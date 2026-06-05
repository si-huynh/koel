# Epic 5: Backend Bridges — `koel_agno` + `koel_langgraph` + `koel_runtime`

Developer can `dart pub add koel_agno` (or `_langgraph` / `_runtime`) and connect to a real backend out-of-the-box with the right auth interceptor and error classifier wired. `koel_runtime` uses hand-rolled multipart GraphQL parser (no GraphQL client dependency). Real captured fixtures from all four reference backends (dojo + agno + langgraph + CopilotKit Next.js runtime) populate `koel_test/lib/src/fixtures/`. `ConformanceRunner` runs green against every adapter. Coverage ≥ 80%.

**Story ordering.** Three independent story groups — **5.1–5.3 (agno)**, **5.4–5.6 (langgraph)**, **5.7–5.9 (CopilotKit runtime)** — can be scheduled in any order. Story numbering preserves a default reading order, not an execution requirement; pick the group whose backend is easiest to deploy locally first. Within a group, stories run in numbered order (e.g., 5.1 → 5.2 → 5.3 for agno).

## Story 5.1: `koel_agno` — `AgnoAgent` + message conversion

As a Flutter/Dart developer,
I want `AgnoAgent extends HttpAgent` targeting `POST baseURL/agno-chat` with agno's message-shape conversion,
So that connecting to an Agno backend is one constructor call per FR-C1.

**Acceptance Criteria:**

**Given** `packages/koel_agno/lib/src/agno_agent.dart`,
**When** I inspect the constructor,
**Then** it matches Addendum A.3: `AgnoAgent({required Uri baseURL, String? token, http.Client? client, List<Interceptor>? interceptors, AgnoConversionOptions? conversion})`,
**And** the agent posts to `baseURL/agno-chat` per FR-C1.

**Given** `packages/koel_agno/lib/src/conversion/message_conversion.dart`,
**When** I inspect it,
**Then** it converts AG-UI `Message` shape ↔ agno's expected message shape (per agno backend docs),
**And** the conversion is exercised by unit tests covering the full message lifecycle.

**Given** a configured `AgnoAgent` running against a local mock Agno server,
**When** I issue a `RunAgentInput`,
**Then** the request body matches the agno wire-format expectation,
**And** the response SSE stream parses correctly via inherited `HttpAgent` behavior.

## Story 5.2: `koel_agno` — Default-ON `AgnoAuthInterceptor` + `AgnoErrorClassifier`

As a Flutter/Dart developer,
I want `AgnoAuthInterceptor` default-ON injecting the configured Bearer token plus `AgnoErrorClassifier` mapping agno-specific error shapes to `KoelErrorCode`,
So that auth and error reporting work out-of-the-box for agno backends per FR-C1 + AR-20.

**Acceptance Criteria:**

**Given** `packages/koel_agno/lib/src/agno_auth_interceptor.dart`,
**When** I inspect it,
**Then** `class AgnoAuthInterceptor extends AuthInterceptor` accepts `{required String? token}` per Addendum A.3,
**And** when `token == null` the interceptor is a no-op (open dev deployments),
**And** when `token` is non-null, the request carries `Authorization: Bearer <token>`.

**Given** `AgnoAgent(baseURL: …, token: 'abc')` without explicit interceptor list,
**When** a run executes,
**Then** the Bearer header is present on the outgoing request (verified by request inspection),
**And** the auth interceptor is automatically prepended to the chain.

**Given** `packages/koel_agno/lib/src/error/agno_error_classifier.dart`,
**When** I inspect it,
**Then** `class AgnoErrorClassifier extends DefaultErrorClassifier` overrides `classify(...)` to map agno-specific error responses (HTTP 401 → `businessAuth`, HTTP 429 → `businessRateLimited`, agno-specific JSON error envelopes → `agentRefused` / `agentInternal`),
**And** is registered by default when `AgnoAgent` constructs a `KoelClient`.

**Given** an OQ-Agno-Auth spike result (per PRD §15) confirming or refuting the Bearer assumption,
**When** the spike returns,
**Then** the default-ON behavior either stays (assumption confirmed) or flips to opt-in with the new default documented in the package README (per PRD §15 OQ-Agno-Auth).

## Story 5.3: `koel_agno` — Captured fixtures + ConformanceRunner green

As an OSS contributor,
I want real captured fixtures from a running agno backend covering every relevant event type and scenario, plus `ConformanceRunner` running green against `AgnoAgent`,
So that the conformance contract is verified end-to-end per FR-G1 (real captured) + FR-G4 (complete green).

**Acceptance Criteria:**

**Given** a running local agno backend deployed by `tool/capture_fixtures.dart --backend=agno`,
**When** the capture script runs the full event-type matrix,
**Then** JSONL fixtures land under `packages/koel_test/lib/src/fixtures/agno/*.jsonl` covering text-only run, run with tool call, run with state delta, run with reasoning + `encryptedValue` round-trip, error path, cancellation,
**And** each fixture has a `_session` header line with `adapter: koel_agno@0.1.0`, `synthesized: false`, and the agno backend version recorded.

**Given** `ConformanceRunner.runAgainst(AgnoAgent(baseURL: …))` driven by a `MockHttpClient` replaying the captured fixtures,
**When** the runner executes,
**Then** the report has zero failures across every fixture,
**And** the test runs in CI under `conformance.yml` (extended here from Story 1.5's skeleton).

**Given** `packages/koel_agno` overall,
**When** I run `melos run test:coverage`,
**Then** line + branch coverage ≥ 80% per NFR-12.

## Story 5.4: `koel_langgraph` — `LangGraphAgent` + protocol conversion

As a Flutter/Dart developer,
I want `LangGraphAgent extends HttpAgent` targeting a LangGraph deployment URL with LangGraph's protocol conversion to/from AG-UI events,
So that consumers connect to LangGraph in one line per FR-C2.

**Acceptance Criteria:**

**Given** `packages/koel_langgraph/lib/src/langgraph_agent.dart`,
**When** I inspect the constructor,
**Then** it matches Addendum A.4: `LangGraphAgent({required Uri deploymentUrl, String? apiKey, http.Client? client, List<Interceptor>? interceptors})`,
**And** it posts to the LangGraph deployment with the appropriate API-key header when supplied.

**Given** `packages/koel_langgraph/lib/src/conversion/message_conversion.dart`,
**When** I inspect it,
**Then** it converts AG-UI events to/from LangGraph's protocol (events, channels, thread_state envelopes per LangGraph docs).

**Given** a configured `LangGraphAgent` against a local LangGraph deployment,
**When** I issue a `RunAgentInput`,
**Then** the request matches the LangGraph wire format,
**And** the streamed response parses correctly into typed `AgUiEvent`s via inherited `HttpAgent` behavior.

## Story 5.5: `koel_langgraph` — Surface-level interrupt-resume

As a Flutter/Dart developer,
I want `LangGraphAgent.resume(threadId, resumeValue)` posting the resume value to the deployment and reopening the SSE stream against the same threadId/runId,
So that LangGraph's interrupt-resume flow works at the surface level per FR-C2 + PRD §6.1 deferral (deep interrupt-resume defers to v2 per OQ-LangGraph-Graduation).

**Acceptance Criteria:**

**Given** `packages/koel_langgraph/lib/src/langgraph_agent.dart`,
**When** I inspect the surface,
**Then** `Future<void> resume(String threadId, Map<String, dynamic> resumeValue)` exists,
**And** the implementation POSTs the resume value to the LangGraph deployment endpoint then reopens the SSE stream against the same threadId/runId.

**Given** a synthesized LangGraph interrupt scenario (run pauses on tool-call, consumer provides resumeValue, agent continues),
**When** the consumer calls `resume(...)`,
**Then** the new event stream emits subsequent events with the resumed state,
**And** no client-side state reconstruction is attempted (LangGraph rebuilds state server-side per PRD §6.1).

**Given** OQ-LangGraph-Graduation pending,
**When** I inspect package docs,
**Then** the README notes "v1 ships surface-level interrupt-resume; deep interrupt-resume defers to v2" with a link to the OQ tracking item.

## Story 5.6: `koel_langgraph` — Fixtures + ErrorClassifier + ConformanceRunner green

As an OSS contributor,
I want real captured fixtures from a LangGraph deployment, `LangGraphErrorClassifier` mapping LangGraph error shapes, and `ConformanceRunner` green against `LangGraphAgent`,
So that the LangGraph conformance contract is verified end-to-end per FR-G1 + FR-G4 + AR-20.

**Acceptance Criteria:**

**Given** a running LangGraph deployment captured by `tool/capture_fixtures.dart --backend=langgraph`,
**When** the script runs,
**Then** JSONL fixtures land under `packages/koel_test/lib/src/fixtures/langgraph/*.jsonl` covering the standard scenarios + interrupt-resume,
**And** each fixture's `_session` header records the LangGraph deployment version.

**Given** `packages/koel_langgraph/lib/src/error/langgraph_error_classifier.dart`,
**When** I inspect it,
**Then** it extends `DefaultErrorClassifier` mapping LangGraph-specific errors (graph state mismatch → `agentInternal`, deployment-version drift → `protocolVersionDrift`, etc.).

**Given** `ConformanceRunner.runAgainst(LangGraphAgent(...))` driven by `MockHttpClient` replaying the captured fixtures,
**When** the runner executes in CI,
**Then** the report has zero failures,
**And** `conformance.yml` covers this lane.

**Given** `packages/koel_langgraph` overall,
**When** I run `melos run test:coverage`,
**Then** coverage ≥ 80% per NFR-12.

## Story 5.7: `koel_runtime` — Hand-rolled `MultipartGraphQLStreamParser`

As a Flutter/Dart developer,
I want a hand-rolled ~200 LOC `MultipartGraphQLStreamParser` analog to `koel_http`'s `SseParser` for the CopilotKit Next.js runtime's HTTP @defer/multipart streaming,
So that `koel_runtime` is independent of `koel_http` and free of GraphQL-client dependency per AR-10 + D5 + FR-C3.

**Acceptance Criteria:**

**Given** `packages/koel_runtime/lib/src/multipart_graphql_stream_parser.dart`,
**When** I inspect it,
**Then** the parser converts `Stream<List<int>>` HTTP multipart body bytes into typed `Stream<AgUiEvent>`,
**And** the file is ~200 LOC (target per AR-10),
**And** no `package:graphql` or `package:gql*` dependency is imported.

**Given** a synthesized multipart-stream fixture mimicking CopilotKit Next.js runtime's `generateCopilotResponse` mutation response,
**When** the parser processes it,
**Then** every chunk deserializes to the correct typed `AgUiEvent`,
**And** edge cases (boundary split mid-chunk, multipart preamble whitespace, trailing boundary) all pass.

**Given** the conversion layer between AG-UI events and GraphQL response shapes,
**When** I inspect it,
**Then** the translation is bidirectional + tested for symmetry.

## Story 5.8: `koel_runtime` — `CopilotRuntimeAgent implements AbstractAgent`

As a Flutter/Dart developer,
I want `CopilotRuntimeAgent` implementing `AbstractAgent` directly (not extending `HttpAgent`, per D5 independence),
So that consumers using the CopilotKit Next.js runtime get an SDK-compliant agent without dragging the SSE transport stack per FR-C3.

**Acceptance Criteria:**

**Given** `packages/koel_runtime/lib/src/copilot_runtime_agent.dart`,
**When** I inspect the constructor,
**Then** it matches Addendum A.5: `CopilotRuntimeAgent({required Uri graphqlEndpoint, String? authToken, http.Client? client})`,
**And** `class CopilotRuntimeAgent implements AbstractAgent` (NOT extending `HttpAgent` per D5 + AR-20).

**Given** the agent running against a local CopilotKit Next.js runtime,
**When** I issue a `RunAgentInput`,
**Then** the request is a GraphQL mutation `generateCopilotResponse` with the input mapped to the GraphQL variables,
**And** the streamed multipart response parses through Story 5.7's parser into typed events.

**Given** `packages/koel_runtime/pubspec.yaml`,
**When** I inspect deps,
**Then** `koel_http` is NOT listed as a dependency (per D5),
**And** only `koel_core` + `package:http` + standard Dart libs appear.

## Story 5.9: `koel_runtime` — Fixtures + dojo fallback + ConformanceRunner green

As an OSS contributor,
I want real captured fixtures from the CopilotKit Next.js runtime + the AG-UI dojo backend (for synthesized fallback coverage of event types no other backend emits), plus `CopilotRuntimeErrorClassifier` + `ConformanceRunner` green,
So that all four reference backends are conformance-verified per FR-G1 + FR-G4 + AR-14.

**Acceptance Criteria:**

**Given** the dojo backend (`integrations/server-starter-all-features`) deployed locally by `tool/capture_fixtures.dart --backend=dojo`,
**When** the script runs,
**Then** JSONL fixtures land under `packages/koel_test/lib/src/fixtures/dojo/*.jsonl` covering every AG-UI event type at least once,
**And** events the dojo cannot emit fall back to synthesized fixtures with `synthesized: true` in the `_session` header.

**Given** the CopilotKit Next.js runtime deployed locally and captured,
**When** the script runs,
**Then** JSONL fixtures land under `packages/koel_test/lib/src/fixtures/copilotkit_runtime/*.jsonl` covering the standard scenarios.

**Given** `packages/koel_runtime/lib/src/error/copilot_runtime_error_classifier.dart`,
**When** I inspect it,
**Then** it extends `DefaultErrorClassifier` mapping CopilotKit-runtime error shapes (GraphQL extensions.code mappings).

**Given** `ConformanceRunner.runAgainst(CopilotRuntimeAgent(...))` driven by replay,
**When** it runs in CI,
**Then** the report has zero failures across all event-type scenarios,
**And** `conformance.yml` is complete green (all 3 adapters pass) per FR-I1 advancement.

**Given** all three adapter packages,
**When** I run `melos run test:coverage`,
**Then** every package's coverage ≥ 80% per NFR-12,
**And** `dart analyze` exits 0 per NFR-13.

---

## Story group — CopilotKit v2 transition (added by SCP-2026-06-05)

> CopilotKit dropped the GraphQL multipart transport (EOL ≤1.8.14). v2 (≥1.52) is
> native AG-UI over SSE, live-verified (`spike-copilotkit-v2-2026-06-05.md`). These
> stories **replace** the lossy GraphQL bridge (5.7–5.9, now superseded) with a
> full-fidelity v2 adapter and **reverse D5** (`koel_runtime` depends on `koel_http`).

## Story 5.10: `koel_runtime` — `CopilotRuntimeAgent` v2 (native AG-UI over SSE)

As an SDK consumer of a CopilotKit ≥1.52 runtime,
I want `CopilotRuntimeAgent extends HttpAgent` that POSTs to `{endpoint}/agent/{agentName}/run` and parses the `text/event-stream` AG-UI response,
So that I get the full AG-UI event matrix (not the legacy 7/28 GraphQL surface) with the same adapter-never-throw + timeout contract as agno/langgraph.

**Given** `packages/koel_runtime/lib/src/copilot_runtime_agent.dart`,
**When** I inspect it,
**Then** `class CopilotRuntimeAgent extends HttpAgent` (D5 reversed; depends on `koel_http`),
**And** the constructor is `CopilotRuntimeAgent({required Uri endpoint, required String agentName, String? authToken, http.Client? client})`.

**Given** a run against the v2 runtime,
**When** `run(input)` executes,
**Then** it POSTs the **complete** `RunAgentInput` (`tools`/`context`/`forwardedProps` present — the runtime 500s on a partial body) to `{endpoint}/agent/{agentName}/run`,
**And** inherits SSE parsing, `connectTimeout`/`readTimeout` (AI-5.3 free), and the terminal-`RunErrorEvent` contract from `HttpAgent`.

**Given** captured v2 fixtures,
**When** conformance runs,
**Then** the full AG-UI matrix passes (incl. `STATE_DELTA`, `RUN_ERROR`, `STEP_*`, `CUSTOM`) — no 7/28 partition.

## Story 5.11: Remove the GraphQL bridge + harden the v2 backend + fixtures + conformance

As the SDK maintainer,
I want the legacy GraphQL bridge removed and the CopilotKit reference backend + fixtures + conformance moved to v2,
So that koel ships one full-fidelity CopilotKit adapter with zero lossy surface and no dead-transport maintenance.

**Given** the legacy GraphQL implementation,
**When** I retire it,
**Then** `git tag archive/koel-runtime-graphql` is created first (craft preservation),
**And** `MultipartGraphQLStreamParser`, `graphql_event_conversion`, the GraphQL `copilot_runtime_error_classifier` specifics, the `copilotkit_runtime` GraphQL fixtures + conformance lane, and `koel_backend/backends/copilotkit` are deleted,
**And** `deferred-work.md` is reconciled (AI-5.1/5.4/5.5/5.7 retired with the code; AI-5.2/5.8 unaffected).

**Given** `koel_backend/backends/copilotkit_v2/`,
**When** I harden it,
**Then** it ships a Dockerfile + `docker-compose` profile + `Makefile up-copilotkit-v2`,
**And** `dart run tool/capture_fixtures.dart --backend=copilotkit` captures full-matrix v2 fixtures,
**And** `conformance.yml` is complete green across agno + langgraph + the v2 `CopilotRuntimeAgent`,
**And** `koel_runtime` README/dartdoc describe the native-SSE full-matrix adapter (no GraphQL, no 7/28).
