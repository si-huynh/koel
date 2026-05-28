import 'dart:io';

import 'package:koel_lints/src/rules/exhaustive_switch_must_have_default.dart';
import 'package:test/test.dart';

void main() {
  group('exhaustive_switch_must_have_default', () {
    const rule = ExhaustiveSwitchMustHaveDefault();

    test('fires on switch over sealed AgUiEvent without default', () async {
      final errors = await rule.testAnalyzeAndRun(
        File('test/rules/fixtures/violations/missing_default.dart').absolute,
      );
      expect(errors, hasLength(1));
      expect(
        errors.single.diagnosticCode.name,
        'exhaustive_switch_must_have_default',
      );
    });

    test('stays silent on switch over sealed AgUiEvent with default', () async {
      final errors = await rule.testAnalyzeAndRun(
        File('test/rules/fixtures/ok/with_default.dart').absolute,
      );
      expect(errors, isEmpty);
    });

    test(
      'fires on switch-expression over sealed AgUiEvent without `_` arm',
      () async {
        final errors = await rule.testAnalyzeAndRun(
          File(
            'test/rules/fixtures/violations/missing_default_expression.dart',
          ).absolute,
        );
        expect(errors, hasLength(1));
        expect(
          errors.single.diagnosticCode.name,
          'exhaustive_switch_must_have_default',
        );
      },
    );

    test(
      'stays silent on switch-expression over sealed AgUiEvent with `_` arm',
      () async {
        final errors = await rule.testAnalyzeAndRun(
          File('test/rules/fixtures/ok/with_default_expression.dart').absolute,
        );
        expect(errors, isEmpty);
      },
    );
  });
}
