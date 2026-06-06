---
baseline_commit: 656006925e02f2f97008c4e6e5176c8b518eff0b
---

# Story 7.1: KoelTheme extends ThemeExtension<KoelTheme>

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter developer,
I want `KoelTheme` as a `ThemeExtension` carrying color slots, text styles, and spacing tokens that every koel widget consumes via `Theme.of(context).extension<KoelTheme>()`,
so that consumers attach koel theming to their `MaterialApp`/`CupertinoApp` in one declaration per FR-E4.

## Acceptance Criteria

1. **Class shape.** In `packages/koel_widgets/lib/src/theme/koel_theme.dart`, `class KoelTheme extends ThemeExtension<KoelTheme>` is declared with `const KoelTheme({required this.colors, required this.textStyles, required this.spacing})` per Addendum A.7. The three nested types — `KoelColors`, `KoelTextStyles`, `KoelSpacing` — carry color slots (`messageBubbleUser`, `messageBubbleAssistant`, `inputBackground`, etc.), text styles (`bodyText`, `codeText`, etc.), and spacing tokens (`bubblePadding`, `inputPadding`, etc.).
2. **`copyWith` (top-level + nested).** `KoelTheme.copyWith(...)` returns a new theme with the named fields replaced and all others preserved. Each nested type (`KoelColors`/`KoelTextStyles`/`KoelSpacing`) also exposes a `copyWith` with the same semantics.
3. **`lerp` interpolates.** `KoelTheme.lerp(ThemeExtension<KoelTheme>? other, double t)` interpolates smoothly between two themes for theme-switch animations: at `t == 0` the result equals `this`, at `t == 1` it equals `other`, and intermediate `t` blends every slot (`Color.lerp` for colors, `TextStyle.lerp` for text styles, `EdgeInsets.lerp`/`lerpDouble` for spacing). When `other` is `null` or not a `KoelTheme`, `lerp` returns `this` unchanged.
4. **`light()` + `dark()` factories.** `KoelTheme.light()` and `KoelTheme.dark()` produce sensible Material 3 default palettes that differ in their color slots so a widget rendered under each visually adapts (golden verification deferred to Story 7.4).
5. **Value equality.** `KoelTheme` and its three nested types implement value-based `==` / `hashCode` so that `Theme`-driven equality checks (rebuild suppression, `ThemeData` diffing) treat two structurally identical themes as equal.
6. **Reachable + gated.** The barrel `lib/koel_widgets.dart` exports `KoelTheme`, `KoelColors`, `KoelTextStyles`, `KoelSpacing`; `dart analyze` exits 0 under the package's curated Flutter lint profile; unit tests cover `copyWith`, `lerp` (endpoints + midpoint + null/foreign-`other`), the `light()`/`dark()` factories, and value equality.

## Tasks / Subtasks

- [x] **Task 1 — Wire the package for its first Flutter source + test (AC: #1, #6)**
  - [x] Add a `dependencies:` block to `packages/koel_widgets/pubspec.yaml` with `flutter: { sdk: flutter }` (mirror `koel_flutter/pubspec.yaml:12-16`). `KoelTheme` needs `ThemeExtension`, `Color`, `TextStyle`, `EdgeInsets` from `package:flutter`.
  - [x] Add `flutter_test: { sdk: flutter }` to the existing `dev_dependencies:` (alongside `koel_lints:`), mirroring `koel_flutter/pubspec.yaml:37-40`.
  - [x] Keep `version: 0.0.1`, `publish_to: none`, `resolution: workspace`, and the `environment` block unchanged.
  - [x] Run `flutter pub get` (or `melos bootstrap`) and confirm `pubspec.lock` resolves with no drift to the AI-5.9 analyzer/freezed pins (`analyzer 12.1.0` / `freezed 3.2.6-dev.1`) — `koel_widgets` adds no codegen, so the lock must stay pin-stable.
- [x] **Task 2 — Author the nested token types (AC: #1, #2, #3, #5)**
  - [x] Create `packages/koel_widgets/lib/src/theme/koel_theme.dart` with `import 'package:flutter/material.dart';` (`ThemeExtension` lives in the material library) and `import 'dart:ui' show lerpDouble;` if spacing carries bare doubles.
  - [x] `class KoelColors` — immutable, `const` ctor with `required` `Color` fields for the slots the 7.2/7.3 widgets will consume (see Dev Notes → "Recommended slot set"). Implement `copyWith({Color? ...})`, a `lerp(KoelColors other, double t)` using `Color.lerp(a, b, t)!`, and value `==`/`hashCode` (`Object.hash` / `Object.hashAll`).
  - [x] `class KoelTextStyles` — immutable `const` ctor with `TextStyle` fields (`bodyText`, `codeText`, …). `copyWith`, `lerp` via `TextStyle.lerp(a, b, t)!`, value equality.
  - [x] `class KoelSpacing` — immutable `const` ctor with `EdgeInsets` (and/or `double`) tokens (`bubblePadding`, `inputPadding`, …). `copyWith`, `lerp` via `EdgeInsets.lerp(a, b, t)!` / `lerpDouble(a, b, t)!`, value equality.
- [x] **Task 3 — Author `KoelTheme` (AC: #1, #2, #3, #4, #5)**
  - [x] `class KoelTheme extends ThemeExtension<KoelTheme>` with `final KoelColors colors; final KoelTextStyles textStyles; final KoelSpacing spacing;` and `const KoelTheme({required this.colors, required this.textStyles, required this.spacing})`.
  - [x] `@override KoelTheme copyWith({KoelColors? colors, KoelTextStyles? textStyles, KoelSpacing? spacing})` — return a new `KoelTheme` with `??`-fallbacks.
  - [x] `@override KoelTheme lerp(covariant ThemeExtension<KoelTheme>? other, double t)` — `if (other is! KoelTheme) return this;` then delegate to each nested `lerp`. Do **not** override `type`/`runtimeType` — the base default is correct.
  - [x] `factory KoelTheme.light()` and `factory KoelTheme.dark()` returning `const` instances where possible, with Material 3 defaults that differ per palette.
  - [x] Value `==`/`hashCode` over `(colors, textStyles, spacing)`.
- [x] **Task 4 — Surface via the barrel (AC: #6)**
  - [x] In `lib/koel_widgets.dart` add a sectioned `export 'src/theme/koel_theme.dart' show KoelTheme, KoelColors, KoelTextStyles, KoelSpacing;` (incremental growth pattern; the full 7-symbol barrel seals at 7.4). Match the comment-banner style of `koel_flutter/lib/koel_flutter.dart`.
- [x] **Task 5 — Tests (AC: #2, #3, #4, #5, #6)**
  - [x] Create `packages/koel_widgets/test/theme/koel_theme_test.dart` using `package:flutter_test/flutter_test.dart`, importing the type via `package:koel_widgets/koel_widgets.dart` (proves the barrel export).
  - [x] `copyWith`: changed slot reflected, untouched slots preserved (top-level + at least one nested type).
  - [x] `lerp`: `t == 0` ⇒ equals `a`; `t == 1` ⇒ equals `b`; `t == 0.5` ⇒ a known midpoint colour/padding; `other == null` ⇒ returns `this`; foreign `ThemeExtension` ⇒ returns `this`.
  - [x] `light()` / `dark()`: assert at least one slot differs between the two.
  - [x] Value equality: two independently-constructed identical themes are `==` with equal `hashCode`; a one-slot difference is `!=`.
- [x] **Task 6 — Gate locally before marking done**
  - [x] `dart format` (committed sources must be 0-changed under `format:check`).
  - [x] `dart analyze` (or `flutter analyze`) in `koel_widgets` exits 0 — the curated Flutter rules (`use_key_in_widget_constructors`, `prefer_const_constructors_in_immutables`, etc.) and the asp plugin are already wired via `analysis_options.yaml`.
  - [x] `flutter test` in `koel_widgets` is green.

## Dev Notes

### What this story is — and is NOT

- **IS:** the first real source file and first test of `koel_widgets`. A pure, framework-data class (`ThemeExtension`) — no rendering, no `BuildContext` consumption yet. The widgets that *read* `KoelTheme` arrive in 7.2 (`MessageBubble`), 7.3 (`ChatInput`/`FollowUpList`).
- **IS NOT:** goldens, the example app, the full barrel seal, or the `public_member_api_docs` doc gate — all deferred to **Story 7.4** (the koel_widgets finalize/SEALER story), mirroring how `koel_flutter` deferred its doc gate + `dart_apitool` baseline to 6.8. [Source: epics/epic-7…#Story-7.4; analysis_options.yaml comment]

### `ThemeExtension<T>` contract — the load-bearing idiom

`ThemeExtension<KoelTheme>` has exactly two abstract members you MUST override; everything else is a normal immutable data class:

```dart
@override
KoelTheme copyWith({KoelColors? colors, KoelTextStyles? textStyles, KoelSpacing? spacing}) =>
    KoelTheme(
      colors: colors ?? this.colors,
      textStyles: textStyles ?? this.textStyles,
      spacing: spacing ?? this.spacing,
    );

@override
KoelTheme lerp(covariant ThemeExtension<KoelTheme>? other, double t) {
  if (other is! KoelTheme) return this;           // null OR foreign type → identity
  return KoelTheme(
    colors: colors.lerp(other.colors, t),
    textStyles: textStyles.lerp(other.textStyles, t),
    spacing: spacing.lerp(other.spacing, t),
  );
}
```

- **`lerp` null/type guard is mandatory.** `ThemeData.lerp` calls extension `lerp` with the *other* `ThemeData`'s extension of the same `type`; the `is! KoelTheme` early-return is the canonical Flutter idiom and is what makes `t == 0` return `this`. Tests must cover both `null` and a foreign `ThemeExtension` subtype.
- **Do NOT override `type`.** `ThemeExtension` defaults `Object get type => runtimeType`, which is correct for a single concrete class. Overriding it is a footgun.
- **Per-slot lerp helpers** (all framework-provided, no hand-rolled math): `Color.lerp(a, b, t)`, `TextStyle.lerp(a, b, t)`, `EdgeInsets.lerp(a, b, t)`, `dart:ui`'s `lerpDouble(a, b, t)`. Each returns nullable — assert non-null with `!` since both endpoints are non-null here.

### Why hand-written value classes (no freezed, no codegen)

`koel_core` uses `freezed` (Arch B.2), but **do not** pull `freezed`/`build_runner` into `koel_widgets`:
- freezed's generated `copyWith` has a different signature/return type than the `ThemeExtension.copyWith` override demands, and it cannot generate the `lerp` override — you'd hand-write both anyway.
- Keeping `koel_widgets` codegen-free means no `build_runner`, no `*.freezed.dart`, and no `melos run build && git diff --exit-code` drift gate for this package. Hand-write `==`/`hashCode` with `Object.hash(...)` (or `Object.hashAll([...])` for many fields). This matches the precedent set by `koel_flutter`'s hand-rolled sealed `MessageSegment` (Story 6.5 — "koel_flutter has no build_runner/freezed").

### Recommended slot set (design the surface deliberately — it is a one-way door)

`KoelColors`, `KoelTextStyles`, and `KoelSpacing` are reached through the barrel but the barrel does **not** seal until 7.4 — so 7.1 establishes the *structure* and a *starter* slot set; 7.2/7.3 extend the nested types (adding slots + threading them through `copyWith`/`lerp`/factories/equality) as their widgets actually consume them. Build the minimum that 7.2/7.3 demand — neither speculative extras ("just in case" slots) nor an under-built set that forces 7.2 to refactor the equality/lerp plumbing. Recommended starting slots, derived from what the downstream widgets read:

- **`KoelColors`** — `messageBubbleUser`, `messageBubbleAssistant` (bubble backgrounds, 7.2), `onMessageBubbleUser`, `onMessageBubbleAssistant` (readable text-on-bubble, 7.2), `inputBackground` (7.3 `ChatInput`), `codeBlockBackground` (7.2 code-block segments from 6.5), `followUpPillBackground` + `onFollowUpPill` (7.3 `FollowUpList`).
- **`KoelTextStyles`** — `bodyText` (text segments), `codeText` (monospace code blocks). A `caption`/timestamp style is optional; add only if 7.2 needs it.
- **`KoelSpacing`** — `bubblePadding` (`EdgeInsets`), `inputPadding` (`EdgeInsets`). A follow-up-row gap (`double`) is optional; add when 7.3 needs it.

Record any slot you add or omit as a brief decision note in the Dev Agent Record so 7.2/7.3 inherit the rationale.

### Package wiring specifics

- `koel_widgets/pubspec.yaml` is currently scaffolded with **no `dependencies:` block** and only `koel_lints:` under `dev_dependencies:`. You are adding the first runtime dep (`flutter`) and the first test dep (`flutter_test`). [Source: packages/koel_widgets/pubspec.yaml]
- **No `koel_core` / `koel_flutter` dependency is needed for 7.1** — `KoelTheme` is pure framework data. (7.2 will add `koel_flutter` for `Message`/`MessageSegment`.) Keep the dependency surface minimal (counter-metric CM-3).
- The curated Flutter lint profile is **already wired**: `analysis_options.yaml` does `include: [../../analysis_options.yaml, package:koel_lints/koel_flutter.yaml]` (AI-6.1, closed in the Epic 6 retro). The Flutter-type rules (`use_key_in_widget_constructors`, `prefer_const_constructors_in_immutables`, `sized_box_for_whitespace`) and the asp plugin fire in IDE + `analyze`. Expect `prefer_const_constructors_in_immutables` to push you toward `const` ctors on the token classes — comply, it composes with the `const` factory requirement (AC #4). [Source: packages/koel_widgets/analysis_options.yaml]
- Adding `flutter_test` makes `koel_widgets` a Flutter-test package — `tooling/test_package.sh` auto-detects it via the anchored `sdk: flutter` block-form match (AI-6.2, closed). No tooling change needed; the package flips automatically. [Source: epic-6-retro-2026-06-06.md AI-6.2]

### Documentation

Write a one-line dartdoc on every public member now (class, nested types, each factory, `copyWith`/`lerp`). The `public_member_api_docs` gate is **not** enabled until 7.4, but documenting as you go avoids a finalize-time cleanup pile — the same house pattern `koel_flutter` followed (docs written through 6.1–6.7, gate switched on at 6.8). [Source: analysis_options.yaml comment; epic-6 retro]

### Testing standards

- Framework: `package:flutter_test/flutter_test.dart` (`test`/`group`/`expect`), unit-style — **no `WidgetTester`/`pumpWidget` needed** for 7.1 (it is pure data; widget+golden tests arrive in 7.2–7.4). [Source: architecture.md §10 NFR-12/13]
- Import the type under test via `package:koel_widgets/koel_widgets.dart` (not a `src/` path) so the test doubles as a barrel-export assertion.
- Coverage: the package-level ≥ 80% gate (NFR-12) is enforced at the 7.4 finalize via `melos run test:coverage`; for 7.1, cover all public behavior (every `copyWith`/`lerp`/factory/equality path) so the package never dips below floor as it grows. [Source: architecture.md:1123-1124; epics/epic-7…#Story-7.4]
- For `lerp` midpoint assertions, pick endpoint colours/paddings whose `t == 0.5` blend is exact and predictable (e.g. `Color.lerp(black, white, 0.5)` → `Color(0xff7f7f7f)`; `EdgeInsets.all(0)` → `EdgeInsets.all(10)` at 0.5 → `EdgeInsets.all(5)`).

### Project Structure Notes

- New source: `packages/koel_widgets/lib/src/theme/koel_theme.dart` — matches the architecture's `koel_widgets/lib/src/theme/koel_theme.dart` layout. [Source: architecture.md:916-920]
- New test: `packages/koel_widgets/test/theme/koel_theme_test.dart` — mirrors the `koel_flutter` `test/<feature>/…_test.dart` convention.
- Barrel: `packages/koel_widgets/lib/koel_widgets.dart` (extend, don't rewrite). The 7.4 finalize seals it to exactly: `MessageBubble`, `ChatInput`, `FollowUpList`, `KoelTheme`, `KoelColors`, `KoelTextStyles`, `KoelSpacing`. Adding the four theme symbols now is on that trajectory — no variance. [Source: epics/epic-7…#Story-7.4]
- No changes to any other package. No `koel_core` surface change (contrast 6.3, which added `toJson`/`fromJson`).

### References

- [Source: _bmad-output/planning-artifacts/epics/epic-7-widget-primitives-theming-koelwidgets.md#Story-7.1] — story statement + ACs (the detailed `colors/textStyles/spacing` shape).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md#A.7] — canonical (illustrative) `KoelTheme extends ThemeExtension<KoelTheme>` signature.
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md#F-E4] — Theming Hooks requirement (`Theme.of(context).extension<KoelTheme>()`, attach to MaterialApp/CupertinoApp).
- [Source: _bmad-output/planning-artifacts/architecture.md#916-920] — `koel_widgets/lib/src/theme/koel_theme.dart` placement.
- [Source: _bmad-output/planning-artifacts/architecture.md#1123-1130] — `melos run test:coverage` / `dart analyze` gate tooling (NFR-12/13).
- [Source: packages/koel_flutter/pubspec.yaml#12-40] — `flutter`/`flutter_test` SDK-dep pattern to copy.
- [Source: packages/koel_flutter/lib/koel_flutter.dart] — barrel comment-banner style + incremental export pattern.
- [Source: packages/koel_widgets/analysis_options.yaml] — curated Flutter lint profile (already wired; doc gate deferred to 7.4).
- [Source: _bmad-output/implementation-artifacts/epic-6-retro-2026-06-06.md] — AI-6.1 (lint profile, CLOSED) + AI-6.2 (test_package.sh anchor, CLOSED); Epic 7 = first visual layer, goldens/Cupertino is the expected heavy-defect boundary (7.2+).

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Claude Opus 4.8, 1M context) via `/bmad-dev-story`; Flutter specialist persona loaded (`agent-flutter-engineer`).

### Debug Log References

- `flutter pub get` (workspace) → `Got dependencies!`; `pubspec.lock` diff vs baseline = **0 changes** (analyzer 12.1.0 / freezed 3.2.6-dev.1 pins held — AI-5.9). `flutter`/`flutter_test` are `sdk:`-source deps, already resolved transitively via `koel_flutter`, so they add no hosted lock entries.
- `dart format --output=none --set-exit-if-changed lib test` → FORMAT CLEAN (after `dart format` write).
- `dart analyze` (koel_widgets) → `No issues found!`; repo-wide `melos analyze` → 12 pkgs SUCCESS incl. koel_widgets.
- `flutter test` (koel_widgets) → **14/14 passed**; repo-wide `melos test` → SUCCESS, koel_widgets auto-detected as a Flutter package (AI-6.2 `sdk: flutter` block anchor) and run via `flutter test`; koel_flutter 74 unchanged.
- `melos format:check` → 192 files, 0 changed.

### Completion Notes List

- **All 6 ACs satisfied.** `KoelTheme extends ThemeExtension<KoelTheme>` with the A.7 ctor; nested `KoelColors`/`KoelTextStyles`/`KoelSpacing`; top-level + nested `copyWith`; `lerp` with the mandatory `is! KoelTheme` null/foreign guard delegating to per-slot framework lerps; `light()`/`dark()` const factories differing in every colour slot; value `==`/`hashCode` on all four types; barrel-reachable + `analyze` 0 + 14 tests.
- **Midpoint test — caught a stale Dev-Note assumption (green-but-blind guard).** Dev Notes cited `Color.lerp(black, white, 0.5) → Color(0xff7f7f7f)` — that is the **int-era** value. Flutter ≥3.27 (repo runs 3.44) stores colour channels as floats and rounds on `toARGB32`, so `black→white` midpoint is `0xff808080`, not `0x7f7f7f` — a hardcoded `0x7f7f7f` assertion would have been a version-fragile false-pass. Used a **version-stable** exact pair instead: `messageBubbleUser 0xFF000000 → 0xFF808080 ⇒ 0xFF404040` (channel `128/255 · 0.5 = 64/255`, exact double) plus `EdgeInsets.all(0)→all(10) ⇒ all(5)` and `fontSize 10→20 ⇒ 15`. Confirmed live: midpoint resolved to `0xFF404040`.
- **Foreign-`other` lerp test — the `covariant` parameter constrains what "foreign" can mean.** A genuinely-unrelated `ThemeExtension<X>` is a *compile-time* error to pass (covariant narrows the static param to `ThemeExtension<KoelTheme>?`), and forcing one through `dynamic` would trip the covariant runtime downcast *before* the `is! KoelTheme` guard runs. The only input that actually reaches the guard's non-null/foreign branch is a class that **is** a `ThemeExtension<KoelTheme>` but is **not** a `KoelTheme` (`_NotKoelTheme` test double). That is what the test exercises; `null` covers the other guarded path.
- **Slot-set decisions (one-way door — recorded for 7.2/7.3).** Built the recommended starter set verbatim, no speculative extras: `KoelColors` = `messageBubbleUser/Assistant` + `onMessageBubbleUser/Assistant` + `inputBackground` + `codeBlockBackground` + `followUpPillBackground` + `onFollowUpPill` (8). `KoelTextStyles` = `bodyText` + `codeText` (caption **omitted** — add in 7.2 only if `MessageBubble` renders a timestamp). `KoelSpacing` = `bubblePadding` + `inputPadding` (EdgeInsets only; follow-up-row gap `double` **omitted** — add in 7.3 with `FollowUpList`, which also avoids an unused `dart:ui lerpDouble` import now).
- **Text styles are palette-agnostic by design.** Rendered text colour comes from the `onX` colour slots, so `light()`/`dark()` share one `const _defaultTextStyles` + `const _defaultSpacing` (no per-factory allocation). AC4's "differ per palette" is met entirely through colour slots.
- **Dartdoc on every public member** (class + 3 nested types + both factories + every field + `copyWith`/`lerp`), per the house "document-as-you-go" pattern — the `public_member_api_docs` gate is deferred to 7.4 but the surface is already gate-ready.
- **Scope held:** only `koel_widgets` touched. No `koel_core`/`koel_flutter` dependency added (CM-3), no codegen, no other package modified. `pubspec.lock` pin-stable.

### File List

- `packages/koel_widgets/pubspec.yaml` (modified — added `dependencies: flutter` + `dev_dependencies: flutter_test`)
- `packages/koel_widgets/lib/src/theme/koel_theme.dart` (new — `KoelTheme` + `KoelColors`/`KoelTextStyles`/`KoelSpacing`)
- `packages/koel_widgets/lib/koel_widgets.dart` (modified — barrel: theme export + contract banner)
- `packages/koel_widgets/test/theme/koel_theme_test.dart` (new — 14 unit tests)
- `_bmad-output/implementation-artifacts/7-1-koel-theme.md` (story tracking: frontmatter `baseline_commit`, task checkboxes, Dev Agent Record, Change Log, Status)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (status: `ready-for-dev` → `in-progress` → `review`)

## Change Log

| Date       | Change                                                                                     |
| ---------- | ------------------------------------------------------------------------------------------ |
| 2026-06-06 | Implemented Story 7.1 — `KoelTheme` ThemeExtension + nested token types, barrel export, 14 tests. All ACs met; gates green (format/analyze/test). Status → review. |
| 2026-06-06 | Code review (3-layer adversarial) — 2 patches applied (lerp midpoint now asserts all 14 slots; added `KoelTextStyles.copyWith` swap/preserve test → 16 tests), 2 deferred to 7.2/7.4 (`monospace` fallback, `inherit`-parity doc note), 7 dismissed. Gates green (format/analyze/test). Status → done. |

## Review Findings

_Adversarial code review 2026-06-06 (Blind Hunter + Edge Case Hunter + Acceptance Auditor). 2 patch, 2 defer, 7 dismissed as noise._

- [x] [Review][Patch] `lerp` midpoint only asserts 3/14 interpolated slots — add midpoint assertions for the remaining colour slots, `inputPadding`, and `codeText` so AC3 "blends every slot" + AC6 lerp-midpoint coverage is literal, not representative-sample [packages/koel_widgets/test/theme/koel_theme_test.dart:105-111] — FIXED: midpoint test now asserts all 8 colour slots + both spacing tokens + both text styles
- [x] [Review][Patch] `KoelTextStyles.copyWith` swap/preserve not independently tested — only no-arg equality is exercised; add a swap-one-field/preserve-other test to match the AC2 "each nested type's copyWith" coverage given for `KoelColors`/`KoelSpacing` [packages/koel_widgets/test/theme/koel_theme_test.dart:163-166] — FIXED: added `nested KoelTextStyles: one style swapped, other preserved` test
- [x] [Review][Defer] `codeText` uses `fontFamily: 'monospace'` — not a guaranteed cross-platform family; silently falls back to the proportional default on iOS/macOS/web [packages/koel_widgets/lib/src/theme/koel_theme.dart:223] — deferred to 7.2 (code-block widget render) / 7.4 (goldens), where actual rendering validates the monospace choice
- [x] [Review][Defer] `TextStyle.lerp` throws on `inherit`-mismatch between a consumer-built `KoelTextStyles` and a default — add a one-line doc note on the `inherit`-parity contract [packages/koel_widgets/lib/src/theme/koel_theme.dart:164-167] — deferred to 7.4 finalize (consumer-facing theming guidance); only reachable 7.2+ via consumer-supplied styles
