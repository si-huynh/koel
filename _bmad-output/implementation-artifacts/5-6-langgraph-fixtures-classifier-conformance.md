---
baseline_commit: 48e38875beac591923a36c821a7a2a2cde820521
---

# Story 5.6: koel_langgraph — Fixtures + ErrorClassifier + ConformanceRunner green

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As an OSS contributor,
I want real captured fixtures from a LangGraph deployment, a `LangGraphErrorClassifier` mapping LangGraph error shapes, and `ConformanceRunner` running green against `LangGraphAgent`,
so that the LangGraph conformance contract is verified end-to-end per FR-G1 + FR-G4 + AR-20.

This is the **langgraph-group sealer** — the direct structural mirror of Story 5.3 (the agno sealer). It finalizes `koel_langgraph`: captures real fixtures, adds the backend's error classifier, wires the formal `ConformanceRunner` lane, lands the package-finalization analyzer/coverage config, and turns on the coverage gate. After this story the langgraph group (5.4 → 5.5 → 5.6) is complete and `koel_langgraph` is publish-shaped.

## Acceptance Criteria

> **Parity note (binding).** This story ports the agno sealer (5.3) + agno classifier (5.2) onto langgraph. Where the epic's prose and the live backend contract diverge, the **live contract + agno precedent decide** (see RESOLVED items below) — this is a faithful Dart port, not a fresh design.

### AC1 — Real captured fixtures (FR-G1)

**Given** a running LangGraph deployment started by `make up-langgraph` in `../koel_backend` (port **8003**, route **`POST /agent`**),
**When** `dart run tool/capture_fixtures.dart --backend=langgraph` runs,
**Then** real JSONL fixtures land under `packages/koel_test/lib/src/fixtures/langgraph/*.jsonl`,
**And** each fixture's first line is a `_session` header recording `adapter: koel_langgraph@0.0.1`, `synthesized: false`, and `backendVersion: langgraph==0.0.37` (read live from `GET /status`),
**And** the captured scenarios are exactly those the langgraph backend **natively emits** (text, interrupt step-1, interrupt-resume, state, tool, error — drivable via `state.scenario`), each its own `<scenario>.jsonl`.

> **RESOLVED — fixture scope is richer than agno.** Unlike agno (mock-LLM, text-only), the langgraph glue drives **6 real scenarios** via `state.scenario` (`text` | `interrupt` | `state` | `tool` | `error`, plus the interrupt→resume two-request pair). Capture every scenario the backend emits as `synthesized: false`. Do **not** synthesize what the backend can emit. (Source: `../koel_backend/backends/langgraph/CONTRACT.md#Event-type-coverage`.)

> **RESOLVED — `backendVersion` stamp is `langgraph==0.0.37`, not `ag-ui-langgraph==0.0.37`.** `deferred-work.md` (5.4 hand-off) wrote `ag-ui-langgraph==0.0.37` (the *pip package* name). But the existing capture tool derives the stamp from `GET /status` → `{"framework":"langgraph","version":"0.0.37"}` via `'${framework}==${version}'`, yielding `langgraph==0.0.37` — exactly the agno path (`agno==2.6.10`). **Parity with the agno tool wins**: keep the `/status`-derived formula unchanged; the stamp is `langgraph==0.0.37`. The pip package version (`ag-ui-langgraph==0.0.37`) belongs in README prose, not the wire stamp.

### AC2 — `LangGraphErrorClassifier` (AR-20)

**Given** `packages/koel_langgraph/lib/src/error/langgraph_error_classifier.dart`,
**When** I inspect it,
**Then** `final class LangGraphErrorClassifier extends DefaultErrorClassifier` maps the langgraph-meaningful HTTP statuses its `x-api-key` middleware emits (**401 → `businessAuth`**, **403 → `businessForbidden`**, **429 → `businessRateLimited`**) off a typed `TransportError(statusCode:)`,
**And** it delegates every other failure to an injected `_inner` classifier defaulting to `transportErrorClassifier()` (NOT bare `super`) so the native socket/TLS `is`-refinement is preserved,
**And** it never throws (honors `ErrorClassifier.classify`'s contract),
**And** `LangGraphAgent` overrides `errorClassifier()` to return `const LangGraphErrorClassifier()` and exports it from the barrel.

> **RESOLVED — langgraph-specific envelope mappings (`agentInternal` / `protocolVersionDrift`) are evidence-gated, mirroring agno 5.2→5.3.** The epic prose lists "graph state mismatch → `agentInternal`, deployment-version drift → `protocolVersionDrift`". But langgraph surfaces an agent failure as a **`RUN_ERROR` wire event** (scenario `error`: the node raises → glue emits `RUN_ERROR`, CONTRACT.md §5.3), which `HttpAgent` yields **verbatim as a `RunErrorEvent`** — the `ErrorClassifier` only sees transport/parser *throws*, never a parsed wire event. So those two codes are **not classifier territory in v1** unless the captured `error` fixture proves a classifiable shape (e.g. an HTTP error body or a JSON error envelope distinct from a `RUN_ERROR` event). **Decision (no speculative parser, per CLAUDE.md):** implement the three HTTP-status mappings concretely now (byte-identical to `AgnoErrorClassifier`); during AC1 capture, inspect the real `error` fixture and the live error surface; map only what the evidence characterizes; document any deferral in `deferred-work.md` with the observed wire shape cited. Do **not** bounce this as an open question — decide from evidence.

### AC3 — ConformanceRunner green + CI lane (FR-G4, FR-I1)

**Given** `packages/koel_langgraph/test/conformance_test.dart` (`@TestOn('vm')` + `@Tags(['conformance'])`) and `packages/koel_langgraph/dart_test.yaml` declaring the `conformance` tag,
**When** `ConformanceRunner().runAgainst(LangGraphAgent(deploymentUrl: …, client: <MockClient replaying the synthesized all_event_types corpus>))` runs,
**Then** `report.passed` has **25** types (28 − 3), `report.passed ∩ {TEXT_MESSAGE_CHUNK, TOOL_CALL_CHUNK, REASONING_MESSAGE_CHUNK}` is empty, and `report.failed.map(eventType).toSet()` equals exactly those 3 `*_CHUNK` shapes,
**And** `report.agentName` contains `LangGraphAgent`,
**And** a second test replays the **real captured** `langgraph/text_only_run` fixture through `LangGraphAgent` and asserts the run reproduces `FixtureLoader.loadLangGraph('text_only_run')` exactly,
**And** the lane runs in CI via the existing `melos run conformance` → `tool/conformance.sh` (auto-discovered by the declared tag; `conformance.yml` already invokes it — no workflow edit needed).

> **RESOLVED — "zero failures across every fixture" means the 25/28 contract, not 28/28.** The epic AC's optimistic "zero failures" wording is superseded by the 5.3-established fact: koel_http's default-on `synthesizeChunks` (Story 4.8) normalizes the 3 `*_CHUNK` convenience shapes into their START/CONTENT/END triplets *at the transport*, and `LangGraphAgent` doesn't expose the flag (Addendum A.4). So 25/28 is the fixed, correct backend-conformance surface — a real langgraph backend never emits chunk shapes anyway (canonical `EventEncoder`). Assert the same 25/28 shape `koel_agno/test/conformance_test.dart` asserts. (Source: `deferred-work.md` line 26; `koel_agno/test/conformance_test.dart:20-33`.)

### AC4 — Coverage ≥80% + analyzer-clean (NFR-12, NFR-13)

**Given** `packages/koel_langgraph` finalized,
**When** I run the gated build,
**Then** `bash tool/coverage.sh packages/koel_langgraph 80 80` passes (line + branch ≥ 80%, adapter tier — 5.4/5.5 already sit at 100/100, so new code must keep it green),
**And** the root `melos run test:coverage` script gains the `koel_langgraph 80 80` entry,
**And** `dart analyze` exits 0 under the new package-finalization config (`public_member_api_docs: true` gate fires clean across the now-complete public surface).

### AC5 — Package finalization (sealer config + invariant graduation + README)

**Given** the langgraph group seals,
**When** I inspect the package,
**Then** `packages/koel_langgraph/analysis_options.yaml` exists (mirrors koel_agno's sealer: `include: ../../analysis_options.yaml`, generated-file `exclude`, `public_member_api_docs: true`, `comment_references: true`; **no `plugins:`** per Story 1.7),
**And** `packages/koel_langgraph/coverage_options.yaml` exists (the standard generated-file `ignore_files` list — forward-safe no-op),
**And** `packages/koel_test/test/fixtures_test.dart` is updated: `langgraph` is removed from `pendingCaptureDirs` and a "langgraph/ graduated" test asserts the real capture exists, the `.placeholder` is gone, `_session.synthesized == false`, `adapter` startsWith `koel_langgraph@`, and `backendVersion` startsWith `langgraph==`,
**And** the `packages/koel_test/lib/src/fixtures/langgraph/.placeholder` file is deleted,
**And** `packages/koel_langgraph/README.md` is finalized with the default-ON `x-api-key` convention note (SPIKE-LG-AUTH resolved → `apiKey` optional, blank = open) and the `deploymentUrl`-used-verbatim note.

## Tasks / Subtasks

- [x] **Task 1 — Capture real langgraph fixtures (AC1)**
  - [x] Start the backend: `make up-langgraph` in `../koel_backend`; verify `curl -s http://localhost:8003/status` → `{"status":"ok","framework":"langgraph","version":"0.0.37"}`.
  - [x] Implement the langgraph branch in `tool/capture_fixtures.dart` (currently a scaffold that prints `wired in Epic 5 Story 5.6`). Mirror `_captureAgno` structure: `_captureLangGraph({required String baseUrl, String? apiKey})`. Reuse `_agnoVersion` (rename to a shared `_backendVersion`/keep generic) for `GET /status`, `_normalizeMessageIds`, `_renderFixture`, `_endpoint`, the `SocketException`/`_CaptureFailure`/catch-all + `finally client.close(force: true)` error discipline.
  - [x] **Route:** the agno tool appends `agno-chat` to a base; for langgraph the route is `/agent`. Default `--base-url` to `http://localhost:8003`; derive the chat endpoint via `_endpoint(base, 'agent')` and version via `_endpoint(base, 'status')`.
  - [x] **Auth:** langgraph uses `x-api-key` (not Bearer). When `--token`/`--api-key` is non-blank, set header `x-api-key: <value>` on the POST (the `/status` GET stays open). Decide one flag name; `--token` keeps parity with the agno invocation, but the value maps to `x-api-key`. Default open (no header).
  - [x] **Scenarios:** capture one fixture per natively-emitted scenario by POSTing `RunAgentInput` with `state: {"scenario": "<name>"}`. Cover: `text_only_run` (scenario `text`), `state_delta_basic` (scenario `state`), `tool_call_basic` (scenario `tool`), `error_path` (scenario `error`), and the interrupt pair — `interrupt_paused` (scenario `interrupt`, step-1) and `interrupt_resume` (same `threadId` + `forwardedProps: {"command": {"resume": <value>}}`). Name files to match the synthesized core-scenario vocabulary where they overlap (`text_only_run`, `tool_call_basic`, `state_delta_basic`, `error_path`).
  - [x] **Determinism:** the backend already drops `EventType.RAW`/null `raw_event` and normalizes server-side, but the tool must still normalize client-visible nondeterministic ids. Extend `_normalizeMessageIds` to **also** normalize `toolCallId` (the `tool` scenario emits `TOOL_CALL_*` with a UUID4 `toolCallId`) — agno never needed this (text-only), so it's a real gap to close here. Keep the first-seen-stable-token approach (`tool-0`, `tool-1`, …). Re-run capture twice and confirm byte-identical output.
  - [x] Add a `_koelLangGraphVersion = '0.0.1'` const (tracks `koel_langgraph` pubspec `version`) for the `adapter` stamp.
  - [x] Update the tool's `_backends` map entry/comment for langgraph from TODO to live; keep the file zero-dependency (`dart:io` + `dart:convert` only).

- [x] **Task 2 — `LangGraphErrorClassifier` (AC2)**
  - [x] Create `packages/koel_langgraph/lib/src/error/langgraph_error_classifier.dart`. Copy `AgnoErrorClassifier` structure exactly: `final class LangGraphErrorClassifier extends DefaultErrorClassifier`, `const LangGraphErrorClassifier({ErrorClassifier? inner}) : _inner = inner`, `final ErrorClassifier? _inner`, override `classify(Object raw, StackTrace? stack, RunAgentInput input)`.
  - [x] Map `raw is TransportError && raw.statusCode != null`: 401 → `BusinessError(code: KoelErrorCode.businessAuth)`, 403 → `businessForbidden`, 429 → `businessRateLimited`, `_ => null`; fall through to `(_inner ?? transportErrorClassifier()).classify(raw, stack, input)`.
  - [x] Write the class dartdoc explaining the inner-delegate-not-`super` rationale (port the agno dartdoc, swap agno→langgraph, reference SPIKE-LG-AUTH `x-api-key`).
  - [x] Wire it in `langgraph_agent.dart`: add `@override ErrorClassifier errorClassifier() => const LangGraphErrorClassifier();` and update the class dartdoc paragraph that currently says "The LangGraph-specific error classifier is **not** part of this agent yet — it arrives in Story 5.6".
  - [x] Export from the barrel `packages/koel_langgraph/lib/koel_langgraph.dart`: `export 'src/error/langgraph_error_classifier.dart';`.
  - [x] **Evidence-gate the langgraph-specific mappings:** after Task 1 capture, inspect the real `error` scenario's wire output. If the agent error surfaces only as a `RUN_ERROR` event (expected per CONTRACT.md §5.3), document in `deferred-work.md` that `agentInternal`/`protocolVersionDrift` envelope mapping is deferred (no classifiable throw/status observed) with the captured shape cited. If a classifiable HTTP/JSON error shape *is* observed, map it. No speculative parser.

- [x] **Task 3 — Conformance test + support (AC3)**
  - [x] Add the `sseClient` helper to `packages/koel_langgraph/test/_support.dart` (it currently has `fixturePayloads` + `sseBody` but NOT `sseClient`). Port agno's exact helper + add the missing imports (`package:http/http.dart`, `package:http/testing.dart`).
  - [x] Create `packages/koel_langgraph/dart_test.yaml` declaring `tags: { conformance: {} }` (mirror agno's, including the comment).
  - [x] Create `packages/koel_langgraph/test/conformance_test.dart` (`@TestOn('vm')` + `@Tags(['conformance'])` + `library;`). Port `koel_agno/test/conformance_test.dart`:
    - Test A: drive `ConformanceRunner().runAgainst(LangGraphAgent(deploymentUrl: Uri.parse('http://host:8003/agent'), client: sseClient(sseBody(await fixturePayloads('synthesized', 'all_event_types')))))`; assert `report.passed` has 25, `∩ synthesizedChunkTypes` empty, `report.failed.map(eventType).toSet() == synthesizedChunkTypes`, `report.agentName` contains `LangGraphAgent`.
    - Test B: replay the **real** `langgraph/text_only_run` capture through `LangGraphAgent(...).run(const RunAgentInput(threadId: 't', runId: 'r'))` and assert `events == await FixtureLoader.loadLangGraph('text_only_run')`.
  - [x] Confirm `melos run conformance` picks up the new lane (auto-discovered via the declared tag; `tool/conformance.sh` greps `dart_test.yaml` for `conformance`). No edit to `conformance.yml` or `conformance.sh` needed.

- [x] **Task 4 — Sealer config + coverage gate (AC4, AC5)**
  - [x] Create `packages/koel_langgraph/analysis_options.yaml` (copy `koel_agno/analysis_options.yaml` verbatim, swap the package name in comments; list the actual exported symbols: `LangGraphAgent`, `LangGraphAuthInterceptor`, `LangGraphErrorClassifier`).
  - [x] Create `packages/koel_langgraph/coverage_options.yaml` (copy `koel_agno/coverage_options.yaml`).
  - [x] Add `bash "$MELOS_ROOT_PATH/tool/coverage.sh" packages/koel_langgraph 80 80` to the `test:coverage` script in root `pubspec.yaml` (after the `koel_agno` line). Update the script `description` to mention koel_langgraph.
  - [x] Run `dart analyze` in the package and `bash tool/coverage.sh packages/koel_langgraph 80 80`; backfill dartdocs only if the member-doc gate surfaces an undocumented symbol (surface is already fully documented from 5.4/5.5).

- [x] **Task 5 — Graduate the fixtures invariant (AC5)**
  - [x] In `packages/koel_test/test/fixtures_test.dart`: remove `'langgraph'` from `pendingCaptureDirs` (leaving `{dojo, copilotkit_runtime}`).
  - [x] Add a "langgraph/ graduated (Story 5.6)" test mirroring the existing "agno/ graduated" test: assert `langgraph/text_only_run.jsonl` exists, `langgraph/.placeholder` does NOT exist, `_session.synthesized == false`, `_session.adapter` startsWith `koel_langgraph@`, `_session.backendVersion` startsWith `langgraph==`.
  - [x] Delete `packages/koel_test/lib/src/fixtures/langgraph/.placeholder`.

- [x] **Task 6 — README finalization (AC5)**
  - [x] In `packages/koel_langgraph/README.md`, add the auth note (default-ON `LangGraphAuthInterceptor` injects `x-api-key`; `apiKey == null`/blank = no-op, the right default for an open local deployment; SPIKE-LG-AUTH: `ag-ui-langgraph==0.0.37` has no built-in auth, `x-api-key` is a koel-side LangGraph-Platform-style convention) and the `deploymentUrl`-used-verbatim note (full AG-UI POST endpoint, nothing appended — unlike agno's `baseURL`).

- [x] **Task 7 — Verify the whole group is green**
  - [x] `melos run analyze` (NFR-13: zero warnings), `melos run test`, `melos run conformance`, `melos run test:coverage`, `melos run format:check`. All green before review.

## Dev Notes

### The direct template: copy 5.3 (sealer) + 5.2 (classifier), don't reinvent

This story is a structural mirror of two completed stories. Read them and their resulting code first — the patterns are proven and reviewed:
- **Sealer template:** Story 5.3 (`5-3-agno-captured-fixtures-conformance.md`) → produced `tool/capture_fixtures.dart` agno branch, `koel_agno/test/conformance_test.dart`, `koel_agno/test/_support.dart`, `koel_agno/analysis_options.yaml`, `koel_agno/coverage_options.yaml`, the `test:coverage` gate entry, and the `fixtures_test.dart` graduation.
- **Classifier template:** Story 5.2 (`5-2-agno-auth-interceptor-error-classifier.md`) → produced `koel_agno/lib/src/error/agno_error_classifier.dart`.

### Current koel_langgraph surface (from 5.4 + 5.5 — do NOT break)

`packages/koel_langgraph/` today:
```
lib/koel_langgraph.dart              # barrel: exports LangGraphAgent, LangGraphAuthInterceptor
lib/src/langgraph_agent.dart         # LangGraphAgent extends HttpAgent
lib/src/langgraph_auth_interceptor.dart  # x-api-key, default-ON, no-op when blank
lib/src/conversion/message_conversion.dart  # langGraphMessageToWire (internal, no public type)
test/langgraph_agent_test.dart       # 32 tests (endpoint, auth, encode, round-trip, interrupt-resume)
test/langgraph_auth_interceptor_test.dart  # 4 tests
test/message_conversion_test.dart    # 11 tests
test/_support.dart                   # fixturePayloads + sseBody (NO sseClient yet)
README.md                            # has interrupt-resume section; needs auth + deploymentUrl notes
# NO analysis_options.yaml, coverage_options.yaml, dart_test.yaml, error/ dir, conformance_test.dart yet
```

- `LangGraphAgent({required Uri deploymentUrl, String? apiKey, http.Client? client, List<Interceptor>? interceptors})`. `deploymentUrl` is used **verbatim** (no suffix appended — langgraph's route is caller-configured). Fail-fast `ArgumentError` on non-http(s) scheme or missing authority.
- Auth is `x-api-key` (trimmed, default-ON, blank = no-op), prepended outermost so a caller's inner `AuthInterceptor` wins.
- `encodeBody` overrides only the `messages` array (canonical-AG-UI normalization via `langGraphMessageToWire`); response path is pure inherited `HttpAgent`.
- `resume(String threadId, Object? resumeValue) → Stream<AgUiEvent>` (5.5): same route, same `threadId`, minted `runId: 'resume-<threadId>'`, `forwardedProps: {'command': {'resume': resumeValue}}`. `resumeValue` is `Object?` (parity with `CustomEvent.value`), NOT `Map`.
- Adapters **never throw** `KoelError` — all failures reach the consumer as a terminal `RunErrorEvent`. The only allowed throw is construction-time `ArgumentError`. The `ErrorClassifier` you add classifies transport/parser **throws**, never parsed wire events.

### The langgraph backend (from `../koel_backend/backends/langgraph/CONTRACT.md`)

- **Port 8003, `POST /agent`** (run + resume share the route; there is no resume route). `GET /status` → `{"status":"ok","framework":"langgraph","version":"0.0.37"}` (always open).
- Frozen versions: `ag-ui-langgraph==0.0.37`, langgraph `1.2.2`, langgraph-checkpoint `4.1.1`, ag-ui-protocol `0.1.18`.
- **Native AG-UI on both edges** — receives camelCase `RunAgentInput`, streams canonical AG-UI SSE via `EventEncoder`. No protocol-envelope conversion crosses the koel wire (that's internal to `ag-ui-langgraph`).
- **Scenarios via `state.scenario`** (`text` default | `interrupt` | `state` | `tool` | `error`). This is why langgraph captures **far more real fixtures than agno** — agno's mock-LLM was text-only.
- **Interrupt** surfaces as a `CUSTOM` event `{name: "on_interrupt", value: <payload>}`. **Resume** = re-POST same `threadId` + `forwardedProps.command.resume`. State rebuilt server-side from `MemorySaver` (single-process uvicorn constraint — not koel's concern).
- **Error scenario** (`error`): a graph node raises → glue wraps `run()` in try/except and surfaces a deterministic `RUN_ERROR` **event** (not a silent failure, not necessarily an HTTP error). This is the empirical input for AC2's evidence gate.
- **Determinism:** backend drops `EventType.RAW` + null `raw_event`; text run is byte-identical after normalizing `[timestamp, runId, threadId, messageId, toolCallId]`. The capture tool must normalize the client-visible `messageId` **and** `toolCallId`.

### Shared infrastructure to REUSE (already built — do not duplicate)

- `ConformanceRunner` (`packages/koel_test/lib/src/conformance_runner.dart`): generic `Future<ConformanceReport> runAgainst(AbstractAgent)`. Loads the synthesized `all_event_types` corpus, drives the agent, matches by `runtimeType` + freezed `==`. No changes needed.
- `FixtureLoader.loadLangGraph(String scenario)` (`fixture_loader.dart:116`) — already stubbed and ready; resolves `package:koel_test/src/fixtures/langgraph/<scenario>.jsonl`, validates the `_session` header, decodes payloads to typed `AgUiEvent`. No changes needed.
- `decodeFixtureEvent` (`fixture_envelope.dart`) — named `FormatException` on corrupt lines, used by both loader and runner.
- `MockClient` (`package:http/testing.dart`) — the offline replay seam. CI conformance is **offline**, no backend container.
- `tool/coverage.sh` (line+branch AWK gate), `tool/conformance.sh` (tag-gated per-package lane), `tool/capture_fixtures.dart` (the tool you extend).
- `KoelErrorCode` enum (`koel_core/lib/src/error/koel_error_code.dart`) — confirmed present: `businessAuth`, `businessForbidden`, `businessRateLimited`, `agentInternal`, `agentRefused`, `protocolVersionDrift`. `BusinessError` + `TransportError(statusCode:)` are the types `AgnoErrorClassifier` uses.

### Project Structure Notes

- Per **AR-20**: backend bridges import only the `koel_core.dart` / `koel_http.dart` barrels, never `src/` paths. Each adapter subclasses `DefaultErrorClassifier`. The new files conform to the architecture's `koel_langgraph` layout (`lib/src/error/langgraph_error_classifier.dart`).
- Per **Story 1.7**: `plugins:` lives ONLY at the workspace-root `analysis_options.yaml`. The package `analysis_options.yaml` must NOT declare `plugins:` (analyzer rejects `plugins_in_inner_options`) — it only `include:`s root + layers `public_member_api_docs`/`comment_references`.
- The capture tool is a **repo-level tool** (no pubspec, outside every package's coverage scope) — keep it `dart:io`/`dart:convert`-only.

### Testing standards

- Conformance test: `@TestOn('vm')` + `@Tags(['conformance'])` + `library;`; tag declared in `dart_test.yaml`. langgraph is VM-only (no web transport here, no Chrome pass).
- Coverage tier: adapter = **≥80% line + branch** (`tool/coverage.sh packages/koel_langgraph 80 80`). 5.4/5.5 are at 100/100; keep the new classifier + conformance code covered (the classifier needs tests for 401/403/429 mapping + socket-refinement-preserved fall-through — port agno's classifier tests).
- Patch coverage ≥85% per NFR-12. `dart analyze` zero warnings (NFR-13).
- Re-run capture twice; the fixtures must be byte-identical (golden stability). Commit the captured `.jsonl` files.

### References

- [Source: _bmad-output/planning-artifacts/epics/epic-5-backend-bridges-koelagno-koellanggraph-koelruntime.md#Story-5.6]
- [Source: _bmad-output/implementation-artifacts/5-3-agno-captured-fixtures-conformance.md] (sealer template)
- [Source: _bmad-output/implementation-artifacts/5-2-agno-auth-interceptor-error-classifier.md] (classifier template)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (5.4 hand-off items #9–14, #16; 5.3 line 26 the 25/28 contract)
- [Source: ../koel_backend/backends/langgraph/CONTRACT.md] (wire surface, scenarios, SPIKE-LG-RESUME, SPIKE-LG-AUTH, determinism)
- [Source: _bmad-output/planning-artifacts/epics/requirements-inventory.md] (FR-G1 line 64, FR-G4 line 67, FR-I1 line 80, AR-20 line 150, NFR-12 line 108, NFR-13 line 109)
- [Source: _bmad-output/planning-artifacts/architecture.md#koel_langgraph-layout, #AR-20]
- Code: `tool/capture_fixtures.dart`, `packages/koel_agno/test/conformance_test.dart`, `packages/koel_agno/lib/src/error/agno_error_classifier.dart`, `packages/koel_agno/analysis_options.yaml`, `packages/koel_agno/coverage_options.yaml`, `packages/koel_agno/dart_test.yaml`, `packages/koel_test/test/fixtures_test.dart`, `packages/koel_langgraph/lib/src/langgraph_agent.dart`, `pubspec.yaml` (root melos `scripts`).

### Previous Story Intelligence (5.4 + 5.5 code-review learnings)

1. **Trim auth values before injecting** (5.4 review) — header-injection guard. `LangGraphAuthInterceptor` already trims; the capture tool's `x-api-key` write must trim too.
2. **Blank-check trims first** (5.5 review) — `threadId.trim()` then check empty. Already in `resume`.
3. **`resumeValue: Object?` not `Map`** (5.5 review) — reconciled against the live contract (bare-string `"approved-by-human"` resume). When you capture the `interrupt_resume` fixture, the resume value on the wire may be a bare string — that's correct.
4. **No machine-local paths in public dartdoc** (5.5 review) — cite bare spike tokens (`SPIKE-LG-AUTH`, `SPIKE-LG-RESUME`), never `../koel_backend/...` paths in published dartdoc/README.
5. **`test/_support.dart` helper is intentionally minimal** (5.4 review, deferred) — force-unwrap + `.skip(1)` + raw casts give opaque failures on bad fixtures. Known-good for bundled fixtures. When you add `sseClient`, keep the helper's shape identical to agno's so the agno/langgraph twins stay parallel; don't over-engineer guards here.
6. **Interrupt is not special-cased** (5.5) — a run may emit multiple `CUSTOM` events; filter by `name == 'on_interrupt'`, never assume `.single`. Relevant if a conformance/round-trip test inspects the interrupt fixture.

### Git Intelligence (recent commits)

- `48e3887 feat(story-5.5)`: LangGraph interrupt-resume + review (5 patches, +34 tests, `resumeValue: Object?`).
- `099c2f5 feat(story-5.4)`: LangGraphAgent + x-api-key auth + canonical-AG-UI conversion.
- `cc05c7f feat(story-5.3)`: **the exact sealer this story mirrors** — agno captured fixtures, ConformanceRunner green, agno-group sealer. Diff this commit to see every file 5.6 touches in its agno form.
- `f533232 feat(story-5.2)`: default-ON AgnoAuthInterceptor + **AgnoErrorClassifier** (the classifier template).

Auto-commit convention: when `bmad-code-review` flips this story to `done`, commit all related changes in the same turn.

### Latest Tech Information

- Versions are pinned and frozen (`ag-ui-langgraph==0.0.37`, langgraph `1.2.2`); no upgrade in scope. The capture stamp `langgraph==0.0.37` comes live from `/status` — do not hardcode it.
- `package:http` `MockClient` / `package:http/testing.dart` and `package:test` tags (`@Tags`, `dart_test.yaml`) are the established harness — no new dependencies.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context)

### Debug Log References

- Live backend driven via `docker compose --profile langgraph up --build` (`../koel_backend`, port 8003). All 6 `state.scenario` shapes probed live before coding.
- **AC2 evidence gate (live):** `error` scenario → `RUN_STARTED → STEP_STARTED → RUN_ERROR` over **HTTP 200** (a `RunErrorEvent` on the SSE stream, not a status/throw) → `agentInternal`/`protocolVersionDrift` correctly deferred (documented in `deferred-work.md`).
- **Determinism probe (live, two captures/scenario diffed):** the *only* nondeterministic payload field is `RUN_FINISHED.runId` (server UUID7); `messageId`/`toolCallId` are scripted-deterministic — contradicting the story's UUID4-`toolCallId` premise. Generalized `_normalizeMessageIds` → `_normalizeIds(payloads, fieldPrefixes)`; langgraph normalizes `{messageId, toolCallId, runId}`.
- **Fixture pollution caught + fixed:** first capture reused `threadId: "t"` across scenarios → `MemorySaver` + `add_messages` cross-contaminated state (and inherited prior-probe content). Fixed with a distinct `threadId` per scenario; the interrupt pair deliberately shares one. Restarted the container (virgin `MemorySaver`) and re-captured clean.
- **Golden stability verified:** snapshot → container restart → re-capture → payload diff of all 6 fixtures = byte-identical.
- **Conformance Test B blocker (resolved):** real langgraph `MESSAGES_SNAPSHOT` carries a populated message without `timestamp`; koel_core `Message.fromJson` hard-required it (a kernel parity gap agno never exposed). Fixed `Message` decode to tolerate absent/`null` `timestamp` (epoch sentinel, field stays non-nullable). All 6 fixtures now decode; koel_core stays at 98.85/97.88.

### Completion Notes List

Implemented the langgraph-group **sealer** — structural mirror of Story 5.3 (sealer) + 5.2 (classifier), ported onto langgraph against the **live** backend contract.

- **AC1 — real captured fixtures:** `tool/capture_fixtures.dart` gained a `--backend=langgraph` branch capturing the 6 natively-emitted scenarios (`text_only_run`, `state_delta_basic`, `tool_call_basic`, `error_path`, `interrupt_paused`, `interrupt_resume`) as `synthesized: false`, stamped `adapter: koel_langgraph@0.0.1` + `backendVersion: langgraph==0.0.37` (live `/status`). Shared helpers (`_statusVersion`, `_postSseRun`, `_normalizeIds`) extracted so agno's path is behavior-preserved.
- **AC2 — `LangGraphErrorClassifier`:** byte-identical structure to `AgnoErrorClassifier`; maps the `x-api-key` 401/403/429 → `businessAuth`/`businessForbidden`/`businessRateLimited`, delegates the rest to `transportErrorClassifier()` (not bare `super`). Wired via `errorClassifier()` override + barrel export. The two langgraph-specific envelope codes are evidence-gated **deferred** (error is a `RUN_ERROR` wire event, never a classifiable throw — see Debug Log + `deferred-work.md`).
- **AC3 — ConformanceRunner green:** Test A asserts the **25/28** contract (3 `*_CHUNK` transport-synthesized) against `LangGraphAgent`; Test B replays the **real** `text_only_run` capture and asserts equality with `FixtureLoader.loadLangGraph`. `dart_test.yaml` + `_support.dart sseClient` added; the `melos run conformance` lane auto-discovers it.
- **AC4 — coverage + analyzer:** `koel_langgraph` line=100% / branch=100% (≥80/80); `dart analyze` exit 0 under the new sealer config (`public_member_api_docs` + `comment_references` — fixed one pre-existing unresolvable `[MessageRole.name]` reference to match agno's `` `MessageRole.name` `` code-span).
- **AC5 — package finalization:** `analysis_options.yaml` + `coverage_options.yaml` (agno-shaped, no `plugins:`), root `test:coverage` gains the `koel_langgraph 80 80` entry, `fixtures_test.dart` graduated (`langgraph` out of `pendingCaptureDirs` + a graduated assertion), `.placeholder` deleted, README finalized (default-ON `x-api-key` + `deploymentUrl`-verbatim notes).
- **Cross-cutting kernel fix (necessary for AC3/FR-G1):** koel_core `Message.fromJson` made `timestamp`-tolerant (canonical AG-UI `Message` carries none; langgraph re-emits inbound messages without it). Minimal, non-breaking (epoch sentinel, field stays `required`/non-nullable), +2 `message_test.dart` cases. A fuller nullable-`timestamp` parity pass is deferred to koel_core. **Flagged for review** as the one change outside `koel_langgraph`.

Full group green: `melos run analyze` (NFR-13 zero warnings) · `test` · `conformance` · `test:coverage` (all 5 gates) · `format:check`.

> Note: generated files (`*.g.dart`/`*.freezed.dart`) are gitignored — CI regenerates via the `melos build` gate, so the `message.dart` source change drives the regenerated decode.

### File List

**koel_langgraph (new):**
- `packages/koel_langgraph/lib/src/error/langgraph_error_classifier.dart`
- `packages/koel_langgraph/test/error/langgraph_error_classifier_test.dart`
- `packages/koel_langgraph/test/conformance_test.dart`
- `packages/koel_langgraph/dart_test.yaml`
- `packages/koel_langgraph/analysis_options.yaml`
- `packages/koel_langgraph/coverage_options.yaml`

**koel_langgraph (modified):**
- `packages/koel_langgraph/lib/koel_langgraph.dart` (export classifier)
- `packages/koel_langgraph/lib/src/langgraph_agent.dart` (`errorClassifier()` override + dartdoc)
- `packages/koel_langgraph/lib/src/conversion/message_conversion.dart` (`comment_references` fix)
- `packages/koel_langgraph/test/_support.dart` (add `sseClient`)
- `packages/koel_langgraph/test/langgraph_agent_test.dart` (update stale 5.5 classifier test → 5.6 reality)
- `packages/koel_langgraph/README.md` (auth + `deploymentUrl` notes)

**Captured fixtures (new, koel_test):**
- `packages/koel_test/lib/src/fixtures/langgraph/{text_only_run,state_delta_basic,tool_call_basic,error_path,interrupt_paused,interrupt_resume}.jsonl`
- `packages/koel_test/lib/src/fixtures/langgraph/.placeholder` (deleted)
- `packages/koel_test/test/fixtures_test.dart` (graduate langgraph invariant)

**koel_core (cross-cutting kernel fix):**
- `packages/koel_core/lib/src/message/message.dart` (`timestamp`-tolerant decode)
- `packages/koel_core/test/message/message_test.dart` (+2 cases)

**Tooling / config:**
- `tool/capture_fixtures.dart` (langgraph branch + generalized helpers)
- `pubspec.yaml` (root `test:coverage` gate entry)
- `_bmad-output/implementation-artifacts/deferred-work.md` (5.6 findings)

### Change Log

| Date | Change |
|---|---|
| 2026-06-03 | Story 5.6 implemented — langgraph-group sealer: 6 real captured fixtures, `LangGraphErrorClassifier`, `ConformanceRunner` 25/28 green, sealer config + 80/80 coverage gate, fixtures invariant graduated, README finalized. Cross-cutting koel_core `Message` timestamp-tolerant decode (required by real `MESSAGES_SNAPSHOT`). Status → review. |

### Review Findings

Adversarial code review (2026-06-03) — 3 layers (Blind Hunter / Edge Case Hunter / Acceptance Auditor). Acceptance Auditor verdict: **PASS** — all 5 ACs satisfied, every RESOLVED note honored, the cross-cutting koel_core change minimal/justified/flagged. No Critical/High. Triage: 2 patch, 1 defer, 9 dismissed as noise.

- [x] [Review][Patch] Langgraph captures lack decode/structural validation — 5 of 6 committed captures (`state_delta_basic`, `tool_call_basic`, `error_path`, `interrupt_paused`, `interrupt_resume`) are never loaded or validated by any test; only `text_only_run.jsonl` existence + `_session` is asserted (graduation test) and only `text_only_run` is decoded (conformance Test B). A truncated/malformed line — or a `Message.fromJson` throw — in the other 5 passes CI silently; a *missing* capture file also goes undetected. Add a loader sweep over all 6 langgraph captures (decode via `FixtureLoader.loadLangGraph`, mirroring the synthesized structural checks). [packages/koel_test/test/fixtures_test.dart:172-194] (edge)
- [x] [Review][Patch] `_timestampFromWire` dartdoc claims broader safety than the guard — "decoding canonical wire never throws" is true only for absent/`null`; a *present* non-canonical timestamp (empty string or JSON number) still throws via `wire as String`. Scope the dartdoc to canonical wire (= absent or ISO-8601 string) and note that non-canonical input surfaces a caller-visible throw (caught upstream as `ProtocolError(protocolMalformed)` inside `MESSAGES_SNAPSHOT`). No guard widening — handling non-canonical shapes would be speculative parsing (per CLAUDE.md). [packages/koel_core/lib/src/message/message.dart:49-61] (blind+edge)
- [x] [Review][Defer] Epoch-sentinel timestamp leaks into `Message.toJson()` re-serialization [packages/koel_core/lib/src/message/message.dart:59-61] — deferred, the explicitly-scheduled fuller nullable-`timestamp` parity pass. Decoding a no-timestamp wire message then `toJson()` emits a fabricated `1970-01-01T00:00:00Z` the wire never carried. Does not affect AC3 (Test A/B compare decoded-event `==`, never re-encode; epoch is applied symmetrically). (blind+edge)
