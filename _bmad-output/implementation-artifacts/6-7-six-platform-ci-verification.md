---
baseline_commit: f73cb6f
---

# Story 6.7: Six-platform CI verification + smoke tests

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a release manager,
I want `koel_flutter` smoke tests running on all six Flutter platforms (iOS, Android, web, macOS, Windows, Linux) in CI verifying the integration flow,
so that platform-divergence regressions surface immediately per NFR-11.

## Context & scope (read first)

This is an **infrastructure + test + docs** story — the **first CI lane in the monorepo that runs `flutter test`**, and the seventh `koel_flutter` deliverable. It ships **three artifacts and no new `lib/src/` production code**:

1. **`integration_test/` smoke test** under `packages/koel_flutter/` — one widget-level integration test that wires `KoelClientScope(client: …)` + `KoelChatController` + a `MockAgent` over a minimal Flutter widget that renders `controller.state` message text, asserting the streamed assistant turn appears. (Built on `package:integration_test`.)
2. **Six-platform CI matrix** extending [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) — six jobs (iOS, Android, web, macOS, Windows, Linux) each running `flutter test integration_test/` for `koel_flutter`.
3. **README per-platform caveats** (NFR-11 "documented per-platform caveats") + folding the known stale-version fix.

**Three spec-reality gaps make this more than "copy the AC into YAML." Resolve them exactly as the locked decisions (D1–D8) say — do not re-derive from the epic AC alone:**

1. **`MockAgent.fromFixture` is `dart:io`-bound and CANNOT run on the web lane.** The epic AC ([epic-6:166](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L166)) literally names `MockAgent.fromFixture('text_only_run')` — but `fromFixture → FixtureLoader.loadSynthesized → _load` reads the bundled `.jsonl` via `dart:io` `File` + `dart:isolate` `Isolate.resolvePackageUri` + `file.readAsLines()` ([fixture_loader.dart:1-4, 134-149](../../packages/koel_test/lib/src/fixture_loader.dart#L134)). `dart:io` is **absent on the web platform** — the very platform the matrix exists to verify (NFR-11: "Web support uses SSE-over-XHR fallback if `dart:io` is unavailable — verified in CI" — [prd.md:311](../planning-artifacts/prds/prd-koel-2026-05-27/prd.md#L311)). A `fromFixture`-driven smoke test would compile-fail or runtime-fail the web lane. **→ D1: drive a programmatic `MockAgent`** emitting the same `RUN_STARTED → TEXT_MESSAGE_* → RUN_FINISHED` shape (web-safe pure-Dart async). Story 6.1 already made and flagged exactly this substitution ([6-1:141](6-1-koel-chat-controller.md): "Test agent: `MockAgent.programmatic()`, not `fromFixture` … `fromFixture` stays the Story 6.7 smoke-test path") — but 6.7's web lane is precisely where `fromFixture` is infeasible, so the programmatic agent carries forward. No AC depends on fixture provenance.

2. **The current CI installs Dart, not Flutter.** Every existing workflow uses `dart-lang/setup-dart@v1` with `sdk: 3.12.0` ([ci.yml:23-25](../../.github/workflows/ci.yml#L23), conformance/api-diff/perf-bench/codegen-drift/publish-dry-run all the same). `flutter test` needs the **Flutter SDK** on PATH. The six new jobs are the first to run it. **→ D2: install Flutter via `subosito/flutter-action@v2`** (channel `stable`, version pinned to the `.tool-versions` floor `flutter 3.44.0`), in **new** jobs — do NOT add `flutter test integration_test/` to the existing pure-Dart `analyze-test` job.

3. **`flutter test integration_test/` is a SEPARATE invocation from `melos run test`.** Bare `flutter test` runs `test/` only — it does **not** pick up `integration_test/`. So the per-PR fast unit sweep ([`tool/test_package.sh`](../../tool/test_package.sh), which routes `koel_flutter → flutter test` since 6.1) is **unchanged**: the smoke test does not slow every PR's unit run, and the new six jobs invoke `flutter test integration_test/` explicitly. **→ D4: no harness change.**

Read **Dev Notes → Design decisions (D1–D8, locked)** before writing any YAML or test code.

## Acceptance Criteria

1. **Six-platform CI matrix exists, each running the `koel_flutter` integration smoke test (AC source: [epic-6:159-162](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L159)).** [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) is extended with **six platform jobs** — iOS (macOS runner + Xcode/simulator), Android (Linux runner + Android SDK/emulator), web (Linux + headless Chrome), macOS, Windows, Linux. Each job installs Flutter via `subosito/flutter-action@v2` (D2), bootstraps the workspace, and runs `flutter test integration_test/` for `koel_flutter` on its platform. The existing pure-Dart `analyze-test` + `web` (koel_http) jobs are preserved unchanged.

2. **An `integration_test/` smoke test wires scope + controller + agent and observes the streamed turn (AC source: [epic-6:164-167](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L164)).** `packages/koel_flutter/integration_test/` contains at least one test (using `package:integration_test`, `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`) that: (a) builds `KoelClientScope(client: KoelClient(agent: <programmatic MockAgent>))` over a minimal Flutter widget consuming `controller.state.messages` (or the in-flight `pendingMessage`); (b) calls `controller.send(...)`, pumps, and asserts the accumulating assistant text (`"Hello world"`-shape) renders. The agent is a **programmatic `MockAgent`** (D1) — **not** `MockAgent.fromFixture` — so the same test compiles and passes on the **web** lane where `dart:io` is absent. The test passes on every platform lane (AC1).

3. **Per-platform caveats documented in the package README (AC source: [epic-6:169-171](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L169), NFR-11).** [`packages/koel_flutter/README.md`](../../packages/koel_flutter/README.md) documents the platform matrix and any per-platform smoke/integration caveats per NFR-11 ("documented per-platform caveats"). At minimum: the web lane runs without `dart:io` (so `MockAgent.fromFixture` is VM-only — programmatic agents only on web), and the mobile lanes require a booted simulator/emulator. The "Six-platform CI verification lands in a later Epic 6 …" placeholder ([README:65](../../packages/koel_flutter/README.md#L65)) is updated to reflect that it has landed. Fold the deferred stale-version fix: README "Requires Flutter **3.35.0**+" ([README:16](../../packages/koel_flutter/README.md#L16)) → **3.38.0+** to match `pubspec.yaml` `flutter: ">=3.38.0"` (deferred-work.md item — own it here, don't accumulate).

4. **Gates, dependency, and scope boundaries.** Add `integration_test: { sdk: flutter }` to `koel_flutter` `dev_dependencies` (D3) — the **only** pubspec change. `pubspec.lock` may gain `integration_test` + its transitive deps, but the **AI-5.9 pins** (`analyzer 12.1.0` / `freezed 3.2.6-dev.1`) must **not** drift — verify `git diff pubspec.lock` shows no analyzer/freezed version change. `melos run analyze` (11 pkgs clean), `melos run test` (full sweep SUCCESS — **unchanged**, integration_test not picked up by bare `flutter test` — D4), `melos run format:check` (0 changed) all green. **No new `lib/src/` production code** and **no public-surface change** (D8). The coverage gate, perf benches, dartdoc, and final barrel are **Story 6.8**; the full 10-package × 6-platform matrix is **Epic 9 / AR-17** — neither is wired here (D7).

## Tasks / Subtasks

> **Approach change (Si-approved 2026-06-05) — see Dev Agent Record → Completion Notes for the full source-evidence rationale.** AC2/D3/D5 named `integration_test` + `IntegrationTestWidgetsFlutterBinding` + a six-platform device matrix. Two verified facts overrode that: (1) `integration_test` never runs on `flutter_tester` and needs platform folders this library package lacks (so even desktop fails without `flutter create`); (2) a no-channel render smoke proves NFR-11's native-vs-web/`dart:io` divergence more simply via plain `flutter_test` + `flutter test --platform chrome`. koel_test's `MockAgent` is also unusable on web (transitively imports `dart:io`). **Decisions:** plain `flutter_test` widget test in `test/smoke/` with a local web-safe agent; **four** real lanes (macOS/Linux/Windows host + web Chrome); iOS/Android device lanes deferred to the Epic 9 / AR-17 device matrix. Subtask checkboxes below reflect the *as-shipped* work.

- [x] **Task 1 — `koel_flutter`: render smoke test (AC: 2)**
  - [x] ~~Add `integration_test` dev-dep~~ → **superseded**: no pubspec change. Plain `flutter_test` (already a dev-dep) drives the smoke; `integration_test` was added then reverted (lock back to 0 drift). AI-5.9 pins (analyzer 12.1.0 / freezed 3.2.6-dev.1) unmoved.
  - [x] Create `packages/koel_flutter/test/smoke/six_platform_smoke_test.dart` (not `integration_test/`). Imports `package:flutter/material.dart`, `package:flutter_test/flutter_test.dart`, `package:koel_core/koel_core.dart`, `package:koel_flutter/koel_flutter.dart` — **web-safe set only** (no `integration_test`, no `koel_test`).
  - [x] Define a **local web-safe `AbstractAgent`** (`_HelloAgent`) emitting `RUN_STARTED → TextMessageStart → TextMessageContent×2 ("Hello"/" world") → TextMessageEnd → RUN_FINISHED`, mirroring `streamingHelloAgent()`. **Not** `MockAgent` — koel_test's `mock_agent.dart` transitively imports `dart:io` (via `fixture_loader.dart`), which alone fails the dart2js web compile (a stronger constraint than D1's runtime `fromFixture` concern).
  - [x] Widget wires `KoelClientScope(client: KoelClient(agent: const _HelloAgent()), child: MaterialApp(home: AnimatedBuilder(...)))`; test owns the controller, `addTearDown` disposes controller-first then client; renders the `assistantText(state)` projection. Modeled on `state_management_test.dart`'s `driveHello`.
  - [x] `testWidgets('smoke: scope + controller + agent renders streamed turn', …)`: `isStreaming` false → `unawaited(send)` → `isStreaming` true → `pumpAndSettle()` → `find.textContaining('Hello world')` findsOne + `isStreaming` false. `MaterialApp` + explicit `TextDirection.ltr`.
  - [x] Verified green locally **on both** `flutter test test/smoke/...` (host flutter_tester) **and** `flutter test --platform chrome test/smoke/...` (dart2js + headless Chrome — the `dart:io`-free proof). Both: "All tests passed!".

- [x] **Task 2 — CI: Flutter setup + platform matrix (AC: 1)**
  - [x] Extended [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml) with a `flutter-smoke` job, `strategy.matrix.include`, `fail-fast: false`. Runners: **Linux**/**web** → `ubuntu-latest`; **macOS** → `macos-latest`; **Windows** → `windows-latest`. Existing `analyze-test` + koel_http `web` jobs untouched. YAML validated.
  - [x] Each job: `actions/checkout@v4` → `subosito/flutter-action@v2` (`channel: stable`, `flutter-version: 3.44.0`, `cache: true`; bundles a compatible Dart, so no separate setup-dart) → `dart pub global activate melos 7.8.0` → `melos bootstrap` → `melos run build` (gitignored `*.freezed.dart`; koel_core transitive dep) → `${{ matrix.test }}` in `packages/koel_flutter`.
  - [x] **Per-platform execution mode (corrects D5 — `integration_test`/flutter_tester premise was false):**
    - **Linux / macOS / Windows (desktop):** `flutter test test/smoke` on the host flutter_tester — build + render on each OS toolchain.
    - **web:** `flutter test --platform chrome test/smoke` — dart2js + headless Chrome (preinstalled on ubuntu-latest), the NFR-11 `dart:io`-free proof. **Verified green locally.**
    - **iOS / Android:** ~~simulator/emulator lanes~~ → **deferred to Epic 9 / AR-17** (Si-approved). No-channel smoke shares the desktop Dart frontend ⇒ ~0 marginal coverage; mobile needs an example app or device infra. Recorded in `deferred-work.md`.
  - [x] Pinned all third-party actions (`subosito/flutter-action@v2`). Added a header comment block explaining the lanes (mirrors the ci.yml header convention).
  - [x] Smoke kept minimal (local agent, no plugins/network) so lanes exercise **compile + render + Dart-platform divergence** (NFR-11). iOS/Android deferral documented in `deferred-work.md` rather than silently dropped.

- [x] **Task 3 — README per-platform caveats + stale-version fix (AC: 3)**
  - [x] Added a "## Platform support" section to [`packages/koel_flutter/README.md`](../../packages/koel_flutter/README.md) with a six-platform table: macOS/Linux/Windows (`flutter test`), web (`--platform chrome`, no `dart:io` ⇒ programmatic agents only — `fromFixture` is VM/native-only), iOS/Android (Epic 9 device matrix + no-channel rationale).
  - [x] Updated the "Six-platform CI verification lands in a later Epic 6 …" placeholder to point at the landed `ci.yml` `flutter-smoke` matrix.
  - [x] Fixed the stale floor: "Requires Flutter **3.35.0**+ (the release that ships Dart 3.9.0)" → "**3.38.0+** (the release that ships Dart **3.11.0**)" to match `pubspec.yaml` `flutter: ">=3.38.0"`.

- [x] **Task 4 — Gates + scope verification (AC: 4)**
  - [x] From clean repo-root CWD: `melos run format:check` (187 files, **0 changed**), `melos run analyze` (**11 pkgs clean**), `melos run test` (**full sweep SUCCESS**). koel_flutter 73→**74** (+1): the smoke now also runs in the per-PR sweep (a bonus — D4's "unchanged count" premise was tied to the abandoned `integration_test/` separation; the CI-only extra is the web `--platform chrome` pass).
  - [x] `git diff pubspec.lock`: **0 drift** (no pubspec change at all in the final shape; AI-5.9 analyzer/freezed pins held).
  - [x] Confirmed **no** `lib/src/` change and **no** barrel change (no public surface, D8). `koel_core`/`koel_test`/`koel_lints` untouched (D7).
  - [x] Confirmed `tool/test_package.sh` **not** modified (D4).

## Dev Notes

### Design decisions (locked — implement as stated)

- **D1 — Programmatic `MockAgent`, NOT `MockAgent.fromFixture` (web-safety is non-negotiable).** The epic AC names `MockAgent.fromFixture('text_only_run')` ([epic-6:166](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L166)), but `fromFixture` ([mock_agent.dart:52-55](../../packages/koel_test/lib/src/mock_agent.dart#L52)) delegates to `FixtureLoader.loadSynthesized → _load`, which uses `dart:io` (`File`, `file.readAsLines()`) and `dart:isolate` (`Isolate.resolvePackageUri`) ([fixture_loader.dart:1-4, 134-149](../../packages/koel_test/lib/src/fixture_loader.dart#L134)). **`dart:io` does not exist on the web platform** — the web lane (AC1) would fail to compile/run. The smoke test must pass on *every* lane (AC2: "passes on every platform"; NFR-11: web "verified in CI"). So the agent must be a **programmatic** `MockAgent` (pure-Dart async, web-safe), emitting the same `text_only_run`-shaped sequence (`RUN_STARTED → TEXT_MESSAGE_* → RUN_FINISHED`). The blessed pattern is already in the package: [`streamingHelloAgent()`](../../packages/koel_flutter/test/support/test_agent.dart) (two `"Hello"`/`" world"` deltas, proves accumulation). Reproduce it locally in `integration_test/`. **No AC depends on fixture provenance** — the AC's intent is "scope + controller + agent → observe accumulating text," which a programmatic agent satisfies identically (and more strongly than a single-delta fixture). This is the *same* substitution + reasoning Story 6.1 used and recorded ([6-1:141](6-1-koel-chat-controller.md)); 6.1 deferred the literal `fromFixture` to "the 6.7 smoke-test path," but the **web lane makes `fromFixture` infeasible** — parity-with-6.1 + the `dart:io` source-evidence decide. (This is the same "the AC names an illustrative API; the faithful, source-true choice wins" call as 6.5/D2 and 6.6/D1.)

- **D2 — Flutter SDK via `subosito/flutter-action@v2`; new jobs, pinned to 3.44.0.** No existing workflow installs Flutter — all use `dart-lang/setup-dart@v1 sdk: 3.12.0` ([ci.yml:23-25](../../.github/workflows/ci.yml#L23)). `flutter test` needs the Flutter SDK, so the six new jobs install it with `subosito/flutter-action@v2` (the canonical Flutter CI action), `channel: stable`, `flutter-version: 3.44.0` to match the repo toolchain pin ([`.tool-versions`](../../.tool-versions)). Do **not** bolt `flutter test` onto the pure-Dart `analyze-test` job (it is pinned to a standalone Dart SDK and runs `melos run test`/`analyze`/`format:check` across 11 pkgs — mixing in Flutter would be a needless re-architecture and could shadow the Dart pin). The AC says "`ci.yml` (extended here)," so add the matrix to `ci.yml` as a new job. **Workspace resolution note:** `koel_flutter` is a pub-workspace member (root `pubspec.yaml` `workspace:` list); `flutter pub get` inside the package may need the workspace root resolved first. Either run `melos bootstrap` (after `dart pub global activate melos 7.8.0`) as the other lanes do, or `flutter pub get` from the package with the workspace already materialized by checkout. Use `melos bootstrap` for parity with the existing lanes unless it conflicts with the Flutter SDK's bundled Dart — **verify which works** (the flutter-action's bundled Dart 3.x must satisfy the workspace `sdk: ">=3.11.0 <4.0.0"` constraint; 3.44.0 ships a compatible Dart).

- **D3 — `integration_test` SDK dev-dependency is the one pubspec change.** `package:integration_test` (Flutter SDK package) supplies `IntegrationTestWidgetsFlutterBinding`. Add `integration_test: { sdk: flutter }` under `dev_dependencies` in [`packages/koel_flutter/pubspec.yaml`](../../packages/koel_flutter/pubspec.yaml) (beside `flutter_test: { sdk: flutter }`). It is SDK-sourced (no pub.dev version), so it does not introduce a versioned pub dependency, but `pubspec.lock` will record it + transitive deps (`vm_service`, etc.). **AI-5.9 watch:** confirm the analyzer/freezed pins (`analyzer 12.1.0` / `freezed 3.2.6-dev.1`) do **not** move in the lock (D3/AC4) — `integration_test` should not force a solve that bumps them; if it does, that is a finding to surface, not silently accept.

- **D4 — `flutter test integration_test/` is a separate lane; `melos run test` and `tool/test_package.sh` are unchanged.** Bare `flutter test` runs `test/` only — it will **not** auto-discover `integration_test/`. So: (a) the per-PR fast unit sweep (`melos run test` → [`tool/test_package.sh`](../../tool/test_package.sh) → `flutter test` for koel_flutter) stays exactly as 6.1 left it — the smoke test does not slow every PR, and koel_flutter's unit count is unchanged; (b) the six new jobs invoke `flutter test integration_test/` explicitly. **No harness change** — do not touch `test_package.sh`. (The latent `grep "sdk: flutter"` coarseness + 65/79 no-tests gap flagged in [deferred-work.md:18](deferred-work.md) is out of scope — no second Flutter package lands here.)

- **D5 — Per-platform execution mode.** The AC's explicit "macOS runner + **Xcode**" (iOS) and "Linux + **Android SDK**" (Android) signal real simulator/emulator builds, not flutter_tester. Desktop lanes (Linux/macOS/Windows) run `flutter test integration_test/` under the host flutter_tester (build + render smoke, no device). The **web** lane runs in a real headless Chrome (`-d chrome`/chromedriver) — the high-value `dart:io`-divergence proof (D1). **iOS**: boot a simulator + `-d <sim>`. **Android**: `reactivecircus/android-emulator-runner@v2`. The smoke test uses **no platform plugins** (no `flutter_secure_storage`, no `hive`, no `koel_http`) — so the lanes exercise compile + render + Dart-platform divergence, which is NFR-11's intent for a *smoke* test (deeper plugin-channel divergence for storage is implicitly covered by 6.3/6.4's own tests and is not this story's job). Pin every third-party action. Verify exact `flutter test integration_test` invocations for web/iOS/Android against current Flutter 3.44 docs before finalizing (these APIs move between releases).

- **D6 — README is an AC here (unlike 6.1/6.2/6.5/6.6).** NFR-11 mandates "documented per-platform caveats," and the epic AC3 ([epic-6:169-171](../planning-artifacts/epics/epic-6-flutter-glue-persistence-koelflutter.md#L169)) names the README explicitly — so this story *does* edit the README (contrast 6.6, where README was optional). Extend the existing platform table (6.4 added one for secure storage — [README:56-65](../../packages/koel_flutter/README.md#L56)) with smoke/integration platform notes, update the "lands in a later Epic 6" placeholder, and fold the stale `3.35.0`→`3.38.0` fix ([deferred-work.md](deferred-work.md), README:16). Owning the stale-version debt now (rather than deferring again) follows the "fix a red/stale gate, don't accumulate" house rule.

- **D7 — Scope boundaries (what 6.7 does NOT touch).** No `melos run test:coverage` gate wiring (Story 6.8 — `tool/coverage.sh` needs `flutter test --coverage` for koel_flutter). No perf benches (`chat_session_memory_bench.dart` / `streaming_jank_bench.dart` — 6.8). No dartdoc/barrel finalization or `dart_apitool` baseline (6.8 / Epic 9). No full 10-package × 6-platform matrix — this is **koel_flutter's lane only**; the complete matrix is Epic 9 / AR-17 ([deferred-work.md:152](deferred-work.md)). No new `lib/src/` code, no new public symbol (D8).

- **D8 — No production-surface change.** This story adds CI YAML, one `integration_test/` file, one pubspec dev-dep line, and README prose. `lib/` and the barrel `lib/koel_flutter.dart` are untouched; the public API is identical. `koel_core`, `koel_test`, `koel_lints` unchanged. AI-5.9 pins held.

### `integration_test` vs `flutter_test` (why a new dir + dep)

`package:integration_test` wraps `flutter_test` with `IntegrationTestWidgetsFlutterBinding` — the binding that lets the same `testWidgets` body run **on a device/browser** (not just the host flutter_tester), reporting results back to `flutter test`/`flutter drive`. The widget API (`tester.pumpWidget`, `find`, `pumpAndSettle`) is identical to the unit widget tests already in [`test/`](../../packages/koel_flutter/test/) — so the smoke test reads like [`state_management_test.dart`](../../packages/koel_flutter/test/integration/state_management_test.dart) but lives in `integration_test/` and calls `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` first. That binding is what makes the iOS/Android/web device lanes meaningful. (Note: `test/integration/` already exists for the 6.1 *framework*-integration widget tests — those stay in `test/` and run in the fast sweep; `integration_test/` is the new, device-targeted dir. Don't conflate them.)

### The smoke-test contract (model on existing code)

- **Agent (D1):** local programmatic builder = `MockAgent.programmatic().runStarted().event(TextMessageStartEvent(messageId:'m1', role:'assistant')).event(TextMessageContentEvent(messageId:'m1', delta:'Hello')).event(TextMessageContentEvent(messageId:'m1', delta:' world')).event(TextMessageEndEvent(messageId:'m1')).runFinished().build()` — verbatim shape of [`streamingHelloAgent()`](../../packages/koel_flutter/test/support/test_agent.dart).
- **Wiring:** `KoelClient(agent: agent)` → `client.newSession()` → `KoelChatController(session: …)`; publish via `KoelClientScope(client: client, child: MaterialApp(...))`; render `assistantText(controller.state)` (pending-or-last-assistant projection — [test_agent.dart](../../packages/koel_flutter/test/support/test_agent.dart)) inside an `AnimatedBuilder(animation: controller, …)`.
- **Assertion (mirror `driveHello`):** idle → `send` flips `isStreaming` true synchronously → `pumpAndSettle` → `find.textContaining('Hello world')` findsOne + `isStreaming` false. Tear down controller-first, then client.

### Project Structure Notes

- **New:** `packages/koel_flutter/integration_test/smoke_test.dart` (new dir, sibling of `test/`). `.github/workflows/ci.yml` gains a `flutter-smoke` matrix job.
- **Modified:** `packages/koel_flutter/pubspec.yaml` (+`integration_test` dev-dep, D3), `pubspec.lock` (integration_test + transitive only, no analyzer/freezed drift), `packages/koel_flutter/README.md` (platform caveats + stale-version fix, D6).
- **Unchanged:** all `lib/` (no surface change, D8), `lib/koel_flutter.dart` barrel, `tool/test_package.sh` (D4), `koel_core`/`koel_test`/`koel_lints`. Seventh `koel_flutter` deliverable; **first `flutter test` CI lane**; no new pub.dev dependency (the dev-dep is SDK-sourced).

### Carry-ins from prior stories / Epic-5 retro

- **AI-5.9 (analyzer 12.1.0 / freezed 3.2.6-dev.1 pin watch)** — `integration_test` is SDK-sourced; confirm it does not perturb the analyzer/freezed pins in `pubspec.lock` (D3). Do not bump.
- **Flutter-test routing (6.1)** — `tool/test_package.sh` routes koel_flutter → `flutter test`; unchanged (D4). The new lane is `flutter test integration_test/`, invoked directly in CI, not via the harness.
- **CI patterns (1.5 / 4.10)** — `ci.yml`'s `strategy.matrix.os` is the extension point ([ci.yml:16-20](../../.github/workflows/ci.yml#L16)); 4.10 already grew it to Linux+macOS + a headless-Chrome `web` job (the precedent for a platform-specific extra job). Existing workflows build generated code first (`melos run build`) because `*.freezed.dart` is gitignored — the Flutter lane needs the same before `flutter test` (koel_core is a transitive dep). Header-comment convention: [ci.yml:1-6](../../.github/workflows/ci.yml#L1).
- **CI flake realism** — wall-clock assertions and preinstalled-Chrome reliance are known flake surfaces ([deferred-work.md:66,68](deferred-work.md)); the device/web lanes here are new flake surfaces. Keep the smoke minimal; pin actions; document any lane-mitigation in deferred-work.md rather than weakening the gate silently (own-the-gate house rule).
- **House patterns (CLAUDE.md):** no vestigial CI steps ("just in case" matrix entries); the smoke test is a *pure* render-time check (no plugins) so the lanes stay deterministic; "design for what users can't misuse" → the web-safe agent (D1) means the smoke can't accidentally depend on `dart:io`.

### Web research to do before finalizing CI YAML

The exact `flutter test integration_test` invocation for **web** (chromedriver/`-d chrome` vs `-d web-server` vs `flutter drive`) and the canonical **Android emulator** (`reactivecircus/android-emulator-runner@v2`) + **iOS simulator** boot steps move between Flutter releases. Verify against current (Flutter 3.44, mid-2026) docs / the `subosito/flutter-action` + `reactivecircus/android-emulator-runner` READMEs before locking the YAML — these are the flake-prone parts. The web lane is the one that *must* be green (it proves D1); if it cannot be, D1's premise is wrong and the story needs revisiting.

### References

- [Source: epics/epic-6-flutter-glue-persistence-koelflutter.md#Story-6.7] (lines 151-171) — user story + 3 BDD ACs (six-platform matrix, `integration_test/` smoke, README caveats).
- [Source: prds/prd-koel-2026-05-27/prd.md] (N-11:311) — six-platform support, "Web support uses SSE-over-XHR fallback if `dart:io` is unavailable — **verified in CI**" (the D1 web-safety mandate).
- [Source: packages/koel_test/lib/src/fixture_loader.dart] (lines 1-4 imports, 134-149 `_load`) — `dart:io` `File` + `dart:isolate` `Isolate.resolvePackageUri`: proof `fromFixture` is VM-only, web-unsafe (D1).
- [Source: packages/koel_test/lib/src/mock_agent.dart] (lines 24-79) — `MockAgent.fromFixture` (→ `loadSynthesized`, D1) vs `MockAgent.programmatic()` builder (the web-safe path).
- [Source: packages/koel_flutter/test/support/test_agent.dart] — `streamingHelloAgent()` + `assistantText()`: the exact programmatic agent + projection to reproduce in `integration_test/` (D1).
- [Source: packages/koel_flutter/test/integration/state_management_test.dart] — `driveHello` + scope/controller wiring idiom to mirror for the smoke test (AC2). NB: this lives in `test/` (fast sweep); `integration_test/` is the new device-targeted dir (D4).
- [Source: .github/workflows/ci.yml] (lines 1-6 header, 16-20 matrix, 23-25 setup-dart, 28-31 build-first) — the workflow to extend; `setup-dart` (not Flutter) is why D2 adds `subosito/flutter-action`.
- [Source: .github/workflows/conformance.yml] — second `melos bootstrap` + `melos run build` precedent.
- [Source: .tool-versions] — `flutter 3.44.0` / `dart 3.12.0` pins (D2 flutter-action version).
- [Source: packages/koel_flutter/pubspec.yaml] — `flutter_test: { sdk: flutter }` (add `integration_test` beside it, D3); `flutter: ">=3.38.0"` (README stale-fix target, D6); workspace member (D2 resolution note).
- [Source: packages/koel_flutter/README.md] (16 stale floor, 56-65 platform table + "later Epic 6" placeholder) — AC3 edits (D6).
- [Source: _bmad-output/implementation-artifacts/6-1-koel-chat-controller.md] (line 141) — the programmatic-not-`fromFixture` substitution precedent (D1); test-harness Flutter routing (D4).
- [Source: _bmad-output/implementation-artifacts/deferred-work.md] (9 stale README floor, 18 test_package.sh grep, 66/68 CI flake, 152 full-matrix=Epic-9) — folded fix (D6) + scope boundaries (D7) + flake realism.
- [Source: architecture.md] (10 CI-matrix 10×6, 689 example smoke tests, 728/996 ci.yml, 893-915 koel_flutter source tree) — CI-matrix intent + koel_flutter layout.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8, 1M context) — via `/bmad-dev-story` + `agent-flutter-engineer`.

### Debug Log References

- `flutter test test/smoke/six_platform_smoke_test.dart` → `00:00 +1: All tests passed!` (host flutter_tester).
- `flutter test --platform chrome test/smoke/six_platform_smoke_test.dart` → `00:00 +1: All tests passed!` (dart2js + headless Chrome — the `dart:io`-free proof).
- `melos run format:check` → 187 files, 0 changed. `melos run analyze` → 11 pkgs, "No issues found!". `melos run test` → SUCCESS (koel_flutter 74).
- `git diff pubspec.lock` → empty (0 drift; AI-5.9 pins held).

### Completion Notes List

**Approach deviation from AC2/D3/D5 — source-evidence + two Si-approved decisions (2026-06-05).**

The story locked `integration_test` + `IntegrationTestWidgetsFlutterBinding` + a six-platform *device* matrix (AC2, D3, D5). Implementing against Flutter 3.44 + the actual package shape surfaced three verified facts that overrode the locked mechanism (mandated web research + local repro done before finalizing, per the story's own "verify against current docs" gate):

1. **`integration_test` never runs on `flutter_tester`.** It builds a *real app* on a *real target*; `koel_flutter` is a **library package with no platform folders**, so `flutter test integration_test/` errors "No supported devices / not supported by this project" on *every* lane, desktop included — directly contradicting D5's "desktop runs on flutter_tester, no device" premise. Making it green needs per-lane `flutter create` (platform scaffolding) + device infra.
2. **A plain `flutter_test` smoke is the simpler, faithful NFR-11 proof.** The smoke uses no plugins/channels and no `dart:io`; the divergence axis NFR-11 actually targets ("Web support … if `dart:io` is unavailable — verified in CI") is *native vs web*. `flutter test` (host) + `flutter test --platform chrome` (dart2js + headless Chrome) prove compile + render + that axis with no device infra, no `flutter create`, and full local verifiability. Same "the AC names an illustrative mechanism; the source-true choice wins" call as 6.1/D1, 6.5/D2, 6.6/D1.
3. **koel_test's `MockAgent` is web-incompatible.** `mock_agent.dart` `import`s `fixture_loader.dart`, which `import 'dart:io'` — that transitive import alone fails the dart2js web compile, regardless of runtime path. (D1 correctly flagged `fromFixture`'s *runtime* `dart:io`, but the *import-time* coupling is stricter and rules out `MockAgent` entirely on web.) ⇒ the smoke defines a **local web-safe `AbstractAgent`** (`_HelloAgent`) over koel_core's public event types (koel_core + koel_flutter are both `dart:io`-free; the `dart:io` grep hit in `error_classifier.dart` is doc-comment text, not an import).

**Decision 1 (Si):** plain `flutter_test` widget test over the `integration_test` device matrix.
**Decision 2 (Si):** ship **4 real lanes** (macOS/Linux/Windows host + web Chrome) now; **defer iOS/Android** device/build verification to the Epic 9 / AR-17 full 10×6 matrix — a no-channel render smoke shares the desktop Dart frontend (≈0 marginal mobile coverage), and the only mobile-distinct surface (plugin channels for storage) is already covered by 6.3/6.4. Both deviations recorded in `deferred-work.md`.

**Scope held:** no `lib/src/` or barrel change (D8); no public surface; `koel_core`/`koel_test`/`koel_lints` untouched (D7); `tool/test_package.sh` unmodified (D4); **no pubspec change at all** in the final shape (cleaner than AC4's "one dev-dep"); `pubspec.lock` 0 drift; AI-5.9 analyzer/freezed pins held. All gates green.

### File List

- **Added:** `packages/koel_flutter/test/smoke/six_platform_smoke_test.dart`
- **Modified:** `.github/workflows/ci.yml` (new `flutter-smoke` matrix job + header note)
- **Modified:** `packages/koel_flutter/README.md` (Platform support section; placeholder update; stale Flutter 3.35.0→3.38.0 / Dart 3.9.0→3.11.0 fix)
- **Modified:** `_bmad-output/implementation-artifacts/deferred-work.md` (iOS/Android device-lane deferral + `integration_test`→`flutter_test` deviation entries)
- **Modified:** `_bmad-output/implementation-artifacts/sprint-status.yaml` (6-7 → in-progress → review)

### Review Findings

**Code review 2026-06-06 (3-layer adversarial: Blind Hunter + Edge Case Hunter + Acceptance Auditor) — CLEAN.** 0 decision-needed, 0 patch, 0 new defer, 11 dismissed. All four ACs Met / Met-with-Si-approved-deviation; D7/D8 scope held; AI-5.9 pins held; gates re-verified green (format:check 0-changed, analyze 11 pkgs clean, test SUCCESS koel_flutter 74).

Contested findings were resolved by empirical verification (not assertion):

- [x] [Review][Dismiss] **Web lane: barrel transitive `dart:io` (`hive_ce`/`flutter_secure_storage`) fails dart2js compile** [test/smoke/six_platform_smoke_test.dart] — *empirically disproven*: ran `flutter test --platform chrome test/smoke` locally → `All tests passed!` with the full `koel_flutter.dart` barrel (which DOES export both storage adapters). Both deps are web-safe. The reviewer's grep-only premise (first-party lib checked, transitive graph not) is moot — the real compile is green.
- [x] [Review][Dismiss] **`flutter-version: 3.44.0` may not exist on stable channel** [.github/workflows/ci.yml] — confirmed real: local `flutter --version` = 3.44.0 • stable, matching `.tool-versions`.
- [x] [Review][Dismiss] **`expect(isStreaming, isTrue)` after un-awaited `send()` assumes synchronous flip — brittle** [six_platform_smoke_test.dart] — `ChatSession.send` emits `RunPhase.running` synchronously before its first await (Edge Hunter verified against source); test passes green on host + Chrome; mirrors the established `driveHello` idiom.
- [x] [Review][Dismiss] **CI comment "pinned to .tool-versions" but value is hardcoded** [ci.yml] — value (3.44.0) matches `.tool-versions` exactly; whole repo hardcodes pins (melos 7.8.0, dart 3.12.0) + comments the source — consistent house style, comment accurate as intent.
- [x] [Review][Dismiss] **README "Requires Flutter 3.38.0+" contradicts CI pin 3.44.0** [README.md:16] — min-supported ≠ CI-tested; README matches `pubspec.yaml` `flutter: ">=3.38.0"` / `sdk: ">=3.11.0"` exactly. No contradiction.
- [x] [Review][Dismiss] **`unawaited(send)` drops async error / `pumpAndSettle` could hang / Windows native-build-tools gap / two ubuntu lanes share cache key** — host flutter_tester runs no native build, in-memory agent settles instantly, cache restore is read-shared, pattern mirrors `driveHello`; all four lanes pass.
- [x] [Review][Dismiss] **README "targets all six Flutter platforms" overstates 4 CI lanes** [README.md] — the table immediately below discloses iOS/Android = Epic 9 device matrix; "targets" is a capability statement, "proves on every PR" scopes to the web/`dart:io` axis (accurate).

**Accepted deviation (Si-approved 2026-06-05, already in `deferred-work.md` — not a new finding):** AC1's six-platform matrix ships 4 real lanes (macOS/Linux/Windows host + web Chrome); iOS/Android device lanes deferred to Epic 9 / AR-17. Acceptance Auditor independently judged the rationale sound — for a no-plugin render smoke, iOS/Android share the desktop Dart frontend (≈0 marginal coverage), and NFR-11's literal "verified in CI" target (the web/`dart:io` divergence) IS covered.

## Change Log

- 2026-06-05 — Story 6.7 implemented. Added `koel_flutter` render smoke (`test/smoke/six_platform_smoke_test.dart`, local web-safe agent) + `ci.yml` `flutter-smoke` 4-lane matrix (macOS/Linux/Windows host + web `--platform chrome`) + README Platform-support section and stale-version fix. **Approach deviation (Si-approved):** plain `flutter_test` over `integration_test` device matrix (AC2/D3/D5 mechanism overridden by source-evidence — library package has no platform folders, `integration_test` can't run on flutter_tester, `MockAgent` transitively imports `dart:io`); iOS/Android device lanes deferred to Epic 9/AR-17. Gates green: format:check 0-changed, analyze 11 pkgs clean, test full sweep SUCCESS (koel_flutter 73→74); pubspec.lock 0 drift, AI-5.9 pins held.
