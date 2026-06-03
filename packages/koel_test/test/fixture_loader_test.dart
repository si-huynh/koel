import 'package:koel_core/koel_core.dart';
import 'package:koel_test/koel_test.dart';
import 'package:koel_test/src/fixture_envelope.dart';
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

    test('FixtureSession.backendVersion parses a live-capture header, and is '
        'null when absent — backward-compatible with synthesized fixtures '
        '(5.3 AC3)', () {
      Map<String, dynamic> header({String? backendVersion}) => {
        'koelVersion': '0.0.1',
        'adapter': 'koel_agno@0.0.1',
        'captured': '2026-06-03T00:00:00.000Z',
        'threadId': 't',
        'runId': 'r',
        'synthesized': false,
        'backendVersion': ?backendVersion,
      };

      expect(
        FixtureSession.fromJson(
          header(backendVersion: 'agno==2.6.10'),
        ).backendVersion,
        'agno==2.6.10',
      );
      // Absent → null (the seven synthesized fixtures omit it and must still
      // parse unchanged).
      expect(FixtureSession.fromJson(header()).backendVersion, isNull);
    });

    test('FixtureSession.fromJson rejects a wrong-typed backendVersion '
        '(5.3 AC3)', () {
      expect(
        () => FixtureSession.fromJson(const {
          'koelVersion': '0.0.1',
          'adapter': 'koel_agno@0.0.1',
          'captured': '2026-06-03T00:00:00.000Z',
          'threadId': 't',
          'runId': 'r',
          'synthesized': false,
          'backendVersion': 42, // not a String
        }),
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

  // 5.3 AC4 — the corrupt-line → fixture-naming FormatException guard (closes
  // the 3.3 + 3.5 deferral cluster; reachable once live captures can emit
  // partial/truncated lines). The shared guard sits behind both FixtureLoader
  // and ConformanceRunner; here it is exercised with a fixture-style source.
  group('decodeFixtureEvent corrupt-line guard', () {
    Matcher throwsFormatNaming(String needle) => throwsA(
      isA<FormatException>().having(
        (e) => e.message,
        'message',
        contains(needle),
      ),
    );

    test('a well-formed line decodes to (type, payload)', () {
      final event = decodeFixtureEvent(
        'fixture "x"',
        1,
        '{"type":"RUN_STARTED","timestamp":"2026-01-01T00:00:00.000Z",'
            '"payload":{"type":"RUN_STARTED","threadId":"t","runId":"r"}}',
      );
      expect(event.type, 'RUN_STARTED');
      expect(event.payload['threadId'], 't');
    });

    test('a non-object line throws a fixture-naming FormatException', () {
      expect(
        () => decodeFixtureEvent('fixture "x"', 3, '[1, 2, 3]'),
        throwsFormatNaming('fixture "x" line 3'),
      );
    });

    test('a missing payload throws (not an opaque TypeError)', () {
      expect(
        () => decodeFixtureEvent('fixture "x"', 2, '{"type":"RUN_STARTED"}'),
        throwsFormatNaming('missing or non-object `payload`'),
      );
    });

    test('a non-object payload throws', () {
      expect(
        () => decodeFixtureEvent('fixture "x"', 2, '{"payload":7}'),
        throwsFormatNaming('missing or non-object `payload`'),
      );
    });

    test('a non-String payload.type throws', () {
      expect(
        () => decodeFixtureEvent('fixture "x"', 4, '{"payload":{"type":9}}'),
        throwsFormatNaming('`type` is missing or not a String'),
      );
    });
  });
}
