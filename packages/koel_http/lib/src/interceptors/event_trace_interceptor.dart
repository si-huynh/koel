import 'dart:async';

import 'package:koel_core/koel_core.dart';

import 'trace_entry.dart';

/// Captures a structured [TraceEntry] for every event flowing through a run and
/// writes it to a consumer-supplied `Sink<TraceEntry>` (Story 4.6 / FR-B2).
///
/// The machine-readable complement to [`LoggingInterceptor`](LoggingInterceptor):
/// Logging writes human-readable lines to `package:logging` for a developer
/// watching a console; `EventTraceInterceptor` writes typed records a consumer
/// routes to an observability backend, a DevTools panel (Epic 8), or a test
/// collector. Compose whichever (or both) into `HttpAgent(interceptors: …)`.
///
/// ```dart
/// final trace = <TraceEntry>[];
/// HttpAgent(
///   url: endpoint,
///   interceptors: [EventTraceInterceptor(sink: _ListSink(trace))],
/// );
/// ```
///
/// **One entry per event, bracketed by lifecycle markers.** A run yields:
/// - one [TracePhase.request] marker at run start (`event: null`,
///   `runDuration: Duration.zero`),
/// - one [TracePhase.event] entry per emitted non-error `AgUiEvent` — the
///   load-bearing guarantee: the entries' events match the raw stream in count
///   and order,
/// - one [TracePhase.error] entry for a terminal `RunErrorEvent` (carrying it),
///   emitted **instead of** an [TracePhase.event] entry, so every event still
///   produces exactly one entry,
/// - one [TracePhase.response] marker on graceful completion (`event: null`) —
///   suppressed on the error path, where the trailing entry is the error.
///
/// A cancelled run simply stops: no [TracePhase.response] marker, no error.
///
/// **The sink contract.** This interceptor only `add`s to `sink`; it never
/// `close`s it. The consumer owns the sink's lifecycle — it may outlive a single
/// run (e.g. one sink draining many sessions), so closing it here would be a
/// use-after-close bug waiting to happen.
///
/// `final` — there is no Epic-5 subclass (unlike `AuthInterceptor`).
final class EventTraceInterceptor implements Interceptor {
  /// Creates an interceptor that writes a [TraceEntry] per event to [sink]
  /// (Addendum A.2). [sink] is the synchronous `dart:core` `Sink<TraceEntry>`
  /// (`add`/`close`) — not a `StreamSink`; the consumer owns and closes it.
  EventTraceInterceptor({required Sink<TraceEntry> sink}) : _sink = sink;

  final Sink<TraceEntry> _sink;

  @override
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input) {
    // A controller wrapper (the `abortOnCancel`/`RetryInterceptor` shape) lets
    // the request marker capture an accurate run-start on first listen and the
    // response marker fire on `onDone` — neither reachable through a plain
    // `.map`. The stream itself is forwarded untouched; trace entries are a side
    // channel to [_sink].
    final controller = StreamController<AgUiEvent>(sync: true);
    StreamSubscription<AgUiEvent>? sub;
    late final DateTime start;
    var errored = false;

    // Trace is a side channel: a faulty consumer sink (full/closed/throwing)
    // must never disrupt the run — neither drop a downstream event mid-stream
    // nor abort run setup before the upstream is even subscribed. Best-effort.
    void write(TraceEntry entry) {
      try {
        _sink.add(entry);
      } on Object {
        // Swallowed by design — the run is the source of truth, the trace is not.
      }
    }

    void emit(TracePhase phase, AgUiEvent? event) {
      final now = DateTime.now();
      write(
        TraceEntry(
          timestamp: now,
          phase: phase,
          runDuration: now.difference(start),
          event: event,
        ),
      );
    }

    controller
      ..onListen = () {
        start = DateTime.now();
        write(
          TraceEntry(
            timestamp: start,
            phase: TracePhase.request,
            runDuration: Duration.zero,
          ),
        );
        sub = chain
            .proceed(input)
            .listen(
              (event) {
                if (event is RunErrorEvent) {
                  errored = true;
                  emit(TracePhase.error, event);
                } else {
                  emit(TracePhase.event, event);
                }
                controller.add(event);
              },
              // The chain converts stream errors to terminal `RunErrorEvent`
              // values, so this should not fire; forward rather than swallow if
              // the upstream contract is ever broken. Mark `errored` so a stray
              // trailing `onDone` does not emit a spurious `response` after the
              // error (parity with `LoggingInterceptor`).
              onError: (Object error, StackTrace stack) {
                errored = true;
                controller.addError(error, stack);
              },
              onDone: () {
                // Graceful completion only — the error path's trailing entry is
                // the `error` marker, so no `response` follows it.
                if (!errored) emit(TracePhase.response, null);
                controller.close();
              },
            );
      }
      ..onPause = () {
        sub?.pause();
      }
      ..onResume = () {
        sub?.resume();
      }
      ..onCancel = () {
        // Forward cancel upstream so teardown stays transparent (NFR-8). No
        // trace entry on cancel — AC2 covers request/event/response/error only.
        final live = sub;
        sub = null;
        return live?.cancel();
      };
    return controller.stream;
  }
}
