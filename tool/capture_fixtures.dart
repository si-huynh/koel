// Fixture-capture pipeline scaffold (AR-14). Repo-level tool — NOT a package
// `lib/` file, so it carries no pubspec of its own and is outside every
// package's coverage scope. Zero-dependency `dart:io` (no `package:args`): a
// repo tool resolves only against the workspace root.
//
// Each of the four AG-UI backends is wired to emit a captured `.jsonl` fixture
// in Epic 5. Until then this prints which story wires each backend. Invoke via
// `dart run tool/capture_fixtures.dart --backend=<name>` or
// `melos run capture-fixtures -- --backend=<name>`.
import 'dart:io';

/// The four AG-UI backends whose real-run fixtures Epic 5 captures, mapped to
/// the story that wires each. `TODO(Epic 5):` markers are intentional — this
/// scaffold ships in Epic 3; the capture logic lands per backend in Epic 5.
const Map<String, String> _backends = {
  // TODO(Epic 5): Story 5.3 — capture agno real-run fixtures.
  'agno': '5.3',
  // TODO(Epic 5): Story 5.6 — capture langgraph real-run fixtures.
  'langgraph': '5.6',
  // TODO(Epic 5): Story 5.9 — capture AG-UI Dojo real-run fixtures.
  'dojo': '5.9',
  // TODO(Epic 5): Story 5.9 — capture CopilotKit Next.js runtime fixtures.
  'copilotkit_runtime': '5.9',
};

void main(List<String> args) {
  final backend = _parseBackend(args);

  final story = backend == null ? null : _backends[backend];
  if (story == null) {
    stderr.writeln(
      backend == null
          ? 'capture_fixtures: missing --backend=<name>.'
          : 'capture_fixtures: unknown backend "$backend".',
    );
    stderr.writeln('Available backends: ${_backends.keys.join(', ')}');
    stderr.writeln('Usage: dart run tool/capture_fixtures.dart --backend=<name>');
    exit(2);
  }

  stdout.writeln('wired in Epic 5 Story $story');
}

/// Extracts the `--backend=<name>` value from [args], or `null` when absent.
/// Accepts both `--backend=agno` and `--backend agno`.
String? _parseBackend(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg.startsWith('--backend=')) {
      return arg.substring('--backend='.length);
    }
    if (arg == '--backend' && i + 1 < args.length) {
      return args[i + 1];
    }
  }
  return null;
}
