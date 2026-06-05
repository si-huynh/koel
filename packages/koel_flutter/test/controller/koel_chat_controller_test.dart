import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_flutter/koel_flutter.dart';
import 'package:koel_test/koel_test.dart';

import '../support/test_agent.dart';

void main() {
  // Builds a controller over a fresh session driven by [agent] and tears both
  // down in the right order (controller first, then its owning client).
  ({KoelChatController controller, ChatSession session}) wire(
    AbstractAgent agent,
  ) {
    final client = KoelClient(agent: agent);
    final session = client.newSession();
    final controller = KoelChatController(session: session);
    addTearDown(() {
      controller.dispose();
      client.dispose();
    });
    return (controller: controller, session: session);
  }

  group('public surface (A.6)', () {
    test('state reads through to the session synchronously', () {
      final w = wire(streamingHelloAgent());
      expect(w.controller.state, same(w.session.state));
      expect(w.controller.state.messages, isEmpty);
      expect(w.controller.state.phase, RunPhase.idle);
    });

    test('isStreaming is false at idle', () {
      final w = wire(streamingHelloAgent());
      expect(w.controller.isStreaming, isFalse);
    });
  });

  group('send', () {
    test(
      'flips isStreaming true synchronously, then false on RunFinished',
      () async {
        final w = wire(streamingHelloAgent());
        expect(w.controller.isStreaming, isFalse);

        final future = w.controller.send('hi');
        // The session optimistically folds RunPhase.running synchronously inside
        // send(), so isStreaming is true before the run even starts streaming.
        expect(w.controller.isStreaming, isTrue);

        await future;
        expect(w.controller.isStreaming, isFalse);
        expect(w.controller.state.phase, RunPhase.idle);
      },
    );

    test('accumulates streamed text and commits the assistant turn', () async {
      final w = wire(streamingHelloAgent());
      final pendingLog = <String>[];
      w.controller.addListener(() {
        final pending = w.controller.state.pendingMessage?.content;
        if (pending != null) pendingLog.add(pending);
      });

      await w.controller.send('hi');

      // Two deltas → the pending message was seen accumulating before commit.
      expect(pendingLog, containsAllInOrder(['Hello', 'Hello world']));
      // Committed history: the user turn + the finished assistant turn.
      expect(w.controller.state.pendingMessage, isNull);
      expect(assistantText(w.controller.state), 'Hello world');
      expect(w.controller.state.messages.first.role, MessageRole.user);
    });

    test('fires notifyListeners on every folded state change', () async {
      final w = wire(streamingHelloAgent());
      var ticks = 0;
      w.controller.addListener(() => ticks++);

      await w.controller.send('hi');

      // running emit + one per folded event — more than a single tick.
      expect(ticks, greaterThan(1));
    });
  });

  group('cancel', () {
    test('flips to cancelled and notifies, isStreaming false', () async {
      final w = wire(
        MockAgent.programmatic()
            .runStarted()
            .event(TextMessageStartEvent(messageId: 'm1', role: 'assistant'))
            .event(TextMessageContentEvent(messageId: 'm1', delta: 'partial'))
            .build(), // never finishes — a run to cancel mid-flight
      );
      var notified = false;
      w.controller.addListener(() => notified = true);

      unawaited(w.controller.send('hi'));
      expect(w.controller.isStreaming, isTrue);

      w.controller.cancel();
      // State reads are synchronous (the session folds cancelled immediately)…
      expect(w.controller.state.phase, RunPhase.cancelled);
      expect(w.controller.isStreaming, isFalse);
      // …but the broadcast stream delivers the snapshot asynchronously, so the
      // notifyListeners tick lands after a microtask turn.
      await Future<void>.delayed(Duration.zero);
      expect(notified, isTrue);
    });
  });

  group('isStreaming across phases', () {
    test('true inside a STEP_* span (RunPhase.stepRunning)', () async {
      final w = wire(
        MockAgent.programmatic()
            .runStarted()
            .event(StepStartedEvent(stepName: 'think'))
            .build(), // pauses inside the step — never finishes
      );

      unawaited(w.controller.send('hi'));
      await pumpEventQueue(); // drain the canned events into the fold

      expect(w.controller.state.phase, RunPhase.stepRunning);
      expect(w.controller.isStreaming, isTrue);

      w.controller.cancel(); // settle the orphaned run for a clean teardown
    });

    test('false on RunPhase.error, and the error fold notifies', () async {
      final w = wire(
        MockAgent.programmatic()
            .runStarted()
            .event(
              const RunErrorEvent(
                error: AgentError(
                  message: 'boom',
                  code: KoelErrorCode.agentInternal,
                ),
              ),
            )
            .build(),
      );
      var notified = false;
      w.controller.addListener(() => notified = true);

      await w.controller.send('hi');

      expect(w.controller.state.phase, RunPhase.error);
      expect(w.controller.state.error, isA<AgentError>());
      expect(w.controller.isStreaming, isFalse);
      expect(notified, isTrue);
    });
  });

  group('clear', () {
    test('resets to a fresh idle state', () async {
      final w = wire(streamingHelloAgent());
      await w.controller.send('hi');
      expect(w.controller.state.messages, isNotEmpty);

      await w.controller.clear();
      expect(w.controller.state, const ChatState());
      expect(w.controller.isStreaming, isFalse);
    });
  });

  group('dispose (D1: does not own the session)', () {
    test('cancels the subscription — no notify after dispose', () async {
      final client = KoelClient(agent: streamingHelloAgent());
      final session = client.newSession();
      final controller = KoelChatController(session: session);
      addTearDown(client.dispose);

      var ticks = 0;
      controller.addListener(() => ticks++);
      controller.dispose();
      final afterDispose = ticks;

      // The injected session is still alive (D1) and usable; driving it must not
      // reach the disposed controller's listener.
      await session.send('again');
      expect(
        session.state.messages,
        isNotEmpty,
      ); // session worked → not disposed
      expect(ticks, afterDispose); // controller stayed silent post-dispose
    });

    test('is idempotent — a second dispose is a no-op, not an assertion', () {
      final client = KoelClient(agent: streamingHelloAgent());
      final controller = KoelChatController(session: client.newSession());
      addTearDown(client.dispose);

      controller.dispose();
      // Stock ChangeNotifier.dispose asserts on a double-dispose; the _disposed
      // latch must swallow the second call (e.g. Riverpod-owned + app-held).
      expect(controller.dispose, returnsNormally);
    });
  });
}
