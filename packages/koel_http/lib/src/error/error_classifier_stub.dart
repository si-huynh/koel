import 'package:koel_core/koel_core.dart';

/// Non-native fallback (selected when `dart.library.io` is unavailable): the
/// web-safe base classifier. There are no `dart:io` socket shapes to refine
/// here, so the by-name [DefaultErrorClassifier] is already correct.
ErrorClassifier createErrorClassifier() => const DefaultErrorClassifier();
