/// Shared record-or-gate plumbing for the `koel_flutter` perf benches
/// (`chat_session_memory_bench`, `streaming_jank_bench`). Not public API — a
/// `test/` helper.
///
/// A byte-for-byte copy of `koel_core/test/perf/perf_baseline.dart` with **one**
/// change: it imports `package:flutter_test/flutter_test.dart` (which re-exports
/// `expect`/`fail`/`lessThanOrEqualTo` from `package:matcher`/`package:test_api`)
/// instead of `package:test/test.dart`, because `koel_flutter` pulls the Flutter
/// SDK and its benches run under `flutter test` on `flutter_tester` — a host Dart
/// VM **with** `dart:io`, so `File`/`Platform`/`ProcessInfo` all work. Per-package
/// copy is the established pattern (koel_http copied it from koel_core); a `test/`
/// helper is not cross-package-importable.
///
/// The benches measure a wall-clock/byte metric and call [recordOrGate], which
/// reconciles the ">10% regression gate" with convention §6's "no flaky tests"
/// (PRD §10.1: the gate belongs to the CI reference device, not a loaded laptop).
/// Three modes, keyed off the baseline file + two env switches:
///
/// - **baseline absent** *or* `KOEL_PERF_UPDATE` set → write the baseline JSON,
///   pass. This is how the committed v1.0.0 baselines are first captured.
/// - `KOEL_PERF_GATE` set → compare and **fail when `value` exceeds the
///   baseline by > 10%**. Wired by Epic 9's `perf-bench.yml` on the reference
///   device.
/// - **default** (local `flutter test`) → log the delta and **pass
///   unconditionally**, so the bench never flakes under local load.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
/// better (it is a duration in microseconds or a byte count); the gate fires
/// when `value > baseline * tolerance`. [tolerance] defaults to `1.10` (the
/// PRD's > 10% regression band); a metric whose reference-device signal is
/// legitimately noisier than the compute metrics (e.g. the page-quantized RSS
/// footprint, N-3) may pass a wider documented band — see the caller +
/// BENCHMARKS.md. It stays a *block*, never a silent downgrade.
void recordOrGate({
  required String path,
  required String metric,
  required double value,
  required int sampleSize,
  required String label,
  double tolerance = 1.10,
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
    print('[$label] recorded baseline $metric=$rounded -> $path');
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

  final deltaPct = (value - baselineValue) / baselineValue * 100;
  final sign = deltaPct >= 0 ? '+' : '';

  if (env.containsKey('KOEL_PERF_GATE')) {
    final bandPct = ((tolerance - 1) * 100).toStringAsFixed(0);
    // Print the delta in gate mode too (not only on failure) so every bench's
    // number is visible in the perf job log (AC2), then enforce the band.
    // ignore: avoid_print
    print(
      '[$label] $metric=$rounded baseline=$baselineValue '
      'delta=$sign${deltaPct.toStringAsFixed(1)}% (gate band +$bandPct%)',
    );
    expect(
      value,
      lessThanOrEqualTo(baselineValue * tolerance),
      reason:
          '[$label] $metric regressed > $bandPct%: $rounded vs '
          'baseline $baselineValue (NFR regression gate)',
    );
    return;
  }

  // ignore: avoid_print
  print(
    '[$label] $metric=$rounded baseline=$baselineValue '
    'delta=$sign${deltaPct.toStringAsFixed(1)}% '
    '(log-only; set KOEL_PERF_GATE to enforce)',
  );
}
