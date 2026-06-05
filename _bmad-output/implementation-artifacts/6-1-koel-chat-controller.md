---
baseline_commit: 1d5094ff0ac66c741f2fa2eca58f566f3744e562
---

# Story 6.1: `KoelChatController extends ChangeNotifier`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter developer,
I want `KoelChatController` wrapping a `ChatSession` with a synchronous `state` getter, an `isStreaming` getter, `send`/`cancel`/`clear` methods, and `notifyListeners()` on every state change,
so that I can integrate koel into any state-management framework (Bloc, Riverpod, GetX, Provider, `setState`) with one line per FR-D4.

## Acceptance Criteria

1. **Constructor + subscription lifecycle.** `packages/koel_flutter/lib/src/controller/koel_chat_controller.dart` exposes `class KoelChatController extends ChangeNotifier` with `KoelChatController({required ChatSession session})` exactly per Addendum A.6. The controller subscribes to `session.stream` on construction and cancels that subscription on `dispose()`. Every state change emitted by the session triggers `notifyListeners()`.

2. **Public surface matches Addendum A.6 exactly.** `ChatState get state` (synchronous read), `bool get isStreaming` (`true` iff `state.phase == RunPhase.running || state.phase == RunPhase.stepRunning`), `Future<void> send(String content)`, `void cancel()`, `Future<void> clear()` — and **nothing else public** beyond what `ChangeNotifier` already exposes. No extra parameters, no `tools` param on `send` (the A.6 signature is `send(String content)`).

3. **Provider + AnimatedBuilder streaming rebuild.** A widget test wrapping the controller in `ChangeNotifierProvider` (the `provider` package) under an `AnimatedBuilder`/`ListenableBuilder` listening to it: when the session emits `TextMessageContentEvent`s, the widget rebuilds with the accumulating message text, and `isStreaming` flips `false → true` on `send` and back to `false` on `RunFinishedEvent`.

4. **Five-framework integration, zero controller modification.** Widget tests prove the controller slots into each framework through its standard `Listenable` bridge with **no change to the controller**: Bloc (`BlocProvider.value` adapter), Riverpod (`ChangeNotifierProvider`), GetX (`Get.put`), Provider (`ChangeNotifierProvider`), plain `setState` (`AnimatedBuilder`/`ListenableBuilder`). All pass against the same unmodified `KoelChatController`.

## Tasks / Subtasks

- [x] **Task 1 — Wire package dependencies (AC: 1,2,3,4)**
  - [x] Add to `packages/koel_flutter/pubspec.yaml`: `flutter:` (`sdk: flutter`) and `koel_core:` under `dependencies`.
  - [x] Add **test-only** `dev_dependencies` (must NOT leak into `dependencies` — API-surface discipline): `flutter_test` (`sdk: flutter`), `koel_test:` (for `MockAgent`/fixtures), and the four state-mgmt packages used only to prove AC4 — `provider`, `flutter_bloc`, `flutter_riverpod`, `get`. Use `resolution: workspace` for the intra-repo deps.
  - [x] Run `dart pub get` (or `flutter pub get`) at the workspace root; confirm the lock resolves with the pinned `freezed 3.2.6-dev.1` already in the tree (AI-5.9 watch — do not bump it).
- [x] **Task 2 — Implement `KoelChatController` (AC: 1,2)**
  - [x] Create `lib/src/controller/koel_chat_controller.dart`. `class KoelChatController extends ChangeNotifier` (import `package:flutter/foundation.dart` — `ChangeNotifier`, not `package:flutter/widgets.dart`).
  - [x] Constructor `KoelChatController({required ChatSession session})`: store `session`; in the body, assign `late final StreamSubscription<ChatState> _sub = session.stream.listen((_) { ... })`. Subscribe **in the constructor**, not lazily.
  - [x] `ChatState get state => _session.state;` — delegate, do NOT cache a second copy (single source of truth, always fresh; the session already holds `_state`).
  - [x] `bool get isStreaming` → `state.phase == RunPhase.running || state.phase == RunPhase.stepRunning`.
  - [x] `Future<void> send(String content) => _session.send(content);` — drop the session's optional `tools` param (A.6 surface).
  - [x] `void cancel() => _session.cancel();` — synchronous; the session synthesizes `RunPhase.cancelled` and emits, which relays through the listener.
  - [x] `Future<void> clear() => _session.clear();`
  - [x] Listener body: call `notifyListeners()` on each emission. Guard against a post-dispose notify (the `ChangeNotifier` asserts if notified after `dispose` in debug). Cancelling `_sub` in `dispose` before `super.dispose()` already prevents late emits, but keep the guard defensive.
  - [x] `@override void dispose()`: `_sub.cancel();` then `super.dispose();`. Do **NOT** call `_session.dispose()` — see Design Decision D1.
- [x] **Task 3 — Barrel export (AC: 2)**
  - [x] Add `export 'src/controller/koel_chat_controller.dart';` to `lib/koel_flutter.dart`. Export only the controller — `ChatSession`/`ChatState`/`RunPhase` reach consumers through `koel_core`, never re-exported here (no surface duplication).
  - [x] Contract-form dartdoc on the class and every public member (NFR-16) — `KoelChatController` is on the 1.x public contract (one-way door).
- [x] **Task 4 — Establish the Flutter test harness (AC: 3,4) — FIRST Flutter package in the repo**
  - [x] `koel_flutter` is the first package whose tests import `package:flutter_test`. `dart test` **cannot** load these (no Flutter engine binding). Update `tool/test_package.sh` to detect a Flutter package (pubspec declares `flutter:` under `dependencies` / `sdk: flutter`) and run `flutter test --exclude-tags=perf` instead of `dart test`, preserving the existing no-tests exit-code tolerance (0/65/79). Keep pure-Dart packages on `dart test`.
  - [x] Verify `melos run analyze` and `melos run test` both pass for `koel_flutter` after the harness change, and that the existing pure-Dart packages still run under `dart test` (no regression to the sweep).
- [x] **Task 5 — Tests (AC: 1,2,3,4)**
  - [x] AC1/AC2 unit: construct via `KoelClient(agent: MockAgent.fromFixture('text_only_run')).newSession()`; assert subscription established, `state`/`isStreaming` read correctly, `dispose()` cancels the subscription (no notify after dispose), and the public surface matches A.6.
  - [x] AC3 `testWidgets`: `ChangeNotifierProvider.value` + `AnimatedBuilder`; drive the fixture run; assert accumulating text rebuilds and the `isStreaming` `false→true→false` transition across `send` → `RunFinishedEvent`.
  - [x] AC4: one `testWidgets` per framework (Bloc, Riverpod, GetX, Provider, setState) against the **same unmodified** controller. The proof is that each framework's standard `Listenable` bridge consumes it with zero controller-side code.
  - [x] Target ≥ 90% coverage (foundation tier) — see Testing Requirements. Coverage-gate wiring in `melos run test:coverage` / `tool/coverage.sh` is finalized in Story 6.8; do not block 6.1 on the gate entry, but write tests to the 90% bar now.

## Dev Notes

### Design decisions (locked — implement as stated)

- **D1 — The controller does NOT own the injected `ChatSession`; `dispose()` must NOT dispose it.** The constructor *injects* the session (`required ChatSession session`), so the caller owns its lifecycle. `KoelChatController.dispose()` cancels only its own `session.stream` subscription and calls `super.dispose()`. Rationale: (a) injection = caller ownership (Flutter idiom); (b) `KoelClient.dispose()` already cancels+disposes every session it created ([koel_client.dart:163](../../packages/koel_core/lib/src/client/koel_client.dart#L163)) — double-dispose would be wrong; (c) parity — CopilotKit's `useCopilotChat` hook binds a runtime it does not own. A consumer that wants the controller to also tear the session down can do so explicitly outside the controller.
- **D2 — `state` delegates to `_session.state`; no second cached field.** The session is the single source of truth ([chat_session.dart:38](../../packages/koel_core/lib/src/client/chat_session.dart#L38)). Caching a copy in the controller risks divergence and adds an allocation per emit for nothing. The listener's only job is to relay `notifyListeners()`.
- **D3 — `send` drops the session's optional `tools` param.** Addendum A.6 pins `Future<void> send(String content)`. Per-call tool overrides are not on the controller's 1.x surface; a power user reaches `ChatSession.send(content, tools: ...)` directly.

### `ChatSession` collaborator surface (koel_core — already implemented, do not modify)

Read [chat_session.dart](../../packages/koel_core/lib/src/client/chat_session.dart) in full before coding. The controller is a thin `ChangeNotifier` skin over it:

- `ChatState get state` — synchronous, always current. → `controller.state`.
- `Stream<ChatState> get stream` — **broadcast, does NOT replay** ([chat_session.dart:42](../../packages/koel_core/lib/src/client/chat_session.dart#L42)). Subscribe for changes; read `state` for "now" (the `ValueListenable` idiom). Because `state` is read live via the getter, the no-replay property is harmless to the controller.
- `Future<void> send(String content, {List<ToolDefinition>? tools})` — optimistically folds the user message, runs the pipeline, completes when the run finishes.
- `void cancel()` — synchronous; emits `RunPhase.cancelled` immediately (no cancel *event*).
- `Future<void> clear()` — emits a fresh `const ChatState()` then deletes persisted copy.
- `void dispose()` — session-owned teardown; **the controller never calls this** (D1).

### `ChatState` / `RunPhase` (drives `isStreaming`)

[chat_state.dart](../../packages/koel_core/lib/src/state/chat_state.dart). `RunPhase` = `{ idle, running, stepRunning, error, cancelled }`. `isStreaming` is `true` for `running` **or** `stepRunning` only — not `error`/`cancelled`/`idle`. `ChatState` is freezed, deep-`==` comparable (Riverpod-friendly); never mutate in place.

### Cancel-correct teardown — the house pattern

This story is the named target of the cancel-teardown house pattern: [docs/patterns/stream-cancellation.md §"Epic 6 `KoelChatController`"](../../docs/patterns/stream-cancellation.md) (Epic-5 retro AI-5.8, re-carried from Epic-4 AI#3). The controller's case is the **simple** end of that pattern: it listens to a *broadcast `StreamController<ChatState>`*, not the transport's `async*` — the full watchdog+force-abort machinery lives in `koel_http` and is already exercised by `ChatSession.cancel()`. For 6.1, "cancel-correct" means: **own the subscription, cancel it in `dispose`, and never `await` a teardown a stalled transport could hang.** `cancel()` delegates to `_session.cancel()` (which itself never blocks) — do not add an `await` on any teardown in the controller's own `cancel`/`dispose` path. No `catch (_) {}` anywhere (CLAUDE.md: no silent failures).

### Integration-test wiring (AC3/AC4)

Construct the unit-under-test the way Story 6.7's smoke test will:

```dart
final client = KoelClient(agent: MockAgent.fromFixture('text_only_run'));
final controller = KoelChatController(session: client.newSession());
// ... await controller.send('hi'); pump; assert controller.state.messages / isStreaming
addTearDown(() { controller.dispose(); client.dispose(); }); // controller first, then the owner
```

`MockAgent.fromFixture(...)` is koel_test, Addendum A.9. The fixture `text_only_run.jsonl` is bundled in `koel_test` and emits a `RUN_STARTED → TEXT_MESSAGE_* → RUN_FINISHED` sequence — exactly what AC3 needs for the streaming-rebuild + `isStreaming` transition assertions.

**AC4 framing — the point IS the absence of an adapter.** FR-D4's value is that `KoelChatController` is a plain `ChangeNotifier`/`Listenable`, so every framework consumes it through its own standard "listen to a Listenable" path with **zero controller-side code**. Name each framework's entry point, keep the wiring minimal/idiomatic, and assert the same observable behavior (rebuild on emit) across all five. Do not write framework-specific code *into* the controller — if you find yourself needing to, the design is wrong.

### Project Structure Notes

- File: `packages/koel_flutter/lib/src/controller/koel_chat_controller.dart` (matches architecture source tree, [architecture.md:896-897](../planning-artifacts/architecture.md#L896)). Barrel: `lib/koel_flutter.dart`.
- **`koel_flutter` is the first Flutter (non-pure-Dart) package implemented.** `koel_core`/`koel_http`/etc. are pure Dart and run under `dart test`. The monorepo's `test` script (`tool/test_package.sh`) hardcodes `dart test`, which cannot run `flutter_test` widget tests — Task 4 fixes this. Similarly `tool/coverage.sh` (`dart test --coverage`) will need `flutter test --coverage` for koel_flutter, but coverage-gate wiring is Story 6.8 scope; only the *test runner* must work for 6.1.
- `dart analyze .` (the `analyze` gate) works unchanged on Flutter packages.
- `koel_lints` is already the shared analysis profile (dev_dependency). Keep it.

### Epic-5 retro carry-ins relevant here

- **AI-5.8 (cancel-teardown note)** — landed as [docs/patterns/stream-cancellation.md](../../docs/patterns/stream-cancellation.md), aimed at this story. Follow it (above).
- **AI-5.2 (`Message` timestamp parity)** — closed in commit `70b89f8`; it gated **6.3** (Hive persistence round-trip), not 6.1. No action here.
- **AI-5.9 (freezed `3.2.6-dev.1` pin watch)** — surfaces at 6.3/6.5 (Hive/sealed codegen). 6.1 adds no codegen; just do not bump the pin during `pub get`.

### References

- [Source: epics/epic-6-flutter-glue-persistence-koelflutter.md#Story-6.1] — user story + ACs.
- [Source: prds/prd-koel-2026-05-27/addendum.md#A.6] (lines 392-401) — canonical `KoelChatController` signature.
- [Source: packages/koel_core/lib/src/client/chat_session.dart] — collaborator surface.
- [Source: packages/koel_core/lib/src/state/chat_state.dart] — `ChatState` / `RunPhase` (`isStreaming`).
- [Source: packages/koel_core/lib/src/client/koel_client.dart#L153] — `newSession` / construction.
- [Source: docs/patterns/stream-cancellation.md] — cancel-correct teardown house pattern (AI-5.8).
- [Source: prds/prd-koel-2026-05-27/addendum.md#A.9] — `MockAgent.fromFixture`.
- FR-D4 (LCD Flutter binding) — implementation-readiness-report-2026-05-28.md:119,254.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8)

### Debug Log References

- All gates green: `melos run analyze` (11 pkgs clean), `melos run test` (full sweep SUCCESS), `melos run format:check` (0 changed).
- `koel_flutter` suite: 13 tests pass via `flutter test` (8 controller unit + 5 framework integrations); harness routing verified by running `tool/test_package.sh` directly in the package (exit 0).

### Completion Notes List

- **Controller is a thin delegating skin** over `ChatSession` — `state`/`isStreaming` are pure reads, `send`/`cancel`/`clear` delegate, the lone listener relays `notifyListeners()`. Design decisions D1–D3 implemented as specified: no session ownership (dispose cancels only the subscription), `state` delegates (no cached copy), `send(String)` drops the session's optional `tools`.
- **D1 verified by test** — after `controller.dispose()` the injected session is still alive and usable (`session.send` works), and the disposed controller emits no further `notifyListeners` ticks (subscription cancelled + `_disposed` guard).
- **First Flutter package in the monorepo.** `tool/test_package.sh` now detects the Flutter SDK in a package pubspec (`grep "sdk: flutter"`) and routes to `flutter test`; pure-Dart packages stay on `dart test`. Verified no regression across the existing 9 packages (full sweep green).
- **AC4 Bloc lane needed the named adapter.** `provider`'s debug guard (`_debugCheckInvalidValueType`) throws when a raw `ChangeNotifier` is placed in a plain `Provider`/`RepositoryProvider`, and `BlocProvider` requires a `BlocBase`. So a ~6-line external `_ControllerCubit` mirrors controller state into Bloc via `BlocProvider.value` — exactly the "BlocProvider.value adapter" AC4 names. The controller itself is unmodified; all five frameworks (provider, bloc, riverpod, getx, setState) consume the **same** instance.
- **AC4 Riverpod ownership note.** `flutter_riverpod`'s `ChangeNotifierProvider` (2.6.1, not deprecated) takes ownership and disposes the notifier when the scope unmounts, so that test lets Riverpod own disposal (no manual `controller.dispose`) — a real reflection of D1's "whoever constructs/owns it disposes it."
- **Dep pin held (AI-5.9 watch).** `flutter pub get` resolved with `analyzer 12.1.0` / `freezed 3.2.6-dev.1` intact — no bump. The four state-mgmt packages are `dev_dependencies` only (the package ships zero framework dependency).
- **Coverage:** every public member of `KoelChatController` is exercised (constructor, `state`, `isStreaming` across idle/running/**stepRunning**/**error**/cancelled, `send`, `cancel`, `clear`, `dispose` including the idempotent double-dispose). The `melos run test:coverage` gate entry for `koel_flutter` (needs `flutter test --coverage` in `tool/coverage.sh`) is Story 6.8 scope per the epic; not wired here.
- **Test agent: `MockAgent.programmatic()`, not `fromFixture`.** Task 5 / the Dev-Notes "Integration-test wiring" name `MockAgent.fromFixture('text_only_run')`, but the suite drives a programmatic `streamingHelloAgent()` builder emitting the same `RUN_STARTED → TEXT_MESSAGE_* → RUN_FINISHED` shape. Intentional substitution: the programmatic agent is synchronous to construct (no `await`) and emits **two** `TEXT_MESSAGE_CONTENT` deltas, so it proves AC3 accumulation (`Hello` → `Hello world`) more strongly than a single-delta fixture would. No AC depends on fixture provenance; `fromFixture` stays the Story 6.7 smoke-test path.

### File List

- `packages/koel_flutter/pubspec.yaml` (modified — flutter + koel_core deps; dev: flutter_test, koel_test, provider, flutter_bloc, flutter_riverpod, get)
- `packages/koel_flutter/lib/koel_flutter.dart` (modified — barrel exports the controller)
- `packages/koel_flutter/lib/src/controller/koel_chat_controller.dart` (new — `KoelChatController`)
- `packages/koel_flutter/test/support/test_agent.dart` (new — streaming MockAgent + `assistantText` helper)
- `packages/koel_flutter/test/controller/koel_chat_controller_test.dart` (new — AC1/AC2 unit tests)
- `packages/koel_flutter/test/integration/state_management_test.dart` (new — AC3 + AC4 five-framework widget tests)
- `tool/test_package.sh` (modified — route Flutter packages to `flutter test`)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified — tracking: epic-6 in-progress, 6-1 review)

## Change Log

- 2026-06-05 — Implemented Story 6.1 `KoelChatController extends ChangeNotifier` (FR-D4): controller, barrel export, Flutter test harness routing, and AC1–AC4 tests (13 passing). All gates green. Status → review.

## Review Findings

_Adversarial code review 2026-06-05 (Blind Hunter + Edge Case Hunter + Acceptance Auditor). Gates re-verified green: analyze 11/11 clean, full test sweep SUCCESS (koel_flutter 13/13), format 0 changed. All four ACs and D1–D3 confirmed PASS by the Acceptance Auditor._

- [x] [Review][Patch] `isStreaming` `stepRunning` branch and the `RunPhase.error` path are untested [packages/koel_flutter/lib/src/controller/koel_chat_controller.dart:46-47] — every test drives a flat `running → idle`/`cancelled` agent; the `stepRunning == true` branch of `isStreaming` and the whole error fold (`isStreaming == false`, `notifyListeners` fires, `send` future still completes) are never exercised. Gap against the ≥90% foundation-tier bar (Task 5). Add a `STEP_*`-emitting agent test and a `RunErrorEvent` test.
- [x] [Review][Patch] `dispose()` is not idempotent — a second call throws the `ChangeNotifier` debug assertion [packages/koel_flutter/lib/src/controller/koel_chat_controller.dart:62-67] — the `_disposed` flag is already set but only guards the listener, not `dispose()` itself. Real double-dispose path: a host that owns the controller (e.g. Riverpod's `ChangeNotifierProvider`) disposes it, and the app code disposes it too. The wrapped `ChatSession.dispose()` is documented idempotent; the controller silently is not. Fix: `if (_disposed) return;` at the top of `dispose()` (reuses the existing flag) + a double-dispose test. Hardening call — stock `ChangeNotifier` is non-idempotent, but the existing `_disposed` field and CLAUDE.md "design for what users can't misuse" favor closing it.
- [x] [Review][Patch] Story doc names `MockAgent.fromFixture('text_only_run')` but the tests use `MockAgent.programmatic()` [_bmad-output/implementation-artifacts/6-1-koel-chat-controller.md Task 5 / Dev Notes] — intentional, defensible (the programmatic agent emits the same `RUN_STARTED → TEXT_MESSAGE_* → RUN_FINISHED` shape and is arguably stronger for AC3 since two deltas prove accumulation), and violates no AC. But Task 5's `[x]` box and the Integration-test-wiring note still name the fixture form. Update the Completion Notes / Task wording to record the fixture→programmatic substitution so the checklist matches reality.
- [x] [Review][Defer] `tool/test_package.sh` Flutter branch does not honor the 65/79 no-tests exit codes it claims to preserve, and `grep "sdk: flutter"` is coarser than Task 1's "flutter under `dependencies`" intent [tool/test_package.sh:28-40] — deferred, latent. `flutter test` does not emit 65/79, so the tolerance block is a no-op on the Flutter branch (the top-of-file empty-dir guard still covers the common case); and the unanchored grep also matches `flutter_test:`'s `sdk: flutter` (would mis-route a hypothetical pure-Dart package carrying `flutter_test`) while `koel_widgets`/`koel_devtools` — which declare `flutter` only as an `environment` SDK constraint, no `sdk: flutter` dep line — would route to `dart test` the moment they gain widget tests. Only `koel_flutter` qualifies today, so no live mis-route. Revisit when a second Flutter package or an all-perf-tagged Flutter suite lands.
