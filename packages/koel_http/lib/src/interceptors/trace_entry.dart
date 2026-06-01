import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:koel_core/koel_core.dart';

part 'trace_entry.freezed.dart';

/// Where in a run's lifecycle a [TraceEntry] was captured.
///
/// The `EventTraceInterceptor` sees only the event stream and the run `input` —
/// it has no view of the HTTP request/response. So the phases mark **run
/// lifecycle position**, not transport-level request/response:
///
/// - [request] — one marker at run start, before any event (entry's `event` is
///   `null`).
/// - [event] — one entry per emitted non-error `AgUiEvent`; the bulk of a trace.
/// - [response] — one marker on graceful completion, after the last event
///   (entry's `event` is `null`).
/// - [error] — one entry for a terminal `RunErrorEvent`, carrying that event
///   **instead of** an [event] entry, so every event still produces exactly one
///   entry.
enum TracePhase {
  /// One marker at run start, before any event (the entry's `event` is `null`).
  request,

  /// One entry per emitted non-error `AgUiEvent` — the bulk of a trace.
  event,

  /// One marker on graceful completion, after the last event (the entry's
  /// `event` is `null`).
  response,

  /// One entry for a terminal `RunErrorEvent`, carrying that event **instead
  /// of** an [event] entry, so every event still produces exactly one entry.
  error,
}

/// A single structured observation of a run, written to a consumer's
/// `Sink<TraceEntry>` by the `EventTraceInterceptor` (Story 4.6 / FR-B2).
///
/// The machine-readable complement to `LoggingInterceptor`'s human-readable
/// logs: where Logging writes lines to `package:logging` for a developer to
/// read, a `TraceEntry` is a typed record a consumer routes to an observability
/// backend, a DevTools panel (Epic 8), or a test collector.
///
/// freezed-**without**-json: a `TraceEntry` is an in-process Dart value handed
/// straight to a `Sink`, never serialized to the wire, so it carries no JSON
/// codec (the [`RunAgentInput`](RunAgentInput) precedent). freezed supplies
/// value equality, `hashCode`, `copyWith`, and `toString` — so two entries with
/// equal fields are `==`, which is what the trace assertions rely on.
@freezed
abstract class TraceEntry with _$TraceEntry {
  /// Captures one [phase] of a run at [timestamp], [runDuration] after the run
  /// started.
  ///
  /// [event] is the `AgUiEvent` this entry observes for a [TracePhase.event] or
  /// [TracePhase.error] entry, and `null` for the [TracePhase.request] /
  /// [TracePhase.response] lifecycle markers (which bracket the stream and carry
  /// no event of their own). [runDuration] is elapsed-since-run-start —
  /// `Duration.zero` for the opening [TracePhase.request] marker.
  const factory TraceEntry({
    required DateTime timestamp,
    required TracePhase phase,
    required Duration runDuration,
    AgUiEvent? event,
  }) = _TraceEntry;
}
