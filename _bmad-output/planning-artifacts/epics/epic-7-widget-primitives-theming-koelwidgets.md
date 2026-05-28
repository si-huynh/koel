# Epic 7: Widget Primitives & Theming — `koel_widgets`

Developer can drop in `MessageBubble` (Material 3 + Cupertino variants), `ChatInput` (auto-grow + attachment slot), `FollowUpList`, and customize via `KoelTheme extends ThemeExtension<KoelTheme>`. UI is opt-in — `koel_widgets` is never required to use `koel_flutter`. Coverage ≥ 80%.

## Story 7.1: `KoelTheme extends ThemeExtension<KoelTheme>`

As a Flutter developer,
I want `KoelTheme` as a `ThemeExtension` carrying color slots, text styles, and spacing tokens that every koel widget consumes via `Theme.of(context).extension<KoelTheme>()`,
So that consumers attach koel theming to their `MaterialApp`/`CupertinoApp` in one declaration per FR-E4.

**Acceptance Criteria:**

**Given** `packages/koel_widgets/lib/src/theme/koel_theme.dart`,
**When** I inspect the class,
**Then** `class KoelTheme extends ThemeExtension<KoelTheme>` is declared with `const KoelTheme({required this.colors, required this.textStyles, required this.spacing})` per Addendum A.7,
**And** the three nested types (`KoelColors`, `KoelTextStyles`, `KoelSpacing`) carry color slots (`messageBubbleUser`, `messageBubbleAssistant`, `inputBackground`, etc.), text styles (`bodyText`, `codeText`, etc.), and spacing tokens (`bubblePadding`, `inputPadding`, etc.).

**Given** `KoelTheme.copyWith(...)` and `KoelTheme.lerp(KoelTheme? other, double t)`,
**When** I exercise them,
**Then** `copyWith` returns the modified theme,
**And** `lerp` interpolates between two themes smoothly for theme-switch animations.

**Given** a default `KoelTheme.light()` + `KoelTheme.dark()` factory,
**When** I render any koel widget under each,
**Then** the widget visually adapts (golden tests in Story 7.4).

## Story 7.2: `MessageBubble` (Material 3 + Cupertino variants)

As a Flutter developer,
I want `MessageBubble` widget rendering a chat message with role-aware styling for both Material 3 and Cupertino design languages, reading `KoelTheme` for tokens,
So that I can drop a bubble into my Flutter app and have it match the platform's design language per FR-E3.

**Acceptance Criteria:**

**Given** `packages/koel_widgets/lib/src/bubble/message_bubble.dart`,
**When** I inspect it,
**Then** `class MessageBubble extends StatelessWidget` accepts a `Message` plus optional `BubbleStyle.material | BubbleStyle.cupertino` override,
**And** picks the platform variant automatically by default (`Theme.of(context).platform`).

**Given** `material_bubble.dart` and `cupertino_bubble.dart`,
**When** I inspect each,
**Then** Material variant uses M3 surface tokens + rounded corners + tonal elevation,
**And** Cupertino variant uses iOS-style background + standard padding + system font.

**Given** a `Message` with mixed `MessageSegment` content (text + code blocks from Story 6.5),
**When** the bubble renders,
**Then** code-block segments display in a monospace `codeText` style with syntax-friendly background per `KoelTheme.colors`,
**And** text segments render with `bodyText` style.

**Given** golden tests for both variants under light + dark `KoelTheme`,
**When** I run them,
**Then** every golden passes (4 goldens minimum: material-light, material-dark, cupertino-light, cupertino-dark).

## Story 7.3: `ChatInput` (auto-grow + attachment slot) + `FollowUpList`

As a Flutter developer,
I want `ChatInput` (auto-growing text field with attachment slot) and `FollowUpList` (suggested-prompts row),
So that drop-in chat composition + follow-up UI is available without manual layout per FR-E3.

**Acceptance Criteria:**

**Given** `packages/koel_widgets/lib/src/input/chat_input.dart`,
**When** I inspect it,
**Then** `class ChatInput extends StatefulWidget` accepts `onSubmit(String content)` + optional `attachmentSlot: Widget?` + optional `placeholder: String`,
**And** the text field auto-grows to a max line count (default 5),
**And** Enter submits + Shift+Enter inserts a newline.

**Given** an attachment slot widget passed,
**When** the input renders,
**Then** the slot appears in the trailing position per design.

**Given** `packages/koel_widgets/lib/src/follow_up/follow_up_list.dart`,
**When** I inspect it,
**Then** `class FollowUpList extends StatelessWidget` accepts `List<String> suggestions` + `void Function(String) onSelected`,
**And** renders a horizontally scrollable row of pill-shaped suggestions reading `KoelTheme` tokens.

**Given** widget tests + golden tests for both widgets,
**When** I run them,
**Then** all pass.

## Story 7.4: Widget tests + golden tests + barrel + example demo

As a Flutter developer,
I want comprehensive widget tests + golden tests covering every `koel_widgets` primitive + a finalized barrel `lib/koel_widgets.dart` + a runnable example demonstrating composition with `koel_flutter`'s `KoelChatController`,
So that the 1.x widget contract is sealed and consumers see a working end-to-end demo per AR-22 (sample app preparation).

**Acceptance Criteria:**

**Given** the barrel `lib/koel_widgets.dart`,
**When** I inspect it,
**Then** it exports exactly: `MessageBubble`, `ChatInput`, `FollowUpList`, `KoelTheme`, `KoelColors`, `KoelTextStyles`, `KoelSpacing`,
**And** `dart_apitool extract` produces a baseline.

**Given** golden tests covering every primitive × Material/Cupertino × light/dark theme,
**When** I run them,
**Then** all goldens pass on the Linux CI lane (deterministic platform for goldens),
**And** the goldens directory `test/goldens/` is committed.

**Given** `packages/koel_widgets/example/`,
**When** I run `flutter run example/lib/main.dart`,
**Then** the app launches showing a chat surface using `MessageBubble` + `ChatInput` + `FollowUpList` driven by a `MockAgent.fromFixture('text_only_run')` from `koel_test`,
**And** the example is exercised as a smoke test in CI per architecture convention §6.

**Given** the package overall,
**When** I run `melos run test:coverage`,
**Then** coverage ≥ 80% per NFR-12,
**And** `dart analyze` exits 0 per NFR-13.

---
