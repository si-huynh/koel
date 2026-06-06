import 'package:flutter/material.dart';

/// Material 3 chrome for a `MessageBubble` — a tonally-elevated, rounded surface
/// painted in the role-selected [fill] (F-E3).
///
/// Internal to `koel_widgets`: not exported from the barrel. The bubble's
/// design-language-neutral parts (content parsing, segment styling, role/theme
/// resolution) live in `MessageBubble`; this widget only applies the M3 surface
/// treatment to a pre-built [child].
///
/// The surface is capped at [maxWidth] inside its [Align]: a no-op on a phone
/// (screen narrower than the cap ⇒ the bubble fills width), a reading-width cap
/// on a wide desktop/web window so the role alignment stays meaningful (AI-7.1).
class MaterialBubble extends StatelessWidget {
  /// Wraps [child] in an M3 surface filled with [fill], padded by [padding],
  /// aligned to the trailing edge when [alignEnd] (the user side), and capped at
  /// [maxWidth].
  const MaterialBubble({
    required this.child,
    required this.fill,
    required this.padding,
    required this.alignEnd,
    required this.maxWidth,
    super.key,
  });

  /// The bubble body (the message's rendered segments).
  final Widget child;

  /// Role-selected background fill.
  final Color fill;

  /// Inner padding (`KoelSpacing.bubblePadding`).
  final EdgeInsetsGeometry padding;

  /// Trailing alignment for user turns; leading for everything else.
  final bool alignEnd;

  /// Reading-width cap for the surface (logical px); a no-op below it.
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Material(
        color: fill,
        elevation: 1,
        borderRadius: BorderRadius.circular(16),
        type: MaterialType.card,
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}
