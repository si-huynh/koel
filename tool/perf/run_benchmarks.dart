// Cross-package perf-bench orchestrator (architecture.md:738, Story 9.4 / D5).
// Repo-level tool — NOT a package `lib/` file, so it carries no pubspec of its
// own and is outside every package's coverage scope. Zero-dependency
// `dart:io`/`dart:convert` (no `package:args`): a repo tool resolves only
// against the workspace root, whose AI-5.9 pins (`analyzer 12.1.0` / `freezed
// 3.2.6-dev.1`, SCP-2026-05-29-B) no third-party CLI dep may disturb — the same
// isolation discipline as `tool/verify_api_surface.dart`.
//
// ## What it does
//
// Runs the five committed perf benches — each a `test/perf/*_bench.dart` harness
// carrying the shared `recordOrGate` three-mode contract (Stories 2.15 / 4.10 /
// 6.8) — with the correct test runner and CWD per package, sets one env switch
// for all of them, and aggregates their exit codes into a single pass/fail:
//
//   - N-1 sse_parse           koel_http     dart test    (SSE parse µs/event)
//   - N-2 reducer             koel_core     dart test    (reduce µs/event)
//   - N-3 chat_session_memory koel_flutter  flutter test (peak RSS growth)
//   - N-4 cold_start          koel_core     dart test    (client cold-start µs)
//   - N-5 streaming_jank      koel_flutter  flutter test (UI-thread µs/delta)
//
// Each bench reads a fixture relative to its package root (`reducer_bench` reads
// `test/event/full_event_sweep.jsonl`; `sse_parse_bench` resolves a
// `package:koel_test` asset), so every run uses CWD = that package's root (the
// `tool/test_package.sh` convention). The two `koel_flutter` benches import
// `flutter_test`, so they run under `flutter test`; the rest under `dart test`.
// `--tags perf` is passed explicitly so the perf-tagged tests run (they are
// excluded from `melos run test` / coverage by `--exclude-tags=perf`).
//
// ## Modes
//
//   dart run tool/perf/run_benchmarks.dart            # GATE (default, the CI gate)
//   dart run tool/perf/run_benchmarks.dart --update    # CAPTURE the baselines
//   melos run perf [-- --update]                        # same, via the melos script
//
// GATE mode sets `KOEL_PERF_GATE` for every bench → a bench whose gated metric
// regresses past its band fails, and this orchestrator exits NON-ZERO with a
// per-bench summary. CAPTURE mode sets `KOEL_PERF_UPDATE` → each bench overwrites
// its committed `test/perf/baselines/<bench>.json` (the reference-device capture
// run, Story 9.4 Task 5 / 9.9 publish; committed via a reviewed PR, never an
// auto-push). Child stdout/stderr is forwarded verbatim so each bench's own
// human-readable line (events/sec, over-budget count, the delta) lands in the
// job log.
import 'dart:convert';
import 'dart:io';

/// The test runner a bench needs. The two `koel_flutter` benches import
/// `flutter_test`, so they only run under `flutter test`; the rest are plain
/// `dart test`.
enum _Runner {
  dart('dart'),
  flutter('flutter');

  const _Runner(this.executable);
  final String executable;
}

/// One perf bench: its NFR label, owning package, runner, and the bench file
/// relative to that package's root.
class _Bench {
  const _Bench(this.label, this.package, this.runner, this.file);

  final String label;
  final String package;
  final _Runner runner;
  final String file;
}

/// The five committed benches, hard-coded (named-with-reason — no globbing, so a
/// stray or renamed `*_bench.dart` can never silently join or drop out of the
/// gate). Order is the NFR order for a readable summary.
const List<_Bench> _benches = [
  _Bench(
    'N-1 sse_parse',
    'koel_http',
    _Runner.dart,
    'test/perf/sse_parse_bench.dart',
  ),
  _Bench(
    'N-2 reducer',
    'koel_core',
    _Runner.dart,
    'test/perf/reducer_bench.dart',
  ),
  _Bench(
    'N-3 chat_session_memory',
    'koel_flutter',
    _Runner.flutter,
    'test/perf/chat_session_memory_bench.dart',
  ),
  _Bench(
    'N-4 cold_start',
    'koel_core',
    _Runner.dart,
    'test/perf/cold_start_bench.dart',
  ),
  _Bench(
    'N-5 streaming_jank',
    'koel_flutter',
    _Runner.flutter,
    'test/perf/streaming_jank_bench.dart',
  ),
];

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
      '${invalid}run_benchmarks — cross-package perf-bench orchestrator (NFR-1..NFR-5)\n'
      '\n'
      'Usage:\n'
      '  dart run tool/perf/run_benchmarks.dart            run all five benches under KOEL_PERF_GATE (the CI gate)\n'
      '  dart run tool/perf/run_benchmarks.dart --update    run all five under KOEL_PERF_UPDATE (capture baselines)\n',
    );
    exit(unknown.isEmpty ? 0 : 2);
  }

  final repoRoot = _repoRoot();
  final envKey = update ? 'KOEL_PERF_UPDATE' : 'KOEL_PERF_GATE';
  stdout.writeln(
    'run_benchmarks: ${update ? 'CAPTURE' : 'GATE'} mode '
    '($envKey) · ${_benches.length} benches',
  );

  final results = <_Result>[];
  for (final bench in _benches) {
    results.add(await _runBench(bench, repoRoot, envKey));
  }

  stdout.writeln('\nrun_benchmarks: summary');
  for (final r in results) {
    final status = r.passed ? 'PASS' : 'FAIL';
    final detail = r.summaryLine ?? '(no metric line — see output above)';
    stdout.writeln('  [$status] ${r.bench.label.padRight(24)} $detail');
  }

  final failed = results.where((r) => !r.passed).toList();
  if (failed.isNotEmpty) {
    stderr.writeln(
      '\nrun_benchmarks: ${failed.length} bench(es) FAILED the '
      '${update ? 'capture' : 'gate'} — ${failed.map((r) => r.bench.label).join(', ')}. '
      'See each bench\'s regression line above (metric, delta vs baseline, band).',
    );
    exit(1);
  }
  stdout.writeln(
    '\nrun_benchmarks: OK — all ${_benches.length} benches '
    '${update ? 'captured' : 'within band'}.',
  );
  exit(0);
}

/// Runs one [bench] under CWD = its package root with [envKey] set, forwarding
/// its stdout/stderr to the job log and capturing stdout to extract the
/// `[label] metric=… delta=…%` summary line the bench prints in gate + log modes.
Future<_Result> _runBench(_Bench bench, String repoRoot, String envKey) async {
  final workdir = '$repoRoot/packages/${bench.package}';
  stdout.writeln(
    '\n▶ ${bench.label} — ${bench.runner.executable} test ${bench.file} '
    '--tags perf  (cwd: packages/${bench.package})',
  );

  final Process process;
  try {
    process = await Process.start(
      bench.runner.executable,
      ['test', bench.file, '--tags', 'perf'],
      workingDirectory: workdir,
      environment: {envKey: '1'},
      runInShell: Platform.isWindows, // resolve flutter/dart shims on Windows
    );
  } on ProcessException catch (e) {
    // The runner binary is missing/unspawnable (e.g. `flutter` not on PATH on a
    // misconfigured lane). Fail this bench cleanly so the aggregate summary
    // still prints, rather than crashing main with an uncaught exception.
    stderr.writeln(
      '  ✗ could not start ${bench.runner.executable}: ${e.message}',
    );
    return _Result(
      bench: bench,
      passed: false,
      summaryLine:
          'runner "${bench.runner.executable}" could not start (${e.message})',
    );
  }

  // Forward both streams live; tee stdout so the metric line can be summarized.
  final outBuffer = StringBuffer();
  final stdoutDone = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        outBuffer.writeln(line);
        stdout.writeln(line);
      })
      .asFuture<void>();
  final stderrDone = stderr.addStream(process.stderr);

  final exitCode = await process.exitCode;
  await Future.wait([stdoutDone, stderrDone]);

  final metricLine = _extractMetricLine(outBuffer.toString());

  // In GATE mode a zero exit is necessary but NOT sufficient: the bench must
  // actually have measured + gated, which it signals by printing its
  // `[label] …delta=…` line. A zero exit with no such line means the gated test
  // never ran (the `--tags perf` filter matched nothing, or a refactor dropped
  // the body) — a vacuous pass, the exact silent-no-op this gate exists to
  // prevent. Treat it as a failure. CAPTURE mode prints `recorded baseline …`
  // instead and is verified by the committed JSON diff, so it is exempt.
  final vacuous =
      envKey == 'KOEL_PERF_GATE' &&
      exitCode == 0 &&
      !(metricLine?.contains('delta=') ?? false);
  if (vacuous) {
    stderr.writeln(
      '  ✗ ${bench.label} exited 0 but emitted no metric line — the gated '
      'test did not run (vacuous pass).',
    );
  }

  return _Result(
    bench: bench,
    passed: exitCode == 0 && !vacuous,
    summaryLine: vacuous
        ? 'NO METRIC — gated test did not run (vacuous pass)'
        : metricLine,
  );
}

/// The last `[label] …delta=…` line a bench printed (its metric vs baseline) —
/// the one human-readable figure worth echoing in the orchestrator summary.
/// Returns null in capture mode (the bench prints `recorded baseline …` instead)
/// or if no such line was produced.
String? _extractMetricLine(String output) {
  String? found;
  for (final line in const LineSplitter().convert(output)) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('[')) continue;
    // The bench's metric line carries both `baseline=` and `delta=` (gate + log
    // modes); requiring both anchors past a stray `flutter test` timestamp log
    // line like `[ +123 ms] …delta=…` that happens to contain one token.
    if (trimmed.contains('baseline=') && trimmed.contains('delta=')) {
      found = trimmed;
    } else if (trimmed.contains('recorded baseline')) {
      found = trimmed;
    }
  }
  return found;
}

/// The repo root, derived from this script's own location
/// (`<root>/tool/perf/run_benchmarks.dart`) so the orchestrator works regardless
/// of the caller's CWD — `melos run perf` and a bare `dart run` both land here.
String _repoRoot() {
  final scriptDir = File.fromUri(Platform.script).parent; // tool/perf
  return scriptDir.parent.parent.path; // <root>
}

/// One bench's outcome: whether its test process exited 0 and the metric line it
/// printed, for the aggregate summary.
class _Result {
  _Result({
    required this.bench,
    required this.passed,
    required this.summaryLine,
  });

  final _Bench bench;
  final bool passed;
  final String? summaryLine;
}
