@Tags(['perf'])
library;

import 'package:koel_core/src/agent/abstract_agent.dart';
import 'package:koel_core/src/client/koel_client.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/input/run_agent_input.dart';
import 'package:test/test.dart';

import 'perf_baseline.dart';

/// NFR-4 baseline harness: cold-start latency from `KoelClient(...)` constructor
/// return to first event-subscription readiness, against an empty agent.
///
/// **Not a unit test — a regression tool.** Tagged `perf`, excluded from
/// `melos run test`. Same record-or-gate contract as `reducer_bench` (see
/// [recordOrGate]): records the v1.0.0 baseline when absent / under
/// `KOEL_PERF_UPDATE`, **gates > 10% regression** under `KOEL_PERF_GATE` (Epic 9
/// reference device), logs-and-passes by default so it never flakes.
///
/// **Measured interval (AC2, fixed):** the [Stopwatch] starts immediately before
/// `KoelClient(agent: ...)` and stops the moment `runRaw(...).listen(...)`
/// returns a live `StreamSubscription` — i.e. the post-pipeline event stream is
/// subscribed and ready to receive. "Cold" means a **fresh client per
/// iteration**; each is disposed (and its subscription cancelled) right after
/// the measurement so no `StreamController` leaks across iterations.
///
/// **`MockAgent.empty` does not exist yet** (it is Story 3.1, in the still-empty
/// `koel_test`). AC2 is satisfied with the in-package [_EmptyAgent] double — a
/// private `AbstractAgent` whose `run` yields nothing — mirroring
/// `test/agent/abstract_agent_test.dart`'s `_FakeAgent`. When 3.1 ships
/// `MockAgent.empty`, this bench can re-point to it.
const _warmupStarts = 300;
const _timedStarts = 3000;
const _baselinePath = 'test/perf/baselines/cold_start_bench.json';
const _input = RunAgentInput(threadId: 'bench-thread', runId: 'bench-run');

/// Gate band. Cold-start is a tiny absolute interval (~37µs on the reference
/// device), so GitHub shared-runner CPU-generation variance dominates it: Story
/// 9.4 Task 5 saw it span 37–45µs across normal jobs (~22%) with no code change,
/// and a stressed runner pushed it to 69µs. 100% absorbs that jitter while still
/// biting a real cold-start regression (a doubled init path). The wider band vs
/// the other compute metrics is honest about a sub-50µs metric's noise floor on a
/// shared runner — documented in BENCHMARKS.md; a hard block.
const _gateTolerance = 2.0;

/// A terminal [AbstractAgent] whose run completes with no events — the empty
/// cold-start workload (stands in for the not-yet-built `MockAgent.empty`).
class _EmptyAgent implements AbstractAgent {
  const _EmptyAgent();

  @override
  Stream<AgUiEvent> run(RunAgentInput input) => const Stream<AgUiEvent>.empty();
}

void main() {
  group('cold_start_bench', () {
    test('p99 client-construct-to-subscription latency', () async {
      for (var i = 0; i < _warmupStarts; i++) {
        await _coldStart();
      }

      final micros = List<double>.filled(_timedStarts, 0);
      final stopwatch = Stopwatch();
      for (var i = 0; i < _timedStarts; i++) {
        micros[i] = await _coldStart(stopwatch);
      }

      recordOrGate(
        path: _baselinePath,
        metric: 'p99_micros',
        value: percentile(micros, 99),
        sampleSize: _timedStarts,
        label: 'cold_start',
        tolerance: _gateTolerance,
      );
    });
  });
}

/// Runs one cold start: constructs a fresh [KoelClient], subscribes to its
/// post-pipeline stream, then tears both down. When [stopwatch] is supplied it
/// times the construct→subscription interval and returns the elapsed
/// microseconds; otherwise (warm-up) it returns 0.
Future<double> _coldStart([Stopwatch? stopwatch]) async {
  stopwatch
    ?..reset()
    ..start();
  final client = KoelClient(agent: const _EmptyAgent());
  final subscription = client.runRaw(_input).listen((_) {});
  stopwatch?.stop();

  await subscription.cancel();
  client.dispose();
  return stopwatch == null ? 0 : stopwatch.elapsedMicroseconds.toDouble();
}
