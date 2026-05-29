import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';

import 'src/rules/exhaustive_switch_must_have_default.dart';

/// The `analysis_server_plugin` entry point.
///
/// The analysis server generates code that imports this `lib/main.dart` and
/// references the top-level [plugin] variable, then calls [Plugin.register]
/// once per analysis context.
final plugin = KoelLintsPlugin();

final class KoelLintsPlugin extends Plugin {
  @override
  String get name => 'koel_lints';

  @override
  void register(PluginRegistry registry) {
    registry.registerLintRule(ExhaustiveSwitchMustHaveDefault());
  }
}
