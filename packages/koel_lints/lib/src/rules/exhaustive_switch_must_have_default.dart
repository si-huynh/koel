import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

/// Lints switches over koel's sealed unions (`AgUiEvent`, `KoelError`,
/// `MessageSegment`) that lack a `default:` branch.
///
/// Rationale: adding a new subtype to one of these unions must remain a
/// semver-minor bump (FR-A12 / FC-2 / NFR-17). The `default:` branch is what
/// makes that safe for downstream switches.
class ExhaustiveSwitchMustHaveDefault extends AnalysisRule {
  ExhaustiveSwitchMustHaveDefault()
    : super(
        name: 'exhaustive_switch_must_have_default',
        description:
            'Switches over koel sealed unions must include a `default:` branch.',
      );

  static const _code = LintCode(
    'exhaustive_switch_must_have_default',
    'switch over sealed koel type must include a `default:` branch '
        '(adding a new subtype is a semver-minor bump per FR-A12).',
    severity: DiagnosticSeverity.ERROR,
  );

  static const _sealedNames = {'AgUiEvent', 'KoelError', 'MessageSegment'};

  @override
  DiagnosticCode get diagnosticCode => _code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry.addSwitchStatement(this, visitor);
    registry.addSwitchExpression(this, visitor);
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

class _Visitor extends SimpleAstVisitor<void> {
  _Visitor(this.rule);

  final ExhaustiveSwitchMustHaveDefault rule;

  @override
  void visitSwitchStatement(SwitchStatement node) {
    if (rule._isKoelSealedSwitch(node.expression) &&
        !node.members.any((m) => m is SwitchDefault)) {
      rule.reportAtToken(node.switchKeyword);
    }
  }

  @override
  void visitSwitchExpression(SwitchExpression node) {
    if (rule._isKoelSealedSwitch(node.expression) &&
        !node.cases.any((c) => rule._isOpenWildcard(c.guardedPattern))) {
      rule.reportAtToken(node.switchKeyword);
    }
  }
}
