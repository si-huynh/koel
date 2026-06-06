import 'package:flutter/cupertino.dart' show CupertinoTheme;
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'koel_theme.dart';

/// Resolves the [KoelTheme] every koel widget paints with: the ambient
/// `ThemeData.extensions` entry when present, else a brightness-appropriate
/// [KoelTheme.light]/[KoelTheme.dark] default.
///
/// The fallback is load-bearing, not defensive: a bare `CupertinoApp` wraps its
/// subtree in a `CupertinoTheme`, **not** a Material `Theme`, so
/// `Theme.of(context).extension<KoelTheme>()` is `null` there. Without this a
/// koel widget would crash in the exact host app a Cupertino consumer ships.
/// Brightness is sourced from `CupertinoTheme.maybeBrightnessOf` first (defined
/// under a bare `CupertinoApp`, where `Theme.of` only yields a fallback
/// `ThemeData`), else `Theme.of(context).brightness` (always defined).
KoelTheme resolveKoelTheme(BuildContext context) {
  final theme = Theme.of(context).extension<KoelTheme>();
  if (theme != null) return theme;
  final brightness =
      CupertinoTheme.maybeBrightnessOf(context) ?? Theme.of(context).brightness;
  return brightness == Brightness.dark ? KoelTheme.dark() : KoelTheme.light();
}
