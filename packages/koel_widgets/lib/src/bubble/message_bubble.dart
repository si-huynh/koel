import 'package:flutter/material.dart';
import 'package:koel_core/koel_core.dart' show Message, MessageRole;
import 'package:koel_flutter/koel_flutter.dart'
    show CodeBlockSegment, MessageContentParser, MessageSegment, TextSegment;

import '../theme/koel_theme.dart';
import '../theme/theme_resolve.dart';
import 'cupertino_bubble.dart';
import 'material_bubble.dart';

/// Explicit design-language override for a [MessageBubble].
///
/// When passed, it wins over the platform auto-pick; when omitted, the bubble
/// chooses from `Theme.of(context).platform`.
enum BubbleStyle {
  /// Force the Material 3 variant.
  material,

  /// Force the Cupertino (iOS) variant.
  cupertino,
}

/// A chat-message bubble with role-aware styling in either Material 3 or
/// Cupertino design language, reading its colours, text styles, and spacing from
/// the ambient [KoelTheme] (F-E3 / F-E4).
///
/// The variant is picked from `Theme.of(context).platform` by default
/// (`iOS`/`macOS` ⇒ Cupertino, everything else ⇒ Material 3); pass [style] to
/// force one. The bubble parses [message] content into prose + fenced-code
/// segments (Story 6.5's `MessageContentParser`) and paints user turns with the
/// user colour slots, every other role with the assistant slots.
///
/// When no [KoelTheme] is attached to the ambient `ThemeData` — the real case
/// under a bare `CupertinoApp`, which carries no Material `Theme` extension — the
/// bubble falls back to a brightness-appropriate [KoelTheme.light]/[KoelTheme.dark]
/// default rather than throwing, so it renders under any host app.
class MessageBubble extends StatelessWidget {
  /// Creates a bubble for [message], optionally forcing a design language via
  /// [style].
  const MessageBubble(this.message, {this.style, super.key});

  /// The message to render. Only `role` and `content` are read.
  final Message message;

  /// Forces a design language; `null` auto-picks from the platform.
  final BubbleStyle? style;

  @override
  Widget build(BuildContext context) {
    final segments = const MessageContentParser().parse(message.content);
    // An assistant-with-tool-calls turn decodes to `content == ''` (a real wire
    // case) ⇒ no segments. Render nothing rather than an empty padded surface.
    if (segments.isEmpty) return const SizedBox.shrink();

    final koel = resolveKoelTheme(context);
    final isUser = message.role == MessageRole.user;
    final colors = koel.colors;
    final fill = isUser
        ? colors.messageBubbleUser
        : colors.messageBubbleAssistant;
    final onColor = isUser
        ? colors.onMessageBubbleUser
        : colors.onMessageBubbleAssistant;

    final body = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [for (final s in segments) _segmentWidget(s, koel, onColor)],
    );

    final useCupertino =
        style == BubbleStyle.cupertino ||
        (style == null && _isApple(Theme.of(context).platform));
    return useCupertino
        ? CupertinoBubble(
            fill: fill,
            padding: koel.spacing.bubblePadding,
            alignEnd: isUser,
            child: body,
          )
        : MaterialBubble(
            fill: fill,
            padding: koel.spacing.bubblePadding,
            alignEnd: isUser,
            child: body,
          );
  }
}

/// `{iOS, macOS}` are the Apple platforms that get the Cupertino variant.
bool _isApple(TargetPlatform platform) =>
    platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;

/// Renders one [MessageSegment]: prose in `bodyText` tinted by the role's
/// [onColor], a fenced block in `codeText` on the `codeBlockBackground` surface.
///
/// The trailing `_` arm satisfies `koel_lints`'
/// `exhaustive_switch_must_have_default`: adding a `MessageSegment` leaf must
/// stay a semver-minor bump (FR-A12), so the arm makes that leaf degrade to
/// empty here instead of breaking this switch. It is redundant only for today's
/// two-leaf snapshot — hence the analyzer `unreachable_switch_case` is silenced
/// deliberately; it becomes live the moment a third leaf ships.
Widget _segmentWidget(MessageSegment segment, KoelTheme koel, Color onColor) =>
    switch (segment) {
      TextSegment(:final text) => Text(
        text,
        style: koel.textStyles.bodyText.copyWith(color: onColor),
      ),
      CodeBlockSegment(:final code) => _codeBlock(code, koel),
      // ignore: unreachable_switch_case
      _ => const SizedBox.shrink(),
    };

/// A fenced code block: monospace `codeText` on the theme's code surface, its
/// foreground derived from the surface brightness so it stays readable even when
/// the consumer mismatches `KoelTheme` against the ambient app brightness.
Widget _codeBlock(String code, KoelTheme koel) {
  final background = koel.colors.codeBlockBackground;
  final foreground =
      ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? const Color(0xFFECECEC)
      : const Color(0xFF1B1B1B);
  return Padding(
    // Separate the fenced block from adjacent prose runs in a mixed message.
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Text(
          code,
          style: koel.textStyles.codeText.copyWith(color: foreground),
        ),
      ),
    ),
  );
}
