---
baseline_commit: 3bfd18686bca3534a55a90957430d4d239bb2f88
---

# Story 7.2: MessageBubble (Material 3 + Cupertino variants)

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter developer,
I want `MessageBubble` rendering a chat message with role-aware styling for both Material 3 and Cupertino design languages, reading `KoelTheme` for tokens,
so that I can drop a bubble into my Flutter app and have it match the platform's design language per FR-E3.

## Acceptance Criteria

1. **Class shape + platform auto-pick.** In `packages/koel_widgets/lib/src/bubble/message_bubble.dart`, `class MessageBubble extends StatelessWidget` accepts a `koel_core` `Message` (positional, `required`) plus an optional `BubbleStyle? style` override. With no `style`, the variant is picked from `Theme.of(context).platform` — `iOS`/`macOS` ⇒ Cupertino, every other `TargetPlatform` ⇒ Material 3. A non-null `style` (`BubbleStyle.material | BubbleStyle.cupertino`) forces that variant regardless of platform. `enum BubbleStyle { material, cupertino }` is declared in the same library and exported (it is part of `MessageBubble`'s public contract — see Dev Notes → "Barrel").

2. **Material variant.** In `bubble/material_bubble.dart`, the Material variant paints with M3 surface tokens: the role-selected bubble fill (`KoelColors.messageBubbleUser` / `messageBubbleAssistant`), readable text via the paired `onMessageBubble*` slot, rounded corners, tonal elevation (a `Material`/`Card`-grade surface, not a flat `Container`), and `KoelSpacing.bubblePadding` inner padding. Imports `package:flutter/material.dart`.

3. **Cupertino variant.** In `bubble/cupertino_bubble.dart`, the Cupertino variant uses an iOS-style background (same role-selected `KoelColors` slots), standard iOS bubble padding (`KoelSpacing.bubblePadding`), iOS-idiomatic corner rounding, and the system font (no Material elevation/ripple). Imports `package:flutter/cupertino.dart` (not `material.dart`).

4. **Mixed-segment rendering.** Given a `Message` whose `content` carries mixed prose + fenced code blocks, the bubble parses it once via `const MessageContentParser().parse(message.content)` (Story 6.5) and renders the ordered `List<MessageSegment>` with an **exhaustive `switch` carrying a `default:` arm** (koel_lints `exhaustive_switch_must_have_default`): a `TextSegment` renders with `KoelTextStyles.bodyText`; a `CodeBlockSegment` renders its `code` body in `KoelTextStyles.codeText` (monospace) on a `KoelColors.codeBlockBackground` surface. Both variants share one segment-rendering path (no duplicated parse/switch per variant).

5. **Role mapping + null-`KoelTheme` resilience (leave the system working end-to-end).** The bubble selects slots by role: `message.role == MessageRole.user` ⇒ user slots (`messageBubbleUser`/`onMessageBubbleUser`), every other role (`assistant`/`system`/`tool`) ⇒ assistant slots. When `Theme.of(context).extension<KoelTheme>()` is **null** — the real case under a bare `CupertinoApp`, which inserts no Material `Theme` extension (see Dev Notes → "The Cupertino theming gap") — the bubble falls back to a brightness-appropriate `KoelTheme.light()`/`KoelTheme.dark()` default rather than throwing. The bubble renders for any `MessageRole` under any host app (`MaterialApp` or `CupertinoApp`).

6. **Tests + gates (goldens deferred to 7.4).** `test/bubble/message_bubble_test.dart` uses `WidgetTester`/`pumpWidget` to assert, via widget-tree inspection (not pixels): platform auto-pick (pump under `ThemeData(platform: …)` and a forced `style:`), role-driven slot selection, mixed text+code segment rendering (the code block uses `codeText`/`codeBlockBackground`), and the null-extension fallback (pump with no `KoelTheme` ⇒ no throw, renders). `MessageBubble` + `BubbleStyle` are reachable through `package:koel_widgets/koel_widgets.dart`. `dart analyze` exits 0 under the curated Flutter profile. **Golden tests are NOT in this story** — every primitive's goldens (Material/Cupertino × light/dark) are centralized in Story 7.4 on the deterministic Linux CI lane; 7.2's job is to make the widgets golden-*ready* (deterministic, theme-driven, no time/random inputs). See Dev Notes → "Goldens: deferred to 7.4 (variance from epic AC4)".

## Tasks / Subtasks

- [x] **Task 1 — Add the first cross-package dependencies (AC: #1, #4)**
  - [x] In `packages/koel_widgets/pubspec.yaml` add to `dependencies:` two bare workspace keys (mirror `koel_flutter/pubspec.yaml:17` `koel_core:`): `koel_core:` (for `Message`, `MessageRole`) and `koel_flutter:` (for `MessageContentParser`, `MessageSegment`, `TextSegment`, `CodeBlockSegment`). These are koel_widgets' first intra-repo deps — keep it to exactly these two (counter-metric CM-3); do **not** add `koel_test` (the widget tests construct `Message` literals directly, no agent/fixtures needed).
  - [x] `Message` is **not** re-exported by `koel_flutter` (its barrel deliberately re-exports nothing from `koel_core`), so the direct `koel_core` import is mandatory — a `koel_flutter`-only dep would not surface `Message`/`MessageRole`. [Source: packages/koel_flutter/lib/koel_flutter.dart header]
  - [x] Run `flutter pub get` (or `melos bootstrap`); confirm `pubspec.lock` has **0 drift** to the AI-5.9 pins (`analyzer 12.1.0` / `freezed 3.2.6-dev.1`) — both new deps are workspace path packages, so no hosted lock entries are added.

- [x] **Task 2 — `BubbleStyle` + `MessageBubble` dispatcher (AC: #1, #4, #5)**
  - [x] Create `packages/koel_widgets/lib/src/bubble/message_bubble.dart` with `import 'package:flutter/widgets.dart';` (the dispatcher needs neither `material` nor `cupertino` directly — it delegates), `import 'package:koel_core/koel_core.dart';` (`Message`, `MessageRole`), `import 'package:koel_flutter/koel_flutter.dart';` (parser + segments), and parts/imports for the two variant files.
  - [x] `enum BubbleStyle { material, cupertino }` — the explicit override surface.
  - [x] `class MessageBubble extends StatelessWidget` — `const MessageBubble(this.message, {this.style, super.key});` with `final Message message;` and `final BubbleStyle? style;`. (`use_key_in_widget_constructors` + `prefer_const_constructors_in_immutables` are live — supply the `super.key` and keep the ctor `const`.)
  - [x] In `build`: (a) resolve the theme once — `final koel = Theme.of(context).extension<KoelTheme>() ?? _fallbackTheme(context);` (see Task 5 for `_fallbackTheme`); (b) `final isUser = message.role == MessageRole.user;`; (c) parse once — `final segments = const MessageContentParser().parse(message.content);`; (d) pick the variant — `final useCupertino = style == BubbleStyle.cupertino || (style == null && _isApple(Theme.of(context).platform));` — and return `CupertinoBubble(...)` or `MaterialBubble(...)`, threading `segments`, the resolved `koel`, and `isUser`.
  - [x] `bool _isApple(TargetPlatform p) => p == TargetPlatform.iOS || p == TargetPlatform.macOS;` — keep the platform predicate in one place.

- [x] **Task 3 — Shared segment rendering (AC: #4)**
  - [x] Factor the segment `switch` into **one** shared builder both variants call (e.g. a private `Widget _segmentColumn(List<MessageSegment> segments, KoelTheme koel)` or a small `_MessageBody` widget) so the parse-and-switch logic is not duplicated across `material_bubble.dart` and `cupertino_bubble.dart`. Put it where both variant files can reach it without re-exporting (a `part` of `message_bubble.dart`, or a private `_message_body.dart` imported by both — pick the lighter wiring).
  - [x] The `switch` over the sealed `MessageSegment`: `TextSegment(:final text)` ⇒ `Text(text, style: koel.textStyles.bodyText.copyWith(color: onSlot))`; `CodeBlockSegment(:final code)` ⇒ a code surface (`DecoratedBox`/`Container` with `koel.colors.codeBlockBackground`, padded) wrapping `Text(code, style: koel.textStyles.codeText)`; plus a `default:` arm returning `const SizedBox.shrink()` (forward-compat: a future `MessageSegment` leaf degrades to empty, never crashes — the same forward-compat policy as `koel_flutter`'s consumers). Pattern-match with Dart 3 destructuring, not `is`-chains.
  - [x] The text colour on prose comes from the role's `onMessageBubble*` slot (passed down); the code block's own foreground is `codeText`'s colour (palette-agnostic geometry + an explicit colour — confirm `codeText` carries a readable colour against `codeBlockBackground`, else apply the role `on*` slot to it too). Record the choice in the Dev Agent Record.

- [x] **Task 4 — Material + Cupertino variants (AC: #2, #3)**
  - [x] `bubble/material_bubble.dart` — `import 'package:flutter/material.dart';`. Internal widget (`class MaterialBubble extends StatelessWidget`, public-but-**not-exported**). Role-selected fill, `Material`/`Card`-grade tonal surface with rounded corners + tonal elevation, `bubblePadding` inner padding, alignment by role (user trailing / assistant leading is the conventional chat layout — apply via `Align`/`Row` mainAxisAlignment). Renders the shared segment body.
  - [x] `bubble/cupertino_bubble.dart` — `import 'package:flutter/cupertino.dart';`. Internal widget (`class CupertinoBubble extends StatelessWidget`, not exported). Role-selected fill on an iOS-style rounded container (no Material elevation/ripple), `bubblePadding`, system font (Cupertino default text), role alignment. Renders the same shared segment body.
  - [x] Both variants are `StatelessWidget` with `const` ctors + `super.key`. No `setState`, no controllers, no animation — a bubble is pure render of immutable inputs. Keep allocations `const` where the analyzer permits (`prefer_const_constructors`).

- [x] **Task 5 — `KoelTheme` resilience + `codeText` Apple-monospace hardening (AC: #5; resolves 7.1 deferred review)**
  - [x] Add the `_fallbackTheme(BuildContext)` helper used in Task 2: return `KoelTheme.dark()` when the ambient brightness is dark, else `KoelTheme.light()`. Source brightness defensively — `Theme.of(context).brightness` is always defined (even from the fallback `ThemeData` a bare `CupertinoApp` yields); optionally prefer `CupertinoTheme.maybeBrightnessOf(context)` when present. Keep it a single private top-level function in `message_bubble.dart`.
  - [x] **Harden `codeText` for Apple platforms (deferred from the 7.1 code review).** `KoelTextStyles.codeText` currently sets `fontFamily: 'monospace'` ([koel_theme.dart:223]) — a real family on Android/Linux/web but a **silent fallback to the proportional default on iOS/macOS** (where there is no family literally named `monospace`). Add `fontFamilyFallback: const ['Menlo', 'Courier', 'monospace']` (or equivalent) to the `_defaultTextStyles.codeText` in `koel_theme.dart` so the Cupertino variant actually renders monospace. This is a `KoelTheme` (7.1 surface) edit — in scope for 7.2 because 7.2 is the story that first *renders* code blocks. Update the 7.1 unit test only if it asserts on `codeText`'s family; keep all 15 existing theme tests green.

- [x] **Task 6 — Surface via the barrel (AC: #1, #6)**
  - [x] In `lib/koel_widgets.dart` add a sectioned `export 'src/bubble/message_bubble.dart' show MessageBubble, BubbleStyle;` (incremental growth — match the 7.1 banner style). Export **only** `MessageBubble` + `BubbleStyle`; do **not** export `MaterialBubble`/`CupertinoBubble` (internal variants).
  - [x] **Variance flag for 7.4:** the epic's 7.4 barrel-seal list ("exactly: `MessageBubble, ChatInput, FollowUpList, KoelTheme, KoelColors, KoelTextStyles, KoelSpacing`") omits `BubbleStyle`, but `BubbleStyle` appears in `MessageBubble`'s public constructor and therefore *must* be exported for the `style:` override to be nameable. Record in the Dev Agent Record that 7.4's seal set is 8 symbols (the 7 + `BubbleStyle`), not 7.

- [x] **Task 7 — Widget tests (AC: #6)**
  - [x] Create `packages/koel_widgets/test/bubble/message_bubble_test.dart` with `package:flutter_test/flutter_test.dart`, importing the widget via `package:koel_widgets/koel_widgets.dart` (doubles as a barrel-export assertion). Construct `Message` literals directly (`Message(id: 'm1', role: MessageRole.user, content: '…', timestamp: DateTime.utc(2020))`).
  - [x] **Platform auto-pick:** pump under `MaterialApp(theme: ThemeData(platform: TargetPlatform.iOS, extensions: [KoelTheme.light()]))` ⇒ Cupertino variant in tree (`find.byType(CupertinoBubble)` — variants are visible to same-package tests); `TargetPlatform.android` ⇒ Material variant; explicit `style: BubbleStyle.material` under iOS ⇒ Material (override wins).
  - [x] **Role mapping:** a `user` message paints `messageBubbleUser`; an `assistant`/`system`/`tool` message paints `messageBubbleAssistant` (assert by finding the painted colour in the tree, e.g. via the variant's fill `Container`/`DecoratedBox`).
  - [x] **Mixed segments:** content `'before\n```dart\nx()\n```\nafter'` ⇒ two `Text` widgets in `bodyText` + one in `codeText` on `codeBlockBackground`; assert the code `Text` uses `codeText` and sits on the code surface.
  - [x] **Null-extension fallback:** pump the bubble under a `CupertinoApp` (no Material `Theme`/extension) ⇒ no exception, the bubble renders (the AC5 contract); assert it picked a fallback default (e.g. a known light-default colour present).
  - [x] Keep tests deterministic (fixed `Message`, no `DateTime.now()`, no randomness) so 7.4 can wrap the same widgets in goldens without flakiness.

- [x] **Task 8 — Gate locally before marking done**
  - [x] `dart format` (committed sources 0-changed under `melos format:check`).
  - [x] `dart analyze` in `koel_widgets` exits 0 (curated Flutter rules + asp plugin); expect `prefer_const_constructors`, `use_key_in_widget_constructors`, `depend_on_referenced_packages` (the last is *why* `koel_core` must be a direct dep) to fire if any are missed.
  - [x] `flutter test` in `koel_widgets` green (new bubble tests + the 15 existing theme tests). Repo-wide `melos test` SUCCESS.

### Review Findings

_From `/bmad-code-review` (2026-06-06) — Blind Hunter + Edge Case Hunter + Acceptance Auditor. 11 findings dismissed as noise/false-positive/out-of-scope. All 6 ACs PASS; `dart analyze` verified exit 0._

- [x] [Review][Patch] Suppress empty-content bubble (D1 resolved → patch) — when `parse(content)` yields no segments (e.g. an assistant-with-tool-calls turn with `content == ''`), return `const SizedBox.shrink()` instead of painting an empty padded pill; add a widget test for the empty-content path. [message_bubble.dart build()] — APPLIED: early `if (segments.isEmpty) return const SizedBox.shrink();` + `empty content` test group (26 tests total).
- [x] [Review][Patch] Stale theme-test count in Task 5 prose — says "16 existing theme tests" but actual count is 15 (Debug Log arithmetic and Completion Notes already use 15). [7-2-message-bubble.md Task 5 + Task 8] — APPLIED: "16" → "15" in Task 5 + Task 8.
- [x] [Review][Defer] No bubble max-width + long unbreakable code clips horizontally — deferred to 7.4 (the SEALER story owns layout polish + goldens on the Linux lane; spec scopes no max-width into 7.2). [message_bubble.dart `_codeBlock`; material_bubble.dart / cupertino_bubble.dart]

## Dev Notes

### What this story is — and is NOT

- **IS:** the first *rendering* widget of `koel_widgets` and the first consumer of `KoelTheme`. `MessageBubble` is a pure `StatelessWidget` that reads an immutable `Message`, resolves `KoelTheme` from context, parses content into segments, and paints one of two design-language variants. It introduces koel_widgets' first cross-package deps (`koel_core` + `koel_flutter`).
- **IS NOT:** goldens, the example app, or the barrel *seal* / `public_member_api_docs` doc gate — all deferred to **Story 7.4** (the koel_widgets SEALER), exactly as 7.1 deferred them and as `koel_flutter` deferred its doc gate + `dart_apitool` baseline to 6.8. It is also NOT `ChatInput`/`FollowUpList` (7.3). [Source: epics/epic-7…#Story-7.4; 7-1-koel-theme.md Dev Notes]

### The data the bubble renders (read before coding)

- **`Message`** (`koel_core`, freezed) — `{ String id; MessageRole role; String content; DateTime timestamp; String? toolCallId; String? name; }`. `role ∈ {user, assistant, system, tool}`. `content` is the already-decoded assistant/user text (an assistant-with-tool-calls turn can have `content == ''`). The bubble reads only `role` + `content`; it does **not** render `timestamp` (epic AC names no timestamp — no `caption`/timestamp text-style slot is needed, so do not add one). [Source: packages/koel_core/lib/src/message/message.dart:31-52]
- **`MessageContentParser.parse(String)`** (`koel_flutter`, Story 6.5) — a **total pure function**, `const`-constructible, returns `List<MessageSegment>` with strictly alternating, non-empty `TextSegment`s and `CodeBlockSegment`s; empty input ⇒ `const []`. Only a line starting (after ≤3 spaces) with ≥3 backticks opens a fence; inline `` `code` `` stays prose. The bubble must not re-implement any of this — call `parse` and switch. [Source: packages/koel_flutter/lib/src/message/message_content_parser.dart:24-99]
- **`MessageSegment`** is `sealed` with exactly two leaves: `TextSegment { String text }` and `CodeBlockSegment { String language; String code }`. The `switch` over it MUST carry a `default:` arm — `koel_lints`' `exhaustive_switch_must_have_default` enforces it (the same forward-compat seam tested in `koel_flutter/test/message/exhaustive_switch_lint_test.dart`). Use Dart-3 destructuring patterns (`TextSegment(:final text)`), not `is`-chains. [Source: packages/koel_flutter/lib/src/message/message_segment.dart:14-26; text_segment.dart; code_block_segment.dart]

### `KoelTheme` is already fully slotted for this bubble — add no new slots

Story 7.1 deliberately pre-built every slot `MessageBubble` consumes (recorded as a one-way-door decision): `KoelColors.{messageBubbleUser, messageBubbleAssistant, onMessageBubbleUser, onMessageBubbleAssistant, codeBlockBackground}`, `KoelTextStyles.{bodyText, codeText}`, `KoelSpacing.bubblePadding`. **Do not add `KoelColors`/`KoelTextStyles`/`KoelSpacing` slots in 7.2** — the bubble is fully served. The *only* `KoelTheme` edit in scope is the `codeText` `fontFamilyFallback` hardening (Task 5), which changes a default value, not the slot set, so no `copyWith`/`lerp`/equality plumbing changes and the 16 theme tests stay structurally valid. [Source: packages/koel_widgets/lib/src/theme/koel_theme.dart:13-217; 7-1-koel-theme.md Completion Notes "Slot-set decisions"]

### The Cupertino theming gap (load-bearing — why AC5 exists)

`ThemeExtension` is a **Material** concept: it lives on `ThemeData.extensions` and is read via `Theme.of(context).extension<KoelTheme>()`. `CupertinoThemeData` has **no** `extensions` field, and a bare `CupertinoApp` wraps its subtree in a `CupertinoTheme`, **not** a Material `Theme` — verified in Flutter source: `CupertinoApp._buildWidgetApp` builds `CupertinoUserInterfaceLevel → CupertinoTheme → DefaultSelectionStyle → …`, no Material `Theme`. [Source: `flutter/packages/flutter/lib/src/cupertino/app.dart:667-676`]

Consequence: under a pure `CupertinoApp`, `Theme.of(context)` returns a default fallback `ThemeData` (it does not throw), and `.extension<KoelTheme>()` is **null**. FR-E4 says "attach to MaterialApp/CupertinoApp theme," but a Cupertino-only consumer literally cannot hang `KoelTheme` off `CupertinoApp.theme`. So the bubble MUST tolerate a null extension and fall back to a brightness-appropriate `KoelTheme.light()`/`.dark()` default — otherwise the Cupertino variant (the whole point of 7.2) crashes in the exact app type it targets. This is the "leave the system working end-to-end" requirement, not a nice-to-have. (A consumer *can* still theme a Cupertino app by wrapping the subtree in a Material `Theme(data: ThemeData(extensions: [KoelTheme…]))`; document that as the supported Cupertino theming path in 7.4's finalize docs, not here.)

### Platform pick: `Theme.of(context).platform`, not `defaultTargetPlatform`

AC1 names `Theme.of(context).platform` deliberately: it is overridable per-subtree via `ThemeData(platform: …)`, which is exactly how the widget tests force iOS vs Android without running on those devices. `defaultTargetPlatform` is process-global and not test-overridable per pump — do not use it. Apple set = `{iOS, macOS}` ⇒ Cupertino; everything else ⇒ Material. The explicit `style:` override short-circuits the platform read.

### Goldens: deferred to 7.4 (variance from epic AC4 — decided, recorded)

Epic 7.2's fourth AC lists "4 goldens minimum (material-light/dark, cupertino-light/dark)". **This story does not ship goldens** — a deliberate, project-consistent variance:
- Story 7.1 already established "goldens deferred to 7.4" and sprint-status records it; Story 7.4 is *titled* "Widget tests + golden tests + barrel + example demo" and its AC owns "golden tests covering **every** primitive × Material/Cupertino × light/dark … on the **Linux CI lane** (deterministic platform for goldens)."
- Goldens are font/AA/platform-sensitive and require a single deterministic lane plus golden-infra setup (`loadAppFonts`, golden file management, CI wiring). Standing that up in 7.2, touching it again in 7.3, then sealing in 7.4 is wasted setup and divergence risk. Centralizing all goldens in the dedicated SEALER (7.4) is the lower-risk, lower-waste path and matches the koel_flutter precedent (render-smoke incrementally; finalize gates at the sealer).
- 7.2's obligation is to make the widgets **golden-ready**: deterministic inputs (no `DateTime.now()`/randomness), all visual state driven by `KoelTheme` + `Message` + `BubbleStyle`, no hidden ambient dependencies. The `WidgetTester` behavioral tests in Task 7 prove render correctness structurally (tree/colour/style assertions) without pixel baselines.

There is **no golden dependency** (`golden_toolkit`/`alchemist`) in the workspace today; do not add one in 7.2 — 7.4 chooses the golden harness. *(FYI surfaced to Si in the create-story summary.)*

### API shape (sketch the one-way door first)

```dart
enum BubbleStyle { material, cupertino }

class MessageBubble extends StatelessWidget {
  const MessageBubble(this.message, {this.style, super.key});
  final Message message;          // koel_core
  final BubbleStyle? style;       // null ⇒ pick from Theme.of(context).platform

  @override
  Widget build(BuildContext context) {
    final koel = Theme.of(context).extension<KoelTheme>() ?? _fallbackTheme(context);
    final isUser = message.role == MessageRole.user;
    final segments = const MessageContentParser().parse(message.content);
    final cupertino = style == BubbleStyle.cupertino ||
        (style == null && _isApple(Theme.of(context).platform));
    return cupertino
        ? CupertinoBubble(segments: segments, koel: koel, isUser: isUser)
        : MaterialBubble(segments: segments, koel: koel, isUser: isUser);
  }
}
```

- **Why `StatelessWidget`:** a bubble is a pure function of `(Message, KoelTheme, platform)` — no local state, no controller, no animation. `setState`/`StatefulWidget` here would be the anti-pattern the implement guide refuses.
- **Allocations:** the `const MessageContentParser()` is a shared singleton (zero alloc). `parse` runs in `build` — O(content length), pure, acceptable for committed-message bubbles; do **not** pre-optimize with memoization (no measured cost, no second use case). Keep ctors `const` so element identity holds across rebuilds.
- **Pass parsed `segments` down**, don't re-parse per variant — one parse, one switch, shared body builder (Task 3).

### Package wiring specifics

- `koel_widgets/pubspec.yaml` today has `dependencies: flutter` only and `dev_dependencies: { koel_lints, flutter_test }`. 7.2 adds `koel_core:` + `koel_flutter:` (bare workspace keys, mirroring `koel_flutter`'s `koel_core:` at line 17). First intra-repo deps for the package. [Source: packages/koel_widgets/pubspec.yaml; packages/koel_flutter/pubspec.yaml:12-24]
- `depend_on_referenced_packages` (in the curated profile) will flag a direct `package:koel_core/…` import without a declared `koel_core` dep — that lint is the reason koel_core must be direct, not transitive-via-koel_flutter.
- Curated Flutter lint profile already wired (`analysis_options.yaml` includes `../../analysis_options.yaml` + `package:koel_lints/koel_flutter.yaml`); `public_member_api_docs` is **not** enabled until 7.4. [Source: packages/koel_widgets/analysis_options.yaml]
- `pubspec.lock` must stay pin-stable (no codegen added; both new deps are path packages).

### Documentation

Write a one-line dartdoc on every public member now (`MessageBubble`, its ctor, `message`/`style` fields, `BubbleStyle` + both values). The `public_member_api_docs` gate switches on at 7.4, but document-as-you-go avoids a finalize-time pile — the house pattern (7.1 + koel_flutter 6.1–6.7). Internal `MaterialBubble`/`CupertinoBubble` are unexported, so they are not under the public-doc gate, but a one-line `///` on each still earns its place.

### Testing standards

- Framework: `package:flutter_test/flutter_test.dart` with `WidgetTester`/`pumpWidget` (the first *widget* tests in koel_widgets — 7.1 was pure-data unit tests). Import under test via `package:koel_widgets/koel_widgets.dart`. Same-package tests *can* see the unexported `MaterialBubble`/`CupertinoBubble` via their `src/` paths for `find.byType` assertions — that is fine in tests. [Source: architecture.md §10 NFR-12/13; packages/koel_flutter/test/smoke/six_platform_smoke_test.dart for the pumpWidget idiom]
- Pump pattern: wrap in `MaterialApp(theme: ThemeData(platform: …, extensions: [KoelTheme.light()/dark()]), home: …)` to drive platform + theme; for the null-extension case wrap in `CupertinoApp(home: …)` with no extension.
- Coverage: package ≥ 80% (NFR-12) is enforced at 7.4 finalize via `melos run test:coverage`; for 7.2 cover every public behavior (each variant, role mapping, both segment leaves, the null-extension path) so the package never dips below floor as it grows. [Source: architecture.md:1123-1130; epics/epic-7…#Story-7.4]
- Determinism for 7.4 goldens: fixed `Message` content, `DateTime.utc(2020)` timestamps, no randomness — so 7.4 can wrap these exact widgets in goldens without flakiness.

### Project Structure Notes

- New sources: `packages/koel_widgets/lib/src/bubble/{message_bubble.dart, material_bubble.dart, cupertino_bubble.dart}` — matches the architecture's `koel_widgets/lib/src/bubble/` layout verbatim. [Source: architecture.md:921-924]
- New test: `packages/koel_widgets/test/bubble/message_bubble_test.dart` — mirrors the `koel_flutter` `test/<feature>/…_test.dart` convention.
- Barrel: extend `lib/koel_widgets.dart` (don't rewrite) with the bubble export; the 7.4 seal is 8 symbols (the epic's 7 + `BubbleStyle`).
- Touches only `koel_widgets` (+ no other package's *source*). The only edit outside the new files is the `codeText` `fontFamilyFallback` in the same package's `koel_theme.dart`. No `koel_core`/`koel_flutter` source change.

### References

- [Source: _bmad-output/planning-artifacts/epics/epic-7-widget-primitives-theming-koelwidgets.md#Story-7.2] — story statement + the 4 epic ACs (class shape, M3/Cupertino variants, mixed segments, goldens).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md#F-E3] — Widget Primitives requirement (MessageBubble M3+Cupertino, opt-in).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#A.7] — illustrative `class MessageBubble extends StatelessWidget { ... }` (signature is illustrative; epic ACs bind).
- [Source: _bmad-output/planning-artifacts/architecture.md:916-929] — `koel_widgets/lib/src/bubble/` file layout (message_bubble / material_bubble / cupertino_bubble).
- [Source: packages/koel_core/lib/src/message/message.dart] — `Message` + `MessageRole` shape (the bubble's input).
- [Source: packages/koel_flutter/lib/src/message/message_content_parser.dart + message_segment.dart] — Story 6.5 parser + sealed `MessageSegment`/`TextSegment`/`CodeBlockSegment` the bubble renders.
- [Source: packages/koel_widgets/lib/src/theme/koel_theme.dart] — `KoelTheme` slots already cover the bubble; `codeText` `monospace` at line 223 is the 7.1-deferred hardening target.
- [Source: packages/koel_flutter/test/smoke/six_platform_smoke_test.dart] — `pumpWidget` + `MaterialApp` widget-test idiom to mirror.
- [Source: _bmad-output/implementation-artifacts/7-1-koel-theme.md] — slot-set decisions, deferred review items (`monospace` fallback → 7.2; `inherit`-parity doc → 7.4), goldens-to-7.4 precedent.
- [Source: flutter/packages/flutter/lib/src/cupertino/app.dart:667-676] — CupertinoApp inserts `CupertinoTheme`, not a Material `Theme` (why AC5's null-extension fallback is mandatory).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Claude Opus 4.8, 1M context) via `/bmad-dev-story`; Flutter specialist persona loaded (`agent-flutter-engineer`).

### Debug Log References

- `flutter pub get` (workspace) → `Got dependencies!`; root `pubspec.lock` diff vs baseline = **0 changes** (AI-5.9 pins held — `koel_core`/`koel_flutter` are workspace path deps, no hosted lock entries).
- `dart analyze` (koel_widgets) → first pass surfaced `unreachable_switch_case` ×2 on the segment switch's `_` arm (the koel_lints-mandated forward-compat default vs Dart's "redundant today" view). Reconciled with a targeted `// ignore: unreachable_switch_case` + rationale; re-run → `No issues found!`. Repo-wide `melos analyze` → SUCCESS.
- `flutter test` (koel_widgets) → **25/25 passed** (15 theme unchanged + 10 new bubble). First bubble run had 1 failure: the variant-selection test re-pumped a second `MaterialApp` in one test and the `Navigator` retained the first `home` route → split into fresh single-pump tests, all green.
- `melos format:check` → 196 files, 0 changed. `melos test` → SUCCESS (koel_flutter 74 unchanged, koel_lints 5, all packages green).

### Completion Notes List

- **All 6 ACs satisfied.** `MessageBubble(Message, {BubbleStyle? style})` dispatches by `Theme.of(context).platform` (`{iOS,macOS}`→Cupertino, else Material), `style` overrides; `MaterialBubble` (M3 `Material` surface, elevation 1, r16) and `CupertinoBubble` (flat iOS rounded rect, r18, no elevation) are internal/unexported; mixed segments parse once via `const MessageContentParser()` and render through one shared switch (prose→`bodyText`, code→`codeText` on `codeBlockBackground`); role maps user→user slots, else→assistant slots; null-`KoelTheme` falls back to brightness-appropriate `light()`/`dark()`; barrel exports `MessageBubble`+`BubbleStyle`; analyze 0; 10 widget tests.
- **Faithful deviations from the task sketch (recorded):** (1) the dispatcher imports `package:flutter/material.dart` + `cupertino.dart show CupertinoTheme` (not the sketched bare `widgets.dart`) — it genuinely needs `Theme`/`ThemeData`/`Material`/`ThemeData.estimateBrightnessForColor` (material) and `CupertinoTheme.maybeBrightnessOf` (cupertino). (2) Rather than passing `segments` down and switching inside each variant, the dispatcher builds the body `Column` once (the single switch lives in a top-level `_segmentWidget`) and passes a finished `child` to **dumb** variants that only apply design-language chrome (fill/padding/corners/elevation/alignment). This is a stronger read of AC4's "one segment-rendering path" — there is exactly one switch and the variants import neither `koel_core`/`koel_flutter` nor `koel_theme`, keeping AC2/AC3's import constraints literal (`material_bubble.dart` imports only `material`, `cupertino_bubble.dart` only `cupertino`). (3) No separate `_message_body.dart` file was needed → architecture's 3-file `bubble/` layout held exactly.
- **First production exhaustive sealed switch in koel — precedent set.** koel_lints `exhaustive_switch_must_have_default` mandates the `_` arm (so a future `MessageSegment` leaf is a semver-minor bump per FR-A12); Dart flags it `unreachable_switch_case` for today's 2-leaf snapshot. koel_core's `AgUiEvent` switches never hit this (they default a non-exhaustive subset). Resolved with a documented `// ignore: unreachable_switch_case` on the arm — the principled reconciliation (the arm degrades a future leaf to empty, never mis-renders); the dartdoc explains why. This is the pattern future koel sealed-switch consumers should copy.
- **Resolved the 7.1-deferred review item (codeText monospace).** Added `fontFamilyFallback: ['Menlo', 'Courier']` to `_defaultTextStyles.codeText` so Apple platforms (where `'monospace'` resolves to nothing) render real monospace. Slot set, `copyWith`/`lerp`/equality plumbing unchanged → all 15 theme tests stay green; **no new `KoelTheme` slots** added (7.1 pre-built every bubble slot).
- **Code-block foreground is brightness-derived, not a new slot.** `KoelColors` has no `onCodeBlock` slot and the role `on*` pair is text-on-bubble (wrong contrast on the code surface). Derived code text colour from `ThemeData.estimateBrightnessForColor(codeBlockBackground)` (near-white/near-black) so it stays readable even when a consumer mismatches `KoelTheme` against the ambient app brightness — robust without widening the one-way-door theme surface.
- **Cupertino "system font" comes for free.** `bodyText` carries no `fontFamily`, so prose inherits the ambient `DefaultTextStyle` — SF Pro under `CupertinoApp`, Roboto under `MaterialApp` — satisfying AC3 without per-variant font wiring.
- **Variance flag for 7.4 (carried from create-story):** goldens deferred to 7.4 (epic 7.2 AC4 lists 4; no golden harness in the workspace; 7.4 is the dedicated SEALER owning all goldens on the Linux lane). Widgets are golden-ready (deterministic `Message`/`DateTime.utc(2020)`, theme-driven). 7.4 barrel-seal set is **8** symbols (the epic's 7 + `BubbleStyle`, which appears in `MessageBubble`'s public ctor). The `// ignore: unreachable_switch_case` is a deliberate, documented carry-forward — not debt.
- **Scope held:** only `koel_widgets` touched. 3 new `bubble/` sources + 1 new test + the `codeText` edit + the barrel/pubspec growth. No `koel_core`/`koel_flutter`/other-package source change; `pubspec.lock` 0-drift.

### File List

- `packages/koel_widgets/pubspec.yaml` (modified — added `koel_core:` + `koel_flutter:` to `dependencies:`)
- `packages/koel_widgets/lib/src/bubble/message_bubble.dart` (new — `MessageBubble` dispatcher, `BubbleStyle`, shared `_segmentWidget`/`_codeBlock`, `_fallbackTheme`/`_isApple`)
- `packages/koel_widgets/lib/src/bubble/material_bubble.dart` (new — internal M3 chrome `MaterialBubble`)
- `packages/koel_widgets/lib/src/bubble/cupertino_bubble.dart` (new — internal iOS chrome `CupertinoBubble`)
- `packages/koel_widgets/lib/src/theme/koel_theme.dart` (modified — `codeText` `fontFamilyFallback` Apple-monospace hardening)
- `packages/koel_widgets/lib/koel_widgets.dart` (modified — barrel: `MessageBubble` + `BubbleStyle` export)
- `packages/koel_widgets/test/bubble/message_bubble_test.dart` (new — 10 widget tests)
- `_bmad-output/implementation-artifacts/7-2-message-bubble.md` (story tracking: task checkboxes, Dev Agent Record, Change Log, Status)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (status: `ready-for-dev` → `in-progress` → `review`)

## Change Log

| Date       | Change                                                                                                                                                                                                                                              |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 2026-06-06 | Implemented Story 7.2 — `MessageBubble` (Material 3 + Cupertino variants) + internal `MaterialBubble`/`CupertinoBubble`, shared segment switch, role mapping, null-`KoelTheme` fallback, `codeText` Apple-monospace hardening (7.1 deferral resolved). koel_widgets' first cross-package deps (`koel_core`+`koel_flutter`). 10 widget tests; all gates green (format/analyze/test), pubspec.lock 0-drift. Status → review. |
