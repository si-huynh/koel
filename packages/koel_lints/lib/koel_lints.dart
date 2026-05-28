/// Analyzer plugin enforcing koel's mandatory rules.
///
/// Consumers wire this profile via `include: package:koel_lints/koel.yaml`
/// in their per-package `analysis_options.yaml`. See README for details.
library;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/exhaustive_switch_must_have_default.dart';

/// Entry point invoked by `custom_lint` to register koel_lints rules.
PluginBase createPlugin() => _KoelLintsPlugin();

class _KoelLintsPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) =>
      const [ExhaustiveSwitchMustHaveDefault()];
}
