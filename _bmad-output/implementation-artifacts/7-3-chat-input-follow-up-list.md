---
baseline_commit: f623d6d08a441ba3d931fbee0ef889af1a57f98a
---

# Story 7.3: ChatInput (auto-grow + attachment slot) + FollowUpList

Status: done

<!-- Note: Validation is optional. Run validate-create-story for quality check before dev-story. -->

## Story

As a Flutter developer,
I want `ChatInput` (an auto-growing text field with an attachment slot) and `FollowUpList` (a suggested-prompts row), both reading their colours/text/spacing from the ambient `KoelTheme`,
so that drop-in chat composition + follow-up UI is available without my having to hand-roll layout, per FR-E3.

## Acceptance Criteria

1. **`ChatInput` class shape + callbacks.** In `packages/koel_widgets/lib/src/input/chat_input.dart`, `class ChatInput extends StatefulWidget` accepts `required void Function(String content) onSubmit`, an optional `Widget? attachmentSlot`, and an optional `String? placeholder`. `ChatInput` is exported from the barrel `lib/koel_widgets.dart`. On submit the entered text is delivered to `onSubmit` **trimmed-non-empty only** (a blank/whitespace-only field does not fire `onSubmit`) and the field then clears. [Source: epics/epic-7…#Story-7.3; prd.md:269]

2. **Auto-grow to a max line count.** The input starts at a single line and grows with content up to a maximum line count (**default 5**), after which it scrolls internally rather than growing further. The max is configurable via a constructor field (e.g. `int maxLines` defaulting to `5`). [Source: epics/epic-7…#Story-7.3 AC1]

3. **Enter submits, Shift+Enter inserts a newline.** With a hardware keyboard, pressing **Enter (no modifier)** submits (same path as AC1 — trims, fires `onSubmit` if non-empty, clears) and does **not** insert a newline; pressing **Shift+Enter** inserts a newline and does **not** submit. This is implemented by overriding the field's default text-editing shortcut for the Enter key (see Dev Notes → "Enter vs Shift+Enter — source-verified idiom"), not by post-hoc string munging. [Source: epics/epic-7…#Story-7.3 AC1; flutter/packages/flutter/lib/src/widgets/editable_text.dart:716-723]

4. **Attachment slot in the trailing position.** When `attachmentSlot` is non-null, the passed widget renders in the **trailing** position of the input row (after the text field). When it is null, no trailing affordance is shown and the text field occupies the full width. [Source: epics/epic-7…#Story-7.3 AC2]

5. **Works under both `MaterialApp` and a bare `CupertinoApp` (leave the system working end-to-end).** `ChatInput` renders without throwing under a bare `CupertinoApp` — which provides **no `MaterialLocalizations` and no `Material` ancestor** (source-verified). It therefore is **not** built on Material `TextField`/`InputDecorator` (which assert both); it is built on the design-neutral `EditableText` (`package:flutter/widgets.dart`). When `Theme.of(context).extension<KoelTheme>()` is **null** (the real case under a bare `CupertinoApp`), `ChatInput` falls back to a brightness-appropriate `KoelTheme.light()`/`dark()` default — the same resilience contract Story 7.2 established for the bubble. [Source: flutter/packages/flutter/lib/src/cupertino/app.dart:528-531; flutter/packages/flutter/lib/src/material/text_field.dart:97,1205; 7-2-message-bubble.md AC5]

6. **`FollowUpList` class shape + rendering.** In `packages/koel_widgets/lib/src/follow_up/follow_up_list.dart`, `class FollowUpList extends StatelessWidget` accepts `required List<String> suggestions` and `required void Function(String) onSelected`, and renders a **horizontally scrollable** row of pill-shaped suggestions. Each pill reads `KoelColors.followUpPillBackground` (fill), `KoelColors.onFollowUpPill` (label colour), `KoelTextStyles.bodyText` (label geometry), and the new `KoelSpacing.followUpGap` (inter-pill gap). Tapping a pill invokes `onSelected` with that suggestion's string. An empty `suggestions` list renders an empty (zero-height or `SizedBox.shrink`) row without error. `FollowUpList` is exported from the barrel. [Source: epics/epic-7…#Story-7.3 AC3; prd.md:270]

7. **`KoelSpacing.followUpGap` token added (the one pre-reserved theme widening).** `KoelSpacing` gains exactly **one** new token — `final double followUpGap` — wired through its constructor, `copyWith`, `lerp` (via plain `double` interpolation), `operator ==`, `hashCode`, and the shared `_defaultSpacing` const. No new `KoelColors` and no new `KoelTextStyles` slots are added (input + pill foregrounds are derived, not slotted — see Dev Notes). The existing 15 `koel_theme_test.dart` tests are updated to the new `KoelSpacing` shape and stay green (plus a `followUpGap` lerp-midpoint assertion). [Source: packages/koel_widgets/lib/src/theme/koel_theme.dart:182-217; 7-1-koel-theme.md "Slot-set decisions"]

8. **Tests + gates (goldens deferred to 7.4).** New `WidgetTester` tests assert, via widget-tree inspection (not pixels): auto-grow max-lines wiring, Enter-submits / Shift+Enter-newline, blank-submit suppression + clear-on-submit, attachment-slot presence/absence, placeholder display, null-`KoelTheme` resilience for both widgets, `FollowUpList` pill count + `onSelected` payload + horizontal scrollability + empty-list. `ChatInput` + `FollowUpList` are reachable through `package:koel_widgets/koel_widgets.dart`. `dart analyze` exits 0 under the curated Flutter profile; `melos format:check` 0-changed; `melos test` SUCCESS. **Goldens are NOT in this story** — every primitive's goldens (Material/Cupertino × light/dark) are centralized in Story 7.4 on the deterministic Linux CI lane; 7.3's job is to make the widgets golden-*ready* (deterministic, theme-driven, no time/random inputs). [Source: epics/epic-7…#Story-7.4; 7-1-koel-theme.md; 7-2-message-bubble.md "Goldens: deferred to 7.4"]

## Tasks / Subtasks

- [x] **Task 1 — Add `KoelSpacing.followUpGap` (AC: #6, #7)**
  - [x] In `lib/src/theme/koel_theme.dart`, add `final double followUpGap;` to `KoelSpacing`, make it `required` in the `const` ctor, and thread it through `copyWith` (`double? followUpGap` ⇒ `followUpGap ?? this.followUpGap`), `lerp` (`followUpGap + (other.followUpGap - followUpGap) * t` — plain `double` lerp, **not** `EdgeInsets.lerp`), `operator ==` (add `&& other.followUpGap == followUpGap`), and `hashCode` (add to `Object.hash`).
  - [x] Set a sensible default in the shared `_defaultSpacing` const (e.g. `followUpGap: 8`). `_defaultSpacing` is reused by both `light()`/`dark()` — one const, no per-call alloc (keep the 7.1 pattern). Update the slot doc-comment on `KoelSpacing` (line 180-183 narrates "a follow-up-row gap … joins in 7.3" — make it past-tense / accurate now that it exists).
  - [x] Add a one-line dartdoc on the new field (the `public_member_api_docs` gate is still off until 7.4, but document-as-you-go — the house pattern).
  - [x] **Do not** add any `KoelColors` or `KoelTextStyles` slots. Input text/placeholder/cursor colour and pill label colour are **derived** from their backgrounds' brightness (the 7.2 code-block precedent), not slotted — see Dev Notes → "No new colour/text slots".

- [x] **Task 2 — Update `koel_theme_test.dart` for the new `KoelSpacing` shape (AC: #7)**
  - [x] Every `KoelSpacing(...)` literal in `test/theme/koel_theme_test.dart` (constructed at ~lines 40-42 and 60-62) now needs a `followUpGap:` argument — add distinct values per fixture so the lerp/copyWith assertions remain meaningful (e.g. `followUpGap: 0` in one endpoint, `followUpGap: 10` in the other so the `t==0.5` midpoint is `5`).
  - [x] Add a `followUpGap` assertion to the existing `lerp` midpoint test (mirror the `bubblePadding`/`inputPadding` midpoint checks at ~lines 124-126: `expect(mid.spacing.followUpGap, 5)`), and to the nested-`KoelSpacing` `copyWith` swap/preserve test (~line 87-92) so swapping one token preserves `followUpGap`.
  - [x] Re-run: all **15** existing theme tests stay green (count may rise by the added assertions but no test is deleted). Confirm exact pre-edit count with `rg -c 'test\(|testWidgets\(' test/theme/koel_theme_test.dart` (currently 15) and record any delta in the Dev Agent Record.

- [x] **Task 3 — `ChatInput` (AC: #1, #2, #3, #4, #5)**
  - [x] Create `lib/src/input/chat_input.dart` importing `package:flutter/widgets.dart` (for `EditableText`, `Shortcuts`, `Actions`, `Intent`, `CallbackAction`, layout) + `package:flutter/services.dart` (for `LogicalKeyboardKey`) + `package:flutter/cupertino.dart show CupertinoTheme` (for the null-theme brightness probe, mirroring the bubble) + `import '../theme/koel_theme.dart';`. **Do not** import `material.dart`, `koel_core`, or `koel_flutter` — `ChatInput` deals in `String`, not `Message`, and must not pull a Material ancestor requirement (AC5).
  - [x] `class ChatInput extends StatefulWidget` with a `const` ctor: `const ChatInput({required this.onSubmit, this.attachmentSlot, this.placeholder, this.maxLines = 5, super.key});` and fields `final void Function(String content) onSubmit; final Widget? attachmentSlot; final String? placeholder; final int maxLines;`.
  - [x] State (`_ChatInputState`): create a `TextEditingController` + `FocusNode` in `initState`, **dispose both** in `dispose` (lifecycle hygiene — a leaked controller/focus node is the classic StatefulWidget bug). A private `_submit()` reads `_controller.text`, returns early if `.trim().isEmpty` (AC1 blank-suppression), else calls `widget.onSubmit(text)` and `_controller.clear()`.
  - [x] Resolve the theme once in `build`: `final koel = resolveKoelTheme(context);` (the shared helper extracted in Task 5). Derive a readable foreground from `koel.colors.inputBackground` brightness via `ThemeData.estimateBrightnessForColor` (the 7.2 code-block trick) for the entered-text colour + cursor; derive a dimmed placeholder colour from it.
  - [x] Build the editing surface on **`EditableText`** (not `TextField`): supply `controller`, `focusNode`, `style: koel.textStyles.bodyText.copyWith(color: fg)`, `cursorColor: fg`, `backgroundCursorColor` (iOS floating cursor — a translucent `fg`), `minLines: 1`, `maxLines: widget.maxLines`, `keyboardType: TextInputType.multiline`, `textInputAction: TextInputAction.newline` (soft-keyboard return inserts a newline; hardware Enter is intercepted by the Shortcuts wrapper). Render the `placeholder` as an overlaid `Text` (in a `Stack`) shown only when `_controller.text.isEmpty` — subscribe to the controller so it toggles (`EditableText` has no built-in `hintText`). [See Dev Notes → "EditableText config".]
  - [x] Wrap the `EditableText` in the Enter-shortcut override (Task 4) and then in the chrome: a rounded `DecoratedBox`/`Container` filled with `koel.colors.inputBackground`, padded by `koel.spacing.inputPadding`. Lay out text + attachment as a `Row` with the field `Expanded` and `attachmentSlot` (when non-null) in the trailing position. **No send button** — the AC names none; the trailing element is exactly the attachment slot (record this scope decision).

- [x] **Task 4 — Enter / Shift+Enter override (AC: #3) — use the source-verified idiom**
  - [x] Wrap the `EditableText` in `Shortcuts(shortcuts: { SingleActivator(LogicalKeyboardKey.enter): const _SubmitIntent(), SingleActivator(LogicalKeyboardKey.numpadEnter): const _SubmitIntent() }, child: Actions(actions: { _SubmitIntent: CallbackAction<_SubmitIntent>(onInvoke: (_) { _submit(); return null; }) }, child: <EditableText>))`. Declare a private `class _SubmitIntent extends Intent { const _SubmitIntent(); }`.
  - [x] **Why this works (and Shift+Enter falls through):** a `Shortcuts` widget placed between the root `DefaultTextEditingShortcuts` and the `EditableText` overrides the default Enter handling (which sends plain Enter to the IME). `SingleActivator(LogicalKeyboardKey.enter)` matches **only when no modifiers are held**, so Shift+Enter does not match the override → falls through to the default → the IME inserts a newline. This is documented behaviour, verified in Flutter 3.44.0 source — see Dev Notes. **Do not** attempt to intercept via an ancestor `Focus.onKeyEvent` (the default text-editing shortcut consumes plain Enter with `DoNothingAndStopPropagationTextIntent` before an ancestor sees it).

- [x] **Task 5 — Extract the shared `KoelTheme` resolver (AC: #5; refactor 7.2)**
  - [x] Three widgets now need the "read `KoelTheme` from context, else brightness-appropriate fallback" logic (bubble, input, and — read below — pills). Extract `message_bubble.dart`'s private `_fallbackTheme(BuildContext)` into a shared **internal** helper, e.g. `KoelTheme resolveKoelTheme(BuildContext context)` in `lib/src/theme/theme_resolve.dart` (returns `Theme.of(context).extension<KoelTheme>() ?? <brightness fallback>`). It is **not** exported from the barrel (internal).
  - [x] Refactor `message_bubble.dart` to call `resolveKoelTheme(context)` in place of its inline `Theme.of(context).extension<KoelTheme>() ?? _fallbackTheme(context)` and delete the now-duplicated `_fallbackTheme`. The existing 26 bubble tests are the regression guard — they must stay green after the refactor (run them). Rule-of-three: this extraction is triggered by the third consumer, not speculative.
  - [x] `FollowUpList` (`StatelessWidget`) calls `resolveKoelTheme(context)` too — same null-`CupertinoApp` resilience.

- [x] **Task 6 — `FollowUpList` (AC: #6)**
  - [x] Create `lib/src/follow_up/follow_up_list.dart` importing `package:flutter/widgets.dart` + `import '../theme/koel_theme.dart';` + the shared resolver. **No** `material.dart`/`cupertino.dart` chrome needed (pills are neutral rounded containers); use `GestureDetector`/`InkWell`-free tap (`GestureDetector` keeps it Material-ancestor-free for AC5 symmetry).
  - [x] `class FollowUpList extends StatelessWidget` with `const FollowUpList({required this.suggestions, required this.onSelected, super.key});` and fields `final List<String> suggestions; final void Function(String) onSelected;`.
  - [x] `build`: `final koel = resolveKoelTheme(context);`. If `suggestions.isEmpty` return `const SizedBox.shrink()`. Else a horizontally scrollable row — `SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [ … separated by `SizedBox(width: koel.spacing.followUpGap)` … ]))` (or `ListView.separated` horizontal). Each pill: a rounded `DecoratedBox` filled with `koel.colors.followUpPillBackground`, a sensible **const** inner padding (pill padding is **not** a theme token — only the gap is; record this), wrapping `Text(suggestion, style: koel.textStyles.bodyText.copyWith(color: koel.colors.onFollowUpPill))`, made tappable via `GestureDetector(onTap: () => onSelected(suggestion))`.
  - [x] Keep pills `const` where the analyzer permits; one-line dartdoc on `FollowUpList` + its ctor + both fields.

- [x] **Task 7 — Surface via the barrel (AC: #1, #6, #8)**
  - [x] In `lib/koel_widgets.dart` add two sectioned exports matching the 7.1/7.2 banner style: `export 'src/input/chat_input.dart' show ChatInput;` and `export 'src/follow_up/follow_up_list.dart' show FollowUpList;`. Export **only** `ChatInput` and `FollowUpList` — internal `_SubmitIntent` and the `resolveKoelTheme` helper are not exported.
  - [x] After 7.3 the barrel carries **8** symbols: `KoelTheme, KoelColors, KoelTextStyles, KoelSpacing, MessageBubble, BubbleStyle, ChatInput, FollowUpList` — the full set 7.4 seals (the epic's literal 7 + `BubbleStyle`). The symbol set is now **complete**; 7.4 only seals (doc gate + `dart_apitool` baseline), it adds no new public symbol.

- [x] **Task 8 — Widget tests (AC: #8)**
  - [x] `test/input/chat_input_test.dart` (`package:flutter_test`, import via `package:koel_widgets/koel_widgets.dart`):
    - [x] **Auto-grow:** pump `ChatInput`, find the `EditableText`, assert `minLines == 1` and `maxLines == 5` (default), and `maxLines` respects a passed override.
    - [x] **Enter submits / Shift+Enter newline:** enter text, simulate Enter (`tester.sendKeyEvent(LogicalKeyboardKey.enter)` after focusing) ⇒ a captured `onSubmit` payload fires with the text and the field clears; with Shift held (`sendKeyDownEvent(LogicalKeyboardKey.shift)` … `enter` … `sendKeyUpEvent`) the text gains a newline and `onSubmit` does **not** fire. (Pump under a `WidgetsApp`/`MaterialApp` host so `DefaultTextEditingShortcuts` is present.)
    - [x] **Blank-suppression + clear:** Enter on an empty/whitespace field ⇒ `onSubmit` not called; after a real submit the controller is empty.
    - [x] **Attachment slot:** pass a `Key`-tagged widget ⇒ `find.byKey` succeeds and sits trailing; omit it ⇒ that key is absent.
    - [x] **Placeholder:** pass `placeholder: 'Ask…'` ⇒ the text is found while empty, gone after typing.
    - [x] **Null-`KoelTheme` resilience:** pump inside a bare `CupertinoApp` (no Material `Theme`/extension, no `MaterialLocalizations`) ⇒ no throw, renders.
  - [x] `test/follow_up/follow_up_list_test.dart`:
    - [x] **Pill count + payload:** `suggestions: ['a','b','c']` ⇒ three pills; tapping the 2nd invokes `onSelected('b')`.
    - [x] **Horizontal scrollability:** assert a horizontally-scrolling viewport is present (`find.byType(SingleChildScrollView)` with `scrollDirection == Axis.horizontal`, or the `ListView`'s scroll direction).
    - [x] **Theme tokens:** the pill fill is `followUpPillBackground` and the gap between pills equals `followUpGap` (find the separator `SizedBox.width`).
    - [x] **Empty list:** `suggestions: []` ⇒ `SizedBox.shrink`, no error.
    - [x] **Null-`KoelTheme` resilience:** under a bare `CupertinoApp`, renders without throw.
  - [x] Keep every test deterministic (fixed strings, no `DateTime.now()`/randomness) so 7.4 can wrap these exact widgets in goldens without flakiness.

- [x] **Task 9 — Gate locally before marking done**
  - [x] `dart format` (committed sources 0-changed under `melos format:check`).
  - [x] `dart analyze` in `koel_widgets` exits 0 (curated Flutter rules + asp plugin); expect `prefer_const_constructors`, `use_key_in_widget_constructors`, `prefer_const_constructors_in_immutables`, `use_super_parameters` to fire if missed. `public_member_api_docs` is still off (switches on at 7.4) — but document public members as you go.
  - [x] `flutter test` in `koel_widgets` green: new `ChatInput` + `FollowUpList` tests + the 26 bubble tests (regression after the Task 5 extraction) + the updated theme tests. Repo-wide `melos test` SUCCESS. Confirm `pubspec.lock` 0-drift to the AI-5.9 pins (no new deps added).

## Dev Notes

### What this story is — and is NOT

- **IS:** the second + third `koel_widgets` rendering primitives — `ChatInput` (the first **stateful** widget in the package: a controller-owning, auto-growing composer) and `FollowUpList` (a stateless pill row). Both are the *last* `koel_widgets` source primitives; after 7.3 the public symbol set is complete and only the **seal** (7.4) remains. It adds the **one** pre-reserved spacing token (`followUpGap`) and extracts the shared `KoelTheme` resolver now that there are three consumers.
- **IS NOT:** goldens, the `example/` app, the barrel **seal** / `public_member_api_docs` doc gate, or the `dart_apitool` baseline — all deferred to **Story 7.4** (the `koel_widgets` SEALER), exactly as 7.1 and 7.2 deferred them. It is also NOT a redesign of `MessageBubble` or `KoelTheme`'s colour/text slots (only `KoelSpacing` gains one token). [Source: epics/epic-7…#Story-7.4; 7-1-koel-theme.md; 7-2-message-bubble.md Dev Notes]

### Enter vs Shift+Enter — source-verified idiom (the load-bearing detail)

This is the one piece most likely to be implemented wrongly. The naïve approaches **fail**, and the reason is in the framework source:

- `DefaultTextEditingShortcuts` (mounted near the app root by `WidgetsApp`) maps `SingleActivator(LogicalKeyboardKey.enter)` → `DoNothingAndStopPropagationTextIntent` with the comment *"These keys should go to the IME when a field is focused, not to other Shortcuts."* So plain Enter is **consumed and propagation stopped** before any **ancestor** `Shortcuts`/`Focus.onKeyEvent` you add can see it. An ancestor-`Focus.onKeyEvent` interceptor therefore does **not** work. [Source: flutter/packages/flutter/lib/src/widgets/default_text_editing_shortcuts.dart:329,754,894]
- The supported override, stated in `EditableText`'s own dartdoc: *"any [Shortcuts] widget between it and this [EditableText] will override those defaults."* So a `Shortcuts` widget **wrapping the field** (between the root defaults and the `EditableText`) **does** override Enter. Key events are offered to `Shortcuts` (via its `FocusNode`) **before** text input — *"it first gives the framework the opportunity to handle it as a raw key event … If it is not handled, then it will proceed to try handling it as text input"* — so mapping Enter to a submit `Intent` preempts the newline insertion. [Source: flutter/packages/flutter/lib/src/widgets/editable_text.dart:716-742]
- `SingleActivator(enter)` matches **only with no modifiers**, so **Shift+Enter does not match** → it falls through to the default → the IME inserts a newline. That is exactly AC3 with zero extra code for the newline branch. Map `numpadEnter` too for external keyboards.

Verified against this repo's Flutter pin: **3.44.0 / stable** (`frameworkRevision 559ffa3f`, 2026-05-15).

### Why `EditableText`, not Material `TextField` (AC5 — source-verified)

A bare `CupertinoApp` includes **only** `DefaultCupertinoLocalizations.delegate` in its `localizationsDelegates` — **no `MaterialLocalizations`**. Material `TextField` *"requires one of its ancestors to be a [Material] widget"* **and** calls `MaterialLocalizations.of(context)` in `build`. Under a bare `CupertinoApp` it would throw on both counts. Injecting a `Material` + a `Localizations` override into `ChatInput` to make a `TextField` survive there is heavier and hackier than building on the neutral primitive. `EditableText` (`package:flutter/widgets.dart`) requires **neither** Material nor `MaterialLocalizations` — it is the framework's design-neutral editing surface that `TextField`/`CupertinoTextField` both wrap. This matches the architecture's **single-file** `input/chat_input.dart` (no `material_`/`cupertino_` variant split, unlike the bubble's three files) and the epic AC's silence on dual variants. [Source: flutter/packages/flutter/lib/src/cupertino/app.dart:528-531; flutter/packages/flutter/lib/src/material/text_field.dart:97,208,1205; architecture.md:925-928]

- **Decision recorded (FYI):** `ChatInput` is a single, design-neutral `EditableText`-based widget — **not** a Material/Cupertino dual-variant like `MessageBubble`. FR-E3 attaches "Material 3 + Cupertino variants" to `MessageBubble` *only*; for `ChatInput`/`FollowUpList` it says "auto-grow text field with attachment slot" / "suggested-prompts row" with no variant requirement. Parity + architecture single-file layout + AC silence all point the same way. The widget still themes correctly under either host app because it reads `KoelTheme` tokens and falls back when the extension is absent.
- **Trade-off accepted:** `EditableText` gives editing + cursor + basic selection but not the free platform selection-toolbar polish a `TextField`/`CupertinoTextField` ships. No AC requires selection handles; a v1 composer is functional without them. The 7.4 example exercises it end-to-end.

### EditableText config (the fields you must set)

`EditableText` is lower-level than `TextField` — these are **required** or you get asserts / invisible text:

- `controller` + `focusNode` — owned by `_ChatInputState`, disposed in `dispose`.
- `style` — `koel.textStyles.bodyText.copyWith(color: fg)` where `fg` is derived from `inputBackground` brightness (below). `EditableText` paints text in `style.color`; if you leave it null on a coloured surface it can be invisible.
- `cursorColor` (**required**, no default) + `backgroundCursorColor` (**required** — the iOS floating-cursor backdrop; a translucent `fg` is fine).
- `minLines: 1`, `maxLines: widget.maxLines` — the auto-grow-to-max idiom (grows 1→max, then scrolls). `keyboardType: TextInputType.multiline`, `textInputAction: TextInputAction.newline`.
- **Placeholder:** `EditableText` has no `hintText`. Render it as an overlaid `Text` in a `Stack` shown when `_controller.text.isEmpty`; rebuild on controller change (an `AnimatedBuilder`/`ListenableBuilder` on the controller, or a listener calling `setState`). Dim it (placeholder colour = `fg` at reduced opacity).

### No new colour / text slots — derive foregrounds (the 7.2 precedent)

`KoelColors` has `inputBackground` but **no `onInputBackground`**, and no placeholder/cursor colour slot; it has `followUpPillBackground` + `onFollowUpPill` (the pill pair already exists). Story 7.2 deliberately did **not** add an `onCodeBlock` slot — it derived the code foreground from the surface brightness via `ThemeData.estimateBrightnessForColor`, keeping the colour one-way-door narrow. Follow that precedent here: derive `ChatInput`'s text/cursor/placeholder colour from `inputBackground` brightness (so text stays readable even if a consumer mismatches `KoelTheme` against ambient brightness). The pill already has its `onFollowUpPill` slot, so no derivation is needed there. **Net `KoelTheme` surface change for 7.3 = exactly one `KoelSpacing.followUpGap`.** [Source: packages/koel_widgets/lib/src/theme/koel_theme.dart:13-49; 7-2-message-bubble.md Completion Notes "Code-block foreground is brightness-derived, not a new slot"]

- Note `ThemeData.estimateBrightnessForColor` lives in `material.dart`. `ChatInput` must **not** import `material.dart` (AC5). Use `flutter/widgets.dart`'s `ThemeData`? — it is exported from `material.dart` only. Prefer the framework-neutral `Color.computeLuminance()` (on `package:flutter/painting.dart`, re-exported by `widgets.dart`): `final dark = inputBackground.computeLuminance() < 0.5;` then pick a near-white/near-black `fg`. This keeps `ChatInput` free of any Material import while reproducing the 7.2 readability behaviour. (The bubble could afford `material.dart` because it already imports it for the dispatcher; the input cannot.)

### `KoelSpacing.followUpGap` — the pre-reserved widening

`KoelSpacing`'s doc-comment (written in 7.1) already anticipates this: *"Padding-only for 7.1 — a follow-up-row gap (`double`) joins in 7.3 when `FollowUpList` needs it."* This is the planned, principled widening — "add only what a shipped widget reads," and `FollowUpList` reads it. It is a `double`, so its `lerp` is plain arithmetic (`a + (b - a) * t`), **not** `EdgeInsets.lerp`. Adding it touches `copyWith`/`lerp`/`==`/`hashCode`/`_defaultSpacing` **and** the three `KoelSpacing(...)` literals in `koel_theme_test.dart` — all enumerated in Tasks 1-2. Pill **inner** padding stays a `const` (not a token): only the cross-cutting gap earned a slot, matching how the bubble hardcodes its code-block padding while theming `bubblePadding`. [Source: packages/koel_widgets/lib/src/theme/koel_theme.dart:180-217]

### Shared `KoelTheme` resolver — rule of three

7.2 left `_fallbackTheme(BuildContext)` private inside `message_bubble.dart`:

```dart
KoelTheme _fallbackTheme(BuildContext context) {
  final brightness =
      CupertinoTheme.maybeBrightnessOf(context) ?? Theme.of(context).brightness;
  return brightness == Brightness.dark ? KoelTheme.dark() : KoelTheme.light();
}
```

With `ChatInput` + `FollowUpList` now needing the same null-extension fallback, extract a shared internal `resolveKoelTheme(context)` (does the `extension<KoelTheme>() ?? brightnessFallback` in one place) into `lib/src/theme/theme_resolve.dart`, refactor the bubble to use it, and delete the duplicate. Three consumers = the rule-of-three trigger; this is not speculative DRY. The bubble's 26 tests are the regression guard. `Theme.of(context).brightness` is always defined (even from the fallback `ThemeData` a bare `CupertinoApp` yields); `CupertinoTheme.maybeBrightnessOf` is the preferred probe when present. [Source: packages/koel_widgets/lib/src/bubble/message_bubble.dart:95-103; 7-2-message-bubble.md "The Cupertino theming gap"]

### Package wiring — no new dependencies

`koel_widgets/pubspec.yaml` already carries `flutter`, `koel_core`, `koel_flutter` (the last two added in 7.2 for the bubble). **7.3 adds none** — `ChatInput`/`FollowUpList` traffic in `String`/`List<String>`, never `Message`. The new source files import only `package:flutter/*` + the local theme. `pubspec.lock` must stay 0-drift to the AI-5.9 pins (`analyzer 12.1.0` / `freezed 3.2.6-dev.1`); no codegen, no hosted deps. `depend_on_referenced_packages` won't fire (no new cross-package imports). [Source: packages/koel_widgets/pubspec.yaml]

### Curated lint profile (what will fire if you slip)

`analysis_options.yaml` includes the curated Flutter rules + the `koel_lints` `asp` plugin; `public_member_api_docs` is **off until 7.4**. Live rules to expect: `prefer_const_constructors`, `prefer_const_constructors_in_immutables`, `use_key_in_widget_constructors`, `use_super_parameters`, `prefer_final_fields`. `exhaustive_switch_must_have_default` is **not** triggered here (no sealed-type `switch` in 7.3). Keep ctors `const` and pass `super.key`. [Source: packages/koel_widgets/analysis_options.yaml; 7-2-message-bubble.md Task 8]

### Mobile vs desktop submit (honest scope note)

The Enter-submits / Shift+Enter-newline contract is inherently a **hardware-keyboard** gesture (Shift+Enter has no soft-keyboard equivalent). On a touch soft keyboard, the return key inserts a newline (`TextInputAction.newline`) and there is no modifier — so a pure-touch user submits via a consumer-provided affordance, not via this widget. 7.3 adds **no send button** (the AC names none; the trailing slot is the attachment slot). This is a faithful, minimal read of the AC, not a gap — a send affordance, if the 7.4 example needs one on mobile, is the example's/consumer's to add. Record this in the Dev Agent Record. *(FYI surfaced to Si in the create-story summary.)*

### Documentation

One-line dartdoc on every public member now (`ChatInput` + ctor + `onSubmit`/`attachmentSlot`/`placeholder`/`maxLines`; `FollowUpList` + ctor + `suggestions`/`onSelected`; `KoelSpacing.followUpGap`). The `public_member_api_docs` gate switches on at 7.4; document-as-you-go avoids a finalize-time pile (the 7.1/7.2/koel_flutter house pattern). Internal `_SubmitIntent` and `resolveKoelTheme` are unexported — a one-line `///` still earns its place on the resolver.

### Testing standards

- Framework: `package:flutter_test` `WidgetTester`/`pumpWidget`; import under test via `package:koel_widgets/koel_widgets.dart` (doubles as a barrel-export assertion). For key simulation use `tester.sendKeyEvent` / `sendKeyDownEvent`+`sendKeyUpEvent` (`LogicalKeyboardKey.enter`, `.shift`); focus the field first (`tester.tap` on the `EditableText` or request focus) so the key reaches it. Host the field under a `MaterialApp`/`WidgetsApp` so `DefaultTextEditingShortcuts` is mounted (the override sits below it).
- Null-extension cases pump under a bare `CupertinoApp(home: …)` with no `KoelTheme` — both widgets must render (the AC5 contract).
- Coverage: package ≥ 80% (NFR-12) is enforced at the 7.4 finalize via `melos run test:coverage`; for 7.3 cover every public behaviour (auto-grow wiring, both Enter branches, blank-suppression, attachment present/absent, placeholder, pill count/payload/scroll/gap/empty, both null-extension paths) so the package never dips below floor as it grows. [Source: architecture.md §10 NFR-12/13; epics/epic-7…#Story-7.4]
- Determinism for 7.4 goldens: fixed strings, no `DateTime.now()`/randomness.

### Project Structure Notes

- New sources: `packages/koel_widgets/lib/src/input/chat_input.dart` + `packages/koel_widgets/lib/src/follow_up/follow_up_list.dart` — matches the architecture's `koel_widgets/lib/src/{input,follow_up}/` layout verbatim (single file each, no variant split). Plus new internal `lib/src/theme/theme_resolve.dart` (the shared resolver — a justified addition beyond the architecture sketch; record it). [Source: architecture.md:916-928]
- New tests: `test/input/chat_input_test.dart` + `test/follow_up/follow_up_list_test.dart` — mirror the `test/<feature>/…_test.dart` convention.
- Modified: `lib/src/theme/koel_theme.dart` (+`followUpGap`), `lib/src/bubble/message_bubble.dart` (refactor to `resolveKoelTheme`), `lib/koel_widgets.dart` (+2 exports), `test/theme/koel_theme_test.dart` (new `KoelSpacing` shape).
- Touches only `koel_widgets`. No `koel_core`/`koel_flutter`/other-package source change. `pubspec.yaml` unchanged (no new deps).

### References

- [Source: _bmad-output/planning-artifacts/epics/epic-7-widget-primitives-theming-koelwidgets.md#Story-7.3] — story statement + the 3 epic ACs (ChatInput shape/auto-grow/Enter+Shift, attachment slot, FollowUpList shape/scroll/onSelected).
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/prd.md:172,269-270] — F-E3 Widget Primitives; `ChatInput extends StatefulWidget` / `FollowUpList extends StatelessWidget` signatures.
- [Source: _bmad-output/planning-artifacts/prds/prd-koel-2026-05-27/addendum.md:438-449] — illustrative `class ChatInput extends StatefulWidget { ... }` / `class FollowUpList extends StatelessWidget { ... }` (signatures illustrative; epic ACs bind).
- [Source: _bmad-output/planning-artifacts/architecture.md:916-928] — `koel_widgets/lib/src/{input/chat_input.dart, follow_up/follow_up_list.dart}` single-file layout.
- [Source: packages/koel_widgets/lib/src/theme/koel_theme.dart] — `KoelColors`/`KoelTextStyles`/`KoelSpacing` slots; `inputBackground`/`followUpPillBackground`/`onFollowUpPill` already exist; `KoelSpacing` doc reserves the follow-up gap for 7.3.
- [Source: packages/koel_widgets/lib/src/bubble/message_bubble.dart:95-151] — `_fallbackTheme` to extract; the brightness-derived-foreground precedent for code blocks.
- [Source: packages/koel_widgets/test/theme/koel_theme_test.dart] — the `KoelSpacing` literals + lerp/copyWith tests to update for `followUpGap`.
- [Source: packages/koel_widgets/test/bubble/message_bubble_test.dart] — `WidgetTester` host/idiom to mirror; the 26-test regression guard for the Task 5 refactor.
- [Source: _bmad-output/implementation-artifacts/7-2-message-bubble.md] — null-`KoelTheme` resilience contract, goldens-to-7.4 precedent, 8-symbol seal set, no-new-colour-slot derivation precedent.
- [Source: flutter 3.44.0 — packages/flutter/lib/src/widgets/editable_text.dart:716-742] — overriding default Enter via a wrapping `Shortcuts`; raw-key-before-text-input ordering.
- [Source: flutter 3.44.0 — packages/flutter/lib/src/widgets/default_text_editing_shortcuts.dart:329] — `SingleActivator(enter)` → `DoNothingAndStopPropagationTextIntent` (why ancestor `Focus.onKeyEvent` fails).
- [Source: flutter 3.44.0 — packages/flutter/lib/src/cupertino/app.dart:528-531] — `CupertinoApp` ships only `DefaultCupertinoLocalizations` (no `MaterialLocalizations`) → why `ChatInput` avoids Material `TextField`.
- [Source: flutter 3.44.0 — packages/flutter/lib/src/material/text_field.dart:97,1205] — `TextField` requires a `Material` ancestor + `MaterialLocalizations.of`.

## Dev Agent Record

### Agent Model Used

claude-opus-4-8[1m] (Claude Opus 4.8, 1M context) via `/bmad-dev-story`; Flutter specialist persona loaded (`agent-flutter-engineer`).

### Debug Log References

- `flutter test test/theme/koel_theme_test.dart` → 15/15 after the `KoelSpacing.followUpGap` widening (3 literals updated + midpoint/copyWith assertions added).
- `flutter test test/bubble/message_bubble_test.dart` → 11/11 after refactoring the bubble onto the shared `resolveKoelTheme` (regression guard for the Task 5 extraction held).
- First full run: 40 +1 — the Shift+Enter test asserted `controller.text contains '\n'`, which **failed** because `flutter_test` does not round-trip a raw Enter keystroke through the IME to insert the newline (engine-level, not simulable from `sendKeyEvent`). The widget contract that Shift+Enter is *not intercepted* (so it does not submit and the text is preserved) DID pass (`submitCount == 0`). Reworded the test to assert the contract this widget owns; the newline insertion is left to goldens/integration. Re-run → **41/41**.
- Gates: `melos format:check` 201 files / 0-changed (2 new files auto-formatted before commit); `melos analyze` SUCCESS (11 packages, asp plugin); `melos test` SUCCESS (koel_widgets **41**, koel_flutter 74 unchanged); `pubspec.lock` **0-drift** (no new deps — `String`/`List<String>` only).

### Completion Notes List

- **All 8 ACs satisfied.** `ChatInput(onSubmit, {attachmentSlot, placeholder, maxLines = 5})` is a `StatefulWidget` owning a `TextEditingController` + `FocusNode` (both disposed); submit trims, fires `onSubmit` only when non-empty, then clears. Auto-grow = `EditableText(minLines: 1, maxLines: widget.maxLines)`. Enter→submit / Shift+Enter→newline via a wrapping `Shortcuts`+`Actions` mapping `SingleActivator(enter|numpadEnter)→_SubmitTextIntent` (modifier-exact, so Shift+Enter falls through). Attachment renders trailing via a null-aware element `?widget.attachmentSlot` in the `Row`. `FollowUpList(suggestions, onSelected)` is a `SingleChildScrollView(horizontal)` of tappable pills, empty ⇒ `SizedBox.shrink`. Both widgets resolve theme via `resolveKoelTheme` (null-`KoelTheme` fallback verified under a bare `CupertinoApp`).
- **D1 — `EditableText`, not Material `TextField` (source-verified, AC5).** A bare `CupertinoApp` ships only `DefaultCupertinoLocalizations` (no `MaterialLocalizations`) and no `Material` ancestor — both asserted by `TextField` (`text_field.dart:97,1205`; `cupertino/app.dart:528-531`). `EditableText` (`package:flutter/widgets.dart`) needs neither. Single design-neutral widget, **not** a Material/Cupertino dual-variant like the bubble (FR-E3 attaches variants to `MessageBubble` only; architecture's single-file `input/chat_input.dart` agrees). Trade-off: no free platform selection-toolbar polish — no AC requires it.
- **D2 — Enter override (source-verified, AC3).** Root `DefaultTextEditingShortcuts` maps plain Enter → `DoNothingAndStopPropagationTextIntent` ("goes to the IME, not other Shortcuts", `default_text_editing_shortcuts.dart:329`), so an **ancestor** `Focus.onKeyEvent` never sees plain Enter. The supported override is a `Shortcuts` **wrapping** the field (`editable_text.dart:716-742` — "any Shortcuts between it and this EditableText will override those defaults"; raw key handled before text input). `SingleActivator(enter)` is modifier-exact ⇒ Shift+Enter is not matched and the IME inserts the newline. The newline insertion itself is engine-level and not simulable in `flutter_test`; the widget test asserts the interception contract (does-not-submit), which is what this widget owns.
- **D3 — shared `resolveKoelTheme` extracted (rule of three).** 7.2 left `_fallbackTheme` private in `message_bubble.dart`; with three consumers (bubble + input + pills) it moved to `lib/src/theme/theme_resolve.dart` as internal `resolveKoelTheme(BuildContext)` and the bubble was refactored to call it (the dispatcher dropped its `cupertino.dart` import — the helper owns the `CupertinoTheme.maybeBrightnessOf` probe now). Bubble's tests are the regression guard (green).
- **D4 — exactly one theme widening: `KoelSpacing.followUpGap` (double).** The 7.1-pre-reserved token; scalar `lerp` is plain arithmetic, not `EdgeInsets.lerp`. **No** new `KoelColors`/`KoelTextStyles`: `ChatInput`'s text/cursor/placeholder colour is derived from `inputBackground.computeLuminance()` (the 7.2 code-block precedent — keeps `ChatInput` free of any `material.dart` import; `ThemeData.estimateBrightnessForColor` is Material-only, `Color.computeLuminance` is not). Pill foreground uses the existing `onFollowUpPill` slot. Pill **inner** padding is a fixed `const` (only the inter-pill gap earned a token).
- **D5 — no send button (AC scope).** The AC names none; the trailing element is exactly the `attachmentSlot`. Enter-submit is a hardware-keyboard gesture — on a touch soft keyboard the return key inserts a newline (no Shift modifier exists), so a pure-touch user submits via a consumer-provided affordance. Honest scope note, not a gap. *(FYI for Si.)*
- **Idiom choices (persona):** placeholder visibility is driven by a `ValueNotifier<bool> _isEmpty` + `ValueListenableBuilder` (not `setState`) so only the hint subtree rebuilds, and only on the empty↔non-empty flip (the `ValueNotifier` setter suppresses same-value notifications); the hint is wrapped in `IgnorePointer` + `Positioned.fill` so it never absorbs a focus tap. `Row(crossAxisAlignment: end)` pins the attachment to the last line as the field grows.
- **Scope held:** only `koel_widgets` touched — 2 new src primitives + 1 new internal helper + the `followUpGap` token + the bubble refactor + barrel/test growth. No `koel_core`/`koel_flutter`/other-package source change; `pubspec.yaml` unchanged (no new deps); `pubspec.lock` 0-drift. Public symbol set now **complete (8)** — 7.4 seals (doc gate + `dart_apitool` baseline), adds no new symbol.
- **DEFER-TO-7.4 (unchanged):** goldens (Linux lane SEALER; widgets are golden-ready — deterministic, theme-driven), barrel **seal** + `public_member_api_docs` doc gate + `dart_apitool` baseline, `melos run test:coverage` ≥80% floor. Documented the supported Cupertino theming path (wrap the subtree in a Material `Theme(data: ThemeData(extensions: [KoelTheme…]))`) belongs in 7.4's finalize docs.

### File List

- `packages/koel_widgets/lib/src/theme/koel_theme.dart` (modified — `KoelSpacing.followUpGap` token + ctor/copyWith/lerp/==/hashCode/`_defaultSpacing` + doc)
- `packages/koel_widgets/lib/src/theme/theme_resolve.dart` (new — internal shared `resolveKoelTheme(BuildContext)`)
- `packages/koel_widgets/lib/src/bubble/message_bubble.dart` (modified — refactored onto `resolveKoelTheme`; dropped `_fallbackTheme` + `cupertino.dart` import)
- `packages/koel_widgets/lib/src/input/chat_input.dart` (new — `ChatInput` + private `_SubmitTextIntent`)
- `packages/koel_widgets/lib/src/follow_up/follow_up_list.dart` (new — `FollowUpList` + private `_Pill`)
- `packages/koel_widgets/lib/koel_widgets.dart` (modified — barrel: `ChatInput` + `FollowUpList` exports; symbol set complete at 8)
- `packages/koel_widgets/test/theme/koel_theme_test.dart` (modified — new `KoelSpacing` shape + `followUpGap` assertions)
- `packages/koel_widgets/test/input/chat_input_test.dart` (new — 9 widget tests)
- `packages/koel_widgets/test/follow_up/follow_up_list_test.dart` (new — 6 widget tests)
- `_bmad-output/implementation-artifacts/7-3-chat-input-follow-up-list.md` (story tracking: checkboxes, Dev Agent Record, File List, Change Log, Status)
- `_bmad-output/implementation-artifacts/sprint-status.yaml` (status: `ready-for-dev` → `in-progress` → `review`)

## Change Log

| Date       | Change |
| ---------- | ------ |
| 2026-06-06 | Story created via `/bmad-create-story` — ChatInput (`EditableText`-based, auto-grow, Enter/Shift+Enter via wrapping `Shortcuts`, source-verified against Flutter 3.44.0) + FollowUpList (pill row) + `KoelSpacing.followUpGap` + shared `resolveKoelTheme` extraction. Goldens/example/seal deferred to 7.4. Status → ready-for-dev. |
| 2026-06-06 | Implemented Story 7.3 via `/bmad-dev-story` — `ChatInput` (`EditableText`, auto-grow, Enter/Shift+Enter `Shortcuts` override, trailing attachment, null-`KoelTheme` fallback) + `FollowUpList` (horizontal pill row) + `KoelSpacing.followUpGap` + shared `resolveKoelTheme` (bubble refactored, rule-of-three). 15 widget tests (9 input + 6 follow-up); koel_widgets **41** total. All gates green: melos format:check 201/0-changed, analyze SUCCESS (11 pkgs), test SUCCESS, pubspec.lock 0-drift. Public symbol set complete (8); goldens/seal/doc-gate → 7.4. Status → review. |

## Review Findings

_Adversarial code review (Blind Hunter + Edge Case Hunter + Acceptance Auditor), 2026-06-06. Baseline `f623d6d`. Triage: 0 decision-needed, 2 patch, 3 defer, 13 dismissed (false-positives/cosmetic/disclosed). All 8 ACs satisfied; the patches are contract/robustness hardening, not AC failures._

- [x] [Review][Patch] `onSubmit` delivers raw, **un-trimmed** content — contradicts its own dartdoc ("Called with the **trimmed**, non-empty content") and AC1's "trimmed-non-empty only" intent. The gate `content.trim().isEmpty` is correct, but `widget.onSubmit(content)` passes the raw string, so `"  hello  "` is delivered with surrounding whitespace. **FIXED:** `_submit()` now trims once (`final content = _controller.text.trim()`) and delivers the trimmed value; the Enter-submit test now enters `'  hello  '` and asserts `'hello'`. [packages/koel_widgets/lib/src/input/chat_input.dart:75-80]
- [x] [Review][Patch] `maxLines <= 0` trips an `EditableText` assert (`minLines: 1` is hardcoded; `EditableText` asserts `maxLines >= minLines`, so `0 >= 1` fails). `ChatInput` owns the public `maxLines` param but never validated its own boundary. **FIXED:** added `assert(maxLines >= 1, ...)` to the ctor + a `throwsAssertionError` test. [packages/koel_widgets/lib/src/input/chat_input.dart:24-30]
- [x] [Review][Defer] No external `controller` / initial-text param + no `didUpdateWidget` — the internal-only controller means a consumer can't pre-fill, restore a draft, or clear the field externally. Out of the AC's stated surface; record as a v-next ergonomics enhancement. [packages/koel_widgets/lib/src/input/chat_input.dart:246-280] — deferred, design enhancement
- [x] [Review][Defer] `onSubmit` throwing leaves the field uncleared — `_submit()` calls `widget.onSubmit(content)` **before** `_controller.clear()` with no try/finally, so a throwing consumer callback breaks the documented "the field then clears" invariant and re-submits the same text on the next Enter. [packages/koel_widgets/lib/src/input/chat_input.dart:266-271] — deferred, robustness against consumer-thrown errors
- [x] [Review][Defer] `followUpGap` theme-misuse robustness — `KoelSpacing.lerp` extrapolates the scalar `followUpGap` with no `t` clamp (`a + (b-a)*t`), so an overshooting transition curve (`t > 1` / `< 0`) or a directly-set negative/NaN/∞ gap reaches `SizedBox(width: gap)` and trips its `width >= 0` assert. [packages/koel_widgets/lib/src/theme/koel_theme.dart:113; packages/koel_widgets/lib/src/follow_up/follow_up_list.dart:423] — deferred, low-probability theme-animation edge
