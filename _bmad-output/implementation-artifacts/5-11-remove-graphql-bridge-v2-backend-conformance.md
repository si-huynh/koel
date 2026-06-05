---
baseline_commit: eed21d0
---

# Story 5.11: Remove the GraphQL bridge + harden the v2 backend + fixtures + conformance

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As the koel SDK maintainer,
I want the legacy CopilotKit **GraphQL bridge fully removed** (parser + converter + their tests + the GraphQL reference backend + the 7/28 GraphQL fixtures), the `copilotkit_v2` reference backend **hardened** (Dockerfile + compose profile + `Makefile up-copilotkit-v2`), **real full-matrix v2 fixtures captured**, the **conformance lane swapped** GraphQL → v2 and green across agno + langgraph + the v2 `CopilotRuntimeAgent`, and the package **README/dartdoc + architecture + deferred-work reconciled** to the native-SSE reality,
so that koel ships **one full-fidelity CopilotKit adapter** with zero lossy 7/28 surface and **no dead-transport maintenance** — the closing story of the CopilotKit-v2 transition (SCP-2026-06-05).

This is the **second and final story of the two-story CopilotKit-v2 group (5.10 → 5.11)**. Story 5.10 already delivered the v2 agent (`CopilotRuntimeAgent extends HttpAgent`, native AG-UI over SSE) + its auth/error/conversion seams + offline tests + an offline synthesized full-matrix conformance demonstration, and **orphaned** (did not delete) the GraphQL parser/converter/fixtures/backend. **5.11 is the sealer + removal**: `git tag archive/koel-runtime-graphql` first (craft preservation), then delete the orphaned GraphQL code, capture real v2 fixtures, swap the conformance lane, harden the backend, and reconcile all docs/debt. After 5.11, `epic-5 → done` and the Epic-9 v1.0.0 gates (9.2/9.5) reference the full-fidelity v2 adapter.

> **Cross-repo scope (read first).** This story spans **two git repos**:
> - **koel** (this repo, `/Users/sihuynh/Developer/Personal/koel`): delete orphaned GraphQL code + fixtures, capture v2 fixtures, swap the conformance test/lane, rewrite README/dartdoc, reconcile architecture.md + deferred-work.md.
> - **koel_backend** (sibling repo, `/Users/sihuynh/Developer/Personal/koel_backend`): delete `backends/copilotkit/` (legacy GraphQL Next.js backend), harden `backends/copilotkit_v2/` (Dockerfile + compose service + Makefile target + README/.env), commit there separately.
>
> The binding archive tag (`archive/koel-runtime-graphql`) is created in the **koel** repo (it preserves the parser/converter the SCP names as the craft artifact). Optionally also tag the koel_backend legacy backend before its deletion (`archive/copilotkit-graphql-backend`) — craft-nice, not gate-binding.

## Acceptance Criteria

> **Parity & decision note (binding).** koel is a faithful Dart port; after this story the CopilotKit lane is **byte-shape-identical to agno/langgraph** (bare-backend-name fixtures, native-SSE capture, `extends HttpAgent` conformance). Where a naming/structure choice is ambiguous, **parity with the agno/langgraph siblings + the epic AC text decide** — do NOT bounce a preference question to Si (project policy: *parity decides ambiguous API calls; no CYA open questions*). The three RESOLVED decisions below are taken on that basis; record any further such calls as FYI in Completion Notes.

> **RESOLVED #1 — rename `copilotkit_runtime` → `copilotkit` everywhere (the epic AC + sibling parity decide).** Epic 5.11 AC text is literal: *"`dart run tool/capture_fixtures.dart --backend=copilotkit` captures full-matrix v2 fixtures"* — the flag is `copilotkit`, not the GraphQL-era `copilotkit_runtime`. Siblings use **bare backend product names** (`agno`/`langgraph`/`dojo` → dirs `agno/`/`langgraph/`/`dojo/`, loaders `loadAgno`/`loadLangGraph`/`loadDojo`). The GraphQL-era `copilotkit_runtime` was the odd one out. After this story there is **only one** CopilotKit adapter (the GraphQL one is gone), so the unversioned `copilotkit` is correct. **Rename every site** (enumerated in AC2 + the Blast-radius table). The sibling **koel_backend** reference dir stays `copilotkit_v2/` (the SCP names it; renaming it is out-of-scope churn) — the koel-side `--backend=copilotkit` flag names the *fixture lane/adapter*, not the backend dir; the operator points the capture at the v2 backend's URL (`:8005`). Note this asymmetry in the capture-tool dartdoc so it does not read as an inconsistency bug.

> **RESOLVED #2 — capture 4 scenarios (`text_only_run`, `tool_call_basic`, `state_delta_basic`, `error_path`), driven by the user-message-content selector (the live backend + langgraph parity decide).** The v2 backend (`copilotkit_v2/agent.mjs` `scenarioFor`) selects the scenario from the **last user message content** (`"tool"`/`"state"`/`"error"` → that scenario, else `"text"`). So the capture sends a `RunAgentInput` whose last user message content is the scenario key. Names mirror langgraph's (`text_only_run`/`tool_call_basic`/`state_delta_basic`/`error_path`) — NOT the GraphQL set (which had only 3, no `error_path`, because the GraphQL bridge **swallowed** `RUN_ERROR`). The `state` + `error` fixtures are the **headline proof** of the SCP: `state` carries `STATE_SNAPSHOT` **+ `STATE_DELTA`** (GraphQL collapsed the DELTA away); `error` carries `RUN_ERROR` **on the wire** (GraphQL swallowed it, ending Success). These two fixtures are the verbatim evidence that v2 is full-fidelity, not 7/28.

> **RESOLVED #3 — reconcile deferred-work per the SCP's authoritative mapping; the GraphQL-specific debt vanishes with the code.** SCP-2026-06-05 §2: **retire with the GraphQL code** AI-5.1/5.4/5.5/5.7 (mid-stream `@defer` ordering buffer, tool-role wire guard on the GraphQL mapper, silent-truncation guard, GraphQL agent test-strengtheners) — their bug-classes are deleted, not fixed; **survive** AI-5.2 (koel_core `Message.timestamp` re-serialization, a kernel fix unrelated to transport) + AI-5.8 (cancel-teardown doc); **auto-satisfied** AI-5.3 (timeouts — the v2 agent inherits `HttpAgent.connectTimeout`/`readTimeout` structurally). Also retire the **GraphQL-specific** "Deferred from code review of 5-7/5-8/5-9" items (silent truncation, `ResultMessageOutput` characterization, `_query` selection-set, mid-stream ordering, the 5.9-pass-2 copilotkit version-stamp leak + Conformance-Test-B-reframe items) — all reference deleted files. **Keep** the two capture-tool items from the 5.9 review that live in surviving code: `_normalizeUuids` over-normalization and `_postSseRun` one-object-per-`data:`-line (the latter is now MORE load-bearing — the v2 capture rides `_postSseRun`).

### AC1 — Archive then delete the orphaned koel-side GraphQL code (craft preservation + removal)

**Given** the koel repo at this story's baseline,
**When** I retire the GraphQL bridge,
**Then** `git tag archive/koel-runtime-graphql` is created **first** (at a commit that still contains the orphaned files — i.e. before the deletion commit), preserving `MultipartGraphQLStreamParser` + `GraphQLIncrementalConverter` as the craft artifact (SCP §5.2),
**And** these four files are **deleted**: `packages/koel_runtime/lib/src/multipart_graphql_stream_parser.dart`, `packages/koel_runtime/lib/src/conversion/graphql_event_conversion.dart`, `packages/koel_runtime/test/multipart_graphql_stream_parser_test.dart`, `packages/koel_runtime/test/conversion/graphql_event_conversion_test.dart` (the `conversion/` test dir is then empty — remove it),
**And** `packages/koel_runtime/test/_support.dart` drops the **legacy multipart builders** (the `msgPath`/`initialPart`/`incrementalPart`/`textStart`/`contentDelta`/`actionStart`/`argsDelta`/`stateOutput`/`messageSuccess`/`responseSuccess`/`rawMultipart`/`multipartString`/`multipartBytes`/`streamBytes` helpers + their doc comment — the block Story 5.10 kept "alongside" the SSE helpers solely for the now-deleted parser tests) and keeps the SSE helpers (`sseClient`/`sseBody`/`fixturePayloads`) the agent + conformance tests use; its line-55 `copilotkit_runtime/` comment is updated to `copilotkit/`,
**And** a repo-wide grep confirms **zero** remaining references to `MultipartGraphQLStreamParser`, `GraphQLIncrementalConverter`, `multipart_graphql_stream_parser`, or `graphql_event_conversion` under `packages/koel_runtime/` (the barrel already dropped the export in 5.10 — AC1/Task 1 of 5.10),
**And** `packages/koel_runtime` still pulls **no** `graphql`/`gql` package dependency (it never did — hand-rolled; the deleted `graphql_event_conversion_test.dart` carried that D5 assertion, now moot since the converter itself is gone).

### AC2 — Rename the fixture lane `copilotkit_runtime` → `copilotkit` + capture real full-matrix v2 fixtures (RESOLVED #1 + #2, FR-G1)

**Given** the GraphQL 7/28 captures and the `copilotkit_runtime` naming,
**When** I migrate the lane to v2,
**Then** the three GraphQL captures under `packages/koel_test/lib/src/fixtures/copilotkit_runtime/` are **deleted** and the directory is **renamed/recreated as `copilotkit/`**,
**And** `FixtureLoader.loadCopilotkitRuntime` → **`FixtureLoader.loadCopilotkit`** (`_load('copilotkit_runtime', …)` → `_load('copilotkit', …)`, dartdoc rewritten: "captured CopilotKit **v2** fixture … the AG-UI event sequence `CopilotRuntimeAgent` produces against the live **native-SSE** wire (Story 5.11 capture)"; drop the "multipart-GraphQL wire" prose),
**And** `tool/capture_fixtures.dart` is updated: the `_backends` map key `'copilotkit_runtime': '5.9'` → `'copilotkit': '5.11'`; the `_captureCopilotkit` branch is **rewritten** to drive the v2 backend over **native SSE** via the existing `_postSseRun` helper (the same path agno/langgraph use) — `POST {base}/agent/{agentName}/run` with `Accept: text/event-stream`, `agentName: 'koel_scripted'`, default base `http://localhost:8005/api/copilotkit`, writing to `packages/koel_test/lib/src/fixtures/copilotkit/<scenario>.jsonl`; the version default `_copilotkitDefaultVersion` `1.8.14` → `1.59.4` (read the live `x-copilotkit-runtime-version` header if the v2 runtime sends one, else default); the GraphQL-only machinery in that branch (the `_copilotkitEventWire` 7/28 mapper, the GraphQL multipart POST, the `_HeaderCapturingClient` if GraphQL-specific) is removed or replaced by the SSE path; the `--backend=copilotkit_runtime` references in the file header dartdoc (lines ~19) are updated to the native-SSE v2 description,
**And** running `dart run tool/capture_fixtures.dart --backend=copilotkit` against the running v2 backend produces **4** JSONL fixtures under `copilotkit/`: `text_only_run.jsonl`, `tool_call_basic.jsonl`, `state_delta_basic.jsonl`, `error_path.jsonl`,
**And** each fixture's `_session` header records `adapter: koel_runtime@0.0.1`, `synthesized: false`, `backendVersion: copilotkit==1.59.4` (the v2 pin),
**And** `state_delta_basic.jsonl` contains **both** a `STATE_SNAPSHOT` **and** a `STATE_DELTA` payload (the GraphQL bridge collapsed the DELTA — its absence here would be a regression), and `error_path.jsonl` contains a wire `RUN_ERROR` payload (the GraphQL bridge swallowed it).

### AC3 — Conformance: real v2 fixture replay + synthesized full-matrix, green across all three adapters (FR-G4, the headline)

**Given** `packages/koel_runtime/test/conformance_test.dart` (Story 5.10 left only the synthesized 25/28 test),
**When** I seal the v2 conformance,
**Then** a **second test** is added (mirror `koel_agno/test/conformance_test.dart`'s real-fixture replay): drive `CopilotRuntimeAgent(endpoint: …, agentName: 'koel_scripted', client: sseClient(sseBody(await fixturePayloads('copilotkit', '<scenario>'))))` and assert `events == await FixtureLoader.loadCopilotkit('<scenario>')` for the captured scenarios — at minimum `text_only_run`, **plus the two headline proofs** `state_delta_basic` (asserts a `StateDeltaEvent` is present in the replayed sequence) and `error_path` (asserts a `RunErrorEvent` rides the wire, NOT a swallowed-then-classified throw),
**And** the existing synthesized 25/28 test is unchanged (it already proves the full canonical matrix; the 3 misses are exactly the transport-synthesized `*_CHUNK` triplet — `koel_runtime/test/conformance_test.dart:26-69`),
**And** `koel_test/test/fixtures_test.dart` is updated: the `copilotkit_runtime` presence-assertion group + the `captured fixture decode` group are renamed to `copilotkit` and re-pointed at the 4 v2 scenarios via `FixtureLoader.loadCopilotkit(...)` (lines ~76, 81, 261-282, 318, 338-345 carry `copilotkit_runtime` strings — update all; if a `.placeholder` graduation guard remains for the dir, it is satisfied by the real captures),
**And** `melos run conformance` is **green** across the agno + langgraph + v2 `CopilotRuntimeAgent` lanes (no GraphQL lane remains),
**And** `.github/workflows/conformance.yml` is updated: the header comment "Stories 5.6 (langgraph) and 5.9 (copilotkit) extend the lane" → reflect the v2 swap (e.g. "5.6 langgraph, 5.9 dojo, **5.11 copilotkit v2** replace the 5.9 GraphQL lane"); the lane stays **offline** (replays committed fixtures through `MockClient`/`sseClient` — no backend container in CI, capture is the one-time operator step).

### AC4 — Harden the `copilotkit_v2` backend + delete the legacy GraphQL backend (koel_backend repo, SCP §4.3)

**Given** `koel_backend/backends/copilotkit_v2/` (a spike POC: `npm i && npm start`, not dockerized) and `koel_backend/backends/copilotkit/` (the legacy GraphQL Next.js backend),
**When** I harden + remove,
**Then** `backends/copilotkit_v2/` ships a **`Dockerfile`** (mirror the existing Node base `node:24-bookworm-slim`, simple install+run — no Next build phase: `COPY package.json package-lock.json` → `RUN npm ci` → `COPY server.mjs agent.mjs` → `ENV PORT=8005 HOSTNAME=0.0.0.0` → `EXPOSE 8005` → `CMD ["node","server.mjs"]`; `LABEL org.opencontainers.image.version=1.59.4`) + a `.dockerignore` (exclude `node_modules`),
**And** `docker-compose.yml` gains a `copilotkit_v2` service (`build: ./backends/copilotkit_v2`, `image: koel-backend-copilotkit-v2:dev`, `ports: ["${COPILOTKIT_V2_PORT:-8005}:8005"]`, `restart: "no"`, `profiles: ["copilotkit_v2","all"]`) and the legacy `copilotkit` service block (port 8004) is **removed**,
**And** `Makefile` gains `up-copilotkit-v2: ## Build + run copilotkit_v2 (profile: copilotkit_v2)` → `docker compose --profile copilotkit_v2 up --build` (added to `.PHONY`), and the legacy `up-copilotkit` target is **removed**,
**And** `backends/copilotkit/` is **deleted entirely**, and every legacy-`copilotkit` reference in `README.md` / `.env.example` / `docs/port-map.md` (if present) is removed or repointed to `copilotkit_v2` (the grep for `copilotkit` must distinguish legacy from `copilotkit_v2` — the legacy port table row, the backend list, the Makefile-target list, the file-layout diagram),
**And** `make up-copilotkit-v2` builds + runs the backend reachable at `POST http://localhost:8005/api/copilotkit/agent/koel_scripted/run` (the route `tool/capture_fixtures.dart --backend=copilotkit` targets).

### AC5 — Docs & decisions reconciled: README, dartdoc, architecture.md, deferred-work.md (SCP §4.1/4.2, RESOLVED #3)

**Given** the koel-side docs still describing the GraphQL bridge,
**When** I reconcile,
**Then** `packages/koel_runtime/README.md` is **rewritten** end-to-end for the native-SSE v2 adapter: the lede ("adapts the CopilotKit … runtime to koel's typed AG-UI event stream over **native SSE** — `CopilotRuntimeAgent extends HttpAgent`, POSTing the complete `RunAgentInput` to `{endpoint}/agent/{agentName}/run`"), a v2 Getting-started snippet (`endpoint`/`agentName`/`authToken` ctor — NOT `graphqlEndpoint`), the runtime pin (`@copilotkit/runtime ≥1.52`, reference-verified at `1.59.4`; GraphQL EOL ≤1.8.14 noted as removed), and the **full-matrix** event surface (delete the "lossy 7-of-28 bridge" table + the "swallows `RUN_ERROR`" divergence section; replace with the 25/28 passthrough surface identical to agno/langgraph — the 3 `*_CHUNK` shapes transport-synthesized); no machine-local paths (cite `SPIKE-CK-V2` / `spike-copilotkit-v2-2026-06-05`, never `../koel_backend/...` — 5.5 review learning),
**And** any residual GraphQL prose in the kept lib files' dartdoc is swept: `copilot_runtime_agent.dart` / `koel_runtime.dart` / `copilot_runtime_error_classifier.dart` comments that reference "5.11 deletes the orphaned parser" are updated to past tense or removed (the deletion is now done), and no comment points at a deleted file,
**And** `_bmad-output/planning-artifacts/architecture.md` is reconciled: the backend-bridge package-layout diagram (~lines 878-887) drops the `(koel_runtime only) multipart_graphql_stream_parser.dart` line so `koel_runtime` reads as a plain `HttpAgent`-subclass adapter identical in shape to agno/langgraph; verify **A.5** reflects the v2 ctor (`endpoint`/`agentName`/`authToken`/`client`/`interceptors`, not `graphqlEndpoint`) and **AR-20** wording is native-SSE (D5 is already marked REVERSED + AR-10 retired — confirm, do not re-do); grep `architecture.md` for `multipart_graphql_stream_parser`/`graphqlEndpoint` and clean any stale hit,
**And** `_bmad-output/implementation-artifacts/deferred-work.md` gains a **"Reconciled in: Story 5.11"** section applying RESOLVED #3: explicitly mark AI-5.1/5.4/5.5/5.7 + the GraphQL-specific 5.7/5.8/5.9 review items **RETIRED with the deleted code**; AI-5.2/5.8 **SURVIVE**; AI-5.3 **auto-satisfied (inherited)**; the two capture-tool items (`_normalizeUuids`, `_postSseRun`) **survive** (in still-live tooling; `_postSseRun` now carries the v2 capture).

### AC6 — Gates green workspace-wide; coverage holds; epic closed (NFR-12, NFR-13)

**Given** `packages/koel_runtime` (and the workspace) after the removal,
**When** I run `melos run analyze`, `melos run test`, `melos run format:check`, `melos run conformance`, and `tool/coverage.sh packages/koel_runtime 80 80`,
**Then** all pass: `dart analyze` exits 0 with zero warnings under the workspace-root `analysis_options.yaml` (incl. the `koel_lints` `exhaustive_switch_must_have_default` rule); `melos run test` is full-workspace SUCCESS; `format:check` is 0-changed (`dart format` any new/changed file before commit — **own any red gate and prove the fix inert** per solo-repo policy; the 5.6→5.7 incident is the cautionary tale); `melos run conformance` is green across all three adapters; and `tool/coverage.sh packages/koel_runtime 80 80` exits 0 (the package's existing 5.9 sealer gate — note: deleting the ~750 LOC of GraphQL test files *raises* the bar by removing well-covered code, so the kept v2 surface must still clear ≥80/80; the 5.10 v2 code was 100% line / 94.55% branch, so this holds — verify, do not assume),
**And** `koel_backend`'s `make up-copilotkit-v2` brings the backend up cleanly (build succeeds, route reachable) — the cross-repo deliverable's smoke check,
**And** once all gates are green, `sprint-status.yaml` moves `5-11-… : backlog → review` (dev-story) then the code-review flips it to `done` and **`epic-5: in-progress → done`** (the v2 group completing reopens-closes Epic 5; gate Epic 9's 9.2/9.5 lift).

## Tasks / Subtasks

- [x] **Task 1 — Archive tag + delete orphaned koel-side GraphQL code (AC1)**
  - [x] In the **koel** repo: create `git tag archive/koel-runtime-graphql` at HEAD (still contains the orphaned files) **before** any deletion — verify with `git tag -l` and `git show archive/koel-runtime-graphql:packages/koel_runtime/lib/src/multipart_graphql_stream_parser.dart | head` that the parser is preserved.
  - [x] Delete: `packages/koel_runtime/lib/src/multipart_graphql_stream_parser.dart`, `packages/koel_runtime/lib/src/conversion/graphql_event_conversion.dart`, `packages/koel_runtime/test/multipart_graphql_stream_parser_test.dart`, `packages/koel_runtime/test/conversion/graphql_event_conversion_test.dart`. Remove the now-empty `packages/koel_runtime/test/conversion/` dir.
  - [x] Edit `packages/koel_runtime/test/_support.dart`: remove the legacy multipart-builder block (the `MultipartGraphQLStreamParser`-support helpers, ~lines 44-215 per the 5.10 layout) and its doc comment; **keep** `sseClient`/`sseBody`/`fixturePayloads`. Update the line-55 `copilotkit_runtime/` comment → `copilotkit/`.
  - [x] Grep `packages/koel_runtime/` for `MultipartGraphQLStreamParser|GraphQLIncrementalConverter|multipart_graphql_stream_parser|graphql_event_conversion` → must be **zero** hits (barrel already clean from 5.10). Also grep `lib/` for `package:graphql|package:gql` → zero (always was).

- [x] **Task 2 — Rename the fixture lane + rewrite the v2 capture branch (AC2, RESOLVED #1/#2)**
  - [x] `FixtureLoader` (`packages/koel_test/lib/src/fixture_loader.dart`): rename `loadCopilotkitRuntime` → `loadCopilotkit`, change `_load('copilotkit_runtime', …)` → `_load('copilotkit', …)`, rewrite the dartdoc for the native-SSE v2 capture.
  - [x] `tool/capture_fixtures.dart`: `_backends` map `'copilotkit_runtime': '5.9'` → `'copilotkit': '5.11'`; the `switch` case `'copilotkit_runtime'` (line ~229) → `'copilotkit'`; `_copilotkitDefaultVersion` `1.8.14` → `1.59.4`; **rewrite `_captureCopilotkit`** to use `_postSseRun` against `{base}/agent/{agentName}/run` (`agentName: 'koel_scripted'`, default base `http://localhost:8005/api/copilotkit`, `Accept: text/event-stream`), driving the 4 scenarios by setting the last user message content to `text`/`tool`/`state`/`error` (read `copilotkit_v2/agent.mjs scenarioFor`), writing to `…/fixtures/copilotkit/<scenario>.jsonl`; delete the GraphQL multipart POST + `_copilotkitEventWire` 7/28 mapper + any GraphQL-only `_HeaderCapturingClient` specifics (keep a header read for the v2 version stamp if present); update the file-header dartdoc (lines ~19, 538, 603) from the "ASYMMETRIC GraphQL branch" prose to the native-SSE v2 description + note the `--backend=copilotkit` ↔ `copilotkit_v2/` backend-dir asymmetry (RESOLVED #1).
  - [x] **Capture:** bring the v2 backend up (`cd ../koel_backend && make up-copilotkit-v2`, or directly `cd backends/copilotkit_v2 && npm i && npm start` on :8005), then `dart run tool/capture_fixtures.dart --backend=copilotkit`. Confirm 4 fixtures land under `packages/koel_test/lib/src/fixtures/copilotkit/` with `synthesized:false`, `backendVersion:copilotkit==1.59.4`; spot-check `state_delta_basic.jsonl` has a `STATE_DELTA` payload and `error_path.jsonl` has a `RUN_ERROR` payload. Delete the old `copilotkit_runtime/` dir + its 3 GraphQL fixtures (+ any `.placeholder`).

- [x] **Task 3 — Conformance: real-fixture replay + fixtures_test + CI comment (AC3)**
  - [x] `packages/koel_runtime/test/conformance_test.dart`: add a real-fixture replay test mirroring `koel_agno/test/conformance_test.dart:70-90` — replay `copilotkit` captures through `CopilotRuntimeAgent(endpoint: Uri.parse('http://host:8005/api/copilotkit'), agentName:'koel_scripted', client: sseClient(sseBody(await fixturePayloads('copilotkit','<scenario>'))))` and assert `== await FixtureLoader.loadCopilotkit('<scenario>')` for `text_only_run` + the two headline proofs (`state_delta_basic` → assert a `StateDeltaEvent` present; `error_path` → assert a `RunErrorEvent` present on the wire). Keep the existing synthesized 25/28 test verbatim.
  - [x] `packages/koel_test/test/fixtures_test.dart`: rename the `copilotkit_runtime` presence/decode groups → `copilotkit`; re-point assertions at the 4 v2 scenarios via `FixtureLoader.loadCopilotkit(...)`; update the lines carrying `copilotkit_runtime` strings (~76, 81, 261-282, 318, 338-345) + the `$fixturesDir/copilotkit_runtime/...` paths → `copilotkit/`; satisfy any `.placeholder` graduation guard with the real captures.
  - [x] `.github/workflows/conformance.yml`: update the header comment for the GraphQL→v2 swap (5.11 replaces the 5.9 GraphQL copilotkit lane with the native-SSE v2 lane; lane stays offline-replay). No job-step change needed (`melos run conformance` auto-discovers `@Tags(['conformance'])`).

- [x] **Task 4 — koel_backend: harden v2 + delete legacy (AC4)** — sibling repo `../koel_backend`, committed there separately.
  - [x] Create `backends/copilotkit_v2/Dockerfile` (node:24-bookworm-slim, `npm ci` → copy `server.mjs`/`agent.mjs` → `ENV PORT=8005 HOSTNAME=0.0.0.0` → `EXPOSE 8005` → `CMD ["node","server.mjs"]`, `LABEL org.opencontainers.image.version=1.59.4`) + `.dockerignore` (node_modules).
  - [x] `docker-compose.yml`: add the `copilotkit_v2` service (profile `["copilotkit_v2","all"]`, port `${COPILOTKIT_V2_PORT:-8005}:8005`); remove the legacy `copilotkit` service block; update the line-8 backend-list comment.
  - [x] `Makefile`: add `up-copilotkit-v2` (+ `.PHONY`); remove `up-copilotkit`.
  - [x] Delete `backends/copilotkit/` entirely. Update `README.md` (backend list, port table, Makefile-target list, file-layout diagram) + `.env.example` (`COPILOTKIT_PORT=8004` → `COPILOTKIT_V2_PORT=8005`) + `docs/port-map.md` if present — grep `copilotkit` and clean every legacy hit while keeping `copilotkit_v2`.
  - [x] (Optional, craft) `git tag archive/copilotkit-graphql-backend` in koel_backend before deleting `backends/copilotkit/`.
  - [x] Smoke: `make up-copilotkit-v2` builds + serves `POST :8005/api/copilotkit/agent/koel_scripted/run`.

- [x] **Task 5 — Docs & decisions reconciliation (AC5, RESOLVED #3)**
  - [x] Rewrite `packages/koel_runtime/README.md` for native-SSE v2 (v2 ctor snippet, ≥1.52 pin / ≤1.8.14 GraphQL removed, full-matrix 25/28 surface — delete the 7/28 table + the RUN_ERROR-swallow section; cite `SPIKE-CK-V2`, no machine-local paths).
  - [x] Sweep residual GraphQL prose in kept lib dartdoc (`copilot_runtime_agent.dart`, `koel_runtime.dart`, `error/copilot_runtime_error_classifier.dart`): change "5.11 deletes the orphaned parser" → past tense/removed; no comment may reference a deleted file.
  - [x] `architecture.md`: drop the `multipart_graphql_stream_parser.dart` line from the backend-bridge layout (~878-887); verify A.5 = v2 ctor and AR-20 = native-SSE wording (D5/AR-10 already reconciled — confirm only); grep `multipart_graphql_stream_parser|graphqlEndpoint` and clean stale hits.
  - [x] `deferred-work.md`: add the "Reconciled in: Story 5.11" section per RESOLVED #3 (RETIRE AI-5.1/5.4/5.5/5.7 + GraphQL-specific 5.7/5.8/5.9 items; SURVIVE AI-5.2/5.8 + the two capture-tool items; AI-5.3 auto-satisfied).

- [x] **Task 6 — Verify all gates + close epic (AC6)**
  - [x] koel repo: `melos run analyze` (all packages "No issues found!"), `melos run test` (full-workspace SUCCESS), `melos run format:check` (0-changed), `melos run conformance` (green ×3 adapters), `tool/coverage.sh packages/koel_runtime 80 80` (exit 0 — verify the post-deletion surface still clears ≥80/80). **Own any red gate, prove the fix inert** before auto-commit-on-`done`.
  - [x] koel_backend repo: `make up-copilotkit-v2` smoke green; commit koel_backend changes in that repo.
  - [x] Sanity grep (koel): no `copilotkit_runtime` / `loadCopilotkitRuntime` / `MultipartGraphQLStreamParser` / `graphql_event_conversion` remain anywhere under `packages/`, `tool/`, `.github/`; `--backend=copilotkit` is the only CopilotKit capture flag.
  - [x] sprint-status.yaml: `5-11 → review` (dev), then review flips `5-11 → done` + `epic-5 → done`.

### Review Findings

**Code review 2026-06-05 (`bmad-code-review`) — ✅ CLEAN. 0 decision-needed, 0 patch, 0 defer, 5 dismissed.** Three adversarial layers (Blind Hunter, Edge Case Hunter, Acceptance Auditor). Acceptance Auditor verified all 6 ACs against the working tree (independent greps + fixture reads) — zero violations. All 5 gates re-run by the reviewer (not trusted from completion notes): `format:check` 0-changed · `analyze` 11 pkgs clean · `test` full-workspace SUCCESS · `conformance` green ×3 adapters · `coverage` line 100% (48/48) / branch 100% (23/23).

Dismissed (with rationale):

- [Dismiss] **Conformance replay omits `tool_call_basic` at the agent level** [`koel_runtime/test/conformance_test.dart`] — *parity decides:* langgraph captures 6 fixtures but agent-replays only `text_only_run`; agno replays its single one. The sibling pattern is "real-fixture replay drives `text_only_run` + any headline proofs; the synthesized 25/28 test carries the full matrix." 5.11 already **exceeds** the template (replays 3: text + the two SCP headline proofs). Adding a 4th would be over-coverage with no parity basis; tool-call shapes are already proven via the synthesized matrix + the `fixtures_test` decode sweep. AC3 ("at minimum text_only_run + the two headline proofs") met.
- [Dismiss] **`text_only_run` replay lacks an anti-vacuity `isNotEmpty` guard** [`conformance_test.dart:95`] — langgraph's replay is equally bare (parity); the guards on `state_delta_basic`/`error_path` are *headline assertions* (STATE_DELTA / RUN_ERROR specifically), not a generic pattern. Not vacuous today: `loadCopilotkit` throws on an empty/headerless fixture, so the worst case still fails loudly.
- [Dismiss] **End-of-run stdout prints only the last scenario's resolved version** [`tool/capture_fixtures.dart`] — cosmetic; inert against the pinned backend (all 4 fixtures stamp `1.59.4`); each per-fixture `_session.backendVersion` is individually correct.
- [Dismiss] **`onResponseHeaders` fires before the non-200 guard in `_postSseRun`** [`tool/capture_fixtures.dart`] — harmless; a thrown scenario writes no fixture and aborts the whole capture.
- [Dismiss] **copilotkit capture writes wire payloads with no id-normalization unlike siblings** [`tool/capture_fixtures.dart`] — correct-by-construction (the scripted v2 agent fixes every id; input thread/run reused verbatim), documented in the branch dartdoc; the related `_normalizeUuids` robustness item already survives in deferred-work as a latent operator-tool note.

## Dev Notes

### Scope boundary (read first)

5.11 is the **removal + capture + seal**, mirroring how 5.3/5.6 sealed the agno/langgraph groups (real fixtures + conformance lane + classifier) — here the "agent + seams" half was 5.10, and 5.11 adds the *removal of the predecessor transport* on top. It does **NOT** touch the v2 agent's runtime behavior (5.10 sealed it: `extends HttpAgent`, encodeBody/errorClassifier seams, auth interceptor — all green, 6/6 ACs, coverage 100%/94.55%). It does **NOT** add deep/stateful interrupt-resume (that is langgraph's OQ-LangGraph-Graduation, a v2-future item, untouched). It does **NOT** rename the koel_backend `copilotkit_v2/` dir (RESOLVED #1).

### Blast radius — what 5.11 deletes, renames, keeps (the gate-keeping map)

| File / dir | 5.11 action | Why |
|---|---|---|
| `koel_runtime/lib/src/multipart_graphql_stream_parser.dart` | **delete** | orphaned by 5.10 (barrel export dropped); the SCP's archive target |
| `koel_runtime/lib/src/conversion/graphql_event_conversion.dart` | **delete** | GraphQL converter, only the parser referenced it |
| `koel_runtime/test/multipart_graphql_stream_parser_test.dart` | **delete** | tests deleted code |
| `koel_runtime/test/conversion/graphql_event_conversion_test.dart` | **delete** | tests deleted code (carried the moot no-`graphql`-pkg D5 assertion) |
| `koel_runtime/test/conversion/` (dir) | **remove** (now empty) | — |
| `koel_runtime/test/_support.dart` | **edit** (drop multipart builders; keep SSE helpers; fix line-55 comment) | builders existed only for the deleted parser tests |
| `koel_test/lib/src/fixture_loader.dart` | **edit** (`loadCopilotkitRuntime`→`loadCopilotkit`, `_load('copilotkit',…)`, v2 dartdoc) | RESOLVED #1 |
| `koel_test/lib/src/fixtures/copilotkit_runtime/*.jsonl` (3 GraphQL) | **delete** | 7/28 GraphQL captures |
| `koel_test/lib/src/fixtures/copilotkit/*.jsonl` (4 v2) | **new** (capture) | full-matrix native-SSE |
| `koel_test/test/fixtures_test.dart` | **edit** (rename groups, re-point loader + 4 scenarios) | lane rename |
| `tool/capture_fixtures.dart` | **edit** (`_backends` key, `_captureCopilotkit` → SSE, version default, dartdoc) | RESOLVED #1/#2 |
| `koel_runtime/test/conformance_test.dart` | **edit** (add real-fixture replay; keep synthesized test) | seal (parity agno) |
| `.github/workflows/conformance.yml` | **edit** (header comment) | lane-swap doc |
| `koel_runtime/README.md` | **rewrite** | GraphQL→native-SSE prose |
| `koel_runtime/lib/{koel_runtime.dart, src/copilot_runtime_agent.dart, src/error/copilot_runtime_error_classifier.dart}` | **edit** (dartdoc sweep) | drop "5.11 deletes…" forward-refs |
| `architecture.md` | **edit** (drop parser line; verify A.5/AR-20) | layout reconciliation |
| `deferred-work.md` | **edit** (Reconciled-in-5.11 section) | RESOLVED #3 |
| **koel_backend** `backends/copilotkit_v2/{Dockerfile,.dockerignore}` | **new** | AC4 |
| **koel_backend** `{docker-compose.yml, Makefile, README.md, .env.example, docs/port-map.md?}` | **edit** (add v2, remove legacy) | AC4 |
| **koel_backend** `backends/copilotkit/` | **delete** | legacy GraphQL backend |
| `koel_runtime/lib/src/{copilot_runtime_agent.dart core logic, conversion/message_conversion.dart, copilot_runtime_auth_interceptor.dart, error/copilot_runtime_error_classifier.dart logic}`, `pubspec.yaml` | **keep** (logic untouched) | 5.10 sealed; D5 already reversed |

**Highest-risk gotcha:** the rename touches a **`koel_test` public API** (`loadCopilotkitRuntime`). The only live caller is `koel_test/test/fixtures_test.dart` (the GraphQL fixture tests in `koel_runtime` that also referenced it are *deleted* in Task 1). Grep `loadCopilotkitRuntime` repo-wide **before** renaming to confirm no other caller, then rename in lockstep — a missed caller is a compile break, not a silent bug. Likewise grep `copilotkit_runtime` (string) repo-wide; every hit is in the files this story edits.

### The live v2 wire (authoritative, unchanged from 5.10 — `@copilotkit/runtime@1.59.4`)

Source: `spike-copilotkit-v2-2026-06-05.md` + `../koel_backend/backends/copilotkit_v2/` (cite the spike token in published dartdoc; never the `../koel_backend/...` path). Route `POST {base}/agent/{agentName}/run`; `Accept: text/event-stream`; complete `RunAgentInput` body (the runtime 500s on a partial one — already satisfied by `HttpAgent.encodeBody`); response is `data: {<canonical AG-UI event>}` per frame — a **transparent passthrough**: `RUN_STARTED`/`RUN_FINISHED` on the wire, `STATE_DELTA` delivered (not collapsed), `RUN_ERROR` delivered (not swallowed), `STEP_*`/`CUSTOM` pass through. The backend registers `koel_scripted` (`server.mjs:14`); `agent.mjs` scenarios = `text`/`tool`/`state`/`error` selected by last-user-message content (`scenarioFor`). The `state` scenario emits `STATE_SNAPSHOT` then `STATE_DELTA([{op:replace,path:/count,value:2}])`; the `error` scenario emits `RUN_ERROR` then completes (no `RUN_FINISHED`). These are the two headline proofs vs the GraphQL 7/28.

### Why the GraphQL code is safe to delete now (orphaning is complete)

5.10 already (a) dropped the barrel export of `multipart_graphql_stream_parser.dart`, (b) rewrote the agent to `extends HttpAgent` (no parser/converter use), (c) repointed the two legacy GraphQL tests from the barrel to `package:koel_runtime/src/...` so they kept passing in isolation. So the parser + converter are reachable **only** from their own tests. Deleting those four files + the `_support.dart` builders removes the entire GraphQL subtree with zero impact on the v2 agent, which has been the sole production path since 5.10. The conformance + agent tests for v2 do not touch any GraphQL symbol.

### Deferred-work reconciliation (RESOLVED #3 detail — the exact mapping)

- **RETIRE with the deleted code** (bug-class vanishes, not fixed): **AI-5.1** (mid-stream `@defer` ordering buffer in `GraphQLIncrementalConverter`), **AI-5.4** (tool-role null-`toolCallId`/`name` → null GraphQL `resultMessage` fields, `copilot_runtime_agent.dart` GraphQL mapper), **AI-5.5** (silent-truncation `sawPart`/`terminatorSeen` guard in the multipart parser), **AI-5.7** (GraphQL-agent test-strengtheners: mid-stream ProtocolError replay, owned-client close, role coverage, `ResultMessageOutput` response arm) — plus the GraphQL-specific "Deferred from code review of 5-7" (silent truncation, `ResultMessageOutput` forward-mapping), "…of 5-8" (the two `_query` selection-set items: `metaEvents @stream`, `ImageMessageOutput`), and the 5.9-pass-2 "copilotkit per-scenario version stamp leak" + "Conformance Test B reframe unguarded" items — **all reference deleted files** (`graphql_event_conversion.dart`, the GraphQL `_query`, `_captureCopilotkit`'s GraphQL path, the deleted Test B).
- **SURVIVE** (live code, unrelated to transport): **AI-5.2** (`koel_core` `Message.timestamp` re-serialization omit — a kernel fix, keep), **AI-5.8** (cancel-teardown doc), and the two **capture-tool** items from the 5.9 review — `_normalizeUuids` over-normalization + `_postSseRun` one-object-per-`data:`-line (both in surviving `tool/capture_fixtures.dart`; `_postSseRun` now carries the v2 capture, so its robustness item is *more* relevant — note that).
- **AUTO-SATISFIED**: **AI-5.3** (connect/read timeouts) — the v2 agent inherits `HttpAgent.connectTimeout`/`readTimeout` structurally; no agent-level code carries it anymore.

### Inherited machinery (already done in 5.10 — do not touch)

The v2 agent is a thin `HttpAgent` subclass: it overrides only `encodeBody` (messages canonicalization via `copilotRuntimeMessageToWire`) + `errorClassifier` (status map + `transportErrorClassifier` delegate), prepends a default-ON `CopilotRuntimeAuthInterceptor`, and inherits SSE parse + timeouts + adapter-never-throw + `synthesizeChunks` (the 25/28 surface). 5.11 changes **none** of this — it removes the predecessor and seals the fixtures/conformance/docs around it.

### Project structure & conventions

- Backend-bridge layout (`architecture.md` ~868-887): agent at `lib/src/<name>_agent.dart`; `conversion/`; auth interceptor + `error/<name>_error_classifier.dart`. After this story `koel_runtime` matches agno/langgraph **exactly** (no `multipart_graphql_stream_parser.dart`).
- **AR-20:** adapters import only `koel_core.dart` + `koel_http.dart` barrels, never `src/` paths (the deleted GraphQL tests' `src/` imports go away with them).
- **D5 — REVERSED** (SCP-2026-06-05; already in `pubspec.yaml`/architecture.md from 5.10): `koel_runtime` depends on `koel_http`; nothing in 5.11 re-touches the dependency graph.
- Fixtures: bare-backend-name dirs (`agno/`, `langgraph/`, `dojo/`, now `copilotkit/`); `_session` header schema `{koelVersion, adapter, captured, threadId, runId, synthesized, backendVersion}`; `FixtureLoader.load<Backend>` per dir.

### Testing standards

- `package:test` + `package:http/testing.dart`. Conformance: `@Tags(['conformance'])`, replay committed fixtures + the synthesized `all_event_types` corpus through `MockClient`/`sseClient` — offline, VM-only. freezed `==` for event equality; `_`-prefixed helpers.
- Coverage ≥80/80 (`coverage_options.yaml` + `tool/coverage.sh packages/koel_runtime 80 80`). Deleting ~750 LOC of GraphQL *test* files removes coverage of ~626 LOC of GraphQL *lib* code in the same stroke — net the gate should *rise* (less untested-able surface), but **run it** (5.10 left 100% line / 94.55% branch on the kept v2 surface, comfortably clear).
- `dart analyze` zero warnings (NFR-13), incl. `exhaustive_switch_must_have_default` if any new `switch` on `MessageRole` appears (the v2 message conversion uses a map literal + `if`-guards, no switch — keep it that way).

### Git Intelligence (recent commits)

- `eed21d0 feat(story-5.10): CopilotRuntimeAgent v2 …` (this story's baseline) — the v2 agent + seams + offline tests + orphaned GraphQL files; 5.11 is the removal/seal on top.
- `328e5f8` / `70b89f8` — SCP-2026-06-05 correct-course (D5 reversal, 5.7–5.9 superseded, 5.10/5.11 added) + AI-5.1..5.8 debt-pass close-out.
- `099c2f5`/`48e3887`/`2fd43e3` (5.4/5.5/5.6 langgraph) + `a0456e2` (5.7 GraphQL parser) / 5.8 / 5.9 — the langgraph **template** (conformance real-fixture replay, classifier seal) and the GraphQL bridge **being removed** here.
- **Auto-commit:** when `bmad-code-review` flips this story to `done`, commit all related koel-repo changes in the same turn — **after** confirming `analyze`/`test`/`format:check`/`conformance`/coverage all green (the 5.6 red-format-gate incident is the standing caution). The **koel_backend** changes are a separate repo — commit them there independently (its own working tree).

### Latest Tech Information

- **CopilotKit pin:** reference backend `@copilotkit/runtime@1.59.4` + `@ag-ui/client@0.0.55` (`copilotkit_v2/README.md`). v2 (≥1.52) native AG-UI/SSE; GraphQL EOL ≤1.8.14 — removed here. Fixture `backendVersion` stamp `copilotkit==1.59.4`.
- **Dart deps:** **no change** — `koel_core` + `koel_http` + `http: ^1.6.0` (D5 already reversed in 5.10). No new external packages; no `graphql`/`gql` (never was).
- **Docker base:** `node:24-bookworm-slim` (mirror the legacy `copilotkit` Dockerfile + the house Node pattern); v2 is install+run only (no Next build phase — `server.mjs`/`agent.mjs` are plain ESM).

### References

- [Source: _bmad-output/planning-artifacts/epics/epic-5-backend-bridges-koelagno-koellanggraph-koelruntime.md#Story-5.11]
- [Source: _bmad-output/planning-artifacts/sprint-change-proposal-2026-06-05.md] — Path D removal, D5 reversal, OQ-4 pre-authorization, the §4.3 5.11 brief, the §2 debt-pass supersession map
- [Source: _bmad-output/planning-artifacts/spike-copilotkit-v2-2026-06-05.md] — live v2 wire (route, complete-input, full-matrix fidelity, 4 scenarios)
- [Source: _bmad-output/implementation-artifacts/5-10-copilot-runtime-v2-agent.md] — the v2 agent this story seals around (Blast-radius, "orphaned not deleted" scope boundary, inherited machinery)
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] — AI-5.1..5.8 + the 5.7/5.8/5.9 review items reconciled by RESOLVED #3
- [Source: _bmad-output/planning-artifacts/architecture.md#D5] (REVERSED), #AR-10 (retired), #AR-20, #A.5, backend-bridge layout ~868-887
- Templates to clone: `packages/koel_agno/test/conformance_test.dart` (real-fixture replay + synthesized 25/28), `packages/koel_langgraph` capture branch in `tool/capture_fixtures.dart` (SSE multi-scenario capture via `_postSseRun`), `packages/koel_test/test/fixtures_test.dart` (presence + decode groups), `koel_backend/backends/copilotkit/Dockerfile` (Node multi-stage — simplify to install+run for v2)
- koel_backend (sibling repo, **do not cite in published dartdoc**): `backends/copilotkit_v2/{server.mjs,agent.mjs,README.md,package.json}` (route :8005, `koel_scripted`, scenarios, pins), `docker-compose.yml` / `Makefile` / `README.md` / `.env.example` (the patterns to mirror + the legacy `copilotkit` refs to remove)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Claude Opus 4.8, 1M context) via `/bmad-dev-story`, Flutter-engineer specialist loaded.

### Debug Log References

- `git tag archive/koel-runtime-graphql` (koel) + `archive/copilotkit-graphql-backend` (koel_backend) — verified parser/converter preserved in the koel tag before deletion.
- v2 capture: started `node server.mjs` on :8005, probed the `state` scenario wire (no `x-copilotkit-runtime-version` header → falls back to pinned `1.59.4`; wire fully deterministic — `t`/`r`, scripted ids — so **no** id normalization needed), then `dart run tool/capture_fixtures.dart --backend=copilotkit` → 4 fixtures (8/6/4/2 events).
- Gates (koel): `melos run format:check` 0-changed · `melos run analyze` all "No issues found!" (11 pkgs) · `melos run test` full-workspace SUCCESS · `melos run conformance` green ×3 adapters · `tool/coverage.sh packages/koel_runtime 80 80` → **line=100% (48/48) branch=100% (23/23)**, EXIT=0.
- Cross-repo smoke (koel_backend): `docker compose --profile copilotkit_v2 up --build` → container Up, `POST :8005/api/copilotkit/agent/koel_scripted/run` served `STATE_SNAPSHOT + STATE_DELTA`; torn down clean. Committed in koel_backend `442e324`.

### Completion Notes List

- **AC1** — Archive tag created at baseline (parser + converter preserved); the 4 orphaned GraphQL files deleted, `test/conversion/` dir gone, `_support.dart` trimmed to the SSE helpers (multipart builders + their doc comment removed; the line-55 `copilotkit_runtime/` comment vanished with that block). Barrel was already clean (5.10). One stale `MultipartGraphQLStreamParser` example in `koel_runtime/analysis_options.yaml` repointed to `CopilotRuntimeAuthInterceptor`. Zero `graphql`/`gql` deps (never was).
- **AC2** — `FixtureLoader.loadCopilotkitRuntime → loadCopilotkit` (`_load('copilotkit', …)`, v2 dartdoc). `tool/capture_fixtures.dart`: `_backends` key `copilotkit_runtime:5.9 → copilotkit:5.11`; `_copilotkitDefaultVersion 1.8.14 → 1.59.4`; `_captureCopilotkit` **rewritten** to native SSE via `_postSseRun` (new optional `onResponseHeaders` cb reads the version header opportunistically); the GraphQL machinery (`_copilotkitEventWire`, `_HeaderCapturingClient`, the GraphQL POST) + the `package:http`/`koel_core`/`koel_runtime` imports removed → the tool is **zero-dep `dart:io`/`dart:convert`** again. 4 real fixtures captured (`synthesized:false`, `backendVersion:copilotkit==1.59.4`); `state_delta_basic` carries STATE_SNAPSHOT **+ STATE_DELTA**, `error_path` carries a wire RUN_ERROR — the two headline proofs. Old `copilotkit_runtime/` dir + 3 GraphQL fixtures deleted.
- **AC3** — `conformance_test.dart`: added 3 real-fixture replay tests (`text_only_run` verbatim + `state_delta_basic`→asserts `StateDeltaEvent` + `error_path`→asserts `RunErrorEvent` on the wire); synthesized 25/28 test unchanged. `fixtures_test.dart`: `copilotkit_runtime` groups/dirs/loader → `copilotkit`, re-pointed at the 4 v2 scenarios. `conformance.yml` header comment updated for the GraphQL→v2 lane swap (stays offline-replay). `melos run conformance` green across agno + langgraph + v2.
- **AC4 (koel_backend, committed `442e324`)** — `copilotkit_v2/Dockerfile` (node:24-bookworm-slim, `npm ci` → `server.mjs`/`agent.mjs`, ENV/EXPOSE 8005, LABEL 1.59.4) + `.dockerignore`; compose `copilotkit_v2` service (profile, `${COPILOTKIT_V2_PORT:-8005}:8005`), legacy `copilotkit` service removed; `Makefile` `up-copilotkit-v2` (legacy removed); `backends/copilotkit/` deleted entirely; README/port-map/.env.example repointed. `make up-copilotkit-v2` smoke green.
- **AC5** — `koel_runtime/README.md` rewritten for native-SSE v2 (v2 ctor `endpoint`/`agentName`/`authToken`, ≥1.52 pin / ≤1.8.14 removed, full-matrix 25/28 surface; 7/28 table + RUN_ERROR-swallow section dropped; cites `SPIKE-CK-V2`, no machine-local paths). Kept-lib dartdoc swept (`copilot_runtime_agent.dart` forward-ref "5.11 deletes" → past tense; error-classifier + message-conversion already past-tense). `architecture.md` drops the `multipart_graphql_stream_parser.dart` layout line (now identical-shape to siblings); D5 REVERSED / AR-10 retired confirmed; `graphqlEndpoint` zero hits. `deferred-work.md` gains the "Reconciled in: Story 5.11" section applying RESOLVED #3 (RETIRE AI-5.1/5.4/5.5/5.7 + GraphQL-specific 5.7/5.8/5.9 review items; SURVIVE AI-5.2/5.8 + the two capture-tool items; AI-5.3 auto-satisfied).
- **AC6** — all koel gates green (above); koel_backend smoke green; sanity grep: zero `copilotkit_runtime`/`loadCopilotkitRuntime`/`MultipartGraphQLStreamParser`/`graphql_event_conversion` under `packages/`/`tool/`/`.github/` (excl. regenerated `coverage/` + historical deferred-work prose), `--backend=copilotkit` is the only CopilotKit capture flag. The koel-repo commit is left to the code-review→done step (per project policy); `epic-5 → done` flips at that point.
- **FYI (parity calls, no question bounced)** — (1) v2 capture needs **no id normalization** (the scripted v2 agent fixes every message/tool id and reuses input `threadId`/`runId`; verified deterministic via wire probe), unlike agno/langgraph/dojo. (2) The v2 runtime sends **no** `x-copilotkit-runtime-version` header (probed), so the stamp uses the pinned `1.59.4` default — the `onResponseHeaders` read is opportunistic/forward-safe. (3) RUN_STARTED echoes an `input` field on the v2 wire; deterministic per scenario, decodes identically in loader + replay, so it needs no handling.

### File List

**koel (this repo):**
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (M)
- `_bmad-output/implementation-artifacts/5-11-remove-graphql-bridge-v2-backend-conformance.md` (M)
- `_bmad-output/implementation-artifacts/deferred-work.md` (M)
- `_bmad-output/planning-artifacts/architecture.md` (M)
- `.github/workflows/conformance.yml` (M)
- `tool/capture_fixtures.dart` (M)
- `packages/koel_runtime/README.md` (M)
- `packages/koel_runtime/analysis_options.yaml` (M)
- `packages/koel_runtime/lib/src/copilot_runtime_agent.dart` (M)
- `packages/koel_runtime/lib/src/multipart_graphql_stream_parser.dart` (D)
- `packages/koel_runtime/lib/src/conversion/graphql_event_conversion.dart` (D)
- `packages/koel_runtime/test/_support.dart` (M)
- `packages/koel_runtime/test/conformance_test.dart` (M)
- `packages/koel_runtime/test/multipart_graphql_stream_parser_test.dart` (D)
- `packages/koel_runtime/test/conversion/graphql_event_conversion_test.dart` (D; dir removed)
- `packages/koel_test/lib/src/fixture_loader.dart` (M)
- `packages/koel_test/test/fixtures_test.dart` (M)
- `packages/koel_test/lib/src/fixtures/copilotkit_runtime/{text_only_run,tool_call_basic,state_delta_basic}.jsonl` (D)
- `packages/koel_test/lib/src/fixtures/copilotkit/{text_only_run,tool_call_basic,state_delta_basic,error_path}.jsonl` (A — real v2 captures)
- git tag `archive/koel-runtime-graphql` (created at baseline `eed21d0`)

**koel_backend (sibling repo — committed separately as `442e324`):**
- `backends/copilotkit_v2/Dockerfile` (A), `backends/copilotkit_v2/.dockerignore` (A)
- `docker-compose.yml` (M), `Makefile` (M), `README.md` (M), `.env.example` (M), `docs/port-map.md` (M)
- `backends/copilotkit/` (D — entire legacy GraphQL backend)
- git tag `archive/copilotkit-graphql-backend`

## Change Log

| Date | Change |
|---|---|
| 2026-06-05 | Story implemented (dev-story). Removed the legacy CopilotKit GraphQL bridge (parser + converter + tests + `_support.dart` builders + 3 GraphQL fixtures, tagged `archive/koel-runtime-graphql`); renamed the fixture lane `copilotkit_runtime → copilotkit`; rewrote the capture branch to native SSE and captured 4 real v2 fixtures (`copilotkit==1.59.4`, incl. STATE_DELTA + RUN_ERROR headline proofs); added real-fixture conformance replay (green ×3 adapters); hardened + dockerized the koel_backend `copilotkit_v2` backend and deleted the legacy GraphQL backend (committed `442e324`); rewrote README/dartdoc/architecture + reconciled deferred-work (RESOLVED #3). All gates green (analyze/test/format:check/conformance, coverage 100/100). Status → review. |
