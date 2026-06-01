/// Shared record-or-gate plumbing for the `koel_http` perf benches
/// (`sse_parse_bench`). Not public API — a `test/` helper.
///
/// Copied verbatim from `koel_core/test/perf/perf_baseline.dart`: that file
/// imports `package:koel_core/src/...` internals and lives under
/// `koel_core/test/`, so it is not cross-package importable; the
/// [percentile]/[recordOrGate] functions themselves are pure `dart:io` +
/// `dart:convert` with no koel coupling, so the copy is clean.
///
/// The benches measure a wall-clock metric and call [recordOrGate], which
/// reconciles AC4's ">10% regression gate" with convention §6's "no flaky tests"
/// (the gate belongs to the CI reference device, not a loaded laptop). Three
/// modes, keyed off the baseline file + two env switches:
///
/// - **baseline absent** *or* `KOEL_PERF_UPDATE` set → write the baseline JSON,
///   pass. This is how the committed v1.0.0 baselines are first captured.
/// - `KOEL_PERF_GATE` set → compare and **fail when `value` exceeds the
///   baseline by > 10%**. Wired by Epic 9's `perf-bench.yml` on the reference
///   device.
/// - **default** (local `dart test`) → log the delta and **pass
///   unconditionally**, so the bench never flakes under local load.
library;

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// The inclusive-rank percentile of [samples] (e.g. `p = 99`). Sorts a copy, so
/// the caller's list is untouched. Throws [ArgumentError] on an empty list — a
/// percentile of no samples is undefined, never silently 0.
double percentile(List<double> samples, int p) {
  if (samples.isEmpty) {
    throw ArgumentError.value(samples, 'samples', 'must be non-empty');
  }
  final sorted = [...samples]..sort();
  final rank = (p / 100 * (sorted.length - 1)).round();
  return sorted[rank];
}

/// Records [value] as the baseline at [path], or gates against it, per the
/// env-driven contract documented on this library.
///
/// [metric] is the JSON key the number is written/read under; [sampleSize] and
/// the running Dart [Platform.version] are recorded alongside it for context.
/// [label] prefixes the human-readable log/gate messages. Lower [value] is
/// better (it is a duration in microseconds); the gate fires when
/// `value > baseline * 1.10`.
void recordOrGate({
  required String path,
  required String metric,
  required double value,
  required int sampleSize,
  required String label,
}) {
  final file = File(path);
  final env = Platform.environment;
  final rounded = double.parse(value.toStringAsFixed(3));

  if (!file.existsSync() || env.containsKey('KOEL_PERF_UPDATE')) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert({metric: rounded, 'sample_size': sampleSize, 'recorded_dart': Platform.version.split(' ').first})}\n',
    );
    // ignore: avoid_print
    print('[$label] recorded baseline $metric=${rounded}us -> $path');
    return;
  }

  // Read + validate the committed baseline with a precise failure message —
  // a corrupted/edited baseline must surface as "baseline malformed", not an
  // opaque FormatException/CastError inside the Epic-9 perf job.
  final Object? decoded;
  try {
    decoded = jsonDecode(file.readAsStringSync());
  } on FormatException catch (e) {
    fail('[$label] baseline at $path is not valid JSON: ${e.message}');
  }
  if (decoded is! Map<String, dynamic>) {
    fail(
      '[$label] baseline at $path must be a JSON object, got ${decoded.runtimeType}',
    );
  }
  final rawMetric = decoded[metric];
  if (rawMetric is! num) {
    fail(
      '[$label] baseline at $path is missing a numeric "$metric" key '
      '(got ${rawMetric.runtimeType}); re-record with KOEL_PERF_UPDATE',
    );
  }
  final baselineValue = rawMetric.toDouble();

  if (env.containsKey('KOEL_PERF_GATE')) {
    expect(
      value,
      lessThanOrEqualTo(baselineValue * 1.10),
      reason:
          '[$label] $metric regressed > 10%: ${rounded}us vs '
          'baseline ${baselineValue}us (NFR regression gate)',
    );
    return;
  }

  final deltaPct = (value - baselineValue) / baselineValue * 100;
  final sign = deltaPct >= 0 ? '+' : '';
  // ignore: avoid_print
  print(
    '[$label] $metric=${rounded}us baseline=${baselineValue}us '
    'delta=$sign${deltaPct.toStringAsFixed(1)}% '
    '(log-only; set KOEL_PERF_GATE to enforce)',
  );
}
