@Tags(['perf'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:koel_http/koel_http.dart';
import 'package:test/test.dart';

import 'perf_baseline.dart';

/// NFR-1 baseline harness: p99 SSE-parse time per event over a large
/// `text/event-stream` byte stream.
///
/// **Not a unit test — a regression tool.** Tagged `perf` and excluded from
/// `melos run test` and the coverage gate; run it on demand or in the Epic 9
/// perf job. It builds the richest synthesized fixture (`all_event_types`,
/// every AG-UI event kind) framed as `data: <json>\n\n`, repeated to a
/// multi-thousand-event stream, warms the JIT, then times
/// `SseParser.parse` draining the stream to completion and records the 99th
/// percentile of the per-event time.
///
/// **Record-or-gate (never flakes) — see [recordOrGate]:**
/// - baseline absent **or** `KOEL_PERF_UPDATE` set → measure, write
///   `test/perf/baselines/sse_parse_bench.json`, pass (captures the v1.0.0
///   baseline);
/// - `KOEL_PERF_GATE` set (the CI reference-device path, Epic 9
///   `perf-bench.yml`) → measure, **fail when p99 regresses > 10%** vs the
///   committed baseline (NFR-1);
/// - default local `dart test` → measure, log the delta + derived events/sec,
///   **pass unconditionally** (convention §6 "no flaky tests").
///
/// The gated metric is `p99_micros_per_event` (lower-is-better, the
/// `recordOrGate` contract); "events-per-second throughput" (the AC's words) is
/// the derived human-readable figure (`1e6 / micros`) logged alongside.
const _warmupSweeps = 50;
const _timedSweeps = 300;
const _bodyRepeats = 200;
const _baselinePath = 'test/perf/baselines/sse_parse_bench.json';

/// Gate band. The PRD's 10% default is far too tight for an absolute-µs metric on
/// GitHub-hosted runners, whose CPU generation varies job-to-job — a slow instance
/// ran the sibling compute metrics ~54–86% over with no code change (Story 9.4
/// Task 5), i.e. ~2× slower hardware. 100% clears that shared-runner variance
/// while still biting a real parse regression. Documented in BENCHMARKS.md; a hard
/// block, never a silent downgrade.
const _gateTolerance = 2.0;

void main() {
  group('sse_parse_bench', () {
    test('p99 parse-time per event over a large SSE byte stream', () async {
      final payloads = await _fixturePayloads('all_event_types');
      expect(payloads, isNotEmpty);

      // One large, in-memory wire body: every fixture event framed as an SSE
      // `data:` record, repeated to a few thousand events. Encoded once; each
      // sweep re-parses the same bytes.
      final buffer = StringBuffer();
      for (var i = 0; i < _bodyRepeats; i++) {
        for (final payload in payloads) {
          buffer.write('data: ${jsonEncode(payload)}\n\n');
        }
      }
      final body = utf8.encode(buffer.toString());
      final eventCount = payloads.length * _bodyRepeats;

      const parser = SseParser();

      Future<void> parseOnce() async {
        final parsed = await parser.parse(Stream.value(body)).length;
        // Guard: a parser that drops or duplicates events would make the
        // per-event number measure the wrong work.
        if (parsed != eventCount) {
          throw StateError('parsed $parsed events, expected $eventCount');
        }
      }

      for (var i = 0; i < _warmupSweeps; i++) {
        await parseOnce();
      }

      final perEventMicros = List<double>.filled(_timedSweeps, 0);
      final stopwatch = Stopwatch();
      for (var i = 0; i < _timedSweeps; i++) {
        stopwatch
          ..reset()
          ..start();
        await parseOnce();
        stopwatch.stop();
        perEventMicros[i] = stopwatch.elapsedMicroseconds / eventCount;
      }

      final p99 = percentile(perEventMicros, 99);
      // ignore: avoid_print
      print(
        '[sse_parse] p99=${p99.toStringAsFixed(3)}us/event '
        '≈ ${(1e6 / p99).round()} events/sec (derived, NFR-1)',
      );
      recordOrGate(
        path: _baselinePath,
        metric: 'p99_micros_per_event',
        value: p99,
        sampleSize: _timedSweeps,
        label: 'sse_parse',
        tolerance: _gateTolerance,
      );
    });
  });
}

/// The raw wire `payload` of each event line in a synthesized fixture (skipping
/// the `_session` header) — the bytes a real SSE endpoint would emit. Resolved
/// through the `package:` asset URI so it reads `koel_test`'s fixtures
/// regardless of CWD (the mechanism `http_agent_test` uses).
Future<List<Map<String, dynamic>>> _fixturePayloads(String name) async {
  final uri = Uri.parse(
    'package:koel_test/src/fixtures/synthesized/$name.jsonl',
  );
  final resolved = await Isolate.resolvePackageUri(uri);
  final lines = (await File.fromUri(
    resolved!,
  ).readAsLines()).where((line) => line.trim().isNotEmpty).toList();
  return [
    for (final line in lines.skip(1))
      (jsonDecode(line) as Map<String, dynamic>)['payload']
          as Map<String, dynamic>,
  ];
}
