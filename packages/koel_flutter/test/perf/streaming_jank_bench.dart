@Tags(['perf'])
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_flutter/koel_flutter.dart';

import 'perf_baseline.dart';

/// NFR-5 baseline harness: p99 of the **synchronous per-event UI-thread work**
/// (reduce → `notifyListeners` → widget rebuild) during continuous streaming
/// through a [KoelChatController]-bound widget.
///
/// **Not a unit test — a regression tool.** Tagged `perf`, excluded from
/// `melos run test`; run it on demand or in the Epic 9 perf job.
///
/// **Why a synchronous-work proxy, not real frame raster (D3):** `flutter_tester`
/// does not rasterize on a real GPU, so a literal "frames over 16 ms" / GPU
/// raster-timing measurement is unobtainable under `flutter test` — that is the
/// Epic 9 / AR-17 device-matrix concern (BENCHMARKS.md reference-device profile).
/// The jank-relevant quantity that *is* host-runnable and deterministic is the
/// synchronous work each streamed event lands on the caller's isolate — the work
/// that would consume a frame's 16 ms budget. This bench drives a continuous
/// fixed-length stream of `TEXT_MESSAGE_CONTENT` deltas through a controller-bound
/// [AnimatedBuilder] and `Stopwatch`es the per-delta rebuild+notify work.
///
/// **Pacing:** a local agent gates each delta behind a one-frame
/// [Future.delayed], and the bench advances the fake clock exactly one frame per
/// `pump`, so each `pump` fires one timer → delivers one delta → folds it →
/// notifies → rebuilds the bound widget, all synchronously inside that frame. The
/// `Stopwatch` wraps the `pump` to capture that real CPU time; the fake clock
/// makes the 16 ms spacing itself free.
///
/// Records `p99_frame_micros` and prints the count of events whose synchronous
/// work exceeded the 16 ms (= 16000 µs) budget — the human-readable NFR-5 line.
/// **Record-or-gate (never flakes) — see [recordOrGate]:** baseline absent **or**
/// `KOEL_PERF_UPDATE` → write the committed v1.0.0 baseline; `KOEL_PERF_GATE`
/// (Epic 9 reference-device path) → **fail when p99 regresses > 10%** (NFR-5);
/// default local `flutter test` → log the delta, **pass unconditionally**.
const _frame = Duration(milliseconds: 16);
const _frameBudgetMicros = 16000;
const _warmupEvents = 50;
const _measuredEvents = 500;
const _baselinePath = 'test/perf/baselines/streaming_jank_bench.json';

void main() {
  testWidgets(
    'streaming_jank_bench p99 synchronous UI-thread work per delta',
    (tester) async {
      final client = KoelClient(agent: const _PacedStreamAgent());
      final controller = KoelChatController(session: client.newSession());
      addTearDown(() {
        controller.dispose();
        client.dispose();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: AnimatedBuilder(
            animation: controller,
            builder: (_, _) => Text(
              _assistantText(controller.state),
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      );

      // Kick off the run; the first un-paced events (RUN_STARTED, TEXT_MESSAGE_START)
      // land on this initial pump.
      unawaited(controller.send('hi'));
      await tester.pump();

      // Warmup: drive the first deltas to warm the JIT and let the bound Text grow
      // past its cold-start size; timings discarded.
      for (var i = 0; i < _warmupEvents; i++) {
        await tester.pump(_frame);
      }

      final perEventMicros = List<double>.filled(_measuredEvents, 0);
      final stopwatch = Stopwatch();
      for (var i = 0; i < _measuredEvents; i++) {
        stopwatch
          ..reset()
          ..start();
        await tester.pump(
          _frame,
        ); // one timer → one delta → fold → notify → rebuild
        stopwatch.stop();
        perEventMicros[i] = stopwatch.elapsedMicroseconds.toDouble();
      }

      // Drain the trailing TEXT_MESSAGE_END / RUN_FINISHED so the controller settles
      // idle before teardown.
      await tester.pumpAndSettle();
      expect(controller.isStreaming, isFalse);

      // Invariant guard: the metric is only valid if each `pump` folded exactly one
      // delta. The committed assistant message must hold all warmup+measured tokens —
      // a pacing regression (a `pump` delivering zero or two deltas, or the fake
      // clock drifting off the agent's one-frame spacing) trips this loudly here
      // instead of silently skewing p99.
      final delivered = _assistantText(
        controller.state,
      ).trim().split(' ').where((t) => t.isNotEmpty).length;
      expect(delivered, _warmupEvents + _measuredEvents);

      final overBudget = perEventMicros
          .where((m) => m > _frameBudgetMicros)
          .length;
      // ignore: avoid_print
      print(
        '[streaming_jank] $overBudget/$_measuredEvents events exceeded the '
        '16ms UI-thread budget (host flutter_tester; synchronous-work proxy, '
        'not GPU raster — real-device jank is Epic 9 / AR-17)',
      );

      recordOrGate(
        path: _baselinePath,
        metric: 'p99_frame_micros',
        value: percentile(perEventMicros, 99),
        sampleSize: _measuredEvents,
        label: 'streaming_jank',
      );
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

/// The assistant text the bound widget renders from a [ChatState] — the in-flight
/// [ChatState.pendingMessage] while streaming. Mirrors
/// `test/support/test_agent.dart`'s `assistantText`; reproduced locally so the
/// bench imports only koel_core/koel_flutter.
String _assistantText(ChatState s) {
  final pending = s.pendingMessage?.content;
  if (pending != null && pending.isNotEmpty) return pending;
  final committed = s.messages.where((m) => m.role == MessageRole.assistant);
  return committed.isEmpty ? '' : committed.last.content;
}

/// A local [AbstractAgent] that streams `_warmupEvents + _measuredEvents`
/// `TEXT_MESSAGE_CONTENT` deltas, each gated behind a one-[_frame]
/// [Future.delayed] so the bench can advance the fake clock one frame at a time
/// and process exactly one delta per `pump`.
final class _PacedStreamAgent implements AbstractAgent {
  const _PacedStreamAgent();

  @override
  Stream<AgUiEvent> run(RunAgentInput input) async* {
    yield RunStartedEvent(threadId: 'jank-thread', runId: 'jank-run');
    yield TextMessageStartEvent(messageId: 'm1', role: 'assistant');
    for (var i = 0; i < _warmupEvents + _measuredEvents; i++) {
      await Future<void>.delayed(_frame);
      yield TextMessageContentEvent(messageId: 'm1', delta: 'token$i ');
    }
    yield TextMessageEndEvent(messageId: 'm1');
    yield RunFinishedEvent(threadId: 'jank-thread', runId: 'jank-run');
  }
}
