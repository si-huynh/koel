import 'dart:async';

import 'package:koel_core/koel_core.dart';
import 'package:koel_test/koel_test.dart';
import 'package:test/test.dart';

/// The argument to [MockAgent.run] is ignored (verbatim replay), so one shared
/// input suffices for most tests.
const _input = RunAgentInput(threadId: 'ignored', runId: 'ignored');

void main() {
  group('MockAgent shape (AC1)', () {
    test('fromEvents and built agents are AbstractAgents', () {
      expect(MockAgent.fromEvents(const []), isA<AbstractAgent>());
      expect(MockAgent.programmatic().build(), isA<AbstractAgent>());
    });

    test(
      'programmatic() returns a builder whose build() yields a MockAgent',
      () {
        final agent = MockAgent.programmatic()
            .runStarted()
            .textMessage('hi')
            .runFinished()
            .build();
        expect(agent, isA<MockAgent>());
      },
    );

    test(
      'builder produces the expected sequence with a shared non-empty messageId',
      () async {
        final agent = MockAgent.programmatic()
            .runStarted()
            .textMessage('hi')
            .runFinished()
            .build();
        final events = await agent.run(_input).toList();

        expect(events, hasLength(5));
        expect(events[0], isA<RunStartedEvent>());
        expect(events[1], isA<TextMessageStartEvent>());
        expect(events[2], isA<TextMessageContentEvent>());
        expect(events[3], isA<TextMessageEndEvent>());
        expect(events[4], isA<RunFinishedEvent>());

        final start = events[1] as TextMessageStartEvent;
        final content = events[2] as TextMessageContentEvent;
        final end = events[3] as TextMessageEndEvent;
        expect(start.messageId, isNotEmpty);
        expect(start.messageId, content.messageId);
        expect(content.messageId, end.messageId);
        expect(content.delta, 'hi');
        expect(start.role, 'assistant');
      },
    );

    test(
      'runStarted/runFinished share the builder run pair; override updates it',
      () async {
        final events = await MockAgent.programmatic()
            .runStarted(threadId: 't-9', runId: 'r-9')
            .runFinished()
            .build()
            .run(_input)
            .toList();
        final started = events[0] as RunStartedEvent;
        final finished = events[1] as RunFinishedEvent;
        expect(started.threadId, 't-9');
        expect(started.runId, 'r-9');
        expect(finished.threadId, 't-9');
        expect(finished.runId, 'r-9');
      },
    );
  });

  group('replay order & verbatim semantics (AC2)', () {
    const canned = [
      RunStartedEvent(threadId: 't', runId: 'r'),
      TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
      TextMessageContentEvent(messageId: 'm1', delta: 'hi'),
      TextMessageEndEvent(messageId: 'm1'),
      RunFinishedEvent(threadId: 't', runId: 'r'),
    ];

    test('fromEvents replays the declared order verbatim', () async {
      final events = await MockAgent.fromEvents(canned).run(_input).toList();
      expect(events, canned);
    });

    test(
      'run(input) ignores input — output is identical regardless of input ids',
      () async {
        final agent = MockAgent.fromEvents(const [
          RunStartedEvent(threadId: 'canned', runId: 'canned'),
        ]);
        final a = await agent
            .run(const RunAgentInput(threadId: 'A', runId: 'A'))
            .toList();
        final b = await agent
            .run(const RunAgentInput(threadId: 'B', runId: 'B'))
            .toList();
        expect(a, b);
        expect((a.single as RunStartedEvent).threadId, 'canned');
      },
    );

    test(
      'emission is asynchronous — no event is delivered synchronously inside listen()',
      () async {
        final agent = MockAgent.fromEvents(canned);
        var firstSeen = false;
        final sub = agent.run(_input).listen((_) => firstSeen = true);
        // Set synchronously right after listen(): if delivery were synchronous,
        // firstSeen would already be true here.
        expect(
          firstSeen,
          isFalse,
          reason: 'first event must not arrive synchronously',
        );
        await sub.asFuture<void>();
        expect(firstSeen, isTrue);
        await sub.cancel();
      },
    );

    test(
      'fromEvents defensively copies — post-construction mutation does not affect replay',
      () async {
        final events = <AgUiEvent>[
          const RunStartedEvent(threadId: 't', runId: 'r'),
        ];
        final agent = MockAgent.fromEvents(events);
        events.add(const RunFinishedEvent(threadId: 't', runId: 'r'));
        expect(await agent.run(_input).toList(), hasLength(1));
      },
    );
  });

  group('configurable delay (AC2/AC3)', () {
    test('per-event delay accumulates (loose lower bound only)', () async {
      const delay = Duration(milliseconds: 10);
      final events = List<AgUiEvent>.generate(
        3,
        (i) => RunStartedEvent(threadId: 't$i', runId: 'r$i'),
      );
      final agent = MockAgent.fromEvents(events, delay: delay);

      final sw = Stopwatch()..start();
      await agent.run(_input).toList();
      sw.stop();

      // Never an upper bound — a loaded machine can take arbitrarily longer.
      expect(sw.elapsed, greaterThanOrEqualTo(delay * 3));
    });

    test(
      'cancelling mid-stream stops further emissions (TCP-close analog)',
      () async {
        const delay = Duration(milliseconds: 20);
        final agent = MockAgent.programmatic()
            .runStarted(delay: delay)
            .textMessage('hi', delay: delay) // 3 events
            .runFinished(delay: delay)
            .build(); // 5 events total

        final received = <AgUiEvent>[];
        final firstArrived = Completer<void>();
        late final StreamSubscription<AgUiEvent> sub;
        sub = agent.run(_input).listen((event) {
          received.add(event);
          if (!firstArrived.isCompleted) firstArrived.complete();
        });

        // Cancel deterministically the instant the first event actually
        // arrives — no wall-clock race (timers fire at-or-after, never early,
        // so a fixed sleep would be an implicit upper bound on arrival).
        await firstArrived.future;
        await sub.cancel();
        final countAtCancel = received.length;

        // Pump well past all remaining delays; nothing more must arrive.
        await Future<void>.delayed(const Duration(milliseconds: 200));

        expect(countAtCancel, 1);
        expect(
          received.length,
          countAtCancel,
          reason: 'no events after cancel',
        );
        expect(
          received.length,
          lessThan(5),
          reason: 'cancel stopped replay early',
        );
      },
    );
  });

  group('reusability', () {
    test('run() twice yields two independent, equal sequences', () async {
      final agent = MockAgent.programmatic()
          .runStarted()
          .textMessage('hi')
          .runFinished()
          .build();
      final a = await agent.run(_input).toList();
      final b = await agent.run(_input).toList();
      expect(a, b);
      expect(identical(a, b), isFalse);
    });

    test('build() is single-shot — a second call throws StateError', () {
      final builder = MockAgent.programmatic().runStarted().runFinished();
      builder.build();
      expect(builder.build, throwsStateError);
    });
  });

  group('adapter never throws (architecture §5)', () {
    test('empty timelines complete without throwing', () async {
      expect(
        await MockAgent.fromEvents(const []).run(_input).toList(),
        isEmpty,
      );
      expect(
        await MockAgent.programmatic().build().run(_input).toList(),
        isEmpty,
      );
    });

    test('a RunErrorEvent is emitted as a normal event, not thrown', () async {
      const error = RunErrorEvent(
        error: AgentError(message: 'boom', code: KoelErrorCode.unknown),
      );
      final agent = MockAgent.programmatic().runStarted().event(error).build();
      final events = await agent.run(_input).toList(); // must not throw
      expect(events.whereType<RunErrorEvent>(), hasLength(1));
      expect(events.last, error);
    });
  });

  group('builder ID determinism', () {
    MockAgent buildTwoMessages() => MockAgent.programmatic()
        .runStarted()
        .textMessage('a')
        .textMessage('b')
        .runFinished()
        .build();

    test(
      'counter-based IDs are reproducible and reset per builder instance',
      () async {
        final first = await buildTwoMessages().run(_input).toList();
        final second = await buildTwoMessages().run(_input).toList();
        expect(first, second, reason: 'two builds must be byte-identical');

        final ids = first
            .whereType<TextMessageStartEvent>()
            .map((e) => e.messageId)
            .toList();
        expect(ids, ['mock-msg-1', 'mock-msg-2']);
        expect(ids.every((id) => id.isNotEmpty), isTrue);
      },
    );

    test(
      'an explicit empty messageId is honoured (deliberate negative test)',
      () async {
        final events = await MockAgent.programmatic()
            .textMessage('x', messageId: '')
            .build()
            .run(_input)
            .toList();
        expect((events.first as TextMessageStartEvent).messageId, isEmpty);
      },
    );
  });
}
