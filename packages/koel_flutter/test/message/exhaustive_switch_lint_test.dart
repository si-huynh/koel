@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// AC1 (Story 6.5) integration check: the `koel_lints`
/// `exhaustive_switch_must_have_default` rule fires on a `switch` over
/// [MessageSegment] that lacks `default:`, under the production `dart analyze`.
///
/// Mirrors `koel_lints/test/integration/dart_analyze_fires_test.dart` (D4): a
/// self-contained consumer package is built in a temp dir **outside** the koel
/// workspace (the analyzer rejects `plugins:` in options nested inside a
/// workspace — `plugins_in_inner_options`), the koel_lints plugin is enabled by
/// absolute path, and `dart analyze` runs over the violation. The rule matches
/// by **simple type name**, so an inline `sealed class MessageSegment` exercises
/// the exact `_sealedNames` registry path the real koel_flutter type will — and
/// importing the real type is impossible anyway, since the fixture must live
/// outside the workspace.
void main() {
  test(
    'dart analyze reports exactly one error on a defaultless MessageSegment switch',
    () async {
      // `Directory.current` is the koel_flutter package root under `flutter
      // test`; the sibling koel_lints package is `../koel_lints`.
      final koelLintsPath = Directory(
        '${Directory.current.parent.absolute.path}/koel_lints',
      ).absolute.path;
      expect(
        Directory(koelLintsPath).existsSync(),
        isTrue,
        reason: 'koel_lints not found at $koelLintsPath',
      );

      final fixture = Directory.systemTemp.createTempSync('koel_flutter_ac1_');
      addTearDown(() => fixture.deleteSync(recursive: true));

      File('${fixture.path}/pubspec.yaml').writeAsStringSync('''
name: koel_flutter_ac1_fixture
publish_to: none
environment:
  sdk: ">=3.11.0 <4.0.0"
''');

      File('${fixture.path}/analysis_options.yaml').writeAsStringSync('''
plugins:
  koel_lints:
    path: ${_yamlString(koelLintsPath)}
    diagnostics:
      exhaustive_switch_must_have_default: true
''');

      Directory('${fixture.path}/lib').createSync();
      File('${fixture.path}/lib/violation.dart').writeAsStringSync('''
sealed class MessageSegment {}
final class TextSegment extends MessageSegment {}
final class CodeBlockSegment extends MessageSegment {}

String describe(MessageSegment s) {
  switch (s) {
    case TextSegment _:
      return 'text';
    case CodeBlockSegment _:
      return 'code';
  }
}
''');

      final pubGet = Process.runSync('dart', [
        'pub',
        'get',
      ], workingDirectory: fixture.path);
      expect(pubGet.exitCode, 0, reason: 'pub get failed:\n${pubGet.stderr}');

      final analyze = Process.runSync('dart', [
        'analyze',
      ], workingDirectory: fixture.path);
      final output = '${analyze.stdout}${analyze.stderr}';

      expect(
        analyze.exitCode,
        isNonZero,
        reason: 'dart analyze should fail on the violation:\n$output',
      );
      final hits = 'exhaustive_switch_must_have_default'
          .allMatches(output)
          .length;
      expect(
        hits,
        1,
        reason: 'expected exactly one rule error, got $hits:\n$output',
      );
    },
  );
}

/// Quotes a filesystem path for safe embedding in a YAML scalar.
String _yamlString(String path) =>
    '"${path.replaceAll(r'\', r'\\').replaceAll('"', r'\"')}"';
