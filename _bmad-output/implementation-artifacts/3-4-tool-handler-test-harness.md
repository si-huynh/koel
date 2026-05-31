---
baseline_commit: 5a15a5f
---

# Story 3.4: `ToolHandlerTestHarness` fluent builder

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this story ships a **`koel_test`-only** fluent test harness so a downstream test exercises a tool handler in ~5 lines: register → invoke → assert on the result. It touches `.dart` files, designs a new public API, and orchestrates a real `KoelClient` run, so **invoke `/agent-flutter-engineer` before producing any code** (per CLAUDE.md). The whole footprint is **one new lib file + one barrel line + one new test file** — and crucially, **ZERO `koel_core` change** (unlike 3.3, the kernel already exports everything the harness consumes). Six things are load-bearing, and the first four are *non-obvious traps* that will sink a naïve reading of the AC:
>
> 1. **There is NO `ToolHandler` type and NO tool-execution path in `koel_core` — you author the handler machinery here, from scratch.** The kernel *transports* tool-call events (`ToolCallStartEvent`/`ToolCallArgsEvent`/`ToolCallEndEvent`/`ToolCallResultEvent`) and *folds* them into `ChatState.pendingToolCalls` — it **never invokes a handler**. There is no `registerTool`, no `ToolRegistry`, no `typedef ToolHandler` anywhere in `packages/koel_core/lib` (grep-verified). So `ToolHandlerTestHarness` defines its **own** `typedef ToolHandler` and runs the handler **itself**. **Do NOT** hunt for a `koel_core` `ToolHandler` to import (there isn't one), and **do NOT** add one to `koel_core` (no kernel code consumes it — that is speculative surface, YAGNI; 3.3 added a `koel_core` seam *only* because barrel discipline made fixture decoding literally impossible otherwise — no such forcing function exists here). See §"The harness mechanism".
> 2. **`ToolCallResultEvent` has a `content` String field — NOT a `payload` getter and NOT a `value` key.** AC2 writes `expect(result.payload['value'], equals(5))`, but the real type (`tool_call_events.dart:102-135`) is `ToolCallResultEvent({required String messageId, required String toolCallId, required String content, String? role})`. A real result `content` is a free string (the shipped `tool_call_basic.jsonl` carries `content: "ok"`). The AC prose **predates the finalized event shape** — same class of gap 3.3 hit with `agent.run(input)`/`chatSession` (it mapped them to the real `session.send`/`session.state`). **RESOLVED:** the harness encodes the handler's return as `content = jsonEncode({'value': <return>})`, and AC2's `result.payload['value']` is realized as `(jsonDecode(result.content) as Map<String, dynamic>)['value']`. **Do NOT** add a `payload` getter/extension to `koel_core`'s `ToolCallResultEvent` — a global extension that `jsonDecode`s `content` would throw on every real `content` that is a bare string (`"ok"`), a footgun. See §"Result encoding — RESOLVED".
> 3. **"Runs the handler under a `MockAgent`" cannot mean the replay invokes the handler — a `MockAgent` timeline is frozen before `run()`.** `MockAgent` replays a *fixed* event list verbatim (`mock_agent.dart:30-37,64-72`); it cannot compute a handler result mid-stream, and `AgentSubscriber.onToolCall` carries only the `START` (no args — args ride a separate `TOOL_CALL_ARGS` event with no callback). So the handler is invoked **by the harness** (which already holds `args` from `invoke(name, args)`); the `MockAgent` provides the **observable tool-call run** the result threads through. **RESOLVED:** `invoke` computes the result, assembles a canonical `RUN_STARTED → TOOL_CALL_START → TOOL_CALL_ARGS → TOOL_CALL_END → TOOL_CALL_RESULT → RUN_FINISHED` sequence, and replays it through a real `KoelClient` so `AgentSubscriber` dispatch is exercised end-to-end. See §"The harness mechanism".
> 4. **`ToolReplayContext` does NOT exist and you CANNOT reference it — `koel_test` is pure Dart, `ToolReplayContext` is a `koel_flutter` `InheritedWidget` (Story 6.6).** AC3's handler "checks `ToolReplayContext.isReplaying`," but that type lands in Epic 6 and pulling Flutter into a framework-free package is a regression 3.2/3.3 forbade. **RESOLVED:** the harness exposes an instance flag `bool get isReplaying`; `invoke(..., isReplaying: true)` sets it around the handler call; a replay-aware test handler **closes over the harness** and reads `harness.isReplaying` (the **stub stand-in** for the future `ToolReplayContext.isReplaying`), skipping its side effect while still returning the recorded value — so the `ToolCallResultEvent` still emits. **Full FR-F7 validation defers to Epic 8 Story 8.7** wired against the 6.6 type. **Do NOT** add a Flutter dep, and **do NOT** ship a stub class literally named `ToolReplayContext` (it would shadow/pre-empt the real 6.6 type and mislead). See §"Replay stub — RESOLVED".
> 5. **Unknown tool name → `ArgumentError` (programmer error), not `KoelError`** — with the registered names enumerated, mirroring 3.3's `FixtureLoader` error contract exactly. A typo'd handler name is a test-authoring mistake, the textbook `ArgumentError` case. See §"Error contract".
> 6. **No new dependency anywhere; zero `koel_core` change.** The harness uses `dart:async` (`FutureOr`) + `dart:convert` (`jsonEncode`/`jsonDecode`) + `koel_core`'s public barrel (`KoelClient`, `AgentSubscriber`, `ToolCall*` events, `RunAgentInput`, `AbstractAgent`) + `koel_test`'s own `MockAgent`. No `freezed`, no `build_runner`, no Flutter.

## Story

As a Flutter/Dart developer,
I want a fluent `ToolHandlerTestHarness` that registers tool handlers, drives them through a `MockAgent`, and asserts on tool args / responses / replay behavior in ~5 lines per case,
so that downstream consumers test their tool handlers without rebuilding the harness per FR-G3.

## Acceptance Criteria

Verbatim from [epic-3 Story 3.4](../planning-artifacts/epics/epic-3-test-harness-conformance-koeltest.md):

> **Cross-epic anchor.** This story exercises the replay path via a **stub flag** because `ToolReplayContext` (the real `InheritedWidget` type that replay-aware handlers consult) does not exist until Epic 6 Story 6.6, and end-to-end replay semantics complete in Epic 8 Story 8.7. A green Story 3.4 establishes the harness contract; **full FR-F7 contract validation defers to Story 8.7** (DevTools replay path + recorded-result stubbing) wired against the Story 6.6 type.

1. **Given** `koel_test/lib/src/tool_handler_test_harness.dart`, **When** I inspect the class, **Then** it exposes `ToolHandlerTestHarness register(String name, ToolHandler handler)` returning `this` for chaining, **And** `Future<ToolCallResultEvent> invoke(String name, Map<String, dynamic> args)` runs the handler under a `MockAgent` and returns the resulting tool-call result event.

2. **Given** a downstream test:
   ```dart
   final result = await ToolHandlerTestHarness()
     .register('addTwo', (args) => args['a'] + args['b'])
     .invoke('addTwo', {'a': 2, 'b': 3});
   expect(result.payload['value'], equals(5));
   ```
   **When** the test runs, **Then** it completes in < 100 ms, **And** the handler invocation is observable via an attached `AgentSubscriber`.

3. **Given** a replay-aware handler that checks `ToolReplayContext.isReplaying` (the type is defined in Story 6.6 — Epic 6; this Epic 3 story ships only the harness scaffold and exercises the replay path via a stub flag), **When** the harness simulates a replay scenario with the stub `isReplaying: true`, **Then** the handler's side effect is skipped while the recorded result still emits (full end-to-end replay verified in Epic 8 Story 8.7).

> **AC-vs-reality mappings (RESOLVED, do not re-litigate — implement):**
> - AC2 `result.payload['value']` → **`(jsonDecode(result.content) as Map<String, dynamic>)['value']`** (the real `ToolCallResultEvent` exposes `content: String`, not `payload`; the harness encodes the return as `jsonEncode({'value': <return>})` — trap #2).
> - AC3 `ToolReplayContext.isReplaying` → **`harness.isReplaying`** (the harness's instance stub flag; the real Flutter type is unavailable in pure-Dart `koel_test` — trap #4).

## Tasks / Subtasks

- [x] **Task 0 — Read the real surfaces before writing a line** (AC: all — skipping this is how the wrong contract gets built)
  - [x] Read `packages/koel_core/lib/src/event/tool_call_events.dart` — confirm `ToolCallResultEvent({required String messageId, required String toolCallId, required String content, String? role})` (`content` is a String; **no** `payload`/`value`). Confirm `ToolCallStartEvent({required String toolCallId, required String toolCallName, String? parentMessageId})`, `ToolCallArgsEvent({required String toolCallId, required String delta})`, `ToolCallEndEvent({required String toolCallId})`. [Source: tool_call_events.dart:9-135]
  - [x] Read `packages/koel_core/lib/src/agent/agent_subscriber.dart` — confirm `onToolCall(ToolCallStartEvent start, ToolCallEndEvent? end)` (end is always `null` under per-event firing) and `onToolResult(ToolCallResultEvent e)`. **Extend, do not implement** `AgentSubscriber` (empty default bodies; implementing forfeits forward-compat). [Source: agent_subscriber.dart:42-71]
  - [x] Read `packages/koel_core/lib/src/client/koel_client.dart` — confirm `KoelClient({required AbstractAgent agent, List<AgentSubscriber>? subscribers, ...})`, the mutable `subscribers` list, `runRaw(RunAgentInput) → Stream<AgUiEvent>` (which calls `_notify` per event when listened — the path that fires subscribers), and `dispose()`. [Source: koel_client.dart:62-83,105-108,140-143,165-172,192-227]
  - [x] Read `packages/koel_test/lib/src/mock_agent.dart` — confirm `MockAgent.fromEvents(List<AgUiEvent>, {Duration delay})` (verbatim replay, ignores input). The harness builds its timeline and wraps with `fromEvents` — **do not** re-implement replay. [Source: mock_agent.dart:30-37,64-72]
  - [x] Confirm `RunAgentInput({required String threadId, required String runId, ...})` — only `threadId`/`runId` are required; everything else defaults. The harness builds a minimal input (the `MockAgent` ignores it anyway). [Source: run_agent_input.dart:31-40]
  - [x] Grep-confirm there is **no** `ToolHandler`/`registerTool`/`ToolRegistry` in `packages/koel_core/lib` — so the typedef is yours to define (trap #1). [Source: trap #1]

- [x] **Task 1 — `ToolHandler` typedef (koel_test-local)** (AC: #1, #2)
  - [x] In the new file (Task 2), declare `typedef ToolHandler = FutureOr<Object?> Function(Map<String, dynamic> args);` (`dart:async` for `FutureOr`). `FutureOr` lets a handler be sync (`(args) => args['a'] + args['b']`, AC2) **or** async (`(args) async => await something(args)`); `Object?` is the un-encoded return the harness wraps into the result `content`. Dartdoc it as the koel_test test-handler contract (one input map → a JSON-encodable return; replay-awareness is read from `harness.isReplaying`). [Source: AC2 handler shape; trap #1]
  - [x] **Do NOT** add this typedef to `koel_core` — no kernel code consumes a handler; tool execution is a downstream/Flutter concern (Epic 6 frontend tools own any canonical kernel `ToolHandler` decision). [Source: CLAUDE.md "no just-in-case parameters / API surface is a one-way door"; trap #1]

- [x] **Task 2 — `ToolHandlerTestHarness` skeleton + `register`** (AC: #1)
  - [x] New file `packages/koel_test/lib/src/tool_handler_test_harness.dart` (architecture-pinned: `tool_handler_test_harness.dart # F-G3`, architecture :965). Import **only** the public barrel `package:koel_core/koel_core.dart` + `package:koel_test/...`'s own `mock_agent.dart` (or a relative `mock_agent.dart` import) + `dart:async` + `dart:convert`. **No `src/` import into koel_core, no Flutter.** [Source: architecture §6 :684-685; 3.1/3.3 barrel discipline]
  - [x] Declare a **plain `final class ToolHandlerTestHarness`** with a public **default (unnamed) generative constructor** — AC2 constructs it as `ToolHandlerTestHarness()`. Hold `final Map<String, ToolHandler> _handlers = {};`. [Source: AC2 `ToolHandlerTestHarness()`]
  - [x] `ToolHandlerTestHarness register(String name, ToolHandler handler)` → stores `_handlers[name] = handler`; returns `this` for chaining (AC1). A duplicate `name` overwrites (last registration wins — a harness is per-test, reuse is the author's; no need to throw). [Source: AC1 "returning this for chaining"]

- [x] **Task 3 — Observability seam: `AgentSubscriber` attachment** (AC: #2 "observable via an attached AgentSubscriber")
  - [x] Add a fluent `ToolHandlerTestHarness observe(AgentSubscriber subscriber)` (symmetric with `register`, returns `this`) storing into `final List<AgentSubscriber> _observers = [];`. On each `invoke`, these are attached to the internal `KoelClient`'s `subscribers` so the test's subscriber sees `onToolCall(start, null)` + `onToolResult(result)` fire through the **real** dispatch path. [Source: AC2; koel_client.dart:192-227]
  - [x] **Why a real `KoelClient` and not a hand-rolled notify:** AC2 demands observability *via `AgentSubscriber`*, and the only sanctioned dispatch is `KoelClient._notify`→`_dispatch` (post-pipeline, isolation contract). Driving the assembled `MockAgent` through `runRaw` exercises that path verbatim — high fidelity, not a fake. [Source: koel_client.dart:140-143,177-227; architecture §"Integration points" :1062-1087]

- [x] **Task 4 — `invoke`: the core (compute → assemble → replay → return)** (AC: #1, #2)
  - [x] `Future<ToolCallResultEvent> invoke(String name, Map<String, dynamic> args, {bool isReplaying = false})`:
    1. **Look up** `_handlers[name]`; if absent → throw the enumerated `ArgumentError` (Task 6). [Source: AC implicit; 3.3 error contract]
    2. **Allocate deterministic ids** from an instance counter `int _callSeq` (no `static` — FR-D3): `final n = _callSeq++; final toolCallId = 'harness-call-$n'; final messageId = 'harness-result-$n';`. [Source: FR-D3 "no static mutable state"; koel_client.dart:113-116 identity-derived ids precedent]
    3. **Set the replay flag, invoke the handler, reset:** `_isReplaying = isReplaying; final Object? raw; try { raw = await handler(args); } finally { _isReplaying = false; }`. `await` accepts both sync and `Future` returns (`FutureOr`). The handler reads `harness.isReplaying` to no-op side effects under replay (Task 5). [Source: trap #3/#4; AC3]
    4. **Encode the result:** `final content = jsonEncode({'value': raw});` — the `{'value': …}` envelope is what makes AC2's `['value']` accessor real (trap #2). A non-JSON-encodable `raw` surfaces `jsonEncode`'s error (a test-authoring mistake — let it throw loud). [Source: trap #2]
    5. **Assemble the canonical run** (a `List<AgUiEvent>`): `RunStartedEvent(threadId, runId)` → `ToolCallStartEvent(toolCallId: toolCallId, toolCallName: name)` → `ToolCallArgsEvent(toolCallId: toolCallId, delta: jsonEncode(args))` → `ToolCallEndEvent(toolCallId: toolCallId)` → `ToolCallResultEvent(messageId: messageId, toolCallId: toolCallId, content: content)` → `RunFinishedEvent(threadId, runId)`. This is the exact well-formed shape the shipped `tool_call_basic.jsonl` uses (`START→ARGS→END→RESULT`); the verify stage tracks `START`/`END` pairing and lets `RESULT` pass — no `ProtocolError`. [Source: tool_call_basic.jsonl; verify-stage tool rules]
    6. **Replay through a real client:** build `final client = KoelClient(agent: MockAgent.fromEvents(timeline), subscribers: [..._observers]);` then drain the post-pipeline stream to a list: `final events = await client.runRaw(input).toList();` (a minimal `RunAgentInput(threadId: …, runId: …)` — the `MockAgent` ignores it). `runRaw` fires every observer per event as it drains (AC2 observability). Wrap in `try { … } finally { client.dispose(); }`. [Source: koel_client.dart:140-143,165-172; mock_agent.dart:64-72]
    7. **Return the post-pipeline result event:** `return events.whereType<ToolCallResultEvent>().single;` — returning the event that actually flowed through verify/apply/dispatch (not a bypassed local), so the returned object and the one the observer saw are the same. [Source: AC1 "returns the resulting tool-call result event"]
  - [x] Keep `invoke` total/clean: no `catch (_) {}` swallows; `client.dispose()` in `finally`. Completion is well under the AC2 100 ms budget (zero-delay `MockAgent` + in-memory pipeline). [Source: AC2; CLAUDE.md "explicit lifecycle, no vestigial code"]

- [x] **Task 5 — Replay stub flag** (AC: #3)
  - [x] Add `bool _isReplaying = false;` and a public `bool get isReplaying => _isReplaying;`. Dartdoc it as the **stub stand-in for `ToolReplayContext.isReplaying`** (the real `InheritedWidget` arrives in Epic 6 Story 6.6; full FR-F7 validation in Epic 8 Story 8.7). A replay-aware test handler closes over the harness and reads it:
    ```dart
    var sideEffects = 0;
    final harness = ToolHandlerTestHarness()
      ..register('sendEmail', (args) {
        if (!harness.isReplaying) sideEffects++; // skipped under replay
        return {'sent': true};                   // recorded result still returned
      });
    await harness.invoke('sendEmail', {'to': 'x'}, isReplaying: true);
    // sideEffects == 0, yet the ToolCallResultEvent still emits.
    ```
  - [x] **Do NOT** name any symbol `ToolReplayContext` or add a Flutter dep — the stub is *only* the harness's `isReplaying` flag (trap #4). The flag is set by `invoke`'s `isReplaying:` param around the handler call (Task 4 step 3) and reset in `finally`. [Source: trap #4; cross-epic anchor; FR-F7 :60]

- [x] **Task 6 — Error contract: unknown tool name → enumerated `ArgumentError`** (AC: #1 robustness)
  - [x] In `invoke`, when `name` is not registered, throw **`ArgumentError`** (NOT `KoelError`/`RunErrorEvent`) enumerating the registered names — e.g. `ArgumentError.value(name, 'name', 'No handler registered for "$name". Registered: ${(_handlers.keys.toList()..sort()).join(', ')}')`. A typo'd name is a programmer error, exactly as 3.3's `FixtureLoader` treats an unknown fixture. The throw is async (inside the `Future`), asserted with `throwsArgumentError`. [Source: 3.3 §"Error contract"; AC3 precedent of ArgumentError for authoring mistakes]

- [x] **Task 7 — Export from the barrel** (AC: #1)
  - [x] In `packages/koel_test/lib/koel_test.dart` (MODIFY), add `export 'src/tool_handler_test_harness.dart';` — the **third** export (after `mock_agent.dart`, `fixture_loader.dart`). This surfaces both `ToolHandlerTestHarness` and the `ToolHandler` typedef. **Do NOT** re-export `koel_core` (only the meta-package re-exports). [Source: koel_test.dart:7-11; architecture :980]

- [x] **Task 8 — Tests** (AC: #1, #2, #3)
  - [x] New `packages/koel_test/test/tool_handler_test_harness_test.dart` (`package:test` only; one top-level `group(ToolHandlerTestHarness, () {...})`; source-mirror naming — convention §6 :654-664). [Source: architecture §6 :654-664]
  - [x] **AC1/AC2 (the literal AC example, mapped):**
    ```dart
    final result = await ToolHandlerTestHarness()
      .register('addTwo', (args) => args['a'] + args['b'])
      .invoke('addTwo', {'a': 2, 'b': 3});
    expect(result, isA<ToolCallResultEvent>());
    expect((jsonDecode(result.content) as Map<String, dynamic>)['value'], 5);
    ```
    Assert `result.toolCallId`/`messageId` are the harness-generated ids (non-empty). Optionally wrap in a `Stopwatch` and assert `< 100ms` (or rely on the test's own fast completion). [Source: AC2; trap #2 mapping]
  - [x] **AC2 (observability):** attach a recording `AgentSubscriber` via `.observe(...)` that captures `onToolCall`/`onToolResult`; after `invoke`, assert the subscriber saw the `ToolCallStartEvent` (name `addTwo`) and the `ToolCallResultEvent`. This proves the invocation flows through real `KoelClient` dispatch, not a bypass. [Source: AC2 "observable via an attached AgentSubscriber"]
  - [x] **AC3 (replay stub):** register a handler that increments a side-effect counter only `if (!harness.isReplaying)` and returns a recorded map; `invoke(..., isReplaying: true)`; assert the counter stayed 0 **and** the returned `ToolCallResultEvent`'s decoded `content` carries the recorded value (the result still emits). Add the mirror case `isReplaying: false` → counter incremented (proves the gate is real, not a no-op). [Source: AC3]
  - [x] **Async handler:** register `(args) async => 7`; assert `jsonDecode(result.content)['value'] == 7` (proves `FutureOr` + `await handler(...)`). [Source: Task 1 FutureOr]
  - [x] **Unknown name:** `expect(ToolHandlerTestHarness().invoke('nope', const {}), throwsArgumentError)` and assert the message enumerates registered names (e.g. via `throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('addTwo')))` on a harness that registered `addTwo`). [Source: Task 6; AC3 error-class precedent]

- [x] **Task 9 — Quality gates** (AC: all)
  - [x] `melos run analyze` → **0 issues** workspace-wide. The new public symbols (`ToolHandlerTestHarness`, `ToolHandler`, `isReplaying`, `register`/`observe`/`invoke`) each need a dartdoc if `koel_test` carries a member doc-gate — **note:** the member doc-gate `analysis_options.yaml` for `koel_test` is **Story 3.5's** epic-sealing AC (not yet present), but write dartdocs anyway (every public symbol is documented per convention §6 / PRD §13 D-2). [Source: NFR-13; architecture §6 :632-643; epic-3 3.5]
  - [x] `melos run test` → green workspace-wide, including the new `tool_handler_test_harness_test.dart` (alongside `mock_agent_test.dart`, `fixtures_test.dart`, `fixture_loader_test.dart`). [Source: 3.1/3.2/3.3 melos test wiring]
  - [x] `dart format --set-exit-if-changed .` (via `melos run format:check`) → clean. [Source: convention; tool/format.sh]
  - [x] **Do NOT** add `koel_test`'s ≥80% coverage gate or a member `analysis_options.yaml` doc-gate, and **do NOT** build `ConformanceRunner`/`ConformanceReport`/`CONFORMANCE.md`/`tool/capture_fixtures.dart` — all **Story 3.5** (the epic sealer). 3.4 needs only `analyze`/`test`/`format:check` green. [Source: epic-3 3.5; 3.1/3.2/3.3 "do not add finalization gates"]
  - [x] Confirm the change set is **exactly**: 1 new `koel_test` lib file + 1 barrel-export line + 1 new `koel_test` test file. **No `koel_core` change. No new dependency anywhere.** [Source: §"Files you will touch"]

## Dev Notes

### What this story is, in one paragraph
The **tool-handler ergonomics layer** of `koel_test`. 3.1 shipped `MockAgent`; 3.2 the fixtures; 3.3 the loader/decoder. This story adds `ToolHandlerTestHarness`: a fluent, `koel_test`-only builder that lets a downstream test register a tool handler and assert on its result in ~5 lines. The **one hard truth** is that the kernel has no handler machinery at all — `koel_core` transports and folds tool-call *events* but never invokes a handler — so the harness **owns** the `typedef ToolHandler` and runs the handler itself, then assembles a canonical tool-call run and replays it through a real `KoelClient` so `AgentSubscriber` observability is exercised for real. Scope is exactly: the typedef, the harness (`register`/`observe`/`invoke`/`isReplaying`), the barrel export, and one test file. **Not** `ConformanceRunner`/`ConformanceReport`/coverage gate (3.5), **not** any `koel_core` change, **not** any new dependency. [Source: epic-3 3.4 :77-105; trap #1]

### The harness mechanism (the heart of this story) — RESOLVED
The AC phrase "runs the handler under a `MockAgent`" is satisfiable only one way, because of two hard constraints:
- **The kernel never invokes handlers.** `koel_core`'s pipeline synthesizes `START`/`ARGS`/`END`, validates them (verify stage), and folds them into `ChatState.pendingToolCalls` — there is no code path that calls a registered function and emits a `ToolCallResultEvent`. (Grep: no `ToolHandler`/`registerTool`/`ToolRegistry` in `packages/koel_core/lib`.)
- **A `MockAgent` timeline is frozen before `run()`.** It replays a fixed list verbatim and ignores its input; it cannot compute a result mid-stream. And `AgentSubscriber.onToolCall` carries only the `START` (args ride a separate `TOOL_CALL_ARGS` event with no callback), so you cannot reconstruct the handler's input from the subscriber either.

Therefore the **harness** is the handler runner. `invoke(name, args)` already holds `args`, so it: (1) invokes the handler → a return value; (2) JSON-encodes it into a `ToolCallResultEvent.content`; (3) assembles the canonical `RUN_STARTED → TOOL_CALL_START → TOOL_CALL_ARGS → TOOL_CALL_END → TOOL_CALL_RESULT → RUN_FINISHED` run; (4) replays that run through a real `KoelClient(agent: MockAgent.fromEvents(...), subscribers: observers)` and drains `runRaw(...)`, firing `onToolCall`/`onToolResult` for any attached observer; (5) returns the post-pipeline `ToolCallResultEvent`. The `MockAgent` + `KoelClient` + four-stage pipeline + subscriber dispatch are all **real** koel machinery — the harness is glue, not a fake. This is the only reading consistent with the primitives, and it is what AC1's "runs the handler under a `MockAgent` and returns the resulting tool-call result event" describes. [Source: koel_client.dart:140-143,192-227; mock_agent.dart:30-37,64-72; agent_subscriber.dart:65-71]

### Result encoding — RESOLVED
`ToolCallResultEvent` exposes **`content: String`**, never a `payload` getter or a `value` key (`tool_call_events.dart:102-135`; the shipped `tool_call_basic.jsonl` result carries `content: "ok"`, a bare string). AC2's `result.payload['value']` is **aspirational prose written before the event shape was finalized** — the same kind of gap 3.3 resolved when the AC's `agent.run(input)`/`chatSession` mapped to the real `session.send`/`session.state`. The resolution:
- The harness encodes the handler's return under a `value` envelope: **`content = jsonEncode({'value': handlerReturn})`**. So `addTwo`'s `5` → `content == '{"value":5}'`.
- AC2's assertion is realized as **`(jsonDecode(result.content) as Map<String, dynamic>)['value'] == 5`**.
- **Do NOT** add a `payload` getter or a global `extension on ToolCallResultEvent` in `koel_core`: most real `content`s are *not* JSON objects (`"ok"`), so a global `jsonDecode`-backed `payload` would throw across the codebase — a footgun that violates "design for what users can't misuse." The `{'value': …}` envelope is the **harness's** test-result convention, documented on `invoke`, and it lives only inside the harness. [Source: tool_call_events.dart:92-135; tool_call_basic.jsonl; CLAUDE.md "what users can't misuse"; 3.3 AC-mapping precedent]

### Replay stub — RESOLVED
AC3's handler "checks `ToolReplayContext.isReplaying`," but `ToolReplayContext` is a **`koel_flutter` `InheritedWidget` defined in Epic 6 Story 6.6** (architecture :896-897: `tool_replay_context.dart # F-F7 replay-safety InheritedWidget`), and `koel_test` is **pure Dart** — adding Flutter to a framework-free package is a regression. The cross-epic anchor in the epic spec is explicit: this Epic 3 story "ships only the harness scaffold and exercises the replay path via a **stub flag**," with "full FR-F7 contract validation defer[red] to Story 8.7." So:
- The harness exposes **`bool get isReplaying`** (backed by a private `_isReplaying` the `invoke(..., isReplaying:)` param sets around the handler call and resets in `finally`). This is the **stub stand-in** for `ToolReplayContext.isReplaying`.
- A replay-aware test handler **closes over the harness instance** and reads `harness.isReplaying`, skipping its side effect when `true` while still returning the recorded value — so the `ToolCallResultEvent` still emits (AC3's "side effect is skipped while the recorded result still emits").
- **Do NOT** ship a class named `ToolReplayContext` in `koel_test` (it would collide conceptually with — and pre-empt — the real 6.6 `InheritedWidget`) and **do NOT** add Flutter. When Epic 8 Story 8.7 lands the DevTools replay path against the 6.6 type, it owns the real recorded-result stubbing; 3.4 only proves the harness can gate a handler on a replay flag. [Source: epic-3 3.4 cross-epic anchor :83; architecture :896-901,932-935; FR-F7 :60; requirements-inventory.md FR map :206-207]

### Error contract
Unknown tool name → **`ArgumentError`** with the registered names enumerated — a typo'd handler name is a **test-authoring / programmer error**, not a runtime `KoelError`/`RunErrorEvent` (the "adapter never throws, emits `RunErrorEvent`" rule is for *runtime* stream failures). This mirrors 3.3's `FixtureLoader` unknown-fixture contract exactly. The throw is async (inside the `Future`-returning `invoke`), asserted with `throwsArgumentError` on the future. [Source: 3.3 §"Error contract"; architecture §5 adapter rule]

### Out of scope — do NOT build these (RESOLVED)
- **`ConformanceRunner`, `ConformanceReport`, `koel_core/CONFORMANCE.md`, `tool/capture_fixtures.dart`** — Story 3.5 (the epic sealer). [Source: epic-3 3.5]
- **Any `koel_core` change** — unlike 3.3, the kernel already exports everything the harness consumes (`KoelClient`, `AgentSubscriber`, `ToolCall*` events, `RunAgentInput`, `AbstractAgent`). Adding a kernel `ToolHandler` is speculative. [Source: trap #1; koel_core.dart exports]
- **A real `ToolReplayContext` / any Flutter dependency / `flutter.assets:` stanza** — wrong package; 6.6/8.7 own the real type. [Source: trap #4]
- **A `payload` getter/extension on `ToolCallResultEvent`** — footgun (trap #2). [Source: §"Result encoding"]
- **`freezed`/`build_runner` in `koel_test`** — no new freezed type is declared; the harness is a plain `final class`. 3.5 owns any future codegen decision. [Source: 3.1/3.2/3.3 no-codegen rule]
- **`koel_test` package-finalization gates** (member `analysis_options.yaml` doc gate, ≥80% coverage) — **Story 3.5**. [Source: epic-3 3.5; 3.1/3.2/3.3]
- **Changing `publish_to: none`** anywhere — flips at Epic 9 Story 9.9. [Source: 3.2/3.3 Out of scope]

### Files you will touch
| Path | Action | Note |
|------|--------|------|
| `packages/koel_test/lib/src/tool_handler_test_harness.dart` | **NEW** | `typedef ToolHandler` + `final class ToolHandlerTestHarness` (`register`/`observe`/`invoke`/`isReplaying` + private `_handlers`/`_observers`/`_isReplaying`/`_callSeq`) (Tasks 1-6). |
| `packages/koel_test/lib/koel_test.dart` | **MODIFY** | Add `export 'src/tool_handler_test_harness.dart';` — the third export (Task 7). |
| `packages/koel_test/test/tool_handler_test_harness_test.dart` | **NEW** | AC1/AC2 (mapped), AC2 observability, AC3 replay-stub, async handler, unknown-name `ArgumentError` (Task 8). |

**Do NOT touch:** any `koel_core` file; 3.2's `.jsonl`/`.placeholder` fixtures; `koel_test/lib/src/mock_agent.dart` or `fixture_loader.dart` (consumed, not modified); `koel_test/pubspec.yaml` (no new dep); any other package; `publish_to`; `koel_test`'s `README`/`CHANGELOG`/`LICENSE`; root melos scripts.

### Library / framework requirements
- **No new dependencies anywhere.** `koel_test` already depends on `koel_core` (3.1) + `test` dev-dep. The harness uses `dart:async` (`FutureOr`), `dart:convert` (`jsonEncode`/`jsonDecode`) — both SDK — and `koel_core`'s public barrel + `koel_test`'s own `MockAgent`. **No `freezed`/`build_runner`, no Flutter.** [Source: koel_test/pubspec.yaml; trap #1/#6]
- **`package:test` only** for tests; async matchers (`throwsArgumentError`, `throwsA(isA<…>().having(...))`); no `fakeAsync` (the harness has no time subject — zero-delay replay). [Source: architecture §6 :654-664]
- **Consumed from `koel_core`'s public barrel:** `KoelClient` (+ `runRaw`, `subscribers`, `dispose`), `AgentSubscriber` (extend it for the test observer), `ToolCallStartEvent`/`ToolCallArgsEvent`/`ToolCallEndEvent`/`ToolCallResultEvent`, `RunStartedEvent`/`RunFinishedEvent`, `RunAgentInput`, `AbstractAgent`/`AgUiEvent`. From `koel_test`: `MockAgent.fromEvents`. **Read for use; modify nothing in `koel_core`.** [Source: koel_core.dart exports :22-56; mock_agent.dart:30-37]

### Project Structure Notes
- `packages/koel_test/lib/src/tool_handler_test_harness.dart` is the architecture-pinned location (architecture :958-977 lists `tool_handler_test_harness.dart # F-G3` between `fixture_loader.dart` and `conformance_runner.dart`). [Source: architecture :958-977]
- `lib/koel_test.dart` stays the single barrel; this adds its **third** export (after `mock_agent.dart`, `fixture_loader.dart`). `lib/src/` stays private. [Source: koel_test.dart:7-11; architecture §6 :684]
- Test mirrors source: `test/tool_handler_test_harness_test.dart` ↔ `lib/src/tool_handler_test_harness.dart` (convention §6 :654). It is `koel_test`'s fourth test file. [Source: architecture §6 :654-664; 3.1/3.2/3.3 File Lists]
- The `koel_test → koel_core` edge is unchanged (no reverse dep, no new edge); this story widens **only `koel_test`'s** public surface, by one class + one typedef. [Source: architecture :1034,:1301]

### Previous Story Intelligence
- **3.3 (`FixtureLoader`)** — established the `koel_test` patterns this story reuses: barrel discipline (import only `package:koel_core/koel_core.dart`), plain `final class` over freezed, **unknown-name → enumerated `ArgumentError`** (copy that error contract verbatim for unknown tool names), async throws asserted with `throwsArgumentError`, and the discipline of **mapping aspirational AC prose to the real API** (3.3 mapped `agent.run`/`chatSession` → `session.send`/`session.state`; 3.4 maps `result.payload['value']` → `jsonDecode(result.content)['value']` and `ToolReplayContext.isReplaying` → `harness.isReplaying`). 3.3 also added the one `koel_core` change of Epic 3 (`AgUiEvent.fromWire`) **because barrel discipline forced it** — note that **no such forcing function exists here**, so 3.4 is zero-`koel_core`-change. [Source: 3-3-fixture-loader-from-fixture.md §"Error contract", §"Crossing the codec wall", Review Findings]
- **3.1 (`MockAgent`)** — `invoke` builds on `MockAgent.fromEvents(List<AgUiEvent>)` (verbatim replay, defensive copy, ignores input, cancellable). The `MockAgentBuilder` has **no `.toolCall(...)` sugar** — its `event()` escape hatch appends arbitrary events, but the harness builds its `List<AgUiEvent>` directly and wraps with `fromEvents` (simpler than the builder for a fixed quartet). [Source: 3-1-mock-agent-foundation.md; mock_agent.dart:30-37,128-132]
- **2.10 (`AgentSubscriber`)** — the callback bag the AC2 observer extends: `onToolCall(start, end)` fires with `end: null` (per-event firing), `onToolResult(e)` fires on the result. **Extend, do not implement** (forward-compat). Subscribers are observation-only; a throw is reported to the Zone and does not stop the run. [Source: agent_subscriber.dart:42-71; 2.10]
- **2.14 (`KoelClient`)** — `runRaw(input)` is the layer-3 stream that fires subscribers via `_notify` per event (no reducer/persistence needed for the harness); `subscribers` is a mutable list; `dispose()` clears it. Build a fresh client per `invoke` and dispose it. [Source: koel_client.dart:140-143,165-172,177-227]
- **2.6 (`ToolCall*` events)** — the event family the harness assembles: `ToolCallStartEvent(toolCallId, toolCallName)`, `ToolCallArgsEvent(toolCallId, delta)`, `ToolCallEndEvent(toolCallId)`, `ToolCallResultEvent(messageId, toolCallId, content, role?)`. **`content` is a String** — the trap-#2 anchor. [Source: tool_call_events.dart:9-135]

### Git Intelligence Summary
HEAD / baseline for 3.4 is `5a15a5f` (`feat(story-3.3): FixtureLoader + MockAgent.fromFixture + AgUiEvent.fromWire decode seam`). 3.1 (`8c26147`) added `mock_agent.dart`; 3.2 (`b28bbbb`) added fixtures; 3.3 (`5a15a5f`) added `fixture_loader.dart` + the one `koel_core` seam. 3.4's expected footprint is the **smallest of Epic 3**: 1 new `koel_test` lib file + 1 barrel line + 1 new test file + `sprint-status.yaml` (each prior story commit touched it — expect the same). **Zero `koel_core` change, zero new dependency.** Suggested commit: `feat(story-3.4): ToolHandlerTestHarness fluent builder + ToolHandler typedef`. [Source: git log 5a15a5f/b28bbbb/8c26147; epic-3 3.4]

### Latest Tech Information
- **`FutureOr<T>`** (`dart:async`) as a callback return lets one `typedef` accept both sync and async handlers; `await` on a `FutureOr` value is valid (returns the value when not a `Future`). This is the idiomatic single-signature way to support `(args) => 5` and `(args) async => await f()` together. [Source: dart:async; AC2 sync handler]
- **`jsonEncode`/`jsonDecode`** (`dart:convert`) for the `content` envelope and the test-side decode. `jsonEncode` throws on a non-encodable object (surface it — a handler returning a non-serializable value is a test bug). [Source: dart:convert; trap #2]
- **`KoelClient.runRaw(input).toList()`** drains the post-pipeline stream and, via the `map((e){_notify(e);return e;})` wiring, fires every attached `AgentSubscriber` exactly once per event — the real observability path for AC2. The `MockAgent` emits with zero delay, so the whole run is sub-millisecond (well under AC2's 100 ms). [Source: koel_client.dart:140-143; mock_agent.dart:64-72]
- **`package:test` async matchers** — `expect(harness.invoke('nope', const {}), throwsArgumentError)` matches a `Future` rejected with `ArgumentError`; `throwsA(isA<ArgumentError>().having((e) => e.message, 'message', contains('addTwo')))` asserts the enumerated message. [Source: package:test matchers; Task 6]

### References
- [epic-3 Story 3.4 spec + ACs + cross-epic anchor (`ToolReplayContext` 6.6 / replay 8.7)](../planning-artifacts/epics/epic-3-test-harness-conformance-koeltest.md)
- [architecture.md :958-977 (`koel_test` layout — `tool_handler_test_harness.dart # F-G3` at :965); :896-901,932-935 (`ToolReplayContext` lives in koel_flutter 6.6 / koel_devtools 8.7); §6 :632-671 (doc + testing conventions); :684-685 (single barrel, no external `src/` import); :980 (only meta-package re-exports); :1062-1087 (integration points — `AgentSubscriber` post-pipeline)](../planning-artifacts/architecture.md)
- [requirements-inventory.md :64-67 (FR-G1..G4 — FR-G3 is this harness); :60 (FR-F7 replay safety + `ToolReplayContext`); :18 (FR-A10 `AgentSubscriber` bag); :206-207 (F-F7 → Epic 8 map)](../planning-artifacts/epics/requirements-inventory.md)
- [koel_core/lib/src/event/tool_call_events.dart:9-135 — `ToolCall*` event shapes; `ToolCallResultEvent.content` is a String (trap #2)](../../packages/koel_core/lib/src/event/tool_call_events.dart)
- [koel_core/lib/src/agent/agent_subscriber.dart:42-71 — extend it; `onToolCall(start, null)` + `onToolResult`](../../packages/koel_core/lib/src/agent/agent_subscriber.dart)
- [koel_core/lib/src/client/koel_client.dart:62-83,140-143,165-172,192-227 — `KoelClient(agent:, subscribers:)`, `runRaw`, `dispose`, the `_notify`→`_dispatch` observability path](../../packages/koel_core/lib/src/client/koel_client.dart)
- [koel_core/lib/src/input/run_agent_input.dart:31-40 — only `threadId`/`runId` required (the `MockAgent` ignores input anyway)](../../packages/koel_core/lib/src/input/run_agent_input.dart)
- [koel_test/lib/src/mock_agent.dart:30-37,64-72 — `MockAgent.fromEvents` (verbatim replay) the harness wraps](../../packages/koel_test/lib/src/mock_agent.dart)
- [koel_test/lib/koel_test.dart:7-11 — the barrel that gains the third export](../../packages/koel_test/lib/koel_test.dart)
- [koel_test/lib/src/fixtures/synthesized/tool_call_basic.jsonl — the canonical `START→ARGS→END→RESULT` shape (`content: "ok"`) the harness mirrors](../../packages/koel_test/lib/src/fixtures/synthesized/tool_call_basic.jsonl)
- [3-3-fixture-loader-from-fixture.md — error contract, AC-mapping discipline, `final class` patterns this story reuses](3-3-fixture-loader-from-fixture.md)

### Design decisions (RESOLVED — AC/architecture-forced, not open)
Baked in so the dev has zero ambiguity. No confirmation gate.
1. **`ToolHandler` is a `koel_test`-local `typedef FutureOr<Object?> Function(Map<String, dynamic> args)`.** `koel_core` has no `ToolHandler` and no tool-execution path; the harness owns it. **No `koel_core` change** (no kernel consumer; YAGNI). [trap #1]
2. **The harness runs the handler itself** (it holds `args`), then assembles a canonical `RUN_STARTED→TOOL_CALL_START→ARGS→END→TOOL_CALL_RESULT→RUN_FINISHED` run and replays it through a **real `KoelClient.runRaw`** so `AgentSubscriber` dispatch is exercised. "Under a `MockAgent`" = the run is `MockAgent`-driven; the handler cannot be invoked *by* the frozen replay. [trap #3, §"The harness mechanism"]
3. **Result encoding: `content = jsonEncode({'value': handlerReturn})`.** `ToolCallResultEvent` exposes `content: String`, not `payload`. AC2's `result.payload['value']` → `(jsonDecode(result.content) as Map)['value']`. **No `payload` getter/extension on `koel_core`'s event** (footgun). [trap #2]
4. **Replay stub: `bool get isReplaying`** on the harness, set by `invoke(..., isReplaying:)` around the handler call. The replay-aware test handler closes over the harness and reads it; side effect skipped, recorded result still emits. **No `ToolReplayContext` symbol, no Flutter dep.** Full FR-F7 → Story 8.7. [trap #4]
5. **Fluent API:** `register(name, handler) → this`, `observe(AgentSubscriber) → this`, `invoke(name, args, {bool isReplaying = false}) → Future<ToolCallResultEvent>`. Default unnamed constructor (`ToolHandlerTestHarness()`). [AC1/AC2]
6. **Unknown name → `ArgumentError`** with registered names enumerated (programmer error, not `KoelError`); async throw asserted with `throwsArgumentError`. [§"Error contract"]
7. **Deterministic instance-scoped ids** (`_callSeq`, no `static` — FR-D3): `toolCallId='harness-call-$n'`, `messageId='harness-result-$n'`.
8. **No new dependency; zero `koel_core` change.** `dart:async` + `dart:convert` + `koel_core` barrel + own `MockAgent`. No freezed, no Flutter. [trap #6]
9. **Package-finalization gates (doc/coverage) and `ConformanceRunner`/`ConformanceReport`/capture-pipeline are Story 3.5, not 3.4.** 3.4 needs only `analyze`/`test`/`format:check` green. [epic-3 3.5]

### Review Findings

_Code review 2026-05-31 (Blind Hunter + Edge Case Hunter + Acceptance Auditor). Acceptance Auditor: fully compliant, zero AC violations. Triage: 1 patch, 0 defer, 7 dismissed._

- [x] [Review][Patch] Document the single-invoke contract on `invoke`/`isReplaying` [packages/koel_test/lib/src/tool_handler_test_harness.dart:62,121] — `_isReplaying` is shared instance state reset unconditionally to `false` in `invoke`'s `finally`. Under **overlapping** invokes (`Future.wait([h.invoke(.., isReplaying: true), h.invoke(..)])`) or a **re-entrant** handler that calls `harness.invoke` again, one call's `finally` clobbers the other's flag mid-flight, so a replay-aware handler gates on the wrong state with no error (flagged by blind + edge). Intended usage is per-test sequential single invoke (class doc already says "A harness is per-test"), and the underlying flag is an explicitly-temporary stub for `ToolReplayContext` (replaced in Story 8.7) — so this is a doc-hardening patch, not a mechanism change: make the public `invoke`/`isReplaying` contract state explicitly that one invoke must complete before the next on a given harness (honors CLAUDE.md "design for what users can't misuse"). No code-behavior change.

**Dismissed (rationale):**
- _Heavyweight `KoelClient` round-trip per invoke_ (blind) — by design (RESOLVED #2): the real-dispatch drain is exactly what AC2's "observable via an attached AgentSubscriber" requires; returning the inline event would bypass it.
- _`jsonEncode` throws on non-encodable handler return / args_ (blind + edge) — by design (RESOLVED #3): documented as a let-it-throw-loud test-authoring bug.
- _`isReplaying` getter reads `false` to outside observers_ (blind) — by design: the flag is read by the handler closure *during* its call; doc explicitly states "`false` at every other time."
- _`.single` could throw opaque `StateError` if the pipeline drops/dupes the result_ (blind + edge) — verified safe: edge confirmed the canonical START→ARGS→END→RESULT timeline passes `verify_stage` unchanged → exactly one result event; harness owns the fixed timeline. Latent-only.
- _Observer accumulation across multiple invokes_ (blind + edge) — by design: `observe` doc states observers attach to "every subsequent invoke"; multi-invoke-with-count-assert is the test author's concern, outside the harness contract.
- _Empty `content`/`messageId` result not protocol-validated_ (edge) — harness emits its own well-formed result; `verify_stage` has no rule for `ToolCallResultEvent`. Not a crash; latent-only.
- _Throwing observer reported to `Zone`, not aborting the run_ (edge) — by design of `KoelClient` (subscribers are observation-only); `package:test`'s zone surfaces uncaught async errors anyway.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (dev-story workflow + `/agent-flutter-engineer` specialist)

### Debug Log References

None — no HALT conditions hit. Implementation was a single red→green→refactor pass; all gates green first run.

### Completion Notes List

- **Task 0 (surface read) — all confirmed:** `ToolCallResultEvent.content` is a `String` (no `payload`/`value`); `AgentSubscriber.onToolCall(start, end?)`/`onToolResult(e)` extend-not-implement; `KoelClient(agent:, subscribers:)` + `runRaw`/`dispose` + mutable `subscribers`; `MockAgent.fromEvents`; `RunAgentInput(threadId:, runId:)`; **grep-verified no `ToolHandler`/`registerTool`/`ToolRegistry` in `packages/koel_core/lib`** — the typedef is `koel_test`-local.
- **`ToolHandler` typedef** = `FutureOr<Object?> Function(Map<String, dynamic> args)` — one signature for sync + async handlers; `koel_test`-only, zero `koel_core` change.
- **Harness mechanism (the heart):** `invoke` runs the handler itself (it holds `args`), encodes the return as `content = jsonEncode({'value': raw})`, assembles the canonical `RUN_STARTED → TOOL_CALL_START → TOOL_CALL_ARGS → TOOL_CALL_END → TOOL_CALL_RESULT → RUN_FINISHED` timeline, and drains it through a **real** `KoelClient.runRaw` so `AgentSubscriber` dispatch fires for real. Returns the post-pipeline `ToolCallResultEvent` (`events.whereType<ToolCallResultEvent>().single`) — the same instance observers saw.
- **AC-vs-reality mappings implemented as resolved:** `result.payload['value']` → `(jsonDecode(result.content) as Map<String, dynamic>)['value']`; `ToolReplayContext.isReplaying` → harness instance flag `bool get isReplaying` (stub stand-in; **no Flutter dep, no `ToolReplayContext` symbol**). Full FR-F7 defers to Story 8.7.
- **Lifecycle:** fresh `KoelClient` per `invoke`, disposed in `finally`. Replay flag set around the handler call and reset in `finally` (proven by the AC3-mirror assertion `harness.isReplaying == false` post-invoke).
- **Determinism (FR-D3):** ids from an **instance** counter `_callSeq` (`harness-call-$n`/`harness-result-$n`/`harness-thread-$n`/`harness-run-$n`) — no `static` mutable state.
- **Error contract:** unknown name → enumerated `ArgumentError` (mirrors 3.3's `FixtureLoader`), asserted with `throwsA(isA<ArgumentError>().having(message, contains('addTwo')))`.
- **Gates:** `melos run analyze` → 0 issues (9 packages); `melos run test` → green workspace-wide incl. 6 new harness tests; `melos run format:check` → 0 changed. Footprint exactly: 1 new lib file + 1 barrel line + 1 new test file. **Zero `koel_core` change, zero new dependency.**

### File List

- `packages/koel_test/lib/src/tool_handler_test_harness.dart` — **NEW** — `typedef ToolHandler` + `final class ToolHandlerTestHarness` (`register`/`observe`/`invoke`/`isReplaying`).
- `packages/koel_test/lib/koel_test.dart` — **MODIFY** — added `export 'src/tool_handler_test_harness.dart';` (third export).
- `packages/koel_test/test/tool_handler_test_harness_test.dart` — **NEW** — AC1/AC2 mapped, AC2 observability, AC3 replay-stub + mirror, async handler, unknown-name `ArgumentError` (6 tests).
- `_bmad-output/implementation-artifacts/sprint-status.yaml` — **MODIFY** — `3-4` → `in-progress` → `review`.

## Change Log

| Date | Change |
|------|--------|
| 2026-05-31 | Created Story 3.4 context (ready-for-dev): `ToolHandlerTestHarness` fluent builder + `ToolHandler` typedef in `koel_test`; zero `koel_core` change; resolved AC-vs-reality mappings (`result.payload['value']` → `jsonDecode(content)['value']`, `ToolReplayContext.isReplaying` → `harness.isReplaying`). |
| 2026-05-31 | Implemented Story 3.4 (status → review): `ToolHandler` typedef + `ToolHandlerTestHarness` (`register`/`observe`/`invoke`/`isReplaying`) replaying through real `KoelClient.runRaw`; barrel third export; 6 tests (AC1/AC2/AC3 + mirror, async, unknown-name `ArgumentError`). `analyze`/`test`/`format:check` green workspace-wide; zero `koel_core` change, zero new dependency. |
