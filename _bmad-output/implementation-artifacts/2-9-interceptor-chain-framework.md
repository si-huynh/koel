---
baseline_commit: c4c6b602b43b0b1a04bc2ae527a7ba1442461d0a
---

# Story 2.9: `Interceptor` + `InterceptorChain` framework (no built-ins)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

> **Dev agent:** this story touches `.dart` files and core async/Stream design. **Invoke `/agent-flutter-engineer` before producing any code** (per CLAUDE.md). The framework-source-first, line-economy, runtime-cost mindset is mandatory here — `InterceptorChain.proceed` is hot-path async glue and the wrong `Stream` idiom leaks subscriptions or swallows cancellation.

## Story

As a Flutter/Dart developer,
I want the `Interceptor` interface + `InterceptorChain.proceed()` mechanism in `koel_core` with no built-ins (those live in `koel_http`),
so that backend bridges and consumer code can compose cross-cutting behavior around `Stream<AgUiEvent>` execution per FR-A4.

## Acceptance Criteria

Verbatim from [epic-2 Story 2.9](../planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md):

1. **Given** `koel_core/lib/src/agent/interceptor.dart`, **When** I inspect it, **Then** `abstract class Interceptor` defines `Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input)`, **And** `class InterceptorChain` exposes `Stream<AgUiEvent> proceed(RunAgentInput input)` to call the next interceptor or the underlying agent.

2. **Given** an ordered list of three test interceptors `[A, B, C]` wrapping a `MockAgent`, **When** a run executes, **Then** the order of invocation is `A.intercept → B.intercept → C.intercept → MockAgent.run`, **And** unwinding follows the inverse path, **And** an interceptor that throws causes the chain to short-circuit by emitting `RunErrorEvent` via the classifier (no uncaught throw).

3. **Given** an interceptor that returns a transformed stream, **When** the chain runs, **Then** the transformation is observable in the final emitted events.

> **⚠️ AC2 says "wrapping a `MockAgent`" — `MockAgent` does NOT exist yet.** It is Story 3.1 (`koel_test`), which has not shipped (`packages/koel_test/lib/koel_test.dart` is a bare `library;` stub). The AC's *intent* is "a terminal `AbstractAgent` that emits a known event sequence." Satisfy it with a **private inline test double** in the test file (`_FixtureAgent implements AbstractAgent`) — do **not** add a `koel_test` dependency and do **not** build a public `MockAgent` here. See Dev Notes §"There is no MockAgent — build an inline double".

## Tasks / Subtasks

- [x] **Task 1 — Create `interceptor.dart` with `Interceptor` + `InterceptorChain`** (AC: #1)
  - [x] New file `packages/koel_core/lib/src/agent/interceptor.dart`. Imports: `../event/ag_ui_event.dart`, `../event/run_events.dart` (for `RunErrorEvent`), `../input/run_agent_input.dart`, `../error/error_classifier.dart`, `abstract_agent.dart`. **No `part` directive, no freezed** — these are behavioral types, not data classes (see Dev Notes §"No codegen").
  - [x] Declare `abstract class Interceptor` with the single method `Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input)` — signature **byte-identical** to addendum.md L179-181. Contract dartdoc per Dev Notes §"Dartdoc requirements".
  - [x] Declare `class InterceptorChain` exposing public `Stream<AgUiEvent> proceed(RunAgentInput input)`. Implement the design in Dev Notes §"InterceptorChain design": public constructor `InterceptorChain({required List<Interceptor> interceptors, required AbstractAgent agent, ErrorClassifier errorClassifier = const DefaultErrorClassifier()})` + private advancing constructor carrying the cursor index.
- [x] **Task 2 — Implement `proceed()` dispatch + error short-circuit** (AC: #1, #2)
  - [x] `proceed()` calls `interceptors[index].intercept(<next-chain>, input)` while `index < interceptors.length`, else `terminal.run(input)`. The "next-chain" is a fresh `InterceptorChain` positioned at `index + 1` (see code sketch in Dev Notes).
  - [x] Wrap dispatch in a **single `async*` + `try/catch` around `yield* downstream`** so that BOTH a synchronous throw from `intercept()` AND an error propagated through the downstream stream are caught, classified via `errorClassifier.classify(e, st, input)`, and emitted as `RunErrorEvent(error: <classified>)`. No uncaught throw may escape. (Rationale in Dev Notes §"Why one async* try/catch handles both throw sites".)
  - [x] Confirm cancellation passes through untouched: cancelling the `proceed()` subscription must cancel `downstream` (Dart `async*`/`yield*` gives this for free — do NOT add manual `StreamSubscription` plumbing).
- [x] **Task 3 — Dartdoc every public symbol** (AC: #1)
  - [x] Contract-form dartdoc on `Interceptor`, `Interceptor.intercept`, `InterceptorChain`, its constructor, and `proceed` (one-line summary + when-to-use / when-NOT / ordering & error semantics / a short usage example). Document: ordering is explicit; `intercept` MUST call `chain.proceed(input)` exactly once to continue (or return a substitute stream to short-circuit); interceptors may transform/replace `input` before proceeding (auth/retry pattern); the chain converts throws to `RunErrorEvent` — interceptors should NOT catch-and-swallow.
- [x] **Task 4 — Unit tests: ordering + unwind** (AC: #2)
  - [x] New `packages/koel_core/test/agent/interceptor_test.dart`, imports `package:koel_core/src/...` (barrel is empty until 2.15 — match existing test convention). Use `package:test`.
  - [x] Define private test doubles (see Dev Notes §"Test doubles to build"): `_FixtureAgent` (emits a fixed `[RunStartedEvent, RunFinishedEvent]` sequence), `_RecordingInterceptor` (appends `'<label> enter'` before `proceed`, `'<label> exit'` after the downstream completes, into a shared `List<String> log`).
  - [x] Test: with `[A, B, C]` wrapping `_FixtureAgent`, draining `proceed()` yields `log == ['A enter','B enter','C enter','agent run','C exit','B exit','A exit']` (or the agreed enter/exit shape) — proving forward order `A→B→C→agent` and inverse unwind.
  - [x] Test: the agent's events arrive unchanged when no interceptor transforms.
- [x] **Task 5 — Unit tests: throw short-circuits to `RunErrorEvent`** (AC: #2)
  - [x] `_ThrowingInterceptor` that throws synchronously inside `intercept` (before returning a stream) → draining the chain yields exactly one `RunErrorEvent` (no exception escapes `await for`). Assert `event.error` is a `KoelError` and matches what `DefaultErrorClassifier` produces for that raw throw (e.g. a thrown `StateError`/arbitrary object → `AgentError(code: unknown)`; a thrown `TimeoutException` → `TransportError(transportTimeout)`).
  - [x] A `_FixtureAgent` variant whose stream **emits an error mid-stream** (e.g. `yield RunStartedEvent(...); throw TimeoutException(...)`) → the chain emits the prior events THEN a terminal `RunErrorEvent` (error surfaced through `yield*`, classified, no uncaught throw).
  - [x] Assert a thrown **`KoelError`** passes through the classifier idempotently (stays its own subtype/code — `DefaultErrorClassifier` returns `raw` when `raw is KoelError`).
- [x] **Task 6 — Unit tests: stream transformation observable** (AC: #3)
  - [x] `_TransformingInterceptor` whose `intercept` returns `chain.proceed(input).map(<transform>)` (e.g. replaces every `RunFinishedEvent` with a marker event, or wraps via a `StreamTransformer`). Assert the transformation is visible in the final drained events — proving interceptors compose around the stream, not just the request.
- [x] **Task 7 — Quality gates** (AC: all)
  - [x] `dart test` (from `packages/koel_core`) → all green (existing 428 + new).
  - [x] `melos run analyze` → 0 issues.
  - [x] `melos run format:check` (or `dart format --set-exit-if-changed .`) → clean.
  - [x] Coverage on `lib/src/agent/interceptor.dart` ≥ 90% line + branch (N-12). Branch coverage means: cover the `index < length` true/false branches, the synchronous-throw catch, AND the stream-error catch.
  - [x] Confirm **untouched**: `lib/koel_core.dart` barrel (export sweep is Story 2.15), `pubspec.yaml`, `build.yaml`, `abstract_agent.dart`, all event/error files. No new dependency. No `*.freezed.dart`/`*.g.dart` generated for this file.

## Dev Notes

### What this story is, in one paragraph
This is the **first non-data subsystem** in `koel_core` — a behavioral contract, not a freezed value type. You are adding a dio-style composable interceptor chain: `abstract class Interceptor` (one method) + `class InterceptorChain` (`proceed()`), both in a single new file `lib/src/agent/interceptor.dart`. The chain wraps the terminal `AbstractAgent.run()` so that an ordered list of interceptors executes **forward** on the way in (`A→B→C→agent`) and **unwinds in reverse** on the way out, each able to transform/replace the `RunAgentInput`, transform the resulting `Stream<AgUiEvent>`, or short-circuit. Critically, the chain is the seam that upholds the kernel invariant **"never let a raw throw escape into consumer code"** (architecture §5, [abstract_agent.dart](../../packages/koel_core/lib/src/agent/abstract_agent.dart)): any throw — synchronous from `intercept()` or surfaced through the downstream stream — is routed through the existing `ErrorClassifier` and emitted as a `RunErrorEvent`. **No built-in interceptors ship here** (Logging/Retry/Auth/etc. are `koel_http`, Epic 4). This story is contract + chain mechanics + tests only. [Source: epic-2 §"Story 2.9"; PRD F-A4 prd.md:45; architecture.md:108-109, :994]

### No codegen — this is NOT a freezed/event story
Unlike Stories 2.1–2.8 (all freezed data types with `build_runner`), `Interceptor`/`InterceptorChain` are **behavioral**: no fields to compare, no wire JSON, no `part of`, no `.freezed.dart`, no `.g.dart`. Do **not** run `build_runner` for this file and do **not** add a `part` directive. The "copy the freezed event idiom" muscle memory from 2.5–2.8 does **not** apply. The only shared discipline that carries over: **contract-form dartdoc on every public symbol** and **no raw exception may cross the boundary** (the SF-1 lesson, generalized from codecs to the chain). [Source: 2-8 Dev Notes §"Freezed subtype template" — explicitly inapplicable here]

### Files you will touch
| Path | Action | Note |
|------|--------|------|
| `packages/koel_core/lib/src/agent/interceptor.dart` | **NEW** | `Interceptor` + `InterceptorChain` — the whole story |
| `packages/koel_core/test/agent/interceptor_test.dart` | **NEW** | ordering/unwind, throw→RunErrorEvent, transform tests + inline doubles |

**Do NOT touch:** `lib/koel_core.dart` (barrel — frozen until Story 2.15), `pubspec.yaml`, `build.yaml`, `abstract_agent.dart`, any event/error/input file. All dependencies you need already exist (`AbstractAgent`, `RunErrorEvent`, `ErrorClassifier`/`DefaultErrorClassifier`, `RunAgentInput`). Adding a dependency, a freezed annotation, or a `koel_test` import is a smell.

### The authoritative API signature (byte-exact — addendum is the contract)
```dart
// Interceptor.
abstract class Interceptor {
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input);
}

class InterceptorChain {
  Stream<AgUiEvent> proceed(RunAgentInput input);
}
```
The public surface above is **fixed** by [addendum.md:178-186](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md) and restated in [prd.md:221-222](../planning-artifacts/prds/prd-koel-2026-05-27/prd.md) and the epic AC1. The *internals* of `InterceptorChain` (how it tracks position, where the classifier and terminal agent come from) are **koel's to design** — the addendum only pins `proceed(input)`. The recommended internal shape is below.

> **Note — F-A4 prose says `Future<Stream<AgUiEvent>>`** ([prd.md:45](../planning-artifacts/prds/prd-koel-2026-05-27/prd.md): "Each interceptor wraps `Future<Stream<AgUiEvent>>` execution"). That is conceptual phrasing; the **binding** signature is the synchronous `Stream<AgUiEvent> intercept(...)` from the addendum + epic AC1. Implement the synchronous signature. (An interceptor needing async setup — e.g. fetching an auth token — does it lazily inside an `async*` body or via `Stream.fromFuture(...).asyncExpand(...)`; the return type stays `Stream<AgUiEvent>`.)

### InterceptorChain design
The chain is an immutable cursor over `(interceptors, agent, classifier)` plus an `index`. Public constructor builds the head (index 0); a private constructor advances the cursor. `proceed()` dispatches to the interceptor at `index` or, past the end, to `agent.run`.

```dart
import '../error/error_classifier.dart';
import '../event/ag_ui_event.dart';
import '../event/run_events.dart';        // RunErrorEvent
import '../input/run_agent_input.dart';
import 'abstract_agent.dart';

/// A single cross-cutting stage wrapped around agent execution (auth, retry,
/// logging, …). Interceptors run forward in registration order and unwind in
/// reverse. An implementation MUST call [chain.proceed] exactly once to continue
/// the chain (optionally transforming [input] first), or return a substitute
/// stream to short-circuit. Do NOT catch-and-swallow errors — the chain
/// converts any throw into a `RunErrorEvent` via the configured classifier.
abstract class Interceptor {
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input);
}

/// Drives an ordered [Interceptor] list around a terminal [AbstractAgent].
/// Each [proceed] call invokes the next interceptor, or the agent once the list
/// is exhausted. Any throw — synchronous from `intercept` or surfaced through
/// the downstream stream — is classified into a `KoelError` and emitted as a
/// terminal `RunErrorEvent`; nothing escapes as an uncaught exception
/// (kernel invariant: adapters never throw `KoelError`, architecture §5).
class InterceptorChain {
  InterceptorChain({
    required List<Interceptor> interceptors,
    required AbstractAgent agent,
    ErrorClassifier errorClassifier = const DefaultErrorClassifier(),
  }) : this._(interceptors, agent, errorClassifier, 0);

  InterceptorChain._(this._interceptors, this._agent, this._classifier, this._index);

  final List<Interceptor> _interceptors;
  final AbstractAgent _agent;
  final ErrorClassifier _classifier;
  final int _index;

  Stream<AgUiEvent> proceed(RunAgentInput input) async* {
    try {
      final downstream = _index < _interceptors.length
          ? _interceptors[_index].intercept(_advance(), input)
          : _agent.run(input);
      yield* downstream;                                  // forwards events AND throws
    } catch (error, stack) {
      yield RunErrorEvent(error: _classifier.classify(error, stack, input));
    }
  }

  InterceptorChain _advance() =>
      InterceptorChain._(_interceptors, _agent, _classifier, _index + 1);
}
```

Why this shape:
- **Immutable cursor, no shared mutable index** — each `intercept` receives a fresh chain at `index+1`. An interceptor that calls `proceed` twice (future retry built-in) re-subscribes cleanly; no index aliasing bugs.
- **`const DefaultErrorClassifier()` default** — `DefaultErrorClassifier` has a `const` constructor ([error_classifier.dart](../../packages/koel_core/lib/src/error/error_classifier.dart)), so a chain is constructible with zero wiring for tests/standalone use. Story 2.14 `KoelClient` will inject its own `errorClassifier` here.
- **`RunErrorEvent(error: ...)`** is the only field that type takes — `const factory RunErrorEvent({required KoelError error})` ([run_events.dart:84](../../packages/koel_core/lib/src/event/run_events.dart)). No `threadId`/`runId`/`timestamp` on it.

### Why one `async*` + `try/catch` around `yield*` handles BOTH throw sites
AC2 demands "an interceptor that throws causes the chain to short-circuit by emitting `RunErrorEvent` … (no uncaught throw)." There are two distinct failure surfaces:
1. **Synchronous throw from `intercept()`** — the interceptor throws while *building* the stream (before returning it). In the sketch this happens inside the `try`, at the `_interceptors[_index].intercept(...)` call, so the `catch` fires.
2. **Error surfaced through the returned stream** — the downstream stream emits an error event (e.g. the agent's `async*` body throws mid-emit). `yield* downstream` **re-throws stream errors into the generator body**, so the same `catch` fires after the already-yielded events.

A single `try { … yield* downstream; } catch` therefore covers both — this is the crux of the story and the reason to use `async*` rather than `.handleError`/manual `StreamController` plumbing (which cannot catch the synchronous build-time throw and bloats the code). **Branch coverage (N-12) requires a test for each site** (Task 5 has both).

Cancellation note: a consumer cancelling the `proceed()` subscription does **not** throw into the generator — `async*`/`yield*` propagate cancellation downstream automatically. So cancel ≠ error; you get clean teardown with no spurious `RunErrorEvent`. Do not add manual subscription handling. [Source: architecture §4 — "Cancellation propagates via `StreamSubscription.cancel()`; no cancellation tokens"]

### There is no MockAgent — build an inline double
AC2/AC3 say "MockAgent," but `MockAgent` is **Story 3.1** (`koel_test`) and does not exist yet (`packages/koel_test/lib/koel_test.dart` is a bare `library;`). Do **not** add a `koel_test` dependency (it would invert the dependency graph — `koel_core` is the foundation) and do **not** prematurely build a public `MockAgent` (that's 3.1's scope and design). Build a **private** `_FixtureAgent implements AbstractAgent` in the test file that yields a fixed event sequence. This is the established convention: koel_core tests already construct events inline and import `package:koel_core/src/...` directly. [Source: explorer of `packages/koel_test/`; architecture dependency graph — koel_core has no deps]

### Test doubles to build (all private, in `interceptor_test.dart`)
```dart
class _FixtureAgent implements AbstractAgent {
  _FixtureAgent(this._events, {this.recordRun});
  final List<AgUiEvent> _events;
  final void Function()? recordRun;     // append 'agent run' to the shared log
  @override
  Stream<AgUiEvent> run(RunAgentInput input) async* {
    recordRun?.call();
    for (final e in _events) yield e;
  }
}

class _RecordingInterceptor implements Interceptor {
  _RecordingInterceptor(this.label, this.log);
  final String label;
  final List<String> log;
  @override
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input) async* {
    log.add('$label enter');
    yield* chain.proceed(input);
    log.add('$label exit');             // runs on unwind, after downstream drains
  }
}

class _ThrowingInterceptor implements Interceptor {
  @override
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input) {
    throw StateError('boom');           // SYNCHRONOUS throw, before returning a stream
  }
}

class _TransformingInterceptor implements Interceptor {
  @override
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input) =>
      chain.proceed(input).map(_transform);  // observable transform (AC3)
}
```
Fixture events — use the two **confirmed-existing** lifecycle events: `const RunStartedEvent(threadId: 't1', runId: 'r1')` and `const RunFinishedEvent(threadId: 't1', runId: 'r1')` ([run_events.dart:11,43](../../packages/koel_core/lib/src/event/run_events.dart) — both take `required threadId, required runId`). A minimal `RunAgentInput`: `const RunAgentInput(threadId: 't1', runId: 'r1')` (all other fields have `@Default`s — [run_agent_input.dart](../../packages/koel_core/lib/src/input/run_agent_input.dart)).

> **Ordering-test subtlety:** `_RecordingInterceptor` logs `'$label exit'` *after* `yield* chain.proceed(input)` completes — i.e. after the entire downstream drains. So for `[A,B,C]` the log is `A enter, B enter, C enter, agent run, C exit, B exit, A exit`. If you instead want "exit fires as control returns up the stack per-stage," note that with streaming the exit only runs once the inner stream is exhausted — assert the drain-complete ordering above (it directly proves forward-in / reverse-out). Drain with `await chain.proceed(input).toList()` (or `drain()`), THEN assert the log.

### Test import idiom (match existing koel_core tests)
```dart
import 'dart:async';                                   // TimeoutException, etc.
import 'package:koel_core/src/agent/abstract_agent.dart';
import 'package:koel_core/src/agent/interceptor.dart';
import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/event/run_events.dart';
import 'package:koel_core/src/input/run_agent_input.dart';
import 'package:test/test.dart';
```
Import from `package:koel_core/src/...` — the barrel `lib/koel_core.dart` is empty until Story 2.15; every existing event/error test does this. [Source: explorer of `test/error/error_classifier_test.dart` imports]

### The classifier you're wiring (already shipped — do not reimplement)
`DefaultErrorClassifier.classify(Object raw, StackTrace? stack, RunAgentInput input) → KoelError` is implemented and tested (Story 2.3). Contract you depend on ([error_classifier.dart](../../packages/koel_core/lib/src/error/error_classifier.dart)):
- **Never throws, never returns null.**
- **Idempotent for `KoelError`** — `if (raw is KoelError) return raw;` (a thrown typed error keeps its subtype/code).
- Maps `TimeoutException → TransportError(transportTimeout)`, `FormatException → ProtocolError(protocolMalformed)`, socket/handshake (by type-name) → transport codes, **everything else → `AgentError(code: unknown)`**.
So a `_ThrowingInterceptor` throwing a bare `StateError` yields `RunErrorEvent(error: AgentError(code: KoelErrorCode.unknown))`; throwing a `TimeoutException` yields `transportTimeout`. Use these exact expectations in Task 5 assertions.

### Dartdoc requirements
Every public symbol (`Interceptor`, `Interceptor.intercept`, `InterceptorChain`, the constructor, `proceed`) needs contract-form dartdoc: one-line summary, blank line, then semantics + when-to-use + when-NOT + error/ordering cases + a short example. Must state: (a) interceptors run forward, unwind reverse; (b) `intercept` must call `chain.proceed(input)` exactly once to continue, or return a substitute stream to short-circuit; (c) `input` may be transformed before proceeding (the auth/retry pattern); (d) the chain converts throws to `RunErrorEvent` — interceptors must not swallow errors; (e) built-ins live in `koel_http`, not here. This is enforced in spirit now and by `dart doc` zero-warning in Story 2.15. [Source: architecture convention §6; PRD §13 D-2]

### Project structure & conventions
- File lands exactly where architecture pencils it: `koel_core/lib/src/agent/interceptor.dart  # F-A4` ([architecture.md:767](../planning-artifacts/architecture.md), feature map [:994](../planning-artifacts/architecture.md)). No structural variance.
- Naming: classes end in `Interceptor` for concrete built-ins (none here); the abstract base is exactly `Interceptor`; chain is `InterceptorChain`. `snake_case.dart` filename. [Source: architecture.md:464, :435]
- `Stream<AgUiEvent>` from `AbstractAgent.run()` is **single-listener** by default — `proceed()` returning an `async*` stream preserves single-subscription semantics. Do NOT call `asBroadcastStream()`. [Source: architecture.md §4 stream multiplicity]
- No silent catches anywhere — the `catch` in `proceed` classifies (does not swallow); that is the sanctioned pattern. [Source: architecture §5 "No silent catches; `catch (_) {}` is banned"]

### Dartdoc / data-flow context (where the chain sits)
Runtime order is: `backend → typed Stream<AgUiEvent> → interceptor chain (wrapped around the stream) → pipeline (chunks→verify→apply→transform) → subscribers → ChatSession.stream` ([architecture.md:1077-1087](../planning-artifacts/architecture.md)). This story builds **only the interceptor-chain layer**; the pipeline (2.11), subscribers (2.10), and `KoelClient` wiring (2.14) consume it later. Your `proceed()` output is a raw post-interceptor `Stream<AgUiEvent>` — it does NOT run the pipeline or fire subscribers (those are downstream stories). Keep the scope tight.

## Previous Story Intelligence
From Stories 2.1–2.8 (the koel_core lineage so far):
- **2.1** established `AbstractAgent` as `abstract interface class` with `Stream<AgUiEvent> run(RunAgentInput input)` — your terminal call target. It is frozen; do not modify it.
- **2.3** shipped `ErrorClassifier`/`DefaultErrorClassifier` (const ctor, idempotent on `KoelError`, never throws) — you consume it verbatim for the throw→`RunErrorEvent` short-circuit. The 2.3 review confirmed the idempotence path (`raw is KoelError → raw`); rely on it.
- **2.5** shipped `RunErrorEvent({required KoelError error})` — the only error-event constructor you call.
- **Recurring discipline across 2.3–2.8 (SF-1 lesson):** no raw `TypeError`/`FormatException`/arbitrary throw may cross a koel boundary into consumer code. In codecs this meant `_require*` helpers; **here it means the `try/catch` around `yield*`**. Same invariant, different mechanism — this story is where that invariant generalizes from "decode" to "execute."
- **What does NOT carry over:** the freezed/`part of`/`build_runner`/codec-helper machinery from 2.5–2.8. This is behavioral code; resist copying the event idiom. [Source: 2-8-raw-custom-events-integration-sweep.md; 2-5/2-3 stories]

## Git Intelligence Summary
Recent commits are all event-codec stories (`feat(story-2.8/2.7/2.6)`) — **not** a template for this one (those add freezed parts + registry entries; this adds two behavioral classes + a behavior test). Expect a **small, surgical footprint**: 2 new files (`interceptor.dart` ~50–70 lines incl. dartdoc; `interceptor_test.dart` ~150–200 lines), zero modified production files, zero regenerated `*.freezed.dart`. Commit message convention: `feat(story-2.9): Interceptor + InterceptorChain framework (no built-ins)`. [Source: `git log` c4c6b60/d7efe39/3994989]

## Latest Tech Information
- **Dio interceptor model** is the named inspiration ([addendum.md:618](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md): "`Interceptor.intercept(chain)` composition"); koel borrows the *chain.proceed* composition shape but **rejects** dio's singleton `Dio()` instance and option-bag explosion (KoelClient is non-singleton, Story 2.14). Don't import dio; this is a from-scratch ~60-line implementation.
- **Dart `async*` / `yield*` error semantics** (the load-bearing language feature): `yield* stream` forwards the stream's data events AND re-raises its error events into the generator body, where an enclosing `try/catch` can intercept them. A synchronous throw while constructing the delegated stream is caught by the same `try`. This is why a single `try/catch` suffices for both AC2 throw sites. No new dependency, no version change. Dart SDK `>=3.11.0 <4.0.0`, `test: ^1.25.0` (already in [pubspec.yaml](../../packages/koel_core/pubspec.yaml)). [Source: Dart language spec — async generators; pubspec.yaml]

### Project Structure Notes
- New files land exactly where architecture.md:767/:994 already place them. No structural variance, no barrel change, no pubspec change.
- AC2's "MockAgent" is a forward-reference to Story 3.1 that does not yet exist — satisfied here with a private inline `_FixtureAgent` (documented above). This is a known spec-vs-sequencing drift, not a structure conflict.

### References
- [epic-2 Story 2.9 spec + ACs](../planning-artifacts/epics/epic-2-protocol-kernel-koelcore.md)
- [addendum.md:178-186 — Interceptor/InterceptorChain authoritative signatures](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md)
- [prd.md:45 (F-A4), :133-134, :221-222 — interceptor chain feature + API](../planning-artifacts/prds/prd-koel-2026-05-27/prd.md)
- [architecture.md — interceptor location :767/:994; semantics :108-109; data flow :1077-1087; stream/async §4; error §5; naming :464](../planning-artifacts/architecture.md)
- [abstract_agent.dart — terminal SPI you wrap](../../packages/koel_core/lib/src/agent/abstract_agent.dart)
- [error_classifier.dart — `classify(Object, StackTrace?, RunAgentInput)`, const `DefaultErrorClassifier`, idempotent on KoelError](../../packages/koel_core/lib/src/error/error_classifier.dart)
- [run_events.dart:81-84 — `RunErrorEvent({required KoelError error})`; RunStarted/Finished fixture events](../../packages/koel_core/lib/src/event/run_events.dart)
- [run_agent_input.dart — `RunAgentInput` fields (all defaulted except threadId/runId)](../../packages/koel_core/lib/src/input/run_agent_input.dart)
- [2-8-raw-custom-events-integration-sweep.md — prior-story patterns + import/test convention](2-8-raw-custom-events-integration-sweep.md)

### Design decisions (RESOLVED — these are AC/convention-forced, not open)
All three were determined by the ACs and existing conventions, not by preference — baked in here so the dev has zero ambiguity. No confirmation gate.
1. **Classifier lives in `InterceptorChain`, defaulted to `const DefaultErrorClassifier()`.** Not a real fork: AC2 attributes the throw→`RunErrorEvent` conversion to *the chain*, tested here as `[A,B,C]` wrapping an agent with **no `KoelClient`** (that's Story 2.14, doesn't exist yet). So the classifier cannot live anywhere else. Story 2.14 injects its own classifier through the same parameter.
2. **Wrapped-agent parameter is named `agent`** (mirrors `KoelClient(agent:)` / addendum), not `terminal`. Cosmetic; chosen for cross-API consistency.
3. **Ordering assertion = drain-complete order.** With streaming, an interceptor's post-`proceed` code runs only after the downstream fully drains, so `[A,B,C]` logs `A enter…C enter, agent run, C exit…A exit`. That IS the proof of forward-in / reverse-out — there is no synchronous call-stack alternative for streams. Assert exactly this.

### Review Findings

_Code review 2026-05-30 (Blind Hunter + Edge Case Hunter + Acceptance Auditor). Verdict: PASS — all 3 ACs satisfied, 8/8 tests green, 100% line+branch coverage, scope clean. Findings below are hardening/precision only; none block acceptance._

- [x] [Review][Patch] `proceed` dartdoc overclaimed "Returns a single-subscription stream" — fixed: reworded to "Preserves the delegated stream's subscription model …" making clear the property is inherited from `AbstractAgent.run`'s single-listener contract (architecture §4), not unconditionally guaranteed. [packages/koel_core/lib/src/agent/interceptor.dart:96] (blind+edge+auditor)
- [x] [Review][Patch] Error-without-close path was untested — fixed: added test `'an error from a never-closing source terminates with one RunErrorEvent'` driving a `StreamController` that `addError`s without closing (then emits a dropped tail), asserting exactly one trailing `RunErrorEvent`, the post-error event is dropped, and the open source's `onCancel` fires. 9/9 interceptor tests + 437 koel_core tests green. [packages/koel_core/test/agent/interceptor_test.dart] (blind+edge)
- [x] [Review][Defer] Throwing `ErrorClassifier` escapes the "nothing escapes" invariant — `_runError` calls `classify` inside the unguarded `catch` (sync branch) and inside `handleError` (stream branch); a classifier that violates its no-throw contract would propagate uncaught. The default classifier never throws, so this is dormant until Story 2.14 injects a custom one. [packages/koel_core/lib/src/agent/interceptor.dart:105-108,126-130] — deferred, defensive-depth for 2.14 (blind)
- [x] [Review][Defer] Multiple-`proceed` (retry) re-subscription is untested — the immutable cursor is deliberately built to support it (Dev Notes §"Why this shape"; Epic 4 `RetryInterceptor`), but no test proves a second `proceed` re-subscribes cleanly with no index aliasing. Land the test alongside the retry built-in in `koel_http`. [packages/koel_core/test/agent/interceptor_test.dart] — deferred, ships with Epic 4 retry built-in (blind+edge)

## Dev Agent Record

### Agent Model Used

claude-opus-4-8 (Opus 4.8, 1M context) — via `/agent-flutter-engineer` implement mode.

### Debug Log References

- `dart test test/agent/interceptor_test.dart` → **8 passed**.
- `dart test` (full koel_core) → **436 passed** (baseline 428 + 8 new). No regressions.
- `dart analyze packages/koel_core` → "No issues found!"; `melos run analyze` (workspace) → all 10 packages clean.
- `dart format` → 2 files reformatted then `--set-exit-if-changed` clean.
- Coverage on `lib/src/agent/interceptor.dart` → **17/17 lines (100%)**, all branches exercised (≥ 90% N-12).
- **Two implementation-spec corrections discovered at the keyboard (see Completion Notes):** the `import run_events.dart` hint and the `async*`/`yield*` error-handling sketch in Dev Notes were both wrong; the shipped code diverges deliberately and is the correct form.

### Completion Notes List

- **All 3 ACs satisfied.** AC1: `abstract class Interceptor` + `class InterceptorChain.proceed` declared byte-exact to the addendum. AC2: ordering test proves `A→B→C→agent` forward / inverse unwind, and both throw sites short-circuit to a classified `RunErrorEvent` with no uncaught throw. AC3: a `.map`-transforming interceptor's output is observed in the drained events.
- **Spec correction #1 — import path.** Dev Notes Task 1 said to import `../event/run_events.dart` for `RunErrorEvent`. That file is `part of 'ag_ui_event.dart'` and **cannot be imported**. `RunErrorEvent` (and `RunStartedEvent`/`RunFinishedEvent`) come from importing `ag_ui_event.dart`, which is what the code does.
- **Spec correction #2 — error handling is NOT `async*` + `try/catch` around `yield*`.** The Dev Notes §"Why one async* try/catch handles both throw sites" is **wrong on two counts**, verified empirically:
  1. `yield* downstream` forwards a delegated stream's *errors* straight to the output stream — they bypass the surrounding `catch`. (Only the *synchronous* `intercept()` throw was caught; the 3 mid-stream-error tests failed.)
  2. Switching to `await for` *does* catch stream errors, but then cancelling a `proceed()` subscription suspended at `await for` **never propagates cancel to the inner subscription** — `sub.cancel()` hangs forever (reproduced in a standalone probe: cancel timed out, downstream `onCancel` never fired).

  Shipped form: `proceed` is a **synchronous** method. It builds the delegated stream inside a `try` (catches the synchronous `intercept()` throw → returns `Stream.value(RunErrorEvent)`), then pipes it through a `StreamTransformer.fromHandlers` whose `handleError` converts a stream-borne error into a terminal `RunErrorEvent` value and closes. A transformer is a plain pipe, so **cancellation propagates to the terminal stream untouched** (verified: `onCancel` fires, no `RunErrorEvent` on cancel) — satisfying the architecture §4 cancellation contract that the `await for` form would have silently broken.
- **`abstract class Interceptor`, not `abstract interface class`.** Followed AC1's verbatim wording. `implements Interceptor` works regardless; the one-method contract needs no `interface` marker.
- **No `MockAgent` (Story 3.1).** Terminal agent is a private inline `_FixtureAgent implements AbstractAgent`; no `koel_test` dependency added (would invert the dependency graph).
- **Classifier idempotence relied upon:** a thrown `KoelError` returns from `DefaultErrorClassifier` by identity (`raw is KoelError → raw`), asserted via `identical`.
- **Scope clean:** barrel `lib/koel_core.dart`, `pubspec.yaml`, `build.yaml`, `abstract_agent.dart`, and all event/error files untouched. No `build_runner` run — `Interceptor`/`InterceptorChain` are behavioral, no `*.freezed.dart`/`*.g.dart`.

### File List

New:
- `packages/koel_core/lib/src/agent/interceptor.dart`
- `packages/koel_core/test/agent/interceptor_test.dart`

## Change Log

| Date | Change |
|------|--------|
| 2026-05-30 | Implemented Story 2.9: `Interceptor` interface + `InterceptorChain.proceed()` (no built-ins). Ordering/unwind, dual throw-site short-circuit to classified `RunErrorEvent`, and stream-transformation observability all tested (8 tests). Error handling uses a `StreamTransformer` (not `async*`/`yield*`/`await for`) to catch stream-borne errors **while preserving cancellation** — correcting the Dev Notes sketch, which broke one or the other. All 3 ACs met; 436 koel_core tests green; analyze/format clean; interceptor.dart 100% line coverage. Status → review. |
