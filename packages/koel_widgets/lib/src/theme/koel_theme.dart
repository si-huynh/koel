import 'package:flutter/material.dart';

/// Color slots every koel widget paints with (F-E4).
///
/// Each field is a single semantic role — bubble fills, the readable
/// text-on-bubble pair, the input surface, code-block background, and the
/// follow-up pill — not a raw Material `ColorScheme`. Widgets read a named slot
/// instead of deriving a colour, so a consumer retheme is one slot override, not
/// a fork. Immutable + `const`; slots grow with the widgets that consume them
/// (7.2 `MessageBubble`, 7.3 `ChatInput`/`FollowUpList`), so treat the set as a
/// one-way door — add only what a shipped widget reads.
@immutable
class KoelColors {
  /// Creates a fully-specified color slot set; every slot is required so no
  /// widget can read a null colour.
  const KoelColors({
    required this.messageBubbleUser,
    required this.messageBubbleAssistant,
    required this.onMessageBubbleUser,
    required this.onMessageBubbleAssistant,
    required this.inputBackground,
    required this.codeBlockBackground,
    required this.followUpPillBackground,
    required this.onFollowUpPill,
  });

  /// Background fill of a user-authored message bubble (7.2).
  final Color messageBubbleUser;

  /// Background fill of an assistant message bubble (7.2).
  final Color messageBubbleAssistant;

  /// Text/icon colour painted on [messageBubbleUser] (7.2).
  final Color onMessageBubbleUser;

  /// Text/icon colour painted on [messageBubbleAssistant] (7.2).
  final Color onMessageBubbleAssistant;

  /// Background fill of the chat input field (7.3 `ChatInput`).
  final Color inputBackground;

  /// Background fill of a fenced code-block segment (7.2, from F-E1 parsing).
  final Color codeBlockBackground;

  /// Background fill of a follow-up suggestion pill (7.3 `FollowUpList`).
  final Color followUpPillBackground;

  /// Text colour painted on [followUpPillBackground] (7.3).
  final Color onFollowUpPill;

  /// Returns a copy with the named slots replaced and all others preserved.
  KoelColors copyWith({
    Color? messageBubbleUser,
    Color? messageBubbleAssistant,
    Color? onMessageBubbleUser,
    Color? onMessageBubbleAssistant,
    Color? inputBackground,
    Color? codeBlockBackground,
    Color? followUpPillBackground,
    Color? onFollowUpPill,
  }) => KoelColors(
    messageBubbleUser: messageBubbleUser ?? this.messageBubbleUser,
    messageBubbleAssistant:
        messageBubbleAssistant ?? this.messageBubbleAssistant,
    onMessageBubbleUser: onMessageBubbleUser ?? this.onMessageBubbleUser,
    onMessageBubbleAssistant:
        onMessageBubbleAssistant ?? this.onMessageBubbleAssistant,
    inputBackground: inputBackground ?? this.inputBackground,
    codeBlockBackground: codeBlockBackground ?? this.codeBlockBackground,
    followUpPillBackground:
        followUpPillBackground ?? this.followUpPillBackground,
    onFollowUpPill: onFollowUpPill ?? this.onFollowUpPill,
  );

  /// Interpolates every slot toward [other] by [t] via [Color.lerp].
  ///
  /// Both endpoints are non-null, so each `Color.lerp` result is asserted
  /// non-null with `!`.
  KoelColors lerp(KoelColors other, double t) => KoelColors(
    messageBubbleUser: Color.lerp(
      messageBubbleUser,
      other.messageBubbleUser,
      t,
    )!,
    messageBubbleAssistant: Color.lerp(
      messageBubbleAssistant,
      other.messageBubbleAssistant,
      t,
    )!,
    onMessageBubbleUser: Color.lerp(
      onMessageBubbleUser,
      other.onMessageBubbleUser,
      t,
    )!,
    onMessageBubbleAssistant: Color.lerp(
      onMessageBubbleAssistant,
      other.onMessageBubbleAssistant,
      t,
    )!,
    inputBackground: Color.lerp(inputBackground, other.inputBackground, t)!,
    codeBlockBackground: Color.lerp(
      codeBlockBackground,
      other.codeBlockBackground,
      t,
    )!,
    followUpPillBackground: Color.lerp(
      followUpPillBackground,
      other.followUpPillBackground,
      t,
    )!,
    onFollowUpPill: Color.lerp(onFollowUpPill, other.onFollowUpPill, t)!,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KoelColors &&
          other.messageBubbleUser == messageBubbleUser &&
          other.messageBubbleAssistant == messageBubbleAssistant &&
          other.onMessageBubbleUser == onMessageBubbleUser &&
          other.onMessageBubbleAssistant == onMessageBubbleAssistant &&
          other.inputBackground == inputBackground &&
          other.codeBlockBackground == codeBlockBackground &&
          other.followUpPillBackground == followUpPillBackground &&
          other.onFollowUpPill == onFollowUpPill;

  @override
  int get hashCode => Object.hash(
    messageBubbleUser,
    messageBubbleAssistant,
    onMessageBubbleUser,
    onMessageBubbleAssistant,
    inputBackground,
    codeBlockBackground,
    followUpPillBackground,
    onFollowUpPill,
  );
}

/// Text styles every koel widget renders with (F-E4).
///
/// The colour of rendered text comes from the `onX` slots in [KoelColors], so
/// these styles carry geometry (size, height, family) and stay palette-agnostic
/// — `light()` and `dark()` share one const instance. Immutable + `const`.
@immutable
class KoelTextStyles {
  /// Creates a fully-specified text-style set.
  const KoelTextStyles({required this.bodyText, required this.codeText});

  /// Style for prose runs (text segments from F-E1).
  final TextStyle bodyText;

  /// Style for monospace fenced code blocks (F-E1).
  final TextStyle codeText;

  /// Returns a copy with the named styles replaced and all others preserved.
  KoelTextStyles copyWith({TextStyle? bodyText, TextStyle? codeText}) =>
      KoelTextStyles(
        bodyText: bodyText ?? this.bodyText,
        codeText: codeText ?? this.codeText,
      );

  /// Interpolates each style toward [other] by [t] via [TextStyle.lerp].
  KoelTextStyles lerp(KoelTextStyles other, double t) => KoelTextStyles(
    bodyText: TextStyle.lerp(bodyText, other.bodyText, t)!,
    codeText: TextStyle.lerp(codeText, other.codeText, t)!,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KoelTextStyles &&
          other.bodyText == bodyText &&
          other.codeText == codeText;

  @override
  int get hashCode => Object.hash(bodyText, codeText);
}

/// Spacing tokens every koel widget lays out with (F-E4).
///
/// Padding-only for 7.1 — a follow-up-row gap (`double`) joins in 7.3 when
/// `FollowUpList` needs it. Immutable + `const`.
@immutable
class KoelSpacing {
  /// Creates a fully-specified spacing token set.
  const KoelSpacing({required this.bubblePadding, required this.inputPadding});

  /// Inner padding of a message bubble (7.2).
  final EdgeInsets bubblePadding;

  /// Inner padding of the chat input field (7.3 `ChatInput`).
  final EdgeInsets inputPadding;

  /// Returns a copy with the named tokens replaced and all others preserved.
  KoelSpacing copyWith({EdgeInsets? bubblePadding, EdgeInsets? inputPadding}) =>
      KoelSpacing(
        bubblePadding: bubblePadding ?? this.bubblePadding,
        inputPadding: inputPadding ?? this.inputPadding,
      );

  /// Interpolates each token toward [other] by [t] via [EdgeInsets.lerp].
  KoelSpacing lerp(KoelSpacing other, double t) => KoelSpacing(
    bubblePadding: EdgeInsets.lerp(bubblePadding, other.bubblePadding, t)!,
    inputPadding: EdgeInsets.lerp(inputPadding, other.inputPadding, t)!,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KoelSpacing &&
          other.bubblePadding == bubblePadding &&
          other.inputPadding == inputPadding;

  @override
  int get hashCode => Object.hash(bubblePadding, inputPadding);
}

// Shared, palette-agnostic geometry — light()/dark() differ only in colours, so
// these const instances are reused across both factories (no per-call alloc).
const KoelTextStyles _defaultTextStyles = KoelTextStyles(
  bodyText: TextStyle(fontSize: 14, height: 1.4),
  codeText: TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.45),
);

const KoelSpacing _defaultSpacing = KoelSpacing(
  bubblePadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
  inputPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
);

/// koel's theming hook: a [ThemeExtension] carrying every colour, text style,
/// and spacing token koel widgets consume (F-E4 / Addendum A.7).
///
/// Consumers attach it once — `MaterialApp(theme: ThemeData(extensions: [const
/// KoelTheme.light()...]))` — and widgets read it via
/// `Theme.of(context).extension<KoelTheme>()`. As a `ThemeExtension`, it
/// participates in `ThemeData` equality (rebuild suppression) and animates
/// across theme switches through [lerp].
@immutable
class KoelTheme extends ThemeExtension<KoelTheme> {
  /// Creates a theme from its three token groups; all required so no slot is
  /// ever unset.
  const KoelTheme({
    required this.colors,
    required this.textStyles,
    required this.spacing,
  });

  /// A Material 3 light-palette default theme.
  factory KoelTheme.light() => const KoelTheme(
    colors: KoelColors(
      messageBubbleUser: Color(0xFF6750A4),
      messageBubbleAssistant: Color(0xFFE7E0EC),
      onMessageBubbleUser: Color(0xFFFFFFFF),
      onMessageBubbleAssistant: Color(0xFF1D1B20),
      inputBackground: Color(0xFFF3EDF7),
      codeBlockBackground: Color(0xFFE7E0EC),
      followUpPillBackground: Color(0xFFEADDFF),
      onFollowUpPill: Color(0xFF21005D),
    ),
    textStyles: _defaultTextStyles,
    spacing: _defaultSpacing,
  );

  /// A Material 3 dark-palette default theme; differs from [KoelTheme.light] in
  /// every colour slot.
  factory KoelTheme.dark() => const KoelTheme(
    colors: KoelColors(
      messageBubbleUser: Color(0xFFD0BCFF),
      messageBubbleAssistant: Color(0xFF49454F),
      onMessageBubbleUser: Color(0xFF381E72),
      onMessageBubbleAssistant: Color(0xFFE6E0E9),
      inputBackground: Color(0xFF211F26),
      codeBlockBackground: Color(0xFF1D1B20),
      followUpPillBackground: Color(0xFF4A4458),
      onFollowUpPill: Color(0xFFEADDFF),
    ),
    textStyles: _defaultTextStyles,
    spacing: _defaultSpacing,
  );

  /// Color slots (bubble fills, text-on-bubble, input, code, follow-up).
  final KoelColors colors;

  /// Text styles (prose + monospace code).
  final KoelTextStyles textStyles;

  /// Spacing tokens (bubble + input padding).
  final KoelSpacing spacing;

  @override
  KoelTheme copyWith({
    KoelColors? colors,
    KoelTextStyles? textStyles,
    KoelSpacing? spacing,
  }) => KoelTheme(
    colors: colors ?? this.colors,
    textStyles: textStyles ?? this.textStyles,
    spacing: spacing ?? this.spacing,
  );

  /// Interpolates toward [other] by [t], delegating to each token group's
  /// `lerp`.
  ///
  /// When [other] is `null` or not a [KoelTheme] (the type-mismatch
  /// `ThemeData.lerp` passes during a partial theme switch) the receiver is
  /// returned unchanged — the canonical `ThemeExtension` identity guard, and
  /// what makes `t == 0` evaluate to `this`.
  @override
  KoelTheme lerp(covariant ThemeExtension<KoelTheme>? other, double t) {
    if (other is! KoelTheme) return this;
    return KoelTheme(
      colors: colors.lerp(other.colors, t),
      textStyles: textStyles.lerp(other.textStyles, t),
      spacing: spacing.lerp(other.spacing, t),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KoelTheme &&
          other.colors == colors &&
          other.textStyles == textStyles &&
          other.spacing == spacing;

  @override
  int get hashCode => Object.hash(colors, textStyles, spacing);
}
