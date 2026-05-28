---
title: koel v1 PRD — API Discipline & Spec Completeness Review
reviewer: parent-agent (API discipline lens)
target: prd.md + addendum.md
created: 2026-05-27
verdict: NOT READY to freeze as 1.x contract; PRD is close to architect-ready but has ~12 substantive gaps that should close before downstream handoff.
---

# Part I — API Discipline Findings

## 1. One-way-door risk (per public symbol)

The §9 list + addendum §A names are mostly defensible, but several symbols are not nailed down enough to ship as a 1.x contract.

### 1.1 HIGH — `KoelClient.run(RunAgentInput)` is a duplicate escape hatch

*Location:* Addendum §A.1, line 40 (`Stream<AgUiEvent> run(RunAgentInput input); // raw escape hatch (F-A2 layer 3)`).

**Issue.** `KoelClient.run` and `AbstractAgent.run` both exist and both return `Stream<AgUiEvent>`. The PRD's "three-layer API" (F-A2) intends layer-3 as `client.run(...)`, but the natural Dart instinct is `client.agent.run(...)`. Two public ways to do the exact same thing — and which one runs interceptors? `KoelClient.run` presumably does; `AbstractAgent.run` (on the bare agent) does not. That semantic difference is invisible at the type level and will be misused.

**Resolution.** Either (a) make `AbstractAgent` non-public (it's the SPI for adapter authors, not a consumer surface) and rename `KoelClient.run` → `KoelClient.runRaw`, or (b) document that `client.run` is the only "runs through interceptors" path and that handing a bare `AbstractAgent` to consumer code is a programmer error. Pick one; today both are public and the relationship is ambient.

### 1.2 HIGH — `RunAgentInput.runId` ownership unspecified

*Location:* Addendum §A.1, lines 45-54.

**Issue.** `runId` is `final String runId` — required, no factory. Who generates it? The consumer? `ChatSession.send`? The agent? If consumers must mint runIds, every consumer reinvents UUID generation. If `ChatSession.send` mints one internally, the field shouldn't be required on the public `RunAgentInput` constructor — it should default to an internal generator.

**Resolution.** Add to addendum: "runId is minted by `ChatSession.send`; consumers calling `client.run(RunAgentInput(...))` must supply their own. Recommended generator: `Uuid().v4()`." Or make it nullable with an internal default. Either way, the contract is currently ambiguous.

### 1.3 HIGH — `SessionStorage.listThreads()` appeared in addendum but not PRD §9

*Location:* Addendum §A.1, line 160 vs PRD §9 line 217.

**Issue.** PRD §9 says `SessionStorage` has `save`, `load`, `delete`. Addendum adds `listThreads()`. These must agree — they're the same contract.

**Resolution.** Reconcile. If `listThreads` is in, add to PRD §9. Also: pagination? Sort order? Returning `List<String>` precludes ever paging without a 2.0.

### 1.4 MEDIUM — `WidgetResolver._registry` field is leaked via constructor parameter type

*Location:* Addendum §A.6, lines 318-325.

**Issue.** `WidgetResolver(this._registry, {this.onUnknown})` takes a positional `Map<String, Widget Function(...)>` and stores it as `_registry`. Two issues: (a) `Map` is mutable — consumer can mutate after construction; koel sees the mutation. (b) The constructor takes a positional argument named with a leading underscore, which is Dart-illegal for cross-package field initialization — this won't actually compile as written. Also: positional-first is inconsistent with every other class in the SDK (`HttpAgent`, `KoelChatController`, etc. are named-only).

**Resolution.** `WidgetResolver({required Map<String, Widget Function(BuildContext, ToolCallEvent)> registry, Widget Function(BuildContext, ToolCallEvent)? onUnknown})` and `_registry = Map.unmodifiable(registry)` internally. Plus add `WidgetResolver.builder()` for fluent registration.

### 1.5 MEDIUM — `ChatState.error: KoelError?` contradicts F-A5

*Location:* Addendum §A.1, line 78.

**Issue.** F-A5 declares "errors ride the event stream as `RUN_ERROR`." But `ChatState` carries `error: KoelError?` as a top-level field — which means the reducer extracts the error onto state, and consumers naturally read `state.error` instead of pattern-matching on `RunErrorEvent`. That's fine, but the contract is unstated: when does `error` clear? On `send()`? On `RunStartedEvent`? On `clear()`? Is `error` only the latest, or accumulated?

**Resolution.** Specify lifecycle of `ChatState.error` explicitly in addendum: "Cleared on each new `RunStartedEvent`; only the latest error is retained; persists across `send()` calls until the next successful run start."

### 1.6 MEDIUM — Mutable collections returned from immutable types

*Location:* Addendum §A.1, lines 72-81 (`ChatState`); freezed defaults to non-immutable lists unless wrapped.

**Issue.** `@Default([])` on `List<Message> messages` gives a mutable list. `freezed` does not produce `UnmodifiableListView`. A consumer can do `state.messages.add(...)`, mutating the snapshot, and break reducer equality semantics.

**Resolution.** Document that `ChatState` requires `BuiltList`/`IList`/manual `List.unmodifiable` wrapping. Pick a stance and pin it — this is a 1.x contract decision (do we depend on `package:fast_immutable_collections`? on `package:built_value`?). Pretending `List<T>` is immutable is the classic Dart trap.

### 1.7 MEDIUM — `abstract class AbstractAgent` vs `interface class`

*Location:* PRD §9 line 207; Addendum A.1 line 21.

**Issue.** `abstract class AbstractAgent` allows subclassing — consumers will `extends AbstractAgent` to share base logic. But `HttpAgent extends AbstractAgent` is the only intended path; mixing of behavior between `HttpAgent` and an `extends AbstractAgent` is a recipe for diamond-inheritance gotchas when koel adds methods. Dart 3 has `interface class` for "implement-only, no extend."

**Resolution.** `interface class AbstractAgent` so consumers can only `implements`, never `extends`. Force them through composition. This is the kind of one-way-door choice that is much cheaper to make now than at 2.0.

### 1.8 LOW — `AgnoAgent extends HttpAgent` (and `LangGraphAgent extends HttpAgent`) leaks `HttpAgent`'s constructor surface

*Location:* Addendum §A.3-A.4.

**Issue.** Subclassing `HttpAgent` means every public method/field on `HttpAgent` is also on `AgnoAgent`. Consumers can call `agnoAgent.synthesizeChunks` or pass `connectTimeout`. Is that intended? If `AgnoAgent` is supposed to be a curated façade, it should `implements AbstractAgent` and *contain* an `HttpAgent`. If it's supposed to be a configured `HttpAgent`, that's fine but should be stated.

**Resolution.** Decide: façade-via-composition (recommended for adapter contracts) or thin-subclass. Document.

## 2. Naming consistency

### 2.1 HIGH — `Event` suffix inconsistency

*Location:* Addendum §A.1, lines 88-124.

**Issue.** Every concrete event class has the `Event` suffix (`RunStartedEvent`, `TextMessageContentEvent`, etc.) — but the sealed parent is `AgUiEvent`. So `AgUiEvent` → `RunStartedEvent` (good). But the AG-UI wire names are `RUN_STARTED`, `TEXT_MESSAGE_CONTENT`. Mapping is by-convention: `SCREAMING_SNAKE` → `PascalCase + Event` suffix. That mapping is not specified anywhere. Two-way conversion logic depends on this convention being stable forever.

**Resolution.** Specify the mapping rule explicitly in addendum §A or a new §F.5 (alongside chunks rules). Provide the canonical name table for all 28 events so parser and consumer implementations agree.

### 2.2 MEDIUM — `RunPhase` vs `RunStatus` ambiguity

*Location:* Addendum §A.1 line 83.

**Issue.** `enum RunPhase { idle, running, stepRunning, error, cancelled }` — but `stepRunning` is awkward. AG-UI has separate `STEP_*` events; is `stepRunning` "we got a `STEP_STARTED` event"? Then what about between steps? The enum is leaking implementation into the API.

**Resolution.** Either drop `stepRunning` (consumers infer from event stream if they care) or rename to clarify: `RunPhase { idle, running, finished, error, cancelled }` with step info exposed as `int currentStep` separately.

### 2.3 LOW — Interceptor naming: `EventTraceInterceptor` vs `LoggingInterceptor`

*Location:* Addendum §A.2.

**Issue.** Both log. What's the difference? Logging logs events to the Dart logging framework; EventTrace dumps to a Sink. Names don't convey this — they read as synonyms.

**Resolution.** Rename `EventTraceInterceptor` → `TraceSinkInterceptor` (it writes to a `Sink<TraceEntry>`), and document the relationship: "Use `Logging` for human-readable dev logs; use `TraceSink` for structured machine-readable export to your observability backend."

### 2.4 LOW — `KoelClient.newSession()` factory naming

*Location:* Addendum §A.1 line 39.

**Issue.** `newSession` is an effective-Java-style verb. Dart idiom is `createSession` or factory constructor `ChatSession.forClient(client)`. Also: does `newSession` return a fresh empty session, or restore from storage if `threadId` exists?

**Resolution.** Either `KoelClient.createSession({...})` returning a fresh session, plus `KoelClient.restoreSession(threadId)` returning `Future<ChatSession?>` from `SessionStorage`. Two methods, two clear contracts.

## 3. Symmetry

### 3.1 HIGH — `connect`/`disconnect` lifecycle is asymmetric

*Location:* Addendum §A.2 `HttpAgent` lines 187-203.

**Issue.** `HttpAgent` has `onConnect`, `onDisconnect`, `onReconnectAttempt` callbacks. No explicit `connect()` / `disconnect()` methods. So connection is implicit (happens inside `run()`), but disconnection has a callback. Inconsistent. Plus: there's no way to pre-warm a connection or close one without canceling a stream subscription. For long-lived clients this matters.

**Resolution.** Either add explicit `Future<void> connect()` / `Future<void> disconnect()` (symmetric, lets consumers pool), or remove the lifecycle callbacks and surface connection state via the event stream as `MetaEvent`s (consistent with F-A5 "errors as events"). The current half-and-half is the worst of both.

### 3.2 MEDIUM — `send`/`cancel` is on `ChatSession` but no `pause`/`resume`

*Location:* Addendum §A.1 `ChatSession` lines 56-68.

**Issue.** `ChatSession` exposes `send`, `cancel`, `clear`, `persist`, `dispose`. Missing: any mechanism to pause stream consumption (the backpressure policy applies at the transport, not the session). Also missing: `restore()` — addendum shows `persist()` but not its inverse. `clear()` is destructive (deletes state); `restore()` would be non-destructive read-from-storage.

**Resolution.** Add `restore()` for symmetry with `persist()`. Decide whether session-level pause is a v1 feature (probably no — defer to consumer's `StreamSubscription.pause()`) and document the decision.

### 3.3 MEDIUM — `AgentSubscriber.onToolCall(start, end?)` is asymmetric and weird

*Location:* Addendum §A.1 line 173.

**Issue.** `onToolCall(ToolCallStartEvent start, ToolCallEndEvent? end)` — when is `end` non-null? Is this called twice (once with `(start, null)`, once with `(start, end)`)? Or once when end arrives? Either way, the callback signature is unusual: most callback bags are one-event-per-method.

**Resolution.** Split into `onToolCallStart(ToolCallStartEvent e)` and `onToolCallEnd(ToolCallEndEvent e)` plus `onToolResult(ToolCallResultEvent e)` (already present). Consistent with the rest of the subscriber.

### 3.4 LOW — Subscriber doesn't cover all event subtypes

*Location:* Addendum §A.1 lines 166-178.

**Issue.** Subscriber has callbacks for run, step, text-chunk, tool-call, tool-result, state-delta, reasoning, unknown. Missing: snapshot events (`MessagesSnapshotEvent`, `StateSnapshotEvent`, `ActivitySnapshotEvent`, `ActivityDeltaEvent`), `RawEvent`, `CustomEvent`. Either subscriber should expose all 28 (a lot of API surface) or document that subscriber is intentionally a curated subset and reference the raw stream for full access.

**Resolution.** State the policy. Recommend curated subset (current shape) plus `void onAny(AgUiEvent e) {}` catch-all for telemetry use cases. That's one method instead of 20.

## 4. Error-channel discipline

### 4.1 HIGH — `sealed class KoelError implements Exception` is a contradiction

*Location:* Addendum §A.1 line 146.

**Issue.** F-A5 says errors ride the event stream (good). But `KoelError implements Exception` invites `throw`. And the addendum doesn't tell adapter authors when to throw vs when to emit a `RunErrorEvent`. Without a clear contract, every adapter will pick its own answer.

**Resolution.** State explicitly:
> "Adapter authors emit `RunErrorEvent(error: KoelError(...))` for all protocol/transport/agent/business errors. The `Exception` marker is for compatibility with `Future.catchError` only — koel itself throws `KoelError` only for programmer errors (null required parameters, etc.). Adapter authors must not throw; they must emit."

Without this, the error channel discipline declared in F-A5 is aspirational.

### 4.2 MEDIUM — `Stream<AgUiEvent>` can still emit errors via `StreamController.addError`

*Location:* Throughout `koel_core`, `koel_http`.

**Issue.** A `Stream<AgUiEvent>` can carry stream errors (`onError` handler) separately from emitting `RunErrorEvent` values. If `HttpAgent` ever does `controller.addError(...)`, the consumer's `listen` gets a stream error, not an event. That's two error channels in one stream.

**Resolution.** Add an NFR: "koel-emitted streams must never invoke `addError`. All errors flow as `RunErrorEvent` values. The stream-error channel is reserved for unrecoverable programmer errors (null in non-null places, etc.) and propagates as Dart `Error`, not `Exception`."

### 4.3 LOW — `ToolHandlerTestHarness.invoke` returns `Future<ToolCallResultEvent>` but how are errors expressed?

*Location:* Addendum §A.9 line 367.

**Issue.** If the tool handler throws, does the harness throw? Emit a `RunErrorEvent`? Return a `ToolCallResultEvent` with an error field? Unspecified.

**Resolution.** Define: probably `ToolCallResultEvent` has a nullable error field, and the harness surfaces the same shape the real pipeline would. Add to addendum §A.9.

## 5. Configuration explosion

### 5.1 HIGH — `HttpAgent` constructor already has 9 parameters

*Location:* Addendum §A.2 lines 187-199.

**Issue.** `Uri url`, `http.Client? client`, `List<Interceptor>? interceptors`, `Duration connectTimeout`, `Duration readTimeout`, `RetryPolicy? retry`, `bool synthesizeChunks`, plus 3 lifecycle callbacks = 10 params at v1 with zero room to grow. Future-1 protobuf adds a transport switch; SSE-on-web fallback wants an option; auth headers want a closure. Constructor will be 15 params by 1.5.

**Resolution.** Introduce `HttpAgentConfig` (a freezed data class) and accept `HttpAgent({required Uri url, HttpAgentConfig config = const HttpAgentConfig()})`. Config is one object that can grow. Lifecycle callbacks move to a separate `lifecycle: HttpAgentLifecycle?` or are dropped in favor of a `MetaEvent` channel (see §3.1).

### 5.2 MEDIUM — `KoelClient` constructor has 7 parameters

*Location:* Addendum §A.1 lines 28-37.

**Issue.** `agent`, `sessionStorage`, `reducer`, `interceptors`, `subscribers`, `devtoolsBufferSize`, `backpressure`. Already at 7; will grow with telemetry knobs, logger injection, etc.

**Resolution.** Same fix as §5.1: `KoelClient({required AbstractAgent agent, KoelClientConfig config = const KoelClientConfig()})`. Future knobs added to config don't touch the constructor.

### 5.3 MEDIUM — `RetryInterceptor` has 5 params; `RetryPolicy` is also a parameter on `HttpAgent`

*Location:* Addendum §A.2 lines 195, 212-220.

**Issue.** Two ways to configure retries: pass `RetryPolicy` to `HttpAgent`, or include a `RetryInterceptor` in `interceptors`. Which wins? Both?

**Resolution.** Remove `RetryPolicy?` from `HttpAgent`. There is exactly one way to configure retries: register a `RetryInterceptor`. (Aligns with the "interceptors are the single composition primitive" framing in F-A4.)

## 6. Behavioral gaps

### 6.1 HIGH — `verify` stage semantics on dropped events

*Location:* Addendum §F.1.

**Issue.** "Drop the offending event and emit `ProtocolError`" — but does the stream continue? Does the run abort? Is the drop visible to the consumer (as a `RunErrorEvent`) or silent? Two implementations could diverge: one drops + continues, one drops + aborts.

**Resolution.** State: "Verify failures emit a `RunErrorEvent` with `ProtocolError`; the stream continues. To abort, the consumer cancels their subscription. Verify is fail-soft, not fail-fast."

### 6.2 HIGH — `chunks` synthesis ordering vs `verify`

*Location:* Addendum §C.1 vs §F.1.

**Issue.** `verify` runs first; `chunks` synthesizes after. But verify checks "`TOOL_CALL_END` must have matching `TOOL_CALL_START`". If chunks synthesizes the START, the START doesn't exist *before* verify. So verify must run *after* chunks for chunk-synthesized streams. The pipeline order in F-A11 is wrong, or the verify rules apply to a different stage.

**Resolution.** Reorder: `chunks → verify → apply → transform`. Or split verify into "pre-chunks verify" (wire-format sanity) and "post-chunks verify" (semantic sanity). State which it is.

### 6.3 HIGH — `ReasoningEncryptedValueEvent.encryptedValue: Uint8List` vs F-A9 "verbatim round-trip"

*Location:* Addendum §A.1 line 115; F-A9.

**Issue.** F-A9 says reasoning encrypted blobs round-trip verbatim, including being echoed on subsequent runs. But there's no API for "echo back on next run" — `RunAgentInput.messages` carries `List<Message>` but the encrypted blob isn't attached to a message. Where is it stored? Where does it attach to the next request?

**Resolution.** Specify: either `ChatState` carries a `reasoningEcho: Map<messageId, Uint8List>` field that the next `RunAgentInput` includes (via `forwardedProps` or a dedicated field), or `Message` itself has an optional `encryptedValue` slot. Either way: the path from "received encryptedValue" → "next request body" must be on paper. Today it's a behavior gap.

### 6.4 MEDIUM — `cancel()` semantics on a session mid-tool-call

*Location:* Addendum §A.1 (`ChatSession.cancel()`); §C.2.

**Issue.** §C.2 covers TCP-close cancellation. But what happens to in-flight `pendingToolCalls`? Does `ChatState.pendingToolCalls` clear? Does each pending get a synthetic `ToolCallEndEvent`? Does the reducer see a synthetic `RunErrorEvent`? Two implementations would diverge.

**Resolution.** Specify: on cancel, the reducer emits a synthetic `RunPhase.cancelled` transition; pending tool calls remain in state with a `cancelled: true` flag; no synthetic events are generated upstream. State-machine on paper.

### 6.5 MEDIUM — `SessionStorage.save` is `Future<void>` — when does it return?

*Location:* Addendum §A.1 line 158.

**Issue.** After write-to-disk? After fsync? Is it atomic? If `save` is in-flight and `delete` is called, what wins?

**Resolution.** Define ordering: "All `SessionStorage` calls are serialized per `threadId`. `save` completes after durable write. Concurrent `save`s for the same threadId apply in call order; the last `save` wins."

### 6.6 LOW — `ConformanceRunner.runAgainst` return type `ConformanceReport` is unspecified

*Location:* Addendum §A.9 line 371.

**Issue.** `ConformanceReport` is referenced but never typed. What does it contain? Pass/fail per event? A diff?

**Resolution.** Specify the type signature in addendum §A.9 or add §F.5.

---

# Part II — Spec Completeness Findings

## 7. Architect handoff

### 7.1 HIGH — Threading / isolate model is unspecified

**Issue.** N-5 says "no protocol work on the UI thread; reducer + parser stay off the main isolate via `Stream` async semantics." But `Stream` is single-threaded on the event loop by default — async ≠ off-isolate. To genuinely move work off the main isolate, you need `Isolate.run` or `compute()`. The PRD declares the requirement but doesn't specify the mechanism.

**Resolution.** Architect needs: (a) which work runs on what isolate; (b) whether `koel_http` spawns a parser isolate; (c) how `Stream<AgUiEvent>` crosses the isolate boundary (only sendable types). Add §C.6 "Isolate model" to addendum.

### 7.2 HIGH — Inter-package internal dependencies not specified

**Issue.** PRD §7 says `koel_widgets` depends on `koel_flutter` which depends on `koel_core` + `koel_http`. But `koel_http` depending on `koel_core` means `koel_core` cannot reference any types defined in `koel_http`. The line where `SseParser` lives in `koel_http` but consumes byte streams — what's the relationship between `SseParser` output and the pipeline stages defined in `koel_core`? Are pipeline stage classes exported from `koel_core` and instantiated inside `koel_http`?

**Resolution.** Add a "module-level architecture" diagram or table showing which type belongs to which package and what crosses package boundaries. Architect will need this to assemble interfaces.

### 7.3 MEDIUM — `koel_widgets` ↔ `koel_flutter` boundary

**Issue.** `koel_widgets` ships `MessageBubble`, `ChatInput`, `FollowUpList`. Do they consume `ChatState` directly? Or just `MessageSegment`? Or do they take `KoelChatController`? The widget package's API contract with the binding layer isn't specified.

**Resolution.** Specify whether `koel_widgets` widgets are state-aware (consume `KoelChatController`) or stateless (take props). Recommend stateless props for composability.

### 7.4 LOW — DevTools extension binary distribution

**Issue.** DevTools extensions ship pre-built JS bundles alongside the Dart code. Is the build pipeline for this in `koel_devtools` or out-of-band? Architect needs to plan.

**Resolution.** Note this in addendum §G.

## 8. Epic-planner handoff

### 8.1 HIGH — No explicit feature → package mapping for sequencing

**Issue.** Features F-A* live in `koel_core`; F-B* in `koel_http`; F-C* in adapters; etc. Mostly inferable from prefix and feature description. But: where does `WidgetResolver` live (`koel_flutter` per addendum, but feature group is E)? Where does `ChatStateReducer` live — `koel_core` (per §9) but its implementation `DefaultChatStateReducer` is presumably also there. Epic-planner needs a tabular map.

**Resolution.** Add §6.3 "Feature → Package matrix" showing every F-* in which package's deliverable. Drives epic sequencing (foundations first, adapters second, Flutter glue third).

### 8.2 HIGH — Conformance fixtures (F-G1) require live captures from 3 backends; no plan

**Issue.** "Real SSE traces captured live from AG-UI dojo, agno, langgraph." Capturing these requires running each backend, hitting it with a Dart test harness, recording. No epic sequencing for the capture work, no record of who/when captures happen, no statement of which captures must exist *before* `koel_core` test work can begin. This is a critical-path dependency.

**Resolution.** Add an epic prerequisite: "E0 — Fixture Capture" must complete before E1 (`koel_core` implementation) can begin its test phase. Specify infra: a `scripts/capture-fixtures.dart` that runs all three captures and emits to `koel_test/fixtures/`. The PRD acknowledges fixtures but doesn't sequence them.

### 8.3 MEDIUM — `koel_runtime` has no transport spec

**Issue.** F-C3 says "GraphQL bridge to CopilotKit Next.js runtime, implements `generateCopilotResponse` streaming client." But the GraphQL schema is not referenced. The translation rules (GraphQL response shape → AG-UI event shape) are not specified. Independent of `koel_http`? Then where does it parse SSE-over-GraphQL streams from?

**Resolution.** Either add a sub-spec or reference the upstream `@copilotkit/runtime` GraphQL schema explicitly. Epic-planner can't sequence `koel_runtime` work without knowing the input/output shape.

### 8.4 LOW — Sample app scope

**Issue.** §6.1 mentions "sample app demonstrating quickstart via meta-package, generic chat scenarios only." Generic chat covers maybe 10% of the feature surface (interceptors, devtools integration, tool-calls, state-delta, reasoning round-trip). What demonstrates the rest?

**Resolution.** Either expand sample app scope or add `/example` directory requirements (already in D-4) with explicit list of examples that must ship: interceptor-auth, tool-call-handler, devtools-integration, custom-reducer, generative-ui-with-WidgetResolver, etc.

## 9. Testability

### 9.1 HIGH — SC-1 "100% AG-UI protocol conformance" — test is not materially specified

**Issue.** SC-1 is the headline ship gate but reads as a declaration. To make it a CI gate, you need: (a) the set of fixtures (named, count); (b) the assertion mechanism (the `ConformanceRunner` from F-G4); (c) what counts as a pass (every event round-trips? what's "round-trip"? consumer sees a typed event equivalent to the wire event?); (d) what about unknown events — does a fixture containing an unrecognized type pass via `UnknownAgUiEvent`?

**Resolution.** Add SC-1.a-d sub-criteria with the test specification. Should look like: "ConformanceRunner asserts: for every event in fixture set F={dojo: [...], agno: [...], langgraph: [...]}, the round-trip wire→typed→wire produces a byte-for-byte equivalent JSON payload modulo ordering of object keys." That's testable. The current statement is not.

### 9.2 HIGH — Performance NFRs (N-1 through N-5) need test fixtures

**Issue.** "10,000 events/sec on a midrange Android device" — what's the test? Which fixture? Which device class in CI (CI doesn't have Pixel 4a)? Without a benchmark harness specification, these NFRs cannot gate.

**Resolution.** Add: "Benchmark harness in `koel_http/test/perf/` runs against `benchmark_fixtures/throughput.jsonl`. CI gate runs on `linux-x64` GitHub Actions runner; absolute target adjusted to runner-equivalent (typically 3x reference). Reference Pixel 4a numbers are documented but not CI-gated."

### 9.3 MEDIUM — N-12 "Coverage ≥ 90%/80%" — coverage of what?

**Issue.** Line coverage of source files? Including generated `freezed` files? Including `package:json_serializable` output? If generated code counts, hitting 90% is trivial. If it doesn't, the threshold is meaningful but the boundary isn't drawn.

**Resolution.** Specify: "Coverage measured on `lib/**/*.dart` excluding `**/*.g.dart`, `**/*.freezed.dart`, generated bindings. Tool: `package:coverage`."

### 9.4 LOW — CM-2 "10% cold-start regression blocks merge"

**Issue.** Regression measured against what baseline? Last main commit? Last release? Rolling window? Without baseline strategy, the gate is unimplementable.

**Resolution.** Define: "Baseline = mean of last 10 main-branch CI runs of the same benchmark. Block if PR's run is > 10% above baseline."

## 10. Forward-compat sanity

### 10.1 HIGH — FC-2 + Dart 3 sealed unions is a contradiction

**Issue.** FC-2 says "adding a new AG-UI event type is a minor version bump on `koel_core`." But for consumers writing `switch (event) { case RunStartedEvent: ... }` exhaustively, adding a `case NewEvent: ...` requirement is a *source-breaking* change. Dart's flow analyzer will refuse to compile the switch if it's not exhaustive over the sealed hierarchy.

The PRD acknowledges this in passing: "Consumers writing exhaustive `switch` statements on `AgUiEvent` would not be source-compatible across minor versions if they don't include `case UnknownAgUiEvent()`." But the proposed escape (`case UnknownAgUiEvent()`) doesn't help — adding `MyNewEvent` is still a new case the consumer's switch must handle. Adding `UnknownAgUiEvent` as a catchall to the consumer's switch doesn't help because the new event has its own typed class, not `UnknownAgUiEvent`.

**Resolution.** Pick one:

(a) **`AgUiEvent` is not sealed; subclassing is allowed.** Sacrifices compile-time exhaustive matching but enables true semver-minor event additions. Consumers must use `if (event is X)` defensively.

(b) **`AgUiEvent` is sealed; adding events is MAJOR.** Honest, defensible. Semver bumps go major for protocol additions. Acceptable if you commit to it — but then F-A6 `UnknownAgUiEvent` becomes a no-op (a sealed hierarchy can't have unknowns from future versions because consumers must recompile).

(c) **Hybrid:** `sealed class AgUiEvent` ships with one open extension point (`sealed class AgUiEvent` → `class _DeclaredEvent extends AgUiEvent`; new events go into `_DeclaredEvent` family which is `final class`-but-not-`sealed`). Awkward.

The current PRD has (b) on the type system, (a) on the semver policy, and (b-ish) on the unknown-event escape. That's incoherent.

Recommend: own the truth. Sealed = MAJOR bumps for additions. Or: don't seal, use `final class` and accept run-time type checks. Don't try to have both.

### 10.2 MEDIUM — FC-4 "breaking AG-UI changes → major bump on koel_core + koel_http"

**Issue.** Adapter packages "receive a minor or patch bump on their dependency range" — but adapter packages currently depend on `^1.0.0` style ranges. If `koel_core` goes to 2.0.0, every adapter must change its range to `^2.0.0`, which is itself a breaking change for adapter consumers. So a koel_core major triggers a cascade of adapter majors.

**Resolution.** Acknowledge the cascade. Either: (a) adapters re-publish at their own major when `koel_core` majors (clear, propagating), or (b) adapters publish a compatibility shim `koel_agno: ^1.x` that depends on `koel_core: '>=1.0.0 <3.0.0'` (fragile). Pick a posture.

### 10.3 LOW — FC-3 "maintainer reads AG-UI release notes manually"

**Issue.** Single-point-of-failure on a person reading notes. No automation, no monitoring.

**Resolution.** Add to CI a daily/weekly job that diffs the AG-UI TypeScript SDK's event-type registry against `koel_core`'s. File a GitHub issue automatically on diff. Cheap, removes the human-attention dependency.

---

# Summary by Severity

**HIGH (must address before architect handoff):** 1.1, 1.2, 1.3, 2.1, 3.1, 4.1, 5.1, 6.1, 6.2, 6.3, 7.1, 7.2, 8.1, 8.2, 9.1, 9.2, 10.1.

**MEDIUM (close before epic-planner handoff):** 1.4, 1.5, 1.6, 1.7, 2.2, 3.2, 3.3, 4.2, 5.2, 5.3, 6.4, 6.5, 7.3, 8.3, 9.3, 10.2.

**LOW (track but doesn't block):** 1.8, 2.3, 2.4, 3.4, 4.3, 6.6, 7.4, 8.4, 9.4, 10.3.

**Total:** 17 HIGH + 16 MEDIUM + 10 LOW = 43 findings.

The PRD is unusually well-written and most criticisms are sharpening, not redirecting. But §10.1 (sealed-vs-semver contradiction) is a load-bearing structural inconsistency that affects how every consumer writes their code — it should be resolved before the §9 contract is frozen.
