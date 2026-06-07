// Public-API breaking-change gate (NFR-14 / AR-12 / Story 9.3). Repo-level tool —
// NOT a package `lib/` file, so it carries no pubspec of its own and is outside
// every package's coverage scope. Zero-dependency `dart:io`/`dart:convert` (no
// `package:args`, no `package:dart_apitool`): a repo tool resolves only against
// the workspace root, and the workspace pins `analyzer 12.1.0` / `freezed
// 3.2.6-dev.1` (AI-5.9 / SCP-2026-05-29-B) — versions `package:dart_apitool`'s
// recent-analyzer dependency would violate. So this tool NEVER imports
// `dart_apitool`; it shells out (`Process.run`) to the GLOBALLY-activated
// `dart-apitool 0.23.1` CLI, whose own pubspec is fully isolated from the
// workspace hold (the 2.15/6.8/7.4 baseline extractions already proved this).
//
// ## Why the wrapper computes the diff itself (and does not call `dart-apitool diff`)
//
// `dart-apitool diff --old <ref> --new <ref>` re-analyzes BOTH refs from package
// SOURCES — a directory, a `pub://` ref, or a `git://` ref (verified in
// dart_apitool-0.23.1 `lib/src/cli/package_ref.dart` + `command_mixin.dart`
// `prepare`/`analyze`). It CANNOT consume a stored `extract` JSON: passing a
// `.json` path yields `Error: Unknown package ref`. So the committed
// `.api-baseline/<pkg>.json` files — the established 2.15/6.8/7.4 convention,
// which are dart_apitool `extract` outputs — are not feedable to the CLI `diff`.
// (Story 9.3 D7 assumed `diff --old <baseline.json>`; Task 0 disproved it. The
// prior stories only ever ran `extract`; nobody had wired the diff before, so
// the gap was never hit — recorded as an FYI in the Dev Agent Record.)
//
// The faithful design keeps the committed-JSON baseline model (D1/D2/D6) intact:
// this wrapper uses the CLI ONLY for `extract` (current surface → temp JSON),
// then computes the breaking-vs-additive classification itself by comparing the
// fresh extract against the committed baseline at the SYMBOL level. The
// classification maps exactly onto AC2:
//   - a public symbol present in the baseline but absent now  → BREAKING (removal)
//   - a public symbol whose declaration shape changed         → BREAKING (signature/type change)
//   - a public symbol present now but absent in the baseline  → additive (new symbol — WARN, non-blocking)
// Member granularity (a class's methods/fields are keyed individually) means a
// NEW method on an existing class reads as additive, while a removed or retyped
// method reads as breaking — matching AC2's "new public symbols pass with a
// warning" against "signature/type change blocks".
//
// CONSERVATIVE EDGE (FYI): any change to an EXISTING symbol's serialized
// declaration is treated as breaking — including the technically-additive case
// of adding an *optional* parameter to an existing method. For a 1.0.0 freeze
// that is the safe direction: such a change must go through an explicit
// `--update` baseline-refresh PR (Story 9.9's flow), where a human reviews it.
//
// ## Determinism
//
// `extract` is byte-deterministic for a fixed SDK + resolved deps (pubspec.lock):
// re-extracting the same package twice is identical EXCEPT `packageApi.packagePath`,
// an absolute temp dir (`/var/.../T/xxxx`). This wrapper neutralizes that one
// field to `''` before writing a baseline (so re-extraction on CI/another machine
// is not a spurious diff — D7) and the symbol comparison reads only the four
// declaration arrays, so any residual incidental fields (`packageDependencies`,
// platform constraints) never false-fail the gate.
//
// ## Modes
//
//   dart run tool/verify_api_surface.dart            # diff/verify (the CI gate)
//   dart run tool/verify_api_surface.dart --update   # capture/refresh baselines
//   melos run api-diff [-- --update]                 # same, via the melos script
//
// Diff mode (default): per package, extract the current surface and diff it
// against the committed `packages/<pkg>/.api-baseline/<pkg>.json`. A breaking
// delta exits NON-ZERO with a per-package report; an additive delta logs a
// warning and keeps going (exit 0). A missing baseline fails ("run --update").
//
// Update mode: per package, extract + overwrite the committed baseline. This is
// what Story 9.3 Task 2 runs to capture the v1.0.0 truth and what Story 9.9
// reruns at publish.
import 'dart:convert';
import 'dart:io';

/// The pinned `dart-apitool` version. A drift silently reshapes the extract JSON
/// (format version, field ordering) and corrupts the diff — so the wrapper
/// asserts this exact version up front and fails fast on a mismatch
/// (deferred-work.md:441 churn warning).
const String _requiredApiToolVersion = '0.23.1';

/// The nine surface-bearing release packages the gate covers. Each has (or, in
/// `--update`, gets) a committed `packages/<pkg>/.api-baseline/<pkg>.json`.
///
/// `koel` is the quickstart meta-barrel — it re-exports `package:koel_core`,
/// `package:koel_http`, `package:koel_flutter` and defines no symbol of its own.
/// dart_apitool scopes a surface to its DEFINING package (it does not follow
/// cross-`package:` re-exports — `_isInternalRef`, package_api_analyzer.dart),
/// so `koel`'s extract is legitimately EMPTY. It stays in the gate anyway: the
/// empty baseline guards the real invariant "the meta-package stays a pure
/// barrel and introduces no own symbol". Its TRANSITIVE surface is gated by the
/// `koel_core`/`koel_http`/`koel_flutter` baselines below, and its re-export
/// integrity by `koel`'s barrel-resolve test.
const List<String> _surfacePackages = [
  'koel', // meta-barrel — empty own surface (re-exports core+http+flutter); see above
  'koel_core',
  'koel_http',
  'koel_test',
  'koel_agno',
  'koel_langgraph',
  'koel_runtime',
  'koel_flutter',
  'koel_widgets',
];

/// Packages deliberately EXCLUDED from the API-surface gate (named here so a
/// reader scanning `packages/` sees they were skipped on purpose, not forgotten):
///
///   - `koel_lints`  — an analyzer-profile package (`lib/koel.yaml`,
///     `lib/koel_flutter.yaml`, the `analysis_server_plugin` `lib/main.dart`,
///     internal rules under `lib/src/`). No `lib/koel_lints.dart` barrel and no
///     consumable Dart symbol surface — nothing meaningful to extract (D4). Its
///     contract is the lint profile, version-gated by `verify:versioning`.
///   - `koel_devtools` — Epic 8 (DevTools) work-in-progress; NOT part of the
///     ten-package v1.0.0 release set (Story 9.1), so it carries no v1.x API
///     contract for this gate to protect yet.
const List<String> _excludedPackages = ['koel_lints', 'koel_devtools'];

Future<void> main(List<String> args) async {
  final update = args.contains('--update');
  final unknown = args.where(
    (a) => a != '--update' && a != '--help' && a != '-h',
  );
  if (args.contains('--help') || args.contains('-h') || unknown.isNotEmpty) {
    final invalid = unknown.isEmpty
        ? ''
        : 'unknown argument(s): ${unknown.join(', ')}\n';
    stderr.write(
      '${invalid}verify_api_surface — public-API breaking-change gate (NFR-14)\n'
      '\n'
      'Usage:\n'
      '  dart run tool/verify_api_surface.dart            verify current surface == committed baseline (CI gate)\n'
      '  dart run tool/verify_api_surface.dart --update   refresh every committed baseline from the current surface\n',
    );
    exit(unknown.isEmpty ? 0 : 2);
  }

  // Fail fast on a tool-version mismatch — never extract with the wrong tool.
  final version = await _apiToolVersion();
  if (version != _requiredApiToolVersion) {
    stderr.writeln(
      'verify_api_surface: global dart-apitool is "$version" but this gate '
      'requires $_requiredApiToolVersion.\n'
      '  Run: dart pub global activate dart_apitool $_requiredApiToolVersion',
    );
    exit(1);
  }

  stdout.writeln(
    'verify_api_surface: ${update ? 'UPDATE' : 'VERIFY'} mode · '
    'dart-apitool $version · ${_surfacePackages.length} packages '
    '(excluded: ${_excludedPackages.join(', ')})',
  );

  final breakingPackages = <String>[];
  for (final pkg in _surfacePackages) {
    final current = await _extractSurface(pkg);
    if (update) {
      await _writeBaseline(pkg, current.rawApi);
      stdout.writeln(
        '  updated $pkg → ${_baselinePath(pkg)} (${current.topLevel} symbols)',
      );
      continue;
    }
    if (!_verifyOnePackage(pkg, current)) breakingPackages.add(pkg);
  }

  if (update) {
    stdout.writeln(
      'verify_api_surface: refreshed ${_surfacePackages.length} baselines.',
    );
    exit(0);
  }
  if (breakingPackages.isNotEmpty) {
    stderr.writeln(
      'verify_api_surface: BREAKING API change(s) in ${breakingPackages.join(', ')} '
      '— blocked (NFR-14: zero breaking changes to the 1.x surface). To accept an '
      'intentional break, refresh the baseline with `--update` in its own reviewed PR.',
    );
    exit(1);
  }
  stdout.writeln(
    'verify_api_surface: OK — every surface matches its committed baseline.',
  );
  exit(0);
}

/// Diffs [current] against package [pkg]'s committed baseline; prints a
/// per-package report. Returns `false` iff a BREAKING delta (or a missing
/// baseline) was found, so the caller blocks the merge.
bool _verifyOnePackage(String pkg, _Surface current) {
  final baselineFile = File(_baselinePath(pkg));
  if (!baselineFile.existsSync()) {
    stderr.writeln(
      '  $pkg: NO committed baseline at ${_baselinePath(pkg)} — run `--update` first.',
    );
    return false;
  }
  final baseline = _surfaceOf(
    (jsonDecode(baselineFile.readAsStringSync())
            as Map<String, dynamic>)['packageApi']
        as Map<String, dynamic>,
  );

  // Symbol-level set algebra. Member keys (`type X.method y`) are filtered when
  // their parent type itself is added/removed, so the report names the type once
  // instead of echoing every member.
  bool parentTypeMoved(String key, Set<String> typeKeys) {
    final dot = key.indexOf('.');
    return dot != -1 && typeKeys.contains(key.substring(0, dot));
  }

  final removedTypes = {
    for (final k in baseline.symbols.keys)
      if (k.startsWith('type ') &&
          !k.contains('.') &&
          !current.symbols.containsKey(k))
        k,
  };
  final addedTypes = {
    for (final k in current.symbols.keys)
      if (k.startsWith('type ') &&
          !k.contains('.') &&
          !baseline.symbols.containsKey(k))
        k,
  };

  final removed = [
    for (final k in baseline.symbols.keys)
      if (!current.symbols.containsKey(k) && !parentTypeMoved(k, removedTypes))
        k,
  ]..sort();
  final added = [
    for (final k in current.symbols.keys)
      if (!baseline.symbols.containsKey(k) && !parentTypeMoved(k, addedTypes))
        k,
  ]..sort();
  final changed = [
    for (final k in baseline.symbols.keys)
      if (current.symbols.containsKey(k) &&
          current.symbols[k] != baseline.symbols[k])
        k,
  ]..sort();

  final breaking = removed.length + changed.length;
  if (breaking == 0 && added.isEmpty) {
    stdout.writeln('  $pkg: OK (${current.topLevel} symbols, no change)');
    return true;
  }
  if (breaking > 0) {
    stdout.writeln('  $pkg: $breaking BREAKING, ${added.length} additive');
    for (final k in removed) {
      stdout.writeln('      BREAKING removed: $k');
    }
    for (final k in changed) {
      stdout.writeln('      BREAKING changed: $k (signature/type change)');
    }
  } else {
    stdout.writeln('  $pkg: ${added.length} additive (non-blocking)');
  }
  for (final k in added) {
    stdout.writeln(
      '      WARNING additive: $k (new public symbol — allowed, logged)',
    );
  }
  return breaking == 0;
}

/// The flattened public surface of one extract: [topLevel] is the count of
/// top-level declarations (the figure prior stories quote, e.g. koel_widgets 8),
/// [symbols] maps a stable per-symbol key to that symbol's canonical declaration
/// JSON (members keyed individually), and [rawApi] is the full `packageApi`
/// object (with `packagePath` neutralized) used when writing a baseline.
class _Surface {
  _Surface({
    required this.topLevel,
    required this.symbols,
    required this.rawApi,
  });

  final int topLevel;
  final Map<String, String> symbols;
  final Map<String, dynamic> rawApi;
}

/// Extracts [pkg]'s current public surface via the global `dart-apitool`,
/// normalizes the machine-specific `packagePath`, and flattens it to a
/// [_Surface]. Fails the process (never fabricates) if extraction errors.
Future<_Surface> _extractSurface(String pkg) async {
  final temp = Directory.systemTemp.createTempSync('koel_api_');
  try {
    final outFile = '${temp.path}/$pkg.json';
    final result = await _runApiTool([
      'extract',
      '--input',
      'packages/$pkg',
      '--output',
      outFile,
    ]);
    if (result.exitCode != 0 || !File(outFile).existsSync()) {
      stderr
        ..writeln(
          'verify_api_surface: `dart-apitool extract` failed for $pkg (exit ${result.exitCode}).',
        )
        ..writeln((result.stderr as String).trim())
        ..writeln((result.stdout as String).trim());
      exit(1);
    }
    final decoded =
        jsonDecode(File(outFile).readAsStringSync()) as Map<String, dynamic>;
    final api = decoded['packageApi'] as Map<String, dynamic>;
    api['packagePath'] =
        ''; // neutralize the absolute temp path (D7 determinism)
    return _Surface(
      topLevel:
          (api['interfaceDeclarations'] as List).length +
          (api['executableDeclarations'] as List).length +
          (api['fieldDeclarations'] as List).length +
          (api['typeAliasDeclarations'] as List).length,
      symbols: _surfaceOf(api).symbols,
      rawApi: decoded,
    );
  } finally {
    temp.deleteSync(recursive: true);
  }
}

/// Flattens a `packageApi` object to its symbol map. [_canonicalJson] drops the
/// location incidentals (at every depth) and sorts keys, so the only thing the
/// map captures is the caller-visible declaration shape.
///
/// Each symbol key embeds the declaration KIND, not just its name. Within one
/// interface (and at the top level) a getter and a setter — or a named
/// constructor and a same-named method — share a `name` but are distinct
/// `executableDeclarations` (the `type` field discriminates: `method`/`getter`/
/// `setter`/`constructor`/`operator`). Keying by name alone would collapse the
/// pair into one map entry, and removing the overwritten member would then slip
/// past the diff as a FALSE GREEN. Keying by `${decl['type']} ${decl['name']}`
/// keeps every member independently classified — true AC2 member granularity.
_Surface _surfaceOf(Map<String, dynamic> api) {
  const memberArrays = {'executableDeclarations', 'fieldDeclarations'};
  final symbols = <String, String>{};

  for (final decl
      in (api['interfaceDeclarations'] as List).cast<Map<String, dynamic>>()) {
    final name = decl['name'];
    symbols['type $name'] = _canonicalJson(_without(decl, memberArrays));
    for (final m
        in (decl['executableDeclarations'] as List? ?? const [])
            .cast<Map<String, dynamic>>()) {
      symbols['type $name.${m['type']} ${m['name']}'] = _canonicalJson(m);
    }
    for (final f
        in (decl['fieldDeclarations'] as List? ?? const [])
            .cast<Map<String, dynamic>>()) {
      symbols['type $name.field ${f['name']}'] = _canonicalJson(f);
    }
  }
  for (final fn
      in (api['executableDeclarations'] as List).cast<Map<String, dynamic>>()) {
    symbols['${fn['type']} ${fn['name']}'] = _canonicalJson(fn);
  }
  for (final field
      in (api['fieldDeclarations'] as List).cast<Map<String, dynamic>>()) {
    symbols['field ${field['name']}'] = _canonicalJson(field);
  }
  for (final ta
      in (api['typeAliasDeclarations'] as List).cast<Map<String, dynamic>>()) {
    symbols['typedef ${ta['name']}'] = _canonicalJson(ta);
  }

  return _Surface(topLevel: 0, symbols: symbols, rawApi: api);
}

/// Writes [pkg]'s baseline to `packages/<pkg>/.api-baseline/<pkg>.json`, pretty
/// 4-space JSON with a trailing newline (matches the committed convention and
/// keeps `--update` diffs clean). [rawApi] is the full decoded extract with
/// `packagePath` already neutralized.
Future<void> _writeBaseline(String pkg, Map<String, dynamic> rawApi) async {
  final file = File(_baselinePath(pkg));
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('    ').convert(rawApi)}\n',
  );
}

String _baselinePath(String pkg) => 'packages/$pkg/.api-baseline/$pkg.json';

/// A copy of [m] without [drop] keys.
Map<String, dynamic> _without(Map<String, dynamic> m, Set<String> drop) => {
  for (final e in m.entries)
    if (!drop.contains(e.key)) e.key: e.value,
};

/// Per-declaration location incidentals dropped at EVERY depth before
/// canonicalizing — `relativePath`/`entryPoints` ride along not just on a
/// declaration but on each nested parameter's resolved type, so moving a symbol
/// (or a parameter's type) to a different file while keeping it exported is not
/// an API change and must not read as one.
const Set<String> _incidentalKeys = {'entryPoints', 'relativePath'};

/// Encodes [node] with map keys recursively sorted (list order preserved — a
/// method's positional parameters are order-significant) and the
/// [_incidentalKeys] location fields dropped at every depth, so neither a
/// key-ordering difference nor a file move between two extracts reads as a
/// semantic change.
String _canonicalJson(Object? node) => jsonEncode(_canonicalize(node));

Object? _canonicalize(Object? node) {
  if (node is Map) {
    final keys = [
      for (final k in node.keys.cast<String>())
        if (!_incidentalKeys.contains(k)) k,
    ]..sort();
    return {for (final k in keys) k: _canonicalize(node[k])};
  }
  if (node is List) return [for (final e in node) _canonicalize(e)];
  return node;
}

/// Reads `dart-apitool --version`. The bare exe prints just the version
/// (`0.23.1`), but the `dart pub global run` fallback can prefix a one-time
/// precompile/activation notice — so take the LAST non-empty stdout line rather
/// than the whole trimmed output (else the notice would fail the version match).
Future<String> _apiToolVersion() async {
  final result = await _runApiTool(['--version']);
  if (result.exitCode != 0) {
    stderr.writeln(
      'verify_api_surface: cannot run dart-apitool — is it activated?\n'
      '  Run: dart pub global activate dart_apitool $_requiredApiToolVersion',
    );
    exit(1);
  }
  final lines = (result.stdout as String)
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty);
  return lines.isEmpty ? '' : lines.last;
}

/// Whether the bare `dart-apitool` executable is on PATH. Probed once on first
/// use; if absent (the pub-cache `bin` dir isn't on PATH), every call falls back
/// to `dart pub global run dart_apitool`.
bool? _apiToolOnPath;

/// Runs the global `dart-apitool` with [args], preferring the bare executable
/// and falling back to `dart pub global run dart_apitool`.
Future<ProcessResult> _runApiTool(List<String> args) async {
  if (_apiToolOnPath ?? true) {
    try {
      final result = await Process.run('dart-apitool', args);
      _apiToolOnPath = true;
      return result;
    } on ProcessException {
      _apiToolOnPath = false;
    }
  }
  return Process.run('dart', ['pub', 'global', 'run', 'dart_apitool', ...args]);
}
