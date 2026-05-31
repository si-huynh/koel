import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:koel_core/koel_core.dart';

part 'conformance_report.freezed.dart';

/// One per-event-type conformance miss produced by
/// [ConformanceRunner.runAgainst]: the agent failed to reproduce the canonical
/// fixture event for a single AG-UI type.
///
/// Two distinct failure shapes share this record, told apart by [actual]:
/// - **diverged** — the agent emitted an event of the right type but it is not
///   structurally equal to [expected]; [actual] holds that divergent event.
/// - **missing** — the agent emitted no event of this type at all; [actual] is
///   `null` (a missing type has no actual event to carry).
///
/// `freezed`-only (no JSON codec): the report needs structural `==`/`hashCode`
/// for value comparison in tests, not a wire form.
@freezed
abstract class ConformanceFailure with _$ConformanceFailure {
  /// Records that the agent failed to reproduce the canonical [expected] event
  /// for the AG-UI type [eventType].
  ///
  /// [actual] is the agent's same-type-but-divergent event, or `null` when it
  /// emitted no event of [eventType]. [error] carries the run-terminating
  /// [KoelError] when the agent errored or threw during the drive, else `null`.
  const factory ConformanceFailure({
    required String eventType,
    required AgUiEvent expected,
    AgUiEvent? actual,
    KoelError? error,
  }) = _ConformanceFailure;
}

/// The result of driving an [AbstractAgent] through the synthesized
/// type-coverage corpus: which AG-UI event types it reproduced, and which it
/// missed.
///
/// `freezed` gives `DeepCollectionEquality` `==` over [passed] and [failed], so
/// two reports built from equal inputs compare equal — the contract the runner's
/// own tests assert against.
@freezed
abstract class ConformanceReport with _$ConformanceReport {
  /// Assembles a report from the per-type outcome of one conformance drive.
  ///
  /// [passed] holds the AG-UI wire-type names the agent reproduced exactly;
  /// [failed] holds one [ConformanceFailure] per type it did not. [agentName] is
  /// the runtime type name of the agent under test, and [runDuration] is the
  /// wall-clock time of the drive (measured with a monotonic [Stopwatch]).
  const factory ConformanceReport({
    required List<String> passed,
    required List<ConformanceFailure> failed,
    required String agentName,
    required Duration runDuration,
  }) = _ConformanceReport;
}
