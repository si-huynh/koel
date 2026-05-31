import 'dart:async';

import 'package:koel_core/koel_core.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

/// The sub-50ms cancellation budget (NFR-8 / Addendum C.2): when a consumer
/// cancels a run, the transport abort must tear the connection down within this
/// window. A client that does not is handled by silent-drop + a one-shot
/// warning.
const Duration _abortBudget = Duration(milliseconds: 50);

/// koel_http's cancellation logger — the abort-not-honored warning is its only
/// record (architecture §4: `Level.WARNING` for "single debug warnings, e.g.
/// abort-not-honored"). The normal per-event cancellation trace is `Level.FINE`
/// and belongs to the `LoggingInterceptor` (Story 4.6), not here.
final Logger _log = Logger('koel_http.cancellation');

/// Process-once gate (Addendum C.2): a client that ignores abort warns **once
/// per process**, not once per cancellation. Library-private; flipped on first
/// emission and never reset (its once-ness is the contract).
var _abortNotHonoredWarned = false;

/// Resets the abort-not-honored process-once gate to its initial state.
///
/// **Test-only.** Production never resets the gate — warning *once per process*
/// is the contract (Addendum C.2), which is why `@visibleForTesting` makes the
/// analyzer reject any non-test caller. A test asserting "exactly one warning
/// across N cancellations" calls this first so the count is deterministic
/// regardless of what tripped the gate earlier in the same process.
@visibleForTesting
void resetAbortNotHonoredWarning() => _abortNotHonoredWarned = false;

/// Wraps [events] so a consumer `cancel()` mid-run forces a **prompt** connection
/// teardown via [abort] — the transport's explicit abort handle — instead of
/// waiting for cancel to thread down through `SseParser`'s `async*` stream (which
/// strands the cancel and blows the <50ms budget, NFR-8).
///
/// Two guarantees:
/// - **Sub-50ms TCP abort.** [abort] fires the instant the consumer cancels.
/// - **Silent drop.** No event escapes after cancel: the wrapping controller is
///   torn down on `onCancel`, so even a client that keeps producing has nowhere
///   to deliver.
///
/// Neither [abort] nor the upstream cancel is awaited on the cancel-return path:
/// a client that ignores abort must not be able to **hang** the consumer's
/// `cancel()`. A fire-and-forget watchdog races the teardown against the budget
/// and emits one `Level.WARNING` (process-once) if it stalls — the
/// abort-not-honored fallback.
Stream<AgUiEvent> abortOnCancel(
  Stream<AgUiEvent> events,
  Future<void> Function() abort,
) {
  final controller = StreamController<AgUiEvent>(sync: true);
  StreamSubscription<AgUiEvent>? subscription;
  controller
    ..onListen = () {
      subscription = events.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
    }
    ..onPause = () {
      subscription?.pause();
    }
    ..onResume = () {
      subscription?.resume();
    }
    ..onCancel = () {
      final upstream = subscription;
      subscription = null;
      _watchAbortBudget(
        Future.wait<void>([
          Future<void>.sync(abort),
          if (upstream != null) upstream.cancel(),
        ]),
      );
      // Return nothing: the consumer's cancel() completes immediately and never
      // blocks on the socket teardown (which a misbehaving client could stall).
    };
  return controller.stream;
}

/// Fires the one-shot abort-not-honored warning if [teardown] has not settled
/// within [_abortBudget]. A settled teardown (success or error) cancels the
/// watchdog, so an honoring client never warns and leaves no pending timer.
void _watchAbortBudget(Future<void> teardown) {
  final timer = Timer(_abortBudget, () {
    if (_abortNotHonoredWarned) return;
    _abortNotHonoredWarned = true;
    _log.warning(
      'HTTP client did not honor cancellation within '
      '${_abortBudget.inMilliseconds}ms. koel dropped the connection on its '
      'side (no further events are delivered), but the underlying socket may '
      'linger until the client releases it. Emitted once per process.',
    );
  });
  // Errors from teardown are irrelevant: a cancelled run is not a failed one,
  // and a settled-with-error teardown still means the client responded.
  teardown.then((_) => timer.cancel(), onError: (_) => timer.cancel());
}
