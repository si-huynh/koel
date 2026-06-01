import 'dart:async';

import 'package:koel_core/koel_core.dart';
import 'package:logging/logging.dart';

/// Writes human-readable run logs to `package:logging` at the architecture-§4
/// per-category levels, gated by a single emission [level] threshold (Story 4.6
/// / FR-B2/B3). The human-readable complement to
/// [`EventTraceInterceptor`](EventTraceInterceptor)'s structured `TraceEntry`
/// capture; compose whichever (or both) into `HttpAgent(interceptors: …)`.
///
/// ```dart
/// Logger.root.onRecord.listen((r) => stdout.writeln('${r.level} ${r.message}'));
/// HttpAgent(url: endpoint, interceptors: [LoggingInterceptor(level: Level.FINE)]);
/// ```
///
/// **[level] is an emission THRESHOLD, not a uniform level.** Each lifecycle
/// category logs at its own **fixed** architecture-§4 level; [level] is the
/// minimum that actually emits. So `LoggingInterceptor(level: Level.FINE)` shows
/// everything, and the default `Level.INFO` shows lifecycle + errors but hides
/// the per-event tail. The mapping (architecture §4):
///
/// | Category | Level |
/// | --- | --- |
/// | run start, response start, completion | `Level.INFO` |
/// | per-event tail, cancellation drop | `Level.FINE` |
/// | terminal `ProtocolError` | `Level.SEVERE` |
/// | terminal other `KoelError` | `Level.WARNING` |
///
/// **The cancellation drop is `Level.FINE`, once per cancelled run.** It is
/// **not** the once-per-process abort-not-honored `Level.WARNING` that
/// `cancellation.dart` (Story 4.3) owns — that one stays untouched. A consumer
/// at `Level.FINE` sees one drop record per run they cancel.
///
/// **No secrets, ever.** Lifecycle logs carry run/thread ids and event *types*,
/// never event payloads or `input.forwardedProps` (which may hold the Story 4.5
/// reserved auth-headers key). Per-event detail is `FINE` (dev opt-in). PII
/// redaction (Story 4.7) composes *before* this interceptor for consumers who
/// need it. No `print` — `package:logging` exclusively (architecture §4).
///
/// `final` — there is no Epic-5 subclass (unlike `AuthInterceptor`).
final class LoggingInterceptor implements Interceptor {
  /// Creates a logging interceptor emitting at or above [level] (Addendum A.2).
  ///
  /// [level] defaults to `Level.INFO` — lifecycle + errors, no per-event tail.
  /// Pass `Level.FINE` for per-event and cancellation tracing in development.
  LoggingInterceptor({Level level = Level.INFO}) : _level = level;

  final Level _level;
  final Logger _log = Logger('koel_http.logging');

  /// Logs [message] at its category's fixed [categoryLevel] iff that level
  /// clears the [_level] threshold — the trap-#2 gate that makes [_level] a
  /// minimum rather than a uniform level.
  void _emit(Level categoryLevel, String Function() message) {
    // Lazy message: the string (and any `runtimeType` lookup it interpolates) is
    // built only when the category clears the threshold — so the per-event FINE
    // tail costs nothing on the hot path at the default `Level.INFO`.
    if (categoryLevel >= _level) _log.log(categoryLevel, message());
  }

  /// The fixed terminal-error level (architecture §4): an unrecoverable
  /// `ProtocolError` is `SEVERE`; every other `KoelError` is a `WARNING`. The
  /// `default` is mandatory — `koel_lints`' `exhaustive_switch_must_have_default`
  /// is an ERROR-severity rule even over a sealed type.
  Level _errorLevel(KoelError error) => switch (error) {
    ProtocolError() => Level.SEVERE,
    _ => Level.WARNING,
  };

  @override
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input) {
    // A controller wrapper (the `abortOnCancel` shape) is mandatory here: only a
    // controller's `onCancel` exposes cancellation, which a `.map`/transformer
    // cannot see. Forwarding cancel upstream keeps the 4.3 sub-50ms abort
    // invariant (NFR-8) intact — logging must be transparent to teardown.
    final controller = StreamController<AgUiEvent>(sync: true);
    StreamSubscription<AgUiEvent>? sub;
    var responseStarted = false;
    var errored = false;

    controller
      ..onListen = () {
        _emit(
          Level.INFO,
          () => 'run started: thread=${input.threadId} run=${input.runId}',
        );
        sub = chain
            .proceed(input)
            .listen(
              (event) {
                if (event is RunErrorEvent) {
                  errored = true;
                  final error = event.error;
                  _emit(
                    _errorLevel(error),
                    () => 'run failed: ${error.code} — ${error.message}',
                  );
                } else {
                  if (!responseStarted) {
                    responseStarted = true;
                    _emit(
                      Level.INFO,
                      () => 'response started: run=${input.runId}',
                    );
                  }
                  _emit(Level.FINE, () => 'event: ${event.runtimeType}');
                }
                controller.add(event);
              },
              // The chain converts stream errors to terminal `RunErrorEvent`
              // values, so this is a contract-breach safety net: log + forward,
              // never swallow.
              onError: (Object error, StackTrace stack) {
                errored = true;
                _emit(
                  Level.WARNING,
                  () => 'run stream error: ${error.runtimeType}',
                );
                controller.addError(error, stack);
              },
              onDone: () {
                // Graceful completion only — a run that already logged a terminal
                // error is not also "completed".
                if (!errored) {
                  _emit(Level.INFO, () => 'run completed: run=${input.runId}');
                }
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
        // Per-run FINE drop trace — NOT the 4.3 once-per-process WARNING. Forward
        // cancel upstream so teardown stays sub-50ms (NFR-8).
        _emit(
          Level.FINE,
          () => 'run cancelled — dropping connection: run=${input.runId}',
        );
        final live = sub;
        sub = null;
        return live?.cancel();
      };
    return controller.stream;
  }
}
