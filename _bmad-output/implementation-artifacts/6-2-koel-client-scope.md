---
baseline_commit: 225e7ba
---

# Story 6.2: `KoelClientScope extends InheritedWidget`

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter developer,
I want `KoelClientScope` publishing a `KoelClient` down the widget tree with a `KoelClientScope.of(context)` lookup,
so that descendant widgets resolve the client without a service-locator or `get_it` per FR-D5.

## Acceptance Criteria

1. **Class shape + signature match Addendum A.6 exactly.** `packages/koel_flutter/lib/src/scope/koel_client_scope.dart` exposes `class KoelClientScope extends InheritedWidget` with `const KoelClientScope({required this.client, required super.child, super.key})` and `final KoelClient client`. `static KoelClient of(BuildContext context)` returns the nearest ancestor scope's client. `@override bool updateShouldNotify(KoelClientScope old) => client != old.client`. **Nothing else public** beyond what `InheritedWidget` already exposes — no `maybeOf`, no extra fields, no exposed dependency-mode variants (Design Decision D3).

2. **`of(context)` resolves the nearest ancestor and registers a dependency.** Given a tree `KoelClientScope(client: c, child: MaterialApp(...))`, a descendant calling `KoelClientScope.of(context)` returns exactly `c`. The lookup uses `dependOnInheritedWidgetOfExactType<KoelClientScope>()` so the calling element becomes a dependent (Design Decision D2).

3. **Swapping `client` rebuilds dependents exactly once.** When the scope is rebuilt with a **different** `KoelClient` instance, `updateShouldNotify` returns `true` and every dependent that called `of(context)` rebuilds **exactly once**; rebuilding the scope with the **same** client instance does **not** rebuild dependents (`updateShouldNotify` returns `false`).

4. **No-ancestor lookup throws a remediating `FlutterError`.** A descendant calling `KoelClientScope.of(context)` with no `KoelClientScope` ancestor throws a `FlutterError` (not a stripped-in-release `assert`, not a null-deref) whose message names the failure and tells the caller to wrap the app in a `KoelClientScope`. Verified by `expect(tester.takeException(), isFlutterError)` plus a message-content assertion.

## Tasks / Subtasks

- [x] **Task 1 — Implement `KoelClientScope` (AC: 1,2,3,4)**
  - [x] Create `lib/src/scope/koel_client_scope.dart`. `import 'package:flutter/widgets.dart';` (carries `InheritedWidget`, `BuildContext`, `FlutterError`, the `ErrorSummary`/`ErrorDescription`/`ErrorHint` diagnostics) and `import 'package:koel_core/koel_core.dart';` (carries `KoelClient` — exported at [koel_core.dart:27](../../packages/koel_core/lib/koel_core.dart#L27)). No other imports; the package adds **no** new dependency (pubspec already has `flutter` + `koel_core`).
  - [x] `class KoelClientScope extends InheritedWidget` with `const KoelClientScope({required this.client, required super.child, super.key});` and `final KoelClient client;` — verbatim A.6. Keep the `const` constructor even though call sites won't be const (a runtime-built `KoelClient` is never a const expression) — it matches A.6 and costs nothing.
  - [x] `static KoelClient of(BuildContext context)`: call `context.dependOnInheritedWidgetOfExactType<KoelClientScope>()` (Design Decision D2 — the subscribing variant, **not** `getElementForInheritedWidgetOfExactType`). If the result is `null`, throw a `FlutterError.fromParts([...])` (AC4 / Design Decision D4); otherwise return `scope.client`.
  - [x] `@override bool updateShouldNotify(KoelClientScope old) => client != old.client;` — narrowing the base's `covariant InheritedWidget oldWidget` to `KoelClientScope old` is legal and matches A.6. `KoelClient` has **no `==` override** ([koel_client.dart:57](../../packages/koel_core/lib/src/client/koel_client.dart#L57) — identity equality), so `!=` is an identity check: a new client instance notifies, the same instance does not (AC3). Do **not** add a value-equality shim.
  - [x] Contract-form dartdoc on the class, `client`, `of`, and `updateShouldNotify` (NFR-16) — `KoelClientScope` is on the 1.x public contract (one-way door). Note in the `of` doc that it registers a dependency (rebuilds the caller on client swap).
- [x] **Task 2 — Barrel export (AC: 1)**
  - [x] Add `export 'src/scope/koel_client_scope.dart';` to `lib/koel_flutter.dart`, under a `// ---- Scope: InheritedWidget client publication (F-D5) ----` banner mirroring the existing controller banner. Export only the scope — `KoelClient` reaches consumers through `koel_core` / the `koel` meta-package, never re-exported here (no surface duplication — the barrel doc already states this rule).
- [x] **Task 3 — Tests (AC: 1,2,3,4)**
  - [x] Create `test/scope/koel_client_scope_test.dart`. Build a real `KoelClient(agent: ...)` for the published value — reuse the existing `streamingHelloAgent()` / programmatic `MockAgent` from [test/support/test_agent.dart](../../packages/koel_flutter/test/support/test_agent.dart) so no fixture/IO is needed; `addTearDown(client.dispose)`.
  - [x] AC2 `testWidgets`: pump `KoelClientScope(client: c, child: Builder(builder: (ctx) { resolved = KoelClientScope.of(ctx); return const SizedBox(); }))`; assert `identical(resolved, c)`.
  - [x] AC3 `testWidgets` — **exactly-once rebuild**: a descendant `Builder` increments a build counter and calls `of(context)`. Pump with client A; record the count. Rebuild the **parent** (e.g. via a `StatefulBuilder`/`setState`) supplying a **new** client B; `await tester.pump()`; assert the counter incremented by **exactly 1** and the resolved client is now B. Then rebuild with the **same** B instance and assert the counter did **not** advance (`updateShouldNotify == false`). Dispose both clients in tear-down.
  - [x] AC4 `testWidgets`: pump a bare `Builder` (no scope ancestor) whose `builder` calls `KoelClientScope.of(context)`; assert `expect(tester.takeException(), isA<FlutterError>())` and that the exception's message contains the remediation substring (e.g. `'KoelClientScope'`). Use `tester.takeException()` (the throw happens during build, not as a thrown-from-`of` you can `try` around).
  - [x] AC1 surface guard: a compile-level / reflection-free assertion is impractical, but assert the observable contract — `of` returns the client, `updateShouldNotify` true on swap / false on same — is covered by AC2/AC3. No `maybeOf` exists (do not write a test for a symbol that must not exist).
  - [x] Target ≥ 90% coverage (foundation tier). The class has four members; AC2/AC3/AC4 exercise `of` (both branches), `updateShouldNotify` (both branches), and the constructor. Coverage-gate wiring (`tool/coverage.sh` → `flutter test --coverage`) is Story 6.8 scope — write to the 90% bar now, do not block 6.2 on the gate entry.
- [x] **Task 4 — Verify gates green (AC: 1,2,3,4)**
  - [x] `melos run analyze` (all 11 pkgs clean), `melos run test` (full sweep SUCCESS — `koel_flutter` routes to `flutter test` via the [tool/test_package.sh](../../tool/test_package.sh) detection landed in 6.1), `melos run format:check` (0 changed). No new dependency → no `pub get` churn expected; if the lock touches, confirm `analyzer 12.1.0` / `freezed 3.2.6-dev.1` are intact (AI-5.9 watch — do not bump).

## Dev Notes

### Design decisions (locked — implement as stated)

- **D1 — The scope publishes the client but does NOT own it; there is no `dispose`.** `InheritedWidget` is immutable and stateless — it has no `dispose` hook, and `KoelClientScope` must not grow one. The client is *injected* (`required this.client`), so the caller owns its lifecycle and disposes it (`KoelClient.dispose()` cancels+disposes every session it created — [koel_client.dart:165](../../packages/koel_core/lib/src/client/koel_client.dart#L165)). This is the exact parity of Story 6.1's D1 (the controller does not own the session it's handed) and of `graphql_flutter`'s `GraphQLProvider`, the named prior art for this widget ([addendum.md:627](../planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#L627)).

- **D2 — `of` uses `dependOnInheritedWidgetOfExactType`, NOT `getElementForInheritedWidgetOfExactType`.** AC3 mandates that swapping the scope's `client` rebuilds dependent widgets exactly once. Only the *subscribing* lookup (`dependOnInheritedWidgetOfExactType`) registers the calling element as a dependent so the framework marks it dirty when `updateShouldNotify` returns true ([framework.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/widgets/framework.dart) — `Element.dependOnInheritedWidgetOfExactType` → `dependOnInheritedElement` → registers in `_dependents`). `getElementForInheritedWidgetOfExactType` reads **without** subscribing (used inside `initState`/callbacks where a dependency would be illegal/unwanted) and would make AC3 unobservable. The A.6 surface pins a single `of`, so there is no non-subscribing variant to expose. **FYI (deliberately not built):** a `KoelClient readClient(BuildContext)` non-subscribing accessor for `initState`-time reads is a plausible future ask, but it is *not* on the A.6 1.x surface — omitted to keep the one-way door narrow (parity decides; see [[project_parity_decides_ambiguous_api]]). A consumer needing an `initState`-time read can capture the client in `didChangeDependencies` instead.

- **D3 — Public surface is exactly A.6: constructor, `client`, `of`, `updateShouldNotify`. No `maybeOf`.** Story 6.1's review held the controller to A.6 verbatim (dropped the session's `tools` param, added no extras). Same discipline here: do not add a `maybeOf` (nullable-returning) convenience — A.6 lists only `of`, and the no-ancestor case is a programming error that should fail loudly (AC4), not return null. Adding `maybeOf` is a one-way-door surface expansion with no AC behind it.

- **D4 — No-ancestor failure is a thrown `FlutterError` with structured diagnostics, never a bare `assert` or null-deref.** AC4 requires a real throw (asserts are stripped in release; a null-deref gives an opaque `Null` error). Use the framework's `of`-failure idiom — `FlutterError.fromParts([ErrorSummary, ErrorDescription, ErrorHint, context.describeElement(...)])` — exactly as `Scaffold.of` / `Material.of` do in framework source ([material/scaffold.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/scaffold.dart) `Scaffold.of`; [material/material.dart](https://github.com/flutter/flutter/blob/master/packages/flutter/lib/src/material/material.dart) `Material.of`). The `ErrorHint` carries the remediation: *"Wrap your app (or the subtree that needs the client) in a KoelClientScope."* No `catch (_) {}` anywhere (CLAUDE.md: no silent failures).

### Canonical implementation shape (A.6 + framework idiom)

```dart
import 'package:flutter/widgets.dart';
import 'package:koel_core/koel_core.dart';

/// Publishes a [KoelClient] to the widget subtree so descendants resolve it via
/// [KoelClientScope.of] — no service-locator, no `get_it` (FR-D5).
class KoelClientScope extends InheritedWidget {
  const KoelClientScope({required this.client, required super.child, super.key});

  final KoelClient client;

  /// The nearest ancestor's client. Registers the caller as a dependent, so it
  /// rebuilds when the scope is given a different client. Throws a [FlutterError]
  /// if no [KoelClientScope] ancestor exists.
  static KoelClient of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<KoelClientScope>();
    if (scope == null) {
      throw FlutterError.fromParts([
        ErrorSummary(
          'KoelClientScope.of() called with a context that has no KoelClientScope ancestor.',
        ),
        ErrorHint(
          'Wrap your app (or the subtree that needs the client) in a '
          'KoelClientScope, e.g.\n'
          '  KoelClientScope(client: client, child: MaterialApp(...))',
        ),
        context.describeElement('The context used was'),
      ]);
    }
    return scope.client;
  }

  @override
  bool updateShouldNotify(KoelClientScope old) => client != old.client;
}
```

Treat this as the contract, not boilerplate to paraphrase — the signatures are pinned by A.6 and the ACs. Add the full contract-form dartdoc (every public member) before shipping.

### `KoelClient` collaborator surface (koel_core — already implemented, do not modify)

The published value. Relevant facts for this story:

- Constructed `KoelClient({required AbstractAgent agent, ...})` — non-singleton (FR-D3), holds no static mutable state ([koel_client.dart:57-83](../../packages/koel_core/lib/src/client/koel_client.dart#L57)). For tests, build one with the existing programmatic `MockAgent` helper in [test/support/test_agent.dart](../../packages/koel_flutter/test/support/test_agent.dart).
- **No `operator ==`** ([koel_client.dart](../../packages/koel_core/lib/src/client/koel_client.dart) — none defined) → identity equality. This is *why* `updateShouldNotify` can be the trivial `client != old.client`: distinct instances are distinct, the same instance is equal. Do not add an equality shim to the client or the scope.
- `void dispose()` is idempotent ([koel_client.dart:165](../../packages/koel_core/lib/src/client/koel_client.dart#L165)) — the scope never calls it (D1); tests that build a client own its tear-down (`addTearDown(client.dispose)`).
- `KoelClient` is surfaced by the `koel_core` barrel ([koel_core.dart:27](../../packages/koel_core/lib/koel_core.dart#L27)) — import `package:koel_core/koel_core.dart`, never `src/`.

### `InheritedWidget` mechanics that drive the ACs

- `InheritedWidget` is a `ProxyWidget` with an `InheritedElement`. `dependOnInheritedWidgetOfExactType<T>()` walks `_inheritedElements` (an O(1) hash lookup populated as the element tree mounts — **not** an O(depth) walk), registers the caller in the inherited element's `_dependents`, and returns the widget. When the scope rebuilds and `updateShouldNotify` returns `true`, `InheritedElement.notifyClients` marks each dependent dirty → each rebuilds **once** that frame (AC3's "exactly once").
- `updateShouldNotify` is called by the framework only when the `InheritedWidget` itself is rebuilt with a new instance (parent rebuild). Returning `false` short-circuits dependent notification entirely — that is the "same client instance → no rebuild" half of AC3.
- The `const` constructor preserves element identity across rebuilds *when the call site is const* — but a runtime `KoelClient` is never const, so in practice every `KoelClientScope(...)` is a fresh widget each parent build. That's fine: identity of the *widget* doesn't matter; `updateShouldNotify` gates the dependents on the *client field*, which is the intended behavior. Keep `const` on the constructor (A.6) regardless.

### Testing (AC3 — the exactly-once trap)

The "rebuilds exactly once" assertion is the easy place to write a passing-but-wrong test. Pitfalls:

- **Rebuild the parent, not the descendant.** `updateShouldNotify` only fires when the *scope* is rebuilt with a new widget. Wrap the scope in a `StatefulBuilder`; on `setState`, hand the scope a different `client`. If you instead rebuild the descendant directly you're testing `setState`, not the inherited dependency.
- **Count in the descendant that called `of`.** Increment a counter inside that `Builder`'s closure. After the swap-`pump`, assert `+1` exactly; after a same-client `pump`, assert `+0`.
- **`pump`, not `pumpAndSettle`.** No animation is in play; `pumpAndSettle` can mask an unintended extra frame.
- **AC4 uses `tester.takeException()`.** The `FlutterError` is thrown during the descendant's `build`, so it surfaces through the test binding, not as a value you can `try/catch` around the `of` call. Assert `isA<FlutterError>()` and a message substring.

The Flutter test harness already runs for this package — `tool/test_package.sh` routes `koel_flutter` to `flutter test` (landed in Story 6.1). No harness change needed here.

### Project Structure Notes

- File: `packages/koel_flutter/lib/src/scope/koel_client_scope.dart` — matches the architecture source tree exactly ([architecture.md:898-899](../planning-artifacts/architecture.md#L898) — `scope/koel_client_scope.dart # F-D5 InheritedWidget`). Barrel: `lib/koel_flutter.dart` (already exists; add one export line).
- This is the **second** symbol in `koel_flutter` (after `KoelChatController`). The `scope/` directory is new; `controller/` already exists. No other package is touched.
- `koel_lints` is the shared analysis profile (dev_dependency, already wired). The barrel already documents the "re-export nothing from koel_core" rule — honor it (export the scope only).
- No new dependency, no codegen, no `pub get` requirement (contrast Story 6.1, which added the four state-mgmt dev-deps and the test-harness routing). This is a small, self-contained story.

### Carry-ins from Epic-5 retro / Story 6.1

- **AI-5.9 (freezed `3.2.6-dev.1` pin watch)** — 6.2 adds no codegen and no dependency; just do not bump the pin if the lock is touched.
- **6.1 deferred item (`tool/test_package.sh` Flutter-branch 65/79 + coarse grep)** — latent, not triggered by 6.2 (still only `koel_flutter` qualifies as a Flutter package; no mis-route). No action here. Will resurface when `koel_widgets`/`koel_devtools` gain widget tests (Epic 7/8).
- **House pattern parity with 6.1's D1** — "injected collaborator ⇒ caller owns lifecycle." The scope (D1) and the controller (6.1 D1) make the identical call: publish/wrap, never dispose, the injector disposes. Keep them consistent.

### References

- [Source: epics/epic-6-flutter-glue-persistence-koelflutter.md#Story-6.2] — user story + the four ACs.
- [Source: prds/prd-koel-2026-05-27/addendum.md#A.6] (lines 403-407) — canonical `KoelClientScope` signature (`const` ctor, `client` field, `static of`).
- [Source: prds/prd-koel-2026-05-27/addendum.md#L627] — `graphql_flutter` `GraphQLProvider` as the named `InheritedWidget`-client-injection prior art.
- [Source: packages/koel_core/lib/src/client/koel_client.dart] — `KoelClient` surface; no `==` override; idempotent `dispose`.
- [Source: packages/koel_core/lib/koel_core.dart#L27] — `KoelClient` barrel export (the import path).
- [Source: architecture.md#L898] — source-tree placement of `scope/koel_client_scope.dart`.
- [Source: _bmad-output/implementation-artifacts/6-1-koel-chat-controller.md] — sibling story; D1 lifecycle-ownership parity, Flutter test-harness routing, barrel-discipline pattern.
- FR-D5 (no service-locator client injection) — implementation-readiness-report-2026-05-28.md:120,255.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8)

### Debug Log References

- `koel_flutter` scope suite: 3 tests pass via `flutter test test/scope/koel_client_scope_test.dart` (AC2 resolve, AC3 swap-rebuild-exactly-once + same-instance-no-rebuild, AC4 no-ancestor FlutterError).
- All gates green from a clean repo-root CWD: `melos run analyze` (11 pkgs, **No issues found**), `melos run test` (**SUCCESS** — `koel_flutter +19` = 16 prior + 3 new scope; `koel_core +582`, `koel_http +97`, `koel_test +81`, all green), `melos run format:check` (171 files, **0 changed** after formatting the 2 new files).
- Pins held (AI-5.9 watch): `analyzer 12.1.0` / `freezed 3.2.6-dev.1` intact; `pubspec.lock` unchanged (no `pub get` churn — no new dependency).
- **Flaky-gate note (not a 6.2 regression):** two intermediate sweeps reported a single failure that *moved between packages* — first `koel_http` `cancellation owned default client really tears the socket down on cancel (AC1)`, then `koel_test`. Ruled out as 6.2-caused by adversarial check: (a) the koel_http test is a **real-`HttpServer`-socket** teardown test, passed in isolation and on every subsequent sweep — flaky under concurrent melos load (latent Epic-4 item); (b) the `koel_test` "failure" was a **my-invocation artifact** — `fixtures_test.dart` resolves fixtures via a *relative* path (`lib/src/fixtures/synthesized/`) against the test process CWD, and my shell had a stale `cd packages/koel_flutter`; from repo-root CWD koel_test is `+81` green. `git status` confirms koel_http/koel_test sources and `pubspec.lock` are untouched by this story.

### Completion Notes List

- **`KoelClientScope` is a minimal `InheritedWidget` skin** — `const` ctor + `final KoelClient client`, `static of` (subscribing lookup), `updateShouldNotify` (identity gate). Surface is **exactly A.6**: no `maybeOf`, no extra fields, no exposed dependency-mode variant (D3).
- **D2 implemented — `of` uses `dependOnInheritedWidgetOfExactType<KoelClientScope>()`** (the subscribing variant), so the calling element becomes a dependent and rebuilds on client swap. The AC3 test proves "exactly once" by rebuilding the **scope** (via a `_Swapper` `StatefulBuilder`-style host) with a new client and asserting the descendant's build-counter advances by exactly 1; re-publishing the **same** instance advances it by 0 (`updateShouldNotify == false`).
- **D4 implemented — no-ancestor throws `FlutterError.fromParts([ErrorSummary, ErrorHint, describeElement])`** in the `Scaffold.of`/`Material.of` idiom (a real throw, not a release-stripped `assert`). AC4 asserts `isA<FlutterError>()` and the message carries both `'KoelClientScope'` and the `'Wrap your app'` remediation. No `catch (_) {}` anywhere.
- **D1 honored — the scope never owns/disposes the client.** `InheritedWidget` is immutable with no teardown hook; the client is injected, so the caller disposes it. Tests `addTearDown(client.dispose)` for the clients they construct. Exact lifecycle parity with Story 6.1's controller D1.
- **`updateShouldNotify => client != old.client` is an identity compare** — verified `KoelClient` has no `==` override, so distinct instances differ and the same instance is equal. No equality shim added to client or scope.
- **Smallest possible footprint:** one new lib file + one barrel export line + one test file. No new dependency, no codegen, no test-harness change (the `flutter test` routing from 6.1 already covers `koel_flutter`).
- **Coverage:** all four members exercised — `of` (found + not-found branches), `updateShouldNotify` (true + false branches), the constructor, and the `client` field read — comfortably above the ≥90% foundation-tier bar. Coverage-gate wiring stays Story 6.8 scope.

### File List

- `packages/koel_flutter/lib/src/scope/koel_client_scope.dart` (new — `KoelClientScope extends InheritedWidget`)
- `packages/koel_flutter/lib/koel_flutter.dart` (modified — barrel exports the scope under a F-D5 banner)
- `packages/koel_flutter/test/scope/koel_client_scope_test.dart` (new — AC2/AC3/AC4 widget tests + `_Swapper` host)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (modified — tracking: 6-2 → in-progress → review)

## Change Log

- 2026-06-05 — Implemented Story 6.2 `KoelClientScope extends InheritedWidget` (FR-D5): subscribing `of()` lookup, identity-gated `updateShouldNotify`, remediating `FlutterError` on missing ancestor, barrel export, and AC2–AC4 widget tests (3 passing; `koel_flutter` suite 16→19). All gates green; A.6 surface exact (no `maybeOf`); no new dependency. Status → review.

## Review Findings

Code review 2026-06-05 (Blind Hunter + Edge Case Hunter + Acceptance Auditor): all 4 ACs and D1–D4 PASS, A.6 surface exact. 1 patch, 0 decision-needed, 0 defer, 3 dismissed.

- [x] [Review][Patch] Constructor dartdoc leads with an element-identity `const` benefit it then negates in the same sentence; tighten to the honest reason ("matches A.6, costs nothing") [packages/koel_flutter/lib/src/scope/koel_client_scope.dart:21] — fixed 2026-06-05

Dismissed (false positives, recorded for trace): (a) `updateShouldNotify` using `!=` vs `identical` — `client != old.client` is AC1-verbatim per A.6 and `KoelClient` has no `operator ==` (verified in source), so it *is* an identity compare; changing it would violate AC1. (b) `F-D5` (barrel banner / architecture tree) vs `FR-D5` (dartdoc / functional-requirement citation) — established two-namespace convention, mirrors Story 6.1's `F-D4`/`FR-D4` split. (c) `of()` called in `initState` throwing a framework assert — deliberate D2 design, matches Flutter `Theme.of` idiom, dartdoc directs callers to `didChangeDependencies`.
