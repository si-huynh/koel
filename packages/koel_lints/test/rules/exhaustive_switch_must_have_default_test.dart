// test_reflective_loader requires `test_`-prefixed method names.
// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:koel_lints/src/rules/exhaustive_switch_must_have_default.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ExhaustiveSwitchMustHaveDefaultTest);
  });
}

@reflectiveTest
class ExhaustiveSwitchMustHaveDefaultTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = ExhaustiveSwitchMustHaveDefault();
    super.setUp();
  }

  /// A local `sealed class AgUiEvent` whose **name** (not identity) the rule
  /// keys off — this is what lets the rule fire before `koel_core`'s real type
  /// exists (Story 1.3 §5.1). Subtypes are deliberately under-listed in the
  /// "silent" cases so `default:`/`_` is reachable (no `unreachable_switch_*`).
  static const _sealed = '''
sealed class AgUiEvent {}
final class RunStartedEvent extends AgUiEvent {}
final class RunFinishedEvent extends AgUiEvent {}
final class RunErrorEvent extends AgUiEvent {}
''';

  Future<void> test_statement_fires_without_default() async {
    await assertDiagnostics(
      '''
${_sealed}String describe(AgUiEvent e) {
  switch (e) {
    case RunStartedEvent _:
      return 'started';
    case RunFinishedEvent _:
      return 'finished';
    case RunErrorEvent _:
      return 'error';
  }
}
''',
      [lint(205, 6)],
    );
  }

  Future<void> test_statement_silent_with_default() async {
    await assertNoDiagnostics('''
${_sealed}String describe(AgUiEvent e) {
  switch (e) {
    case RunStartedEvent _:
      return 'started';
    default:
      return 'other';
  }
}
''');
  }

  Future<void> test_expression_fires_without_wildcard() async {
    await assertDiagnostics(
      '''
${_sealed}String describe(AgUiEvent e) => switch (e) {
      RunStartedEvent _ => 'started',
      RunFinishedEvent _ => 'finished',
      RunErrorEvent _ => 'error',
    };
''',
      [lint(204, 6)],
    );
  }

  Future<void> test_expression_silent_with_wildcard() async {
    await assertNoDiagnostics('''
${_sealed}String describe(AgUiEvent e) => switch (e) {
      RunStartedEvent _ => 'started',
      _ => 'other',
    };
''');
  }
}
