## 0.0.1

- Initial scaffold.
- Built on the first-party `analysis_server_plugin` (asp). Enabled centrally at
  the workspace-root `analysis_options.yaml`; fires under `dart analyze` and
  IDEs in the native pub workspace.
- Requires Dart `>=3.11.0` (`analyzer 13` → `_fe_analyzer_shared ^3.11`).
