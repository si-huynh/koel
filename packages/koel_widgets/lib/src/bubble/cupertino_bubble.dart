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
class CupertinoBubble extends StatelessWidget {
  /// Wraps [child] in an iOS bubble filled with [fill], padded by [padding], and
  /// aligned to the trailing edge when [alignEnd] (the user side).
  const CupertinoBubble({
    required this.child,
    required this.fill,
    required this.padding,
    required this.alignEnd,
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

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(padding: padding, child: child),
    ),
  );
}
