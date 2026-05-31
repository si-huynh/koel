---
baseline_commit: 8317787
---

# Story 3.1: `MockAgent` foundation — `.programmatic()` + `.fromEvents()`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this story writes the **first production code in `koel_test`** — a new public class (`MockAgent`) + its builder, async-stream replay with cancellation, and the **first cross-package dependency edge in the workspace** (`koel_test → koel_core`). It touches `.dart` files, designs a public API surface, and turns on async/`Stream` cancellation semantics. **Invoke `/agent-flutter-engineer` before producing any code** (per CLAUDE.md). Four things are load-bearing, and three are *non-obvious traps*:
> 1. **`MockAgent` is an adapter → it NEVER throws `KoelError`; it emits `RunErrorEvent`** (architecture §5 :596-600 names `MockAgent` explicitly in the adapter list). `run()` must not throw on empty/odd input. An error path is just `fromEvents([…, RunErrorEvent(error: …)])`. See §"Error channel".
> 2. **The builder's generated `messageId` MUST be non-empty.** The `verifyStage` (Story 2.11, `pipeline/verify_stage.dart:84-103`) **drops** any `TextMessage*` event with an empty `messageId` and emits a `ProtocolError` in its place. A builder that emits `messageId: ''` produces a stream that silently corrupts under the real pipeline. Counter-based, non-empty, deterministic IDs only. See §"Builder ID determinism".
> 3. **Replay is verbatim — `run(input)` IGNORES `input`.** The pipeline does **not** correlate events to `input.runId`/`threadId` (verify_stage checks structural rules only; confirmed by reading `pipeline/verify_stage.dart` — no runId filter). The canned event sequence IS the contract, exactly as fixture replay will be in Story 3.3. Do **not** rewrite event IDs to match `input`. See §"Verbatim replay".
> 4. **Determinism over realism — no `Random`, no `DateTime.now()`.** Generated IDs are counter-based so two runs of the same builder produce byte-identical streams (tests assert on them; flakiness is a bug per convention §6). See §"Builder ID determinism".

## Story

As a Flutter/Dart developer,
I want `MockAgent` exposing `.programmatic()` (builder pattern) and `.fromEvents(List<AgUiEvent>)` factory constructors implementing `AbstractAgent`,
so that I can author deterministic test agents inline without authoring fixtures per FR-G2.

## Acceptance Criteria

Verbatim from [epic-3 Story 3.1](../planning-artifacts/epics/epic-3-test-harness-conformance-koeltest.md):

1. **Given** `koel_test/lib/src/mock_agent.dart`, **When** I inspect the class, **Then** `class MockAgent implements AbstractAgent` declares factories `MockAgent.fromEvents(List<AgUiEvent>)` and `MockAgent.programmatic()` returning a builder for declarative event-sequence construction (e.g., `.runStarted().textMessage("hi").runFinished().build()`).

2. **Given** a `MockAgent.fromEvents([RunStartedEvent(...), TextMessageStartEvent(...), TextMessageContentEvent(...), TextMessageEndEvent(...), RunFinishedEvent(...)])`, **When** I `await for` its `run(input)` stream, **Then** every event emits in declared order with realistic timing (default: zero delay; configurable per-event delay for streaming-jank tests).

3. **Given** a programmatic agent with a configured `Duration` per event, **When** I drive a run, **Then** each event emits after its configured delay, **And** cancelling the subscription mid-stream stops further emissions (TCP-close-analog behavior).

## Tasks / Subtasks

- [x] **Task 1 — Wire the `koel_test → koel_core` dependency edge** (AC: #1, prerequisite for all)
  - [x] In `packages/koel_test/pubspec.yaml`, add a `dependencies:` block declaring **`koel_core:`** (bare key, no version — resolved from the pub workspace, exactly as the existing `koel_lints:` dev-dep is). `koel_core` must be a **regular `dependency`, not a dev_dependency**: `MockAgent`'s *public* signature names `AbstractAgent`, `AgUiEvent`, `RunAgentInput` (all from `koel_core`), so it is part of `koel_test`'s runtime contract. This is the **first cross-package dependency edge in the workspace** — no `packages/*/pubspec.yaml` declares `koel_core:` today (verified). [Source: koel_test/pubspec.yaml; root pubspec.yaml workspace members :8-19; architecture package DAG :1034]
  - [x] Add **`test: ^1.25.0`** to `dev_dependencies` (mirror `koel_core/pubspec.yaml:22`) so `koel_test` can run its own unit tests. **Do NOT add `freezed`/`build_runner`/`json_serializable`** — `MockAgent` is a plain class with no codegen; it replays already-`freezed` events from `koel_core`. [Source: koel_core/pubspec.yaml:17-22; convention §3 "no codegen unless a freezed type is declared"]
  - [x] Run `dart pub get` (or `melos bootstrap`) and confirm the workspace resolves with the new edge — this is the first real inter-package solve, so a failure here is a workspace-config problem, not a code problem. [Source: resolution: workspace]

- [x] **Task 2 — `MockAgent.fromEvents` + the replay engine** (AC: #1, #2, #3)
  - [x] New file `packages/koel_test/lib/src/mock_agent.dart`. Import the **public barrel** `package:koel_core/koel_core.dart` (NOT `package:koel_core/src/...`) — `koel_test` is a downstream consumer and must dog-food the 1.x public surface Story 2.15 finalized (`AbstractAgent`, all `AgUiEvent` subtypes, `RunAgentInput` are all exported there). [Source: 2-15 barrel finalize; architecture §6 :685 "no external import of internal `src/` paths"]
  - [x] Declare **`final class MockAgent implements AbstractAgent`** (`final` → one-way door, no subclassing; `implements` not `extends` — `AbstractAgent` is an `abstract interface class`). Store an **immutable timeline**: `final List<_TimedEvent> _timeline` where `_TimedEvent` is a private `(AgUiEvent event, Duration delay)` record-or-class (the delay is waited **before** emitting its event). [Source: AC1; abstract_agent.dart:10 `abstract interface class`; CLAUDE.md "API surface one-way door"]
  - [x] `factory MockAgent.fromEvents(List<AgUiEvent> events, {Duration delay = Duration.zero})`: maps every event to `(event, delay)` (uniform spacing) and **defensively copies** into an unmodifiable list (a caller mutating the passed `List` after construction must not change replay). The uniform `delay` is the "configurable per-event delay" of AC2; heterogeneous per-event delays come from the builder (Task 3). [Source: AC2 "default: zero delay; configurable per-event delay"]
  - [x] Implement **`@override Stream<AgUiEvent> run(RunAgentInput input)` as an `async*` generator** that ignores `input` and replays the timeline:
    ```dart
    @override
    Stream<AgUiEvent> run(RunAgentInput input) async* {
      for (final (:event, :delay) in _timeline) {
        await Future<void>.delayed(delay);
        yield event;
      }
    }
    ```
    - **Always `await Future<void>.delayed(delay)` before each `yield`, even when `delay == Duration.zero`.** `Future.delayed(Duration.zero)` schedules a zero-duration timer (next event-loop turn), which (a) makes emission **asynchronous** — the stream never delivers synchronously inside `listen()`, matching a real transport; and (b) makes **cancellation observable between every pair of events** (AC3). [Source: AC2 "realistic timing"; AC3 "cancelling mid-stream stops further emissions"; dart:async `_AsyncStarStreamController` honors cancel at `yield`/`await` suspension points]
    - **Cancellation is free with `async*`** — do NOT hand-roll a `StreamController` with `onCancel` bookkeeping. When the consumer cancels the `StreamSubscription`, the generator terminates at its next suspension and emits nothing further; a single in-flight `Future.delayed` timer fires once and is GC'd (no leak, no `StreamController` to dispose). Each `run()` call returns a **fresh single-subscription stream**, so a `MockAgent` is reusable across runs (the `ConformanceRunner` in Story 3.5 will drive one repeatedly). [Source: §"Async/cancellation semantics"; implement.md "explicit lifecycle, no silent leaks"]

- [x] **Task 3 — `MockAgent.programmatic()` + `MockAgentBuilder`** (AC: #1, #3)
  - [x] `static MockAgentBuilder programmatic()` returns a fresh builder. Declare **`final class MockAgentBuilder`** (same file, tightly coupled). The builder is **mutable during construction**; `build()` produces the **immutable** `MockAgent`. Do NOT make `MockAgent` itself fluent/mutable — separate the building phase from the built agent. [Source: AC1 "returning a builder"; implement.md "pure/immutable over hidden state"]
  - [x] Ship the **three AC-named sugar methods + one generic escape hatch**, each returning `this` for chaining and each taking an optional `Duration? delay`:
    - `runStarted({String? threadId, String? runId, Duration? delay})` → appends `RunStartedEvent(threadId: threadId ?? _threadId, runId: runId ?? _runId)`. Defaults: `_threadId = 'mock-thread'`, `_runId = 'mock-run'`. Overriding `threadId`/`runId` here updates the builder's current pair so a following `runFinished()` matches.
    - `textMessage(String text, {String? messageId, String role = 'assistant', Duration? delay})` → expands to **three** events sharing one `messageId`: `TextMessageStartEvent(messageId, role)` → `TextMessageContentEvent(messageId, text)` → `TextMessageEndEvent(messageId)`. The `delay` (if any) applies **before each of the three** events (each is a `(event, delay)` timeline entry) — so AC3's "each event emits after its configured delay" holds literally and unambiguously, and a `delay` simulates per-delta streaming latency for jank tests. Generated `messageId` is **counter-based and non-empty** (see §"Builder ID determinism").
    - `runFinished({Object? result, Duration? delay})` → appends `RunFinishedEvent(threadId: _threadId, runId: _runId, result: result)`.
    - `event(AgUiEvent event, {Duration? delay})` → the escape hatch: append any event verbatim (tool calls, state deltas, `RunErrorEvent`, reasoning, etc.). This is how negative-path and non-text scenarios are authored without per-type sugar. [Source: AC1 "(e.g., …)" — the three are *examples*, not the exhaustive set; implement.md "resist abstraction until the second concrete use case"]
  - [x] `MockAgent build()` constructs `MockAgent` from the accumulated timeline via a **private** constructor (`MockAgent._(this._timeline)`). The builder does **NOT** enforce lifecycle ordering (no "runStarted must precede textMessage" guard) — authors must be free to build deliberately malformed sequences for negative tests (e.g. a content event with no run bracket). The sugar produces well-formed *sub*-sequences; overall coherence is the author's. [Source: §"Verbatim replay"; the deterministic-double contract]

- [x] **Task 4 — Export the surface from the barrel** (AC: #1)
  - [x] In `packages/koel_test/lib/koel_test.dart` (today: `library;` + a one-line doc, zero exports), add `export 'src/mock_agent.dart';`. This surfaces **both** `MockAgent` and `MockAgentBuilder` (the builder is the return type of the public `programmatic()`, so it is public and must be reachable). Keep `_TimedEvent` private (never exported). **Do NOT re-export `koel_core`** — consumers of `koel_test` already depend on `koel_core`; the meta-package is the only re-exporter (architecture :980). [Source: 2-15 barrel discipline; architecture §6 single-barrel :684]

- [x] **Task 5 — Tests** (AC: #1, #2, #3)
  - [x] New `packages/koel_test/test/mock_agent_test.dart` (`package:test`, the only framework — convention §6 :656). Cover:
    - **AC1 (shape):** `MockAgent.fromEvents([...])` is an `AbstractAgent`; `MockAgent.programmatic().runStarted().textMessage('hi').runFinished().build()` returns a `MockAgent`; assert the built timeline emits the expected `[RunStarted, TextMessageStart, TextMessageContent('hi'), TextMessageEnd, RunFinished]` sequence with non-empty, shared `messageId`.
    - **AC2 (order + default zero delay):** `await for` (or `.toList()`) over `fromEvents([...])` yields the exact declared order; emission is asynchronous (a sentinel set synchronously after `listen()` is observed before the first event, proving non-synchronous delivery).
    - **AC2 (configurable delay):** with a per-event `delay`, total elapsed ≥ `delay × eventCount` (use a *loose lower-bound* assertion — `elapsed >= n*delay`, never an upper bound — so it can't flake on a loaded machine; convention §6 "no flaky tests").
    - **AC3 (cancellation):** subscribe with a delay, `cancel()` after the first event, pump the event loop past the remaining delays, assert **no further events** arrived (TCP-close analog). Use a collecting list + `await subscription.cancel()`.
    - **Reusability:** calling `run()` twice on one `MockAgent` yields two independent, equal sequences.
    - **Adapter never throws (architecture §5):** `MockAgent.fromEvents(const [])` and `MockAgent.programmatic().build()` each `run()` to an empty stream that **completes** without throwing; a timeline containing a `RunErrorEvent` emits it as a normal event (no `throw`).
  - [x] Verify the determinism guardrail empirically: two builds from identical builder calls produce byte-identical `messageId`s (counter resets per builder instance). [Source: §"Builder ID determinism"]

- [x] **Task 6 — Quality gates** (AC: all)
  - [x] `melos run analyze` → **0 issues** workspace-wide (the new dependency edge + new files must not introduce diagnostics). [Source: NFR-13]
  - [x] `melos run test` → green, including the new `koel_test` suite (it now has real test files, so it no longer hits the scaffold exit-79/65 path that `tool/test_package.sh` tolerates). [Source: 2-15 melos test wiring; tool/test_package.sh]
  - [x] `dart format --set-exit-if-changed .` (via `melos run format:check`) → clean. [Source: convention; tool/format.sh]
  - [x] Confirm **no `koel_core` change** — this story is additive in `koel_test` only. No edit to any `packages/koel_core/**` file. [Source: §"Files you will touch"]
  - [x] **Do NOT** add a `koel_test/analysis_options.yaml` doc-gate, perf benches, or coverage-threshold wiring — `koel_test`'s ≥80% coverage gate (NFR-12) is **Story 3.5's** AC (the epic's last story), not 3.1's. 3.1 ships the class + its tests; the package-finalization gates land with 3.5. [Source: epic-3 Story 3.5 AC "coverage ≥ 80%"; 2-15 precedent: the finalize gates live in the epic's sealing story]

## Dev Notes

### What this story is, in one paragraph
The **first feature in `koel_test`** and the foundation every later test-harness story builds on. It ships `MockAgent` — a deterministic `AbstractAgent` test double that **replays a canned `AgUiEvent` sequence** through a real `Stream` — via two authoring surfaces: `.fromEvents(List<AgUiEvent>)` (a flat list, the low-level path) and `.programmatic()` (a fluent `MockAgentBuilder` for inline declarative construction). It is the blessed alternative to hand-mocking `AbstractAgent` (architecture anti-patterns :697). Stories 3.3 (`.fromFixture`), 3.4 (`ToolHandlerTestHarness`), and 3.5 (`ConformanceRunner`) all drive a `MockAgent`. Scope is exactly the two factories + replay + cancellation; **`.fromFixture` is Story 3.3, fixtures are Story 3.2** — not here. [Source: epic-3 :5-25; architecture First-Implementation-Priority block 4 :1315-1316]

### The public API contract (sketch — the heart of this story)
The signature *is* the contract; everything else is implementation detail. Design it so a caller cannot reach an illegal state:

```dart
/// A deterministic [AbstractAgent] test double that replays a fixed event
/// sequence. Authored inline via [MockAgent.fromEvents] or [MockAgent.programmatic].
final class MockAgent implements AbstractAgent {
  MockAgent._(this._timeline);

  /// Replays [events] verbatim, [delay] before each (default: no delay).
  factory MockAgent.fromEvents(List<AgUiEvent> events, {Duration delay = Duration.zero});

  /// A fluent builder for declarative inline construction.
  static MockAgentBuilder programmatic() => MockAgentBuilder._();

  final List<_TimedEvent> _timeline;

  /// Replays the canned sequence. [input] is ignored — the sequence is the
  /// contract. Returns a fresh single-subscription stream; cancel to stop.
  @override
  Stream<AgUiEvent> run(RunAgentInput input) async* { /* … */ }
}

final class MockAgentBuilder {
  MockAgentBuilder._();
  MockAgentBuilder runStarted({String? threadId, String? runId, Duration? delay});
  MockAgentBuilder textMessage(String text, {String? messageId, String role, Duration? delay});
  MockAgentBuilder runFinished({Object? result, Duration? delay});
  MockAgentBuilder event(AgUiEvent event, {Duration? delay});
  MockAgent build();
}
```

Why this shape: `final` classes (no subclassing — one-way door); `implements` (the SPI is an `abstract interface class`); private constructor + `build()` (the agent is immutable once built); a separate builder (building phase ≠ built agent); a generic `.event()` escape hatch (no speculative per-type sugar). [Source: implement.md "sketch the public API first"; CLAUDE.md "design for what users can't misuse"]

### Async / cancellation semantics (the second heart)
`async*` is the right primitive — not a hand-rolled `StreamController`:
- **Backpressure is free.** A paused subscription suspends the generator at its `yield`; it resumes when the listener resumes. No buffering, no `onPause`/`onResume` bookkeeping.
- **Cancellation is free.** Cancelling the subscription terminates the generator at its next suspension point (`await` or `yield`). At most one in-flight `Future.delayed` timer outlives the cancel — it fires once, delivers nothing (stream already closed), and is GC'd. There is **no `StreamController` to leak and nothing to `dispose`**. This is precisely AC3's "cancelling mid-stream stops further emissions (TCP-close analog)." [Source: dart:async async-generator semantics — cancel honored at yield points; AbstractAgent contract `abstract_agent.dart:11-12` "Cancelling the subscription cancels the run"]
- **`await Future.delayed(delay)` before every `yield`, including `Duration.zero`.** Zero-delay still schedules a next-turn timer, so (a) the stream never emits synchronously inside `listen()` (a real transport doesn't either — a synchronous burst would mask ordering/timing bugs in consumers), and (b) cancellation is observable between *every* pair of events, not just delayed ones. This is the single non-obvious implementation choice and it is what makes AC2 ("realistic timing") and AC3 (mid-stream cancel) both hold without contradiction. [Source: AC2; AC3]
- **Single-subscription, reusable agent.** Each `run()` call returns a *new* `async*` stream (single-subscription, as `KoelClient` expects — it `listen`s once). The `MockAgent` instance is reusable: drive `run()` repeatedly (the Story 3.5 `ConformanceRunner` does exactly this). The timeline is immutable, so concurrent runs are independent.

### Verbatim replay — `run(input)` ignores `input` (RESOLVED, with pipeline evidence)
`MockAgent` replays its canned events **exactly as authored**; it does **not** rewrite `threadId`/`runId`/`messageId` to match the `RunAgentInput` passed to `run()`. This is safe and correct, and it matches the fixture-replay semantics Story 3.3 will inherit (a fixture's events carry their own IDs from the `_session` header). The evidence: the 4-stage pipeline does **not** correlate events to `input.runId` — `pipeline/verify_stage.dart` enforces only *structural* rules (orphan tool-call envelope, empty `STATE_DELTA`, empty `messageId`, reasoning round-trip) and drops nothing on an ID mismatch (read the full `onEvent` switch — no `runId`/`threadId` branch). The reducer (Story 2.12) keys text messages by `messageId` and tool calls by `toolCallId`, so a self-consistent canned sequence yields well-formed state regardless of what `input` carried. **The author owns sequence coherence**; the builder's sugar generates coherent sub-sequences for the common path. [Source: pipeline/verify_stage.dart `_VerifyStage.onEvent`; chat_state_reducer.dart message/tool keying (Story 2.12); epic-3 3.3 fixture `_session` header :41]

### Builder ID determinism + the `messageId` guardrail (RESOLVED)
Two hard constraints:
- **Determinism.** Tests assert on the replayed sequence. Generated IDs must be reproducible across runs of the same builder — so **no `Random`, no `DateTime.now()`/`Stopwatch`-derived IDs**. Use a per-builder-instance **integer counter**: `'mock-msg-${++_messageSeq}'`. Two `textMessage(...)` calls get `mock-msg-1`, `mock-msg-2`; a fresh `programmatic()` resets the counter. (This mirrors the same reproducibility discipline `koel_core`'s no-flaky-test convention enforces.)
- **Non-empty `messageId` is mandatory.** `verifyStage` (`pipeline/verify_stage.dart:84-103`) **drops** a `TextMessageStartEvent`/`ContentEvent`/`EndEvent` whose `messageId.isEmpty` and emits a `ProtocolError` in its place. A builder that ever produces `messageId: ''` ships a `MockAgent` whose text messages **silently vanish** when run through the real `KoelClient` pipeline. The counter guarantees a non-empty id; if `textMessage(messageId: '')` is passed explicitly, that is the author's deliberate negative-test choice (don't second-guess it — but the *default* path must never be empty). [Source: pipeline/verify_stage.dart:84-103; chat_session.dart:61 `msg-$_threadId-$runIndex` ID-shape precedent]

The default `runStarted` IDs (`'mock-thread'`/`'mock-run'`) are likewise fixed strings, not generated — deterministic by construction. `RunStartedEvent`/`RunFinishedEvent` have no empty-string verify rule, but keeping them non-empty and paired (same `threadId`/`runId` across a run bracket) keeps the replayed run well-formed for the reducer's run-phase tracking. [Source: run_events.dart:16-20, :52-56; chat_state.dart `RunPhase` (Story 2.12)]

### Error channel (RESOLVED — architecture §5)
`MockAgent` is in the adapter list architecture §5 :597 enumerates as **never throwing `KoelError`** ("Adapters … `MockAgent` … emit a `RunErrorEvent` into the stream"). Concretely for 3.1:
- `run()` must **not** `throw` for any timeline (including `const []` — the empty agent replays nothing and the stream completes normally).
- An error scenario is authored *in-band*: `fromEvents([RunStartedEvent(...), RunErrorEvent(error: AgentError(message: 'boom')), ...])` or `programmatic().runStarted().event(RunErrorEvent(...)).build()`. The `RunErrorEvent` is emitted like any event; the consumer's pipeline/subscriber handles it.
- There is **no `catch (_) {}`** anywhere — there is nothing to catch (replay can't fail), and a swallow would be a bug. [Source: architecture §5 :596-600; abstract_agent.dart:7 "Adapters NEVER throw KoelError"]

### Out of scope — do NOT build these (RESOLVED)
- **`MockAgent.fromFixture(name)`** — **Story 3.3**. It needs `FixtureLoader` + bundled JSONL (**Story 3.2**), neither of which exists yet. Do not stub it. [Source: epic-3 3.2/3.3]
- **`MockAgent.empty`** — **not in any 3.1 AC.** `fromEvents(const [])` *is* the empty agent; a named `.empty` is speculative API (YAGNI / one-way-door). Story 2.15's `cold_start_bench` deliberately used a private inline `_EmptyAgent` and stays on it — **do not re-point 2.15's bench** (it's a `done` story; touching it is churn outside this scope). If Epic 3 later wants `.empty`, adding it is a non-breaking 1.x minor. [Source: 2-15 §"The MockAgent trap (again)"; CLAUDE.md "no just-in-case parameters"]
- **Per-event-type builder sugar** (`toolCall()`, `stateDelta()`, `reasoning()`, …) — the generic `.event(AgUiEvent)` escape hatch covers them. Add sugar when a second concrete consumer needs it (implement.md). [Source: implement.md "resist abstraction until the second use case"]
- **The fixtures directory, `FixtureLoader`, `ToolHandlerTestHarness`, `ConformanceRunner`, `CONFORMANCE.md`, `tool/capture_fixtures.dart`** — Stories 3.2 / 3.3 / 3.4 / 3.5. [Source: epic-3]
- **`koel_test` package-finalization gates** (a member `analysis_options.yaml` doc gate, `coverage_options.yaml`, the ≥80% coverage assertion) — **Story 3.5's** AC (the epic-sealing story), mirroring how 2.15 sealed Epic 2. 3.1 only needs `melos run analyze`/`test`/`format:check` green. [Source: epic-3 3.5 coverage AC; 2-15 finalize precedent]
- **Any `koel_core` change** — 3.1 is additive in `koel_test` only. [Source: §"Files you will touch"]

### Files you will touch
| Path | Action | Note |
|------|--------|------|
| `packages/koel_test/pubspec.yaml` | **MODIFY** | Add `dependencies: koel_core:` (first cross-package edge) + `dev_dependencies: test: ^1.25.0` (Task 1). |
| `packages/koel_test/lib/src/mock_agent.dart` | **NEW** | `MockAgent` + `MockAgentBuilder` + private `_TimedEvent` (Tasks 2-3). |
| `packages/koel_test/lib/koel_test.dart` | **MODIFY** | `library;` → add `export 'src/mock_agent.dart';` (Task 4). |
| `packages/koel_test/test/mock_agent_test.dart` | **NEW** | AC1-AC3 + reusability + never-throws coverage (Task 5). |

**Do NOT touch:** any `packages/koel_core/**`; any other package; the placeholder CI workflows; the root `pubspec.yaml` `melos.scripts` (already wired in 2.15); `koel_test`'s `README.md`/`CHANGELOG.md`/`LICENSE` (scaffolded in Epic 1; package-docs polish is a later concern).

### Library / framework requirements
- **One new runtime dependency: `koel_core`** (workspace-resolved, bare key). One new dev dependency: **`test: ^1.25.0`**. **No `freezed`/`build_runner`** — `MockAgent` is a plain `final class`, no codegen. [Source: koel_core/pubspec.yaml; convention §3]
- **`dart:async` / `dart:core` only** for the replay engine (`async*`, `Stream`, `Future.delayed`, `Duration`). No third-party async helpers. [Source: implement.md "cheapest construct that satisfies the requirement"]
- **`package:test` only** for tests (convention §6 :656 "No alternative frameworks"). Loose lower-bound timing assertions only (never an upper bound) so the delay tests can't flake. [Source: architecture §6 :654-661]
- **Consumed verbatim from `koel_core`'s public barrel:** `AbstractAgent`, `AgUiEvent` (+ `RunStartedEvent`, `RunFinishedEvent`, `RunErrorEvent`, `TextMessageStartEvent`, `TextMessageContentEvent`, `TextMessageEndEvent`, and any event the `.event()` escape hatch takes), `RunAgentInput`, `AgentError`/`KoelError` (for authoring error timelines). Read for use — never modified. [Source: 2-15 barrel export table; run_events.dart; text_message_events.dart]

### Project Structure Notes
- `packages/koel_test/lib/src/mock_agent.dart` is the architecture-pinned location (architecture :963 "`mock_agent.dart  # F-G2`"). `MockAgentBuilder` co-locates there (tightly coupled; one `export`).
- `lib/koel_test.dart` is the single barrel (architecture §6 :684); `lib/src/` stays private (consumers reach `MockAgent` only through the barrel). This is the first export the `koel_test` barrel carries.
- `test/` is a new directory for `koel_test` — its first real test file. (Until now `koel_test` had zero test files, which is why `tool/test_package.sh` tolerates the scaffold exit-79/65; after 3.1 it has a real suite.) [Source: architecture :958-968; 2-15 Review Finding on scaffold exit codes]
- The `koel_test → koel_core` edge respects the package DAG (architecture :1034 "koel_test … depended on as dev_dependency" by *others*; `koel_test` itself depends *up* on `koel_core`). No reverse dependency introduced. [Source: architecture :1301 "respect the package DAG; never introduce reverse dependencies"]

### Previous Story Intelligence
- **2.15 (Epic 2 sealing)** — finalized the `koel_core` public barrel `MockAgent` now imports (`package:koel_core/koel_core.dart`). It also **twice** dodged the "`MockAgent` doesn't exist yet" trap with a private inline `_EmptyAgent`/`_FakeAgent` double, and explicitly said: "When 3.1 ships `MockAgent.empty`, the bench can adopt it." **3.1 does NOT ship `.empty`** (not in the ACs — see Out of scope) and does **not** re-point 2.15's bench. [Source: 2-15 §"The MockAgent trap (again)"; 2-15 File List]
- **2.14 (`KoelClient`/`ChatSession`)** — the run path a `MockAgent` plugs into: `KoelClient(agent: MockAgent.fromEvents([...]))`, then `client.newSession().run(...)` / `client.runRaw(input)`. `chat_session.dart:61,:74-75` shows the *client* generates `input.threadId/runId/messageId` per run — independent of the `MockAgent`'s canned event IDs, which is exactly why verbatim replay (ignoring `input`) is correct. [Source: 2-14; chat_session.dart:61,:74-75]
- **2.12 (`ChatState` + `DefaultChatStateReducer`)** — keys text by `messageId`, tool calls by `toolCallId`, tracks `RunPhase` by the run bracket. A `MockAgent` sequence is "well-formed" iff its `messageId`s pair Start/Content/End and its run bracket shares one `runId` — what the builder guarantees. [Source: 2-12; chat_state_reducer.dart]
- **2.11 (`verifyStage`)** — the structural gate that **drops empty-`messageId` text events**. This is the single hard correctness constraint on the builder's ID generation (§"Builder ID determinism"). [Source: 2-11; pipeline/verify_stage.dart:84-103]
- **`abstract_agent_test.dart:8-11` (`_FakeAgent`)** — the minimal `implements AbstractAgent` + `Stream<AgUiEvent>` pattern `MockAgent` generalizes (from a fixed-empty stream to a replayable timeline). [Source: abstract_agent_test.dart:8-11]

### Git Intelligence Summary
Recent commits close Epic 2 (`docs(epic-2): retrospective + close epic` @ `8317787`; `feat(story-2.15)` @ `0c04705`; `feat(story-2.14)` @ `b4f86bf`). 3.1 opens Epic 3 — the **first commit that writes `koel_test/lib/src`** and the **first to add a cross-package `dependencies:` edge**. Expected footprint: 1 pubspec edit (2 deps), 1 new source file (`mock_agent.dart`), 1 barrel one-liner, 1 new test file. **Zero `koel_core` change, zero codegen, one new runtime dep (`koel_core`) + one dev dep (`test`).** Commit message: `feat(story-3.1): MockAgent foundation — programmatic builder + fromEvents`. [Source: `git log` 8317787/0c04705/b4f86bf; epic-3 :5-25]

### Latest Tech Information
- **Dart `async*` honors subscription cancellation at `yield`/`await` suspension points** — the generator terminates and runs `finally` blocks when the listener cancels; this is the idiomatic, leak-free way to make a replay stream cancellable (vs a manual `StreamController` + `onCancel`). [Source: dart:async async-generator semantics; abstract_agent.dart:11-12]
- **`Future.delayed(Duration.zero)` schedules a 0-duration `Timer`** (a macrotask, next event-loop turn) — not a microtask — so it reliably yields control and lets a pending `cancel()` land between events. This is why the replay engine `await`s even on zero delay. [Source: dart:async `Future.delayed`]
- **Records `(AgUiEvent event, Duration delay)`** (Dart 3) are the cheapest way to store the timeline with named destructuring `for (final (:event, :delay) in _timeline)` — no allocation of a wrapper class, exhaustive by shape. Prefer over a hand-written `_TimedEvent` class unless a method is needed. [Source: Dart 3 records; implement.md "cheapest construct"]
- **Bare workspace dependency keys** (`koel_core:` with no version) resolve from `resolution: workspace` against the root `pubspec.yaml` member list — the existing `koel_lints:` dev-dep already proves the mechanism; `koel_core:` as a regular `dependency` is the first *runtime* edge. [Source: pub workspace resolution; root pubspec.yaml :8-19]

### References
- [epic-3 Story 3.1 spec + ACs; 3.2 fixtures / 3.3 `fromFixture` / 3.4 harness / 3.5 conformance scope fences](../planning-artifacts/epics/epic-3-test-harness-conformance-koeltest.md)
- [architecture.md §5 :596-600 (adapters — incl. `MockAgent` — emit `RunErrorEvent`, never throw); §6 :684-685 (single barrel, private `src/`); :697 (anti-pattern: don't hand-mock `AbstractAgent`); :958-968 (`koel_test` layout, `mock_agent.dart` = F-G2); :1034 (package DAG); :1301 (no reverse deps); :1315-1316 (block-4 `MockAgent` first)](../planning-artifacts/architecture.md)
- [abstract_agent.dart:10-13 — the SPI `MockAgent implements`; :7 "Adapters NEVER throw KoelError"](../../packages/koel_core/lib/src/agent/abstract_agent.dart)
- [abstract_agent_test.dart:8-11 — `_FakeAgent` inline-double pattern `MockAgent` generalizes](../../packages/koel_core/test/agent/abstract_agent_test.dart)
- [run_events.dart:16-20,:52-56,:92 — `RunStartedEvent`/`RunFinishedEvent`/`RunErrorEvent` constructors](../../packages/koel_core/lib/src/event/run_events.dart)
- [text_message_events.dart:17-20,:47-50,:76 — `TextMessage{Start,Content,End}Event` constructors the builder's `textMessage()` expands into](../../packages/koel_core/lib/src/event/text_message_events.dart)
- [run_agent_input.dart:31-40 — `RunAgentInput` (the ignored `run()` arg)](../../packages/koel_core/lib/src/input/run_agent_input.dart)
- [pipeline/verify_stage.dart:84-103 — drops empty-`messageId` text events (the builder ID guardrail); confirms no `runId` correlation (verbatim-replay evidence)](../../packages/koel_core/lib/src/pipeline/verify_stage.dart)
- [client/chat_session.dart:61,:74-75 — the client generates per-run `input` IDs independently of the agent's canned IDs](../../packages/koel_core/lib/src/client/chat_session.dart)
- [koel_test/pubspec.yaml + lib/koel_test.dart — the empty package to populate; koel_core/pubspec.yaml:22 for the `test:` dev-dep form](../../packages/koel_test/pubspec.yaml)
- [2-15-perf-baselines-dartdoc-barrel.md §"The MockAgent trap (again)" — why `.empty` is out of scope and 2.15's bench is not re-pointed](2-15-perf-baselines-dartdoc-barrel.md)

### Design decisions (RESOLVED — AC/architecture-forced, not open)
Baked in so the dev has zero ambiguity. No confirmation gate.
1. **`MockAgent` imports `package:koel_core/koel_core.dart` (the public barrel), not `src/`**, and `koel_core` is a regular **`dependency`** (its types are in `MockAgent`'s public signature). First cross-package edge in the workspace.
2. **`run()` is an `async*` generator that `await Future.delayed(delay)` before every `yield`, including `Duration.zero`.** This makes emission asynchronous and cancellation observable between every event pair — satisfying AC2 (realistic timing) and AC3 (mid-stream cancel) without contradiction. No manual `StreamController`. Fresh single-subscription stream per `run()`; agent reusable.
3. **Verbatim replay — `run(input)` ignores `input`.** The pipeline doesn't correlate events to `input.runId` (verify_stage evidence). Matches Story 3.3 fixture-replay semantics. Author owns coherence; builder sugar generates coherent sub-sequences.
4. **Builder IDs are deterministic + non-empty.** Counter-based (`mock-msg-N`, no `Random`/`DateTime.now`); fixed default `mock-thread`/`mock-run`. Non-empty `messageId` is mandatory — `verifyStage` drops empty ones.
5. **`MockAgent` never throws (adapter rule).** Empty timeline → empty completing stream; error scenarios are authored in-band via a `RunErrorEvent` in the sequence. No `catch (_) {}`.
6. **Minimal builder surface: 3 AC-named sugar methods (`runStarted`/`textMessage`/`runFinished`) + 1 generic `.event()` escape hatch.** No per-type sugar, no `.empty`, no `.fromFixture` — those are speculative or belong to 3.2/3.3/later minors.
7. **`final class` for both `MockAgent` and `MockAgentBuilder`** (one-way door, no subclassing); builder mutable during construction, `MockAgent` immutable after `build()` (private ctor + unmodifiable timeline).
8. **Package-finalization gates (doc/coverage) are Story 3.5, not 3.1.** 3.1 needs only `analyze`/`test`/`format:check` green.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8, 1M context) via `/bmad-dev-story`; Dart code produced under the `agent-flutter-engineer` specialist (implement mode), per CLAUDE.md.

### Debug Log References

- `dart pub get` — workspace resolved with the first runtime cross-package edge (`koel_test → koel_core`); analyzer-12 holds are the documented stopgap, not a solve failure.
- `melos run analyze` → all 11 packages "No issues found!".
- `dart test` (koel_test) → 15/15 passed; `melos run test` → green workspace-wide (koel_core 572, koel_test 15, koel_lints 5; scaffolds tolerated).
- `melos run format:check` → clean after `melos run format` rewrapped the two new files (long chained/named-arg lines).

### Completion Notes List

- **Source-verified APIs, not the story's loose sketches.** Confirmed every constructor against `koel_core` source before use. One concrete trap caught: the story's `AgentError(message: 'boom')` would **not compile** — `AgentError` requires `code: KoelErrorCode` (`koel_error.dart:97-102`). The error-channel test passes `code: KoelErrorCode.unknown` (the same canonicalization the wire deserializer uses).
- **Timeline record uses named fields.** Implemented `_TimedEvent` as `typedef _TimedEvent = ({AgUiEvent event, Duration delay})` (named, not positional). The story's destructuring pattern `for (final (:event, :delay) in _timeline)` requires **named** record fields — a positional `(AgUiEvent event, Duration delay)` exposes only `.$1`/`.$2` and would not destructure by name.
- **`run()` is an `async*` generator** that `await Future<void>.delayed(delay)` before every `yield` (including `Duration.zero`) — makes emission asynchronous and cancellation observable between every event pair. No hand-rolled `StreamController`, nothing to dispose; cancellation is free at the suspension point. Verified empirically by the async-sentinel and mid-stream-cancel tests.
- **Verbatim replay** — `run(input)` ignores `input`; proven by a test running the same agent under two different `RunAgentInput` ids and asserting identical output.
- **Builder IDs counter-based + non-empty** (`mock-msg-N`, reset per builder instance); fixed `mock-thread`/`mock-run` defaults. Determinism asserted by two builds producing byte-identical streams. An explicit empty `messageId` is honoured (deliberate negative-test path) while the default path never empties.
- **Adapter never throws** — empty timelines complete to an empty stream; a `RunErrorEvent` is emitted as a normal event. No `catch (_) {}` anywhere (nothing can fail).
- **Scope honoured** — no `.fromFixture`, no `.empty`, no per-type sugar, no package-finalization gates (doc/coverage are Story 3.5). Zero `koel_core` change; the first commit to write `koel_test/lib/src` and the first runtime cross-package `dependencies:` edge.

### File List

- `packages/koel_test/pubspec.yaml` — MODIFY: add `dependencies: koel_core:` (first runtime cross-package edge) + `dev_dependencies: test: ^1.25.0`.
- `packages/koel_test/lib/src/mock_agent.dart` — NEW: `MockAgent` + `MockAgentBuilder` + private `_TimedEvent` typedef.
- `packages/koel_test/lib/koel_test.dart` — MODIFY: add `export 'src/mock_agent.dart';`.
- `packages/koel_test/test/mock_agent_test.dart` — NEW: AC1–AC3 + reusability + never-throws + determinism + verbatim-replay + defensive-copy coverage (15 tests).

## Change Log

| Date       | Change                                                                                          |
|------------|-------------------------------------------------------------------------------------------------|
| 2026-05-31 | Implemented Story 3.1 — `MockAgent` foundation (`.programmatic()` builder + `.fromEvents()`), first `koel_test` production code and first runtime cross-package edge. All ACs satisfied; analyze/test/format gates green. Status → review. |

## Review Findings

_Code review 2026-05-31 (baseline `8317787`) — 3 adversarial layers (Blind Hunter, Edge Case Hunter, Acceptance Auditor). Acceptance Auditor: **PASS on every AC / Task / design-decision**, zero `koel_core` change, gates green. ~11 findings dismissed as by-design (spec RESOLVED) or verified-safe. 2 substantive findings below._

- [x] [Review][Patch] `MockAgentBuilder` is silently reusable after `build()` — **FIXED (option c):** `build()` is now single-shot (`bool _built` guard → `StateError` on second call); test `build() is single-shot` added. `build()` snapshots via `List.unmodifiable` (first agent always correct) but never clears `_timeline`/`_messageSeq`, so reuse yields a cumulative second agent. Make `build()` single-shot (a `bool _built` guard + `StateError`) so misuse fails loudly instead of corrupting silently — aligns with CLAUDE.md "design for what users can't misuse / API one-way door." [mock_agent.dart:117] (source: edge+blind)
- [x] [Review][Patch] Cancellation test can flake on a loaded machine — **FIXED:** test now cancels from inside the listener the instant the first event arrives (via a `Completer`), removing the wall-clock upper bound; asserts `countAtCancel == 1`. — `expect(countAtCancel, greaterThanOrEqualTo(1))` fires after a fixed 30ms wall-clock wait, an implicit *upper bound* on the 20ms-delayed first event's arrival (timers fire at-or-after, never early; under load event[0] can land >30ms → `countAtCancel == 0` → fail). This is exactly the upper-bound-on-timing the project's no-flaky-test convention (§6) forbids. Fix: cancel deterministically from inside the listener after the first event arrives, then pump and assert no further events — removes the wall-clock race. [mock_agent_test.dart:155-188] (source: blind)
