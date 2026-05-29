@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:test/test.dart';

/// AC1 integration check (Story 1.7): the proof the archived predecessor engine
/// never achieved — the rule firing on consumer source under `dart analyze`.
///
/// Builds a self-contained consumer package in a temp dir **outside** the koel
/// workspace (the analyzer rejects `plugins:` in any options file nested inside
/// a workspace — `plugins_in_inner_options`), enables the koel_lints plugin by
/// absolute path, and runs the production `dart analyze` CLI over a `switch`
/// that lacks `default:`. It must report exactly one
/// `exhaustive_switch_must_have_default` error.
void main() {
  test(
    'dart analyze reports exactly one error via the server-plugin path',
    () async {
      // `Directory.current` is the package root under `dart test`.
      final koelLintsPath = Directory.current.absolute.path;

      final fixture = Directory.systemTemp.createTempSync('koel_lints_ac1_');
      addTearDown(() => fixture.deleteSync(recursive: true));

      File('${fixture.path}/pubspec.yaml').writeAsStringSync('''
name: koel_lints_ac1_fixture
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
sealed class AgUiEvent {}
final class RunStartedEvent extends AgUiEvent {}
final class RunFinishedEvent extends AgUiEvent {}
final class RunErrorEvent extends AgUiEvent {}

String describe(AgUiEvent e) {
  switch (e) {
    case RunStartedEvent _:
      return 'started';
    case RunFinishedEvent _:
      return 'finished';
    case RunErrorEvent _:
      return 'error';
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
