import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:koel_core/koel_core.dart';

import 'conformance_report.dart';
import 'fixture_envelope.dart';

/// The raw outcome of one conformance drive: the agent's emitted `events`, the
/// run-terminating `error` (the first `RUN_ERROR`, or a wrapped thrown error),
/// and the monotonic `elapsed` wall-clock of the drive.
typedef _DriveOutcome = ({
  List<AgUiEvent> events,
  KoelError? error,
  Duration elapsed,
});

/// One canonical corpus entry: the AG-UI wire-type `label` and the `event`
/// decoded from that fixture line. The label is read from the wire (the spec's
/// `type` string) because the sealed [AgUiEvent] has no polymorphic type getter.
typedef _Expected = ({String label, AgUiEvent event});

/// Drives an [AbstractAgent] through every AG-UI event type and reports, per
/// type, whether the agent reproduced the canonical event — the backend-agnostic
/// conformance check (FR-G4).
///
/// The expected corpus is the synthesized `all_event_types.jsonl` fixture (one
/// event of every AG-UI type). The runner drives `agent.run(input)` **directly**
/// — not through `KoelClient` — because that fixture is a *type catalogue*, not a
/// valid run (it carries both `RUN_ERROR` and `RUN_FINISHED`), so the
/// `koel_core` pipeline's verify stage would reject it. Conformance asks whether
/// the agent *emits* the right events, so the comparison is against the agent's
/// raw stream.
///
/// Each expected event is matched to the agent's output by `runtimeType` (a
/// cheap, stable same-type test over `freezed` concrete types) and decided by
/// `freezed`-generated `==` — the structural `AgUiEvent_equal` rule documented in
/// `koel_core/CONFORMANCE.md` (Addendum AR-16), which compares all fields
/// including byte-equal `Uint8List`.
///
/// Holds no state; construct it `const`.
final class ConformanceRunner {
  /// Creates a runner. Stateless — every drive is self-contained.
  const ConformanceRunner();

  /// Drives [agent] through the synthesized type-coverage corpus and returns a
  /// [ConformanceReport] recording pass/fail per AG-UI event type.
  ///
  /// A type **passes** when the agent emits an event of that type structurally
  /// equal to the canonical fixture event; it **fails** when the agent emits a
  /// same-type-but-divergent event ([ConformanceFailure.actual] is that event)
  /// or emits no event of that type at all ([ConformanceFailure.actual] is
  /// `null`). When the agent terminates the run with an error — emitting a
  /// `RUN_ERROR` or (defensively) throwing — every resulting failure carries it
  /// in [ConformanceFailure.error].
  Future<ConformanceReport> runAgainst(AbstractAgent agent) async {
    final corpus = await _loadExpectedCorpus();
    final outcome = await _drive(agent);

    final passed = <String>[];
    final failed = <ConformanceFailure>[];
    for (final (:label, :event) in corpus) {
      final sameType = outcome.events
          .where((emitted) => emitted.runtimeType == event.runtimeType)
          .toList(growable: false);
      if (sameType.any((emitted) => emitted == event)) {
        passed.add(label);
      } else {
        failed.add(
          ConformanceFailure(
            eventType: label,
            expected: event,
            actual: sameType.isEmpty ? null : sameType.first,
            error: outcome.error,
          ),
        );
      }
    }

    return ConformanceReport(
      passed: passed,
      failed: failed,
      agentName: agent.runtimeType.toString(),
      runDuration: outcome.elapsed,
    );
  }

  /// Reads `all_event_types.jsonl` as the expected corpus, preserving each
  /// line's wire-type label alongside the decoded event.
  ///
  /// Mirrors `FixtureLoader`'s `package:` asset-URI resolution
  /// ([Isolate.resolvePackageUri] → [File]), so it reads correctly from any
  /// consuming package's test CWD. The `_session` header line is skipped; each
  /// remaining line pairs its `payload['type']` with [AgUiEvent.fromWire] of
  /// that payload. The runner re-reads the raw lines (rather than calling
  /// `FixtureLoader.loadSynthesized`) precisely because the loader drops the
  /// wire-type label, which the per-type report needs.
  Future<List<_Expected>> _loadExpectedCorpus() async {
    final uri = Uri.parse(
      'package:koel_test/src/fixtures/synthesized/all_event_types.jsonl',
    );
    final resolved = await Isolate.resolvePackageUri(uri);
    if (resolved == null) {
      throw StateError('cannot resolve the bundled conformance corpus: $uri');
    }
    final lines = (await File.fromUri(
      resolved,
    ).readAsLines()).where((line) => line.trim().isNotEmpty).toList();

    // Line 0 is the `_session` header; lines 1..N are the type catalogue. A
    // malformed/hand-edited corpus line throws a corpus-naming `FormatException`
    // (the same guard as `FixtureLoader`) instead of an opaque `TypeError`.
    const source = 'conformance corpus all_event_types.jsonl';
    final corpus = <_Expected>[];
    for (var i = 1; i < lines.length; i++) {
      final (:type, :payload) = decodeFixtureEvent(source, i, lines[i]);
      corpus.add((label: type, event: AgUiEvent.fromWire(payload)));
    }
    return corpus;
  }

  /// Drives [agent] directly and collects its raw emission.
  ///
  /// Accumulates every emitted event, captures the first `RUN_ERROR`'s error as
  /// the run-terminating failure, and times the drive with a monotonic
  /// [Stopwatch]. An [AbstractAgent] adapter must never throw (it emits
  /// `RUN_ERROR` instead), but the harness must survive a non-conformant one: a
  /// thrown [KoelError] is captured verbatim, any other thrown object is wrapped
  /// as an [AgentError]`(unknown)`.
  Future<_DriveOutcome> _drive(AbstractAgent agent) async {
    const input = RunAgentInput(
      threadId: 'conformance-thread',
      runId: 'conformance-run',
    );
    final events = <AgUiEvent>[];
    KoelError? runError;
    final stopwatch = Stopwatch()..start();
    try {
      await for (final event in agent.run(input)) {
        events.add(event);
        if (runError == null && event is RunErrorEvent) {
          runError = event.error;
        }
      }
    } on KoelError catch (error) {
      runError = error;
    } catch (error) {
      runError = AgentError(
        message: 'agent threw during run: $error',
        code: KoelErrorCode.unknown,
        cause: error,
      );
    }
    stopwatch.stop();
    return (events: events, error: runError, elapsed: stopwatch.elapsed);
  }
}
