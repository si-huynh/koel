import 'package:koel_core/koel_core.dart';
import 'package:koel_test/koel_test.dart';
import 'package:test/test.dart';

void main() {
  group('FixtureLoader', () {
    test('loadSynthesized decodes text_only_run to typed events in order, '
        'with the _session header excluded (AC1)', () async {
      final events = await FixtureLoader.loadSynthesized('text_only_run');

      // Five event lines — the six-line file minus the _session header.
      expect(events, hasLength(5));
      expect(events[0], isA<RunStartedEvent>());
      expect(events[1], isA<TextMessageStartEvent>());
      expect(events[2], isA<TextMessageContentEvent>());
      expect(events[3], isA<TextMessageEndEvent>());
      expect(events[4], isA<RunFinishedEvent>());

      // The payload-decode lands on typed subtypes, never the Unknown fallback.
      expect(events, everyElement(isNot(isA<UnknownAgUiEvent>())));
      expect((events[2] as TextMessageContentEvent).delta, 'Hello, world!');
    });

    test('FixtureSession.fromJson decodes the six header fields (AC1)', () {
      final session = FixtureSession.fromJson(const {
        'koelVersion': '0.0.1',
        'adapter': 'synthesized',
        'captured': '2026-05-26T00:00:00.000Z',
        'threadId': 'synth-text-only-run',
        'runId': 'synth-text-only-run-1',
        'synthesized': true,
      });

      expect(session.koelVersion, '0.0.1');
      expect(session.adapter, 'synthesized');
      expect(session.synthesized, isTrue);
      expect(session.threadId, 'synth-text-only-run');
      expect(session.runId, 'synth-text-only-run-1');
      expect(session.captured, DateTime.parse('2026-05-26T00:00:00.000Z'));
    });

    test('FixtureSession.fromJson throws ArgumentError on a missing field', () {
      expect(
        () => FixtureSession.fromJson(const {'koelVersion': '0.0.1'}),
        throwsArgumentError,
      );
    });

    test('unknown synthesized fixture throws an enumerated ArgumentError, '
        'not a KoelError (AC3)', () {
      expect(
        FixtureLoader.loadSynthesized('does_not_exist'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('text_only_run'),
          ),
        ),
      );
    });

    test('backend loaders are wired; today their dirs hold no .jsonl, so any '
        'name throws ArgumentError (no captures until Epic 5)', () {
      expect(FixtureLoader.loadAgno('whatever'), throwsArgumentError);
      expect(FixtureLoader.loadDojo('whatever'), throwsArgumentError);
      expect(FixtureLoader.loadLangGraph('whatever'), throwsArgumentError);
    });
  });

  group('MockAgent.fromFixture', () {
    test('replays text_only_run through the real KoelClient pipeline; '
        'messages.last.content is the fixture text (AC2)', () async {
      // Resolution is Isolate.resolvePackageUri-based (not CWD-relative), so
      // this works unchanged from any consuming package's test root.
      final client = KoelClient(
        agent: await MockAgent.fromFixture('text_only_run'),
      );
      addTearDown(client.dispose);

      final session = client.newSession();
      await session.send('hi');

      expect(session.state.messages.last.content, 'Hello, world!');
    });

    test('an unknown fixture name surfaces ArgumentError (AC3)', () {
      expect(MockAgent.fromFixture('does_not_exist'), throwsArgumentError);
    });
  });
}
