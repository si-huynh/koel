/// Material 3 + Cupertino chat UI primitives (theme, bubble, input, follow-up list).
///
/// This barrel is the **public 1.x contract** of `koel_widgets`. It grows
/// incrementally per story and seals at 7.4 to exactly the widget primitives
/// (`MessageBubble`, `ChatInput`, `FollowUpList`) plus the theming hook below.
library;

// ---- Theming hook: ThemeExtension carrying colours, text, spacing (F-E4) --
export 'src/theme/koel_theme.dart'
    show KoelTheme, KoelColors, KoelTextStyles, KoelSpacing;

// ---- MessageBubble: Material 3 + Cupertino chat bubble (F-E3) -------------
// `BubbleStyle` rides along — it is part of `MessageBubble`'s public ctor, so
// the 7.4 seal set is these 8 symbols, not the epic's literal 7. The internal
// `MaterialBubble`/`CupertinoBubble` variants are deliberately NOT exported.
export 'src/bubble/message_bubble.dart' show MessageBubble, BubbleStyle;

// ---- ChatInput: auto-grow composer + attachment slot (F-E3) ---------------
export 'src/input/chat_input.dart' show ChatInput;

// ---- FollowUpList: horizontally scrollable suggestion pills (F-E3) --------
// With these two the public symbol set is complete (8); 7.4 only seals it
// (doc gate + dart_apitool baseline), adding no new public symbol.
export 'src/follow_up/follow_up_list.dart' show FollowUpList;
