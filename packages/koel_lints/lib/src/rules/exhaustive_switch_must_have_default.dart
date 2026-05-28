import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/error/error.dart' show DiagnosticSeverity;
import 'package:analyzer/error/listener.dart' show DiagnosticReporter;
import 'package:custom_lint_builder/custom_lint_builder.dart';

/// Lints switches over koel's sealed unions (`AgUiEvent`, `KoelError`,
/// `MessageSegment`) that lack a `default:` branch.
///
/// Rationale: adding a new subtype to one of these unions must remain a
/// semver-minor bump (FR-A12 / FC-2 / NFR-17). The `default:` branch is what
/// makes that safe for downstream switches.
class ExhaustiveSwitchMustHaveDefault extends DartLintRule {
  const ExhaustiveSwitchMustHaveDefault() : super(code: _code);

  static const _code = LintCode(
    name: 'exhaustive_switch_must_have_default',
    problemMessage:
        'switch over sealed koel type must include a `default:` branch '
        '(adding a new subtype is a semver-minor bump per FR-A12).',
    errorSeverity: DiagnosticSeverity.ERROR,
  );

  static const _sealedNames = {'AgUiEvent', 'KoelError', 'MessageSegment'};

  @override
  void run(
    CustomLintResolver resolver,
    DiagnosticReporter reporter,
    CustomLintContext context,
  ) {
    context.registry.addSwitchStatement((node) {
      if (_isKoelSealedSwitch(node.expression) &&
          !node.members.any((m) => m is SwitchDefault)) {
        reporter.atToken(node.switchKeyword, _code);
      }
    });
    context.registry.addSwitchExpression((node) {
      if (_isKoelSealedSwitch(node.expression) &&
          !node.cases.any((c) => _isOpenWildcard(c.guardedPattern))) {
        reporter.atToken(node.switchKeyword, _code);
      }
    });
  }

  bool _isKoelSealedSwitch(Expression expr) {
    final name = expr.staticType?.element?.name;
    return name != null && _sealedNames.contains(name);
  }

  /// The switch-expression analog of `default:` — an untyped, unguarded `_`.
  bool _isOpenWildcard(GuardedPattern guarded) {
    final pattern = guarded.pattern;
    return pattern is WildcardPattern &&
        pattern.type == null &&
        guarded.whenClause == null;
  }
}
