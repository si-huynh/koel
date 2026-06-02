---
baseline_commit: 38deee65c2cbf61e4b965ae1d5ee78156723596d
---

# Story 5.1: `koel_agno` — `AgnoAgent` + message conversion

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter/Dart developer,
I want `AgnoAgent extends HttpAgent` targeting `POST baseURL/agno-chat` with agno's message-shape conversion,
so that connecting to an Agno backend is one constructor call per FR-C1.

## Acceptance Criteria

> AC1–AC3 are the epic's stated criteria. AC4 (extension surface) and AC5 (token no-op pin) are **Project-Lead-mandated additions** for this story — AC4 is the Epic-4-retro Discovery 1 first-task decision; AC5 closes the retro's recurring "dropped ctor param" trap (Action Item #2). Both are in 5.1's scope by decision, not invention.

**AC1 — `AgnoAgent` constructor + endpoint (FR-C1, Addendum A.3).**
**Given** `packages/koel_agno/lib/src/agno_agent.dart`,
**When** I inspect the constructor,
**Then** it matches Addendum A.3 exactly: `AgnoAgent({required Uri baseURL, String? token, http.Client? client, List<Interceptor>? interceptors, AgnoConversionOptions? conversion})`,
**And** a run POSTs to `baseURL/agno-chat` (the join is trailing-slash-safe — `http://host:8002` and `http://host:8002/` both resolve to `http://host:8002/agno-chat`).

**AC2 — message conversion (FR-C1).**
**Given** `packages/koel_agno/lib/src/conversion/message_conversion.dart`,
**When** I inspect it,
**Then** it converts koel's `Message` to agno's expected on-the-wire shape — **canonical AG-UI**: `{id, role, content}` plus `toolCallId`/`name` **only when non-null**, and koel's non-AG-UI `timestamp` field **excluded by default** (`AgnoConversionOptions.includeTimestamp == false`),
**And** the conversion is exercised by unit tests covering the full message lifecycle (user / assistant / system / tool roles; null vs. populated `toolCallId`/`name`; timestamp included vs. excluded).

**AC3 — end-to-end through inherited transport.**
**Given** a configured `AgnoAgent` running against a mock Agno endpoint (`MockClient` or a loopback `HttpServer`),
**When** I issue a `RunAgentInput`,
**Then** the request body's `messages` array matches the agno wire-format expectation (canonical AG-UI per AC2 — no `timestamp`, no explicit-null keys),
**And** the response AG-UI SSE stream parses correctly into typed `AgUiEvent`s via inherited `HttpAgent` behavior (no reshaping of the response — agno emits canonical AG-UI SSE).

**AC4 — `HttpAgent` body-encoding extension surface (Epic-4 retro Discovery 1).**
**Given** `packages/koel_http/lib/src/http_agent.dart`,
**When** I inspect `HttpAgent`,
**Then** the request-body construction is exposed as an overridable `@protected` seam (recommended: `@protected Map<String, dynamic> encodeBody(RunAgentInput input) => encodeRunAgentInput(input);`) that `_TransportTerminal` calls in place of the hardcoded `encodeRunAgentInput(wireInput)`,
**And** `AgnoAgent` overrides it to route `messages` through `message_conversion.dart` while delegating the other six body fields to `super.encodeBody(...)`,
**And** `koel_http`'s existing `test:coverage` gate (≥90% line + branch) stays green after the change.

**AC5 — `token` pinned no-op until Story 5.2.**
**Given** `AgnoAgent(baseURL: …, token: 'abc')` in this story (auth wiring belongs to Story 5.2),
**When** a run executes,
**Then** **no** `Authorization` header is emitted (the `token` param is accepted but not yet consumed),
**And** a test asserts this no-op explicitly, with a code comment pointing to Story 5.2 (`AgnoAuthInterceptor`) — so the accepted-but-dropped param cannot silently regress (Epic-4 retro Action Item #2).

## Tasks / Subtasks

- [x] **Task 1 — Validate + build the `HttpAgent` body-encoding seam (AC4). DO THIS FIRST.** (Epic-4 retro Discovery 1, Project-Lead decision: resolve in-story, before AgnoAgent logic.)
  - [x] Confirm the source reality: `_TransportTerminal.run` in [http_agent.dart:203](packages/koel_http/lib/src/http_agent.dart#L203) hardcodes `final body = utf8.encode(jsonEncode(encodeRunAgentInput(wireInput)));`. A cross-package subclass currently has **no** way to shape the wire body. (`_client`/`_interceptors` are *set* via the public super ctor — they do **not** need cracking open; the body encoding does. This is the precise, source-verified meaning of Discovery 1 for Story 5.1.)
  - [x] Add `@protected Map<String, dynamic> encodeBody(RunAgentInput input) => encodeRunAgentInput(input);` to `HttpAgent`, with a member-doc dartdoc (the package's `public_member_api_docs` gate applies). Change `_TransportTerminal.run` to call `jsonEncode(_agent.encodeBody(wireInput))`. Same-library access from `_TransportTerminal` is lint-clean for `@protected` (the restriction is cross-library); cross-package `AgnoAgent` overriding it is the intended use.
  - [x] Verify cross-package: a throwaway `class _Probe extends HttpAgent { @override Map<String,dynamic> encodeBody(i) => {...super.encodeBody(i), 'probe': true}; }` in a `koel_agno` test compiles and the override is honored on the wire. This is the adversarial proof the seam is reachable (Epic-4 retro A7 — "a seam designed for a future consumer must be reachable by that consumer"). Do not assume; demonstrate. → `_ProbeAgent` in `agno_agent_test.dart` asserts `body['probe'] == true` on the captured wire.
  - [x] Run `bash tool/coverage.sh packages/koel_http 90 90 with_chrome` — the seam's default path is already exercised by existing `http_agent_test.dart`; confirm the gate stays green. → **line=94.55% (434/459), branch=92.11% (175/190)**, exit 0.
- [x] **Task 2 — `AgnoConversionOptions` + `message_conversion.dart` (AC2).**
  - [x] Create `packages/koel_agno/lib/src/conversion/message_conversion.dart`.
  - [x] Define `class AgnoConversionOptions` (immutable, `const` ctor) with the **one** justified knob: `final bool includeTimestamp;` defaulting to `false`. Do **not** invent speculative options (CLAUDE.md: no "just-in-case" params) — agno is native AG-UI; the only real variance point is koel's non-normative `timestamp`. Dartdoc must state why the seam is deliberately small and cite the agno-is-native-AG-UI finding.
  - [x] Implement `Map<String, dynamic> agnoMessageToWire(Message m, AgnoConversionOptions options)` producing canonical AG-UI: `{'id', 'role', 'content'}`, add `'toolCallId'`/`'name'` **only when non-null**, add `'timestamp'` (ISO-8601) **only when `options.includeTimestamp`**. Role enum → string is already identity (`user`/`assistant`/`system`/`tool` — see [message.g.dart:27](packages/koel_core/lib/src/message/message.g.dart#L27)); reuse `MessageRole` names, do not hand-roll a parallel map. → used `message.role.name`.
  - [x] Unit-test the full lifecycle (AC2): each role; null vs. populated `toolCallId`/`name` (assert keys are **absent**, not null, when unset); `includeTimestamp` true/false. Assert the output never contains an explicit-`null` value. → 10 tests incl. a full cross-product null-sweep.
- [x] **Task 3 — `AgnoAgent extends HttpAgent` (AC1, AC3).**
  - [x] Create `packages/koel_agno/lib/src/agno_agent.dart`.
  - [x] Constructor exactly per Addendum A.3 (AC1). Forward `client` and `interceptors` straight to `super(...)`; compute the endpoint and pass `url: <baseURL/agno-chat>` to `super`. Store `conversion ?? const AgnoConversionOptions()`. → `client`/`interceptors` forwarded as `super.` formal parameters alongside the explicit `super(url: …)` (analyzer-clean; silences `use_super_parameters`).
  - [x] Trailing-slash-safe endpoint join (AC1) — do **not** use raw string concat or naive `Uri.resolve` (both mishandle a trailing slash or an empty base path). Recommended:
    ```dart
    Uri _agnoChatEndpoint(Uri baseURL) => baseURL.replace(
      pathSegments: [...baseURL.pathSegments.where((s) => s.isNotEmpty), 'agno-chat'],
    );
    ```
  - [x] Override the AC4 seam to route messages through conversion, patching only `messages`:
    ```dart
    @override
    Map<String, dynamic> encodeBody(RunAgentInput input) => {
      ...super.encodeBody(input),
      'messages': [for (final m in input.messages) agnoMessageToWire(m, _conversion)],
    };
    ```
    This composes correctly with the auth-key stripping: `_TransportTerminal` passes the already-stripped `wireInput` to `encodeBody` (the `AuthInterceptor.transportHeadersKey` is removed *before* the call — see [http_agent.dart:196-203](packages/koel_http/lib/src/http_agent.dart#L196-L203)).
  - [x] **Do not** override `run()` for conversion and **do not** add output/event conversion: agno emits canonical AG-UI SSE, so the inherited `HttpAgent` → `SseParser` path is correct and identity on the response (AC3). Adding an event-mapping hook would be vestigial. → response path verified by replaying `text_only_run`/`tool_call_basic` fixtures and asserting equality with `FixtureLoader.loadSynthesized`.
- [x] **Task 4 — `token` no-op pin (AC5).**
  - [x] Accept `token` in the ctor (AC1 surface) but **do not** wire any auth. Add a code comment on the field: `// Consumed in Story 5.2 (AgnoAuthInterceptor extends AuthInterceptor); pinned no-op here.`
  - [x] Test: `AgnoAgent(baseURL: …, token: 'secret')` issues a run via a request-capturing `MockClient`; assert the captured request has **no** `Authorization` header. (Closes Epic-4 retro Action Item #2 for this param.) → also asserts the token never leaks onto the wire body.
- [x] **Task 5 — package wiring + exports.**
  - [x] Add to `packages/koel_agno/pubspec.yaml` `dependencies:` — `koel_core:`, `koel_http:`, `http: ^1.6.0` (bare workspace keys mirror koel_http's style; see [koel_http/pubspec.yaml](packages/koel_http/pubspec.yaml)). `dev_dependencies:` already has `koel_lints:`; add `test:` and `koel_test:` for the harness/fixtures. `meta` is **not** needed in koel_agno (the `@protected` seam lives in koel_http, which already depends on `meta`).
  - [x] Export the public surface from `packages/koel_agno/lib/koel_agno.dart`: `AgnoAgent`, `AgnoConversionOptions`, and the conversion function if part of the public contract (keep it minimal — export only what a consumer needs). → exported `AgnoAgent` + `AgnoConversionOptions` (via `show`); `agnoMessageToWire` kept internal.
  - [x] Run `dart analyze` on `koel_agno` + `koel_http` → exit 0 (NFR-13). → "No issues found!".
- [ ] **Out of scope for 5.1 — record, do not implement:** `AgnoAuthInterceptor` + default-ON wiring + `AgnoErrorClassifier` (Story 5.2); captured fixtures + `ConformanceRunner` green + the `test:coverage` gate entry + package-finalization `analysis_options.yaml` (Story 5.3, the agno-group sealer — mirrors how koel_http deferred its finalization gates to the 4.10 sealer).

### Review Findings

Adversarial review (Blind Hunter + Edge Case Hunter + Acceptance Auditor), 2026-06-02. Acceptance Auditor verdict: **AC1–AC5 all PASS**, no scope creep, koel_http coverage gate independently re-verified green (94.55% line / 92.11% branch). 9 findings dismissed as noise (camelCase-`toolCallId`-is-correct since agno is native AG-UI; `content` is `required String` so the unconditional emit is safe; `role.name` identity-maps to AG-UI; `token` inertness is the intended AC5 no-op; the `@protected` cross-package seam is the mandated AC4 design proven by `_ProbeAgent`; double-`messages`-encode is the spec-sanctioned override pattern with negligible cost; three minor test-helper nits).

- [x] [Review][Decision→Patch] `_agnoChatEndpoint` now fails fast on a baseURL that cannot name an HTTP POST target — **APPLIED** (Project-Lead chose "design for what users can't misuse"). `_agnoChatEndpoint` throws `ArgumentError` at construction when `baseURL` is not `http(s)` or lacks an authority, instead of building a nonsense endpoint that fails opaquely at transport. Query/fragment kept as passthrough (fragment never transmitted; query may be legitimate) — documented in the dartdoc. Added a parameterised guard test (relative / `file:` / `ftp:` / authority-less `http:`); koel_agno coverage stayed 100%/100% (27/27 line, 11/11 branch). [packages/koel_agno/lib/src/agno_agent.dart:44-72]
- [x] [Review][Defer] `timestamp` emitted via `toIso8601String()` without `.toUtc()` — a local `DateTime` yields a zone-less ISO string (only when `includeTimestamp: true`, which defaults off). Mirrors koel_core's canonical `message.g.dart:22` exactly, so it is **not introduced by this change**, and normalizing only the agno converter would diverge from the canonical codec. Any UTC-normalization decision belongs to koel_core's message codec, not this story. [packages/koel_agno/lib/src/conversion/message_conversion.dart:198-199] — deferred, pre-existing (systemic, koel_core)

## Dev Notes

### The single most important finding: agno is **native AG-UI** — conversion is normalization, not reshaping

The epic AC2 and PRD F-C1 say message conversion translates "agno's chat message shape" (written speculatively, "per agno backend docs"). **The resolved spike refutes the premise of a reshape.** Per [`../koel_backend/backends/agno/CONTRACT.md`](../koel_backend/backends/agno/CONTRACT.md) (SPIKE-AGNO, 2026-06-02, `agno==2.6.10`, source-verified + docker-probed):

- agno's AG-UI route handler receives `ag_ui.core.types.RunAgentInput` and **parses koel's camelCase JSON directly — no reshape**.
- The response is **canonical AG-UI SSE** via `ag_ui.encoder.EventEncoder` (`RUN_STARTED → TEXT_MESSAGE_* → RUN_FINISHED`).

So for the agno reference backend, the response path is **identity** (don't write event conversion). The request path needs exactly **one** real reconciliation: koel's `Message` is a *superset* of the AG-UI message. [`message.g.dart`](packages/koel_core/lib/src/message/message.g.dart) emits `{id, role, content, timestamp, toolCallId, name}` — and `timestamp` is **koel-only, not AG-UI-normative** (the AG-UI `Message` is `{id, role, content?, name?}` + `toolCalls`/`toolCallId`; it has no `timestamp` — koel added it for `ChatState.messages` per [message.dart:22](packages/koel_core/lib/src/message/message.dart#L22)). The probe's request body used `{"id","role","content"}` only — koel's `timestamp` + explicit-null `toolCallId`/`name` were **never tested against agno's parser**. "Infra deep, business out" (CLAUDE.md): do not leak koel-internal fields onto a foreign wire. `message_conversion.dart` normalizes koel's `Message` down to canonical AG-UI. That is genuine, verifiable work — not a vague reshape.

> ⚠️ **Verify, don't assume** (memory: *"Confirmed" needs adversarial evidence*). We do **not** know whether agno's pydantic parser tolerates the extra `timestamp`/null fields (pydantic *usually* ignores extras, but the CONTRACT evidence never sent them). Designing conversion to emit canonical AG-UI is correct **regardless** of agno's tolerance, so the seam is the right call either way. Story 5.3's live capture against `make up-agno` is the empirical confirmation; do not block 5.1 on it.

### Discovery 1, precisely: the transport seam is the **body encoding**, not `_client`/`_interceptors`

Epic-4 retro Discovery 1 + Action Item A7 flagged that Story 4.2 closed `_client`/`_interceptors` behind `_`-privacy, so Epic-5 subclasses "cannot reach the transport seam." Reading the source ([http_agent.dart](packages/koel_http/lib/src/http_agent.dart)) sharpens this for Story 5.1:

- `AgnoAgent` **sets** `client` and `interceptors` through the **public** `HttpAgent(...)` ctor params ([http_agent.dart:87-105](packages/koel_http/lib/src/http_agent.dart#L87-L105)) — it never needs to *read* the private fields. So those are **not** 5.1's blocker.
- The genuine blocker is `_TransportTerminal.run`'s hardcoded `encodeRunAgentInput(wireInput)` ([http_agent.dart:203](packages/koel_http/lib/src/http_agent.dart#L203)) — there is no override point for the wire body. **That** is the seam AC4 opens.

Recommended seam: a `@protected Map<String,dynamic> encodeBody(RunAgentInput)` on `HttpAgent` (default delegates to `encodeRunAgentInput`), called by the same-library `_TransportTerminal`. `@protected`'s cross-library restriction does not apply to same-library callers, and overriding from the cross-package `AgnoAgent` subclass is exactly its intent. This is a minimal, additive, non-breaking change to a sealed ≥90%-covered package — keep `koel_http`'s coverage gate green (the default path is already covered; the override is covered by koel_agno's tests).

> The error-classifier seam is a **separate, later** gap. `HttpAgent.run` hardcodes `errorClassifier: transportErrorClassifier()` ([http_agent.dart:156](packages/koel_http/lib/src/http_agent.dart#L156)); `AgnoErrorClassifier` (Story 5.2) will need a seam there. **Do not build it in 5.1** (no consumer yet — CLAUDE.md "no just-in-case"). Record it here so 5.2 isn't surprised: 5.2 will add an overridable error-classifier hook alongside `AgnoErrorClassifier` + the deferred `401 → businessAuth` (Story 4.5 deferral) + the `DefaultErrorClassifier` subclass-name-asymmetry fix (Story 2.3 deferral).

### `token` is the recurring "dropped ctor param" trap (Action Item #2)

The Addendum A.3 ctor includes `token`, but the consuming `AgnoAuthInterceptor` is **Story 5.2**. This is the exact shape of the bug class that hit Epic 4 three times (4.2→4.8→4.9: ctor accepts a param a later story wires, initializer never stores/uses it). The retro's Action Item #2 mandates: a forward-looking param is either stored-and-used now **or** explicitly test-pinned as a documented no-op. 5.1 takes the **no-op-test** path (AC5) — it keeps the clean 5.1/5.2 boundary the epic drew (auth wiring is 5.2's deliverable) while making the gap impossible to miss. `AuthInterceptor` is already subclass-ready for 5.2 — `class AuthInterceptor` (not `final`), and `AuthInterceptor.transportHeadersKey` is the public header seam ([auth_interceptor.dart:48-69](packages/koel_http/lib/src/interceptors/auth_interceptor.dart#L48-L69)).

### Source tree (what to touch)

```
packages/koel_agno/
├── pubspec.yaml                         # UPDATE: add koel_core, koel_http, http deps + test/koel_test dev-deps
├── lib/
│   ├── koel_agno.dart                   # UPDATE: export AgnoAgent + AgnoConversionOptions
│   └── src/
│       ├── agno_agent.dart              # NEW: AgnoAgent extends HttpAgent (Task 3)
│       └── conversion/
│           └── message_conversion.dart  # NEW: AgnoConversionOptions + agnoMessageToWire (Task 2)
└── test/
    ├── message_conversion_test.dart     # NEW: full message lifecycle (AC2)
    └── agno_agent_test.dart             # NEW: endpoint + body shape + SSE parse + token no-op (AC1/3/5)

packages/koel_http/
└── lib/src/http_agent.dart              # UPDATE: add @protected encodeBody seam; route _TransportTerminal through it (AC4)
```
Adapter-package layout per [architecture.md §ARCH-871](_bmad-output/planning-artifacts/architecture.md) (`<name>_agent.dart` + `conversion/message_conversion.dart`). Adapter agents end in `Agent`.

### Existing-code contracts that must not break (read before editing `http_agent.dart`)

- `_TransportTerminal.run` is a tightly-reasoned lazy pipeline: auth-key strip → `encodeBody` → `Transport().connect` → `onConnect` → non-2xx throw (with socket drain + `onDisconnect`) → `SseParser` → optional `chunksStage` → `abortOnCancel(connection.track(...))`. The AC4 change is **one line** (swap `encodeRunAgentInput(wireInput)` → `_agent.encodeBody(wireInput)`); touch nothing else. The lifecycle-hook one-to-one pairing and the cancel/abort budget depend on the band staying throw-free and lazy — `encodeBody` runs synchronously *before* `connect()`, same as today, so a conversion throw surfaces identically (classified to a terminal `RunErrorEvent`). Keep `encodeBody` cheap and synchronous.
- **Adapters never throw `KoelError`** ([architecture.md ARCH-597](_bmad-output/planning-artifacts/architecture.md)): every failure reaches the consumer as a terminal `RunErrorEvent`. `AgnoAgent` inherits this for free by extending `HttpAgent` — do not add try/catch in `AgnoAgent`.

### Testing standards

- **Harness pattern** (mirror [http_agent_test.dart](packages/koel_http/test/http_agent_test.dart)): unit tests for pure conversion; for the agent, use `MockClient` (`package:http/testing.dart`) to **capture the outgoing request** (assert URL = `…/agno-chat`, `messages` shape, absent `Authorization`) and to **replay** an SSE body to confirm the inherited parse path. Reuse `koel_test` synthesized fixtures (e.g. `text_only_run`, `tool_call_basic`) for the SSE replay rather than hand-rolling event JSON.
- `@TestOn('vm')` is fine — koel_agno is offline/VM (no web transport, no Chrome pass needed; the `with_chrome` arg is koel_http-specific).
- Coverage: `koel_agno` target is **≥80%** line+branch (adapter tier, SC-2/NFR-12) — but the **gate enforcement + `tool/coverage.sh packages/koel_agno 80 80` entry in the root `test:coverage` script land in Story 5.3** (the sealer). Write thoroughly-covered code now; don't add the gate wiring in 5.1.
- Do not add `analysis_options.yaml` to koel_agno yet (finalization gate → 5.3). But `koel_http`'s existing member-doc gate **does** apply to the new `encodeBody` — give it a proper dartdoc.

### References

- [Source: _bmad-output/planning-artifacts/epics/epic-5-backend-bridges-koelagno-koellanggraph-koelruntime.md#Story-5.1] — story ACs, group ordering (5.1→5.2→5.3 within agno).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#A.3] — exact `AgnoAgent`/`AgnoAuthInterceptor` constructor signatures.
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md#F-C1] — `koel_agno` scope; OQ-Agno-Auth RESOLVED (default-ON `AgnoAuthInterceptor`, §6.1).
- [Source: ../koel_backend/backends/agno/CONTRACT.md] — **authoritative** agno wire contract: `POST /agno-chat`, camelCase `RunAgentInput` parsed natively, canonical AG-UI SSE response, no built-in auth, `agno==2.6.10`.
- [Source: _bmad-output/implementation-artifacts/epic-4-retro-2026-06-01.md#Significant-Discovery] — Discovery 1 (extension surface, resolve as 5.1 first task), A7 (seam reachability), Action Item #2 (dropped ctor param).
- [Source: _bmad-output/implementation-artifacts/epic-5-prep-plan.md] — koel-side build sequence; findings Q1 (auth) / Q2 (`/agno-chat` contract) / Q3 (error envelope, → 5.2).
- [Source: packages/koel_http/lib/src/http_agent.dart] — `HttpAgent`/`_TransportTerminal`; the `encodeRunAgentInput` line AC4 opens.
- [Source: packages/koel_http/lib/src/interceptors/auth_interceptor.dart] — subclass-ready `AuthInterceptor` + `transportHeadersKey` (for 5.2 context).
- [Source: packages/koel_core/lib/src/message/message.dart + message.g.dart] — `Message` shape; koel-only `timestamp`; role enum strings.

### Project Structure Notes

- `koel_agno` already scaffolded (Story 1.2) with bare barrel + empty `test/`; this story fills it. No new package creation.
- Modifying `koel_http` (a `done`, sealed, ≥90%-covered package) is **expected and sanctioned** here — AC4 is the Project-Lead in-story resolution of Discovery 1. Keep the change additive (`@protected encodeBody`) and re-run koel_http's coverage gate.
- Hybrid versioning (PRD R-3 / F-H2): `koel_agno` declares `^X.Y.0` ranged deps on foundations and versions independently — but all packages are pre-1.0 `version: 0.0.1, publish_to: none` today; bare workspace dep keys are correct for now (mirror koel_http). Lock-step publish is Epic 9.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8, 1M context) — via `/bmad-dev-story`, `/agent-flutter-engineer` specialist loaded for all Dart work.

### Debug Log References

- `dart analyze packages/koel_agno packages/koel_http` → **No issues found!** (NFR-13).
- `bash tool/coverage.sh packages/koel_http 90 90 with_chrome` → line=94.55% (434/459), branch=92.11% (175/190), exit 0 — AC4 gate stays green after the `encodeBody` seam.
- `bash tool/coverage.sh packages/koel_agno 80 80` → line=100.00% (22/22), branch=100.00% (9/9) — well above the ≥80% adapter target (gate *wiring* deferred to 5.3 per Dev Notes).
- `dart run melos test` (full workspace) → SUCCESS: koel_core 575, koel_http 97, koel_lints 5, koel_agno 18 — no regression.
- `bash tool/format.sh check` → 0 changed.

### Completion Notes List

- **Implementation Plan (red→green→refactor).** Built the AC4 seam first (Task 1, per Project-Lead first-task decision), proved it reachable cross-package with `_ProbeAgent` *before* writing `AgnoAgent`, then layered conversion (Task 2) → agent (Task 3) → token pin (Task 4) → wiring (Task 5).
- **AC4 seam is one additive method + one-line swap.** `HttpAgent.encodeBody` (`@protected`, dartdoc'd for the `public_member_api_docs` gate) defaults to `encodeRunAgentInput`; `_TransportTerminal.run` now calls `_agent.encodeBody(wireInput)`. Touched nothing else in the tightly-reasoned transport band — `encodeBody` runs synchronously before `connect()`, identical to the old hardcoded call, so the lifecycle/cancel guarantees are preserved.
- **agno is native AG-UI → request normalization only, response identity.** `agnoMessageToWire` normalizes koel's `Message` *superset* down to canonical AG-UI (`{id, role, content}` + `toolCallId`/`name` only-when-non-null; koel-only `timestamp` excluded by default). No event/`run()` override — the inherited `SseParser` path is identity on the response (verified by fixture replay).
- **Role string via `MessageRole.name`** — identity with AG-UI's vocabulary (`user`/`assistant`/`system`/`tool`, confirmed against `message.g.dart`'s enum map); no hand-rolled parallel map.
- **Trailing-slash-safe join** via `Uri.replace(pathSegments: …)` filtering empties — covers `http://h:8002`, `http://h:8002/`, and `http://h:8002/api/` (asserted).
- **`token` pinned no-op (AC5).** Accepted + stored as a public `final String? token` (a stored public field avoids an `unused_field`/dropped-param regression), never consumed; a test asserts no `Authorization` header *and* no token in the body, with a code comment pointing to Story 5.2. Closes Epic-4 retro Action Item #2 for this param.
- **Super-parameters used for `client`/`interceptors`** alongside the explicit `super(url: _agnoChatEndpoint(...))` — legal and silences `use_super_parameters` without dropping the computed `url`.
- **Out of scope (recorded, not built):** `AgnoAuthInterceptor` + default-ON wiring + the error-classifier seam + `AgnoErrorClassifier` (Story 5.2); captured fixtures + `ConformanceRunner` green + the `test:coverage` gate entry for koel_agno + package-finalization `analysis_options.yaml` (Story 5.3).

### File List

- `packages/koel_http/lib/src/http_agent.dart` — **MODIFIED**: added `import 'package:meta/meta.dart'`; added `@protected encodeBody(RunAgentInput)` seam (default delegates to `encodeRunAgentInput`); routed `_TransportTerminal.run`'s body encode through `_agent.encodeBody(wireInput)` (AC4).
- `packages/koel_agno/lib/src/conversion/message_conversion.dart` — **NEW**: `AgnoConversionOptions` + `agnoMessageToWire` (AC2).
- `packages/koel_agno/lib/src/agno_agent.dart` — **NEW**: `AgnoAgent extends HttpAgent` — trailing-slash-safe `/agno-chat` join, `encodeBody` messages override, `token` no-op pin (AC1, AC3, AC5).
- `packages/koel_agno/lib/koel_agno.dart` — **MODIFIED**: export `AgnoAgent` + `AgnoConversionOptions` (`show`).
- `packages/koel_agno/pubspec.yaml` — **MODIFIED**: added `koel_core`/`koel_http`/`http` runtime deps + `test`/`koel_test` dev-deps.
- `packages/koel_agno/test/message_conversion_test.dart` — **NEW**: full message-lifecycle conversion tests (AC2).
- `packages/koel_agno/test/agno_agent_test.dart` — **NEW**: endpoint join, body shape, SSE-parse fixture replay, token no-op, cross-package seam probe (AC1/AC3/AC4/AC5).

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-06-02 | 0.1 | Implemented Story 5.1: `AgnoAgent` + message conversion; opened `HttpAgent.encodeBody` body-encoding seam (AC4). All ACs satisfied; koel_http coverage gate green (94.55%/92.11%); koel_agno 100%/100%; full workspace regression green. Status → review. | Amelia (Dev) |
