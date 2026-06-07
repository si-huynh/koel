@Tags(['perf'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_flutter/koel_flutter.dart';

import 'perf_baseline.dart';

/// NFR-3 baseline harness: the **peak resident-set growth above a warmed floor**
/// that driving a **single active session** to completion reaches.
///
/// **Not a unit test — a regression tool.** Tagged `perf`, excluded from
/// `melos run test`; run it on demand or in the Epic 9 perf job. It drives the
/// real Flutter glue stack — a fresh [KoelClient] → [ChatSession] →
/// [KoelChatController] — to completion over a **fixed, large** event sequence,
/// repeatedly, and records how far the process resident set climbs above the
/// post-warmup floor (`peak_rss_growth_bytes`). A fixed sequence bounds the
/// conversation, so the metric reflects koel's steady working-set footprint,
/// **not** the unbounded consumer-held message history N-3 explicitly excludes.
///
/// **Why peak-growth, not the original per-run-delta p99 (D3 / deferred-work.md:424).**
/// `ProcessInfo.currentRss` is a process-wide, GC-nondeterministic signal. The
/// original metric — p99 of the per-run `after − before` delta — swung ±88–105%
/// run-to-run (Story 9.4 Task 0): a fully-disposed session retains ≈ 0, so the
/// per-run delta is dominated by GC timing, and on Linux (which returns freed
/// pages to the OS) the **median per-run delta is even negative** (Task 5 capture
/// recorded −504 KB) — a negative baseline makes the multiplicative gate
/// meaningless. Neither a wider band nor a robust central statistic fixes a
/// signal centred on zero. So the metric is the **peak working-set growth**: warm
/// up, settle the GC to a stable floor ([_settleGc]), then drive the measured
/// runs while tracking the maximum [ProcessInfo.currentRss], and record
/// `peak − floor`. This is **positive, MB-scale, and stable** (a fixed workload's
/// high-water set is deterministic up to new-space sizing), and it is exactly
/// what a real leak inflates — a session that fails to release its messages makes
/// the resident set climb run-over-run and the peak balloon. The metric key is
/// `peak_rss_growth_bytes` (was `rss_delta_bytes`); the v1.0.0 baselines are
/// recaptured on the reference device under it (Task 5). The observed
/// reference-device swing + the chosen gate band are documented in
/// `BENCHMARKS.md`.
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
/// path) → **fail when peak growth regresses past the N-3 band** (NFR-3); default
/// local `flutter test` → log the delta, **pass unconditionally**.
const _deltaCount = 2000;
const _argDeltas = 40;
const _warmupRuns = 8;
const _measuredRuns = 150;
const _baselinePath = 'test/perf/baselines/chat_session_memory_bench.json';

/// Post-warmup GC-settle tuning (D3). One churn-and-yield pass batch runs once,
/// after warmup, to collect warmup garbage so the recorded floor is the true
/// post-warmup resident floor (not an in-flight-garbage peak). Each pass
/// allocates a short-lived buffer to pressure the scavenger, then yields the
/// event loop so a collection can complete.
const _gcSettlePasses = 4;
const _gcChurnInts = 1 << 16; // ~512 KB transient churn per pass

/// N-3 gate band (D3). The peak-RSS-growth metric is positive and MB-scale, so a
/// multiplicative band is meaningful (unlike the original per-run delta, whose
/// reference-device median was negative). The reference-device peak swung
/// **4.4–13.7 MB (~3×) run-to-run** (Task 5 captures) from shared-runner
/// old-space GC nondeterminism — irreducible without a fixed self-hosted device.
/// This `4.0` band is the smallest honest multiple that clears that swing from
/// any captured baseline while still *biting a genuine leak*: a session that
/// failed to release its history would climb the resident set by tens of MB over
/// the 150 measured runs, far past 4×. Sub-MB footprint creep is below RSS
/// resolution on a shared runner and is NOT claimed to be caught — documented
/// honestly in BENCHMARKS.md (no silent cap). It stays a hard block, never a
/// silent downgrade.
const _n3GateTolerance = 4.0;

void main() {
  group('chat_session_memory_bench', () {
    test(
      'peak RSS growth over a fixed streaming run',
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

        // Settle warmup garbage so the floor is the true post-warmup resident
        // set, then track the high-water resident growth over the measured runs.
        // The peak (max) is the most stable cross-run statistic for this signal —
        // the median is dominated by where the GC-driven RSS climb happens to land
        // (it swung ~68× run-to-run on the reference device), while the peak is
        // the saturated high-water and is exactly what a leak inflates.
        await _settleGc();
        final floor = ProcessInfo.currentRss;
        var peak = floor;
        for (var i = 0; i < _measuredRuns; i++) {
          sink ^= await driveOnce();
          final rss = ProcessInfo.currentRss;
          if (rss > peak) peak = rss;
        }
        expect(sink, greaterThanOrEqualTo(0));

        recordOrGate(
          path: _baselinePath,
          metric: 'peak_rss_growth_bytes',
          value: (peak - floor).toDouble(),
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
/// collection complete so the following `floor` sample reflects retained
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
