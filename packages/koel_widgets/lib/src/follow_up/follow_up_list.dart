import 'package:flutter/widgets.dart';

import '../theme/theme_resolve.dart';

/// A horizontally scrollable row of pill-shaped suggestion prompts, reading its
/// fill, label colour, text geometry, and inter-pill gap from the ambient
/// `KoelTheme` (F-E3).
///
/// Tapping a pill invokes [onSelected] with that suggestion. An empty
/// [suggestions] list renders nothing. Like the rest of `koel_widgets` it falls
/// back to a brightness-appropriate default when no `KoelTheme` is attached (see
/// [resolveKoelTheme]).
class FollowUpList extends StatelessWidget {
  /// Creates a follow-up row over [suggestions], reporting taps via
  /// [onSelected].
  const FollowUpList({
    required this.suggestions,
    required this.onSelected,
    super.key,
  });

  /// The suggested prompts, rendered left-to-right.
  final List<String> suggestions;

  /// Called with the tapped suggestion's text.
  final void Function(String suggestion) onSelected;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    final koel = resolveKoelTheme(context);
    final colors = koel.colors;
    final labelStyle = koel.textStyles.bodyText.copyWith(
      color: colors.onFollowUpPill,
    );
    final gap = koel.spacing.followUpGap;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < suggestions.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            _Pill(
              label: suggestions[i],
              fill: colors.followUpPillBackground,
              labelStyle: labelStyle,
              onTap: () => onSelected(suggestions[i]),
            ),
          ],
        ],
      ),
    );
  }
}

/// One tappable suggestion pill — a rounded fill wrapping its label. Pill inner
/// padding is a fixed const (only the inter-pill gap is a theme token).
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.fill,
    required this.labelStyle,
    required this.onTap,
  });

  final String label;
  final Color fill;
  final TextStyle labelStyle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(label, style: labelStyle),
      ),
    ),
  );
}
