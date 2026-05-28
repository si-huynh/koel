# Epic 3: Test Harness & Conformance — `koel_test`

Developer (and every subsequent epic) can write tests using `MockAgent.fromFixture(name)` against synthesized fixtures covering every AG-UI event type. `ToolHandlerTestHarness` reduces test boilerplate; `ConformanceRunner` skeleton is ready for backend adapters to plug into. Fixture-capture pipeline scaffold exists; real backend captures land in Epic 5. `koel_core/CONFORMANCE.md` records the AG-UI spec commit SHA.

## Story 3.1: `MockAgent` foundation — `.programmatic()` + `.fromEvents()`

As a Flutter/Dart developer,
I want `MockAgent` exposing `.programmatic()` (builder pattern) and `.fromEvents(List<AgUiEvent>)` factory constructors implementing `AbstractAgent`,
So that I can author deterministic test agents inline without authoring fixtures per FR-G2.

**Acceptance Criteria:**

**Given** `koel_test/lib/src/mock_agent.dart`,
**When** I inspect the class,
**Then** `class MockAgent implements AbstractAgent` declares factories `MockAgent.fromEvents(List<AgUiEvent>)` and `MockAgent.programmatic()` returning a builder for declarative event-sequence construction (e.g., `.runStarted().textMessage("hi").runFinished().build()`).

**Given** a `MockAgent.fromEvents([RunStartedEvent(...), TextMessageStartEvent(...), TextMessageContentEvent(...), TextMessageEndEvent(...), RunFinishedEvent(...)])`,
**When** I `await for` its `run(input)` stream,
**Then** every event emits in declared order with realistic timing (default: zero delay; configurable per-event delay for streaming-jank tests).

**Given** a programmatic agent with a configured `Duration` per event,
**When** I drive a run,
**Then** each event emits after its configured delay,
**And** cancelling the subscription mid-stream stops further emissions (TCP-close-analog behavior).

## Story 3.2: Synthesized fixture set + storage layout

As an OSS contributor,
I want `koel_test/lib/src/fixtures/` to ship JSONL synthesized fixtures covering every AG-UI event type and key scenarios under a backend-organized layout (`synthesized/`, `dojo/`, `agno/`, `langgraph/`, `copilotkit_runtime/`),
So that early epics (Epic 4 `koel_http`) can test against canonical fixtures before real backend captures arrive in Epic 5 per FR-G1 + AR-13.

**Acceptance Criteria:**

**Given** `koel_test/lib/src/fixtures/`,
**When** I list the directory,
**Then** five subdirectories exist: `synthesized/`, `dojo/`, `agno/`, `langgraph/`, `copilotkit_runtime/`,
**And** `synthesized/` contains at minimum one fixture per AG-UI event type plus core scenarios: `text_only_run.jsonl`, `tool_call_basic.jsonl`, `state_delta_basic.jsonl`, `reasoning_with_encrypted_value.jsonl`, `error_path.jsonl`, `cancellation.jsonl`.

**Given** any synthesized JSONL fixture,
**When** I read the first line,
**Then** it is the `_session` metadata header per Addendum C.4 with `koelVersion`, `adapter`, `captured`, `threadId`, `runId`, and a `synthesized: true` marker,
**And** subsequent lines each carry one event with `timestamp` (ISO 8601) + `payload` (wire-format JSON).

**Given** `koel_test/pubspec.yaml`,
**When** I inspect it,
**Then** the fixtures directory is declared under `flutter.assets:` (Flutter packages) or referenced via `package:` URI relative path resolution (Dart packages),
**And** the assets are bundled in the published tarball.

**Given** the backend subdirectories `dojo/`, `agno/`, `langgraph/`, `copilotkit_runtime/`,
**When** I list each,
**Then** each carries a `.placeholder` file with a doc comment naming Epic 5 stories that populate it,
**And** no real captured fixtures exist yet (real captures land in Stories 5.3, 5.6, 5.9).

## Story 3.3: `FixtureLoader` + `MockAgent.fromFixture(name)`

As a Flutter/Dart developer,
I want `FixtureLoader` static API plus `MockAgent.fromFixture(String name)` factory that reads bundled JSONL fixtures via `package:` asset URI,
So that test code reduces to `final agent = MockAgent.fromFixture('text_only_run')` with zero setup per FR-G2.

**Acceptance Criteria:**

**Given** `koel_test/lib/src/fixture_loader.dart`,
**When** I inspect it,
**Then** it exposes static methods `FixtureLoader.loadDojo(String eventType)`, `loadAgno(String scenario)`, `loadLangGraph(String scenario)`, plus a generic `loadSynthesized(String name)`,
**And** each returns `Future<List<AgUiEvent>>` reading the JSONL via `rootBundle.loadString` (Flutter) or `File`-relative (Dart),
**And** the `_session` header line is parsed into a typed `FixtureSession` value and discarded from the event list.

**Given** `MockAgent.fromFixture('text_only_run')`,
**When** the test invokes `agent.run(input)`,
**Then** the synthesized text-only fixture replays through the SDK pipeline,
**And** asserting `chatSession.state.messages.last.content` matches the expected text passes.

**Given** an unknown fixture name,
**When** the test invokes `MockAgent.fromFixture('does_not_exist')`,
**Then** the call throws `ArgumentError` (programmer error, not `KoelError`) with the available fixture names enumerated in the message.

## Story 3.4: `ToolHandlerTestHarness` fluent builder

As a Flutter/Dart developer,
I want a fluent `ToolHandlerTestHarness` that registers tool handlers, drives them through a `MockAgent`, and asserts on tool args / responses / replay behavior in ~5 lines per case,
So that downstream consumers test their tool handlers without rebuilding the harness per FR-G3.

> **Cross-epic anchor.** This story exercises the replay path via a **stub flag** because `ToolReplayContext` (the real `InheritedWidget` type that replay-aware handlers consult) does not exist until Epic 6 Story 6.6, and end-to-end replay semantics complete in Epic 8 Story 8.7. A green Story 3.4 establishes the harness contract; **full FR-F7 contract validation defers to Story 8.7** (DevTools replay path + recorded-result stubbing) wired against the Story 6.6 type.

**Acceptance Criteria:**

**Given** `koel_test/lib/src/tool_handler_test_harness.dart`,
**When** I inspect the class,
**Then** it exposes `ToolHandlerTestHarness register(String name, ToolHandler handler)` returning `this` for chaining,
**And** `Future<ToolCallResultEvent> invoke(String name, Map<String, dynamic> args)` runs the handler under a `MockAgent` and returns the resulting tool-call result event.

**Given** a downstream test:
```dart
final result = await ToolHandlerTestHarness()
  .register('addTwo', (args) => args['a'] + args['b'])
  .invoke('addTwo', {'a': 2, 'b': 3});
expect(result.payload['value'], equals(5));
```
**When** the test runs,
**Then** it completes in < 100 ms,
**And** the handler invocation is observable via an attached `AgentSubscriber`.

**Given** a replay-aware handler that checks `ToolReplayContext.isReplaying` (the type is defined in Story 6.6 — Epic 6; this Epic 3 story ships only the harness scaffold and exercises the replay path via a stub flag),
**When** the harness simulates a replay scenario with the stub `isReplaying: true`,
**Then** the handler's side effect is skipped while the recorded result still emits (full end-to-end replay verified in Epic 8 Story 8.7).

## Story 3.5: `ConformanceRunner` skeleton + `CONFORMANCE.md` pin + capture pipeline scaffold

As a release manager,
I want `ConformanceRunner.runAgainst(AbstractAgent)` returning `ConformanceReport`, plus `koel_core/CONFORMANCE.md` pinning the AG-UI release commit SHA, plus `tool/capture_fixtures.dart` scaffold ready for Epic 5 to execute,
So that backend adapters can plug into a conformance test that runs every event type from fixtures per FR-G4 + AR-14 + AR-16.

**Acceptance Criteria:**

**Given** `koel_test/lib/src/conformance_runner.dart`,
**When** I inspect it,
**Then** `class ConformanceRunner` exposes `Future<ConformanceReport> runAgainst(AbstractAgent agent)` that drives the agent through every event-type scenario in `koel_test/lib/src/fixtures/synthesized/` and records pass/fail per event type.

**Given** `koel_test/lib/src/conformance_report.dart`,
**When** I inspect it,
**Then** `ConformanceReport` is freezed with `passed: List<String>`, `failed: List<ConformanceFailure>`, `agentName: String`, `runDuration: Duration`,
**And** `ConformanceFailure` carries `eventType: String`, `expected: AgUiEvent`, `actual: AgUiEvent`, `error: KoelError?`.

**Given** `koel_core/CONFORMANCE.md`,
**When** I inspect the file,
**Then** it pins the specific commit SHA of AG-UI `release/2026-05-26` (placeholder commit hash committed here; finalized at v1.0.0 publish per SC-1),
**And** documents the structural-equality rule for `AgUiEvent_equal` per Addendum AR-16 (`freezed`-generated `==` covers all fields including byte-equal `Uint8List` comparison — OQ-Conformance-Equivalence resolves before v1.0.0).

**Given** `tool/capture_fixtures.dart`,
**When** I inspect the scaffold,
**Then** it declares the four backend configurations (dojo, agno, langgraph, CopilotKit Next.js runtime) with `// TODO(Epic 5):` markers pointing to specific story IDs,
**And** the script can be invoked via `dart run tool/capture_fixtures.dart --backend=<name>` printing "wired in Epic 5 Story <N>" until populated,
**And** `melos.yaml` exposes `melos run capture-fixtures` script wired to this entrypoint.

**Given** `koel_test` package overall,
**When** I run `melos run test:coverage` for it,
**Then** coverage ≥ 80% per NFR-12.

---
