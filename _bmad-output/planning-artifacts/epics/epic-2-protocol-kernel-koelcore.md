# Epic 2: Protocol Kernel — `koel_core`

Developer can construct a `KoelClient` wrapping a programmatic `MockAgent`, drive a `ChatSession`, and observe a fully-typed `Stream<AgUiEvent>` covering all ~28 AG-UI event types through the 4-stage pipeline. Sealed `KoelError`, `AgentSubscriber`, vendor-inline RFC 6902, and `InMemorySessionStorage` all ship. Reducer purity verified. Coverage ≥ 90%. Perf baselines for reducer + cold-start captured.

## Story 2.1: Foundation contracts — `AbstractAgent` SPI + `RunAgentInput` + `ToolDefinition` + `Message`

As a Flutter/Dart developer,
I want the irreducible kernel contracts (`AbstractAgent.run() → Stream<AgUiEvent>`, `RunAgentInput`, `ToolDefinition`, `Message`) defined as freezed-immutable types with the SPI marker,
So that every backend bridge and every consumer surface compiles against a stable foundation per FR-A1.

**Acceptance Criteria:**

**Given** `koel_core/lib/src/agent/abstract_agent.dart`,
**When** I open it,
**Then** `interface class AbstractAgent` is declared with a single method `Stream<AgUiEvent> run(RunAgentInput input)`,
**And** the dartdoc explicitly states "Adapters NEVER throw `KoelError` — they emit `RunErrorEvent`. The `interface class` marker prevents accidental instance construction; consumers reach for `KoelClient` instead."

**Given** `koel_core/lib/src/input/run_agent_input.dart`,
**When** I inspect the freezed type,
**Then** it carries fields `threadId`, `runId`, `state`, `messages`, `tools`, `context`, `forwardedProps`, and `reasoningEcho: Map<String, Uint8List>?` with const constructor,
**And** all collection fields use `List`/`Map` types whose freezed-generated `==` produces deep equality.

**Given** `koel_core/lib/src/tool/tool_definition.dart`,
**When** I inspect it,
**Then** `ToolDefinition` is freezed with `name`, `description`, and `parameters: Map<String, dynamic>` (JSON Schema in v1 per OQ-Tool-Param-DSL).

**Given** `koel_core/lib/src/message/message.dart`,
**When** I inspect it,
**Then** `Message` is a freezed-immutable type carrying `id: String`, `role: MessageRole` (enum: `user`, `assistant`, `system`, `tool`), `content: String`, `timestamp: DateTime`, plus optional `toolCallId: String?` and `name: String?` per the AG-UI `Message` shape,
**And** `Message` is the element type used by both `RunAgentInput.messages: List<Message>` and `ChatState.messages: List<Message>` (Story 2.12),
**And** the freezed-generated `==` produces deep equality across all fields including timestamp.

**Given** `koel_core/build.yaml`,
**When** I inspect the build_runner configuration,
**Then** it configures `freezed: ^3.2.5` (per AR-4) and `json_serializable` with `field_rename: none` per architecture convention §3,
**And** running `dart run build_runner build` produces `*.freezed.dart` and `*.g.dart` next to source files.

## Story 2.2: Sealed `AgUiEvent` root + `UnknownAgUiEvent` forward-compat fallback

As a Flutter/Dart developer,
I want `sealed class AgUiEvent` as the root union plus `UnknownAgUiEvent(type, rawJson)` as the forward-compat fallback,
So that future AG-UI events deserialize into a typed surface that never crashes the SDK per FR-A6 and FC-1.

**Acceptance Criteria:**

**Given** `koel_core/lib/src/event/ag_ui_event.dart`,
**When** I inspect it,
**Then** `sealed class AgUiEvent` is declared (Dart 3) with a `const` constructor,
**And** no concrete event subtypes are declared inline (subtypes live in their own files per the per-package layout in architecture).

**Given** `koel_core/lib/src/event/unknown_event.dart`,
**When** I inspect `UnknownAgUiEvent`,
**Then** it extends `AgUiEvent`, carries `final String type` + `final Map<String, dynamic> rawJson`,
**And** its `==`/`hashCode` use freezed-generated structural equality.

**Given** a future event type with a `type` string not in the current registry,
**When** the event-deserializer dispatcher receives the raw JSON,
**Then** it returns `UnknownAgUiEvent(type: <type>, rawJson: <raw>)` (no exception),
**And** an `AgentSubscriber.onUnknownEvent` callback fires once when the pipeline routes it (verified in Story 2.10 wiring).

## Story 2.3: Sealed `KoelError` hierarchy + `KoelErrorCode` enum + `DefaultErrorClassifier`

As a Flutter/Dart developer,
I want the sealed error model — `KoelError` with `TransportError | ProtocolError | AgentError | BusinessError` subtypes, `KoelErrorCode` typed-vocabulary enum, and `DefaultErrorClassifier` mapping raw failures to typed errors,
So that consumer code pattern-matches errors exhaustively (lint-enforced default branch) and adapters classify backend-specific failures per FR-A5. This story ships error types BEFORE event subtypes because `RunErrorEvent.error: KoelError` (Story 2.5) depends on them.

**Acceptance Criteria:**

**Given** `koel_core/lib/src/error/koel_error.dart`,
**When** I inspect it,
**Then** `sealed class KoelError implements Exception` is declared with abstract getters `message: String`, `code: KoelErrorCode`, `cause: Object?`,
**And** `TransportError`, `ProtocolError`, `AgentError`, `BusinessError` are declared as concrete subtypes with their respective specialization fields per Addendum A.1.

**Given** `koel_core/lib/src/error/koel_error_code.dart`,
**When** I inspect the enum,
**Then** it lists every code from Addendum A.1: `transportTimeout`, `transportClosed`, `transportRefused`, `transportTlsFail`, `protocolUnknownEvent`, `protocolMalformed`, `protocolVersionDrift`, `agentRefused`, `agentToolFailed`, `agentInternal`, `businessQuotaExceeded`, `businessRateLimited`, `businessAuth`, `businessForbidden`, `unknown`.

**Given** `koel_core/lib/src/error/error_classifier.dart`,
**When** I inspect it,
**Then** the abstract `ErrorClassifier` defines `KoelError classify(Object raw, StackTrace? stack, RunAgentInput input)`,
**And** `DefaultErrorClassifier` ships handling common Dart failures — `SocketException`, `HandshakeException`, `TimeoutException`, `FormatException`, generic `HttpException`/`ClientException` — mapping each to the correct `KoelErrorCode`,
**And** unhandled exception types map to `KoelErrorCode.unknown`.

**Given** a property-based test feeding 50 random raw exception instances,
**When** the classifier runs,
**Then** every output is a non-null typed `KoelError` carrying a `KoelErrorCode`,
**And** consumer switch statements over `KoelError` enforce the `koel_lints` default-branch rule.

## Story 2.4: Vendor-inline RFC 6902 JSON Patch implementation

As a Flutter/Dart developer,
I want `koel_core/lib/src/json_patch/` to ship a strict-mode RFC 6902 implementation (`JsonPatch.apply` + sealed `JsonPatchOp` types covering add/remove/replace/move/copy/test) with no external dependency,
So that `STATE_DELTA` events apply deterministically and the SDK remains free of the stale `package:json_patch` per AR-6. This story ships `JsonPatchOp` BEFORE event subtypes because `StateDeltaEvent.patches: List<JsonPatchOp>` (Story 2.6) depends on it.

**Acceptance Criteria:**

**Given** `koel_core/lib/src/json_patch/`,
**When** I list the directory,
**Then** `json_patch.dart` (exposing `JsonPatch.apply(state, patches)`) and `json_patch_op.dart` (sealed `JsonPatchOp` with `add`/`remove`/`replace`/`move`/`copy`/`test` subtypes) exist.

**Given** `koel_core/pubspec.yaml`,
**When** I inspect dependencies,
**Then** `package:json_patch` does NOT appear (per AR-6 / Bonus decision).

**Given** the official RFC 6902 conformance fixture set (downloaded into `koel_core/test/json_patch/rfc6902_fixtures/`),
**When** I run `dart test test/json_patch/`,
**Then** every fixture passes (add, remove, replace, move, copy, test ops; nested paths; array index manipulation; error cases for invalid paths / target-doesn't-exist / type mismatch),
**And** ≥ 95% line + branch coverage on `koel_core/lib/src/json_patch/`.

**Given** an invalid patch operation (e.g., remove from non-existent path),
**When** `JsonPatch.apply` is called,
**Then** it throws a `ProtocolError(code: KoelErrorCode.protocolMalformed)` using the `KoelError` types declared in Story 2.3.

## Story 2.5: `RUN_*` + `STEP_*` + `TEXT_MESSAGE_*` event subtypes

As a Flutter/Dart developer,
I want typed event subtypes for the lifecycle and text-message families — `RunStartedEvent`, `RunFinishedEvent`, `RunErrorEvent`, `StepStartedEvent`, `StepFinishedEvent`, `TextMessageStartEvent`, `TextMessageContentEvent`, `TextMessageEndEvent`, `TextMessageChunkEvent`,
So that pattern matching on the run lifecycle and streaming text is exhaustive per FR-A7.

**Acceptance Criteria:**

**Given** `koel_core/lib/src/event/run_events.dart`, `step_events.dart`, `text_message_events.dart`,
**When** I inspect the files,
**Then** each file defines one or more concrete subclasses of `AgUiEvent` matching the AG-UI `release/2026-05-26` wire format,
**And** every subtype is freezed-generated with const constructors,
**And** `RunErrorEvent.error: KoelError` field consumes the `KoelError` type from Story 2.3.

**Given** sample wire JSON for `RUN_STARTED`, `RUN_FINISHED`, `RUN_ERROR`, `STEP_STARTED`, `STEP_FINISHED`, `TEXT_MESSAGE_START`, `TEXT_MESSAGE_CONTENT`, `TEXT_MESSAGE_END`, `TEXT_MESSAGE_CHUNK` (from synthesized fixtures),
**When** the event-deserializer dispatcher processes each,
**Then** the correct subtype is produced with all fields populated,
**And** the round-trip `event → toJson() → fromJson()` returns a structurally-equal instance.

**Given** the test suite,
**When** I run `melos run test` for `koel_core`,
**Then** every subtype has at least one positive deserialization test + one round-trip test,
**And** coverage for these subtypes ≥ 90% per NFR-12.

## Story 2.6: `TOOL_CALL_*` + `STATE_*` + `MESSAGES_SNAPSHOT` event subtypes

As a Flutter/Dart developer,
I want typed event subtypes for tool calls and state synchronization — `ToolCallStartEvent`, `ToolCallArgsEvent`, `ToolCallEndEvent`, `ToolCallResultEvent`, `ToolCallChunkEvent`, `StateSnapshotEvent`, `StateDeltaEvent`, `MessagesSnapshotEvent`,
So that consumers can render tool execution and react to state changes with full type safety per FR-A7.

**Acceptance Criteria:**

**Given** `koel_core/lib/src/event/tool_call_events.dart` and `state_events.dart`,
**When** I inspect each file,
**Then** every wire-format subtype is freezed-generated with const constructors,
**And** `ToolCallChunkEvent` carries `toolCallId`, `toolCallName`, `parentMessageId`, `delta` per Addendum F.2,
**And** `StateDeltaEvent.patches: List<JsonPatchOp>` consumes the RFC 6902 op type from Story 2.4.

**Given** sample wire JSON for each of these eight event types,
**When** the deserializer processes them,
**Then** structurally-equal round-trips succeed,
**And** `StateSnapshotEvent.state` and `MessagesSnapshotEvent.messages` deserialize the embedded JSON without information loss.

**Given** coverage for these subtypes,
**When** I check the report,
**Then** it stays ≥ 90% per NFR-12.

## Story 2.7: `ACTIVITY_*` + `REASONING_*` event subtypes with `encryptedValue` bit-exact round-trip

As a Flutter/Dart developer,
I want typed event subtypes for activity and reasoning, including `REASONING_ENCRYPTED_VALUE` with a bit-exact opaque round-trip,
So that Anthropic/OpenAI reasoning replay requirements are met per FR-A9 and FR-A7.

**Acceptance Criteria:**

**Given** `koel_core/lib/src/event/activity_events.dart`,
**When** I inspect it,
**Then** `ActivitySnapshotEvent` and `ActivityDeltaEvent` exist as freezed subtypes per AG-UI spec.

**Given** `koel_core/lib/src/event/reasoning_events.dart`,
**When** I inspect the reasoning family,
**Then** the file declares `ReasoningStartEvent`, `ReasoningEndEvent`, `ReasoningMessageStartEvent`, `ReasoningMessageContentEvent`, `ReasoningMessageEndEvent`, `ReasoningMessageChunkEvent`, and `ReasoningEncryptedValueEvent`,
**And** no `THINKING_*` aliases are present per PRD §6.1 / F-A7.

**Given** `ReasoningEncryptedValueEvent`,
**When** I inspect its fields,
**Then** it carries `entityId: String`, `subtype: String` ("tool-call" or "message"), `encryptedValue: Uint8List`, and `encryptedValueBase64: String` (preserving the original wire string),
**And** the codec round-trip `wire-base64 → Uint8List + base64 string → wire-base64` is byte-equal,
**And** a property-based test on 100 random byte sequences confirms the round-trip is bit-exact.

**Given** a downstream `RunAgentInput.reasoningEcho` produced from a `ChatState` carrying these blobs,
**When** the next run posts to a backend,
**Then** the echoed bytes match the originally-received bytes byte-for-byte (verified in Epic 5 with real backend fixtures; verified here via MockAgent in Story 3.1).

## Story 2.8: `RAW` + `CUSTOM` events + 28-type integration sweep

As a Flutter/Dart developer,
I want `RawEvent` and `CustomEvent` typed subtypes plus an integration sweep that exercises all ~28 event types together,
So that the sealed `AgUiEvent` union closes out the AG-UI `release/2026-05-26` registry per FR-A7.

**Acceptance Criteria:**

**Given** `koel_core/lib/src/event/raw_event.dart` and `custom_event.dart`,
**When** I inspect them,
**Then** each subtype is freezed with the wire-defined fields (`RawEvent.payload: Map<String, dynamic>`; `CustomEvent` per AG-UI spec).

**Given** a synthesized fixture file `koel_core/test/event/full_event_sweep.jsonl` containing one canonical example of every ~28 event types,
**When** I run the sweep test,
**Then** each line deserializes to a non-`Unknown` typed subtype,
**And** round-tripping each event through `toJson() → fromJson()` produces structural equality,
**And** the dispatcher `eventTypeRegistry` maps every wire-type string to its concrete subtype with no orphans.

**Given** the consumer-side switch over `AgUiEvent` (in a test file that intentionally omits `default:`),
**When** `dart analyze` runs with `package:koel_lints/koel.yaml`,
**Then** `exhaustive_switch_must_have_default` fires with error severity per FR-A12 (validated end-to-end here, not just in koel_lints fixtures).

## Story 2.9: `Interceptor` + `InterceptorChain` framework (no built-ins)

As a Flutter/Dart developer,
I want the `Interceptor` interface + `InterceptorChain.proceed()` mechanism in `koel_core` with no built-ins (those live in `koel_http`),
So that backend bridges and consumer code can compose cross-cutting behavior around `Stream<AgUiEvent>` execution per FR-A4.

**Acceptance Criteria:**

**Given** `koel_core/lib/src/agent/interceptor.dart`,
**When** I inspect it,
**Then** `abstract class Interceptor` defines `Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input)`,
**And** `class InterceptorChain` exposes `Stream<AgUiEvent> proceed(RunAgentInput input)` to call the next interceptor or the underlying agent.

**Given** an ordered list of three test interceptors `[A, B, C]` wrapping a `MockAgent`,
**When** a run executes,
**Then** the order of invocation is `A.intercept → B.intercept → C.intercept → MockAgent.run`,
**And** unwinding follows the inverse path,
**And** an interceptor that throws causes the chain to short-circuit by emitting `RunErrorEvent` via the classifier (no uncaught throw).

**Given** an interceptor that returns a transformed stream,
**When** the chain runs,
**Then** the transformation is observable in the final emitted events.

## Story 2.10: `AgentSubscriber` callback bag

As a Flutter/Dart developer,
I want `abstract class AgentSubscriber` with per-event callback hooks all defaulted to empty,
So that observers (devtools, telemetry, custom hooks) attach without forcing implementation of every callback per FR-A10.

**Acceptance Criteria:**

**Given** `koel_core/lib/src/agent/agent_subscriber.dart`,
**When** I inspect the class,
**Then** every callback method from Addendum A.1 exists with `void` return and empty default body: `onRunStart`, `onRunFinish`, `onRunError`, `onStepStart`, `onStepFinish`, `onTextChunk`, `onToolCall`, `onToolResult`, `onStateDelta`, `onReasoning`, `onActivity`, `onUnknownEvent`.

**Given** a custom subscriber overriding only `onRunStart` + `onUnknownEvent`,
**When** a run flows through the pipeline,
**Then** the two overrides fire on matching events,
**And** the unoverridden callbacks remain no-ops without exception.

**Given** multiple subscribers attached to `KoelClient`,
**When** an event fires,
**Then** every subscriber's matching callback executes in registration order,
**And** an exception thrown in one subscriber does not prevent subsequent subscribers from running (subscriber-isolation contract).

## Story 2.11: 4-stage event pipeline (chunks → verify → apply → transform)

As a Flutter/Dart developer,
I want the four pipeline stages declared as pure `StreamTransformer<AgUiEvent, AgUiEvent>` instances in `koel_core/lib/src/pipeline/`, composed in the fixed order chunks → verify → apply → transform,
So that every consumer of the pipeline sees identical canonical events with reducer-folded state per FR-A11 and Addendum C.1.

**Acceptance Criteria:**

**Given** `koel_core/lib/src/pipeline/`,
**When** I list the directory,
**Then** `chunks_stage.dart`, `verify_stage.dart`, `apply_stage.dart`, `transform_stage.dart` all exist,
**And** each defines a `StreamTransformer<AgUiEvent, AgUiEvent>` exported as a top-level value or factory.

**Given** the `chunks` stage processing a `TOOL_CALL_CHUNK` sequence,
**When** the chunk synthesizer runs,
**Then** the first chunk emits `ToolCallStartEvent`, subsequent chunks emit `ToolCallArgsEvent`, and the trailing marker emits `ToolCallEndEvent` per Addendum F.2,
**And** the same behavior applies to `TEXT_MESSAGE_CHUNK`.

**Given** the `verify` stage processing a stream containing a `ToolCallEndEvent` without a matching `ToolCallStartEvent`,
**When** the offending event arrives,
**Then** the stage drops it and emits a `RunErrorEvent(error: ProtocolError(...))` per Addendum F.1,
**And** all other documented verify rules (state_delta empty patches, REASONING_ENCRYPTED_VALUE bytes/base64 mismatch, etc.) are tested.

**Given** the four-stage pipeline composed via `events.transform(chunks).transform(verify).transform(apply).transform(transform)`,
**When** I run an integration test that feeds the full 28-event sweep,
**Then** the output stream contains only canonical events with the reducer state folded correctly,
**And** stage order is locked (assertion that swapping any two stages breaks at least one test).

## Story 2.12: `ChatState` + `ChatStateReducer` + `DefaultChatStateReducer` + `ComposedReducer` + reducer purity test

As a Flutter/Dart developer,
I want `ChatState` (freezed-immutable, const-comparable) plus the reducer hierarchy (`abstract ChatStateReducer`, `DefaultChatStateReducer`, `ComposedReducer`) with reducer purity verified by test,
So that the reduce step in the pipeline is replaceable, composable, and Riverpod-friendly per FR-D2.

**Acceptance Criteria:**

**Given** `koel_core/lib/src/state/chat_state.dart`,
**When** I inspect the freezed class,
**Then** it carries `messages`, `pendingMessage`, `pendingToolCalls`, `state`, `reasoningEcho`, `error`, and `phase: RunPhase` with const constructor per Addendum A.1,
**And** `RunPhase` enum lists `idle`, `running`, `stepRunning`, `error`, `cancelled`.

**Given** `koel_core/lib/src/state/chat_state_reducer.dart`,
**When** I inspect it,
**Then** `abstract class ChatStateReducer { ChatState reduce(ChatState state, AgUiEvent event); }` is declared,
**And** `DefaultChatStateReducer` handles every event family appropriately (`RUN_*` → phase transitions; `TEXT_MESSAGE_*` → message accumulation; `TOOL_CALL_*` → pending tool tracking; `STATE_*` → JSON-patch application via Story 2.4; `REASONING_ENCRYPTED_VALUE` → `reasoningEcho` accumulation; `RunErrorEvent` → error field; `UnknownAgUiEvent` → no-op),
**And** `ComposedReducer(List<ChatStateReducer>)` composes reducers left-to-right.

**Given** `koel_core/test/state/reducer_purity_test.dart`,
**When** I run it,
**Then** the test confirms `reduce(s, e)` never mutates `s.messages`/`s.state`/`s.reasoningEcho` (asserts they're identical-pointer or fully-immutable post-call) per architecture convention §3,
**And** repeated `reduce(s, e)` invocations produce structurally-equal results (idempotence on idempotent events).

## Story 2.13: `SessionStorage` interface + `InMemorySessionStorage` + `StateConflict` + `LastWriterWinsResolver`

As a Flutter/Dart developer,
I want the `SessionStorage` interface, `InMemorySessionStorage` reference impl, `StateConflict` value type, and `LastWriterWinsResolver` default,
So that consumers can persist `ChatState` across sessions and handle delta-vs-snapshot conflicts per FR-D1 (interface + in-memory portion) and FR-A8.

**Acceptance Criteria:**

**Given** `koel_core/lib/src/session/session_storage.dart`,
**When** I inspect it,
**Then** `abstract class SessionStorage` declares `Future<void> save(String threadId, ChatState state)`, `Future<ChatState?> load(String threadId)`, `Future<void> delete(String threadId)`, `Future<List<String>> listThreads()`.

**Given** `koel_core/lib/src/session/in_memory_session_storage.dart`,
**When** I exercise it,
**Then** save/load/delete/listThreads round-trip correctly,
**And** the storage holds only an in-process `Map` (no I/O).

**Given** `koel_core/lib/src/state/state_conflict.dart`,
**When** I inspect it,
**Then** `StateConflict` is freezed with `incomingPatches: List<JsonPatchOp>`, `localState: Map<String, dynamic>`, `snapshotState: Map<String, dynamic>`,
**And** `abstract class StateConflictResolver` declares `Map<String, dynamic> resolve(StateConflict conflict)`,
**And** `LastWriterWinsResolver implements StateConflictResolver` ships as the default (applies incoming patches verbatim).

**Given** the apply stage detects a STATE_DELTA whose patches reference a path mutated locally since the last STATE_SNAPSHOT,
**When** the configured `StateConflictResolver` runs,
**Then** the resolver's output replaces the conflicting state slice in the next `ChatState` per Addendum C.1 step 3.

## Story 2.14: `KoelClient` + `ChatSession` 3-layer API + `runRaw` escape hatch

As a Flutter/Dart developer,
I want the top-level `KoelClient` non-singleton class wiring `AbstractAgent`, interceptor chain, subscribers, classifier, conflict resolver, backpressure policy, and `devtoolsBufferSize`, plus the `ChatSession` middle-layer API and `runRaw` power-user escape hatch,
So that the three-layer API surface from FR-A2 + FR-D3 is consumable end-to-end with a `MockAgent`.

**Acceptance Criteria:**

**Given** `koel_core/lib/src/client/koel_client.dart`,
**When** I inspect the constructor,
**Then** it matches Addendum A.1: `KoelClient({required AbstractAgent agent, SessionStorage? sessionStorage, ChatStateReducer? reducer, List<Interceptor>? interceptors, List<AgentSubscriber>? subscribers, ErrorClassifier? errorClassifier, StateConflictResolver? stateConflictResolver, int devtoolsBufferSize = 1000, BackpressurePolicy backpressure = BackpressurePolicy.pauseUpstream})`,
**And** `ChatSession newSession({String? threadId, ChatState? initial})` returns a fresh session,
**And** `Stream<AgUiEvent> runRaw(RunAgentInput input)` returns the post-pipeline stream without reducer / persistence / controller binding (per F-A2 layer 3),
**And** `dispose()` cancels all active sessions and releases subscribers/interceptors.

**Given** `koel_core/lib/src/client/chat_session.dart`,
**When** I inspect the API,
**Then** `ChatSession` exposes `threadId`, `state`, `Stream<ChatState> stream` (broadcast per architecture §4), `Stream<AgUiEvent> events` (post-pipeline), `Future<void> send(String content, {List<ToolDefinition>? tools})`, `void cancel()`, `Future<void> clear()`, `Future<void> persist()`, `void dispose()`.

**Given** an integration test wiring `KoelClient(agent: MockAgent.fromEvents(<28-event sweep>))` + a fresh `ChatSession`,
**When** I `await session.send("hello")` and consume `session.stream`,
**Then** the final emitted `ChatState` reflects the full reducer-folded result,
**And** subscribers fire on every event,
**And** interceptors execute in the registered order,
**And** subsequent `session.cancel()` flips `phase` to `RunPhase.cancelled` immediately.

**Given** multiple `KoelClient` instances in a single test process,
**When** each issues independent sessions,
**Then** no global state leaks between clients (verified by interleaved-run test) per FR-D3.

## Story 2.15: Performance baselines + dartdoc + barrel finalize

As a release manager,
I want `koel_core` to ship perf bench harnesses (`reducer_bench.dart`, `cold_start_bench.dart`) capturing v1.0.0 baselines + every public symbol carrying a contract-form dartdoc + a finalized barrel `lib/koel_core.dart`,
So that NFR-2 + NFR-4 regression-relative SLOs are enforceable and the 1.x public contract is sealed per AR-15 + AR-21 + NFR-13.

**Acceptance Criteria:**

**Given** `koel_core/test/perf/reducer_bench.dart`,
**When** I run `dart test test/perf/reducer_bench.dart --reporter=expanded`,
**Then** the harness measures p99 reduce-time per event across the synthesized 28-event sweep and writes baseline numbers to `koel_core/test/perf/baselines/reducer_bench.json`,
**And** subsequent runs compare against the baseline and fail when regression > 10% per NFR-2.

**Given** `koel_core/test/perf/cold_start_bench.dart`,
**When** I run it,
**Then** it measures the time from `KoelClient(...)` constructor return to first event subscription readiness against `MockAgent.empty`,
**And** writes baseline to `cold_start_bench.json` with the same > 10% regression gate per NFR-4.

**Given** every public symbol in `lib/koel_core.dart`,
**When** I run `dart doc`,
**Then** every exported class, method, getter, enum value carries a contract-form dartdoc (one-line summary + when-to-use / when-not / error cases / example) per architecture convention §6 + PRD §13 D-2,
**And** `dart doc` exits 0 with no missing-doc warnings.

**Given** `lib/koel_core.dart`,
**When** I inspect the barrel,
**Then** it exports exactly the surface listed in PRD §9 + Addendum A.1 — no more, no less,
**And** `dart_apitool extract` produces a baseline diffable in Epic 9 per AR-12,
**And** `melos run analyze` exits 0 across the package per NFR-13.

**Given** the full `koel_core` test suite,
**When** I run `melos run test:coverage` for the package,
**Then** line + branch coverage ≥ 90% per NFR-12.

---
