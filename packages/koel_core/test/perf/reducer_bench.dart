@Tags(['perf'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:koel_core/src/event/event_deserializer.dart';
import 'package:koel_core/src/state/chat_state.dart';
import 'package:koel_core/src/state/chat_state_reducer.dart';
import 'package:test/test.dart';

import 'perf_baseline.dart';

/// NFR-2 baseline harness: p99 reduce-time per event over the synthesized
/// 28-event sweep (`test/event/full_event_sweep.jsonl`, Story 2.8).
///
/// **Not a unit test — a regression tool.** Tagged `perf` and excluded from
/// `melos run test`; run it on demand or in the Epic 9 perf job. It measures
/// `DefaultChatStateReducer.reduce` per event (the F-D2 fold), warms the JIT,
/// then times [_timedSweeps] full folds of the sweep and records the 99th
/// percentile of the per-event time.
///
/// **Record-or-gate (never flakes) — see [recordOrGate]:**
/// - baseline absent **or** `KOEL_PERF_UPDATE` set → measure, write
///   `test/perf/baselines/reducer_bench.json`, pass (captures the v1.0.0
///   baseline);
/// - `KOEL_PERF_GATE` set (the CI reference-device path, Epic 9
///   `perf-bench.yml`) → measure, **fail when p99 regresses > 10%** vs the
///   committed baseline (NFR-2);
/// - default local `dart test` → measure, log the delta, **pass
///   unconditionally** (convention §6 "no flaky tests").
///
/// A single `reduce` is sub-microsecond, below `Stopwatch` micro resolution, so
/// each sample is one full 28-event fold's elapsed time divided by the event
/// count — a stable per-event average whose p99 over many sweeps is a
/// regression-sensitive yet non-flaky signal.
const _warmupSweeps = 500;
const _timedSweeps = 3000;
const _baselinePath = 'test/perf/baselines/reducer_bench.json';

void main() {
  group('reducer_bench', () {
    test('p99 reduce-time per event over the 28-event sweep', () {
      final events = File('test/event/full_event_sweep.jsonl')
          .readAsLinesSync()
          .where((line) => line.trim().isNotEmpty)
          .map(
            (line) =>
                deserializeAgUiEvent(jsonDecode(line) as Map<String, dynamic>),
          )
          .toList(growable: false);
      expect(events, isNotEmpty);

      const reducer = DefaultChatStateReducer();
      const seed = ChatState();
      // Observed accumulator: keeps the pure, result-only `reduce` from being
      // eliminated as dead code by the optimizer.
      var sink = 0;

      for (var i = 0; i < _warmupSweeps; i++) {
        var state = seed;
        for (final event in events) {
          state = reducer.reduce(state, event);
        }
        sink ^= state.phase.index;
      }

      final perEventMicros = List<double>.filled(_timedSweeps, 0);
      final stopwatch = Stopwatch();
      for (var i = 0; i < _timedSweeps; i++) {
        var state = seed;
        stopwatch
          ..reset()
          ..start();
        for (final event in events) {
          state = reducer.reduce(state, event);
        }
        stopwatch.stop();
        perEventMicros[i] = stopwatch.elapsedMicroseconds / events.length;
        sink ^= state.phase.index;
      }
      expect(sink, greaterThanOrEqualTo(0));

      recordOrGate(
        path: _baselinePath,
        metric: 'p99_micros_per_event',
        value: percentile(perEventMicros, 99),
        sampleSize: _timedSweeps,
        label: 'reducer',
      );
    });
  });
}
