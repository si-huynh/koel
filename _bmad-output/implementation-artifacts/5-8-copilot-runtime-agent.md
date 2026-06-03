---
baseline_commit: a0456e2
---

# Story 5.8: koel_runtime — `CopilotRuntimeAgent implements AbstractAgent`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter/Dart developer,
I want `CopilotRuntimeAgent` implementing `AbstractAgent` **directly** (not extending `HttpAgent`, per D5 independence) — POSTing the `generateCopilotResponse` GraphQL mutation to the CopilotKit Next.js runtime, streaming the multipart response through Story 5.7's `MultipartGraphQLStreamParser`, and bracketing it with the `RUN_STARTED`/`RUN_FINISHED` the runtime folds away into its envelope,
so that consumers using the CopilotKit Next.js runtime get an SDK-compliant agent without dragging the `koel_http` SSE transport stack per FR-C3 + AR-20.

This is the **middle story of the `koel_runtime` group (5.7 → 5.8 → 5.9)** — the agent that sits on top of 5.7's parser/converter. 5.7 shipped the wire→domain transport boundary (framing parser + bidirectional conversion); this story adds the **request side** (GraphQL mutation POST + the bake-in request invariants) and the **run-lifecycle envelope** (`RUN_STARTED`/`RUN_FINISHED` synthesis the parser deliberately left to the agent). After this story `koel_runtime` has a working agent + parser, but **no real captured fixtures, no error classifier, no conformance lane, and no sealer config** — those are **Story 5.9** (the runtime-group sealer, mirror of 5.3/5.6).

## Acceptance Criteria

> **Parity note (binding).** koel is a faithful Dart port. The authoritative wire contract is `../koel_backend/backends/copilotkit/CONTRACT.md` (SPIKE-CK-FRAMING, closed live 2026-06-02 against `@copilotkit/runtime@1.8.14`). Where the epic's prose and the live contract diverge, **the live contract decides** (see RESOLVED items). The request shape (mutation, variables, selection set, bake-in invariants) is a faithful port of the contract's `## Wire surface (frozen)` + `Decision` blocks, verbatim — **no reshape**.

### AC1 — `CopilotRuntimeAgent implements AbstractAgent` (D5, AR-20, Addendum A.5)

**Given** `packages/koel_runtime/lib/src/copilot_runtime_agent.dart`,
**When** I inspect the declaration,
**Then** `final class CopilotRuntimeAgent implements AbstractAgent` (it **implements** the SPI directly — it does **NOT** `extends HttpAgent`, per D5 + AR-20),
**And** the constructor is `CopilotRuntimeAgent({required Uri graphqlEndpoint, required String agentName, String? authToken, http.Client? client})` (see **RESOLVED #1** for the `agentName` extension to Addendum A.5),
**And** it `@override`s `Stream<AgUiEvent> run(RunAgentInput input)`,
**And** `packages/koel_runtime/lib/koel_runtime.dart` exports `src/copilot_runtime_agent.dart` (the public agent surface, alongside the already-exported parser).

> **RESOLVED #1 — `agentName` is a REQUIRED constructor parameter, a faithful extension of Addendum A.5's minimal 3-param illustration.** The frozen wire contract makes `data.agentSession.agentName` mandatory for any deterministic run: "khi request mang `agentSession.agentName`, runtime dispatch tới agent đã đăng ký (`processAgentRequest`) và **KHÔNG** gọi service adapter … Không có `agentSession` → … `ExperimentalEmptyAdapter` ném `CopilotKitMisuseError`" (CONTRACT.md lines 76-81). A published SDK cannot hard-code the koel_backend test harness's agent name (`koel_scripted`) — that name is *the consumer's* registered agent, knowable only at construction. So `agentName` is construction-time configuration, semantically identical to how `AgnoAgent.token` / `LangGraphAgent.apiKey` are constructor config (Addendum A.3/A.4 both carry more than their bare-minimum sketch). It is **required** (not optional-with-default) because **no safe default exists** — defaulting to `'koel_scripted'` would silently mis-target every real deployment, the exact misuse AR-15 ("design for what users *can't* misuse") forbids. The 5.9 conformance + fixture path passes `agentName: 'koel_scripted'` to drive the scripted backend. (Per project policy: parity decides ambiguous API calls; no CYA open questions — decided and baked in. The considered alternative — reading `agentName` from `RunAgentInput.forwardedProps` to keep A.5's literal 3 params, mirroring LangGraph's `forwardedProps:{command:…}` idiom — is rejected: `agentName` is constant per-adapter, not per-run, so a per-run forwardedProps key is the footgun, not the fix. **Surface this decision to Si at hand-off** since it widens a one-way-door public constructor.)

### AC2 — GraphQL request shape + bake-in invariants (FR-C3, CONTRACT.md `## Wire surface`)

**Given** a configured `CopilotRuntimeAgent` running a `RunAgentInput`,
**When** I inspect the outgoing HTTP request (verified by `MockClient` request inspection),
**Then** it is `POST graphqlEndpoint` with `Content-Type: application/json` and `Accept: multipart/mixed`,
**And** the body is a JSON GraphQL request `{operationName: 'generateCopilotResponse', query: <the verbatim selection set>, variables: {data: …, properties: {}}}`,
**And** `variables.data` carries **all four bake-in request invariants** (CONTRACT.md line 200-202): `metadata.requestType` set (`'Chat'`), `messages` (the `MessageInput[]` mapped from `input.messages`), `frontend.actions: []`, **`metaEvents: []`** (⚠️ omitting it → runtime `INTERNAL_SERVER_ERROR` "Cannot read properties of undefined (reading 'length')" — CONTRACT.md line 82-86), and `agentSession.agentName: <the configured agentName>`,
**And** `variables.data.threadId` / `variables.data.runId` carry `input.threadId` / `input.runId`,
**And** when `authToken != null` the request carries `Authorization: Bearer <authToken>`; when `authToken == null` no `Authorization` header is sent (the runtime is open by default — CONTRACT.md line 203; a Bearer header is a harmless client convention, mirroring `AgnoAuthInterceptor`'s open-deployment no-op).

> **RESOLVED #2 — the GraphQL `query` is the runtime-client's verbatim selection set; do NOT reshape it.** CONTRACT.md line 88 ("Đúng nguyên văn — KHÔNG reshape") + the source-of-truth `@copilotkit/runtime-client-gql@1.8.14` `dist/graphql/definitions/mutations.mjs`. Copy the selection set from CONTRACT.md lines 89-121 (the `@defer`/`@stream` directives drive the multipart Incremental Delivery the parser consumes — strip them and the runtime returns a single non-streamed JSON body the parser can't frame). Store it as a `const` string in the agent file. The two GraphQL variables are `$data: GenerateCopilotResponseInput!` (non-null) and `$properties: JSONObject` (nullable → send `{}`).

> **RESOLVED #3 — `MessageInput` mapping is by role: `tool` → `resultMessage`, all others → `textMessage`.** Each koel `Message` maps to a `MessageInput` = `{id, createdAt: <timestamp ISO-8601>}` (from `BaseMessageInput`) + exactly one role-shaped sub-object (CONTRACT.md lines 70-74). koel's `MessageRole` is `{user, assistant, system, tool}` (`message.dart:7-19`) — a subset of the runtime's `{user, assistant, system, developer, tool}`, identity-mapped via `MessageRole.name`. Map `MessageRole.tool` → `resultMessage{actionExecutionId: message.toolCallId, actionName: message.name, result: message.content}`; map `user`/`assistant`/`system` → `textMessage{content: message.content, role: message.role.name}`. `frontend.actions` is hard-coded `[]` per the bake-in invariant (the scripted deterministic path ignores actions; mapping `input.tools` → `ActionInput[]` is **out of scope** — no speculative surface, CLAUDE.md "no just-in-case params"; revisit only if a real action-dispatch scenario is captured in 5.9 or later).

### AC3 — Run-lifecycle envelope: synthesize `RUN_STARTED` / `RUN_FINISHED` (CONTRACT.md `## Event-type coverage`, 5.7 RESOLVED #2)

**Given** the agent running a successful text-run against a `MockClient` replaying a `generateCopilotResponse` multipart response,
**When** I collect the emitted `Stream<AgUiEvent>`,
**Then** the stream is `RunStartedEvent(threadId, runId) → <the parser's MESSAGE/TOOL/STATE events> → RunFinishedEvent(threadId, runId)` — the agent **prepends** `RUN_STARTED` and **appends** `RUN_FINISHED` around `MultipartGraphQLStreamParser().parse(response.stream)`,
**And** both lifecycle events carry `input.threadId` / `input.runId` (the agent owns these — the runtime's initial multipart part carries `runId:null`, which `RunStartedEvent`/`RunFinishedEvent` forbid; 5.7's parser deliberately emits **no** run-lifecycle events — 5.7 RESOLVED #2, `run_events.dart:16-18,52-54`),
**And** the parser's events appear in wire order between the two lifecycle events, unmodified.

### AC4 — Adapter never throws: every failure is a terminal `RunErrorEvent` (AR-20, architecture §5 "adapter-never-throw")

**Given** the agent encounters a failure (connection refused, non-2xx HTTP status, malformed multipart body, mid-stream `ProtocolError`),
**When** the run executes,
**Then** the failure reaches the consumer as a single terminal `RunErrorEvent` carrying the typed `KoelError` — **never** an uncaught throw to consumer code (architecture.md:598; 5.4/5.5/5.6 group invariant — "adapters never throw `KoelError` to the consumer"),
**And** a non-2xx response throws a `TransportError(transportClosed, statusCode: …)` that the chain converts to `RunErrorEvent` (mirroring `HttpAgent._TransportTerminal`'s status check),
**And** a successful-headers-then-`RUN_STARTED`-then-failure run emits `RUN_STARTED → RUN_ERROR` (the lifecycle prefix already on the wire is preserved; the chain appends the trailing `RunErrorEvent`),
**And** the **only** permitted construction-time throw is an `ArgumentError` from the constructor's validation (invalid `graphqlEndpoint` / blank `agentName`) — never from `run`.

> **RESOLVED #4 — reuse `koel_core`'s `InterceptorChain` + `DefaultErrorClassifier` for the error contract; do NOT hand-roll a try/catch.** `InterceptorChain.proceed` classifies any throw or stream-borne error into a trailing `RunErrorEvent` (`interceptor.dart:68-133`) — exactly the AC4 contract, and exactly how `HttpAgent.run` composes it (`http_agent.dart:135-159`). Crucially, `InterceptorChain` + `DefaultErrorClassifier` live in **`koel_core`** (the `koel_core.dart` barrel), **not** `koel_http` — so reusing them is **D5-clean** (no `koel_http` edge). Compose `run` as `InterceptorChain(interceptors: const [], agent: _CopilotRuntimeTerminal(this), errorClassifier: const DefaultErrorClassifier()).proceed(input)`; the run lifecycle + POST + parse live in the private terminal's `async*`. `DefaultErrorClassifier` is the right base for 5.8 — `CopilotRuntimeErrorClassifier` (the GraphQL `extensions.code` refinement) is **5.9's** job (epic Story 5.9 AC); keep the classifier swappable behind a `@protected ErrorClassifier errorClassifier()` seam (mirror `HttpAgent.errorClassifier()`) so 5.9 overrides it without touching `run`.

### AC5 — D5 independence holds (no `koel_http`, no GraphQL client)

**Given** `packages/koel_runtime/pubspec.yaml` after this story,
**When** I inspect `dependencies`,
**Then** `koel_http` is **NOT** listed (D5),
**And** no `package:graphql` / `package:gql*` appears (D5),
**And** only `koel_core` + `package:http` + standard Dart libs are dependencies (the epic Story 5.8 AC — `http:` is **added by this story** for the POST; 5.7 added only `koel_core`),
**And** the existing D5 grep/dependency assertion test in `test/conversion/graphql_event_conversion_test.dart` (5.7) still passes, extended to cover the new agent file's imports (no `koel_http`, no `graphql`/`gql` import anywhere in `lib/`).

### AC6 — Tests green, ≥80%-ready, analyzer-clean (NFR-12, NFR-13)

**Given** `packages/koel_runtime` after this story,
**When** I run `dart test` in the package and `melos run analyze` workspace-wide,
**Then** all tests pass and `dart analyze` exits 0 (NFR-13, zero warnings under the workspace-root `analysis_options.yaml` — the `koel_lints` `exhaustive_switch_must_have_default` plugin rule applies to any `switch` over `MessageRole`/`AgUiEvent`),
**And** the new agent file is written **≥80% line + branch ready** so the **5.9 sealer's** `tool/coverage.sh packages/koel_runtime 80 80` lands green (NFR-12),
**And** `melos run format:check` is green workspace-wide,
**And** **no** `analysis_options.yaml` / `coverage_options.yaml` / `test:coverage` gate entry / conformance lane is added here — those are **5.9's** (parity with 5.5, the middle langgraph story, which added no sealer config; 5.6 sealed).

## Tasks / Subtasks

- [x] **Task 1 — Package deps + barrel (AC1, AC5)**
  - [x] In `packages/koel_runtime/pubspec.yaml` add `dependencies: http: ^1.6.0` (the workspace pin — match `koel_http/pubspec.yaml:28`). Keep `koel_core:` (workspace). Do **NOT** add `koel_http` (D5). Do **NOT** add any GraphQL package (D5). Keep `resolution: workspace`.
  - [x] In `packages/koel_runtime/lib/koel_runtime.dart` add `export 'src/copilot_runtime_agent.dart';` (the conversion file stays `lib/src/`-internal; the parser export is already there).
  - [x] Do **NOT** create `analysis_options.yaml` / `coverage_options.yaml`, and do **NOT** add a `test:coverage` gate entry or conformance lane — those are the **5.9 sealer's** job (parity with 5.5 → 5.6). The package inherits the workspace-root config; `dart analyze` must still exit 0 (NFR-13).

- [x] **Task 2 — The agent class + request builder (AC1, AC2)**
  - [x] Create `packages/koel_runtime/lib/src/copilot_runtime_agent.dart`: `final class CopilotRuntimeAgent implements AbstractAgent`. Constructor `CopilotRuntimeAgent({required Uri graphqlEndpoint, required String agentName, String? authToken, http.Client? client})` storing all four. Validate at construction (fail-fast `ArgumentError`, mirroring `LangGraphAgent._validateDeploymentUrl`, `langgraph_agent.dart:66-82`): `graphqlEndpoint` must be `http`/`https` with an authority; `agentName.trim()` must be non-empty.
  - [x] Add a `const` GraphQL `query` string = the **verbatim** selection set from CONTRACT.md lines 89-121 (RESOLVED #2 — no reshape; the `@defer`/`@stream` directives are load-bearing). Operation name `generateCopilotResponse`.
  - [x] `_buildVariables(RunAgentInput input)` → the `variables` map: `{data: {metadata: {requestType: 'Chat'}, threadId: input.threadId, runId: input.runId, messages: [for m in input.messages → _messageInput(m)], frontend: {actions: <empty list>}, metaEvents: <empty list>, agentSession: {agentName: agentName}}, properties: {}}`. **`metaEvents: []` is non-negotiable** (omit → 500, CONTRACT.md line 82-86). Keep the empty lists typed (`<dynamic>[]` / `<Map<String,dynamic>>[]`) so JSON encodes `[]`.
  - [x] `_messageInput(Message m)` (RESOLVED #3): `{id: m.id, createdAt: m.timestamp.toIso8601String()}` + a role-shaped object — `tool` → `resultMessage: {actionExecutionId: m.toolCallId, actionName: m.name, result: m.content}`; else → `textMessage: {content: m.content, role: m.role.name}`. Switch over `MessageRole` needs a `default`/exhaustive arm (koel_lints rule).
  - [x] Expose `@protected ErrorClassifier errorClassifier() => const DefaultErrorClassifier();` (the 5.9 override seam, mirror `HttpAgent.errorClassifier()`). Import `package:meta/meta.dart` for `@protected` — add `meta:` to deps only if not transitively available; prefer the already-present transitive (`koel_core` re-exports nothing of meta — confirm and add `meta:` to `dependencies` if `@protected` doesn't resolve).

- [x] **Task 3 — `run` composition + the transport terminal (AC3, AC4)**
  - [x] `@override Stream<AgUiEvent> run(RunAgentInput input)` returns `InterceptorChain(interceptors: const [], agent: _CopilotRuntimeTerminal(this), errorClassifier: errorClassifier()).proceed(input)` (RESOLVED #4 — `InterceptorChain` + `DefaultErrorClassifier` are `koel_core`, D5-clean).
  - [x] `final class _CopilotRuntimeTerminal implements AbstractAgent` with `async* run`:
    1. `yield RunStartedEvent(threadId: input.threadId, runId: input.runId)` (AC3 — prepend; a later throw → chain appends `RUN_ERROR` after this, AC4).
    2. Build the POST: `final client = _agent._client ?? http.Client();` `final owned = _agent._client == null;` wrap the rest in `try { … } finally { if (owned) client.close(); }`.
    3. `final request = http.Request('POST', _agent.graphqlEndpoint)..headers.addAll({...}) ..bodyBytes = utf8.encode(jsonEncode({'operationName': 'generateCopilotResponse', 'query': _query, 'variables': _agent._buildVariables(input)}));` Headers: `Content-Type: application/json`, `Accept: multipart/mixed`, and `if (authToken != null) 'Authorization': 'Bearer $authToken'`.
    4. `final response = await client.send(request);` — `response.stream` is the `Stream<List<int>>` (the live, unbuffered byte stream; `http.Request.send`/`Client.send` returns a `StreamedResponse`).
    5. Non-2xx → throw `TransportError(message: 'CopilotKit runtime returned HTTP ${response.statusCode}', code: KoelErrorCode.transportClosed, statusCode: response.statusCode)` (mirror `http_agent.dart:263-283`; drain `response.stream.drain()` before the throw so an owned client's socket isn't leaked).
    6. `yield* const MultipartGraphQLStreamParser().parse(response.stream);` (the MESSAGE/TOOL/STATE events).
    7. `yield RunFinishedEvent(threadId: input.threadId, runId: input.runId)` (AC3 — append, after the parser completes cleanly).
  - [x] **Client ownership / teardown:** an injected `client` is **not** closed by the agent (the caller owns it — same contract as `HttpAgent`); a default-created client is closed in the `finally` (covers normal completion, error, and consumer cancel — a cancelled `async*` runs its `finally`). Do not close an injected client.
  - [x] **Cancellation:** cancelling the subscription cancels the `async*` generator (the `AbstractAgent` contract); the `finally` closes an owned client. (A 50ms-budget `response.abort()` like `HttpAgent`'s is **not** available — `package:http`'s `StreamedResponse` has no `abort()`; closing the client tears the socket down. This is acceptable and is the correct D5 boundary — note it, don't reach for `koel_http`'s `Transport`/`abortOnCancel`.)

- [x] **Task 4 — Tests (AC1–AC6)**
  - [x] `packages/koel_runtime/test/copilot_runtime_agent_test.dart`. Reuse 5.7's `test/_support.dart` (`multipartBytes(parts)`, the `initialPart`/`incrementalPart`/`textStart`/`contentDelta`/`messageSuccess`/… builders, and `lib/src/conversion/graphql_event_conversion.dart`'s `eventsToGraphQLParts` imported via a relative `src/` path — same-package test import is fine) to author multipart response bytes. Build the transport seam with `MockClient.streaming((request, bodyStream) async => http.StreamedResponse(Stream.value(multipartBytes(parts)), 200, headers: {'content-type': 'multipart/mixed; boundary="-"'}))` (idiom: `packages/koel_http/test/cancellation_test.dart:198-216`).
  - [x] **Happy paths (AC3):** text-run → `RUN_STARTED → TEXT_MESSAGE_START → TEXT_MESSAGE_CONTENT×4 → TEXT_MESSAGE_END → RUN_FINISHED`; tool-run; state-run. Assert `threadId`/`runId` on the lifecycle events match the input. Use freezed `==` for event equality.
  - [x] **Request-shape assertions (AC2):** capture the `MockClient` request; `jsonDecode(request.body)` and assert `operationName == 'generateCopilotResponse'`, `variables.data.metadata.requestType == 'Chat'`, `variables.data.metaEvents == []`, `variables.data.frontend.actions == []`, `variables.data.agentSession.agentName == <configured>`, `variables.data.threadId/runId`, `variables.data.messages` shape per role (a `user` message → `textMessage`; a `tool` message → `resultMessage`), `variables.properties == {}`. Assert headers `content-type: application/json`, `accept: multipart/mixed`. Assert `Authorization: Bearer <t>` present with `authToken` set and **absent** when null.
  - [x] **Error contract (AC4):** non-2xx (e.g. 500) → stream is `RUN_STARTED → RUN_ERROR` (`isA<RunErrorEvent>()` with a `TransportError`); a `MockClient` that throws a `SocketException`/`ClientException` pre-headers → `RUN_ERROR` (no `RUN_STARTED`? — note: `RUN_STARTED` is yielded *before* the POST, so a pre-headers throw still yields `RUN_STARTED → RUN_ERROR`; assert that exact prefix); a malformed multipart part body in the stream → `RUN_ERROR` (`ProtocolError(protocolMalformed)` from the parser, surfaced by the chain). Assert **no** uncaught throw escapes `run`.
  - [x] **Construction validation (AC1):** non-`http(s)` `graphqlEndpoint` → `ArgumentError`; relative URI / no authority → `ArgumentError`; blank/whitespace `agentName` → `ArgumentError`.
  - [x] **D5 (AC5):** extend the existing pubspec/import assertion (5.7's `test/conversion/graphql_event_conversion_test.dart` D5 block, or add a focused test) to assert no `koel_http`/`graphql`/`gql` dependency in `pubspec.yaml` and no such import in any `lib/` file (incl. the new agent).
  - [x] **Client ownership:** an injected `MockClient` is **not** closed by the agent after a run (assert via a close-tracking client); a default client path completes without leaking (smoke).

- [x] **Task 5 — Verify (AC6)**
  - [x] `melos run analyze` (all packages "No issues found!" — NFR-13), `melos run test` (full workspace SUCCESS), `melos run format:check` (green, 0 changed). If a gate is red, **own it and fix it** (do not punt — the 5.7 review caught a 5.6-committed `format:check` red; confirm `format:check` is genuinely green before any auto-commit-on-`done`).
  - [x] Sanity: `grep` confirms no `graphql`/`gql`/`koel_http` token in `packages/koel_runtime/lib` or `pubspec.yaml` (only doc-prose "GraphQL" mentions remain), asserted by the D5 test.
  - [x] Confirm coverage is 80/80-ready (`tool/coverage.sh packages/koel_runtime 80 80` runs green locally — the 5.9 sealer will gate on it). The new agent file's branches (non-2xx, authToken null/non-null, each `MessageRole` arm, owned/injected client) should all be exercised.

### Review Findings

Adversarial code review (Blind Hunter + Edge Case Hunter + Acceptance Auditor), 2026-06-03. All 6 ACs satisfied, all 4 RESOLVED honored, gates re-verified green (analyze clean, 17/17 tests, format 0-changed, coverage 100% line / 93% branch). 1 patch, 4 deferred, 6 dismissed as noise.

- [x] [Review][Patch] Second selection-set deviation undisclosed: `_query` also omits `ImageMessageOutput` (CONTRACT.md:111), not just `metaEvents @stream` — Completion Notes/deferred-work disclosed only the latter [packages/koel_runtime/lib/src/copilot_runtime_agent.dart:304-332] — zero functional risk (image messages are outside copilotkit's text/tool/state scope), but the binding parity note's "verbatim — no reshape" audit trail must record it as a second 5.9 live-confirm item. **FIXED** 2026-06-03: disclosed in Completion Notes Decision #2 + deferred-work.md.
- [x] [Review][Defer] Tool-role `Message` with null `toolCallId`/`name` emits `actionExecutionId:null`/`actionName:null` into the required `resultMessage` wire fields, unguarded [packages/koel_runtime/lib/src/copilot_runtime_agent.dart:196-205] — deferred: the agent faithfully maps a Message whose dartdoc-documented invariant (tool→toolCallId populated) is the **Message model's** to enforce (koel_core, out of 5.8 scope); guarding here is speculative with no captured misuse scenario. Hardening candidate for the koel_core `Message` factory / 5.9 live-confirm.
- [x] [Review][Defer] No connect/read timeout and no bounded drain — a stalled connection, stalled mid-stream, or slow/huge non-2xx error body wedges the run indefinitely (`RUN_STARTED` with no following `RUN_ERROR`) [packages/koel_runtime/lib/src/copilot_runtime_agent.dart:262,270,281] — deferred: `HttpAgent` carries `connectTimeout`/`readTimeout`; this D5-standalone agent intentionally has none (no AC mandates it). Liveness/`transportTimeout` enhancement for a follow-up — adds config surface, so not a speculative 5.8 add.
- [x] [Review][Defer] Test-strengthening for 5.9 — no genuine mid-stream `ProtocolError`-after-good-events replay (only first-part-malformed); owned-client close-on-cancel/completion not asserted (no observability hook); `assistant`/`system` roles covered only transitively via the shared `default` arm; `ResultMessageOutput` *response* arm not replayed [packages/koel_runtime/test/copilot_runtime_agent_test.dart] — deferred: behaviors are guaranteed by source (`InterceptorChain` prefix-preservation, shared default arm); natural 5.9 strengthening targets.
- [x] [Review][Defer] Clean-EOF-without-terminator truncation → false `RUN_FINISHED` (the line-310 silent-truncation gap) [packages/koel_runtime/lib/src/copilot_runtime_agent.dart:281-282] — re-confirmed real; already recorded as a 5.8→5.9 hand-off, correctly gated on 5.9's live-capture characterization of the completion shape.

**Dismissed (noise/false-positive, 6):** (1) "client.close() waits for in-flight requests / no prompt teardown" — **false premise**: `IOClient.close()` uses `_inner.close(force: true)` and `BrowserClient.close()` aborts open requests, so the dartdoc's "closing the client tears the socket down" is **accurate**; (2) 204/199 boundary → clean empty run — non-2xx check mirrors `HttpAgent` exactly, an empty 2xx is a valid run; (3) epoch-sentinel timestamp re-encoded as 1970 — faithful re-encode of `message.dart`'s documented absent-timestamp sentinel, not 5.8's concern; (4) state-test int-vs-`2.0` coercion — hypothetical, the test works; (5) missing content-type validation before parse — a non-multipart 200 already surfaces as `ProtocolError → RUN_ERROR`, a guard would be speculative; (6) owned-client `close()` dropped-future — author-verified clean, `close(force:true)` is effectively synchronous.

## Dev Notes

### Scope boundary (read first — prevents scope creep into 5.9)

This story delivers **one file + its tests**: `copilot_runtime_agent.dart` (the `AbstractAgent` implementation, GraphQL POST, request invariants, `RUN_STARTED`/`RUN_FINISHED` envelope). It **reuses** 5.7's `MultipartGraphQLStreamParser` + `graphql_event_conversion.dart` unchanged. It does **NOT** deliver:
- `error/copilot_runtime_error_classifier.dart` (the GraphQL `extensions.code` refinement) → **Story 5.9**. 5.8 wires `DefaultErrorClassifier` behind a swappable seam.
- Real captured `koel_test` fixtures (`copilotkit_runtime/*.jsonl`), the `copilotkit_runtime/.placeholder` graduation, the dojo fallback fixtures → **Story 5.9**.
- The `ConformanceRunner` lane, `conformance.yml` entry, `analysis_options.yaml`, `coverage_options.yaml`, the `test:coverage` gate → **Story 5.9** (the runtime-group sealer, mirror of 5.3/5.6).

5.8's test fixtures are **test-local** (`koel_runtime/test/`, reusing 5.7's `_support.dart` multipart builders + `eventsToGraphQLParts`), driven through a `MockClient` — never a `koel_test` captured fixture, and never a live backend.

### Why `implements AbstractAgent`, not `extends HttpAgent` (the defining constraint)

D5 makes `koel_runtime` independent of `koel_http`. `HttpAgent` lives in `koel_http` and carries the SSE transport stack (`SseParser`, `Transport`, native/web seam, `abortOnCancel`, retry/auth interceptors) — none of which apply to a GraphQL multipart bridge. So `CopilotRuntimeAgent` implements the bare `AbstractAgent` SPI (`abstract_agent.dart:10-14`, exported from `koel_core`) **directly** and hand-rolls its own POST + stream wiring over `package:http`. This is a deliberate **contrast** to `AgnoAgent`/`LangGraphAgent` (5.1/5.4), which *do* `extends HttpAgent` — that pattern is **not** the template for 5.8. The shared machinery 5.8 *does* reuse — `InterceptorChain`, `DefaultErrorClassifier`, the event types — all live in `koel_core`, so reuse stays D5-clean.

### The `AbstractAgent` SPI + the error contract (verified)

- `abstract interface class AbstractAgent { Stream<AgUiEvent> run(RunAgentInput input); }` (`abstract_agent.dart`). "Adapters NEVER throw `KoelError` — they emit `RunErrorEvent`."
- `InterceptorChain({required List<Interceptor> interceptors, required AbstractAgent agent, ErrorClassifier errorClassifier = const DefaultErrorClassifier()})` + `Stream<AgUiEvent> proceed(RunAgentInput input)` — classifies **any** throw or stream-borne error into a trailing `RunErrorEvent` (`interceptor.dart:68-133`). With an empty interceptor list it is just "terminal + error classification" — which is exactly the AC4 contract for free, parity with `HttpAgent.run` (`http_agent.dart:154-159`). **All in `koel_core`** — D5-clean.
- `RunErrorEvent({required KoelError error})` (`run_events.dart:88-92`). `RunStartedEvent({required String threadId, required String runId})` / `RunFinishedEvent({required String threadId, required String runId})` — both **require non-null `runId`** (`run_events.dart:16-18,52-54`); the agent owns `input.runId`, so this is satisfiable (unlike the parser, which sees `runId:null` on the wire — 5.7 RESOLVED #2).
- `TransportError({required String message, required KoelErrorCode code, int? statusCode, Object? cause})` + `KoelErrorCode.transportClosed` — the non-2xx throw shape, from the `koel_core.dart` barrel (mirror `http_agent.dart:274-278`).
- `DefaultErrorClassifier` (`error_classifier.dart:46`) — passes a typed `KoelError` through unchanged, buckets an unknown raw throw into `AgentError(unknown)`. Note: on the **web-safe base**, a `package:http` `ClientException`/`SocketException` may classify as `unknown` rather than `transportRefused` (the `is`-check refinement `TransportErrorClassifier` does is `koel_http`-internal and **not** available here per D5). That is acceptable for 5.8 — the consumer still gets a terminal `RunErrorEvent`; 5.9's `CopilotRuntimeErrorClassifier` refines codes. Do **not** import `koel_http`'s classifier.

### The authoritative wire contract (CONTRACT.md, frozen `@copilotkit/runtime@1.8.14`)

Source of truth: `../koel_backend/backends/copilotkit/CONTRACT.md` (SPIKE-CK-FRAMING, closed live 2026-06-02). Pin is **`@copilotkit/runtime@1.8.14`** — the last stable version serving GraphQL `multipart/@defer` via the App Router (`>= 1.52.0` rewrote it to a v2 Hono JSON `agent/run` + SSE protocol — out of scope). This is **the 5.8 request-shape concern** (5.7 only consumed the documented multipart bytes).

- **Route:** `POST /api/copilotkit` — but koel takes the **full** endpoint as `graphqlEndpoint` (used verbatim, like `LangGraphAgent.deploymentUrl`; no suffix appended — the consumer passes their exact endpoint, e.g. `http://host:8004/api/copilotkit`).
- **Request:** `Content-Type: application/json`, `Accept: multipart/mixed`, body `{operationName, query, variables:{data, properties}}`.
- **`GenerateCopilotResponseInput` required fields** (CONTRACT.md lines 54-86): `metadata` (non-null; `metadata.requestType` is the enum `Chat`/`Task`/…), `messages: [MessageInput!]!`, `frontend: {actions: [ActionInput!]!, url?}`. Optional-but-bake-in: `metaEvents: []` (**omit → 500**), `agentSession: {agentName!}` (**required to drive the scripted/registered agent**, RESOLVED #1).
- **`MessageInput`** = `{id, createdAt}` + exactly one of `textMessage{content,role,parentMessageId?}` / `actionExecutionMessage{…}` / `resultMessage{actionExecutionId,actionName,result,parentMessageId?}` / `agentStateMessage{…}` / `imageMessage{…}`. `role ∈ {user,assistant,system,developer,tool}`. (RESOLVED #3 maps koel's 4-role subset.)
- **Response transport:** `multipart/mixed; boundary="-"`, GraphQL Incremental Delivery — **NOT SSE**. Consumed verbatim by 5.7's `MultipartGraphQLStreamParser` (no change).
- **Auth:** none/open on 1.8.14 (`Authorization` is a harmless client convention when `authToken` is set).
- **Divergence (documented, NFR-4):** the runtime **swallows** AG-UI `RUN_ERROR` from the agent — it ends the stream with `status: Success` and drops the remaining text, emitting no GraphQL `errors`. So `CopilotRuntimeAgent` cannot surface an *in-agent* error as `RUN_ERROR` (the wire hides it); copilotkit is a **transport-conformance target, not an AG-UI-event-matrix source** (dojo covers all event types in 5.9). 5.8's `RUN_ERROR` path is for **transport/parser** failures only (non-2xx, connection drop, malformed body) — which is the correct and only observable error surface here.

The verbatim mutation + raw text-run capture are in CONTRACT.md lines 89-158. Copy the selection set (lines 89-121) into the agent's `const _query`.

### Reuse 5.7's parser + converter exactly — do not re-touch them

`MultipartGraphQLStreamParser().parse(Stream<List<int>>)` (5.7, `multipart_graphql_stream_parser.dart`) is `const`, stateless-per-instance (per-stream state lives in the per-call `GraphQLIncrementalConverter`), and emits the MESSAGE/TOOL/STATE events. 5.8 feeds it `response.stream` and brackets the output. **Do not modify** the parser or `graphql_event_conversion.dart` — they're reviewed and 80/80. The `eventsToGraphQLParts` reverse path + `_support.dart` builders (5.7's `test/`) are the fixture authoring tools for 5.8's `MockClient` responses.

### Deferred-work hand-offs relevant to 5.8 (`deferred-work.md`)

- **Silent-truncation observability gap (line 310) — DEFER the explicit guard to 5.9, do not over-build here.** 5.7's parser has no terminal completion assertion: a clean-EOF byte stream that ends *without* the `-----` terminator (or a never-closed header block) completes `parse` normally, so a truncated run with an unclosed message is indistinguishable from a clean one (`hasNext:false` is never consulted as a completion signal). The deferred-work names the **agent layer (5.8)** as the *candidate* fix location ("assert run completion … surface a terminal `RunErrorEvent` on truncation"). **Decision for 5.8:** the common truncation case — a real `transfer-encoding: chunked` connection drop — surfaces as a **source-stream error** that propagates through the parser and is caught by `InterceptorChain` → `RUN_ERROR` (AC4 covers it). The *only* uncovered case is a stream that closes cleanly mid-`@stream` without the terminator (rare; not reproducible without a live capture). Adding a terminator-seen / `hasNext:false`-observed assertion requires the **parser to surface that signal** — a parser surface change that 5.7 deliberately left out and that the deferred-work gates on 5.9's live capture (to know the real completion shape). So 5.8 ships the natural `RUN_STARTED → parser events → RUN_FINISHED` bracketing (drop-as-error covered by the chain) and **leaves the terminator-assertion guard to 5.9** when live capture characterizes the parser-vs-agent boundary. Record this decision in `deferred-work.md` as 5.8's hand-off (do not silently drop the line-310 item).
- **`ResultMessageOutput` forward mapping wire-unverified (line 311)** — 5.7's converter concern, **not** touched by 5.8 (5.8 maps koel `tool` messages → `resultMessage` on the *request* side, a different direction). No action.
- **Mid-stream `@defer` status ordering (line 302) + `STATE_DELTA` snapshot-only (line 304)** — 5.7 converter concerns gated on 5.9 live capture. **Not** 5.8's. No action.
- **Event-less agent stream leaves `ChatSession.phase` stuck at `running` (line 234)** — not relevant: 5.8 always emits `RUN_STARTED`/`RUN_FINISHED`, so a `KoelClient` consumer sees a clean lifecycle. (This is exactly the "well-behaved agent always emits RUN_STARTED/RUN_FINISHED" the deferred note relies on — 5.8 makes `CopilotRuntimeAgent` well-behaved.)

### Project structure & conventions

- Architecture layout for backend bridges (`architecture.md:868-878`): the agent at `lib/src/<name>_agent.dart` → `lib/src/copilot_runtime_agent.dart`. Conversion under `conversion/` (5.7's, untouched).
- **AR-20:** adapters import only the `koel_core.dart` barrel, never `src/` paths. (`package:http` is the one non-koel runtime edge, per the epic AC.)
- **Naming:** `CopilotRuntimeAgent` (UpperCamelCase, backend-adapter agents end in `Agent` — `architecture.md:466-467`); file `copilot_runtime_agent.dart` (snake_case).
- **D5/AR-10:** `koel_runtime` independent of `koel_http`; zero GraphQL-client dependency (`architecture.md:339-350,416`). The "adapter-never-throw" convention (architecture §5, `architecture.md:598,1144`) — every run-time failure is a terminal `RunErrorEvent`; the one allowed throw is construction-time `ArgumentError`.
- **Sealer config is 5.9's:** middle-of-group stories add none (5.5 added no `analysis_options.yaml`; 5.6 sealed). Keep 5.8 lean.

### Testing standards

- `package:test` + `package:http/testing.dart` `MockClient.streaming` (the byte-stream seam — `koel_http/test/cancellation_test.dart:198-216`). VM-only (no Chrome — no web transport here).
- Reuse 5.7's `test/_support.dart` multipart builders + `lib/src/conversion/graphql_event_conversion.dart`'s `eventsToGraphQLParts` (same-package relative `src/` import in tests is fine) to author `MockClient` response bytes — independent hand-authored oracle for the wire shape.
- freezed `==` for event equality (monorepo idiom). Helpers `_`-prefixed.
- Coverage: write the agent **≥80% line + branch ready** (5.9's `tool/coverage.sh … 80 80` gate). Cover: non-2xx branch, `authToken` null/non-null, each `MessageRole` arm of `_messageInput`, owned-vs-injected client, the malformed-body → `RUN_ERROR` path.
- `dart analyze` zero warnings under the workspace-root config (NFR-13) — the `exhaustive_switch_must_have_default` plugin rule applies to the `MessageRole` switch.

### References

- [Source: _bmad-output/planning-artifacts/epics/epic-5-backend-bridges-koelagno-koellanggraph-koelruntime.md#Story-5.8]
- [Source: ../koel_backend/backends/copilotkit/CONTRACT.md] — `## Wire surface (frozen)` (route, request invariants, mutation), SPIKE-CK-FRAMING (variables, selection set lines 89-121, bake-in `metaEvents:[]`+`agentSession.agentName`, divergence), `## Event-type coverage`
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#A.5] — `CopilotRuntimeAgent` constructor (extended with `agentName` per RESOLVED #1)
- [Source: _bmad-output/planning-artifacts/architecture.md#D5] (339-350, 416), #adapter-never-throw (598, 1144), #project-structure (868-878), #naming (466-467)
- [Source: _bmad-output/implementation-artifacts/5-7-multipart-graphql-stream-parser.md] — the parser/converter 5.8 sits on; RESOLVED #2 (run-lifecycle is the agent's job)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] — lines 302/304/310/311 (5.7 hand-offs; 310 is the truncation guard 5.8 evaluates)
- [Source: _bmad-output/implementation-artifacts/epic-5-prep-plan.md] — Story 5.7/5.8 findings (1.8.14 pin, `metaEvents:[]` required, Incremental Delivery shape, `Accept: multipart/mixed`)
- koel_core: `packages/koel_core/lib/src/agent/{abstract_agent,interceptor}.dart`, `event/run_events.dart`, `error/{error_classifier,koel_error,koel_error_code}.dart`, `message/message.dart`, `input/run_agent_input.dart`
- Code templates: `packages/koel_http/lib/src/http_agent.dart` (the `InterceptorChain` + `_TransportTerminal` + non-2xx + owned-client composition pattern to mirror — but **without** the `koel_http` transport stack); `packages/koel_langgraph/lib/src/langgraph_agent.dart` (`_validate*` fail-fast `ArgumentError` idiom); `packages/koel_runtime/lib/src/multipart_graphql_stream_parser.dart` + `test/_support.dart` (5.7, reused)
- Group precedent: `5-3-agno-captured-fixtures-conformance.md`, `5-6-langgraph-fixtures-classifier-conformance.md` (what the **5.9** sealer will do — NOT this story)

### Previous Story Intelligence (Epic 5 group learnings)

1. **Adapters never throw `KoelError` to the consumer** (5.4/5.5/5.6/5.7) — all run-time failures reach the consumer as a terminal `RunErrorEvent`; the one allowed throw is construction-time `ArgumentError`. `InterceptorChain.proceed` gives this for free (AC4 / RESOLVED #4).
2. **Middle-of-group story does not seal** (5.5 left no `analysis_options.yaml`; 5.6 sealed) — keep 5.8 lean; 5.9 seals (classifier + fixtures + conformance + sealer config).
3. **Evidence-gate, then decide — don't bounce open questions** (5.6 AC2, 5.7 STATE_DELTA) — `agentName` (RESOLVED #1) and the request shape are decided from the live contract, not bounced. The live `copilotkit` backend is drivable via `make up-copilotkit` in `../koel_backend` (port 8004) if a request shape needs confirming — but **5.8 is offline** (MockClient); live capture is **5.9**.
4. **No machine-local paths in published dartdoc/README** (5.5 review) — cite bare spike tokens (`SPIKE-CK-FRAMING`), never `../koel_backend/...` paths, in any published doc comment.
5. **Own gate failures, prove the fix inert** (5.7 caught a 5.6-committed `format:check` red on `main`) — before any auto-commit-on-`done`, confirm `analyze` / `test` / `format:check` are **genuinely green** (the 5.6 slip went through a red format gate). This is a hard pre-commit gate (per the auto-commit-on-`done` convention).
6. **5.7's parser/converter are reviewed + 80/80** — reuse unchanged; do not re-touch `multipart_graphql_stream_parser.dart` / `graphql_event_conversion.dart`.

### Git Intelligence (recent commits)

- `a0456e2 feat(story-5.7)`: `MultipartGraphQLStreamParser` + bidirectional conversion (the files 5.8 sits on, reused unchanged).
- `2fd43e3 feat(story-5.6)` / `48e3887 feat(story-5.5)` / `099c2f5 feat(story-5.4)`: the langgraph/agno `HttpAgent`-extending adapters — a **contrast** for 5.8 (`implements AbstractAgent`, D5), not a template. They do show the `ArgumentError` validation + `@protected errorClassifier()` override seam to mirror.
- The request-side template is `HttpAgent`'s `run` + `_TransportTerminal` composition (`http_agent.dart`) — adapted to `package:http` directly (no `Transport`, no `SseParser`, no `abortOnCancel`).
- Auto-commit convention: when `bmad-code-review` flips this story to `done`, commit all related changes in the same turn — **after** confirming all gates green (learning #5).

### Latest Tech Information

- Pin is **frozen** at `@copilotkit/runtime@1.8.14` (last GraphQL-multipart App Router version; `>= 1.52.0` = v2 Hono JSON+SSE — out of scope). This is **the** 5.8 request-shape constraint (the mutation/variables/invariants are 1.8.14's).
- New Dart dependency this story: **`http: ^1.6.0`** (the workspace pin — `koel_http/pubspec.yaml:28`). `package:graphql`/`package:gql*` remain **forbidden** (D5 — assert absence). `meta` may be needed for `@protected` (add to `dependencies` if it doesn't resolve transitively).
- `MockClient.streaming` (`package:http/testing.dart`) is the established byte-stream test seam; no live backend in 5.8.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Claude Opus 4.8, 1M context) — via `/agent-flutter-engineer` specialist (CLAUDE.md mandate for `.dart` work).

### Debug Log References

- `melos run analyze` — all 10 packages "No issues found!" (NFR-13, includes the `koel_lints` `exhaustive_switch_must_have_default` plugin rule over the `MessageRole` switch).
- `dart test packages/koel_runtime` — 45/45 green (17 new agent tests + the existing 28 parser/conversion tests).
- `tool/coverage.sh packages/koel_runtime 80 80` — **line=100.00% (243/243), branch=93.07% (94/101)**, both ≥80 (5.9 sealer-ready, NFR-12).
- `melos run format:check` — green workspace-wide, 0 changed (new files reformatted via `dart format` before commit; learning #5 pre-commit gate honored).
- `melos run test` — full workspace SUCCESS. One transient failure (`koel_http` `cancellation_test` AC1 "owned default client tears the socket down on cancel") observed once under melos parallel load; **proven independent of this story** — koel_runtime ↔ koel_http have no dependency edge, the `http`/`meta` pins are unchanged, and the test passes deterministically in isolation (3×) and in koel_http's standalone suite (97/97) and on the workspace re-run. It is a load-starved `<50ms` socket-teardown timing test, not a regression.

### Completion Notes List

- **AC1** — `final class CopilotRuntimeAgent implements AbstractAgent` (D5: implements the SPI directly, does **not** extend `HttpAgent`). Constructor `({required Uri graphqlEndpoint, required String agentName, String? authToken, http.Client? client})`; `agentName` is a **required** ctor param (RESOLVED #1, faithful extension of Addendum A.5). `@override Stream<AgUiEvent> run(...)`. Barrel exports `src/copilot_runtime_agent.dart`.
- **AC2** — `POST graphqlEndpoint`, `Content-Type: application/json`, `Accept: multipart/mixed`; body `{operationName:'generateCopilotResponse', query:<verbatim>, variables:{data, properties:{}}}`. All four bake-in invariants present (`metadata.requestType:'Chat'`, `messages`, `frontend.actions:[]`, `metaEvents:[]`) + `agentSession.agentName` + `threadId`/`runId`. `Authorization: Bearer <token>` only when `authToken != null`. Verified by `MockClient` request inspection.
- **AC3** — `RunStartedEvent` prepended / `RunFinishedEvent` appended around `MultipartGraphQLStreamParser().parse(response.stream)`; both carry `input.threadId`/`runId` (the agent owns them — the wire envelope's `runId:null` is never used). Parser events appear unmodified in wire order between them.
- **AC4** — `run` composed over `koel_core`'s `InterceptorChain(interceptors: const [], agent: _CopilotRuntimeTerminal(this), errorClassifier: errorClassifier())` (RESOLVED #4 — D5-clean, no hand-rolled try/catch). Non-2xx → `TransportError(transportClosed, statusCode)`; pre-headers throw → `RUN_STARTED → RUN_ERROR`; malformed multipart body → `RUN_ERROR(ProtocolError)`. The only construction-time throw is `ArgumentError`. `errorClassifier()` is the `@protected` swap seam for 5.9's `CopilotRuntimeErrorClassifier`.
- **AC5** — `pubspec` adds only `http: ^1.6.0` (+ `meta: ^1.16.0` for `@protected`); no `koel_http`, no `graphql`/`gql`. D5 test extended to assert no `koel_http`/`graphql`/`gql` in `pubspec` or any `lib/` import.
- **AC6** — analyzer-clean, format:check green, coverage 100%/93% (≥80/80). No sealer config added (`analysis_options.yaml`/`coverage_options.yaml`/conformance lane are 5.9's, parity with 5.5).
- **Decisions (FYI — technical calls, already resolved, no action needed):**
  1. **`agentName` is a required public ctor param** (RESOLVED #1) — widens the Addendum A.5 3-param sketch; required because the runtime's dispatch mechanism (`processAgentRequest` vs `ExperimentalEmptyAdapter`) needs it and no safe default exists. A framework-driven API-design call, not a preference.
  2. **GraphQL `const _query` uses the live-verified probe selection set, not CONTRACT.md lines 89-121 verbatim.** RESOLVED #2 literally referenced lines 89-121, but that block's `metaEvents @stream { … data { messages { ... } value } }` contains a non-sendable doc elision (`{ ... }` = invalid GraphQL). Used the selection set from the curl probe that closed `SPIKE-CK-FRAMING` live (200 multipart) — same shape the 5.7 parser was built against, carrying all load-bearing `@defer`/`@stream` directives — omitting the `metaEvents @stream` *selection* block (a LangGraph-interrupt concern outside copilotkit's text/tool/state scope). The bake-in `metaEvents: []` **variable** (the 500-preventer) is unaffected and always sent. The probe set **also** omits `... on ImageMessageOutput { format bytes role parentMessageId }` (CONTRACT.md:111) — unlike `metaEvents` this is valid GraphQL, dropped purely as a live-probe / scope-narrowing call (image messages are outside copilotkit's text/tool/state scope; the parser handles absent message types, zero functional risk). Source-evidence decides (the live 200 > a doc reconstruction); **both** selection-set deviations (`metaEvents @stream` + `ImageMessageOutput`) are recorded in `deferred-work.md` as 5.9 confirm-against-live items. (Code-review patch P1, 2026-06-03 — disclosed for the binding parity note's "verbatim — no reshape" audit trail.)
- **Deferred-work hand-off** — the line-310 silent-truncation guard was evaluated (5.8 was the named candidate layer) and deliberately left to 5.9: the common drop case is already covered as a source-stream error → `RUN_ERROR` (AC4); the only uncovered case (clean-EOF mid-`@stream` without terminator) needs a parser surface change gated on 5.9's live capture. Recorded in `deferred-work.md`.

### File List

- `packages/koel_runtime/lib/src/copilot_runtime_agent.dart` (new) — the agent, request builder, transport terminal, `const _query`.
- `packages/koel_runtime/lib/koel_runtime.dart` (modified) — export `src/copilot_runtime_agent.dart`.
- `packages/koel_runtime/pubspec.yaml` (modified) — add `http: ^1.6.0`, `meta: ^1.16.0`.
- `packages/koel_runtime/test/copilot_runtime_agent_test.dart` (new) — 17 tests (AC1–AC6).
- `_bmad-output/implementation-artifacts/deferred-work.md` (modified) — Story 5.8 hand-off (truncation guard + selection-set deviation).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified) — 5-8 → in-progress → review.

### Change Log

- 2026-06-03 — Story 5.8 implemented: `CopilotRuntimeAgent implements AbstractAgent` (D5-independent GraphQL mutation POST + `RUN_STARTED`/`RUN_FINISHED` envelope over 5.7's parser). Reuses `koel_core`'s `InterceptorChain`/`DefaultErrorClassifier` (D5-clean) for the adapter-never-throw contract. Status → review.
