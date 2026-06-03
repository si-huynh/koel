import 'package:koel_core/koel_core.dart';
import 'package:koel_test/koel_test.dart';
import 'package:koel_test/src/fixture_envelope.dart';
import 'package:test/test.dart';

/// A non-conformant agent that violates the never-throw SPI by surfacing a raw
/// (non-[KoelError]) error on its stream — exercises the runner's defensive
/// wrap-into-[AgentError] path.
final class _ThrowingAgent implements AbstractAgent {
  @override
  Stream<AgUiEvent> run(RunAgentInput input) =>
      Stream<AgUiEvent>.error(StateError('kaboom'));
}

void main() {
  group(ConformanceRunner, () {
    // One entry per AG-UI type in all_event_types.jsonl (RUN_STARTED … CUSTOM).
    const typeCount = 28;

    test('all-pass: a fixture-backed agent reproduces every event type', () async {
      final agent = await MockAgent.fromFixture('all_event_types');

      final report = await const ConformanceRunner().runAgainst(agent);

      expect(report.failed, isEmpty);
      expect(report.passed, hasLength(typeCount));
      // A scalar type, the byte-equal Uint8List type, and the open CUSTOM type —
      // the REASONING_ENCRYPTED_VALUE pass proves AgUiEvent_equal over Uint8List.
      expect(
        report.passed,
        containsAll(<String>[
          'RUN_STARTED',
          'REASONING_ENCRYPTED_VALUE',
          'CUSTOM',
        ]),
      );
      expect(report.agentName, contains('MockAgent'));
      expect(report.runDuration, greaterThanOrEqualTo(Duration.zero));
    });

    test(
      'missing-type fail: an empty agent fails every type with null actual',
      () async {
        final report = await const ConformanceRunner().runAgainst(
          MockAgent.fromEvents(const []),
        );

        expect(report.passed, isEmpty);
        expect(report.failed, hasLength(typeCount));
        expect(
          report.failed.every((failure) => failure.actual == null),
          isTrue,
        );
        expect(report.failed.every((failure) => failure.error == null), isTrue);
      },
    );

    test(
      'diverged-type fail: a same-type-but-unequal event lands in failed',
      () async {
        final report = await const ConformanceRunner().runAgainst(
          MockAgent.fromEvents(const [
            RunStartedEvent(threadId: 'other', runId: 'other'),
          ]),
        );

        expect(report.passed, isEmpty);
        expect(report.failed, hasLength(typeCount));

        final runStarted = report.failed.singleWhere(
          (failure) => failure.eventType == 'RUN_STARTED',
        );
        expect(
          runStarted.actual,
          const RunStartedEvent(threadId: 'other', runId: 'other'),
        );
        // Every other type was not emitted at all.
        final others = report.failed.where(
          (failure) => failure.eventType != 'RUN_STARTED',
        );
        expect(others, hasLength(typeCount - 1));
        expect(others.every((failure) => failure.actual == null), isTrue);
      },
    );

    test(
      'run-error capture: a RUN_ERROR run-terminates and tags failures',
      () async {
        final report = await const ConformanceRunner().runAgainst(
          MockAgent.fromEvents(const [
            RunStartedEvent(threadId: 't', runId: 'r'),
            RunErrorEvent(
              error: AgentError(message: 'boom', code: KoelErrorCode.unknown),
            ),
          ]),
        );

        // RUN_STARTED and RUN_ERROR match the fixture exactly; the rest are missing.
        expect(
          report.passed,
          containsAll(<String>['RUN_STARTED', 'RUN_ERROR']),
        );
        expect(report.failed, isNotEmpty);
        expect(report.failed.every((failure) => failure.error != null), isTrue);
        expect(
          report.failed.first.error,
          const AgentError(message: 'boom', code: KoelErrorCode.unknown),
        );
      },
    );

    test(
      'throwing agent: a raw stream error wraps into AgentError(unknown)',
      () async {
        final report = await const ConformanceRunner().runAgainst(
          _ThrowingAgent(),
        );

        expect(report.passed, isEmpty);
        expect(report.failed, hasLength(typeCount));
        final error = report.failed.first.error;
        expect(error, isA<AgentError>());
        expect(error!.code, KoelErrorCode.unknown);
        expect(error.message, contains('agent threw during run'));
      },
    );

    test('ConformanceReport has freezed value semantics', () {
      ConformanceReport build() => const ConformanceReport(
        passed: ['RUN_STARTED'],
        failed: [],
        agentName: 'MockAgent',
        runDuration: Duration.zero,
      );

      expect(build(), equals(build()));
    });

    // 5.3 AC4 — the corpus-line guard `_loadExpectedCorpus` routes through.
    // The runner reads its own shipped, all-pass corpus, so the corrupt path is
    // unreachable with valid data; this locks that a malformed corpus line
    // names the corpus in a FormatException rather than an opaque TypeError.
    test('a malformed corpus line throws a corpus-naming FormatException', () {
      const source = 'conformance corpus all_event_types.jsonl';
      expect(
        () => decodeFixtureEvent(source, 5, '{"payload":{"no":"type"}}'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            allOf(contains(source), contains('line 5')),
          ),
        ),
      );
    });
  });
}
