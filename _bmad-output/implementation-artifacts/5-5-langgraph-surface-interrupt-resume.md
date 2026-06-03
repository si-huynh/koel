---
baseline_commit: 099c2f5
---

# Story 5.5: `koel_langgraph` — Surface-level interrupt-resume

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter/Dart developer,
I want `LangGraphAgent.resume(threadId, resumeValue)` to POST the resume value (at `forwardedProps.command.resume`) to the **same** deployment route and reopen the AG-UI SSE stream against the **same threadId**,
so that LangGraph's interrupt→resume flow works at the **surface level** per FR-C2 + PRD §6.1 deferral — deep (stateful sub-tree) interrupt-resume defers to v2 per OQ-LangGraph-Graduation.

## Acceptance Criteria

> **This is the second langgraph-group story** (5.4 = opener, **5.5 = resume**, 5.6 = sealer). It is a **single-method addition** to the `LangGraphAgent` 5.4 shipped — no new files in `lib/src/` beyond editing `langgraph_agent.dart`, plus a README note and tests. It defers to the **5.6 sealer** (exactly as 5.4 did): the real captured **interrupt fixture**, the `ConformanceRunner` lane, the coverage gate, `analysis_options.yaml`/`coverage_options.yaml`, and `LangGraphErrorClassifier`. It does **not** attempt deep/stateful resume (Out-of-scope; v2).
>
> **Two source-verified reconciliations are baked RESOLVED here** (not invented — each cites the live-probed contract `../koel_backend/backends/langgraph/CONTRACT.md`, SPIKE-LG-RESUME, closed 2026-06-02; and `ag_ui_langgraph==0.0.37` source). They mirror how 5.4 baked its native-AG-UI / `x-api-key` reconciliations:
> 1. **`resume(...)` returns `Stream<AgUiEvent>`, not Addendum A.4's `Future<void>`.** Epic AC2 (line 116–117) requires "the **new event stream** emits subsequent events with the resumed state" — a `Future<void>` cannot surface a stream. The A.4 sketch's parenthetical "(echoes MetaEvent back)" is illustrative shorthand, **not** a literal contract: there is **no `MetaEvent` type anywhere in koel_core** (grep is empty). The frozen intent is "surface the resumed run back"; the idiomatic koel surface for that is the same `Stream<AgUiEvent>` shape as `AbstractAgent.run`. See Dev Notes "Why `resume` returns a Stream". **⚠️ This is the one decision flagged for Si at review** (A.4-signature divergence — a one-way-door API call; the alternative is recorded below).
> 2. **The resume value rides at `forwardedProps.command.resume` (camelCase) and `runId` is minted, not the consumer's.** SPIKE-LG-RESUME proved the wire shape exactly (`agent.py` L167-178/L471-477/L554-574): same route, same `threadId`, `forwardedProps:{command:{resume:<value>}}`; `runId` is per-request (a fresh id), the **thread** is the checkpoint key — so the epic AC1 phrase "same threadId/**runId**" is superseded by the source-verified contract (A.4's `resume` takes **no** `runId` param anyway). See Dev Notes "The resume wire shape".

**AC1 — `resume()` surface + wire shape (epic AC1; Addendum A.4 reconciled; SPIKE-LG-RESUME, FR-C2).**
**Given** `packages/koel_langgraph/lib/src/langgraph_agent.dart`,
**When** I inspect the surface,
**Then** `Stream<AgUiEvent> resume(String threadId, Map<String, dynamic> resumeValue)` exists on `LangGraphAgent`,
**And** it builds a `RunAgentInput(threadId: threadId, runId: 'resume-$threadId', forwardedProps: {'command': {'resume': resumeValue}})` and returns `run(thatInput)` — i.e. it **delegates to the inherited `HttpAgent.run`**, so the resume POST goes to **`deploymentUrl` verbatim** (the same route as a normal run — there is no separate resume endpoint per the CONTRACT), carries the default-ON **`x-api-key`** header, runs `encodeBody`'s canonical-AG-UI `messages` normalization, and parses the reopened SSE through the inherited transport,
**And** `resume` adds **no** new transport/interceptor/parse code and holds **no** new agent state (it is one `run(...)` call with a resume-shaped input; see Dev Notes "Why `resume` returns a Stream").

**AC2 — request body is exactly the resume envelope (epic AC1; SPIKE-LG-RESUME).**
**Given** a `LangGraphAgent(deploymentUrl: …, client: capturingMockClient)`,
**When** the consumer calls `agent.resume('t-int-1', {'approved': true}).toList()`,
**Then** the captured outgoing request is `POST <deploymentUrl>` (verbatim, same route as `run`) with `Content-Type: application/json` + `Accept: text/event-stream`,
**And** the JSON body is a canonical camelCase `RunAgentInput` whose `threadId == 't-int-1'`, `runId == 'resume-t-int-1'`, and `forwardedProps == {'command': {'resume': {'approved': true}}}` — the resume value nested **exactly** under `forwardedProps.command.resume`, **not** a top-level field and **not** a serialized `Command` envelope,
**And** when `apiKey` is set, the request carries `x-api-key: <apiKey>` (inherited from the default-ON interceptor — resume is not exempt from auth).

**AC3 — synthesized interrupt→resume round-trip; no client-side state reconstruction (epic AC2; PRD §6.1).**
**Given** a synthesized interrupt scenario replayed by a `MockClient`: the **paused run** stream ends with a `CUSTOM` event `{name: 'on_interrupt', value: …}` (surfaced verbatim through the inherited `run()` parse — koel does **not** special-case it), and the **resumed** stream replays `RUN_STARTED → … → TEXT_MESSAGE_* ("Resumed with value: …") → … → RUN_FINISHED`,
**When** the consumer observes the `on_interrupt` `CustomEvent` on the `run()` stream and then calls `resume(threadId, resumeValue)`,
**Then** the `resume(...)` stream emits the resumed run's typed `AgUiEvent`s in wire order (the `RUN_STARTED…RUN_FINISHED` resumed sequence),
**And** `LangGraphAgent` performs **no** client-side state reconstruction or event-merging — LangGraph rebuilds state **server-side** from its checkpoint (PRD §6.1); koel only reopens the stream and passes events through.

**AC4 — README surface-level disclaimer (epic AC3; OQ-LangGraph-Graduation).**
**Given** `packages/koel_langgraph/README.md`,
**When** I inspect package docs after this story,
**Then** the README carries a focused **Interrupt-resume** note stating "v1 ships **surface-level** interrupt-resume; **deep** interrupt-resume defers to v2" with a link to the **OQ-LangGraph-Graduation** tracking item (PRD §15 OQ registry),
**And** this is the **only** README change in 5.5 — the broader README finalization (the `x-api-key` convention note, the `deploymentUrl`-verbatim note, package overview polish) **remains the 5.6 sealer's** deferred item (do not pre-empt it).

**AC5 — gates green for what exists now (epic-stated NFR-13; coverage gate deferred to 5.6).**
**Given** all of the above,
**When** I run the workspace gates,
**Then** `dart analyze packages/koel_langgraph` exits **0** (NFR-13) under the inherited **root** `analysis_options.yaml` (5.5 adds **no** package-level `analysis_options.yaml` — still the 5.6 sealer's job; write the `resume` dartdoc now so 5.6's `public_member_api_docs` gate lands clean with no backfill),
**And** `dart test packages/koel_langgraph` is green (the existing 26 tests **plus** the new resume tests),
**And** `dart run melos test` (full workspace) shows **no regression** in any other package (5.5 edits only `koel_langgraph`),
**And** `bash tool/format.sh check` is clean,
**And** coverage for koel_langgraph is **not yet gated** here (the `test:coverage` entry + `coverage_options.yaml` are the 5.6 sealer's wiring); nonetheless the new tests exercise the full `resume` path so 5.6's ≥80% gate stays green.

## Tasks / Subtasks

- [x] **Task 1 — add `resume()` to `LangGraphAgent` (AC1, AC2).**
  - [x] In `packages/koel_langgraph/lib/src/langgraph_agent.dart`, add:
    ```dart
    Stream<AgUiEvent> resume(String threadId, Map<String, dynamic> resumeValue) =>
        run(RunAgentInput(
          threadId: threadId,
          runId: 'resume-$threadId',
          forwardedProps: {'command': {'resume': resumeValue}},
        ));
    ```
    Added the `ArgumentError` fail-fast guard on a blank `threadId` (`threadId.trim().isEmpty`) — the only throw; `resumeValue` is not validated.
  - [x] **Did not** add transport/parse/interceptor code, did not override the response path, did not hold any controller/sink — `resume` is one inherited `run(...)` call. The default-ON `x-api-key`, `encodeBody` `messages` normalization, SSE parse, and `DefaultErrorClassifier` are all inherited unchanged. `LangGraphAgent` stays stateless.
  - [x] **Dartdoc** `resume`: the `forwardedProps.command.resume` wire shape (SPIKE-LG-RESUME), same-route/same-thread/minted-runId rationale, consumer detects `on_interrupt` itself (plain `CustomEvent` on the `run()` stream), surface-level (no client-side reconstruction; server-side rebuild), error contract (failed resume → terminal `RunErrorEvent`), deep resume deferred to v2 (OQ-LangGraph-Graduation).
  - [x] Flipped the **class** dartdoc: the "resume … not part of this agent yet — arrives in Story 5.5" sentence now describes the present surface-level resume; the langgraph error classifier still noted as Story 5.6.

- [x] **Task 2 — README interrupt-resume disclaimer (AC4).**
  - [x] Added an **Interrupt-resume** section to `packages/koel_langgraph/README.md`: surface-level v1 (`resume` reopens on the same thread; LangGraph rebuilds state server-side, no client-side reconstruction) with a `dart` usage snippet; deep interrupt-resume deferred to v2.
  - [x] Referenced `OQ-LangGraph-Graduation` as a **bare token** (not a hyperlink) — mirroring the same README's existing `OQ-Docs-Framework` convention, because a published-README link into internal `_bmad-output/` planning docs would be broken on pub.dev and no public docs site exists yet. Recorded as a docs-site follow-up in `deferred-work.md`.
  - [x] Left the rest of the README untouched — the `x-api-key`/`deploymentUrl` convention notes + overview polish stay deferred to **5.6**.

- [x] **Task 3 — tests (AC2, AC3).**
  - [x] Extended `test/langgraph_agent_test.dart` with `group('surface-level interrupt-resume (Story 5.5)', …)` — chose cohesion with the existing agent test (4 tests, file stays readable).
  - [x] **Request-shape test (AC2):** `resume('t-int-1', {'approved': true})` through `_capturingClient`; asserts URL == `http://host:8003/agent` verbatim, POST, `body['threadId']=='t-int-1'`, `body['runId']=='resume-t-int-1'`, `body['forwardedProps']=={'command':{'resume':{'approved':true}}}`. Plus a variant asserting `x-api-key` rides the resume request when `apiKey` is set, and a fail-fast test asserting a blank `threadId` throws `ArgumentError`.
  - [x] **Interrupt→resume round-trip (AC3):** built both SSE streams **inline** via `sseBody(...)` — no bundled fixture. One `MockClient` routes by whether the body carries `forwardedProps.command` (mirroring the single-route backend): returns the paused stream (`RUN_STARTED → CUSTOM on_interrupt → RUN_FINISHED`) for `run()`, the resumed stream (`RUN_STARTED → TEXT_MESSAGE_* "Resumed with value: approved-by-human" → RUN_FINISHED`) for `resume()`. Asserts `run()` surfaces the interrupt as a `CustomEvent` (name + value), and `resume(...).toList()` equals the exact typed resumed-event sequence.
  - [x] `@TestOn('vm')` kept; no `@Tags(['conformance'])` lane (5.6 sealer).

- [x] **Task 4 — gates + close-out (AC5).**
  - [x] `dart analyze packages/koel_langgraph` → **0**; `dart run melos analyze` → SUCCESS (all pkgs). `dart test packages/koel_langgraph` → **+32** (26 prior + 6 — 4 new resume tests in a group + the 2 parametrized fixture-replays already counted). `dart run melos test` → SUCCESS, **no regression** (koel_core +576, koel_http +97, koel_lints +5, koel_langgraph +32). `bash tool/format.sh check` → clean (ran `dart format packages/koel_langgraph` once, re-checked 0 changed). Informational coverage (gate is 5.6): **line 35/35 (100%)**, `langgraph_agent.dart` 24/24.
  - [x] Recorded the 5.5→5.6 / 5.5→v2 hand-offs in `deferred-work.md` (real captured interrupt fixture + ConformanceRunner interrupt lane + coverage gate + analysis_options + README finalization → 5.6; deep stateful resume + typed interrupt model → v2; README OQ hyperlink → docs-site follow-up).

- [ ] **Out of scope for 5.5 — record, do not implement:**
  - **Deep / stateful interrupt-resume** (sub-tree resumption, client-side state merge/reconstruction) → **v2** per OQ-LangGraph-Graduation + Addendum "Future-4" (line 672). 5.5 is surface-level only: reopen the stream, pass events through, no state logic.
  - **Real captured langgraph interrupt fixture** (`tool/capture_fixtures.dart --backend=langgraph` interrupt scenario, operator `make up-langgraph`) + **`ConformanceRunner` interrupt assertion** + **`conformance.yml` langgraph lane** + **coverage gate** + **`analysis_options.yaml`/`coverage_options.yaml`** + **the broader README finalization** → **Story 5.6** (langgraph-group sealer).
  - **`LangGraphErrorClassifier` + `errorClassifier()` override** → **Story 5.6**. 5.5 leaves `LangGraphAgent` on the inherited `DefaultErrorClassifier`; a resume that 401s surfaces as a terminal `RunErrorEvent` via the inherited classifier (the langgraph-specific 401→`businessAuth` mapping is 5.6).
  - **Parsing/typing the `on_interrupt` payload into a koel domain type** — surface-level v1 leaves it as a raw `CustomEvent` the consumer inspects. A typed interrupt model (if ever wanted) is a v2 concern, not 5.5.

### Review Findings (code review 2026-06-03) — all resolved, gates re-green (+34 tests)

**Deciding principle (Si, at review): parity with the canonical AG-UI standard, not preference.** Both flagged decisions were resolved by source-verified evidence rather than a judgement call.

- [x] [Review][Decision→RESOLVED] **`resumeValue` retyped `Map<String, dynamic>` → `Object?`** — four sources converge on parity: (1) the wire builds `Command(resume=<any JSON>)`; (2) **the live SPIKE-LG-RESUME itself resumed with a bare string `"approved-by-human"`** — the `Map` signature could not reproduce the proven contract; (3) AG-UI standard `resume = any`; (4) the internal twin `CustomEvent.value` (the inbound half of the same interrupt cycle) is already `Object?` ("accepts any JSON value"). Typing the outbound resume as `Map` while the inbound is `Object?` was an unjustified asymmetry. This **supersedes epic AC1/AC2's literal `Map<String, dynamic>`** (a source-verified reconciliation, same move 5.4/5.5 used for the native-AG-UI / `x-api-key` / wire-shape reconciliations). Fixed + parity test added (resume with a bare String). [`langgraph_agent.dart:118`] (blind)
- [x] [Review][Decision→CONFIRMED] **`Stream<AgUiEvent>` return type stands** — parity: the AG-UI protocol has no separate resume primitive (run and resume share `POST /agent`), so resume *is* another run and its surface is `run`'s `Stream<AgUiEvent>`. A.4's `Future<void>`/`MetaEvent` was a koel-only sketch (no `MetaEvent` type exists). Confirmed at review. (auditor)
- [x] [Review][Patch] Blank-check now **trims-and-uses** `threadId` — a padded id resolves to the same checkpoint instead of riding verbatim into `threadId`/`runId` and missing it [`langgraph_agent.dart:118`] (blind)
- [x] [Review][Patch] dartdoc "a **fresh** … id is minted" → "a **deterministic** `resume-<threadId>` id is minted; the server keys resumption on threadId, not runId" [`langgraph_agent.dart`] (blind+edge)
- [x] [Review][Patch] Removed the machine-local path `../koel_backend/backends/langgraph/CONTRACT.md` from the public dartdoc — now bare `SPIKE-LG-RESUME` (the class-doc pre-existing reference at line 12 is baseline, out of this story's scope) [`langgraph_agent.dart:99`] (blind)
- [x] [Review][Patch] AC3 round-trip test filters by `name == 'on_interrupt'` instead of `.single` — no longer assumes the interrupt is the only CUSTOM event a run carries [`langgraph_agent_test.dart`] (blind)
- [x] [Review][Patch] Added a resume-specific failed-resume → terminal `RunErrorEvent` test (the dartdoc's error contract, now directly asserted for resume) [`langgraph_agent_test.dart`] (blind)

**Dismissed as noise/refuted (5):** sync-throw on encode (Edge refuted — `jsonEncode` runs inside `_TransportTerminal`'s `async*` → terminal `RunErrorEvent`, never escapes); missing `resumeValue` JSON-validation (same path; aligns with ARCH "adapters never throw `KoelError`"); no extra-`forwardedProps` seam (adding it would violate CLAUDE.md "no just-in-case parameters"); runId-collision *functional* impact (intentional/deterministic, backend strips runId — only the doc wording was inaccurate, fixed above); AC4 link-vs-bare-token (documented + docs-site follow-up already in `deferred-work.md`).

## Dev Notes

### Why `resume` returns a `Stream<AgUiEvent>` (the AC1 decision, baked RESOLVED — flagged for Si at review)

Addendum A.4 sketches `Future<void> resume(String threadId, Map<String, dynamic> resumeValue)` with the parenthetical "`// Surface-level interrupt resume (echoes MetaEvent back).`". Two facts make the literal `Future<void>` the wrong surface, and the resolution is the same "decide-and-bake-with-evidence" move 5.4 used for its native-AG-UI and `x-api-key` reconciliations:

1. **The epic AC requires a stream.** Story 5.5 AC2 (epic line 116–117): "the **new event stream** emits subsequent events with the resumed state." A `Future<void>` cannot deliver a stream of events to the consumer. To honor it with `Future<void>` you would have to bolt an out-of-band channel onto the agent (a held `StreamController`, a broadcast `events` getter, or a retained downstream sink) — hidden agent state and a second delivery path, strictly more surface for strictly less clarity (violates CLAUDE.md "every line earns its place", "pure functions > hidden state", "explicit lifecycle > magic").
2. **"MetaEvent" does not exist.** A repo-wide grep for `MetaEvent` in `koel_core` returns nothing. The A.4 parenthetical is illustrative shorthand for "surface the resumed run back", not a literal frozen contract — exactly the kind of sketch detail 5.4 treated as reconcilable against the live contract.

`AbstractAgent`'s sole method is `Stream<AgUiEvent> run(RunAgentInput)`. A resume **is** another run on the same thread carrying a resume command — so returning `Stream<AgUiEvent>` makes `resume` a one-liner that delegates to the inherited `run`, reusing the **entire** transport/interceptor(`x-api-key`)/`encodeBody`/SSE-parse/classifier path with **zero** new state and **zero** new files. The consumer flow reads naturally:

```dart
final live = agent.run(input);                 // ends with CUSTOM on_interrupt, then RUN_FINISHED
// ... consumer sees the on_interrupt CustomEvent, gathers the human's resumeValue ...
final resumed = agent.resume(threadId, {'approved': true});  // a fresh AG-UI stream
```

**⚠️ Flag for Si (one-way-door API call).** This diverges from the **frozen** Addendum A.4 return type — bigger than 5.4's choices (which matched A.4's ctor exactly). It is baked as the evidence-backed default per the project's "decide and bake, no CYA open questions" norm, but the return type of a public method is a one-way door. **The faithful-to-A.4 alternative**, if Si prefers it: keep `Future<void> resume(...)` and surface the resumed events via a separate broadcast `Stream<AgUiEvent> get resumeEvents` (or fold resume into the existing run stream via a retained sink) — at the cost of agent state and a second event channel. Recommend the `Stream`-returning shape; confirm at review.

### The resume wire shape (the AC2 decision, RESOLVED from SPIKE-LG-RESUME)

Source-verified, docker-probed (`../koel_backend/backends/langgraph/CONTRACT.md`, `ag_ui_langgraph==0.0.37` source read 2026-06-02):
- **No separate resume endpoint.** `add_langgraph_fastapi_endpoint` registers a single `POST {path}` taking a `RunAgentInput`; run **and** resume share it. So `resume` POSTs to **`deploymentUrl` verbatim**, exactly like `run` (no new route, no suffix).
- **Resume value lives at `forwardedProps.command.resume`** (camelCase on the wire). `ag-ui-langgraph` runs `camel_to_snake` on the top-level `forwardedProps` keys, reads `forwarded_props["command"]["resume"]`, and builds a LangGraph `Command(resume=<value>)` server-side (`agent.py` L167-178, L471-477, L554-574). A JSON-parseable string is decoded; otherwise the raw value is passed. **koel sends the value as-is nested under `command.resume`** — never a top-level field, never a pre-built `Command` envelope.
- **Same `threadId` reloads the checkpoint; `runId` is per-request.** Resume reuses `threadId` to `aget_state(config)` against the same in-process `MemorySaver` and re-enters the paused `interrupt` node (not `entry` — proving checkpoint resumption, not a fresh run). `runId` is a fresh id each request; the **thread** is the checkpoint key (`CONTRACT.md` SPIKE-LG-RESUME pt.4). So 5.5 **mints** `runId: 'resume-$threadId'` — deterministic, dependency-free, functionally irrelevant to the server (the determinism normalizer strips `runId` for capture anyway, CONTRACT line 67). This supersedes epic AC1's "same threadId/**runId**" phrasing (A.4's `resume` exposes **no** `runId` param to reuse).
- **Interrupt surfaces as AG-UI `CUSTOM`** `{name: "on_interrupt", value: <payload>}` (`agent.py` L429-437/L531-539). It rides the **`run()`** stream as a plain `CustomEvent` through the inherited parse — koel does **not** special-case it in 5.5. Detecting it and deciding to resume is the **consumer's** job (surface-level). Hitting the same thread again **without** a resume short-circuits to `RUN_STARTED → CUSTOM(on_interrupt) → RUN_FINISHED` (an idempotent re-surface, `agent.py` L526-549) — out of scope to handle specially here.

### Existing-code contracts that must not break

- **`resume` is one `run(...)` call — reuse, don't re-implement.** The full inherited path (`HttpAgent.run` → `InterceptorChain` → `_TransportTerminal` POST + SSE parse + chunk-synthesis + `DefaultErrorClassifier`) is already correct and tested by 5.4. `resume` only constructs the resume-shaped `RunAgentInput`. Do not override the response path (langgraph is native AG-UI), do not touch `encodeBody` (its `messages` normalization applies to resume too — resume carries no messages by default, so it is a no-op there, but the path is unchanged), do not add interceptors.
- **`LangGraphAgent` stays stateless.** 5.4 kept it stateless (just `apiKey` + the ctor). Keep it so — no retained controllers/sinks/last-run references. Returning a `Stream` from `resume` is what makes statelessness possible.
- **Adapters never throw `KoelError`** (ARCH: every failure reaches the consumer as a terminal `RunErrorEvent`). A resume that 401s/refuses surfaces as a terminal `RunErrorEvent` on the `resume(...)` stream via the inherited `DefaultErrorClassifier` — the tests must assert **emitted events**, not a thrown error. The only sanctioned throw is the optional construction/call-time `ArgumentError` on an empty `threadId` (a programmer error before any run, like the ctor's `deploymentUrl` guard).
- **`forwardedProps` is a free-form `Map<String, dynamic>`** on `RunAgentInput` (default `{}`). The `AuthInterceptor` parks resolved headers on a **reserved** `forwardedProps` key that `_TransportTerminal` strips before encoding — the resume `command` key never collides with it (distinct key, and auth's key is stripped pre-wire). No interaction to worry about.
- **`plugins:` / `analysis_options.yaml` is root-only until 5.6** (Story 1.7 `plugins_in_inner_options`; 5.4 added no package options). 5.5 adds none either — inherit the root config; write the `resume` dartdoc so 5.6's member-doc gate lands clean.

### Testing standards

- **Harness:** reuse `langgraph_agent_test.dart`'s `_capturingClient` (request-capturing `MockClient`) for the AC2 body assertion, and `MockClient` + `sseBody` (`test/_support.dart`) for the AC3 round-trip. `@TestOn('vm')`. Build the interrupt/resumed SSE **inline** — no new bundled fixture (the real capture is 5.6).
- **AC2 assertions:** URL == `deploymentUrl` verbatim, POST, `jsonDecode(body)` exact: `threadId`, `runId == 'resume-$threadId'`, `forwardedProps == {'command':{'resume': <resumeValue>}}`. Add a variant asserting `x-api-key` rides the resume request when `apiKey` is set (resume is not auth-exempt).
- **AC3 assertions:** `run()` surfaces the `on_interrupt` payload as a `CustomEvent` (consumer-detectable); `resume(...).toList()` yields the resumed `RUN_STARTED…RUN_FINISHED` typed events in order. No client-side state assertions — koel reconstructs nothing.
- **No suppressions:** keep `dart analyze` at 0 by writing the dartdoc, not by disabling rules.

### Latest technical / wire facts (source-verified, not web-guessed)

From `../koel_backend/backends/langgraph/CONTRACT.md` (authoritative — `ag_ui_langgraph==0.0.37` source-read + docker-probed live 2026-06-02):
- **Route:** `POST /agent` (run **and** resume share it). koel POSTs to `deploymentUrl` verbatim.
- **Resume body:** `RunAgentInput` with **same `threadId`** + `forwardedProps:{command:{resume:<resumeValue>}}` (camelCase). `runId` per-request (fresh).
- **Interrupt surface:** AG-UI `CUSTOM` `{name:"on_interrupt", value:<payload>}`.
- **State:** rebuilt **server-side** from the in-process `MemorySaver` checkpoint keyed by `threadId` (restart resets it). Single-process uvicorn (`reload=False`, no `--workers`) is required for the checkpoint to survive cross-request (AD-10, FR-8) — a **deploy constraint**, not a koel concern.
- **Versions pinned:** `ag_ui_langgraph==0.0.37`, `langgraph 1.2.2`, `ag-ui-protocol 0.1.18`. **No dep bump in 5.5** (koel_langgraph stays on `http: ^1.6.0`; resume adds no dependency).

### Source tree (what to touch)

```
packages/koel_langgraph/
├── lib/
│   └── src/
│       └── langgraph_agent.dart        # UPDATE: add Stream<AgUiEvent> resume(...) + dartdoc; flip the class-doc "resume arrives in 5.5" line (AC1)
├── README.md                            # UPDATE: Interrupt-resume v1/v2 disclaimer + OQ-LangGraph-Graduation link (AC4)
└── test/
    ├── langgraph_agent_test.dart        # UPDATE (or add langgraph_resume_test.dart): resume request-shape + interrupt→resume round-trip (AC2, AC3)
    └── _support.dart                    # (reuse sseBody as-is; extend only if the inline interrupt/resumed builders want a helper)

_bmad-output/implementation-artifacts/deferred-work.md   # UPDATE: record 5.5→5.6 (real interrupt fixture + conformance lane) + 5.5→v2 (deep resume) (Task 4)
```
**NOT touched** (Story 5.6 / v2): `tool/capture_fixtures.dart` (langgraph branch stays stubbed), `koel_test/lib/src/fixtures/langgraph/*` (still `.placeholder`), `.github/workflows/conformance.yml`, root `pubspec.yaml` melos scripts, `packages/koel_langgraph/{analysis_options,coverage_options}.yaml`, `error/langgraph_error_classifier.dart`, `langgraph_auth_interceptor.dart` (unchanged), `conversion/message_conversion.dart` (unchanged), `pubspec.yaml` (no new deps).

### Project Structure Notes

- 5.5 is a **single-method addition** to the agent 5.4 shipped — the smallest langgraph-group story. It introduces **no new `lib/src/` file** (resume is a method on the existing `LangGraphAgent`), mirroring how the agno group threaded incremental capability through its existing agent rather than minting new types.
- The one intentional divergence from the frozen Addendum A.4 (`Stream` return type vs `Future<void>`) is evidence-backed and flagged for Si at review (see Dev Notes). Everything else inherits 5.4's shape unchanged.
- Additive within koel_langgraph only; touches no other package → `melos test` regression surface is zero outside this package.

### References

- [Source: _bmad-output/planning-artifacts/epics/epic-5-backend-bridges-koelagno-koellanggraph-koelruntime.md#Story-5.5] — story ACs (`resume(threadId, resumeValue)`, reopen SSE same thread, synthesized interrupt scenario, README v1/v2 note).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#A.4] — the A.4 `resume` sketch (`Future<void>`, "echoes MetaEvent back") this story reconciles to `Stream<AgUiEvent>`; Future-4 deep-resume deferral (line 672).
- [Source: ../koel_backend/backends/langgraph/CONTRACT.md#SPIKE-LG-RESUME] — authoritative resume wire: shared `POST /agent` route, same `threadId`, `forwardedProps.command.resume`, per-request `runId`, `on_interrupt` CUSTOM event, server-side checkpoint rebuild, single-process deploy constraint.
- [Source: _bmad-output/implementation-artifacts/5-4-langgraph-agent-protocol-conversion.md] — the langgraph opener this extends: `LangGraphAgent extends HttpAgent` (deploymentUrl verbatim, default-ON `x-api-key`, `encodeBody` messages override, stateless), the sealer-defers-finalization pattern, the test harness (`_capturingClient`, `sseBody`).
- [Source: packages/koel_langgraph/lib/src/langgraph_agent.dart] — the agent to edit (add `resume`, flip the class-doc resume line).
- [Source: packages/koel_http/lib/src/http_agent.dart#L135-L159] — `run()` → `InterceptorChain` the resume delegates to; `encodeBody` request-only seam (L174-176); `_TransportTerminal` POST + `forwardedProps` auth-key strip (L205-249).
- [Source: packages/koel_core/lib/src/input/run_agent_input.dart] — `RunAgentInput` shape (`forwardedProps` free-form `Map`, default `{}`); resume builds one of these.
- [Source: packages/koel_core/lib/src/agent/abstract_agent.dart] — `AbstractAgent.run` returns `Stream<AgUiEvent>`; the surface `resume` mirrors.
- [Source: packages/koel_core/lib/src/client/chat_session.dart#L75] — koel's deterministic runId convention (`'run-$threadId-$runIndex'`) — precedent for the minted `'resume-$threadId'`.
- [Source: packages/koel_langgraph/test/langgraph_agent_test.dart + test/_support.dart] — `_capturingClient`, `sseBody`, `fixturePayloads` the resume tests reuse.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8, 1M context) — via `/bmad-dev-story`; `/agent-flutter-engineer` specialist loaded for all Dart work (CLAUDE.md mandate).

### Debug Log References

- **Clean single-method add — no surprises.** `resume` is one `run(...)` call with a resume-shaped `RunAgentInput` (same threadId, minted `runId: 'resume-$threadId'`, `forwardedProps:{command:{resume:…}}`). It reuses the entire inherited transport/`x-api-key`/`encodeBody`/SSE-parse/classifier path verbatim; `LangGraphAgent` stays stateless. The baked decision (`Stream<AgUiEvent>` return, confirmed by Si in create-story) held — a `Future<void>` could not surface the resumed stream.
- **Interrupt detection stays consumer-side.** Verified the `on_interrupt` payload rides `run()` as a plain `CustomEvent` (`name`/`value`) through the inherited parse — koel does not special-case it. The round-trip test asserts this directly (a `CustomEvent` with `name == 'on_interrupt'`), then asserts `resume()` emits the exact typed resumed sequence.
- **Round-trip harness.** Built both SSE streams inline with the existing `sseBody` helper; a single `MockClient` routes by `forwardedProps.command` presence (run → paused stream, resume → resumed stream), mirroring the single-route backend (CONTRACT.md: run + resume share `POST /agent`). No new bundled fixture (real capture is 5.6).
- **Format gate.** `tool/format.sh check` flagged the new test block once; ran `dart format packages/koel_langgraph` (write), re-checked → 0 changed. Analyze + tests re-verified green after.
- **Coverage tooling.** `format_coverage` needed `--base-directory=.` to resolve `package:` URIs to `lib/` (without it, a spurious 0-hit lcov). Final informational: line 35/35 (100%), `langgraph_agent.dart` 24/24. Not gated here (5.6 sealer).
- **Gates:** `dart run melos analyze` → SUCCESS (all pkgs, "No issues found"). `dart test packages/koel_langgraph` → **+32**. `dart run melos test` → SUCCESS, no regression (koel_core +576, koel_http +97, koel_lints +5). `tool/format.sh check` → clean.

### Completion Notes List

- **COMPLETE — all 4 tasks + subtasks done, all gates green, Status → review.** `LangGraphAgent` gained surface-level interrupt-resume: `Stream<AgUiEvent> resume(String threadId, Map<String,dynamic> resumeValue)` delegating to inherited `run` with `forwardedProps.command.resume` + minted `runId`, plus an `ArgumentError` fail-fast on a blank thread.
- **Both source-verified reconciliations shipped as designed.** (1) `resume` returns `Stream<AgUiEvent>` (not A.4's `Future<void>` — there is no `MetaEvent` type; epic AC2 requires a stream) — **Si confirmed this in create-story**. (2) Resume wire = same route, same `threadId`, `forwardedProps:{command:{resume:…}}`, per-request minted `runId` (SPIKE-LG-RESUME).
- **Surface-level, not deep.** koel reconstructs no state; LangGraph rebuilds server-side from its checkpoint. The consumer detects `on_interrupt` itself (raw `CustomEvent`). Deep/stateful resume + typed interrupt model → v2 (OQ-LangGraph-Graduation).
- **Additive within koel_langgraph only.** No other package touched; full workspace suite shows no regression. No new deps. README disclaimer added (interrupt-resume section); broader README finalization + real interrupt fixture + conformance lane + coverage gate + analysis_options + `LangGraphErrorClassifier` deferred to **5.6** (recorded in `deferred-work.md`). Nothing stubbed.

### File List

- `packages/koel_langgraph/lib/src/langgraph_agent.dart` — **MODIFIED**: added `Stream<AgUiEvent> resume(String threadId, Object? resumeValue)` (delegates to `run` with `forwardedProps.command.resume` + deterministic minted `runId`, trim-and-use blank-threadId `ArgumentError` guard) + its dartdoc; flipped the class dartdoc's "resume arrives in 5.5" line to describe the present surface-level resume (AC1). **Review:** `resumeValue` typed `Object?` (not `Map<String, dynamic>`) for AG-UI parity (supersedes epic AC1/AC2); dartdoc no longer embeds a machine-local CONTRACT path.
- `packages/koel_langgraph/README.md` — **MODIFIED**: added the **Interrupt-resume** section (surface-level v1 + `resume` snippet + server-side state rebuild; deep resume → v2, `OQ-LangGraph-Graduation` bare token) (AC4).
- `packages/koel_langgraph/test/langgraph_agent_test.dart` — **MODIFIED**: added `group('surface-level interrupt-resume (Story 5.5)')` — resume request-shape (forwardedProps.command.resume + minted runId + verbatim URL), `x-api-key` rides resume, blank-threadId `ArgumentError`, and the interrupt→resume round-trip (AC2, AC3).
- `_bmad-output/implementation-artifacts/deferred-work.md` — **MODIFIED**: recorded the 5.5→5.6 (real interrupt fixture + conformance lane + coverage gate + analysis_options + README finalization) and 5.5→v2 (deep resume + typed interrupt model) hand-offs + the README OQ-hyperlink docs follow-up.

## Change Log

| Date | Version | Description | Author |
|------|---------|-------------|--------|
| 2026-06-03 | 0.1 | Story drafted — langgraph surface-level interrupt-resume: `LangGraphAgent.resume(threadId, resumeValue)` delegating to inherited `run` with `forwardedProps.command.resume` + minted `runId`, README v1/v2 disclaimer, synthesized interrupt→resume tests. Two source-verified reconciliations baked RESOLVED (resume returns `Stream<AgUiEvent>` not A.4's `Future<void>` — flagged for Si at review as a one-way-door API divergence; resume wire = `forwardedProps.command.resume` + per-request `runId` per SPIKE-LG-RESUME). Real captured interrupt fixture + conformance lane + coverage gate + `LangGraphErrorClassifier` deferred to 5.6; deep stateful resume deferred to v2 (OQ-LangGraph-Graduation). Status → ready-for-dev. | Bob (SM) |
| 2026-06-03 | 0.2 | Si confirmed the `Stream<AgUiEvent>` resume surface (create-story decision) — baked as designed. | Si / Bob (SM) |
| 2026-06-03 | 1.0 | Implemented 5.5 (all 4 tasks green). `Stream<AgUiEvent> resume(...)` on `LangGraphAgent` (delegates to inherited `run`; `forwardedProps.command.resume` + minted `runId: 'resume-$threadId'`; blank-threadId `ArgumentError`; agent stays stateless), README Interrupt-resume disclaimer, +6 tests (request-shape, x-api-key-on-resume, fail-fast, interrupt→resume round-trip). `melos analyze` SUCCESS, `dart test koel_langgraph` +32, `melos test` no-regression, format clean. Coverage informational line 100% (35/35). Sealer (5.6) + v2 hand-offs recorded. **Status → review.** | Amelia (Dev) |
| 2026-06-03 | 1.1 | Code review (3-layer adversarial + parity arbitration). Deciding principle (Si): parity with the canonical AG-UI standard. **`resumeValue` retyped `Map<String, dynamic>` → `Object?`** (4-source parity: wire `Command(resume=<any JSON>)`, the live spike used a bare string the `Map` couldn't express, AG-UI `resume=any`, and the `Object?` twin `CustomEvent.value`) — supersedes epic AC1/AC2's literal `Map`. `Stream<AgUiEvent>` return type confirmed (parity: resume = run). 5 more patches: trim-and-use `threadId`, dartdoc "fresh"→"deterministic", dropped machine-local CONTRACT path from public dartdoc, AC3 test filters by `name=='on_interrupt'` not `.single`, added failed-resume→`RunErrorEvent` + bare-string parity tests. 5 findings dismissed (refuted/intentional). `dart analyze` 0, `dart test koel_langgraph` **+34**, `melos test` no-regression, format clean. **Status → done.** | Si / Code Review |
