/// Material 3 + Cupertino chat UI primitives (theme, bubble, input, follow-up list).
///
/// This barrel is the **public 1.x contract** of `koel_widgets`. It grows
/// incrementally per story and seals at 7.4 to exactly the widget primitives
/// (`MessageBubble`, `ChatInput`, `FollowUpList`) plus the theming hook below.
library;

// ---- Theming hook: ThemeExtension carrying colours, text, spacing (F-E4) --
export 'src/theme/koel_theme.dart'
    show KoelTheme, KoelColors, KoelTextStyles, KoelSpacing;
