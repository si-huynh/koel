---
baseline_commit: 922fd7f9af1bd0b26cad336d682f92718bd5808f
---

# Story 9.2: Repo-root sample app via `koel` meta-package

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter developer,
I want a repo-root `example/` Flutter app consuming the `koel` meta-package and demonstrating the quickstart end-to-end (generic chat, zero business domain) across all six platforms,
so that pub.dev visitors see a real working entrypoint per FR-H3 + AR-22 + PRD §13 D-5.

## Context — second story of Epic 9 (the pub.dev showcase)

Story 9.1 finalized the `koel` 3-export meta-barrel (`koel_core` + `koel_http` + `koel_flutter`) and the ten-package `1.0.0` hybrid-versioning convention. **9.2 builds the repo-root `example/` app that consumes that barrel** — the first real, six-platform consumer of the whole stack and the page pub.dev visitors land on.

This story also lands **Epic-7 retro AI-7.1** (folded into AC4, SCP-2026-06-06-B): the `MessageBubble` max-width cap + long-code no-clip that was deferred from Story 7.2 and never closed at the 7.4 SEALER. The sample app is its first real consumer, where edge-to-edge prose looks unfinished on a wide pub.dev/desktop window, and goldens make the cap testable.

**Scope frame:** this is the heavy-CI-boundary story of Epic 9 (the retro forecast it). The new surface is (a) a runnable six-platform Flutter app + (b) a `flutter build`-per-platform CI matrix + (c) a small internal koel_widgets layout change with two new Linux goldens. It ships **no new public symbol** in any package.

## Acceptance Criteria

**AC1 — Repo-root `example/` app structure consuming the meta-package.**
**Given** repo-root `example/`, **when** I inspect the structure, **then** it is a Flutter app whose `pubspec.yaml` depends on the `koel` meta-package (path/workspace dependency during dev, package dependency post-publish), **and** `lib/main.dart` shows a `MaterialApp` with a single chat screen using `KoelChatController` + `KoelClientScope` + `MessageBubble` + `ChatInput`, **and** the app uses `MockAgent` from `koel_test` (a `dev_dependency`) for the offline demo (see **D2** for the `programmatic` vs `fromFixture` decision), **and** `example/README.md` describes how to swap `MockAgent` for `AgnoAgent`/`LangGraphAgent`/`CopilotRuntimeAgent`.

**AC2 — Six-platform `flutter build` CI matrix.**
**Given** `.github/workflows/ci.yml`, **when** I extend the matrix, **then** a job runs `flutter build` against the example app and asserts the build succeeds, covering iOS, Android, web, macOS, Windows, Linux per NFR-11 + AR-22 (each target built on the runner OS that supports it; non-codesigned/debug builds where signing is unavailable — see **D7**).

**AC3 — Human-demoable, business-domain-free, polished bubbles.**
**Given** the sample app demoed by a human following `example/README.md`, **when** it runs, **then** the chat surface renders **and** the mock conversation streams visibly, **and** zero business-domain content appears (generic chat only, per AR-22 + PRD §13 D-5), **and** `MessageBubble` renders polished across all six platforms — long prose is **width-capped** (no edge-to-edge stretch; the role `Align` stays meaningful) **and** a long unbreakable code token does **not** clip (per **Epic-7 retro AI-7.1** — the `ConstrainedBox(maxWidth)` + long-code horizontal handling deferred from Story 7.2 lands here).

## Tasks / Subtasks

> Run all Flutter/Dart work under the `/agent-flutter-engineer` persona (CLAUDE.md mandate).

- [x] **Task 1 — Land AI-7.1 in `koel_widgets`: bubble max-width cap + long-code no-clip** (AC3, D5)
  - [x] In [packages/koel_widgets/lib/src/bubble/message_bubble.dart](packages/koel_widgets/lib/src/bubble/message_bubble.dart): cap the bubble surface width. Add a **private** top-level const (e.g. `const double _maxBubbleWidth = 560;`) and pass it into both variant chromes (see next subtask). **Do NOT add a public `KoelSpacing`/`KoelTheme` token** — keep it internal (D5): the 8-symbol barrel + the committed `.api-baseline/koel_widgets.json` must stay frozen (the `dart_apitool` gate is Story 9.3; 9.2 must not churn the public surface).
  - [x] In [packages/koel_widgets/lib/src/bubble/material_bubble.dart](packages/koel_widgets/lib/src/bubble/material_bubble.dart) and [packages/koel_widgets/lib/src/bubble/cupertino_bubble.dart](packages/koel_widgets/lib/src/bubble/cupertino_bubble.dart): add a `required final double maxWidth;` ctor field (these widgets are **internal**, not barrel-exported — no public API change) and wrap the `Material`/`DecoratedBox` in `ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: …)`, still **inside** the existing `Align`. On a phone (screen < cap) the cap is a no-op and the bubble fills width; on wide desktop/web it caps so the role `Align` (left/right) stays meaningful. Update each widget's dartdoc to mention the cap.
  - [x] In `_codeBlock` (message_bubble.dart:117): wrap the code `Text` in a horizontal `SingleChildScrollView(scrollDirection: Axis.horizontal, child: Text(...))` so a long unbreakable token scrolls instead of clipping (`Text` default `overflow: clip`). Keep the existing `DecoratedBox` background + padding around it.
  - [x] **Behavioral test** in [packages/koel_widgets/test/message_bubble_test.dart](packages/koel_widgets/test/message_bubble_test.dart) (or `test/bubble/`): on a wide surface (e.g. 1200px), a long-prose bubble's painted width is ≤ `_maxBubbleWidth` (assert via the rendered `Material`/`DecoratedBox` size or a `find`-scoped `tester.getSize`), and a long-code message renders without a `RenderFlex`/clip overflow exception (`tester.takeException()` is null). Mirror the existing test file's host/pump pattern.
  - [x] **Goldens** (Linux-canonical, `@Tags(['golden'])`): add to [packages/koel_widgets/test/goldens/message_bubble_golden_test.dart](packages/koel_widgets/test/goldens/message_bubble_golden_test.dart) one **wide-prose capped** golden and one **long-code** golden (pick a wide `physicalSize`, e.g. 1000–1200px, so the cap is visible). Generate the PNG bytes on the **Linux** lane only — via `ghcr.io/cirruslabs/flutter:3.44.0` Docker `--update-goldens` (the 7.4 method; dev machine is macOS, discard macOS bytes) **or** the CI `goldens` lane. Commit the new `.png` files under `test/goldens/`. Do not regenerate existing goldens unless the cap visibly changes them (it shouldn't for the 420px-wide existing cases — the cap exceeds that width).

- [x] **Task 2 — Scaffold the repo-root `example/` Flutter app** (AC1, D1, D6)
  - [x] Create repo-root `example/` (sibling of `packages/`, `tool/`, `docs/` — see architecture.md:741–744). Generate the six platform folders so `flutter build` works for every target (AC2 / AC3 human-demo):
    ```
    cd example && flutter create --platforms=android,ios,web,linux,macos,windows \
      --org dev.koel --project-name koel_example --overwrite .
    ```
    Then **replace** the generated `lib/main.dart` + `pubspec.yaml` + `test/` with the koel versions below. Commit the generated platform folders (`android/`, `ios/`, `web/`, `linux/`, `macos/`, `windows/`) — a human demoer needs them present to `flutter run` (AC3). They are generated non-Dart files (Kotlin/Swift/CMake/HTML), untouched by `dart format`/`analyze`.
  - [x] Write [example/pubspec.yaml](example/pubspec.yaml). Mirror [packages/koel_widgets/example/pubspec.yaml](packages/koel_widgets/example/pubspec.yaml)'s shape (`publish_to: none`, `version: 0.0.1`, `resolution: workspace`, bare workspace keys) **but route core/flutter through the meta-package**:
    ```yaml
    name: koel_example
    description: Repo-root quickstart demo — a koel chat surface over the koel meta-package.
    publish_to: none
    version: 0.0.1

    environment:
      sdk: ">=3.11.0 <4.0.0"
      flutter: ">=3.38.0"

    # Pub-workspace member: shares the single root lockfile, so the AI-5.9 pins
    # (analyzer 12.1.0 / freezed 3.2.6-dev.1) govern this app and cannot drift.
    resolution: workspace

    dependencies:
      flutter:
        sdk: flutter
      # The quickstart path: re-exports koel_core + koel_http + koel_flutter
      # (KoelClient, KoelChatController, KoelClientScope, HttpAgent, …).
      koel:
      # Widgets are NOT re-exported by the meta-barrel (architecture §2:512-514) —
      # the opinionated UI layer is a direct, opt-in dependency.
      koel_widgets:

    dev_dependencies:
      flutter_test:
        sdk: flutter
      koel_lints:
      # MockAgent.programmatic — deterministic, flutter_tester-safe demo agent.
      koel_test:
    ```
    **D1:** `koel_widgets` is a **direct** dep (the meta-barrel excludes widgets, per 9.1/D1). `koel_test` is a **dev_dependency** (offline demo agent; not a runtime dep of a real consumer's app). Post-publish, a consumer would pin `koel: ^1.0.0` + `koel_widgets: ^1.0.0`; the README documents that. During dev the bare workspace keys resolve by path (AC1 "path dependency during dev").
  - [x] Add `- example` to the root [pubspec.yaml](pubspec.yaml) `workspace:` list (alongside `packages/koel_widgets/example`). Like that example, this is a workspace member but **not** a melos package, so `melos run analyze`/`test`/`test:coverage` skip it — it is exercised only by its dedicated CI lanes (Task 4). **Verify** with `melos list` that `koel_example` is absent.
  - [x] Add an [example/analysis_options.yaml](example/analysis_options.yaml) mirroring [packages/koel_widgets/example/analysis_options.yaml](packages/koel_widgets/example/analysis_options.yaml) (include root `analysis_options.yaml` via the correct relative depth — root `example/` is one level down, so `- ../analysis_options.yaml` — plus `- package:koel_lints/koel_flutter.yaml`; NO `plugins:` key — root-only).

- [x] **Task 3 — Write `example/lib/main.dart`: the chat screen** (AC1, AC3, D2, D3, D4)
  - [x] Compose the demo using **`package:koel/koel.dart`** for the core/flutter symbols (`KoelClient`, `KoelChatController`, `KoelClientScope`) + **`package:koel_widgets/koel_widgets.dart`** for `MessageBubble`/`ChatInput`/`FollowUpList`/`KoelTheme` + **`package:koel_test/koel_test.dart`** for `MockAgent`. Use the meta import for everything it re-exports (showcase the quickstart path) — do NOT import `koel_core`/`koel_flutter` directly.
  - [x] **D3 — wrap with `KoelClientScope`** (epic AC mandates it; the koel_widgets/example did not). Pattern: a `StatefulWidget` root owns the full lifecycle (create in `initState`, dispose in `dispose`) — mirror [packages/koel_widgets/example/lib/main.dart](packages/koel_widgets/example/lib/main.dart):
    - `_client = KoelClient(agent: _demoAgent());`
    - `_controller = KoelChatController(session: _client.newSession());`
    - `build` → `KoelClientScope(client: _client, child: MaterialApp(theme: ThemeData(extensions: [KoelTheme.light()]), home: _ChatScreen(controller: _controller)))`.
    - `dispose()` → controller first, then client (LIFO — the controller only cancels its own listener; the client owns session teardown). This is the correct-ownership reference.
  - [x] **D2 — demo agent = `MockAgent.programmatic()`, NOT `MockAgent.fromFixture('text_only_run')`.** The epic AC names `fromFixture`, but `FixtureLoader` resolves its asset via `Isolate.resolvePackageUri` — a `dart:io`/VM-only path that throws under `flutter test` (flutter_tester) **and** has no resolvable file in a compiled `flutter run`/`flutter build` app. Stories 6.1, 6.7, and 7.4 all made this exact substitution. Replay the identical `text_only_run` sequence programmatically:
    ```dart
    MockAgent _demoAgent() => MockAgent.programmatic()
        .runStarted()
        .textMessage('Hello, world!')
        .runFinished()
        .build();
    ```
    `MockAgent` is **reusable across runs** (mock_agent.dart:62 — "the agent is reusable across runs"), so every `send` replays the same canned reply.
  - [x] **D4 — chat screen** (a `StatelessWidget` driven by the controller, mirroring koel_widgets/example's `_ChatScreen`): a `ListenableBuilder` over the controller → `ListView.builder` of `MessageBubble(messages[i])` + a `FollowUpList` (generic suggestions, zero business domain — e.g. "Tell me a joke", "Show me code", "Summarize this") wired to `controller.send` + a `ChatInput(onSubmit: controller.send, placeholder: 'Message koel…')`. Seed **one** turn in the root's `initState` (`unawaited(_controller.send('Hello!'));`) so the demo opens on a live, visibly-streamed conversation (AC3 "streams visibly"). The `ChatInput` is fully functional — typing + Enter calls `controller.send`. **Honest behavior note for the README (D2):** because the demo agent is a fixed-script mock, every send replays the same "Hello, world!" reply (and the replayed assistant message reuses the mock's fixed id, so repeated replies fold onto one assistant bubble — a mock artifact, not a koel defect); a real backend (`AgnoAgent`/`LangGraphAgent`/`CopilotRuntimeAgent`) gives dynamic, per-turn replies. Document this in `example/README.md`, don't paper over it.
  - [x] Generic-chat only — **no business domain** (AR-22 / PRD §13 D-5): no commerce, no support-ticket, no named product personas. Plain "chat with an assistant".

- [x] **Task 4 — `example/README.md` + CI lanes** (AC1, AC2, AC3, D7)
  - [x] Write [example/README.md](example/README.md): a one-paragraph "what is this", how to run (`cd example && flutter run`), and a **clear swap section** — replace `_demoAgent()` with a real transport, e.g. `HttpAgent(url: Uri.parse('https://your-backend/agui'))` wrapped by `AgnoAgent`/`LangGraphAgent`/`CopilotRuntimeAgent` (name all three per AC1). Note the fixed-reply mock behavior from D4. No marketing prose, no badges (architecture anti-pattern rules; full docs polish is Story 9.6).
  - [x] **Smoke test** [example/test/widget_test.dart](example/test/widget_test.dart) (or `example_smoke_test.dart`): mirror [packages/koel_widgets/example/test/example_smoke_test.dart](packages/koel_widgets/example/test/example_smoke_test.dart) — pump the **real** root widget `main()` hands to `runApp`, `pumpAndSettle`, assert `takeException()` is null and `find.byType(MessageBubble)` finds widgets. Delete the `flutter create`-generated default counter `widget_test.dart`.
  - [x] **CI `example-app` lanes** in [.github/workflows/ci.yml](.github/workflows/ci.yml). Two pieces:
    1. A **lint/format/smoke** lane (mirror the existing `example-smoke` lane for koel_widgets/example): `dart format --output=none --set-exit-if-changed .` + `dart analyze` + `flutter test`, `working-directory: example`. **Reason `dart format` is needed here:** `tool/format.sh` only formats `packages/` — the root `example/`'s Dart is otherwise unchecked (mirror koel_widgets/example, which has its own CI `dart analyze`; add format too).
    2. A **`flutter build` matrix** (AC2) covering all six targets, each on a runner OS that supports it:
       - `ubuntu-latest` → `flutter build web --release`, `flutter build linux --release`, `flutter build apk --debug` (Android SDK is preinstalled on ubuntu runners).
       - `macos-latest` → `flutter build macos --release`, `flutter build ios --release --no-codesign` (no signing cert in CI ⇒ `--no-codesign`).
       - `windows-latest` → `flutter build windows --release`.
       Use `subosito/flutter-action@v2` (channel stable, `flutter-version: 3.44.0`, the .tool-versions pin — same as the existing flutter lanes), `melos bootstrap`, `melos run build` (codegen for the transitive `koel_core` `*.freezed.dart`), then the build command(s), `working-directory: example`. **D7:** these are **build** assertions (compile + bundle), not device-run — consistent with AC2 ("asserts the build succeeds") and with 6.7's deferral of device *run* lanes to AR-17. If a target genuinely cannot build green in CI, do **not** silently drop it — make it green or surface the blocker to Si with the exact failure (memory: own gate failures, no silent caps).
  - [x] Update the architecture/CI banner comment block at the top of `ci.yml` to mention the new example-app lanes (the file documents each lane's origin story — keep that convention).

- [x] **Task 5 — Gate verification** (all ACs)
  - [x] `melos bootstrap` (flutter-aware) from repo root → green resolution (the new workspace member + its deps resolve; no new hosted dep ⇒ near-zero lock churn).
  - [x] `git diff pubspec.lock` (root) → **AI-5.9 pins held**: `analyzer 12.1.0` + `freezed 3.2.6-dev.1` MUST NOT drift (SCP-2026-05-29-B).
  - [x] `melos run analyze` (all pkgs + asp plugin) clean — **including koel_widgets** (the AI-7.1 changes). NOTE (9.1 harness finding): on this machine `melos exec` parallel fan-out can crash the asp plugin (env resource limit, not a code defect); run per-package `dart analyze` sequentially if so. Also run `dart analyze` + `dart format --set-exit-if-changed` **inside `example/`** (not a melos package).
  - [x] `melos run verify:versioning` green (the root `example/` is auto-excluded — `tool/verify_versioning.sh` enumerates an explicit ten-package `release_pkgs` list; confirm the new app did NOT need to be added/excluded by hand).
  - [x] `melos run test` SUCCESS (koel_widgets gains the AI-7.1 behavioral test; goldens are tag-excluded from the default run and gated on the Linux `goldens` lane). `melos run format:check` 0-changed.
  - [x] `flutter test` in `example/` → smoke passes. Locally verify at least one `flutter build` target succeeds (e.g. `flutter build web` or the host desktop) to de-risk the CI matrix before pushing; document which targets you verified locally vs deferred to CI.
  - [x] Run the koel_widgets `goldens` lane (or Docker `--update-goldens`) and commit the two new Linux PNGs; confirm the existing goldens are byte-unchanged.

## Dev Notes

### Locked decisions

- **D1 — `example/` consumes `koel` (meta) + a DIRECT `koel_widgets` dep + `koel_test` (dev).** The meta-barrel re-exports only `koel_core` + `koel_http` + `koel_flutter` (Story 9.1/D1, architecture.md:512–514) — it does **not** surface widget symbols. So the sample app gets `KoelClient`/`KoelChatController`/`KoelClientScope` via `package:koel/koel.dart` but must declare `koel_widgets` directly for `MessageBubble`/`ChatInput`/`FollowUpList`/`KoelTheme`, and `koel_test` (dev) for `MockAgent`. This is the documented, by-design opt-in for the opinionated UI layer — and it's exactly what 9.1's Dev Notes flagged forward to 9.2 ("its `example/pubspec.yaml` MUST declare `koel_widgets` in addition to `koel`").

- **D2 — Demo agent is `MockAgent.programmatic()`, NOT `fromFixture` (parity-decided, FYI→Si).** The epic AC literally names `MockAgent.fromFixture('text_only_run')`, but `FixtureLoader._load` resolves the fixture via `Isolate.resolvePackageUri` (fixture_loader.dart) — a `dart:io`/VM-only path that throws `UnsupportedError` under `flutter test`/`flutter run`/`flutter build` and has no resolvable `File` in a compiled app's asset bundle. `fromFixture` is a **dart-test-only** loader. The programmatic builder needs neither and replays the **identical** sequence (`RUN_STARTED → assistant "Hello, world!" → RUN_FINISHED`), deterministic, runnable everywhere. Stories 6.1, 6.7, and 7.4 made this exact substitution for this exact constraint — established precedent, parity-preserving. `MockAgent` is reusable across `run()` calls (mock_agent.dart:62), so a `ChatInput`-driven multi-send demo works; the fixed-script reply (and the assistant-id fold on repeat) is a **mock artifact**, resolved by the README's "swap for a real backend" instruction — document it honestly, don't hide it.

- **D3 — `KoelClientScope` is in the tree (epic-mandated, unlike koel_widgets/example).** AC1 requires `KoelClientScope`. Wrap `MaterialApp` in `KoelClientScope(client: _client, child: …)`. Const ctor `KoelClientScope({required this.client, required super.child})`; `KoelClientScope.of(context)` is the subscribing accessor (koel_client_scope.dart:44). The controller is still built from `_client.newSession()` — the scope demonstrates idiomatic ambient-client access for any deeper widget that needs it, even though this small demo passes the controller down directly.

- **D4 — Seed one turn + functional `ChatInput`; generic chat, zero business domain.** Seed `_controller.send('Hello!')` in `initState` for a visibly-streamed conversation on open (AC3). Wire `ChatInput.onSubmit` and `FollowUpList.onSelected` to `controller.send` so the surface is genuinely interactive. Suggestions/placeholder are generic ("Tell me a joke" / "Message koel…") — no commerce/support/product domain (AR-22, PRD §13 D-5).

- **D5 — AI-7.1 is an INTERNAL layout change — no new public symbol, baseline stays frozen.** The max-width cap is a private const in `message_bubble.dart` threaded into the two internal variant chromes (`MaterialBubble`/`CupertinoBubble` are not barrel-exported); long-code no-clip is a horizontal `SingleChildScrollView` inside `_codeBlock`. **Deliberately NOT a `KoelSpacing`/`KoelTheme` token:** (a) the committed `.api-baseline/koel_widgets.json` (8 symbols, frozen at 7.4) and the 8-symbol barrel must not churn — the `dart_apitool` diff gate is Story 9.3, and a new public token would force a baseline regen that 9.2 doesn't own; (b) the Epic-7 retro frames AI-7.1 as **layout polish**, not a theming feature; (c) a sample-app story should not expand `koel_widgets`' public theming contract. If Si later wants the cap themeable, that's a deliberate `KoelSpacing` addition in a future minor — not this story. The cap value (~560dp) is a fixed reading-width: a no-op on phones (screen < cap → bubble fills width), a cap on wide desktop/web (role `Align` stays meaningful) — and golden-deterministic.

- **D6 — `example/` is a workspace member but NOT a melos package; CI-only (mirror koel_widgets/example).** Add to the root pub `workspace:` so it shares the lockfile (AI-5.9 pins govern it). Melos' package detection does not pick up the nested/`example/` dir, so `melos run analyze`/`test`/`test:coverage` skip it (verify with `melos list`). It is exercised only by its own CI lanes. `tool/format.sh` formats `packages/` only — so the example's Dart is format-checked by its **own** CI step, not `melos run format:check`.

- **D7 — Six-platform = `flutter build` (compile+bundle), each on its supporting runner OS; non-codesigned where needed.** AC2 says "asserts the build succeeds," not "runs on a device." Build web/linux/android(apk) on ubuntu, macos/ios(`--no-codesign`) on macOS, windows on windows. iOS needs `--no-codesign` (no CI signing cert); Android `apk --debug` (no release keystore). This is the natural reading of AR-22 + the honest continuation of 6.7, which already deferred device-*run* lanes to AR-17. Committing the six `flutter create` platform folders is required for both the builds and the AC3 human `flutter run`.

### Current state of files being modified (read before editing)

- [packages/koel_widgets/lib/src/bubble/message_bubble.dart](packages/koel_widgets/lib/src/bubble/message_bubble.dart): `StatelessWidget` dispatcher. Parses content → segments, resolves `KoelTheme` (with null-fallback), builds the segment `Column`, then dispatches to `CupertinoBubble`/`MaterialBubble` by `style ?? platform`. `_codeBlock` (line 117) builds the fenced block (`DecoratedBox` + padded `Text`). **No width constraint today.** Task 1 adds the cap + code-scroll.
- [packages/koel_widgets/lib/src/bubble/material_bubble.dart](packages/koel_widgets/lib/src/bubble/material_bubble.dart) / [cupertino_bubble.dart](packages/koel_widgets/lib/src/bubble/cupertino_bubble.dart): internal chromes — `Align(alignment, child: Material/DecoratedBox(child: Padding(child)))`. Add a `maxWidth` field + `ConstrainedBox` inside the `Align`.
- [packages/koel_widgets/test/goldens/message_bubble_golden_test.dart](packages/koel_widgets/test/goldens/message_bubble_golden_test.dart): 4 goldens (material/cupertino × light/dark) on a fixed 420×200 surface via `view.physicalSize`. Add the wide-prose + long-code goldens with a wider `physicalSize`.
- [packages/koel_widgets/example/](packages/koel_widgets/example/) — the **template** for the new root example (main.dart, pubspec.yaml, analysis_options.yaml, test/example_smoke_test.dart). Copy its shape; change the import routing (D1) + add `KoelClientScope` (D3) + the platform folders (D7).
- [.github/workflows/ci.yml](.github/workflows/ci.yml): jobs `analyze-test`, `web`, `flutter-smoke`, `goldens`, `example-smoke`. The new example-app lint+build lanes follow the `example-smoke`/`flutter-smoke` patterns (subosito/flutter-action@v2, flutter 3.44.0, melos bootstrap + build).
- Root [pubspec.yaml](pubspec.yaml): `workspace:` lists every member incl. `packages/koel_widgets/example`. Add `- example`.

### What must keep working (regression guards)

- **AI-5.9 pins held** — `analyzer 12.1.0` / `freezed 3.2.6-dev.1` no drift in root `pubspec.lock`. This story adds no new hosted dependency (Flutter SDK + koel_* paths only).
- **`koel_widgets` public surface frozen** — exactly 8 barrel symbols; `.api-baseline/koel_widgets.json` byte-unchanged. AI-7.1 is internal (D5). The 4 existing goldens stay byte-identical (the 420px-wide cases are below the cap).
- **`verify:versioning` stays green and the ten-package release set unchanged** — the root `example/` is NOT a release package and must NOT enter `tool/verify_versioning.sh`'s `release_pkgs` list. Confirm it's auto-excluded.
- **`melos run test`/`analyze`/`test:coverage` unaffected by the new example** — it is not a melos package (D6); `melos list` must not show `koel_example`. Existing suites (koel_widgets 42 widget + goldens, koel_flutter 74, etc.) stay green; koel_widgets test count rises by the AI-7.1 behavioral test(s).
- **`koel_devtools` + `packages/koel_widgets/example` untouched.**

### Scope boundaries (explicitly OUT of 9.2)

- `dart_apitool` wiring / `api-diff.yml` / baseline regen → **Story 9.3**. (9.2 keeps the surface frozen precisely so 9.3 owns the gate.)
- Perf baselines / `BENCHMARKS.md` / `perf-bench.yml` → **Story 9.4**.
- `conformance.yml` / `publish-dry-run.yml` / removing `publish_to: none` → **Story 9.5 / 9.9**.
- Docs site + per-package README polish to §13 D-1 bar + `TextStyle.lerp` inherit note (AI-7.2) → **Story 9.6**. (9.2 writes only `example/README.md`, at demo quality, not the docs-site bar. The root/`koel` README quickstart inaccuracies — `endpoint:` vs the real `url:` ctor param, `chatSession`/`run` vs `newSession`/`send` — are **9.6**'s to fix, not this story's.)
- iOS/Android device-**run** lanes (emulator/simulator on-device execution) → **AR-17** full 10×6 matrix. 9.2 ships `flutter build` (compile+bundle) per D7.
- Making the demo agent emit **dynamic** replies → out of scope; the mock is a fixed-script showcase, real backends are the README swap.

### Testing standards

- koel_widgets tests run under `flutter test` (AI-6.2 anchor routes `sdk: flutter` packages). Default run excludes `perf`+`golden` tags; the AI-7.1 behavioral test is a plain `testWidgets` (runs in the default lane). Goldens are Linux-canonical, generated via Docker/CI (never commit macOS-rendered bytes).
- The example smoke pumps the **real** root (`main()`'s composition path), `pumpAndSettle`, asserts no exception + bubbles render — exactly the koel_widgets/example pattern.
- Keep the behavioral width test deterministic: fix the surface size via `view.physicalSize` (golden-test pattern) so the cap is reproducibly exercised.

### Project Structure Notes

- Matches architecture.md:741–744 — repo-root `example/` = `pubspec.yaml` + `lib/main.dart` (generic chat, no business domain) + `README.md`, "uses `koel`". Adds `test/` + the six `flutter create` platform folders (needed for `flutter build`/`run`; not in the architecture sketch but implied by AC2's six-platform build). No structural variance from the intent.
- The ten-package v1.0.0 release set is unchanged; `example/` is tooling/showcase (like `tool/`, `_bmad-output/`), never published.

### References

- [Source: epics/epic-9-meta-package-sample-app-v100-release-gates.md#Story 9.2] — AC1–AC3 verbatim, incl. the AI-7.1 fold (line 64).
- [Source: architecture.md#repo tree (lines 741–744, 746–757)] — repo-root `example/` layout + package roster.
- [Source: architecture.md#examples (lines 677–678, 1111–1113)] — per-package + repo-level example convention; repo `example/` uses the `koel` meta-package.
- [Source: architecture.md#2. Public/private discipline (lines 503–514)] — meta re-exports core+http+flutter only, NOT widgets (D1).
- [Source: epic-7-retro-2026-06-06.md (AI-7.1, lines 47, 88, 105)] — bubble max-width cap + long-code no-clip re-homed from 7.2/7.4 → 9.2.
- [Source: deferred-work.md (lines 7–8)] — the original 7.2 max-width/long-code deferral + the 9.2 re-home.
- [Source: implementation-artifacts/9-1-koel-meta-package-versioning.md] — meta-barrel shape, D1 (widgets excluded), `verify_versioning.sh` ten-package list, AI-5.9 pin discipline, the `melos exec` asp-crash harness note.
- [Source: packages/koel_widgets/example/] — the runnable-example + smoke-test + CI-lane template (fixture→programmatic substitution precedent).
- [Source: packages/koel_test/lib/src/mock_agent.dart:40,52,59–72] — `programmatic()` builder; `fromFixture` is dart:io/VM-only; agent reusable across runs (D2).
- [Source: prds/prd-koel-2026-05-27/prd.md §13 D-5] — generic chat, zero business domain.
- [Source: sprint-change-proposal-2026-06-06-B.md] — Epic 9 resequence; AI-7.1 folded into 9.2.

## Review Findings

Code review 2026-06-06 — 3-layer adversarial (Blind Hunter / Edge Case Hunter / Acceptance Auditor), all findings independently re-verified by the reviewer. **0 decision-needed, 2 patch, 0 defer, 12 dismissed.**

### Patch (must fix)

- [x] **[Review][Patch] `example/README.md` backend-swap snippet does not compile** ✅ FIXED 2026-06-06 — rewrote the snippet to construct the adapter directly (`AgnoAgent(baseURL: …)`) and dropped the `show HttpAgent` import + wrapping framing; bullet list now shows each adapter's real named ctor. [example/README.md:39-50] — The "Swap in a real backend" snippet shows `AgnoAgent(HttpAgent(url: Uri.parse('https://your-backend/agui')))` and `import 'package:koel/koel.dart' show HttpAgent;`. **Verified against source:** all three adapters `extends HttpAgent` (they *are* the transport, not wrappers) and take named ctors — `AgnoAgent({required Uri baseURL, …})` (agno_agent.dart:10), `LangGraphAgent({required Uri deploymentUrl, …})` (langgraph_agent.dart:14), `CopilotRuntimeAgent({required Uri endpoint, required String agentName, …})` (copilot_runtime_agent.dart:22). None accepts a positional `HttpAgent` or a `url:` param ⇒ a consumer copy-pasting the snippet hits a compile error. The single artifact this README exists to get right. (The spec's own Task-4 hint at line 110 carried the same error — but the OUT-of-scope "README quickstart inaccuracies → 9.6" deferral is scoped to the root/`koel` README, not this `example/README.md` which 9.2 authors. Source: Acceptance Auditor.)

- [x] **[Review][Patch] "repeated replies fold onto one assistant bubble" is factually wrong — they append** ✅ FIXED 2026-06-06 — corrected the README honest-behavior note to "the thread fills with repeated identical assistant turns … duplicate bubbles even share an id". (The `main.dart` `_demoAgent` dartdoc said only "each `send` replays the same canned reply" — already accurate, left untouched; the wrong claim lived only in the README.) [example/README.md:28-31; example/lib/main.dart:25-27] — Both the README honest-behavior note and the `_demoAgent` dartdoc claim repeated sends "fold onto one assistant bubble." **Empirically refuted** (`flutter test`, two sends + `pumpAndSettle`): `total=4 helloCount=2 ids=[mock-msg-1, mock-msg-1]` — each send **appends another** "Hello, world!" assistant bubble. The reducer's `TextMessageEndEvent` arm is a pure append (`messages: [...state.messages, pending]`, chat_state_reducer.dart:109) with no fold/upsert-by-id, and the mock bakes a fixed `mock-msg-1` at build. So the visible behavior is N duplicate bubbles sharing a colliding id (the colliding id is a latent concern, not a fold). The honesty note — the whole point of D2/D4 — is itself inaccurate. Fix the wording in both artifacts. (Source: Edge Case Hunter, reframed + verified.)

### Dismissed (false positives / mischaracterized / out-of-scope) — recorded for audit

- [x] **[Review][Dismiss] "existing 4 goldens regress / `SingleChildScrollView` doesn't shrink-wrap short code"** (Edge Case Hunter, HIGH) — **FALSE POSITIVE.** The Edge Case Hunter ran `flutter test --tags golden` on **macOS** and read the failures as a layout regression; these goldens are **Linux-canonical** (by design — dev machine is macOS), so all 6 fail on macOS purely from font-rendering, independent of any code change. Reviewer probe on a single platform: `prose=256.5 codeTextIntrinsic=185.5 codeBgRendered=205.5` — the code surface hugs the token (185.5 + 20 padding = 205.5), it does **not** fill the 256.5 prose width. Old (`Text`) and new (`SCV→Text`) render the code block identically; the committed Linux PNGs still match on the CI Linux lane. The dev's "shrink-wraps short code / existing 4 byte-unchanged" claim holds.
- [x] **[Review][Dismiss] platform folders absent from the change** (Blind Hunter, MEDIUM) — false positive: the Blind Hunter saw only the hand-written diff; the six `flutter create` platform folders (~124 files) are committed (untracked-but-present), confirmed by `git status`.
- [x] **[Review][Dismiss] width-cap test is a tautology / false-green** (Blind Hunter, MEDIUM) — mischaracterized. `expect(width, lessThanOrEqualTo(560))` is contingent on the code: remove the `ConstrainedBox` and on the 1200px surface the `* 40` prose makes the Material ~1200 > 560 ⇒ the test **fails**. So it is a valid cap-presence regression guard. (Optional nicety only: `closeTo(560, 1)` would additionally prove the cap *binds* and would catch a wrong cap value; not required.)
- [x] **[Review][Dismiss] unawaited `send` in initState races dispose → post-dispose notify** (Blind Hunter, MEDIUM) — handled: `KoelChatController` is cancel-correct (`_disposed` latch guards `notifyListeners`; `dispose()` cancels `_sub`; "the session never emits after its own dispose" — koel_chat_controller.dart:28-71). The reference example is correct.
- [x] **[Review][Dismiss] `SingleChildScrollView` is intrinsic-hostile (throws under an `IntrinsicWidth` ancestor)** (Blind Hunter, HIGH) — true property of viewports, but not triggered by any current composition: the bubble body is hosted in a `ListView.builder` / `Column`, neither of which probes intrinsics. Speculative-future-composition; no live trigger (no-just-in-case).
- [x] **[Review][Dismiss] `flutter build apk --debug` Android SDK not provisioned by flutter-action** (Blind Hunter, HIGH) — `ubuntu-latest` preinstalls the Android SDK + accepts licenses (spec D7/Task-4 explicitly relies on this); common practice. Forward-CI item to watch on first push; cannot be verified locally. Same for iOS pods on macos-latest (preinstalled).
- [x] **[Review][Dismiss] CI jobs lack `needs:` ordering (expensive matrix runs even when cheap gates are red)** (Blind Hunter, MEDIUM) — cost optimization opinion, not correctness; consistent with the existing flat job list.
- [x] **[Review][Dismiss] `melos run build` / `--delete-conflicting-outputs`** (Blind Hunter + Edge Case Hunter, LOW) — `melos run build` exists and is used by the pre-existing lanes; not introduced by this change.
- [x] **[Review][Dismiss] `pumpAndSettle` may hang with a streaming agent** (Blind Hunter + Edge Case Hunter, LOW) — the programmatic mock is finite/synchronous; settles immediately (smoke green). Future fixture/timer swap is out of scope.
- [x] **[Review][Dismiss] session double-send overwrites `_sub`/`_completer` with no in-flight guard** (Edge Case Hunter, MEDIUM) — pre-existing koel_core `ChatSession` send-concurrency semantics, not changed by 9.2; the fast mock never overlaps in the demo. Out of scope.
- [x] **[Review][Dismiss] UI `controller.send` callbacks have no disposed/streaming guard** (Edge Case Hunter, LOW) — the minimal demo is correct under the controller's cancel-correct teardown; adding guards would obscure the reference.
- [x] **[Review][Dismiss] `koel_test` in `dependencies` not `dev_dependencies`; D6 `melos list` premise** (Acceptance Auditor) — both are accurately disclosed, justified FYI deviations (lib/ runtime use ⇒ `depend_on_referenced_packages`; melos 7 lists all workspace members) and verified to leave the release/coverage/versioning gates intact.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Opus 4.8) under the `/agent-flutter-engineer` persona (CLAUDE.md mandate).

### Debug Log References

- Goldens generated on the **Linux** lane via `ghcr.io/cirruslabs/flutter:3.44.0` Docker `--update-goldens` (dev machine is macOS; never commit macOS-rendered bytes). The container's `melos bootstrap` rewrote `.dart_tool/package_config.json` with `/repo/...` paths → local `dart analyze` then flooded with ~1672 phantom `comment_references`/`public_member_api_docs` infos; fixed by re-running `melos bootstrap` locally (paths restored, analyze clean). Heads-up for any future Docker-golden round.
- `melos run analyze` (parallel `melos exec`) hung with 10+ `analysis_server_aot` processes — the asp parallel-crash the 9.1 harness note documented. Killed and re-ran **sequentially per package** (`dart analyze` in each of the 13 members) → ALL-GREEN. The asp env limit is not a code defect.

### Completion Notes List

**Implemented (all 3 ACs satisfied):**

- **AC1 + AC3 (Task 1) — AI-7.1 landed in `koel_widgets`, internal-only (D5):** private `const double _maxBubbleWidth = 560` in `message_bubble.dart`, threaded into both internal variant chromes (`MaterialBubble`/`CupertinoBubble`) as a `required final double maxWidth` field wrapping their surface in `ConstrainedBox(maxWidth)` **inside** the existing `Align`. Long-code no-clip: the `_codeBlock` `Text` is wrapped in `SingleChildScrollView(scrollDirection: Axis.horizontal)`. **No new public symbol** — the 8-symbol barrel + `.api-baseline/koel_widgets.json` stay frozen for 9.3. +2 behavioral tests (wide-surface width-cap assertion via the rendered `Material` size; long-token → `SingleChildScrollView` present + no exception); koel_widgets 42 → **44**. +2 Linux goldens (`message_bubble_wide_prose_capped.png`, `message_bubble_long_code_scroll.png`); the **existing 4 goldens are byte-unchanged** (the cap exceeds the 420px existing surface; `SingleChildScrollView` *shrink-wraps* short code — `_RenderSingleChildViewport` sizes to `constraints.constrain(child.size)` — so the chip still hugs).
- **AC1 (Tasks 2–3) — repo-root `example/`** consuming `package:koel/koel.dart` (meta: `KoelClient`/`KoelChatController`/`KoelClientScope`) + `package:koel_widgets/koel_widgets.dart` + `package:koel_test/koel_test.dart`. `StatefulWidget` root owns the full lifecycle (create in `initState`, dispose controller-then-client LIFO), wraps `MaterialApp` in `KoelClientScope` (D3), seeds one streamed turn (D4). Demo agent = `MockAgent.programmatic()` (D2), generic chat / zero business domain (AR-22 / PRD §13 D-5). Six `flutter create` platform folders committed.
- **AC2 (Task 4) — CI `example-app` (lint/format/smoke) + `example-build`** six-target `flutter build` matrix (ubuntu: web/linux/apk-debug + apt `ninja-build`/`libgtk-3-dev`; macos: macos/ios `--no-codesign`; windows: windows). `example/README.md` documents the `HttpAgent(url:)` swap naming all three backends (Agno/LangGraph/CopilotRuntime). Top-of-file CI banner updated.

**Decisions / deviations (FYI → Si):**

- **`koel_test` is a runtime `dependencies` entry, NOT `dev_dependencies` (deviates from Task 2/D1's literal placement).** `lib/main.dart` constructs the mock agent and `flutter run`'s entrypoint *is* `lib/`, so `depend_on_referenced_packages` (source-truth lint) mandates `dependencies` — exactly as the cited `packages/koel_widgets/example` template already does. A `dev_dependency` placement would force a `// ignore:` on the import (silent-error anti-pattern). The README still instructs a real consumer to delete `koel_test` after swapping in a backend, preserving D1's intent.
- **D6's `melos list` premise is factually wrong for melos 7.** Melos 7 enumerates **all pub-workspace members**, so `melos list` shows `koel_example` (and has shown `koel_widgets_example` since Story 7.4 — the 7.4 note even records "test SUCCESS … + example smoke"). The example is therefore swept by `melos run test`/`analyze` and simply passes there (verified green). The substantive guards hold: `verify:versioning` (explicit ten-package `release_pkgs`) and `test:coverage` (explicit package list) both exclude examples, so the release set and coverage gates are untouched. No attempt was made to force `koel_example` out of `melos list`, since that would also require changing the untouched `koel_widgets_example`.
- **Six-platform = `flutter build` (compile+bundle), per D7** — not device-run; iOS `--no-codesign`, Android `apk --debug`. Device/simulator *run* lanes remain Epic 9 / AR-17. De-risked locally with `flutter build web --release` (green; the cupertino_icons font warning is benign — no such hosted dep was added).

**Gates (all green):** `melos bootstrap` 13 pkgs; `pubspec.lock` **0-drift** (AI-5.9 analyzer 12.1.0 / freezed 3.2.6-dev.1 held — example adds only path members + flutter/flutter_test already in lock); `analyze` ALL-GREEN (13/13 sequential, incl. koel_widgets + example); `verify:versioning` OK; `test` SUCCESS (koel_widgets 44, koel_flutter 74 unchanged, both example smokes green); `format:check` 210/0-changed + example `dart format` 0-changed; existing 4 goldens byte-identical.

### File List

**Modified (koel_widgets — AI-7.1):**
- `packages/koel_widgets/lib/src/bubble/message_bubble.dart` — `_maxBubbleWidth` const + pass `maxWidth` to both variants + `_codeBlock` horizontal `SingleChildScrollView`
- `packages/koel_widgets/lib/src/bubble/material_bubble.dart` — `maxWidth` field + `ConstrainedBox` inside `Align` + dartdoc
- `packages/koel_widgets/lib/src/bubble/cupertino_bubble.dart` — `maxWidth` field + `ConstrainedBox` inside `Align` + dartdoc
- `packages/koel_widgets/test/bubble/message_bubble_test.dart` — +2 AI-7.1 behavioral tests (cap, long-code no-clip)
- `packages/koel_widgets/test/goldens/message_bubble_golden_test.dart` — +2 wide-surface goldens (`_wideProse`, `_longCode`, `_useWideSurface`), parameterized `_host`

**Added (koel_widgets goldens — Linux-canonical):**
- `packages/koel_widgets/test/goldens/message_bubble_wide_prose_capped.png`
- `packages/koel_widgets/test/goldens/message_bubble_long_code_scroll.png`

**Modified (workspace + CI):**
- `pubspec.yaml` (root) — `- example` added to `workspace:`
- `.github/workflows/ci.yml` — `example-app` + `example-build` jobs + banner

**Added (repo-root `example/` — new workspace member):**
- `example/lib/main.dart` — the chat-screen demo over the `koel` meta-package
- `example/pubspec.yaml`, `example/analysis_options.yaml`, `example/README.md`
- `example/test/widget_test.dart` — §6 smoke (pumps the real root)
- `example/{android,ios,web,linux,macos,windows}/…` — the six `flutter create` platform folders (committed for build + human `flutter run`)

## Change Log

| Date       | Change                                                                                                                                                  |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 2026-06-06 | Story 9.2 implemented → review. AI-7.1 bubble max-width cap + long-code no-clip (internal, koel_widgets 42→44 tests, +2 Linux goldens, existing 4 byte-unchanged); repo-root `example/` app over the `koel` meta-package (six platform folders, smoke test); CI `example-app` + six-platform `example-build` lanes. `koel_test` placed in `dependencies` (lib/ runtime use) and D6 melos-7 premise corrected — both recorded as FYI deviations. All gates green; pubspec.lock 0-drift. |
