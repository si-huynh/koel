---
baseline_commit: 37e0f9752f16e94bc9cc6474707c4e01fc0b6f87
---

# Story 2.10: `AgentSubscriber` callback bag

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this story touches `.dart` files and async/Stream observation design. **Invoke `/agent-flutter-engineer` before producing any code** (per CLAUDE.md). The line-economy + no-vestigial-code + no-silent-catch mindset is load-bearing here: the *temptation* is to ship a production dispatcher, but its only caller (`KoelClient`) is Story 2.14 — building it now is exactly the "just in case" code koel bans. See Dev Notes §"Scope: the dispatcher is test-local".

## Story

As a Flutter/Dart developer,
I want `abstract class AgentSubscriber` with per-event callback hooks all defaulted to empty,
so that observers (devtools, telemetry, custom hooks) attach without forcing implementation of every callback per FR-A10.

## Acceptance Criteria

Verbatim from [epic-2 Story 2.10](../planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md):

1. **Given** `koel_core/lib/src/agent/agent_subscriber.dart`, **When** I inspect the class, **Then** every callback method from Addendum A.1 exists with `void` return and empty default body: `onRunStart`, `onRunFinish`, `onRunError`, `onStepStart`, `onStepFinish`, `onTextChunk`, `onToolCall`, `onToolResult`, `onStateDelta`, `onReasoning`, `onActivity`, `onUnknownEvent`.

2. **Given** a custom subscriber overriding only `onRunStart` + `onUnknownEvent`, **When** a run flows through the pipeline, **Then** the two overrides fire on matching events, **And** the unoverridden callbacks remain no-ops without exception.

3. **Given** multiple subscribers attached to `KoelClient`, **When** an event fires, **Then** every subscriber's matching callback executes in registration order, **And** an exception thrown in one subscriber does not prevent subsequent subscribers from running (subscriber-isolation contract).

> **⚠️ AC2/AC3 reference machinery that does NOT exist yet.** "the pipeline" is Story 2.11; "`KoelClient`" is Story 2.14. This is the *exact* situation Story 2.9 hit with "`MockAgent`" (Story 3.1). The AC *intent* is "prove the bag's callbacks route to the right events, and that subscribers are isolated from each other's throws." Satisfy that intent with a **private test-local dispatcher** in the test file (the inline-double analog) — do **NOT** build the pipeline, do **NOT** build `KoelClient`, and do **NOT** ship a production dispatcher (it would be vestigial until 2.14 — see Dev Notes §"Scope: the dispatcher is test-local"). The production routing + isolation ships with its first real caller in Story 2.14.

## Tasks / Subtasks

- [x] **Task 1 — Create `agent_subscriber.dart` with `abstract class AgentSubscriber`** (AC: #1)
  - [x] New file `packages/koel_core/lib/src/agent/agent_subscriber.dart`. **Single import:** `../event/ag_ui_event.dart` — every callback parameter type (`RunStartedEvent`, `TextMessageContentEvent`, `ToolCallStartEvent`, `UnknownAgUiEvent`, the `AgUiEvent` root, …) is a `part of` that library, so one import covers them all. **No `part` directive, no freezed, no `build_runner`** — this is a behavioral contract with no fields (see Dev Notes §"No codegen").
  - [x] Declare `abstract class AgentSubscriber` with a `const AgentSubscriber();` constructor and the **12** callbacks from Dev Notes §"The authoritative signature", each `void`, each with an **empty `{}` body** (concrete default, NOT `abstract` — empty body is what makes every callback optional to override). Signatures byte-exact to the addendum block, plus `onActivity` (see Dev Notes §"onActivity is in the epic AC, not the stale addendum block").
- [x] **Task 2 — Dartdoc every public symbol** (AC: #1)
  - [x] Contract-form dartdoc on `AgentSubscriber` (class) and each of the 12 callbacks (one-line summary + which event(s) trigger it + when-to-override). The **class** dartdoc MUST state: (a) subscribers are **passive observers** — fired post-pipeline, observation-only, they never mutate `KoelClient`/`ChatSession` state (architecture §"subscribers fire … observation-only"); (b) **`extends`, do NOT `implements`** — empty-body defaults make every callback optional, and adding a callback in a 1.x minor is then additive (a new empty method) rather than a breaking change (forward-compat, review M-6); (c) the **subscriber-isolation contract** — when wired (Story 2.14), a throw from one subscriber's callback is reported to the current `Zone` and does NOT stop the others; subscribers must not assume their throw aborts the run; (d) the bag is a **curated subset** of the 28 event types, not 1:1 — events without a callback (snapshots, `RAW`/`CUSTOM`, the chunk/args/start/end framing events) are observed via the raw `ChatSession.events` stream (Story 2.14), not here.
- [x] **Task 3 — Unit test: every callback is a no-op by default** (AC: #1, #2-partial)
  - [x] New `packages/koel_core/test/agent/agent_subscriber_test.dart`, imports `package:koel_core/src/...` (barrel empty until 2.15 — match existing convention). Use `package:test`.
  - [x] Construct a **bare** `AgentSubscriber` via a trivial private `extends` with zero overrides (`class _NoopSubscriber extends AgentSubscriber { const _NoopSubscriber(); }`), then invoke **all 12** callbacks directly with a representative event each. Assert none throws. This drives 100% line coverage of the empty bodies (every `void onX(e) {}` line executes).
- [x] **Task 4 — Build the test-local dispatcher + routing test** (AC: #2)
  - [x] In the test file, write a private dispatcher that maps **one** `AgUiEvent` to the matching callback — a `switch (event)` over the sealed root (see Dev Notes §"The callback↔event routing map" for the exact mapping; §"Test doubles to build" for the shape). The `switch` MUST be exhaustive with a `default:`/`_` arm (the un-subscribed events route nowhere) — this also satisfies `koel_lints`' `exhaustive_switch_must_have_default`.
  - [x] `_RecordingSubscriber extends AgentSubscriber` overriding **only** `onRunStart` + `onUnknownEvent`, appending a label to a shared `List<String> log`. Drive `[RunStartedEvent, UnknownAgUiEvent(...), TextMessageContentEvent, RunFinishedEvent]` through the dispatcher → assert `log == ['runStart', 'unknown']` (the two overrides fired on their matching events; the other events hit unoverridden no-ops and recorded nothing). Proves AC2 intent.
  - [x] Add a focused route-coverage check: feed one representative event per mapped callback through the dispatcher into a subscriber that records every callback name, asserting each maps to the expected callback (esp. the family fan-ins: all 7 `Reasoning*` → `onReasoning`; both `Activity*` → `onActivity`; `ToolCallStartEvent` → `onToolCall(e, null)`; `TextMessageContentEvent` → `onTextChunk`).
- [x] **Task 5 — Unit test: multi-subscriber order + isolation** (AC: #3)
  - [x] Extend the dispatcher to a `_notifyAll(List<AgentSubscriber>, AgUiEvent)` that loops subscribers **in registration order**, invoking each inside a `try` and forwarding any throw to `Zone.current.handleUncaughtError(e, st)` before continuing (the no-silent-catch isolation idiom — Dev Notes §"Subscriber isolation: how to swallow nothing yet stop nothing").
  - [x] Test ordering: `[A, B, C]` recording subscribers + one `RunStartedEvent` → `log == ['A', 'B', 'C']` (registration order).
  - [x] Test isolation: `[A, _ThrowingSubscriber, C]` → both `A` and `C` still fire (log contains both), AND the thrown error is observed via `Zone.current.handleUncaughtError` — wrap the drive in `runZonedGuarded(() => _notifyAll(...), (e, st) { caught.add(e); })` and assert `caught` holds exactly the one thrown error. This proves the throw was **reported, not swallowed** (architecture §5 bans `catch (_) {}`) **and** that it did not abort the loop.
- [x] **Task 6 — Quality gates** (AC: all)
  - [x] `dart test` (from `packages/koel_core`) → all green (existing ~437 + new).
  - [x] `melos run analyze` → 0 issues (workspace-wide).
  - [x] `dart format --set-exit-if-changed .` → clean.
  - [x] Coverage on `lib/src/agent/agent_subscriber.dart` ≥ 90% line + branch (N-12). Empty-body methods have no branches; the Task-3 "invoke all 12" test gives 100% line. (The test-local dispatcher is test code — it does not count toward lib coverage, but its `switch` arms should all be exercised so the test itself is honest.)
  - [x] Confirm **untouched**: `lib/koel_core.dart` barrel (export sweep is Story 2.15), `pubspec.yaml`, `build.yaml`, `abstract_agent.dart`, `interceptor.dart`, all event/error files. No new dependency. No `*.freezed.dart`/`*.g.dart` generated.

## Dev Notes

### What this story is, in one paragraph
You are adding **one** behavioral type — `abstract class AgentSubscriber` — a passive callback bag lifted from CopilotKit's `AgentSubscriber`. It is the third non-data subsystem in `koel_core` after `AbstractAgent` (2.1) and `Interceptor`/`InterceptorChain` (2.9): no fields, no wire JSON, no freezed. Consumers `extends AgentSubscriber` and override only the callbacks they care about; the empty-body defaults make every other callback a free no-op. Subscribers sit **post-pipeline, observation-only** — they watch the canonical event stream a consumer would see and never mutate client/session state (architecture data-flow: `pipeline → subscribers fire (observation-only) → ChatSession.stream`). This story ships the bag + its dartdoc'd contracts; the *wiring* that fires callbacks (event→callback routing + multi-subscriber isolation) is **demonstrated by tests here** and **shipped in production by `KoelClient` (Story 2.14)** — building a production dispatcher now would be vestigial. [Source: epic-2 §"Story 2.10"; PRD F-A10 prd.md:139, §230; addendum.md:250-263; architecture.md:1067,1083]

### No codegen — this is NOT a freezed/event story
Like 2.9 (`Interceptor`) and unlike 2.1–2.8 (freezed data types), `AgentSubscriber` is **behavioral**: no fields to compare, no wire shape, no `part of`, no `.freezed.dart`/`.g.dart`. Do **not** run `build_runner`, do **not** add a `part` directive, do **not** add a freezed annotation. The only discipline that carries over from the event stories is **contract-form dartdoc on every public symbol** and **no raw throw / silent catch crosses a koel boundary** (here that surfaces as the Zone-forwarding isolation idiom, not a codec helper). [Source: 2-9 Dev Notes §"No codegen" — same classification]

### Files you will touch
| Path | Action | Note |
|------|--------|------|
| `packages/koel_core/lib/src/agent/agent_subscriber.dart` | **NEW** | `abstract class AgentSubscriber` — 12 empty-body callbacks + dartdoc. ~45-55 lines incl. docs. The whole production deliverable. |
| `packages/koel_core/test/agent/agent_subscriber_test.dart` | **NEW** | no-op default test, routing test (test-local dispatcher), order + isolation tests, private subscriber doubles. |

**Do NOT touch:** `lib/koel_core.dart` (barrel — frozen until Story 2.15), `pubspec.yaml`, `build.yaml`, `abstract_agent.dart`, `interceptor.dart`, any event/error/input file. Every type you need already exists (`AgUiEvent` + all 28 subtypes via `ag_ui_event.dart`). Adding a dependency, a freezed annotation, a `koel_test` import, or a **production dispatcher** is a smell.

### The authoritative signature (byte-exact — addendum is the contract, plus the epic's `onActivity`)
```dart
import '../event/ag_ui_event.dart';   // the ONLY import — all event subtypes are `part of` it

/// Passive, post-pipeline observer of an agent run. Extend (do NOT implement)
/// and override only the callbacks you need; every default is an empty no-op.
abstract class AgentSubscriber {
  const AgentSubscriber();

  void onRunStart(RunStartedEvent e) {}
  void onRunFinish(RunFinishedEvent e) {}
  void onRunError(RunErrorEvent e) {}
  void onStepStart(StepStartedEvent e) {}
  void onStepFinish(StepFinishedEvent e) {}
  void onTextChunk(TextMessageContentEvent e) {}
  void onToolCall(ToolCallStartEvent start, ToolCallEndEvent? end) {}
  void onToolResult(ToolCallResultEvent e) {}
  void onStateDelta(StateDeltaEvent e) {}
  void onReasoning(AgUiEvent e) {}
  void onActivity(AgUiEvent e) {}
  void onUnknownEvent(UnknownAgUiEvent e) {}
}
```
The 11 callbacks `onRunStart … onUnknownEvent` (minus `onActivity`) are byte-exact from [addendum.md:250-263](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md). `onActivity(AgUiEvent e)` is added per the epic AC1 + [prd.md:230](../planning-artifacts/prds/prd-koel-2026-05-27/prd.md) (see next note). `const AgentSubscriber();` is a koel addition (zero-cost, lets const subtypes exist; matches the const-ctor convention on every event type) — the addendum omits it but does not forbid it.

### `onActivity` is in the epic AC, not the stale addendum block (RESOLVED — include it)
The addendum A.1 code block (addendum.md:251-263) lists **11** callbacks and omits `onActivity`. The **epic AC1** and **prd.md:230** both list **12**, including `onActivity`. The epic AC is the binding contract for this story, and the PRD agrees. **Include `onActivity(AgUiEvent e)`** — the addendum block is simply older than the PRD/epic. Signature mirrors `onReasoning`: it takes the `AgUiEvent` base (fires for both `ActivitySnapshotEvent` and `ActivityDeltaEvent`), not a narrowed type. This is a doc-vs-doc drift, not a design fork — do not raise it as an open question.

### The callback↔event routing map (used by the test-local dispatcher AND, later, by KoelClient 2.14)
The bag is a **curated subset**, not 1:1 with the 28 event types. Exact mapping:

| AgUiEvent subtype | Callback | Note |
|---|---|---|
| `RunStartedEvent` | `onRunStart(e)` | |
| `RunFinishedEvent` | `onRunFinish(e)` | |
| `RunErrorEvent` | `onRunError(e)` | |
| `StepStartedEvent` | `onStepStart(e)` | |
| `StepFinishedEvent` | `onStepFinish(e)` | |
| `TextMessageContentEvent` | `onTextChunk(e)` | **only** the delta event — NOT start/end/chunk |
| `ToolCallStartEvent` | `onToolCall(e, null)` | `end` is always `null` here — see §"onToolCall asymmetry" |
| `ToolCallResultEvent` | `onToolResult(e)` | |
| `StateDeltaEvent` | `onStateDelta(e)` | NOT `StateSnapshotEvent` |
| `ReasoningStartEvent`, `ReasoningEndEvent`, `ReasoningMessageStartEvent`, `ReasoningMessageContentEvent`, `ReasoningMessageEndEvent`, `ReasoningMessageChunkEvent`, `ReasoningEncryptedValueEvent` | `onReasoning(e)` | all **7** reasoning-family events fan in to one callback (param is the `AgUiEvent` base) |
| `ActivitySnapshotEvent`, `ActivityDeltaEvent` | `onActivity(e)` | both activity events fan in (param is base) |
| `UnknownAgUiEvent` | `onUnknownEvent(e)` | FC-1 forward-compat surface |
| **no callback** (default arm) | — | `TextMessageStartEvent`, `TextMessageEndEvent`, `TextMessageChunkEvent`, `ToolCallArgsEvent`, `ToolCallEndEvent`, `ToolCallChunkEvent`, `StateSnapshotEvent`, `MessagesSnapshotEvent`, `RawEvent`, `CustomEvent` → observed via raw `ChatSession.events`, not the bag |

The dispatcher `switch (event)` is **exhaustive over the sealed `AgUiEvent`** with a `default:`/`_` arm for the no-callback set. (All 28 typed subtypes + `UnknownAgUiEvent` are `part of 'ag_ui_event.dart'`, confirmed by reading the event files.)

### Scope: the dispatcher is test-local (the inline-double analog) — do NOT ship it
AC2/AC3 say "the pipeline" and "`KoelClient`," neither of which exists (2.11 / 2.14). This is the same forward-reference 2.9 hit with "`MockAgent`," and the resolution is the same: **build the missing caller as a private test double, not as production code.** Concretely:
- **2.10 production lib ships exactly one symbol: `abstract class AgentSubscriber`.** Nothing else.
- The **event→callback routing** (the `switch`) and the **multi-subscriber loop with Zone-isolation** live in the **test file** as private helpers — they are the analog of 2.9's `_FixtureAgent`/`_RecordingInterceptor`.
- A production dispatcher (`notifySubscribers(...)`, a `SubscriberDispatcher` class, etc.) has **zero callers until Story 2.14**. Shipping it now is "just in case" code — banned by CLAUDE.md ("no vestigial code") and the line-economy principle. The addendum names **no** dispatcher type (contrast 2.9, where `InterceptorChain.proceed` *was* named → shipped). So there is no spec mandate to ship one, and a strong mandate not to.
- **What 2.14 inherits:** the **documented contracts** on `AgentSubscriber` (routing intent, isolation, observation-only, extend-not-implement) + this story's test as the executable reference. 2.14 wires the production routing into `KoelClient`'s post-pipeline subscriber notification.

If you feel the pull to "just make it real," resist — that pull is the bug 2.9's notes warned about. Keep 2.10 surgical.

### Subscriber isolation: how to swallow nothing yet stop nothing (the load-bearing idiom)
AC3 demands two things that look contradictory: "an exception in one subscriber does not prevent subsequent subscribers from running" (must not propagate) AND architecture §5 bans `catch (_) {}` (must not silently swallow). The reconciliation is the framework-standard **report-but-continue** pattern:

```dart
for (final sub in subscribers) {            // registration order
  try {
    _dispatch(sub, event);                  // the routing switch
  } catch (error, stack) {
    Zone.current.handleUncaughtError(error, stack);   // report, do NOT rethrow
  }
}
```
`Zone.current.handleUncaughtError` forwards the error to the ambient zone's handler — a consumer's `runZonedGuarded`, or the root zone (which prints + lets the process decide). It is **not** a silent catch: the error reaches a surface. The loop then continues to the next subscriber. This is the pure-Dart analog of Flutter's own listener-isolation: `ChangeNotifier.notifyListeners` (in `package:flutter/src/foundation/change_notifier.dart`) wraps each listener call in a try/catch and routes a throw to `FlutterError.reportError(...)` before moving to the next listener — koel_core has no Flutter dependency, so it uses the zone instead of `FlutterError`. **Test it** by driving `_notifyAll` inside `runZonedGuarded(body, (e, st) => caught.add(e))` and asserting the surviving subscribers fired *and* `caught` holds the thrown error (Task 5).

> When 2.14 ships the production dispatcher, this same idiom moves into it; for now it is the test's job to pin the contract.

### onToolCall asymmetry — fire `(start, null)`, pairing is out of scope (RESOLVED)
`onToolCall(ToolCallStartEvent start, ToolCallEndEvent? end)` is the addendum's (acknowledged-as-unusual) two-arg shape; the review's proposed split into `onToolCallStart`/`onToolCallEnd` was **not** adopted into the addendum/epic, so follow the addendum. The per-event dispatcher fires `onToolCall(startEvent, null)` on a `ToolCallStartEvent` — it does **not** correlate start↔end (that pairing needs run-scoped state, which is the reducer's / KoelClient's job, Story 2.12/2.14, not the callback bag's). The non-null `end` path is reserved for a future correlated dispatch in 2.14; in 2.10 it is always `null`. `ToolCallEndEvent` itself routes to the no-callback default arm. Do not invent pairing logic here. [Source: addendum.md:258; review-api-and-completeness.md:131-137 — split *recommended but not adopted*]

### Test doubles to build (all private, in `agent_subscriber_test.dart`)
```dart
import 'dart:async';                                          // Zone, runZonedGuarded
import 'package:koel_core/src/agent/agent_subscriber.dart';
import 'package:koel_core/src/error/koel_error.dart';         // to build a RunErrorEvent
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';        // all event subtypes
import 'package:test/test.dart';

class _NoopSubscriber extends AgentSubscriber {
  const _NoopSubscriber();                                    // zero overrides → all no-ops
}

class _RecordingSubscriber extends AgentSubscriber {
  _RecordingSubscriber(this.label, this.log);
  final String label;
  final List<String> log;
  @override
  void onRunStart(RunStartedEvent e) => log.add(label);       // e.g. 'A'
  @override
  void onUnknownEvent(UnknownAgUiEvent e) => log.add('$label:unknown');
}

class _ThrowingSubscriber extends AgentSubscriber {
  @override
  void onRunStart(RunStartedEvent e) => throw StateError('boom');
}

// The test-local dispatcher — the analog of 2.9's _FixtureAgent. Production
// routing ships in KoelClient (Story 2.14); here it proves AC2/AC3 intent.
void _dispatch(AgentSubscriber s, AgUiEvent e) {
  switch (e) {
    case RunStartedEvent(): s.onRunStart(e);
    case RunFinishedEvent(): s.onRunFinish(e);
    case RunErrorEvent(): s.onRunError(e);
    case StepStartedEvent(): s.onStepStart(e);
    case StepFinishedEvent(): s.onStepFinish(e);
    case TextMessageContentEvent(): s.onTextChunk(e);
    case ToolCallStartEvent(): s.onToolCall(e, null);
    case ToolCallResultEvent(): s.onToolResult(e);
    case StateDeltaEvent(): s.onStateDelta(e);
    case ReasoningStartEvent() ||
          ReasoningEndEvent() ||
          ReasoningMessageStartEvent() ||
          ReasoningMessageContentEvent() ||
          ReasoningMessageEndEvent() ||
          ReasoningMessageChunkEvent() ||
          ReasoningEncryptedValueEvent(): s.onReasoning(e);
    case ActivitySnapshotEvent() || ActivityDeltaEvent(): s.onActivity(e);
    case UnknownAgUiEvent(): s.onUnknownEvent(e);
    default: break;                                           // no-callback set
  }
}

void _notifyAll(List<AgentSubscriber> subs, AgUiEvent e) {
  for (final s in subs) {
    try {
      _dispatch(s, e);
    } catch (error, stack) {
      Zone.current.handleUncaughtError(error, stack);
    }
  }
}
```
Fixture events (all const, confirmed-existing constructors): `const RunStartedEvent(threadId: 't1', runId: 'r1')`, `const RunFinishedEvent(threadId: 't1', runId: 'r1')`, `const TextMessageContentEvent(messageId: 'm1', delta: 'hi')`, `const ToolCallStartEvent(toolCallId: 'c1', toolCallName: 'search')`, `UnknownAgUiEvent(type: 'FUTURE_EVENT', rawJson: const {})`. A `RunErrorEvent` needs a `KoelError`: `RunErrorEvent(error: AgentError(message: 'x', code: KoelErrorCode.unknown))`.

> **Pattern-match note:** in a `switch (e)` over a sealed type, `case RunStartedEvent():` narrows `e` to `RunStartedEvent` inside that arm, so `s.onRunStart(e)` type-checks without a cast. The `||` (logical-or) patterns let the 7 reasoning / 2 activity arms share one body. The `default:` arm is required by `koel_lints` (`exhaustive_switch_must_have_default`) AND is genuine here — the no-callback events legitimately route nowhere.

### Test import idiom (match existing koel_core tests)
Import from `package:koel_core/src/...` — the barrel `lib/koel_core.dart` is empty until Story 2.15; every existing event/agent test does this (see `test/agent/interceptor_test.dart` header). `import 'dart:async';` for `Zone`/`runZonedGuarded`.

### Project structure & conventions
- File lands exactly where architecture pencils it: `koel_core/lib/src/agent/agent_subscriber.dart  # F-A10` ([architecture.md:766](../planning-artifacts/architecture.md), feature map [:1000](../planning-artifacts/architecture.md)). No structural variance.
- Naming: the abstract base is exactly `AgentSubscriber`; callbacks are `onX` verbs. `snake_case.dart` filename. [Source: architecture naming conventions]
- No silent catches — the isolation `catch` forwards to the zone (does not swallow); that is the sanctioned pattern. [Source: architecture §5 "No silent catches; `catch (_) {}` is banned"]
- Subscribers are **observation-only** — a callback must never mutate `KoelClient`/`ChatSession`/`ChatState`. This is a documented contract (you can't enforce it in the type system since callbacks receive immutable events anyway), reinforced by the dartdoc. [Source: architecture.md:1053, :1067]

### Data-flow context (where subscribers sit)
Runtime order: `backend → typed Stream<AgUiEvent> → interceptor chain → pipeline (chunks→verify→apply→transform) → subscribers fire (observation-only) → ChatSession.stream emits ChatState → KoelChatController → widgets` ([architecture.md:1077-1087](../planning-artifacts/architecture.md)). Subscribers fire on the **post-pipeline canonical events** — i.e. after chunk synthesis and verification, so a subscriber sees `ToolCallStartEvent` (synthesized), not the raw `ToolCallChunkEvent`. This story builds **only the bag**; the firing point is Story 2.14. The architecture prose says subscribers fire "parallel, observation-only" — "parallel" means *side-channel / off the data path*, not literally concurrent isolates; the **epic AC3 binds the actual semantics: synchronous, registration order, isolated**. No conflict — implement AC3's wording.

## Previous Story Intelligence
From the koel_core lineage 2.1–2.9:
- **2.9 (`Interceptor`/`InterceptorChain`)** is the closest sibling and the template for *process*, not code: behavioral type, no codegen, 2-file footprint (lib + test), inline test doubles standing in for not-yet-existent machinery, contract dartdoc, Zone/error discipline. Re-read its Dev Notes before starting. The **key transferred lesson**: when an AC references a later story's component (there `MockAgent`, here `pipeline`/`KoelClient`), build a *private test double*, never the real thing.
- **2.9 spec-correction worth heeding:** its Dev Notes said to `import '../event/run_events.dart'` for `RunErrorEvent` — that **failed** because `run_events.dart` is `part of 'ag_ui_event.dart'` and cannot be imported. This story's single import is therefore `../event/ag_ui_event.dart` (verified: all subtypes are parts of it). Do not try to import individual event part-files.
- **2.1** froze `AbstractAgent` (`abstract interface class`, `Stream<AgUiEvent> run`). Not touched here, but it is the producer of the events subscribers observe.
- **2.3** shipped `KoelError`/`AgentError`/`KoelErrorCode` — you only need them to *construct* a `RunErrorEvent` fixture in the test (`AgentError(message:…, code: KoelErrorCode.unknown)`).
- **2.5–2.8** shipped all 28 event subtypes (the routing-map sources). The `||`-pattern fan-in for the 7 reasoning + 2 activity events depends on those exact class names — confirmed present.
- **Recurring SF-1 discipline (2.3–2.9):** no raw throw / silent catch crosses a koel boundary. Here it manifests as the `Zone.handleUncaughtError` isolation idiom (report-not-swallow), the generalization of the same invariant. [Source: 2-9-interceptor-chain-framework.md; 2-8/2-5/2-3 stories]

## Git Intelligence Summary
Recent commits: `feat(story-2.9)` (Interceptor), `feat(story-2.8/2.7/2.6/2.5)` (event codecs). 2.9 is the relevant precedent (behavioral, 2 files, no freezed); the 2.5–2.8 codec commits are **not** a template (those regenerate `*.freezed.dart` + registry entries — none of that here). Expect a **small, surgical footprint**: `agent_subscriber.dart` ~45-55 lines incl. dartdoc; `agent_subscriber_test.dart` ~120-180 lines incl. doubles; zero modified production files; zero regenerated artifacts; zero new deps. Commit message convention: `feat(story-2.10): AgentSubscriber callback bag`. [Source: `git log` 37e0f97/c4c6b60/d7efe39]

## Latest Tech Information
- **`Zone.handleUncaughtError` / `runZonedGuarded`** (`dart:async`) — the load-bearing isolation primitive. `runZonedGuarded(body, onError)` runs `body` in a child zone whose uncaught errors (including those forwarded by `Zone.current.handleUncaughtError`) route to `onError` instead of crashing. This is how the test observes a thrown-but-isolated subscriber error. No new dependency; `dart:async` is core. Dart SDK `>=3.11.0 <4.0.0`. [Source: dart:async Zone API]
- **Dart 3 sealed-class `switch` exhaustiveness + logical-or patterns** — `case A() || B() || C(): body;` shares one arm across subtypes; a `switch` over a sealed type is exhaustive, and the `default:` arm both satisfies `koel_lints` and homes the no-callback events. No version change. [Source: Dart 3 patterns spec; ag_ui_event.dart sealed-root dartdoc]
- **CopilotKit `AgentSubscriber`** is the named inspiration (a hook bag of optional callbacks). koel's faithful port: an `abstract class` with empty-body defaults that consumers `extends`. Don't add a dependency; this is a ~50-line from-scratch type. [Source: discovery-copilotkit.md:99-116, :340; reconcile-spec.md:132 — "Faithful"]

### Project Structure Notes
- New files land exactly where architecture.md:766/:1000 place them. No structural variance, no barrel change, no pubspec change.
- AC2/AC3's "pipeline"/"KoelClient" are forward-references to Stories 2.11/2.14 that do not yet exist — satisfied here with a private test-local dispatcher (documented above). Known spec-vs-sequencing drift, not a structure conflict — identical in kind to 2.9's "MockAgent" forward-reference.

### References
- [epic-2 Story 2.10 spec + ACs](../planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md)
- [addendum.md:250-263 — `AgentSubscriber` authoritative signatures (11 callbacks; `onActivity` omitted — stale)](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md)
- [prd.md:139 (F-A10), :230 — callback bag, 12 callbacks incl. `onActivity`; :325 (FC-1 onUnknownEvent)](../planning-artifacts/prds/prd-koel-2026-05-27/prd.md)
- [review-api-and-completeness.md:131-145 — onToolCall asymmetry + curated-subset note (recommendations NOT adopted)](../planning-artifacts/prds/prd-koel-2026-05-27/review-api-and-completeness.md)
- [review-adversarial.md:228-230 (M-6) — extend-not-implement for forward-compat](../planning-artifacts/prds/prd-koel-2026-05-27/review-adversarial.md)
- [architecture.md — F-A10 location :766/:1000; subscriber timing/observation-only :1053,:1067,:1083; data flow :1077-1087; error §5](../planning-artifacts/architecture.md)
- [ag_ui_event.dart — sealed root; all 28 subtypes are `part of` it (the single import)](../../packages/koel_core/lib/src/event/ag_ui_event.dart)
- [2-9-interceptor-chain-framework.md — sibling behavioral story; inline-double pattern; part-file import gotcha](2-9-interceptor-chain-framework.md)

### Design decisions (RESOLVED — AC/convention-forced, not open)
Baked in so the dev has zero ambiguity. No confirmation gate.
1. **Ship only `AgentSubscriber`; the dispatcher is test-local.** The addendum names no dispatcher; AC2/AC3's callers (pipeline/KoelClient) are later stories; a production dispatcher would be vestigial until 2.14. Mirrors 2.9 shipping `InterceptorChain` (named) but NOT a public `MockAgent` (unnamed, forward-ref). The routing/isolation is proven by tests and documented as a contract; 2.14 ships the production version.
2. **Include `onActivity`.** Epic AC1 + prd.md:230 list 12 callbacks including `onActivity`; the addendum code block (11) is stale. Epic AC binds. Signature `void onActivity(AgUiEvent e) {}`, mirroring `onReasoning`.
3. **`extends`, not `implements`.** Empty-body defaults + the M-6 forward-compat argument (adding a callback in a minor stays additive only for `extends` users). Documented in the class dartdoc; tests use `extends`.
4. **Isolation = report-to-Zone, not swallow.** `Zone.current.handleUncaughtError` reconciles AC3's "don't stop the others" with §5's "no silent catch." Framework-grounded (the `ChangeNotifier.notifyListeners` shape). Tested via `runZonedGuarded`.
5. **`onToolCall` fires `(start, null)`; no start↔end pairing.** Per-event dispatch can't correlate; pairing is reducer/KoelClient territory (2.12/2.14). `ToolCallEndEvent` routes to the no-callback arm.
6. **Synchronous, registration-order dispatch.** Epic AC3 binds this; the architecture's "parallel" = side-channel/observation-only, not concurrency.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8, 1M context) — via `/agent-flutter-engineer` implement mode.

### Debug Log References

- `dart analyze lib/src/agent/agent_subscriber.dart test/agent/agent_subscriber_test.dart` → "No issues found!"
- `dart test test/agent/agent_subscriber_test.dart` → **9 passed**.
- `dart test` (full koel_core) → **446 passed** (baseline 437 + 9 new). No regressions.
- `melos run analyze` (workspace) → all 10 packages "No issues found!".
- `dart format --set-exit-if-changed` → clean (test file reformatted once during dev, then stable).
- Coverage on `lib/src/agent/agent_subscriber.dart` → **13/13 lines (100%)**; file has **no branches** (empty-body methods + const ctor), so branch coverage is trivially satisfied (≥ 90% N-12).

### Completion Notes List

- **All 3 ACs satisfied.** AC1: `abstract class AgentSubscriber` ships all 12 callbacks (`onRunStart … onUnknownEvent`, incl. `onActivity`), each `void` with an empty `{}` body, verified by the "every callback is an inherited no-op" test. AC2: a subscriber overriding only `onRunStart`+`onUnknownEvent` fires exactly on those events; the rest route to inherited no-ops. AC3: multi-subscriber dispatch fires in registration order, and a throwing subscriber is isolated — `A` and `C` still fire and the throw surfaces via `runZonedGuarded`'s handler exactly once (reported, not swallowed).
- **Scope held exactly as planned — no production dispatcher shipped.** The production lib gained one symbol: `abstract class AgentSubscriber`. Event→callback routing + multi-subscriber isolation live in the test file as `_dispatch`/`_notifyAll` (the Story-2.9 `_FixtureAgent` analog); they are the inline doubles standing in for the not-yet-existent `KoelClient`/pipeline (Stories 2.14/2.11). Building a production dispatcher now would be vestigial.
- **`onActivity` included** per epic AC1 + prd.md:230 (the addendum A.1 code block omits it — stale). Signature `void onActivity(AgUiEvent e) {}`, mirroring `onReasoning`.
- **Isolation = report-to-Zone, not swallow.** `Zone.current.handleUncaughtError(error, stack)` reconciles AC3's "don't stop the others" with architecture §5's "no `catch (_) {}`". The test asserts the surviving subscribers ran AND the error reached the zone handler — proving it was reported, not silently dropped.
- **Single import confirmed.** `agent_subscriber.dart` imports only `../event/ag_ui_event.dart`; all callback parameter types are `part of` it (the 2.9 part-file import gotcha avoided). No error import needed — callbacks take `RunErrorEvent`, not `KoelError`.
- **No codegen.** Behavioral type, no fields → no freezed, no `part` directive, no `build_runner`, no `*.freezed.dart`/`*.g.dart`.
- **Scope clean:** barrel `lib/koel_core.dart`, `pubspec.yaml`, `build.yaml`, `abstract_agent.dart`, `interceptor.dart`, and all event/error files untouched. No new dependency. Two new files only.
- **Minor test-fixture note:** `ReasoningEncryptedValueEvent` carries a `Uint8List`, which is not const-constructible, so the reasoning-fan-in fixture list is `final` (not `const`) with `Uint8List(0)` inlined — the only deviation from the all-const fixture sketch in the story.

### File List

New:
- `packages/koel_core/lib/src/agent/agent_subscriber.dart`
- `packages/koel_core/test/agent/agent_subscriber_test.dart`

## Change Log

| Date | Change |
|------|--------|
| 2026-05-30 | Story drafted (create-story). Status → ready-for-dev. |
| 2026-05-30 | Implemented Story 2.10: `abstract class AgentSubscriber` (12 empty-body callbacks incl. `onActivity`) + contract dartdoc. Event→callback routing and multi-subscriber registration-order dispatch with Zone-reported isolation proven via a test-local dispatcher (no production dispatcher shipped — that's Story 2.14). All 3 ACs met; 9 new tests; 446 koel_core tests green; 10-package analyze + format clean; agent_subscriber.dart 100% line coverage (no branches). Status → review. |
| 2026-05-30 | Code review (3-layer adversarial: Blind Hunter + Edge Case Hunter + Acceptance Auditor). Clean — 0 decision-needed, 0 patch, 0 defer, 15 dismissed. Edge Hunter verified exhaustive routing over all 29 `AgUiEvent` subtypes; Auditor re-ran gates (analyze clean, 9/9 tests) and confirmed all 3 ACs + 8 binding design decisions. Blind Hunter findings all traced to the binding addendum/spec decisions or were false positives (e.g. `dart:typed_data` is used at `:236`). Status → done. |
