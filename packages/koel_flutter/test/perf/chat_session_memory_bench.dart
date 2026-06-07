@Tags(['perf'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_flutter/koel_flutter.dart';

import 'perf_baseline.dart';

/// NFR-3 baseline harness: the **median** resident-set growth a **single active
/// session** retains while folding one fixed streaming run.
///
/// **Not a unit test — a regression tool.** Tagged `perf`, excluded from
/// `melos run test`; run it on demand or in the Epic 9 perf job. It drives the
/// real Flutter glue stack — a fresh [KoelClient] → [ChatSession] →
/// [KoelChatController] — to completion over a **fixed, large** event sequence
/// (so koel's retained structures dominate the GC-noisy RSS signal, exactly the
/// "large N → stable" rationale `reducer_bench` uses), samples
/// [ProcessInfo.currentRss] before/after each run, and records the **median** of
/// the per-run delta. A fixed sequence bounds the conversation, so the metric
/// reflects koel's steady footprint, **not** the unbounded consumer-held message
/// history N-3 explicitly excludes.
///
/// **Two stabilizations vs the original p99 capture (D3 / deferred-work.md:424).**
/// `ProcessInfo.currentRss` is a process-wide, GC-nondeterministic signal: the
/// raw per-run delta swung **±88–105%** run-to-run (Story 9.4 Task 0), so a
/// single-sample p99 over it would either false-trip a > 10% gate or mask real
/// regressions. (1) Before each `before` sample the bench runs a [_settleGc]
/// churn-and-yield pass so `before` reflects *retained* footprint, not the prior
/// run's in-flight garbage. (2) The recorded statistic is the **median** of the
/// per-run deltas, not the p99 tail — N-3 is a *footprint* SLO, not a
/// tail-latency one, so the central tendency is the faithful figure and the
/// noise-sensitive tail is the wrong target. The recorded metric key is
/// therefore `median_rss_delta_bytes` (renamed from the old `rss_delta_bytes`;
/// the v1.0.0 baselines are recaptured on the reference device under this key,
/// Task 5). The residual reference-device swing + the chosen gate band are
/// documented in `BENCHMARKS.md`.
///
/// Plain `test` (no widget): [KoelChatController] is a `ChangeNotifier` and
/// [ChatSession] constructs without a binding, so isolating the metric to koel's
/// data-structure footprint — not Flutter render allocations — needs no
/// `WidgetTester`. Runs under `flutter test` on `flutter_tester`, a host VM with
/// `dart:io`, so `ProcessInfo.currentRss` reports a real RSS (D1/D2).
///
/// **Record-or-gate (never flakes) — see [recordOrGate]:** baseline absent **or**
/// `KOEL_PERF_UPDATE` → write `test/perf/baselines/chat_session_memory_bench.json`
/// (the committed v1.0.0 baseline); `KOEL_PERF_GATE` (Epic 9 reference-device
/// path) → **fail when p99 regresses > 10%** (NFR-3); default local `flutter
/// test` → log the delta, **pass unconditionally**.
const _deltaCount = 2000;
const _argDeltas = 40;
const _warmupRuns = 8;
const _measuredRuns = 80;
const _baselinePath = 'test/perf/baselines/chat_session_memory_bench.json';

/// GC-settle tuning (D3). Each pass allocates a short-lived buffer to pressure
/// the scavenger, then yields the event loop so a collection can complete before
/// the next RSS sample. Sized to trigger a scavenge without growing the retained
/// heap (so it stabilizes `before` rather than inflating it).
const _gcSettlePasses = 4;
const _gcChurnInts = 1 << 16; // ~512 KB transient churn per pass

/// N-3 gate band (D3). After GC-stabilization the median per-run RSS delta sits
/// at the OS page-quantization floor (koel retains ≈ 0 per disposed session —
/// no leak), so a uniform > 10% band is meaningless: a single page (4–16 KB)
/// dwarfs 10% of a tens-of-KB median. This wider multiple is the smallest that
/// does not false-block on the reference device's residual GC swing while still
/// *biting a genuine (MB-scale) footprint leak* — a leak pushes the median far
/// above the page floor. It stays a hard block, never a silent downgrade. The
/// observed reference-device swing + this band are documented in BENCHMARKS.md.
/// Validated on the reference device in Story 9.4 Task 5.
const _n3GateTolerance = 4.0;

void main() {
  group('chat_session_memory_bench', () {
    test(
      'p99 RSS delta over a fixed streaming run',
      () async {
        final fixedRun = _buildFixedRun();
        // Observed accumulator: an XOR of final-state fields keeps the whole drive
        // from being eliminated as dead code by the optimizer (mirrors
        // reducer_bench's sink).
        var sink = 0;

        Future<int> driveOnce() async {
          final client = KoelClient(agent: _FixedRunAgent(fixedRun));
          final controller = KoelChatController(session: client.newSession());
          await controller.send('hi');
          final s = controller.state;
          final marker =
              s.messages.length ^
              (s.pendingMessage?.content.length ?? 0) ^
              s.pendingToolCalls.length ^
              s.phase.index;
          controller.dispose();
          client.dispose();
          return marker;
        }

        for (var i = 0; i < _warmupRuns; i++) {
          sink ^= await driveOnce();
        }

        final deltas = List<double>.filled(_measuredRuns, 0);
        for (var i = 0; i < _measuredRuns; i++) {
          await _settleGc();
          final before = ProcessInfo.currentRss;
          sink ^= await driveOnce();
          final after = ProcessInfo.currentRss;
          deltas[i] = (after - before).toDouble();
        }
        expect(sink, greaterThanOrEqualTo(0));

        recordOrGate(
          path: _baselinePath,
          metric: 'median_rss_delta_bytes',
          value: percentile(deltas, 50),
          sampleSize: _measuredRuns,
          label: 'chat_session_memory',
          tolerance: _n3GateTolerance,
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}

/// Best-effort GC settle before an RSS sample (D3). Dart exposes no synchronous
/// force-GC outside the VM service, so this pressures the scavenger with a burst
/// of short-lived allocations and yields the event loop between passes, letting a
/// collection complete so the following `before` sample reflects retained
/// footprint rather than the prior run's in-flight garbage (the ±88% noise
/// source, deferred-work.md:424). The churn is read back so the optimizer can't
/// elide it.
Future<void> _settleGc() async {
  for (var pass = 0; pass < _gcSettlePasses; pass++) {
    final churn = List<int>.filled(_gcChurnInts, 0);
    churn[pass] = pass;
    if (churn[pass] != pass) throw StateError('unreachable'); // keep churn live
    await Future<void>.delayed(Duration.zero);
  }
}

/// A local [AbstractAgent] that replays a fixed event list verbatim, ignoring
/// [RunAgentInput] — the same `RUN_STARTED → TEXT_MESSAGE_* → TOOL_CALL_* →
/// RUN_FINISHED` shape as `test/support/test_agent.dart`'s `streamingHelloAgent`,
/// scaled up and reproduced locally (no koel_test import) so the bench measures
/// koel's footprint, not the fixture loader's.
final class _FixedRunAgent implements AbstractAgent {
  const _FixedRunAgent(this._events);

  final List<AgUiEvent> _events;

  @override
  Stream<AgUiEvent> run(RunAgentInput input) async* {
    for (final event in _events) {
      yield event;
    }
  }
}

/// One fixed, large streaming run: a single assistant text message of
/// [_deltaCount] content deltas plus one tool-call round of [_argDeltas] argument
/// deltas. Built once and shared across every iteration so the sequence is
/// identical run to run.
List<AgUiEvent> _buildFixedRun() {
  const threadId = 'mem-thread';
  const runId = 'mem-run';
  return List<AgUiEvent>.unmodifiable(<AgUiEvent>[
    const RunStartedEvent(threadId: threadId, runId: runId),
    const TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
    for (var i = 0; i < _deltaCount; i++)
      TextMessageContentEvent(messageId: 'm1', delta: 'token$i '),
    const TextMessageEndEvent(messageId: 'm1'),
    const ToolCallStartEvent(toolCallId: 't1', toolCallName: 'search'),
    for (var i = 0; i < _argDeltas; i++)
      ToolCallArgsEvent(toolCallId: 't1', delta: '{"q":"$i"}'),
    const ToolCallEndEvent(toolCallId: 't1'),
    const RunFinishedEvent(threadId: threadId, runId: runId),
  ]);
}
