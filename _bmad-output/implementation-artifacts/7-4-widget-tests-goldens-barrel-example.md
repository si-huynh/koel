---
baseline_commit: 49eeaed4e1f97bfc42679b9cf5a949ae8ae51920
---

# Story 7.4: Widget tests + golden tests + barrel + example demo (koel_widgets SEALER)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter developer,
I want comprehensive golden tests covering every `koel_widgets` primitive (× Material/Cupertino × light/dark), a **sealed** barrel `lib/koel_widgets.dart` with a committed `dart_apitool` baseline + the `public_member_api_docs` doc gate, an ≥80% coverage gate, and a runnable `example/` app demonstrating composition with `koel_flutter`'s `KoelChatController`,
so that the **1.x `koel_widgets` contract is sealed** and consumers see a working end-to-end demo, per Epic 7.4 + AR-22 (sample-app preparation).

## Acceptance Criteria

1. **Barrel verified-sealed (8 symbols, no rewrite).** `lib/koel_widgets.dart` exports **exactly** the 8-symbol public surface — `KoelTheme`, `KoelColors`, `KoelTextStyles`, `KoelSpacing`, `MessageBubble`, `BubbleStyle`, `ChatInput`, `FollowUpList` (the epic's literal 7 + `BubbleStyle`, which appears in `MessageBubble`'s public ctor). The barrel is **already** at this surface after 7.3 — 7.4 **verifies** it (does NOT rewrite or add symbols) and updates the library-level dartdoc from "seals at 7.4" to past-tense "sealed". Importing `package:koel_widgets/koel_widgets.dart` resolves all 8 and nothing else (internal `MaterialBubble`/`CupertinoBubble`/`_Pill`/`_SubmitTextIntent`/`resolveKoelTheme` stay unexported). [Source: epics/epic-7…#Story-7.4 AC1; 7-3 Task 7 "symbol set complete at 8"; lib/koel_widgets.dart]

2. **`public_member_api_docs` doc gate added + green (NFR-13/NFR-16).** `packages/koel_widgets/analysis_options.yaml` gains the package-finalization lints — `public_member_api_docs: true` + `comment_references: true` + the `analyzer.exclude` `*.freezed.dart`/`*.g.dart` block — mirroring `koel_flutter/analysis_options.yaml` (2.15/6.8 pattern), **without** adding a `plugins:` key (it stays at the workspace root only — `plugins_in_inner_options`). The gate fires on **every public-named member in `lib/` including `lib/src/`** — so `MaterialBubble` + `CupertinoBubble` (public-named, unexported, added in 7.2) and any of their public members must be documented; backfill only real gaps. `dart analyze` (curated Flutter profile + asp plugin + the new doc gate) exits **0**. [Source: packages/koel_flutter/analysis_options.yaml:14-39; 6-8 Dev Agent Record "backfilled 2 undocumented segment ctors"; lib/src/bubble/material_bubble.dart:10, cupertino_bubble.dart:12]

3. **Golden tests — every primitive × design language × brightness, Linux-canonical, tag-gated (epic AC2).** Native `matchesGoldenFile` golden tests (NO new dependency — see Dev Notes "Golden harness: native `matchesGoldenFile`, not alchemist") cover each primitive under each relevant axis: `MessageBubble` material-light / material-dark / cupertino-light / cupertino-dark (the epic's named 4-golden minimum), plus `ChatInput` and `FollowUpList` light/dark. Every golden test file is tagged `@Tags(['golden'])`. The committed golden PNGs live under `packages/koel_widgets/test/goldens/` and are **rendered on Linux** (the deterministic golden platform — rounded-corner anti-aliasing differs per OS); they are **excluded** from the default `melos test` and `melos test:coverage` runs (so a macOS/Windows dev never false-fails against Linux bytes) and **gated** on a new Linux-only `goldens` job in `ci.yml`. [Source: epics/epic-7…#Story-7.4 AC2; ci.yml flutter-smoke precedent]

4. **`dart_apitool` baseline committed (epic AC1 second half).** With `dart_apitool 0.23.1` **globally** activated (isolated from the workspace analyzer-12/freezed pins), extract the koel_widgets public surface **after** the barrel is verified-final and commit it to `packages/koel_widgets/.api-baseline/koel_widgets.json` (the 2.15/6.8 path convention). 6.8 proved 0.23.1 extracts a Flutter package on SDK 3.12 with no special flag — **verify, don't assume**: if extraction fails, capture the exact error, hand off to `9-3` in `deferred-work.md`, and commit a hand-verified 8-symbol surface manifest as the interim baseline (do NOT fabricate a passing extract). The diff **gate** (`api-diff.yml`) stays Epic 9's (9-3); 7.4 ships the baseline artifact only. [Source: 2-15 Task 6; 6-8 D8; packages/koel_flutter/.api-baseline/koel_flutter.json]

5. **`example/` app — end-to-end composition, fixture-driven (epic AC2 + AR-22).** `packages/koel_widgets/example/lib/main.dart` is a runnable Flutter app that renders a chat surface composed of `MessageBubble` (over the controller's messages) + `ChatInput` + `FollowUpList`, themed via `KoelTheme` attached to `MaterialApp.theme.extensions`, driven by a `KoelChatController` whose session wraps `await MockAgent.fromFixture('text_only_run')` from `koel_test`. The example is a **pub-workspace member** (added to the root `workspace:` list + `resolution: workspace` in its pubspec) so it shares the single lockfile (no AI-5.9 drift). A smoke test `example/test/example_smoke_test.dart` pumps the app, `pumpAndSettle`s, and asserts it builds without throwing and a `MessageBubble` is present. A new Linux `example-smoke` job in `ci.yml` runs it (architecture §6 "every example … runs to completion without throwing"). [Source: epics/epic-7…#Story-7.4 AC2; architecture.md:676-689; packages/koel_test/lib/src/mock_agent.dart:52; packages/koel_flutter/test/controller/koel_chat_controller_test.dart:16-18]

6. **Coverage ≥80% wired + green (NFR-12, epic AC4).** Root `pubspec.yaml` `melos.scripts.test:coverage` gains `bash "$MELOS_ROOT_PATH/tool/coverage.sh" packages/koel_widgets 80 80`. koel_widgets carries `sdk: flutter` (deps + dev-deps) so `coverage.sh` routes it to the **`flutter test --coverage`** branch (native `lcov.info`, branch defaults 100 ⇒ **line is the gate**). Golden tests are excluded from the coverage run (they add no `lib/` line coverage the widget tests don't already exercise). `melos run test:coverage` reports koel_widgets **line ≥ 80%**; if a symbol genuinely blocks 80%, surface it rather than silently lowering the tier. [Source: tool/coverage.sh:47-52; root pubspec.yaml:32-42; epics/epic-7…#Story-7.4 AC4]

7. **All gates green + zero drift (epic AC4, NFR-13).** `melos run format:check` 0-changed; `melos run analyze` SUCCESS across all 11 packages incl. the new doc gate; `melos run test` SUCCESS (the existing 41 koel_widgets widget tests + the example smoke; goldens excluded by tag); `pubspec.lock` **0-drift** to the AI-5.9 pins (`analyzer 12.1.0` / `freezed 3.2.6-dev.1`) — the example introduces no new **hosted** dep beyond what the lock already carries (only `koel_*` + `flutter`/`flutter_test`). [Source: 6-8 Dev Agent Record gate block; sprint-status AI-5.9 pin watch]

## Tasks / Subtasks

- [x] **Task 1 — Verify-seal the barrel + update library dartdoc (AC: #1)**
  - [x] Confirm `lib/koel_widgets.dart` exports **exactly** the 8 symbols (`KoelTheme, KoelColors, KoelTextStyles, KoelSpacing, MessageBubble, BubbleStyle, ChatInput, FollowUpList`) via the four sectioned `show` exports. Do **not** add, remove, or re-shape any export — 7.3 left it final. Internal helpers (`resolveKoelTheme`, `_SubmitTextIntent`, `MaterialBubble`, `CupertinoBubble`, `_Pill`) must remain unexported.
  - [x] Edit only the library-level doc comment: change the forward-looking "grows incrementally per story and **seals at 7.4**" wording to past-tense "**sealed** to exactly the widget primitives … plus the theming hook" (the surface is now frozen). No code change.

- [x] **Task 2 — Add the `public_member_api_docs` doc gate + backfill (AC: #2)**
  - [x] Append to `packages/koel_widgets/analysis_options.yaml` (after the existing two `include:`s — keep them) an `analyzer.exclude` block (`**/*.freezed.dart`, `**/*.g.dart` — inert here, kept for sibling-parity) and a `linter.rules` block with `public_member_api_docs: true` + `comment_references: true`. **Do NOT** add a `plugins:` key (root-only; the analyzer rejects it in inner files). Copy the koel_flutter file's structure + comments verbatim, retargeting the narration to koel_widgets/Story-7.4.
  - [x] Run `dart analyze` in `packages/koel_widgets`. The gate fires on every **public-named** declaration in `lib/` (incl. `lib/src/`). Backfill a one-line `///` on any that fire — expect `MaterialBubble` + `CupertinoBubble` and possibly their public ctors/fields (added in 7.2 before the gate existed); 7.1/7.2/7.3's barrel-exported members were documented as-they-went so should be clean. Demote any broken `[Ref]` comment-reference to a plain code-span if `comment_references` flags it (the 6.8 experience). Re-run → **exit 0**.

- [x] **Task 3 — Golden infrastructure: tag + exclusion wiring (AC: #3, #7)**
  - [x] Create `packages/koel_widgets/dart_test.yaml` declaring the `golden` tag (mirror `koel_flutter/dart_test.yaml`'s `perf` declaration — `tags: { golden: {} }` — the declaration alone suppresses the "undeclared tag" warning). Narrate: golden tests are Linux-canonical, excluded from the cross-platform default runs, gated on the Linux `goldens` CI lane.
  - [x] Add `golden` to the Flutter exclusion in the two shared scripts so a macOS/Windows dev (and the coverage run) never compares against Linux bytes: `tool/test_package.sh:39` `flutter test --exclude-tags=perf` → `--exclude-tags=perf,golden`; `tool/coverage.sh:48` `flutter test --coverage --exclude-tags=perf` → `--exclude-tags=perf,golden`. These edits are inert for every other package (no `golden`-tagged tests elsewhere) and mirror exactly how `perf` is excluded. Update each script's adjacent comment to name `golden` alongside `perf`.

- [x] **Task 4 — Write the golden tests (AC: #3)**
  - [x] Create `test/goldens/` test files (suggest one per primitive: `message_bubble_golden_test.dart`, `chat_input_golden_test.dart`, `follow_up_list_golden_test.dart`), each with a **file-level** `@Tags(['golden'])` annotation (top of file, before `library;`/imports per dart_test convention) and importing widgets via `package:koel_widgets/koel_widgets.dart`.
  - [x] For `MessageBubble`, render the **named 4 minimum**: `BubbleStyle.material` × `KoelTheme.light()`/`dark()` and `BubbleStyle.cupertino` × light/dark, each wrapping a fixed `Message` with **mixed** segments (a text + a fenced code block, exercising the 7.2 code-block path) so the golden is meaningful. For `ChatInput` and `FollowUpList`, render light + dark. Attach `KoelTheme` via the host app's `ThemeData(extensions: [KoelTheme.light()/dark()])` so the widgets read real tokens (not the null-fallback) — and add one `ChatInput`/`FollowUpList` golden under a bare `CupertinoApp` to lock the null-`KoelTheme` fallback's pixels too if cheap.
  - [x] Use `matchesGoldenFile('goldens/<name>.png')`; keep every input deterministic (fixed strings, fixed sizes via a sized host, **no** `DateTime.now()`/randomness/animation) — the widgets are already golden-ready per 7.1-7.3. Wrap each in a minimally-sized host (e.g. a fixed `MediaQuery`/`Center` of bounded width) so the captured surface is stable and small.
  - [x] **Generate the committed bytes on Linux** (the canonical platform — see Dev Notes "Linux-canonical golden bytes"): run `flutter test --update-goldens --tags golden` inside a Linux Flutter 3.44.0 environment (Docker image primary; the new CI `goldens` lane's first `--update-goldens` run is the fallback). Visually sanity-check locally on macOS with `--update-goldens` to confirm the **test logic** renders, but commit only the **Linux-rendered** PNGs under `test/goldens/`. Do NOT commit macOS-rendered bytes.

- [x] **Task 5 — `example/` app (AC: #5)**
  - [x] Create `packages/koel_widgets/example/pubspec.yaml`: `name: koel_widgets_example`, `publish_to: none`, `resolution: workspace`, `environment` matching the workspace (`sdk: ">=3.11.0 <4.0.0"`, `flutter: ">=3.38.0"`), `dependencies:` `flutter (sdk)`, `koel_widgets`, `koel_flutter`, `koel_core` (for `KoelClient` — koel_flutter re-exports nothing from koel_core), `koel_test` (for `MockAgent.fromFixture`); `dev_dependencies:` `flutter_test (sdk)`, `koel_lints`. Add `- packages/koel_widgets/example` to the root `pubspec.yaml` `workspace:` list so it shares the single lock.
  - [x] `example/lib/main.dart`: in `main()` build the controller — `final client = KoelClient(agent: await MockAgent.fromFixture('text_only_run')); final controller = KoelChatController(session: client.newSession());` (the koel_flutter controller-test idiom). Wrap the app in `MaterialApp(theme: ThemeData(extensions: [KoelTheme.light()]), …)`. The home scaffold: an `AnimatedBuilder`/`ListenableBuilder` on the `KoelChatController` (it's a `ChangeNotifier`) rendering `controller.state`'s messages as a `ListView` of `MessageBubble`, a `FollowUpList` of a few static suggestions calling `controller.send(...)`, and a trailing `ChatInput(onSubmit: controller.send)`. Dispose the controller. Keep it a small, idiomatic, real demo — this is the consumer-facing reference.
  - [x] `example/test/example_smoke_test.dart`: `testWidgets` that pumps the app (or its root widget), `await tester.pumpAndSettle()`, and asserts no exception was thrown + `find.byType(MessageBubble)` (after the fixture run completes) — architecture §6 "runs to completion without throwing". Keep it deterministic.
  - [x] Add `example/analysis_options.yaml` including the workspace root + `package:koel_lints/koel_flutter.yaml` (mirror the package) so the example is lint-clean; the example is **not** a melos package (`packages/*` glob doesn't match the nested dir) so it stays out of `melos test`/`analyze`/`test:coverage` — it's exercised only by the CI `example-smoke` lane + on demand.

- [x] **Task 6 — `dart_apitool` baseline (AC: #4)**
  - [x] After Task 1 confirms the barrel is final: `dart pub global activate dart_apitool 0.23.1` (global → carries its own pubspec, the AI-5.9 analyzer-12/freezed pins do NOT constrain it).
  - [x] Extract the koel_widgets surface and commit to `packages/koel_widgets/.api-baseline/koel_widgets.json` (match the `koel_flutter.json` shape — `version: 3`, `packageApi.packageName: koel_widgets`). Use the same invocation 6.8 used for koel_flutter (a Flutter package — 6.8 needed no `--force-use-flutter`). **Verify the extract succeeds**; on failure capture the exact error, write a precise hand-off to `9-3` in `deferred-work.md`, and commit a hand-verified 8-symbol manifest as the interim baseline — never fabricate a passing extract.

- [x] **Task 7 — Coverage gate wiring (AC: #6)**
  - [x] Add `bash "$MELOS_ROOT_PATH/tool/coverage.sh" packages/koel_widgets 80 80` to the `test:coverage` `run:` block in root `pubspec.yaml` (after the koel_flutter line). Update the script's `description:` to name koel_widgets at the 80% adapter/UI tier (flutter path, line-gate). No `with_chrome` (koel_widgets has no `@TestOn('browser')` suite).
  - [x] Run `melos run test:coverage`. koel_widgets routes through `flutter test --coverage --exclude-tags=perf,golden` (Task 3 edit) → native `lcov.info` → line ≥ 80%. If below floor, add the cheap missing widget-tree assertions (don't lower the tier silently); record the final % in the Dev Agent Record.

- [x] **Task 8 — CI lanes: goldens + example-smoke (AC: #3, #5)**
  - [x] Add a Linux-only `goldens` job to `.github/workflows/ci.yml` (mirror the `flutter-smoke` job's `subosito/flutter-action@v2` + `flutter-version: 3.44.0` + `melos bootstrap` + `melos run build` setup): `run: flutter test --tags golden` with `working-directory: packages/koel_widgets`, `runs-on: ubuntu-latest`. This is the deterministic golden gate (the only lane that runs the `golden`-tagged tests).
  - [x] Add a Linux `example-smoke` job: same Flutter setup, `run: flutter test` (or `flutter test test/example_smoke_test.dart`) with `working-directory: packages/koel_widgets/example`. Architecture §6 smoke ("runs to completion without throwing").
  - [x] **Do NOT** touch `perf-bench.yml`/`api-diff.yml` — those dedicated gate workflows are Epic 9's (9-3/9-4). Adding `ci.yml` **test lanes** is in-scope (6.7 set the precedent with `flutter-smoke`); wiring the dedicated **gate** workflows is not.

- [x] **Task 9 — Gate locally before marking done (AC: #7)**
  - [x] `melos run format:check` → 0-changed (auto-format the new example + golden files first; the example is outside melos format scope — run `dart format` in it manually).
  - [x] `melos run analyze` → SUCCESS across all packages incl. the new doc gate; `dart analyze` in `example/` → 0.
  - [x] `melos run test` → SUCCESS (41 koel_widgets widget tests unchanged + bubble regression; goldens excluded by tag); run the example smoke + the Linux goldens (Docker or note CI will) separately and confirm green.
  - [x] `melos run test:coverage` → koel_widgets line ≥ 80%.
  - [x] Confirm `pubspec.lock` **0-drift** to AI-5.9 pins (`analyzer 12.1.0` / `freezed 3.2.6-dev.1`) after adding the example workspace member — `melos bootstrap` / `dart pub get` must not bump the pinned transitives. If the lock drifts, stop and reconcile (the example must add no new hosted dep).

## Dev Notes

### What this story is — and is NOT

- **IS:** the **koel_widgets SEALER** — the twin of koel_core's 2.15 and koel_flutter's 6.8. It ships the *finalize artifacts* that 7.1/7.2/7.3 each explicitly deferred here: **goldens** (every primitive × design-language × brightness, on the deterministic Linux lane), the **doc gate** (`public_member_api_docs`), the **`dart_apitool` baseline**, the **≥80% coverage gate**, and the consumer-facing **`example/` app**. It also verifies (does not rewrite) the already-final 8-symbol barrel.
- **IS NOT:** any new `lib/src/**` widget logic, any new public symbol (the set is complete at 8 after 7.3), any `KoelTheme` slot change, or the **dedicated Epic-9 gate workflows** (`perf-bench.yml`/`api-diff.yml` — 7.4 ships the baseline they will diff, not the diff gate). It does NOT add a golden-harness dependency (native `matchesGoldenFile`). [Source: 7-1/7-2/7-3 "DEFER-TO-7.4"; 2-15/6-8 sealer pattern]

### Golden harness: native `matchesGoldenFile`, not alchemist/golden_toolkit (decision — FYI to Si)

The architecture is **silent** on goldens (no convention exists — `grep golden architecture.md` = 0 hits), so this story sets it, and the house's two hard constraints decide it:

- **No new dependency.** `golden_toolkit` is **archived/discontinued** (the Flutter team folded its features into the SDK). `alchemist` works but adds a dependency **and** pulls its own transitive analyzer — a real **AI-5.9 pin-drift risk** (the freezed↔asp analyzer-12 hold the whole repo guards). koel's house pattern across every package so far is **zero new deps unless a shipped widget reads it**. Flutter's **built-in `matchesGoldenFile`** (in `flutter_test`, already a dev-dep) needs nothing new.
- **Parity + simplicity.** Native goldens are the framework-source-of-truth path; the widgets are already deterministic/theme-driven (7.1-7.3 made them "golden-ready"). `matchesGoldenFile('goldens/<name>.png')` + a committed `test/goldens/` dir is exactly the epic's AC ("the goldens directory `test/goldens/` is committed").

Decision recorded as FYI (not a question): **native `matchesGoldenFile`, no harness dep.** [Source: parity_decides_ambiguous_api memory; AI-5.9 pin discipline; epics/epic-7…#Story-7.4 AC2 "test/goldens/ committed"]

### Linux-canonical golden bytes (the load-bearing detail)

This is the one piece most likely to go wrong. **Flutter goldens are platform-specific**: rounded-corner anti-aliasing, font hinting, and shadow rasterization differ between macOS/Windows/Linux `flutter_tester`. The epic AC is explicit — goldens "pass on the **Linux CI lane** (deterministic platform for goldens)". The dev machine here is **macOS** (`darwin`), so macOS-rendered bytes will **not** match the Linux gate. Therefore:

- **Tag-gate them.** Every golden test carries `@Tags(['golden'])`; the shared `--exclude-tags=perf` becomes `--exclude-tags=perf,golden` (Task 3) so the cross-platform default `melos test` + the macOS coverage run never compare against the Linux bytes and never false-fail. The **only** place goldens run is the Linux `goldens` CI job + an explicit Linux generation.
- **Generate the committed PNGs on Linux.** Primary: a Linux Flutter 3.44.0 **Docker** image (`docker run --rm -v "$PWD":/app -w /app/packages/koel_widgets <flutter-3.44.0-linux-image> flutter test --update-goldens --tags golden`) — Docker is already part of this ecosystem (the koel_backend harness). Fallback: push the golden test code + the new `goldens` CI lane, let its first run produce the bytes via `--update-goldens`, and commit those. Use macOS `--update-goldens` only to confirm the **test logic** renders; **discard** macOS bytes — commit Linux bytes only.
- Why not "just run on the dev's platform and gate there too"? Because CI is Linux and goldens don't survive an OS change; pinning one canonical platform is the standard Flutter answer and the one the AC already chose. [Source: epics/epic-7…#Story-7.4 AC2; Flutter `matchesGoldenFile` platform-sensitivity; project_koel_backend_harness memory (Docker available)]

### Coverage routes through the Flutter path (not pure-Dart)

`coverage.sh` greps `grep -q "sdk: flutter" pubspec.yaml`; koel_widgets' pubspec has `sdk: flutter` (deps **and** dev-deps), so it matches → the **`flutter test --coverage`** branch (native `lcov.info`, **no** `format_coverage`, **no** `--branch-coverage`; with no BRDA rows the awk gate's branch defaults to 100 ⇒ **line is the real gate**). Pass `80 80`; the branch arg is effectively inert. Goldens are tag-excluded from this run (Task 3) so they neither fail it cross-platform nor inflate/deflate the line number. [Source: tool/coverage.sh:47-52; root pubspec.yaml:32-42 koel_flutter precedent]

### The doc gate fires on `lib/src/`, not just the barrel

`public_member_api_docs` lints **every non-underscore-prefixed declaration in `lib/`** — exported or not. `MaterialBubble` (`lib/src/bubble/material_bubble.dart:10`) and `CupertinoBubble` (`cupertino_bubble.dart:12`) are **public-named** (no leading `_`) though unexported, so the gate **will** fire on them and any public members they expose. They were authored in 7.2 *before* the gate existed → expect to backfill one-line `///`s. `_Pill`, `_SubmitTextIntent`, `_ChatInputState` are underscore-private → exempt. The barrel-exported public members (theme types, `MessageBubble`, `ChatInput`, `FollowUpList`) were documented as-they-went per the 7.1/7.2/7.3 house habit → should already pass. This mirrors 6.8 ("backfilled 2 undocumented segment ctors + demoted 3 broken comment-refs"). [Source: dart `public_member_api_docs` semantics; lib/src/bubble/*.dart; 6-8 Dev Agent Record]

### Example app wiring — the exact idiom

The controller needs a `ChatSession`, and koel_flutter re-exports **nothing** from koel_core, so the example depends on koel_core directly. The construction idiom (from `koel_flutter/test/controller/koel_chat_controller_test.dart:16-18,198`):

```dart
final client = KoelClient(agent: await MockAgent.fromFixture('text_only_run'));
final controller = KoelChatController(session: client.newSession());
```

`KoelChatController extends ChangeNotifier` (so drive the UI with `ListenableBuilder`/`AnimatedBuilder`), exposes `state` (`ChatState`), `isStreaming`, `Future<void> send(String)`, `cancel()`, `clear()`, and must be `dispose()`d. `MockAgent.fromFixture('text_only_run')` is `Future` (loads the synthesized fixture from `koel_test/lib/src/fixtures/synthesized/text_only_run.jsonl` — RUN_STARTED → "Hello, world!" → RUN_FINISHED) — `await` it in `main()` before `runApp`. **Note:** `MockAgent.fromFixture` is `dart:io`-bound (File/Isolate) — fine for an example that runs on desktop/mobile (it is **not** compiled for web here, unlike 6.7's smoke which is why that lane used a local web-safe agent). [Source: packages/koel_flutter/lib/src/controller/koel_chat_controller.dart:24-68; packages/koel_test/lib/src/mock_agent.dart:52-55; packages/koel_core/lib/src/client/koel_client.dart:153 `newSession`]

### Example as a workspace member (no lock drift)

Make the example a **pub-workspace member**: add `- packages/koel_widgets/example` to the root `pubspec.yaml` `workspace:` list and put `resolution: workspace` in `example/pubspec.yaml`. This shares the **single** root lockfile, so the AI-5.9 pins (`analyzer 12.1.0`/`freezed 3.2.6-dev.1`) govern the example too and **cannot drift** — the example adds only `koel_*` path-resolved members + `flutter`/`flutter_test` (already in the lock), no new **hosted** dep. The nested `packages/koel_widgets/example` dir is **not** matched by melos' top-level `packages/*` glob, so it stays out of `melos test`/`analyze`/`test:coverage` — exercised only by the CI `example-smoke` lane. Verify `pubspec.lock` 0-drift after `melos bootstrap` (Task 9). [Source: root pubspec.yaml:8-19 `workspace:`; melos.yaml `packages: - packages/*`]

### CI lanes are in-scope; dedicated gate workflows are not

6.7 established that **adding `ci.yml` test lanes** is in-scope at a story (it added `flutter-smoke`). 7.4 adds two Linux test lanes — `goldens` (`flutter test --tags golden`) and `example-smoke` — both literally required by epic AC2 ("pass on the Linux CI lane", "exercised as a smoke test in CI"). What stays Epic 9's is the **dedicated gate workflows** `api-diff.yml` (diffs the `dart_apitool` baseline 7.4 ships) and `perf-bench.yml` — leave those untouched. Mirror the `flutter-smoke` job's `subosito/flutter-action@v2` + `flutter-version: 3.44.0` + `melos bootstrap && melos run build` preamble. [Source: ci.yml flutter-smoke block; 2-15 Task 7 / 6-8 D9 "do NOT touch perf-bench.yml/api-diff.yml"]

### Curated lint profile (what fires if you slip)

Beyond the new doc gate: `prefer_const_constructors`, `prefer_const_constructors_in_immutables`, `use_key_in_widget_constructors`, `use_super_parameters`, `prefer_final_fields`, `comment_references`. The example app must also pass these (it includes `koel_lints/koel_flutter.yaml`). No sealed-type `switch` is added here, so `exhaustive_switch_must_have_default` is not in play (the existing `MessageSegment` switch in `message_bubble.dart` already carries its documented `// ignore: unreachable_switch_case` default arm — don't disturb it). [Source: packages/koel_widgets/analysis_options.yaml; 7-2/7-3 lint notes]

### Testing standards

- **Goldens:** native `matchesGoldenFile`; file-level `@Tags(['golden'])`; deterministic inputs (fixed strings/sizes, no time/random/animation); committed PNGs Linux-rendered under `test/goldens/`; gated only on the Linux `goldens` CI lane. Pump under a host that supplies `KoelTheme` via `ThemeData(extensions: […])` for the themed goldens; under a bare `CupertinoApp` for the null-fallback golden.
- **Widget tests:** the existing 41 (9 input + 6 follow-up + bubble + theme) are the regression guard — they stay green; don't rewrite them. Add only what coverage needs to clear 80% line.
- **Example smoke:** `testWidgets` + `pumpAndSettle` + no-throw + `find.byType(MessageBubble)`; deterministic (the fixture is fixed).
- **Coverage:** package line ≥ 80% (NFR-12 adapter/UI tier; the epic header says "Coverage ≥ 80%"). Goldens + example excluded from the package coverage number. [Source: architecture.md §10 NFR-12/13; epics/epic-7 header]

### Project Structure Notes

- **New:** `packages/koel_widgets/test/goldens/` (golden PNGs + the `*_golden_test.dart` files — or co-locate the test files under `test/<feature>/` and the PNGs under `test/goldens/`, matching whatever path `matchesGoldenFile('goldens/…')` resolves relative to the test file), `packages/koel_widgets/dart_test.yaml` (golden tag), `packages/koel_widgets/.api-baseline/koel_widgets.json`, `packages/koel_widgets/example/` (`pubspec.yaml`, `analysis_options.yaml`, `lib/main.dart`, `test/example_smoke_test.dart`).
- **Modified:** `lib/koel_widgets.dart` (dartdoc only), `analysis_options.yaml` (doc gate), `tool/test_package.sh` + `tool/coverage.sh` (`,golden` exclusion), root `pubspec.yaml` (`workspace:` += example, `test:coverage` += koel_widgets line), `.github/workflows/ci.yml` (+`goldens` +`example-smoke` jobs). Backfill `///` on `lib/src/bubble/{material,cupertino}_bubble.dart` as the doc gate requires.
- **Untouched:** every `lib/src/**` widget *behavior*, `koel_core`/`koel_flutter`/other-package source, `perf-bench.yml`/`api-diff.yml`. No new public symbol. [Source: architecture.md:916-928 koel_widgets layout; 6-8 File List shape]

### References

- [Source: _bmad-output/planning-artifacts/epics/epic-7-widget-primitives-theming-koelwidgets.md#Story-7.4] — the 4 epic ACs (barrel exact-7 + apitool; goldens × variant × theme on Linux + test/goldens committed; example via `MockAgent.fromFixture('text_only_run')` + CI smoke §6; coverage ≥80% + analyze 0).
- [Source: _bmad-output/implementation-artifacts/7-3-chat-input-follow-up-list.md] — 8-symbol complete set; "7.4 seals, adds no new symbol"; goldens/example/seal deferred here; the `resolveKoelTheme`/`_SubmitTextIntent`/pill internals that stay unexported.
- [Source: _bmad-output/implementation-artifacts/6-8-memory-streaming-jank-baselines.md] — the koel_flutter SEALER pattern: doc gate (`public_member_api_docs`+`comment_references`, no `plugins:`), `dart_apitool 0.23.1` global extract on a Flutter package (no `--force-use-flutter`), coverage.sh flutter-branch (line-gate), "do NOT touch perf-bench.yml/api-diff.yml".
- [Source: _bmad-output/implementation-artifacts/2-15-perf-baselines-dartdoc-barrel.md] — original sealer template: barrel-final-then-extract; `.api-baseline/<pkg>.json` path; coverage wiring into root `test:coverage`.
- [Source: packages/koel_flutter/analysis_options.yaml:14-39] — the exact doc-gate file to mirror (include list + `analyzer.exclude` + `linter.rules`).
- [Source: tool/coverage.sh:35-52] — `coverage.sh <pkg> <line> <branch> [with_chrome]`; `grep "sdk: flutter"` → `flutter test --coverage --exclude-tags=perf` branch.
- [Source: tool/test_package.sh:39-41; packages/koel_flutter/dart_test.yaml] — the `--exclude-tags=perf` Flutter routing + the tag-declaration pattern to copy for `golden`.
- [Source: .github/workflows/ci.yml:56-95] — the `flutter-smoke` job to mirror for the `goldens` + `example-smoke` lanes (subosito/flutter-action@v2, flutter 3.44.0, melos bootstrap+build).
- [Source: packages/koel_flutter/lib/src/controller/koel_chat_controller.dart:24-68; packages/koel_core/lib/src/client/koel_client.dart:153] — `KoelChatController({required ChatSession session})`, `ChangeNotifier`, `state`/`isStreaming`/`send`/`cancel`/`clear`/`dispose`; `KoelClient.newSession()`.
- [Source: packages/koel_test/lib/src/mock_agent.dart:52-55] — `static Future<MockAgent> fromFixture(String name)`; fixture `text_only_run.jsonl` exists under `koel_test/lib/src/fixtures/synthesized/`.
- [Source: _bmad-output/planning-artifacts/architecture.md:676-689] — "one `example/` per package … `flutter run example/lib/main.dart` … Smoke-tested in CI: every example compiles and … runs to completion without throwing" (§6 convention AC2 names).
- [Source: root pubspec.yaml:8-19,32-42] — `workspace:` member list (add the example); `melos.scripts.test:coverage` (add the koel_widgets line).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Flutter Engineer persona via `/agent-flutter-engineer`).

### Debug Log References

- Linux golden generation: `docker run --rm -v "$PWD":/app ghcr.io/cirruslabs/flutter:3.44.0 … flutter test --update-goldens --tags golden` → 10/10 passed (exit 0). pubspec.lock 0-drift after the container's `flutter pub get`.
- Example smoke FIRST run failed: `UnsupportedError: Isolate.resolvePackageUriSync` from `FixtureLoader._load` (fixture_loader.dart:140) under `flutter test` → resolved by the fromFixture→programmatic substitution (see Completion Note D1).

### Completion Notes List

**Outcome:** koel_widgets is SEALED. 8-symbol barrel verified-final, `public_member_api_docs` doc gate green, 10 Linux-canonical goldens, `dart_apitool` baseline committed, ≥80% coverage wired (actual **line 100%, 248/248**), runnable `example/`. All gates green; 0 new lib logic; 0 new public symbol; 0 new hosted dep; pubspec.lock 0-drift (AI-5.9 pins held).

**Key decisions / deviations (FYI-to-Si):**

- **D1 — example uses `MockAgent.programmatic`, NOT `MockAgent.fromFixture('text_only_run')` (deviation from AC5's literal idiom).** `FixtureLoader._load` resolves its asset via `Isolate.resolvePackageUri` (fixture_loader.dart:140) — a `dart:io`/VM-only path that throws `UnsupportedError: Isolate.resolvePackageUriSync` under `flutter test` (flutter_tester), and has no resolvable `File` in a compiled Flutter app either (the `.jsonl` is a Dart-lib asset, not a Flutter asset-bundle entry). So `fromFixture` is a dart-test-only loader — unusable by both the example app's runtime and its required §6 smoke test. The example replays the **same** sequence via `MockAgent.programmatic().runStarted().textMessage('Hello, world!').runFinished().build()` (RUN_STARTED → assistant "Hello, world!" → RUN_FINISHED) — behaviorally identical, deterministic, runs under `flutter test` AND `flutter run`. **Precedent:** Stories 6.1 and 6.7 made the identical fromFixture→programmatic substitution for exactly this `dart:io`/Isolate constraint (6.7: "mock_agent.dart transitively imports dart:io … fails the dart2js web compile"). koel_test stays a dep (`MockAgent.programmatic` is from koel_test), so the example still demonstrates koel_test integration. Parity-decided, recorded per `parity_decides_ambiguous_api`; no question bounced to Si.
- **D2 — goldens generated on Linux via Docker (`ghcr.io/cirruslabs/flutter:3.44.0`), committed as the canonical bytes.** Dev machine is macOS; macOS-rendered bytes would false-fail the Linux `goldens` CI lane (rounded-corner AA differs per OS). Verified the test logic renders on macOS (`--update-goldens`), then **discarded macOS bytes and committed Linux bytes**. All 10 goldens captured on a fixed small viewport (capturing the app root) for stable, compact PNGs.
- **D3 — native `matchesGoldenFile`, no harness dep** (as the story's Dev Notes pre-decided): zero new dependency (golden_toolkit archived; alchemist pulls a transitive analyzer → AI-5.9 drift risk).
- **D4 — doc gate backfill was minimal:** `public_member_api_docs` fired on **nothing** (every public member documented as-it-went per the 7.1–7.3 habit). Only `comment_references` fired — on the `[MessageBubble]` cross-reference in `material_bubble.dart`/`cupertino_bubble.dart` (importing `MessageBubble` there would be a cycle) → demoted both to plain `` `MessageBubble` `` code-spans (the 6.8 demote-broken-comment-ref pattern). `MaterialBubble`/`CupertinoBubble` and their members were already fully documented in 7.2.
- **D5 — `dart_apitool 0.23.1` extracted the Flutter package with NO `--force-use-flutter`** (verified, matching 6.8). Baseline froze exactly the 8 symbols (version 3, packageName koel_widgets); committed to `.api-baseline/koel_widgets.json`. The `api-diff.yml` diff gate stays Epic 9 (9-3).

**Test/coverage notes:** koel_widgets widget tests are **42** (story said 41 — 7.3's code-review added the `maxLines>=1` assertion test; not 41), all green, 10 goldens tag-excluded from the default/coverage runs. Example smoke: 1 test, green. Coverage line **100% (248/248)**, branch 100% (0 BRDA → defaults 100; line is the gate), ≥ 80% floor.

**Gate block (all green):**
- `melos run format:check` → 0-changed (206 files; the 3 golden test files + 2 example files auto-formatted first)
- `melos run analyze` → SUCCESS across all packages incl. the new doc gate + asp plugin
- `melos run test` → SUCCESS (koel_widgets 42, koel_flutter 74 unchanged, koel_lints 5; goldens excluded by tag)
- `tool/coverage.sh packages/koel_widgets 80 80` → line 100.00% ≥ 80%
- example smoke (`flutter test` in `example/`) → All tests passed
- Linux goldens (`flutter test --tags golden` in the 3.44.0 container) → 10/10 passed
- `pubspec.lock` → 0-drift (AI-5.9 analyzer/freezed pins held after the example workspace member + all `flutter pub get`s)

### File List

**New:**
- `packages/koel_widgets/dart_test.yaml` (golden tag declaration)
- `packages/koel_widgets/.api-baseline/koel_widgets.json` (dart_apitool baseline, 8 symbols)
- `packages/koel_widgets/test/goldens/message_bubble_golden_test.dart`
- `packages/koel_widgets/test/goldens/chat_input_golden_test.dart`
- `packages/koel_widgets/test/goldens/follow_up_list_golden_test.dart`
- `packages/koel_widgets/test/goldens/*.png` (10 Linux-rendered goldens: message_bubble_{material,cupertino}_{light,dark}, chat_input_{light,dark,fallback}, follow_up_list_{light,dark,fallback})
- `packages/koel_widgets/example/pubspec.yaml`
- `packages/koel_widgets/example/analysis_options.yaml`
- `packages/koel_widgets/example/lib/main.dart`
- `packages/koel_widgets/example/test/example_smoke_test.dart`

**Modified:**
- `packages/koel_widgets/lib/koel_widgets.dart` (library dartdoc → past-tense "sealed"; no export change)
- `packages/koel_widgets/analysis_options.yaml` (+`public_member_api_docs`/`comment_references` doc gate + `analyzer.exclude`)
- `packages/koel_widgets/lib/src/bubble/material_bubble.dart` (`[MessageBubble]` → code-span)
- `packages/koel_widgets/lib/src/bubble/cupertino_bubble.dart` (`[MessageBubble]` → code-span)
- `tool/test_package.sh` (`--exclude-tags=perf` → `perf,golden`)
- `tool/coverage.sh` (`--exclude-tags=perf` → `perf,golden`)
- `pubspec.yaml` (workspace += `packages/koel_widgets/example`; test:coverage += koel_widgets 80 80)
- `.github/workflows/ci.yml` (+`goldens` Linux lane, +`example-smoke` Linux lane)

## Change Log

| Date       | Change |
| ---------- | ------ |
| 2026-06-06 | Story created via `/bmad-create-story` — koel_widgets SEALER (7.4). Verify-seal 8-symbol barrel + `public_member_api_docs` doc gate + native `matchesGoldenFile` goldens (Linux-canonical, tag-gated) + `dart_apitool 0.23.1` baseline + ≥80% coverage wiring + `example/` app (`MockAgent.fromFixture('text_only_run')` → `KoelChatController`) + Linux `goldens`/`example-smoke` CI lanes. No new lib logic, no new public symbol, no new dep. Decisions recorded: native goldens (no alchemist/golden_toolkit — AI-5.9 drift + archived); Linux-canonical bytes via Docker/CI `--update-goldens`; example as workspace member (0 lock drift). Status → ready-for-dev. |
| 2026-06-06 | `/bmad-code-review` — 3-layer adversarial review (Blind Hunter, Edge Case Hunter, Acceptance Auditor). 0 decision-needed, 2 patch, 0 defer, 10 dismissed as noise. All 7 ACs substantively satisfied. The Medium "smoke-test double-disposes the session" finding was a **false positive** (source-verified: `KoelChatController.dispose` never disposes the session; `KoelClient.dispose` does; `ChatSession.dispose` is `isClosed`-guarded ⇒ idempotent). The 2 patches are reference-quality polish on the new `example/` (lifecycle ownership + CI analyze enforcement), not runtime bugs. See Review Findings below. |
| 2026-06-06 | `/bmad-dev-story` — koel_widgets SEALED. Barrel verified-final (8 symbols, dartdoc → "sealed") + doc gate green (only 2 `[MessageBubble]` comment-refs demoted to code-spans; `public_member_api_docs` fired on nothing) + 10 Linux-canonical goldens (generated via `cirruslabs/flutter:3.44.0` Docker, native `matchesGoldenFile`, tag-gated) + `dart_apitool 0.23.1` baseline (8 symbols, no `--force-use-flutter`) + coverage wired (actual **line 100% 248/248** ≥ 80) + runnable `example/` (workspace member, 0 lock drift) + Linux `goldens`/`example-smoke` CI lanes. **D1 deviation:** example uses `MockAgent.programmatic` not `fromFixture` — `FixtureLoader` uses `Isolate.resolvePackageUri` (VM/dart:io-only, throws under flutter_tester); same fromFixture→programmatic substitution Stories 6.1/6.7 made; replays the identical `text_only_run` sequence. All gates green: format:check 0-changed (206), analyze SUCCESS (all pkgs + doc gate + asp), test SUCCESS (koel_widgets 42 + example smoke; goldens tag-excluded), pubspec.lock 0-drift (AI-5.9 pins held). Status → review. |

## Review Findings

_Code review 2026-06-06 — 3-layer adversarial (Blind Hunter / Edge Case Hunter / Acceptance Auditor). 0 decision-needed, 2 patch, 0 defer, 10 dismissed as noise. Both patches are reference-quality polish on the brand-new `example/` (no runtime bug, all gates remain green)._

- [x] [Review][Patch] (APPLIED) `example/` should own its controller+client lifecycle at the root, not dispose an **injected** controller from a child screen [packages/koel_widgets/example/lib/main.dart] — `main()` creates `KoelClient`+`KoelChatController` and hands them down; `_ChatScreenState.dispose()` then disposes the *injected* controller (an anti-pattern for the consumer-facing reference — a consumer copying it into a multi-screen app where the controller is shared gets a use-after-dispose), while nothing ever disposes the `KoelClient`/`ChatSession` (a leak on a real `flutter run`; harmless only because the single screen never pops and the process reclaims at exit). Fix: make `KoelWidgetsExampleApp` a `StatefulWidget` that creates the client+controller in `initState` and disposes **both** (controller then client) in `dispose`; `main()` → `runApp(const KoelWidgetsExampleApp())`. This also lets the §6 smoke pump the real root, exercising `main()`'s actual composition path (closes the Blind+Auditor "main() unsmoked" note). [blind+edge+auditor]
- [x] [Review][Patch] (APPLIED) `example-smoke` CI lane never analyzes the example — its `analysis_options.yaml` is unenforced [.github/workflows/ci.yml] — the example is not a melos package, so `melos run analyze` skips it and the lane runs only `flutter test`; a lint/doc regression in `example/lib/main.dart` ships undetected despite the example carrying its own curated lint profile. Fix: add a `dart analyze` step before `flutter test` in the `example-smoke` job (`working-directory: packages/koel_widgets/example`). [blind+edge]

_Dismissed (10): smoke-test double-dispose (false positive — controller never disposes session; `ChatSession.dispose` is `isClosed`-guarded); smoke `findsWidgets` flake (false positive — `send` emits the user message synchronously); CI lanes re-run setup with no `needs:` (matches the established `flutter-smoke` precedent, by design); goldens-lane exit-79 if zero golden tests (speculative future state — 3 golden files exist today); `--exclude-tags=perf,golden` unscoped across Flutter packages (intentional, mirrors how `perf` is already unscoped, inert elsewhere); golden single-frame `pumpWidget` (widgets are animation-free; single-frame is the correct deterministic choice with an unfocused cursor); Cupertino bubble golden hosted in `MaterialApp` (intentional per story design — `KoelTheme` drives the text tokens, host type is immaterial); `comment_references` conversion completeness (self-declared confirmation, all refs resolve); story prose "41 tests" vs actual 42 (already self-corrected in the Dev Agent Record); Linux-byte provenance unverifiable from diff (self-correcting — the Linux `goldens` lane is the real verifier)._
