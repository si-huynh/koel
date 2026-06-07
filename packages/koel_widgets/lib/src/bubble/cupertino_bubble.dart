import 'package:flutter/cupertino.dart';

/// Cupertino (iOS) chrome for a `MessageBubble` — a flat, rounded bubble painted
/// in the role-selected [fill] (F-E3).
///
/// Internal to `koel_widgets`: not exported from the barrel. Unlike the Material
/// variant there is no elevation or ink ripple — iOS message bubbles are flat
/// rounded rects. The system font reaches the body through the ambient
/// `CupertinoTheme` text style (the bubble's `bodyText` carries no `fontFamily`,
/// so it inherits), so this widget only applies the iOS surface to a pre-built
/// [child].
///
/// The surface is capped at [maxWidth] inside its [Align]: a no-op on a phone
/// (screen narrower than the cap ⇒ the bubble fills width), a reading-width cap
/// on a wide desktop/web window so the role alignment stays meaningful (AI-7.1).
class CupertinoBubble extends StatelessWidget {
  /// Wraps [child] in an iOS bubble filled with [fill], padded by [padding],
  /// aligned to the trailing edge when [alignEnd] (the user side), and capped at
  /// [maxWidth].
  const CupertinoBubble({
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Padding(padding: padding, child: child),
      ),
    ),
  );
}
