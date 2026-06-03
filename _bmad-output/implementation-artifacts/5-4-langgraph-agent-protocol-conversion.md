---
baseline_commit: cc05c7f00fb573564996ebe6836f27a90a0ea52e
---

# Story 5.4: `koel_langgraph` — `LangGraphAgent` + protocol conversion

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter/Dart developer,
I want `LangGraphAgent extends HttpAgent` targeting a LangGraph deployment URL — posting the canonical AG-UI `RunAgentInput` with an optional `x-api-key` header and parsing the deployment's AG-UI SSE back into typed events,
so that connecting to a LangGraph (`ag-ui-langgraph`) backend is one constructor call per FR-C2 + Addendum A.4.

## Acceptance Criteria

> **This is the langgraph-group OPENER story** (first of 5.4–5.6), mirroring how 5.1 opened the agno group. Two source-verified reconciliations are baked **RESOLVED** here, not invented — each replaces an epic phrase that the live-probed reference-backend contract (`../koel_backend/backends/langgraph/CONTRACT.md`, spikes closed 2026-06-02) contradicts:
> 1. **The epic AC2 asks message conversion to translate "LangGraph's protocol (events, channels, thread_state envelopes)".** The CONTRACT proves `ag-ui-langgraph==0.0.37` is **native AG-UI** on both edges: it receives a camelCase `RunAgentInput` directly and streams **canonical AG-UI SSE via the protocol `EventEncoder`** — no channels/thread_state envelope ever crosses the koel wire (that translation happens *server-side inside* `ag-ui-langgraph`). So the only real conversion is the same koel-`Message`-superset normalization 5.1 proved for agno. This is the exact precedent 5.1 set (agno "is native AG-UI; no response reshape"). See Dev Notes "Why there is no LangGraph-protocol conversion layer".
> 2. **Auth is `x-api-key`, not Bearer.** The epic says "the appropriate API-key header"; the CONTRACT (SPIKE-LG-AUTH) freezes that header as **`x-api-key`** (LangGraph-Platform convention), distinct from agno's `Authorization: Bearer`. The langgraph group has **no dedicated auth story** (5.5 = interrupt-resume, 5.6 = fixtures + classifier), so the API-key seam lands **here** in 5.4 per AC1's "posts … with the appropriate API-key header when supplied".
>
> **Scope boundary (mirrors 5.1, not 5.3).** 5.4 is the OPENER, not the sealer. It adds `lib/` source + unit tests + pubspec wiring + barrel + full dartdocs. It **defers to the 5.6 sealer** (exactly as 5.1 deferred to 5.3): `analysis_options.yaml`/`coverage_options.yaml`, the `test:coverage` gate entry, the conformance test + `conformance.yml` lane, real captured fixtures, and the README finalization. It does **not** add `LangGraphErrorClassifier` (Story 5.6) nor `resume()` (Story 5.5) — both are recorded Out-of-scope below.

**AC1 — `LangGraphAgent` constructor + endpoint + default-ON `x-api-key` auth (epic-stated; Addendum A.4, FR-C2, SPIKE-LG-AUTH).**
**Given** `packages/koel_langgraph/lib/src/langgraph_agent.dart`,
**When** I inspect the constructor,
**Then** it matches Addendum A.4 exactly: `LangGraphAgent({required Uri deploymentUrl, String? apiKey, http.Client? client, List<Interceptor>? interceptors})`,
**And** it `extends HttpAgent`, forwarding `client`/`interceptors` to `super` and POSTing to **`deploymentUrl` used as-is** (the full AG-UI route — **no** path segment is appended, unlike agno's `baseURL/agno-chat`; see Dev Notes "Why `deploymentUrl` is used verbatim"),
**And** a non-`http(s)` scheme or an authority-less `deploymentUrl` throws an `ArgumentError` **at construction** (fail-fast, reusing agno's `_agnoChatEndpoint` validation shape — scheme + authority guard, minus the suffix),
**And** a default-ON `LangGraphAuthInterceptor(apiKey: apiKey)` is **prepended outermost** to the interceptor chain (so a caller-supplied inner `AuthInterceptor` wins the merge), exactly as `AgnoAgent` prepends `AgnoAuthInterceptor`,
**And** `LangGraphAgent` does **not** override `errorClassifier()` (it inherits `HttpAgent`'s `DefaultErrorClassifier`; the langgraph-specific classifier is Story 5.6).

**AC2 — `x-api-key` auth interceptor, default-ON and no-op-when-empty (epic AC1 "appropriate API-key header"; SPIKE-LG-AUTH; AR-20).**
**Given** `packages/koel_langgraph/lib/src/langgraph_auth_interceptor.dart`,
**When** I inspect it,
**Then** `class LangGraphAuthInterceptor extends AuthInterceptor` accepts `{required String? apiKey}` and, via the inherited header-builder closure, injects **`x-api-key: <apiKey>`** (the **raw** key value — **not** `Bearer …`) per the CONTRACT,
**And** when `apiKey == null` or blank (empty/whitespace) the interceptor is a true **no-op** — no `x-api-key` header reaches the wire (the right default for the open local deployment, which ignores the header), mirroring `AgnoAuthInterceptor`'s blank-token no-op,
**And** with `LangGraphAgent(deploymentUrl: …, apiKey: 'k')` (no explicit interceptor list), a run carries `x-api-key: k` on the outgoing POST (verified by request inspection), and the header is **absent** when `apiKey` is null,
**And** the key rides only as a header — it is **never** serialized into the request body (inherited `AuthInterceptor` `transportHeadersKey` plumbing strips it before encoding).

**AC3 — message conversion = canonical-AG-UI normalization (epic AC2, reconciled to the native-AG-UI contract; FR-C2).**
**Given** `packages/koel_langgraph/lib/src/conversion/message_conversion.dart`,
**When** I inspect it,
**Then** it exposes a single internal function `langGraphMessageToWire(Message message)` that normalizes a koel `Message` **down to canonical AG-UI** — emits `{id, role, content}` always, adds `toolCallId`/`name` **only when non-null** (absent, never explicit `null`), and **drops** koel's non-AG-UI `Message.timestamp` (canonical AG-UI has no `timestamp`),
**And** there is **no** `LangGraphConversionOptions` class — Addendum A.4 exposes **no** `conversion` constructor param, so an options type would be unreachable vestigial surface (CLAUDE.md "no just-in-case"; this is the one deliberate divergence from agno's `AgnoConversionOptions`, which existed only because A.3 exposed a `conversion` param),
**And** `LangGraphAgent` overrides `HttpAgent.encodeBody` to remap only the `messages` array through `langGraphMessageToWire` (`{...super.encodeBody(input), 'messages': [...]}`), leaving every other `RunAgentInput` field to the inherited canonical `encodeRunAgentInput`,
**And** the conversion is exercised by `message_conversion_test.dart` covering: tool/name present vs absent, the timestamp drop, every `MessageRole`, and empty-content.

**AC4 — request wire-format + inherited SSE parse round-trip (epic-stated; FR-C2, via inherited `HttpAgent`).**
**Given** a `LangGraphAgent(deploymentUrl: …, client: mockClient)` driven by a `MockClient` (`package:http/testing.dart`),
**When** it runs a `RunAgentInput`,
**Then** the captured outgoing request is `POST <deploymentUrl>` with `Content-Type: application/json` + `Accept: text/event-stream`, body = camelCase `RunAgentInput` (`{threadId, runId, state, messages[], tools[], context[], forwardedProps}`) whose `messages` are the `langGraphMessageToWire`-normalized maps (canonical AG-UI, no `timestamp`),
**And** when the `MockClient` replays **the existing synthesized `all_event_types` corpus re-framed as AG-UI SSE** (`data: <payload>\n\n`, reusing the `agno_agent_test.dart` `sseBody`/`sseClient` helper shape), `LangGraphAgent.run(input)` emits the **25 canonical AG-UI types verbatim** through its **inherited** `HttpAgent` transport+parse (the 3 `*_CHUNK` shapes are `synthesizeChunks`-normalized at the transport — the source-verified 25/28 finding from Story 5.3; `LangGraphAgent` overrides only `encodeBody`, never the response path),
**And** a wire `RUN_ERROR` in the replayed stream rides through as a plain emitted `AgUiEvent` (it does **not** throw / terminate — the chain classifier fires only on transport/parser *throws*, per the 5.3 source-verified mechanism).

**AC5 — package wiring: deps, barrel, dartdocs (opener finalization; FR-C2, NFR-13).**
**Given** `packages/koel_langgraph/pubspec.yaml` today carries only `dev_dependencies: koel_lints`,
**When** I inspect the package after this story,
**Then** `pubspec.yaml` gains `dependencies: koel_core:` + `koel_http:` (bare workspace keys) + `http: ^1.6.0`, and `dev_dependencies: test: ^1.25.0` + `koel_test:` — **mirroring koel_agno's pubspec exactly** (same comment-documented rationale style; `version: 0.0.1`, `publish_to: none`, `resolution: workspace` unchanged),
**And** `packages/koel_langgraph/lib/koel_langgraph.dart` (the barrel) exports the public surface: `src/langgraph_agent.dart` and `src/langgraph_auth_interceptor.dart` in full; `src/conversion/message_conversion.dart` is **not** exported (no public type — `langGraphMessageToWire` stays internal, consumers configure via the agent; mirrors agno's barrel comment, minus the options type agno had to export),
**And** every exported public member (`LangGraphAgent` + its `deploymentUrl`/`apiKey`/ctor, `LangGraphAuthInterceptor` + its ctor) carries a dartdoc — written now so the **5.6 sealer's** `public_member_api_docs` gate (turned on there, as 5.3 turned it on for agno) passes clean with no backfill,
**And** the README finalization (the default-ON `x-api-key` convention note, the `deploymentUrl`-verbatim note) is **deferred to the 5.6 sealer** (recorded Out-of-scope), exactly as the agno README sentence deferred from 5.2 to the 5.3 sealer.

**AC6 — gates green for what exists now (epic-stated NFR-13; coverage-gate enforcement deferred to 5.6).**
**Given** all of the above,
**When** I run the workspace gates,
**Then** `dart analyze packages/koel_langgraph` exits **0** (NFR-13) under the inherited **root** `analysis_options.yaml` (koel_langgraph adds **no** package-level `analysis_options.yaml` — that, with the member-doc gate, is the 5.6 sealer's job, mirroring koel_agno having none until 5.3),
**And** `dart test packages/koel_langgraph` is green (the new `langgraph_agent_test.dart` + `message_conversion_test.dart` + `langgraph_auth_interceptor_test.dart`),
**And** `dart run melos test` (full workspace) shows **no regression** in koel_core / koel_http / koel_test / koel_agno (5.4 is additive — a previously source-only package gains code; nothing else is touched),
**And** `bash tool/format.sh check` is clean,
**And** coverage for koel_langgraph is **not yet gated** here — the `test:coverage` entry + `coverage_options.yaml` are the **5.6 sealer's** wiring (as agno's gate wiring was the 5.3 sealer's); 5.4 nonetheless writes tests that exercise the full `lib/` surface so 5.6's ≥80% gate lands green.

## Tasks / Subtasks

- [x] **Task 1 — pubspec deps first (AC5).** The agent/interceptor/conversion source can't compile until koel_langgraph dependencies resolve. **DO THIS FIRST** (mirror 5.1/5.3's "open the substrate before the consumer").
  - [x] Added `dependencies: { koel_core:, koel_http:, http: ^1.6.0 }` and `dev_dependencies: { koel_lints:, test: ^1.25.0, koel_test: }` to `packages/koel_langgraph/pubspec.yaml`, copying koel_agno's pubspec comment style. `version: 0.0.1` / `publish_to: none` / `resolution: workspace` unchanged.
  - [x] `dart pub get` resolved the new edges against the pub workspace (single root resolve).

- [x] **Task 2 — `LangGraphAuthInterceptor` (AC2).**
  - [x] `packages/koel_langgraph/lib/src/langgraph_auth_interceptor.dart`: `class LangGraphAuthInterceptor extends AuthInterceptor` with `{required String? apiKey}`; injects `{'x-api-key': apiKey}` (raw value, not `Bearer`), blank/null → no-op. Mirrors `AgnoAuthInterceptor` except header name + raw value.
  - [x] Dartdoc: default-ON `x-api-key` convention, blank → no-op, SPIKE-LG-AUTH evidence (langgraph open, header is koel-side convention), inherited plumbing.
  - [x] `langgraph_auth_interceptor_test.dart`: null/blank/whitespace → no header; non-blank → raw `x-api-key` (asserts not `Bearer`, no `authorization` key, not on body).

- [x] **Task 3 — message conversion (AC3).**
  - [x] `packages/koel_langgraph/lib/src/conversion/message_conversion.dart`: a single internal `langGraphMessageToWire(Message)` — `{id, role, content, toolCallId?, name?}`; no timestamp, no options class.
  - [x] Dartdoc: native-AG-UI CONTRACT finding (no protocol/channels/thread_state translation), and why there is no options class (A.4 has no `conversion` param).
  - [x] `message_conversion_test.dart`: every `MessageRole`; tool/name present vs absent; timestamp always dropped; no explicit-null cross-product.

- [x] **Task 4 — `LangGraphAgent` (AC1, AC3-encodeBody, AC4).**
  - [x] `packages/koel_langgraph/lib/src/langgraph_agent.dart`: `class LangGraphAgent extends HttpAgent` with the Addendum-A.4 ctor; prepends `LangGraphAuthInterceptor(apiKey: apiKey)` outermost; holds `apiKey` as a documented `final` field.
  - [x] `_validateDeploymentUrl(Uri)`: scheme(`http`/`https`)+`hasAuthority` `ArgumentError` guards, returns `deploymentUrl` **unchanged** (verbatim — no `pathSegments` rewrite).
  - [x] Overrides `encodeBody` to remap `messages` through `langGraphMessageToWire`. Does **not** override `errorClassifier()` (inherits `DefaultErrorClassifier` — Story 5.6 owns the langgraph mapping).
  - [x] Dartdoc the class: native-AG-UI, `deploymentUrl`-verbatim rationale, default-ON `x-api-key`, classifier + `resume()` → 5.6 / 5.5.

- [x] **Task 5 — barrel + agent tests (AC4, AC5).**
  - [x] `lib/koel_langgraph.dart`: exports `src/langgraph_agent.dart` + `src/langgraph_auth_interceptor.dart`; does **not** export the conversion file (no public symbol). Barrel comment mirrors agno (minus the options export).
  - [x] `langgraph_agent_test.dart` (`@TestOn('vm')`): (a) `POST <deploymentUrl>` verbatim for `/agent`, a bare authority, and an arbitrary `/v2/runs/stream` route (proves no suffix); (b) `ArgumentError` for relative / `file://` / `ftp://` / authority-less; (c) messages canonical (no timestamp, no null keys); (d) `x-api-key` present/absent per apiKey + inner-interceptor override; (e) **inherited-parse round-trip** replaying synthesized `text_only_run`/`tool_call_basic` (mirrors `agno_agent_test`); (f) a 401 surfaces as a terminal `RunErrorEvent`, not a throw (inherited `DefaultErrorClassifier`). **Decision:** used the fixture round-trip (not a full `ConformanceRunner` 25/28 assertion) per the AC's stated latitude — the formal conformance lane is the 5.6 sealer's; duplicating it here before the sealer would be redundant. `test/_support.dart` carries `fixturePayloads`/`sseBody` (dropped agno's `sseClient` — unused without a conformance test, CLAUDE.md no-vestigial).
  - [x] No `dart_test.yaml`/`conformance` tag — the lane is Story 5.6.

- [x] **Task 6 — gates + close-out (AC6).**
  - [x] `dart analyze packages/koel_langgraph` → **0**; `dart run melos analyze` → SUCCESS (all 11 pkgs). `dart test packages/koel_langgraph` → **+26**. `dart run melos test` → SUCCESS (no regression: koel_core +576, koel_http +97, koel_lints +5, …). `bash tool/format.sh check` → clean (after `dart format`). Coverage (informational, gate is 5.6): line=100% (27/27), branch=100% (11/11).
  - [x] Recorded the 5.4→5.6 sealer hand-offs in `deferred-work.md` (analysis_options + member-doc gate, coverage_options, `test:coverage` entry, conformance test + `conformance.yml` lane, real captured fixtures, README finalization) + the 5.6 classifier / 5.5 `resume()` siblings.

- [ ] **Out of scope for 5.4 — record, do not implement:**
  - **`LangGraphAgent.resume(threadId, resumeValue)`** (Addendum A.4's second method) → **Story 5.5**. The CONTRACT (SPIKE-LG-RESUME) already froze its wire: POST the **same `deploymentUrl`** a `RunAgentInput` with the **same `threadId`** + `forwardedProps: {"command": {"resume": <resumeValue>}}` (`runId` may be new); interrupt surfaces as a `CUSTOM` event `{name: "on_interrupt", value: …}`. Do **not** stub `resume()` in 5.4 — adding it as a throwing placeholder is vestigial surface; 5.5 owns the method end-to-end.
  - **`LangGraphErrorClassifier extends DefaultErrorClassifier`** + the `errorClassifier()` override → **Story 5.6** (graph-state-mismatch → `agentInternal`, version-drift → `protocolVersionDrift`, 401/403 → `businessAuth`). 5.4 leaves `LangGraphAgent` on the inherited `DefaultErrorClassifier`.
  - **Real captured fixtures** (`tool/capture_fixtures.dart --backend=langgraph`, operator `make up-langgraph`) + **`ConformanceRunner` green** + **`conformance.yml` langgraph lane** + **coverage gate** + **`analysis_options.yaml`/`coverage_options.yaml`** + **README finalization** → **Story 5.6** (the langgraph-group sealer, as 5.3 sealed agno).
  - **The koel_http case-sensitive header-merge fix + interceptor-disposal seam** (5.2 deferrals — architectural, not triggered here).

### Review Findings

_Code review 2026-06-03 (Blind Hunter + Edge Case Hunter + Acceptance Auditor). 1 decision-needed, 1 patch, 1 defer, 9 dismissed as noise. Si directed "làm đúng chuẩn" → the decision was resolved as a patch (trim + backport). Both patches applied + verified._

- [x] [Review][Patch] Whitespace-padded non-blank `apiKey` is now **trimmed** before it reaches the `x-api-key` header [langgraph_auth_interceptor.dart:33] — was emitting the raw value while the blank-detection trimmed (`apiKey: ' abc\n'` rode to the wire verbatim — a padded-key 401 source and a trailing-newline header-injection vector). Now `{'x-api-key': apiKey.trim()}`. **Backported to the agno twin** (`AgnoAuthInterceptor` → `'Bearer ${token.trim()}'`) to keep the mirror in sync. Regression test added to both (`'  abc\n'` → `'abc'`). (Source: blind+edge)
- [x] [Review][Patch] AC3-enumerated **empty-content** conversion test added [message_conversion_test.dart] — AC3 (line 48) + Task 3 explicitly list "tool/name present vs absent, the timestamp drop, every `MessageRole`, **and empty-content**". Added `empty content is emitted verbatim — the key is present, not dropped` (asserts `content: ''` stays in the wire map, never omitted). (Source: auditor)
- [x] [Review][Defer] `test/_support.dart` helper robustness — `resolved!` force-unwrap (`:18`), `.skip(1)` `_session`-header assumption (`:21`), and unguarded `jsonDecode … as Map` casts (`:22-24`) all fail opaquely on a missing/renamed/malformed fixture — deferred, faithful mirror of agno's `_support.dart`, inputs are known-good bundled fixtures only, test-infra only. (Source: blind+edge)

## Dev Notes

### Why there is no LangGraph-protocol conversion layer (the AC3 decision, baked RESOLVED with evidence)

The epic's AC2 asks `message_conversion.dart` to translate "LangGraph's protocol (events, channels, thread_state envelopes per LangGraph docs)". That is contradicted by the **source-verified, docker-probed** reference contract — and the resolution is the exact precedent Story 5.1 set for agno.

Evidence (`../koel_backend/backends/langgraph/CONTRACT.md`, SPIKE-LG-RESUME + SPIKE-LG-AUTH, live 2026-06-02; `ag-ui-langgraph==0.0.37` source read at `site-packages/ag_ui_langgraph/{endpoint,agent}.py`):
- `add_langgraph_fastapi_endpoint` registers a **single `POST {path}`** that receives a camelCase **`RunAgentInput` directly** (no foreign request envelope).
- The response is **canonical AG-UI SSE via the ag-ui-protocol `EventEncoder`** (`Accept`-negotiated). `ag-ui-langgraph` does the LangGraph-events↔AG-UI translation **server-side, inside the package** — channels / `thread_state` / checkpoint envelopes never cross the koel wire. From koel's side the stream is plain `AgUiEvent`s.
- Therefore `LangGraphAgent` needs **no response-path override** (pure inherited `HttpAgent` parse) and **no protocol-conversion layer**. The only genuine reconciliation is the same one 5.1 found for agno: koel's `Message` is a **superset** of the AG-UI message (it carries a koel-only `timestamp`), so request-side conversion strips that field down to canonical AG-UI. Hence `langGraphMessageToWire` is byte-for-byte the agno `agnoMessageToWire` logic — minus the options knob.

Decision (per memory ["No CYA open questions"] + ["Confirmed needs adversarial evidence"] — decide and bake with the contract cited): the conversion file is a **single canonical-AG-UI normalizer**, no protocol/channels/thread_state translation, no options class. This is more honest than minting a conversion layer for envelopes that `ag-ui-langgraph` already collapses (CLAUDE.md "every line earns its place").

### Why `deploymentUrl` is used verbatim (the AC1 endpoint decision, RESOLVED)

agno's A.3 ctor takes `baseURL` and koel appends the fixed route `/agno-chat`. langgraph's A.4 ctor deliberately names the param **`deploymentUrl`**, not `baseURL` — and koel POSTs to it **as-is**, appending nothing. Two pieces of evidence make this the right call, not a guess:
1. **The param name is a full URL** ("deployment URL"), not a base to extend. The PRD chose different names for the two adapters on purpose.
2. **`ag-ui-langgraph`'s route path is caller-configured** (`add_langgraph_fastapi_endpoint(..., path=…)`) — there is **no canonical suffix** koel could safely assume. The reference backend mounts it at `/agent`, but a real deployment may mount anywhere. Forcing a `/agent` suffix would break every non-default mount. The consumer passes the full AG-UI endpoint their deployment exposes (e.g. `http://localhost:8003/agent` for `make up-langgraph`, captured in Story 5.6).

Keep agno's **fail-fast validation** (reject non-`http(s)` / authority-less URIs with an `ArgumentError` at construction) — that guard is about catching a malformed target early, independent of whether a suffix is added. Just drop the `pathSegments` rewrite; return the URI unchanged.

> **If Si prefers a base-URL+suffix shape** (operator passes `http://localhost:8003` and koel appends a configurable route), that is a viable alternate — but it contradicts the A.4 `deploymentUrl` naming and the configurable-path reality, so this story bakes **verbatim** as the evidence-backed default. Flag at review if the deployment topology you target differs.

### Why `x-api-key`, default-ON, and why the auth seam lands in 5.4 (the AC2 decision)

- **Header name.** SPIKE-LG-AUTH grepped the entire `ag-ui-langgraph` source: **zero built-in auth** on the AG-UI route (no api-key / langsmith / `Authorization` / 401 / 403 handling — `endpoint.py` reads only `accept`). The `x-api-key` header is a **koel-side LangGraph-Platform convention** (the reference backend's `auth.py` enforces it via an opt-in `LANGGRAPH_API_KEY` toggle; missing → 401, wrong → 403, empty toggle → open). So the value is the **raw key under `x-api-key`** — *not* agno's `Authorization: Bearer`.
- **Default-ON is safe** for the same reason agno's is: the open local deployment ignores the header, so a default `x-api-key` is a harmless convention; `apiKey == null`/blank is a true no-op. A deployment that wants enforcement flips its `LANGGRAPH_API_KEY` toggle (then 401/403 → `businessAuth`, mapped by 5.6's classifier).
- **Why here and not a "5.x auth story":** the agno group split auth into its own Story 5.2 (`AgnoAuthInterceptor` + `AgnoErrorClassifier`). The langgraph group is split differently — 5.5 is interrupt-resume, 5.6 is fixtures+classifier — so there is **no** dedicated langgraph-auth story. AC1's "posts … with the appropriate API-key header when supplied" puts the api-key seam in 5.4. The **classifier** half (agno's 5.2 also carried) defers to **5.6**.

### Existing-code contracts that must not break

- **koel_langgraph is currently source-only** (scaffold barrel + empty pubspec deps). 5.4 is purely **additive** — it fills the package. Nothing in koel_core/http/test/agno is touched, so the only regression surface is the new deps resolving cleanly (`melos bootstrap`).
- **`AuthInterceptor` is the documented subclassing seam** (`class … implements Interceptor`, deliberately not `final`; its dartdoc names "Epic-5's `AgnoAuthInterceptor extends AuthInterceptor`"). `LangGraphAuthInterceptor` is the second sanctioned subclass. The header-injection plumbing (`transportHeadersKey` carrier, body-stripping, per-retry re-resolution, secret-free error wrapping) is **inherited unchanged** — do not re-implement it.
- **`HttpAgent.encodeBody` is the request-only seam** (`super.encodeBody` = `encodeRunAgentInput`, the canonical encoder). Override `messages` only; never the response path (langgraph is native AG-UI). Mirror `AgnoAgent.encodeBody` exactly.
- **Adapters never throw `KoelError`** (ARCH: every failure reaches the consumer as a terminal `RunErrorEvent`). The agent/auth tests assert **emitted events** / request shape; they must not expect a thrown error from `LangGraphAgent.run`. (Construction-time `ArgumentError` on a bad `deploymentUrl` is fine — that is a programmer error before any run, exactly like agno.)
- **`plugins:` is root-only** (Story 1.7 — `plugins_in_inner_options`). 5.4 adds **no** package `analysis_options.yaml` at all (5.6 sealer adds the koel_http/koel_test-shaped one). koel_langgraph inherits the root config until then.

### The 25/28 conformance contract (carried from Story 5.3 — don't re-derive)

If Task 5(c) asserts the full corpus: `koel_http`'s default-on `synthesizeChunks` ([http_agent.dart:65-75](packages/koel_http/lib/src/http_agent.dart#L65-L75), Story 4.8) normalizes the 3 `*_CHUNK` shapes into `START/CONTENT/END` at the transport. `LangGraphAgent` (like `AgnoAgent`) doesn't expose that flag (A.4), so it reproduces the **25 canonical types verbatim** and the 3 chunk shapes are synthesized away. Assert `passed` length 25 and `failed` **exactly** `{TEXT_MESSAGE_CHUNK, TOOL_CALL_CHUNK, REASONING_MESSAGE_CHUNK}` — a real langgraph backend never emits chunk shapes (canonical `EventEncoder`, CONTRACT.md). A wire `RUN_ERROR` in the corpus rides through as a plain emitted event (it does **not** terminate the stream — the chain classifier fires only on transport/parser *throws*; 5.3 source-verified this).

### `_session` / fixture provenance (informational — captures are Story 5.6)

5.4 writes **no** langgraph fixtures. The `langgraph/` fixtures dir keeps its `.placeholder` (the `koel_test/test/fixtures_test.dart` `pendingCaptureDirs` invariant from 5.3 already lists `langgraph` among the not-yet-captured dirs — leave it). 5.6 runs `tool/capture_fixtures.dart --backend=langgraph` against `make up-langgraph` (port 8003, `/agent`), stamping `adapter: koel_langgraph@0.0.1`, `synthesized: false`, `backendVersion: ag-ui-langgraph==0.0.37`. The inherited-parse round-trip in 5.4 reuses the **synthesized** corpus (`FixtureLoader.loadSynthesized(...)`), not a langgraph capture — exactly as `agno_agent_test.dart` reused synthesized fixtures before agno's own capture landed in 5.3.

### Source tree (what to touch)

```
packages/koel_langgraph/
├── pubspec.yaml                                   # UPDATE: add koel_core/koel_http/http deps + test/koel_test dev-deps (mirror koel_agno) (AC5)
├── lib/
│   ├── koel_langgraph.dart                         # UPDATE: barrel exports (agent + auth interceptor; NOT conversion) (AC5)
│   └── src/
│       ├── langgraph_agent.dart                    # NEW: LangGraphAgent extends HttpAgent (AC1, AC3-encodeBody, AC4)
│       ├── langgraph_auth_interceptor.dart         # NEW: LangGraphAuthInterceptor extends AuthInterceptor (x-api-key) (AC2)
│       └── conversion/message_conversion.dart      # NEW: langGraphMessageToWire (canonical AG-UI; no options class) (AC3)
└── test/
    ├── langgraph_agent_test.dart                   # NEW: request shape + endpoint-verbatim + x-api-key + inherited-parse round-trip (AC4)
    ├── langgraph_auth_interceptor_test.dart        # NEW: x-api-key present/no-op (AC2)
    ├── message_conversion_test.dart                # NEW: normalization cases (AC3)
    └── _support.dart                               # NEW (if Task 5(c) needs it): copy of agno's sseBody/sseClient helpers

_bmad-output/implementation-artifacts/deferred-work.md   # UPDATE: record the 5.4→5.6 sealer handoffs (Task 6)
```
**NOT touched** (Story 5.6 / 5.5 / sealer): `tool/capture_fixtures.dart` (langgraph branch stays stubbed), `koel_test/lib/src/fixtures/langgraph/*`, `.github/workflows/conformance.yml`, `pubspec.yaml` (root melos scripts), `packages/koel_langgraph/{analysis_options,coverage_options}.yaml`, `README.md`, `error/langgraph_error_classifier.dart`.

Adapter/test layout per architecture §ARCH (each adapter package owns its `lib/src/<name>_agent.dart` + tests; fixtures bundled in koel_test per D8).

### Testing standards

- **Harness:** reuse the koel_agno pattern — `MockClient` (`package:http/testing.dart`) for canned SSE + a request-capturing `MockClient` for the body/header assertions. `@TestOn('vm')` (koel_langgraph is offline/VM). Copy `sseBody`/`sseClient` into koel_langgraph's own `test/_support.dart` if the round-trip test needs them — do **not** import koel_agno's test dir (cross-package test imports don't resolve).
- **Auth test:** assert the **raw** `x-api-key` value (explicitly assert it is **not** prefixed `Bearer `), and that a null/blank apiKey emits no `x-api-key` header. Mirror `agno_auth_interceptor_test.dart`.
- **Endpoint test:** assert the captured request URL **equals** `deploymentUrl` (no suffix), and that a bad scheme / authority-less URI throws `ArgumentError` at construction.
- **Coverage:** not gated in 5.4 (the gate is the 5.6 sealer's wiring), but write tests covering the full `lib/` surface so 5.6's ≥80% line+branch gate lands green. The capture tool is out of scope (repo tool, not yet touched).
- **No suppressions:** keep `dart analyze` at 0 by writing dartdocs, not by disabling rules (the member-doc gate isn't on until 5.6, but write the docs now).

### Latest technical / wire facts (source-verified, not web-guessed)

From `../koel_backend/backends/langgraph/CONTRACT.md` (authoritative — `ag-ui-langgraph==0.0.37` source-read + docker-probed live 2026-06-02):
- **Route:** `POST /agent` (run **and** resume share it — there is no separate resume endpoint). Request `application/json` `RunAgentInput` camelCase; response `text/event-stream` canonical AG-UI via `EventEncoder`. **koel POSTs to `deploymentUrl` verbatim** (the operator supplies the full route).
- **Native AG-UI both edges** — no channels/thread_state envelope on the koel wire; the LangGraph↔AG-UI translation is internal to `ag-ui-langgraph`.
- **Auth:** zero built-in; `x-api-key` is a koel/LangGraph-Platform convention (reference `auth.py` opt-in `LANGGRAPH_API_KEY`: missing → 401, wrong → 403, empty → open). `/status` always open → `{"status":"ok","framework":"langgraph","version":"0.0.37"}`.
- **Interrupt-resume (Story 5.5, not 5.4):** same route, same `threadId`, resume value at `forwardedProps.command.resume` (camelCase); interrupt surfaces as `CUSTOM {name:"on_interrupt", value:<payload>}`; state rebuilt server-side from a single-process `MemorySaver` (restart resets it).
- **Determinism (Story 5.6 capture):** glue drops `EventType.RAW`/null `raw_event`; text run byte-stable after normalizing `[timestamp, runId, threadId, messageId, toolCallId]`.
- **Versions pinned:** `ag-ui-langgraph==0.0.37`, `langgraph 1.2.2`, `ag-ui-protocol 0.1.18`. No dep bump needed in 5.4 (koel_langgraph stays on `http: ^1.6.0`).

### References

- [Source: _bmad-output/planning-artifacts/epics/epic-5-backend-bridges-koelagno-koellanggraph-koelruntime.md#Story-5.4] — story ACs (LangGraphAgent, protocol conversion, request wire-format + inherited SSE parse).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#A.4] — the frozen `LangGraphAgent` ctor (`deploymentUrl`/`apiKey`/`client`/`interceptors`) + the `resume(...)` method deferred to Story 5.5.
- [Source: ../koel_backend/backends/langgraph/CONTRACT.md] — authoritative langgraph wire contract: `POST /agent`, native AG-UI both edges, `x-api-key` auth, `ag-ui-langgraph==0.0.37`, interrupt-resume shape (5.5), error→`RUN_ERROR` glue.
- [Source: _bmad-output/implementation-artifacts/epic-5-prep-plan.md] — Epic-5 build sequence + langgraph findings (resume at `forwardedProps.command.resume`; `on_interrupt` CUSTOM event).
- [Source: _bmad-output/implementation-artifacts/5-1-agno-agent-message-conversion.md] — the agno-is-native-AG-UI reconciliation precedent this story mirrors; `AgnoAgent` ctor/endpoint/encodeBody shape.
- [Source: _bmad-output/implementation-artifacts/5-3-agno-captured-fixtures-conformance.md] — the 25/28 chunk-synthesis conformance contract (AC4) + the sealer-defers-finalization pattern (5.6 ⟸ 5.4, as 5.3 ⟸ 5.1/5.2).
- [Source: packages/koel_agno/lib/src/agno_agent.dart] — `extends HttpAgent`, prepended default-ON auth, `_agnoChatEndpoint` validation shape (reuse minus the suffix), `encodeBody` messages override.
- [Source: packages/koel_agno/lib/src/agno_auth_interceptor.dart] — `extends AuthInterceptor` header-closure pattern (Bearer → `x-api-key`, blank → no-op).
- [Source: packages/koel_agno/lib/src/conversion/message_conversion.dart] — `agnoMessageToWire` (langgraph drops the options class).
- [Source: packages/koel_http/lib/src/interceptors/auth_interceptor.dart] — `AuthInterceptor` subclassing seam + `transportHeadersKey` plumbing (inherited, do not re-implement).
- [Source: packages/koel_http/lib/src/http_agent.dart#L165-L176] — `encodeBody` request-only seam (default `encodeRunAgentInput`); `synthesizeChunks` 25/28 normalization (L65-75).
- [Source: packages/koel_test/lib/src/fixture_loader.dart] — `FixtureLoader.loadSynthesized` (the AC4 round-trip corpus) + `loadLangGraph` (5.6's loader, already stubbed).
- [Source: packages/koel_agno/test/agno_agent_test.dart + test/_support.dart] — the `MockClient`/`sseBody`/`sseClient` harness the 5.4 tests reuse.

### Project Structure Notes

- koel_langgraph mirrors koel_agno's package shape: `lib/src/<name>_agent.dart` + `lib/src/<name>_auth_interceptor.dart` + `lib/src/conversion/message_conversion.dart` + `lib/src/error/` (the error file lands in 5.6, not 5.4). Hybrid versioning unchanged: `version: 0.0.1`, `publish_to: none`, bare workspace dep keys.
- The one deliberate divergence from agno's structure: **no `LangGraphConversionOptions`** (A.4 exposes no `conversion` param, so the options type would be unreachable) and **no package `analysis_options.yaml`/`coverage_options.yaml` yet** (5.6 sealer). Both are evidence-backed, not omissions.
- 5.4 adds new `lib/` source to a previously source-only package; it is additive and touches no other package. Re-run `melos bootstrap` after the pubspec change so the new edges resolve.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8, 1M context) — via `/bmad-dev-story`; `/agent-flutter-engineer` specialist loaded for all Dart work (CLAUDE.md mandate).

### Debug Log References

- **No surprises — a clean mirror of the agno opener (5.1).** The two source-verified reconciliations baked into the story (native-AG-UI ⇒ no protocol-conversion layer; `x-api-key` not Bearer) held: `LangGraphAgent` needed only the `encodeBody` `messages` override + a default-ON `x-api-key` interceptor, no response-path code. The `deploymentUrl`-verbatim decision (no `/agent` suffix) is covered by a 3-URL test (`/agent`, bare authority, arbitrary `/v2/runs/stream`).
- **Conformance assertion scope (decision).** The story's AC4 offered latitude between a full `ConformanceRunner` 25/28 assertion and a simpler fixture round-trip for the opener. Chose the round-trip (`text_only_run`/`tool_call_basic` via synthesized fixtures, mirroring `agno_agent_test`): the formal `ConformanceRunner` lane (`@Tags(['conformance'])` + `conformance.yml`) is the 5.6 sealer's deliverable, and asserting 25/28 here before the sealer would be redundant. Recorded in `deferred-work.md`.
- **`_support.dart` trimmed.** Copied agno's `fixturePayloads`/`sseBody` but dropped its `sseClient` helper — unused without a conformance test (CLAUDE.md no-vestigial); 5.6 re-adds it with the conformance lane.
- **Format gate is read-only `--set-exit-if-changed`.** `tool/format.sh check` reports would-be changes without writing; ran `dart format packages/koel_langgraph` (write) then re-checked clean (0 changed). Analyze + tests re-verified green after the reformat.
- **Gates:** `dart run melos analyze` → SUCCESS (11 pkgs, "No issues found"). `dart test packages/koel_langgraph` → **+26**. `dart run melos test` → SUCCESS, no regression (koel_core +576, koel_http +97, koel_lints +5, koel_langgraph +26). `tool/format.sh check` → clean. Coverage (informational; gate is 5.6): line 100% (27/27), branch 100% (11/11).

### Completion Notes List

- **COMPLETE — all 6 tasks + subtasks done, all gates green.** koel_langgraph went from source-only scaffold to a working langgraph-group opener: `LangGraphAgent extends HttpAgent` (deploymentUrl verbatim, default-ON `x-api-key`), `LangGraphAuthInterceptor extends AuthInterceptor`, canonical-AG-UI `langGraphMessageToWire` (no options class), barrel + pubspec wiring, full dartdocs.
- **Both reconciliations shipped as designed.** (1) No LangGraph-protocol conversion layer — `ag-ui-langgraph==0.0.37` is native AG-UI both edges (CONTRACT.md SPIKE-LG-RESUME), so conversion is just the koel-`Message`-superset timestamp drop. (2) Auth is `x-api-key` (raw value), not agno's `Authorization: Bearer` (SPIKE-LG-AUTH).
- **Additive only.** No other package touched; full workspace suite shows no regression. The new deps resolve via the pub workspace.
- **Deferred to 5.6 sealer (recorded):** `analysis_options.yaml` + member-doc gate, `coverage_options.yaml`, `test:coverage` gate entry, conformance test + `conformance.yml` lane, real captured fixtures (`make up-langgraph`), README finalization. **To 5.5:** `resume()`. **To 5.6:** `LangGraphErrorClassifier` + `errorClassifier()` override. None stubbed (a throwing placeholder would be vestigial).

### File List

- `packages/koel_langgraph/pubspec.yaml` — **MODIFIED**: added koel_core/koel_http/http deps + test/koel_test dev-deps (mirror koel_agno) (AC5).
- `packages/koel_langgraph/lib/koel_langgraph.dart` — **MODIFIED**: barrel exports `langgraph_agent.dart` + `langgraph_auth_interceptor.dart` (not conversion) (AC5).
- `packages/koel_langgraph/lib/src/langgraph_agent.dart` — **NEW**: `LangGraphAgent extends HttpAgent` (deploymentUrl verbatim, default-ON `x-api-key`, `encodeBody` messages override) (AC1, AC3, AC4).
- `packages/koel_langgraph/lib/src/langgraph_auth_interceptor.dart` — **NEW**: `LangGraphAuthInterceptor extends AuthInterceptor` (`x-api-key`, default-ON, blank → no-op) (AC2).
- `packages/koel_langgraph/lib/src/conversion/message_conversion.dart` — **NEW**: `langGraphMessageToWire` (canonical AG-UI; no options class) (AC3).
- `packages/koel_langgraph/test/langgraph_agent_test.dart` — **NEW**: endpoint-verbatim + fail-fast + canonical messages + `x-api-key` + inherited-parse round-trip + 401→RunErrorEvent (AC1–AC4).
- `packages/koel_langgraph/test/langgraph_auth_interceptor_test.dart` — **NEW**: `x-api-key` present/no-op, not-Bearer (AC2).
- `packages/koel_langgraph/test/message_conversion_test.dart` — **NEW**: normalization cases (AC3).
- `packages/koel_langgraph/test/_support.dart` — **NEW**: `fixturePayloads`/`sseBody` test helpers (AC4).
- `_bmad-output/implementation-artifacts/deferred-work.md` — **MODIFIED**: recorded the 5.4→5.6 sealer hand-offs + 5.5/5.6 siblings (Task 6).

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-06-03 | 0.1 | Story drafted — langgraph-group OPENER: `LangGraphAgent extends HttpAgent` (deploymentUrl verbatim, default-ON `x-api-key` auth), `LangGraphAuthInterceptor extends AuthInterceptor`, canonical-AG-UI `langGraphMessageToWire` (no options class), inherited-parse round-trip, pubspec/barrel/dartdoc wiring. Two source-verified reconciliations baked RESOLVED (native-AG-UI → no protocol-conversion layer; `x-api-key` not Bearer). Finalization (analysis_options/coverage gate/conformance lane/fixtures/README) + errorClassifier + `resume()` deferred to Stories 5.6/5.5. Status → ready-for-dev. | Bob (SM) |
| 2026-06-03 | 1.0 | Implemented 5.4 (all tasks green). `LangGraphAgent` + `LangGraphAuthInterceptor` + `langGraphMessageToWire` + barrel + pubspec; 26 tests, coverage 100/100, analyze 0 (11 pkgs), full `melos test` no-regression, format clean. Both reconciliations shipped as designed; conformance assertion done as a fixture round-trip (formal `ConformanceRunner` lane deferred to 5.6 per AC latitude). Sealer hand-offs recorded. **Status → review.** | Amelia (Dev) |
