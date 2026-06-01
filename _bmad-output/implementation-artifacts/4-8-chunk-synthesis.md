---
baseline_commit: 31e558e3d0fcaeaa1a8de6429e42a959c0cdb59d
---

# Story 4.8: Chunk synthesis (START/CONTENT/END from CHUNK)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this is **Story 4.8 of Epic 4** (HTTP transport, `koel_http`). It makes `HttpAgent.synthesizeChunks` *do something* — when `true` (the default), `HttpAgent.run()` normalizes the streaming `*_CHUNK` convenience shapes (`TOOL_CALL_CHUNK`, `TEXT_MESSAGE_CHUNK`, and — for free, see trap #9 — `REASONING_MESSAGE_CHUNK`) into the canonical `START` → `CONTENT`/`ARGS` → `END` triplets **before they leave the transport**, so a consumer reading the raw `AbstractAgent` stream (no `KoelClient`) and the Epic-5 backends both see long-form events (FR-B5 + Addendum F.2). It touches `.dart` files, the transport seam, and **koel_core's 1.x public barrel**, so **invoke `/agent-flutter-engineer` before producing any code** (per [CLAUDE.md](CLAUDE.md)). `packages/koel_http/` already ships `SseParser` (4.1), `HttpAgent` + the transport seam + `_TransportTerminal` (4.2), the `abortOnCancel` watchdog (4.3), and the six interceptors (4.4–4.7). **The single most important fact: the synthesis logic you need already exists, fully tested, in `koel_core` — your job is to REUSE it, not rebuild it.** Ten things are load-bearing; the first four sink a naïve reading of the AC:
>
> 1. **DO NOT reimplement synthesis. Reuse `koel_core`'s `chunksStage` — the one F.2 source of truth.** [`chunks_stage.dart`](packages/koel_core/lib/src/pipeline/chunks_stage.dart) is the canonical, ~120-LOC, property-tested ([chunks_stage_test.dart](packages/koel_core/test/pipeline/chunks_stage_test.dart)) implementation of every Addendum F.2 rule — envelope tracking across three independent id namespaces, missing-name/role defaulting, first-chunk-with-delta, drop-the-un-addressable, flush-on-done. Re-typing this into `koel_http` is the textbook *"reinventing wheels"* disaster: ~100 lines of subtle stateful logic forked into a second copy that **will** drift from the pipeline's. The clean path is to **expose `chunksStage` from koel_core's barrel** (trap #7) and `stream.transform(chunksStage)` in the transport. One implementation, two call sites. [Source: chunks_stage.dart:47-171; CLAUDE.md "Composition > inheritance / No vestigial code"; checklist "Reinventing wheels"]
> 2. **Synthesis is LAYERED, not redundant — and the double-application is idempotent by design.** `koel_core`'s `runPipeline` *always* runs `chunksStage` (it's stage 1 of the locked four-stage order — [pipeline.dart:29-36](packages/koel_core/lib/src/pipeline/pipeline.dart)). So on the default path (`synthesizeChunks: true` + a `KoelClient` consumer) events are synthesized **at the transport AND again in the pipeline**. This is **safe**: once the transport has turned every `*_CHUNK` into `START`/`CONTENT`/`END`, the pipeline's `chunksStage` sees only **non-chunk** events and passes them straight through its `default:` branch ([chunks_stage.dart:144-148](packages/koel_core/lib/src/pipeline/chunks_stage.dart)). No double-synthesis, no doubled `END`. You must **prove this idempotency with a test** (trap #8) — it is the linchpin that lets transport synthesis and pipeline synthesis coexist. [Source: pipeline.dart:9-36; chunks_stage.dart:144-148]
> 3. **`synthesizeChunks: false` does NOT mean "the reducer sees chunks."** It means **the raw `HttpAgent.run()` stream emits chunks unchanged** (AC2). A consumer who pipes that agent through `KoelClient`/`ChatSession` will *still* get long form, because the pipeline's `chunksStage` (trap #2) normalizes whatever the agent emits. `synthesizeChunks` governs **only the transport's own output stream** — its value is for the layer-3 raw `AbstractAgent` consumer and the Epic-5 backends, not for `KoelClient` users. Assert AC2 against `HttpAgent.run()` directly, never through a pipeline. [Source: epic-4 :207-209; pipeline.dart:29-36; koel_client.dart:120-141]
> 4. **Synthesis goes INSIDE `_TransportTerminal.run` (innermost, per-connection) — below every interceptor, below `RetryInterceptor`.** `HttpAgent.run` composes the chain as `InterceptorChain(interceptors, agent: _TransportTerminal(this))` ([http_agent.dart:124-129](packages/koel_http/lib/src/http_agent.dart)). Put the `.transform(chunksStage)` on the parsed stream **in the terminal**, not on the chain's output, for two reasons: (a) **`RetryInterceptor` is outermost and re-runs the terminal per attempt** ([http_agent.dart:108-123](packages/koel_http/lib/src/http_agent.dart)) — synthesis must reset its envelope state on every reconnect (a fresh SSE stream is a fresh synthesis), which only happens if it lives beneath retry; (b) interceptors (logging/trace/sentry/redaction) then observe **canonical long-form** events, the useful shape. Synthesis above the chain would carry one envelope state machine across reconnects → leaked/abandoned envelopes. [Source: http_agent.dart:105-129, 137-217; chunks_stage.dart:154-170]
> 5. **`synthesizeChunks` is currently DROPPED on the floor — you must add the field.** The 4.2 constructor *accepts* `bool synthesizeChunks = true` but the initializer list never stores it ([http_agent.dart:68-82](packages/koel_http/lib/src/http_agent.dart) — only `_client`/`_retry`/`_onReconnectAttempt`/`_interceptors` are assigned). Add `final bool synthesizeChunks;` (public, like `connectTimeout`/`readTimeout`) and read it in the terminal as `_agent.synthesizeChunks`. Update the class dartdoc that currently says it's *"owned by later stories … consumed when their story lands: [synthesizeChunks] → Story 4.8"* (this is that story). [Source: http_agent.dart:62-95]
> 6. **Cancel-safety: synthesis must sit INSIDE `abortOnCancel`, and `<50 ms` abort must still hold.** Today the terminal does `yield* abortOnCancel(SseParser().parse(body), response.abort)` ([http_agent.dart:212-215](packages/koel_http/lib/src/http_agent.dart)). Insert synthesis **between the parser and `abortOnCancel`** so the abort guard wraps the synthesized stream: `abortOnCancel(parsed.transform(chunksStage), response.abort)`. `chunksStage` is `buildStage`-backed (cancellation-correct — [stage_support.dart:42-79](packages/koel_core/lib/src/pipeline/stage_support.dart)): on cancel it cancels upstream and **does not** call `onDone`, so **no trailing `END` is flushed after a cancel** and no synthesized event escapes the abort gate. Re-run [cancellation_test.dart](packages/koel_http/test/cancellation_test.dart) with synthesis ON (default) to prove NFR-8 still holds. [Source: http_agent.dart:207-216; stage_support.dart:53-76; cancellation.dart]
> 7. **The koel_core barrel change is additive, deliberate, and narrowly scoped — expose ONLY the chunk synthesizer.** koel_http cannot `import 'package:koel_core/src/...'` (forbidden; the barrel header is explicit — [koel_core.dart:9-16](packages/koel_core/lib/koel_core.dart)), so reuse (trap #1) requires `chunksStage` on the public barrel. Add exactly one export — `export 'src/pipeline/chunks_stage.dart';` — and **amend the barrel header comment** that currently lists "the pipeline stages" as internal, carving out chunk synthesis as the one stage the transport legitimately needs (Addendum F.2 ties it to `HttpAgent.synthesizeChunks`). **Keep `verify`/`apply`/`transform` internal** — nothing outside the pipeline needs them. This is a 1.x one-way door (AR-15); it is correct here because a *sibling transport package* feeding the pipeline is not the "consumer who reaches stages through `KoelClient`" the barrel warns against. [Source: koel_core.dart:1-17; addendum.md:521,644; AR-15]
> 8. **AC3's "property-based synthesis-correctness test" already exists in koel_core — do not re-port it.** Because you reuse `chunksStage` (trap #1), synthesis *correctness* (every `START` has a matching `END`, verify rules pass on the output) is already locked by [chunks_stage_test.dart](packages/koel_core/test/pipeline/chunks_stage_test.dart) and the chunks→verify composition in [pipeline_test.dart:81-146](packages/koel_core/test/pipeline/pipeline_test.dart). Your koel_http tests prove the **wiring + idempotency**: (a) `true` → `HttpAgent.run()` emits well-formed triplets; (b) `false` → raw chunks pass through; (c) idempotency — synthesized transport output through `runPipeline` is unchanged and emits no extra `END`. Satisfy AC3 by asserting matched `START`/`END` pairing on the transport output directly (no `verifyStage` import — it stays internal). [Source: chunks_stage_test.dart; pipeline_test.dart:81-146; verify_stage.dart]
> 9. **Reuse means reasoning chunks are normalized too — that's a feature, keep it.** AC1 names `TOOL_CALL_CHUNK` and `TEXT_MESSAGE_CHUNK` only, but `chunksStage` *also* synthesizes `REASONING_MESSAGE_CHUNK` → `ReasoningMessageStart/Content/End` ([chunks_stage.dart:116-143](packages/koel_core/lib/src/pipeline/chunks_stage.dart)). Reusing the stage means the transport normalizes reasoning chunks as well — a strict **superset** of AC1 that keeps `HttpAgent`'s output consistent with the pipeline. Do **not** try to suppress it; a divergent transport-only subset would be the exact drift trap #1 warns against. [Source: chunks_stage.dart:116-143]
> 10. **The chunk lines in `all_event_types.jsonl` are all-null and get DROPPED — they won't test synthesis.** [all_event_types.jsonl:10,15,26](packages/koel_test/lib/src/fixtures/synthesized/all_event_types.jsonl) carry empty chunk payloads (`{"type":"TOOL_CALL_CHUNK"}`), which `chunksStage` drops as un-addressable ([chunks_stage.dart:62,87,117](packages/koel_core/lib/src/pipeline/chunks_stage.dart)). To exercise real synthesis in the `HttpAgent` loopback test, **construct real chunk wire lines** (with `toolCallId`/`messageId`/`delta`) inline via the event `toJson()` + the existing `_sseServer(String body)` helper ([http_agent_test.dart:40-56](packages/koel_http/test/http_agent_test.dart)). A new shared `koel_test` fixture is optional, not required. [Source: all_event_types.jsonl; chunks_stage.dart:62,87,117; http_agent_test.dart:40-95]

## Story

As a Flutter/Dart developer,
I want chunk synthesis ON by default in `HttpAgent.synthesizeChunks` so `TOOL_CALL_CHUNK` and `TEXT_MESSAGE_CHUNK` are normalized to START/CONTENT/END triplets before the verify stage,
so that downstream pipeline + reducer only handle the long form per FR-B5 + Addendum F.2.

## Acceptance Criteria

Verbatim from [epic-4 Story 4.8](_bmad-output/planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (lines 192-213):

1. **Given** `HttpAgent(synthesizeChunks: true)` (default), **When** a wire stream of `TOOL_CALL_CHUNK` events arrives, **Then** the first chunk for a given `toolCallId` synthesizes `ToolCallStartEvent` with `toolCallId`, `toolCallName`, `parentMessageId`, **And** subsequent chunks synthesize `ToolCallArgsEvent(toolCallId, delta)`, **And** the trailing "complete" marker synthesizes `ToolCallEndEvent(toolCallId)`, **And** the same rules apply to `TEXT_MESSAGE_CHUNK` → START/CONTENT/END using `messageId` + `delta`.

2. **Given** `HttpAgent(synthesizeChunks: false)`, **When** the same wire stream arrives, **Then** raw `ToolCallChunkEvent` and `TextMessageChunkEvent` instances pass through unchanged.

3. **Given** the verify stage from Story 2.11 running downstream, **When** synthesized triplets feed it, **Then** verify rules pass for matched START/END pairs and fail when synthesis is wrong (regression-tested via property-based synthesis-correctness test).

> **AC clarifications (RESOLVED — do not re-litigate, implement):**
>
> - **AC1 "trailing complete marker".** There is no literal `TOOL_CALL_CHUNK(complete: true)` on the wire. The `END` is synthesized by `chunksStage` when the **envelope closes** — i.e. the next non-chunk event arrives, a chunk for a *different* id arrives, or the stream completes (`onDone` flush). This is exactly `chunksStage`'s existing behavior ([chunks_stage.dart:67-71,144-170](packages/koel_core/lib/src/pipeline/chunks_stage.dart)); you inherit it by reusing the stage. [Source: chunks_stage.dart:24-28 dartdoc]
> - **AC1 scope via reuse.** Reusing `chunksStage` (trap #1) satisfies AC1's tool-call and text-message rules *and* adds reasoning-chunk synthesis (trap #9) for free — a documented superset, not a deviation. Defaulting (missing `toolCallName` → `''`, missing text `role` → `'assistant'`) is `chunksStage`'s contract; do not re-specify it. [Source: chunks_stage.dart:30-42]
> - **AC2 surface = the transport stream ONLY.** `synthesizeChunks: false` ⇒ `HttpAgent.run()` yields the parser's events verbatim (raw `ToolCallChunkEvent`/`TextMessageChunkEvent`/`ReasoningMessageChunkEvent`). Test it by subscribing `agent.run(input)` directly. It does **not** disable the pipeline's `chunksStage` for `KoelClient` consumers — that is by design (trap #2/#3), not a bug. [Source: epic-4 :207-209; trap #3]
> - **AC3 mechanism.** "The verify stage running downstream" describes the production flow (transport synthesizes → pipeline `verifyStage` validates). Synthesis-correctness-vs-verify is **already** property-tested in koel_core against the single shared `chunksStage` ([chunks_stage_test.dart](packages/koel_core/test/pipeline/chunks_stage_test.dart), [pipeline_test.dart:81-146](packages/koel_core/test/pipeline/pipeline_test.dart)). 4.8's new tests prove the **transport wiring + idempotency** (trap #8); they assert well-formed `START`/`END` pairing on `HttpAgent.run()` output **without** importing the internal `verifyStage`. [Source: trap #8; verify_stage.dart]
> - **Default ON.** `synthesizeChunks` defaults to `true` (already the 4.2 ctor default) — chunk synthesis is ON by default per the epic header and Addendum F.2:644. [Source: epic-4 :3,195; addendum.md:644]
> - **OUT OF SCOPE (RESOLVED — do NOT build):** `onConnect`/`onDisconnect`/`onReconnectAttempt` lifecycle hooks (Story 4.9 — `onReconnectAttempt` is *already* wired for retry; do not extend); web transport + `package:web` + the `sse_parse_bench` perf baseline (Story 4.10); the per-member `analysis_options.yaml` doc gate + ≥90% coverage gate (epic-sealing **Story 4.10** — write full dartdoc anyway so 4.10 needs no backfill); changing the pipeline's four-stage order or making `chunksStage` conditional in `runPipeline` (the pipeline stays exactly as Story 2.11 locked it); exposing `verifyStage`/`applyStage`/`transformStage` (only `chunksStage` is exposed — trap #7); any new `koel_test` fixture (inline wire lines suffice — trap #10). [Source: epic-4 :215-271; pipeline.dart:9-36]

## Tasks / Subtasks

- [x] **Task 0 — Read the real surfaces before writing a line** (AC: all — skipping this builds the wrong seam or a duplicate)
  - [x] Read [chunks_stage.dart](packages/koel_core/lib/src/pipeline/chunks_stage.dart) **in full** — this is the logic you reuse, not rebuild (trap #1). Note: three independent envelopes (tool/text/reasoning), the `default:` pass-through (trap #2 idempotency), the `onDone` flush (AC1 "trailing marker"), the drop-on-null-id (trap #10). [Source: chunks_stage.dart:1-171]
  - [x] Read [pipeline.dart](packages/koel_core/lib/src/pipeline/pipeline.dart) — confirm `chunksStage` is **unconditional** stage 1 of `runPipeline` (trap #2/#3) and the order is locked. [Source: pipeline.dart:9-36]
  - [x] Read [http_agent.dart](packages/koel_http/lib/src/http_agent.dart) **lines 45-130** (ctor drops `synthesizeChunks` — trap #5; chain wiring + retry-outermost — trap #4) and **lines 137-217** (`_TransportTerminal.run`: parse → `abortOnCancel` — the exact insertion point, trap #6). [Source: http_agent.dart:45-217]
  - [x] Read [stage_support.dart](packages/koel_core/lib/src/pipeline/stage_support.dart) **lines 42-79** — `buildStage` cancel/backpressure correctness: on cancel it cancels upstream and skips `onDone` (no post-cancel `END` — trap #6). [Source: stage_support.dart:42-79]
  - [x] Read [koel_core.dart](packages/koel_core/lib/koel_core.dart) **lines 1-17** — the barrel header you must amend (trap #7); confirm pipeline stages are currently all internal. [Source: koel_core.dart:1-17]
  - [x] Skim [http_agent_test.dart](packages/koel_http/test/http_agent_test.dart) **lines 17-95** — `_fixturePayloads`, `_sseServer(String body)` loopback, fixture-replay shape; this is the harness you extend for the synthesis tests (trap #10). [Source: http_agent_test.dart:17-95]

- [x] **Task 1 — Expose `chunksStage` from the koel_core barrel** (AC: #1, #3)
  - [x] In [packages/koel_core/lib/koel_core.dart](packages/koel_core/lib/koel_core.dart) (MODIFY) add `export 'src/pipeline/chunks_stage.dart';` under a new `// ---- Pipeline: the transport-reusable chunk synthesizer ----` group. This surfaces the top-level `chunksStage` `StreamTransformer<AgUiEvent, AgUiEvent>` and **nothing else** (`stage_support.dart`'s `buildStage`/`PipelineStage` live in a different file and are not re-exported). [Source: chunks_stage.dart:47; koel_core.dart:60-64]
  - [x] Amend the barrel header dartdoc ([koel_core.dart:8-12](packages/koel_core/lib/koel_core.dart)) so it no longer claims *all* pipeline stages are internal: carve out chunk synthesis as the one stage exposed for sibling transport packages (Addendum F.2 ties it to `HttpAgent.synthesizeChunks`), while `verify`/`apply`/`transform` stay internal. [Source: trap #7; addendum.md:521,644]
  - [x] This is an **additive** 1.x koel_core API change (a new public symbol). No published `dart_apitool` baseline exists yet (Story 9.3), so no API-diff gate fails; flag it in the change log as a deliberate contract addition. [Source: 4-7 Task 6 api-diff note; AR-15]

- [x] **Task 2 — Store `synthesizeChunks` + apply synthesis in the transport** (AC: #1, #2)
  - [x] In [http_agent.dart](packages/koel_http/lib/src/http_agent.dart) (MODIFY) add `final bool synthesizeChunks;` and assign it in the initializer list (`this.synthesizeChunks` shorthand on the ctor param, like `connectTimeout`/`readTimeout`) — fixing the dropped-param bug (trap #5). [Source: http_agent.dart:68-95]
  - [x] Update the class/ctor dartdoc: remove the *"owned by later stories … [synthesizeChunks] → Story 4.8"* deferral ([http_agent.dart:63-67](packages/koel_http/lib/src/http_agent.dart)) and document what `synthesizeChunks` now does — transport-level CHUNK→START/CONTENT/END normalization (default ON), reusing koel_core's `chunksStage`; note it governs the **transport's own output stream only** and that `KoelClient` consumers are normalized by the pipeline regardless (trap #3). [Source: http_agent.dart:16-67; trap #3]
  - [x] In `_TransportTerminal.run` ([http_agent.dart:207-216](packages/koel_http/lib/src/http_agent.dart)) gate synthesis on `_agent.synthesizeChunks` and place it **inside** `abortOnCancel` (trap #4/#6):
    ```dart
    final parsed = const SseParser().parse(response.body);
    final events = _agent.synthesizeChunks ? parsed.transform(chunksStage) : parsed;
    yield* abortOnCancel(events, response.abort);
    ```
    Add a comment: synthesis is innermost (per-connection, beneath retry → fresh envelope state per reconnect) and inside the abort gate (no synthesized event / trailing `END` escapes after cancel). [Source: http_agent.dart:207-216; trap #4/#6]

- [x] **Task 3 — Tests** (AC: #1, #2, #3)
  - [x] New `packages/koel_http/test/chunk_synthesis_test.dart` (`package:test`; reuse `_sseServer`/`_fixturePayloads` from [http_agent_test.dart](packages/koel_http/test/http_agent_test.dart), or build SSE bodies inline from chunk `toJson()` lines — trap #10):
    - [x] **AC1 tool-call (default ON):** serve a body of `TOOL_CALL_CHUNK` lines — first `{toolCallId:'c', toolCallName:'search', parentMessageId:'p'}`, then `{toolCallId:'c', delta:'{'}`, `{toolCallId:'c', delta:'}'}`, then a non-chunk terminal (e.g. `RUN_FINISHED`) — through `HttpAgent(url: …)` (default `synthesizeChunks: true`); assert `run()` yields `ToolCallStartEvent('c','search', parentMessageId:'p')`, `ToolCallArgsEvent('c','{')`, `ToolCallArgsEvent('c','}')`, `ToolCallEndEvent('c')`, then the terminal — **no** `ToolCallChunkEvent` survives.
    - [x] **AC1 text-message (default ON):** same shape with `TEXT_MESSAGE_CHUNK` (`messageId`/`role`/`delta`) → `TextMessageStart/Content/End`.
    - [x] **AC2 (false):** `HttpAgent(url: …, synthesizeChunks: false)` over the same body; assert the raw `ToolCallChunkEvent`/`TextMessageChunkEvent` instances pass through **unchanged** (subscribe `run()` directly — trap #3).
    - [x] **AC3 well-formedness (trap #8):** assert every synthesized `*StartEvent` id has a matching trailing `*EndEvent` id (matched-pair invariant the downstream `verifyStage` enforces) — without importing `verifyStage`.
    - [x] **Idempotency (trap #2 — the linchpin):** take the synthesized transport output, run it through `runPipeline` (via a `KoelClient.runRaw` over a stub agent, **or** assert that re-feeding the long-form list through `koel_core`'s exported `chunksStage` is identity); assert no second synthesis, no doubled `END`. [Source: pipeline.dart:29-36; chunks_stage.dart:144-148]
  - [x] Extend/clone [cancellation_test.dart](packages/koel_http/test/cancellation_test.dart) coverage (trap #6): a long-running `*_CHUNK` stream with default `synthesizeChunks: true`, cancelled mid-envelope, asserts `<50 ms` abort holds **and** no event (including a flushed `END`) emits after cancel. [Source: cancellation_test.dart; NFR-8]
  - [x] `dart:io` in **test** files is fine (web-safety governs `lib/` only — 4.1–4.7 precedent). Re-run under `--test-randomize-ordering-seed=random`. [Source: 4-7 Task 5]

- [x] **Task 4 — Quality gates (NO finalization gates this story)** (AC: all)
  - [x] `melos run build` (or `build_runner`) → no codegen drift (4.8 adds **no** freezed types — it reuses existing events). [Source: 4-7 Task 6]
  - [x] `melos run analyze` → **0 issues** workspace-wide (koel_core + koel_http both touched). [Source: NFR-13]
  - [x] `! grep -rn 'print(' packages/koel_http/lib packages/koel_core/lib` → no matches (architecture §4 no-`print`). [Source: architecture.md:587]
  - [x] `melos run test` → green workspace-wide, including the new koel_http suite, the unchanged 4.1–4.7 suites, **and** the unchanged koel_core `chunks_stage_test`/`pipeline_test` (proving the barrel export did not perturb the stage). [Source: tool/test]
  - [x] `melos run format:check` → clean. [Source: tool/format]
  - [x] **Do NOT** add koel_http's member `analysis_options.yaml` doc gate or the ≥90% coverage gate — those are **package-finalization** gates that land in epic-sealing **Story 4.10**. Write full dartdoc anyway. [Source: epic-4 overview; 4-7 Task 6]

### Review Findings

- [x] [Review][Patch] `_expectWellFormedPairs` does not matched-pair-validate reasoning envelopes — reasoning `Start`/`End` fall to `default: break` and are only count-asserted via `hasLength(1)`, so a misordered reasoning END/START would still pass; tool/text get stronger coverage than reasoning [packages/koel_http/test/chunk_synthesis_test.dart:39-88, 219-221] — FIXED: added `openReasoning` tracking (Start/Content/End matched-pair + no-unclosed assertion); analyze clean, all tests green.

> _Review (2026-06-01): 3 parallel adversarial layers (Blind Hunter, Edge Case Hunter, Acceptance Auditor) ran against baseline `31e558e`. All 3 ACs met, all 10 traps verified correct against source, no out-of-scope creep, all 25 affected tests pass. Product code is sound — the one finding above is a test-coverage strengthening (LOW), not a defect. 4 observations dismissed as non-blocking (AC2 freezed-equality dependency, idempotency `default:`-branch-only coverage, cancellation internal-import pattern, idempotency-via-`chunksStage` which is spec-sanctioned per Task 3's "**or**")._

## Dev Notes

### What this story is, in one paragraph

`HttpAgent.synthesizeChunks` finally does its job: when `true` (default), `HttpAgent.run()` normalizes the streaming `*_CHUNK` convenience shapes into canonical `START`/`CONTENT`/`END` triplets **at the transport**, so a raw `AbstractAgent` consumer and the Epic-5 backends see long form without a `KoelClient` pipeline. The synthesis logic is **not new** — it is `koel_core`'s existing, property-tested `chunksStage`, which you expose on the barrel and `.transform(...)` onto the parsed stream inside `_TransportTerminal`, gated by the (currently dropped) `synthesizeChunks` field, placed beneath `RetryInterceptor` (fresh state per reconnect) and inside `abortOnCancel` (cancel-safe). Scope is **two MODIFYs + one test file**: expose `chunksStage`, wire `synthesizeChunks`, test the wiring + idempotency. No new logic, no `koel_core` behavior change, no finalization gates.

### The layering: why two synthesizers is correct, not redundant (RESOLVED — trap #2)

```
                       synthesizeChunks: true (default)
HttpAgent.run() ──► _TransportTerminal: parse ─► chunksStage ─► abortOnCancel ─► interceptors ─► consumer
                                                  (synthesize)                                      │
                                                                                                    ▼  (if KoelClient)
                                                              runPipeline: chunksStage ─► verify ─► apply ─► transform
                                                                            (now a no-op pass-through)
```

- **Transport `chunksStage`** normalizes for the **raw** `AbstractAgent` consumer (layer-3, no pipeline) and Epic-5 backends.
- **Pipeline `chunksStage`** (unconditional, Story 2.11) normalizes for **any** agent — including non-`HttpAgent` agents that emit chunks, or an `HttpAgent` with `synthesizeChunks: false`.
- They compose **idempotently**: long-form events hit the pipeline stage's `default:` branch and pass through untouched. The reducer therefore *always* sees long form, by one path or the other. This is belt-and-suspenders by design, and the idempotency test (Task 3) is what keeps it honest. [Source: pipeline.dart:9-36; chunks_stage.dart:144-148]

### Why reuse, not reimplement (RESOLVED — trap #1)

| Approach | F.2 source of truth | Reasoning-chunk parity | Drift risk | Verdict |
| --- | --- | --- | --- | --- |
| **Expose + reuse koel_core `chunksStage` (CHOSEN)** | one | yes (free — trap #9) | none | additive 1.x export; ~5 LOC of transport wiring; property test already exists |
| Reimplement synthesis in koel_http | two (forks) | only if hand-copied | high — two copies of subtle envelope logic | rejected — textbook "reinventing wheels"; would re-port the whole `chunks_stage_test` suite |
| Make `runPipeline`'s `chunksStage` conditional + drive it from `synthesizeChunks` | one | yes | n/a | rejected — `runPipeline` is a pure `Stream→Stream` fn with no knowledge of the agent; the four-stage order is locked (2.11); the raw `AbstractAgent` consumer never reaches the pipeline |

[Source: chunks_stage.dart; pipeline.dart:9-36; CLAUDE.md; checklist "Reinventing wheels"]

### Placement & cancel-safety (RESOLVED — trap #4/#6)

Synthesis is the **innermost** transform in `_TransportTerminal.run`, **inside** `abortOnCancel`:
- **Beneath `RetryInterceptor`** (which is the outermost interceptor and re-subscribes the terminal per attempt — [http_agent.dart:108-123](packages/koel_http/lib/src/http_agent.dart)): each reconnect is a fresh SSE stream and gets a **fresh** `chunksStage` instance with empty envelope state. Synthesis above retry would span attempts and leak a half-open envelope across a reconnect. [Source: chunks_stage.dart:154-170]
- **Inside `abortOnCancel`**: `chunksStage` is `buildStage`-backed and cancellation-correct — on cancel it cancels upstream and does **not** run `onDone`, so no trailing `END` is flushed and no synthesized event escapes after the abort gate closes. The existing `<50 ms` NFR-8 guarantee is unaffected because `abortOnCancel` fires `response.abort` on its own `onCancel`, independent of whether cancel threads through the stage. [Source: stage_support.dart:53-76; http_agent.dart:207-216]

### Files you will touch

| Path | Action | Note |
| --- | --- | --- |
| [packages/koel_core/lib/koel_core.dart](packages/koel_core/lib/koel_core.dart) | MODIFY | `export 'src/pipeline/chunks_stage.dart';` + amend the barrel header carving out chunk synthesis as transport-reusable (trap #7). Additive 1.x API. |
| [packages/koel_http/lib/src/http_agent.dart](packages/koel_http/lib/src/http_agent.dart) | MODIFY | add `final bool synthesizeChunks;` (fix dropped param — trap #5); apply `.transform(chunksStage)` inside `abortOnCancel`, gated, in `_TransportTerminal.run` (trap #4/#6); refresh dartdoc. |
| `packages/koel_http/test/chunk_synthesis_test.dart` | NEW | AC1 (tool + text, default ON) + AC2 (false → raw) + AC3 well-formed pairs + idempotency (trap #8). |
| [packages/koel_http/test/cancellation_test.dart](packages/koel_http/test/cancellation_test.dart) | MODIFY (optional) | add a cancel-mid-chunk-envelope case proving no post-cancel `END` + `<50 ms` abort with synthesis ON (trap #6). |

### Library / framework requirements

- **Runtime:** `package:koel_core` (barrel) — the sealed `AgUiEvent` family (`ToolCallChunkEvent`/`TextMessageChunkEvent`/`ReasoningMessageChunkEvent` and their `Start`/`Content`/`Args`/`End` targets), `AbstractAgent`, `InterceptorChain`, `RunAgentInput`, **and now the newly-exported `chunksStage`**; `package:http`; SDK `dart:async` (`Stream.transform`). **No new third-party dependency.**
- **Dev:** `package:test ^1.25.0`; `koel_test` (`FixtureLoader`/synthesized fixtures, optional — inline wire lines suffice); `dart:io` (`HttpServer` loopback) in tests only.
- **Forbidden in `lib/`:** `dart:io`/`dart:html`/`package:web` in the synthesis path (it is a platform-neutral pure stream transform); any change to `chunksStage`'s behavior or the pipeline's four-stage order; reimplementing synthesis; **no `print`**. [Source: architecture.md:587; pipeline.dart:9-36; CLAUDE.md]

### Project Structure Notes

- Touches **two** packages: an additive export in `koel_core`'s barrel (the one 1.x surface change) and the transport wiring + tests in `koel_http`. SDK constraints unchanged; no member `analysis_options.yaml` (gates are 4.10's).
- This is the **first Epic-4 story to change `koel_core`** — and it is deliberately the minimum: one export line + a header-comment amendment, no behavior change. The `chunks_stage_test`/`pipeline_test` must stay green to prove the stage itself is untouched.
- No new freezed types, no new fixture required.

### Previous Story Intelligence

- **Story 4.7** kept `koel_core` untouched and added no finalization gates; 4.8 keeps the finalization-gate discipline but **does** make a minimal, additive `koel_core` change (the one exception, forced by the reuse-not-duplicate principle — trap #1/#7). It reused 4.7's `final class … implements Interceptor` and `.map` discipline context but adds no interceptor here. [Source: 4-7 Dev Notes]
- **Story 4.4** established that `RetryInterceptor` is auto-prepended outermost and re-runs the inner terminal per attempt ([http_agent.dart:108-123](packages/koel_http/lib/src/http_agent.dart)) — the reason synthesis must live in the terminal (trap #4). [Source: http_agent.dart:105-129]
- **Story 4.3** built `abortOnCancel` around the `async*` parser; 4.8 slots synthesis between the parser and that guard, relying on `buildStage`'s cancel-correctness so the guarantee holds (trap #6). [Source: http_agent.dart:207-216; cancellation.dart]
- **Story 2.11** built `chunksStage`/`verifyStage`/`runPipeline` with the locked chunks→verify→apply→transform order and the property tests 4.8 leans on (trap #8). The chunk event dartdocs ([tool_call_events.dart:137-142](packages/koel_core/lib/src/event/tool_call_events.dart), [text_message_events.dart:91-96](packages/koel_core/lib/src/event/text_message_events.dart)) already point to `chunksStage` as the expander — 4.8 honors that by reusing it. [Source: pipeline.dart; chunks_stage_test.dart; tool_call_events.dart:137-142]
- **House style** (3.x, 4.1–4.7): `final`/`sealed` where possible, exhaustive dartdoc, table-driven `package:test`, tight change sets, composition over config, pure transforms over hidden state, no finalization gates until the epic-sealing story. [Source: `git log`; 4-7 :193]

### Latest Tech Information

- **`Stream<T>.transform(StreamTransformer<T,R>)`** (`dart:async`) is the exact composition primitive — `chunksStage` is a `StreamTransformer<AgUiEvent, AgUiEvent>` built via `StreamTransformer.fromBind`, single-subscription, backpressure- and cancel-correct ([stage_support.dart:42-79](packages/koel_core/lib/src/pipeline/stage_support.dart)). Applying it inside an `async*` terminal is fine — `transform` on a live broadcast-free single-subscription stream preserves order and pause/resume. No new SDK feature needed. [Source: stage_support.dart:42-79]
- **No `dart_apitool` regression:** the only API change is the additive `chunksStage` export on `koel_core` (no published baseline yet — Story 9.3). `koel_http` gains no public symbol (the field `synthesizeChunks` already existed on the public ctor). [Source: 4-7 Task 6; api-diff.yml]
- **No new dependency, no codegen:** 4.8 reuses existing freezed events; `melos run build` regenerates nothing new. [Source: 4-7 Debug Log]

### References

- Story spec (ACs): [epic-4 Story 4.8](_bmad-output/planning-artifacts/epics/epic-4-http-transport-koelhttp.md) (lines 192-213); chunk-synthesis rules: [addendum.md §F.2](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#L640-L648); `synthesizeChunks` flag tie-in: [addendum.md:521,644](_bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md).
- The synthesizer being reused: [chunks_stage.dart](packages/koel_core/lib/src/pipeline/chunks_stage.dart); its property tests: [chunks_stage_test.dart](packages/koel_core/test/pipeline/chunks_stage_test.dart), [pipeline_test.dart](packages/koel_core/test/pipeline/pipeline_test.dart).
- Pipeline composition + locked order: [pipeline.dart](packages/koel_core/lib/src/pipeline/pipeline.dart); stage machinery + cancel-correctness: [stage_support.dart](packages/koel_core/lib/src/pipeline/stage_support.dart); downstream validator: [verify_stage.dart](packages/koel_core/lib/src/pipeline/verify_stage.dart).
- Transport seam to modify: [http_agent.dart:45-217](packages/koel_http/lib/src/http_agent.dart); abort watchdog: [connection/cancellation.dart](packages/koel_http/lib/src/connection/cancellation.dart).
- Barrel to amend: [koel_core.dart:1-17,60-64](packages/koel_core/lib/koel_core.dart).
- Event field contracts: [tool_call_events.dart](packages/koel_core/lib/src/event/tool_call_events.dart), [text_message_events.dart](packages/koel_core/lib/src/event/text_message_events.dart).
- Test harness exemplars (`_sseServer`, `_fixturePayloads`, loopback replay): [http_agent_test.dart:17-95](packages/koel_http/test/http_agent_test.dart); cancellation pattern: [cancellation_test.dart](packages/koel_http/test/cancellation_test.dart).
- Fixtures (chunk lines are empty/all-null — trap #10): [all_event_types.jsonl](packages/koel_test/lib/src/fixtures/synthesized/all_event_types.jsonl).

### Design decisions (RESOLVED — AC/architecture-forced, not open)

1. **Reuse `koel_core`'s `chunksStage`; do not reimplement.** Single F.2 source of truth; synthesis correctness already property-tested. [trap #1/#8]
2. **Expose `chunksStage` on the koel_core barrel (additive 1.x), and ONLY that stage.** verify/apply/transform stay internal. [trap #7]
3. **Synthesis is layered with the pipeline's unconditional `chunksStage`; the double-application is idempotent and must be tested.** [trap #2]
4. **`synthesizeChunks` governs the transport's own output stream only** — `KoelClient` consumers are normalized by the pipeline regardless. [trap #3]
5. **Synthesis lives innermost in `_TransportTerminal.run`, beneath `RetryInterceptor` (fresh state per reconnect) and inside `abortOnCancel` (cancel-safe).** [trap #4/#6]
6. **Add the `final bool synthesizeChunks;` field — the 4.2 ctor currently drops the param.** [trap #5]
7. **Reasoning chunks are normalized too (superset of AC1) — keep it.** [trap #9]
8. **No pipeline-order change, no new dependency, no new freezed type, no new fixture, no finalization gates.** [out-of-scope]

These are baked in — implement them; no confirmation gate (except the single barrel-exposure judgment surfaced to the user separately).

## Dev Agent Record

### Context Reference

<!-- Path(s) to story context will be added here by context workflow -->

### Agent Model Used

claude-opus-4-8 (via `/agent-flutter-engineer` specialist, implement mode).

### Debug Log References

- `dart analyze` per package: 0 issues workspace-wide (14 packages).
- `dart test` koel_http: 88 passing (`--test-randomize-ordering-seed=random`); koel_core: 575 passing — proves the barrel export did not perturb `chunks_stage`/`pipeline`.
- `build_runner build` (koel_core): wrote 0 outputs — no codegen drift (no new freezed types).
- `tool/format.sh check`: clean (130 files, 0 changed).
- No-`print` gate: clean across `koel_http/lib` + `koel_core/lib`.

### Completion Notes List

- **Reused, did not reimplement (trap #1).** Synthesis is `koel_core`'s existing property-tested `chunksStage`, exposed additively on the barrel and `.transform(chunksStage)`-ed onto the parsed stream in `_TransportTerminal.run`. One implementation, two call sites (transport + pipeline). No envelope logic forked.
- **Fixed the dropped-param bug (trap #5).** The 4.2 ctor accepted `synthesizeChunks` but never stored it; added `final bool synthesizeChunks;` via `this.synthesizeChunks` shorthand. Refreshed the ctor + field dartdoc to describe the now-live behavior and that it governs the transport's own output stream only (trap #3).
- **Placement (trap #4/#6).** Synthesis sits innermost in the terminal, beneath `RetryInterceptor` (fresh envelope state per reconnect) and inside `abortOnCancel` (no synthesized event or trailing `END` escapes after cancel — `buildStage` cancels upstream without running `onDone`). Proven by the new cancellation trap-#6 test: `<50 ms` abort holds with synthesis on and no `ToolCallEndEvent` is flushed post-cancel.
- **Idempotency proven (trap #2).** New test re-feeds the synthesized transport output through the exported `chunksStage` and asserts identity — long-form events hit the `default:` pass-through, so transport synthesis and the pipeline's unconditional `chunksStage` coexist with no doubled `END`.
- **Reasoning-chunk superset kept (trap #9).** Reuse normalizes `REASONING_MESSAGE_CHUNK` too; the AC3 well-formedness test asserts it.
- **One pre-existing test adjusted, not a regression.** `http_agent_test.dart`'s faithful-replay test (Story 4.2) silently relied on `synthesizeChunks` being a no-op; with the default now real it would drop the fixture's all-null (un-addressable) chunk lines and shift the list. Pinned that test to `synthesizeChunks: false` (its intent is parser/transport fidelity, orthogonal to synthesis) — synthesis itself is covered by the new suite.
- **Barrel exposure judgment (the one surfaced decision).** Added exactly one export — `chunksStage` — and amended the barrel header to carve it out as transport-reusable while keeping `verify`/`apply`/`transform` internal. Additive 1.x API change; no `dart_apitool` baseline exists yet (Story 9.3), so no API-diff gate fired.

### File List

- `packages/koel_core/lib/koel_core.dart` (MODIFY) — additive `export 'src/pipeline/chunks_stage.dart';` + barrel-header carve-out for chunk synthesis.
- `packages/koel_http/lib/src/http_agent.dart` (MODIFY) — `final bool synthesizeChunks;` (fix dropped param); gated `.transform(chunksStage)` inside `abortOnCancel` in `_TransportTerminal.run`; refreshed dartdoc.
- `packages/koel_http/test/chunk_synthesis_test.dart` (NEW) — AC1 (tool + text, default on), AC2 (false → raw passthrough), AC3 well-formed START/END pairs + reasoning superset, idempotency.
- `packages/koel_http/test/cancellation_test.dart` (MODIFY) — `_longRunningChunkServer` + trap-#6 test (cancel mid-envelope: `<50 ms` abort, no flushed `END`).
- `packages/koel_http/test/http_agent_test.dart` (MODIFY) — pinned the faithful-replay test to `synthesizeChunks: false` (default synthesis is now real).

## Change Log

| Date | Change |
| --- | --- |
| 2026-06-01 | Story 4.8 drafted — chunk synthesis via reuse of koel_core `chunksStage` (exposed additively on the barrel) wired into `HttpAgent.synthesizeChunks` at the transport. Status → ready-for-dev. |
| 2026-06-01 | Story 4.8 implemented — exposed `chunksStage` on koel_core's barrel (deliberate additive 1.x contract addition); stored + applied `synthesizeChunks` (default on) in `_TransportTerminal`, beneath retry and inside the abort gate; added `chunk_synthesis_test` + cancellation trap-#6 case; pinned the 4.2 faithful-replay test to synthesis-off. All gates green workspace-wide. Status → review. |
