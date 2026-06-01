import 'dart:async';

import 'package:koel_core/koel_core.dart';
import 'package:meta/meta.dart';

/// Transport-level connection lifecycle hooks for `HttpAgent` (FR-B6) — the home
/// of `onConnect`/`onDisconnect`/`onReconnectAttempt`.
///
/// An **immutable holder** of the three optional observer callbacks an
/// `HttpAgent` is built with. It is created once per agent and lives across
/// every run and every reconnect, so it carries **no** per-connection state.
/// Each physical connection opens its own [ConnectionScope] via [connected]
/// (called from inside the transport terminal, beneath `RetryInterceptor`), so a
/// run that reconnects fires the hooks **once per attempt** — exactly the
/// per-connection accounting FR-B6 / DevTools (Epic 8) need, with no counting
/// logic in the agent.
///
/// `onReconnectAttempt` is **not** fired here: it belongs to `RetryInterceptor`,
/// which already invokes it once per scheduled retry (Story 4.4). This holder
/// merely carries the callback so `HttpAgent.run` can route it into
/// `RetryInterceptor.forAgent` unchanged.
///
/// All callbacks are **fire-and-forget**: a throwing observer is swallowed so it
/// can never abort a recoverable run or hang a consumer's `cancel()`. The hooks
/// are pure callbacks — this layer does **no** logging (connection-lifecycle
/// logging is the `LoggingInterceptor`'s concern, Story 4.6).
///
/// `@internal`, not barrel-exported: the public surface is the `HttpAgent`
/// constructor callbacks. DevTools subscribes through those closures without
/// reaching any private state (AC3).
@internal
final class ConnectionLifecycle {
  /// Bundles the optional [onConnect]/[onDisconnect]/[onReconnectAttempt]
  /// callbacks. `const`-constructible — the holder is pure data.
  const ConnectionLifecycle({
    this.onConnect,
    this.onDisconnect,
    this.onReconnectAttempt,
  });

  /// Fires when an SSE connection's response headers arrive — once per physical
  /// connection (so once per reconnect attempt that reaches the server),
  /// status-agnostic (a non-2xx response **did** connect). A pre-headers failure
  /// (connection refused / TLS / connect-timeout) never fires it.
  final void Function()? onConnect;

  /// Fires exactly once when a connection's stream ends: graceful close →
  /// `null`; stream error → the error; non-2xx → the synthesized
  /// `TransportError`; consumer cancel → `null`. Always paired one-to-one with
  /// an [onConnect].
  final void Function(Object? cause)? onDisconnect;

  /// Carried for `RetryInterceptor.forAgent` — **not** invoked by this holder.
  /// Fires once per scheduled retry with the 1-based attempt index and the
  /// jittered delay (Story 4.4).
  final void Function(int attempt, Duration delay)? onReconnectAttempt;

  /// Opens the tracking scope for one physical connection: fires [onConnect]
  /// (headers received) and returns a [ConnectionScope] that fires [onDisconnect]
  /// exactly once when that connection's stream ends.
  ///
  /// Call **once** per transport-terminal run (per reconnect attempt). The
  /// returned scope owns the per-connection once-guard; the holder stays
  /// stateless and reusable across attempts.
  ConnectionScope connected() {
    final onConnect = this.onConnect;
    if (onConnect != null) {
      try {
        onConnect();
      } on Object {
        // Fire-and-forget telemetry: a throwing observer must not abort the run
        // (mirrors `RetryInterceptor`'s reconnect-observer guard).
      }
    }
    return ConnectionScope._(onDisconnect);
  }
}

/// The per-connection disconnect tracker handed back by
/// [ConnectionLifecycle.connected]. Holds the once-guard for a single physical
/// connection so `onDisconnect` fires **exactly once** no matter which path ends
/// the stream.
///
/// `@internal`: constructed only by [ConnectionLifecycle]; consumers never name
/// this type.
@internal
final class ConnectionScope {
  ConnectionScope._(this._onDisconnect);

  final void Function(Object? cause)? _onDisconnect;
  var _disconnected = false;

  /// Fires `onDisconnect([cause])` the first time it is reached for this
  /// connection; later calls are no-ops. Used directly by the transport's
  /// non-2xx path (which throws before any stream is built) and internally by
  /// [track]. Fire-and-forget: a throwing observer is swallowed.
  void disconnect(Object? cause) {
    if (_disconnected) return;
    _disconnected = true;
    final onDisconnect = _onDisconnect;
    if (onDisconnect == null) return;
    try {
      onDisconnect(cause);
    } on Object {
      // Fire-and-forget telemetry: a throwing observer must not abort the run or
      // hang a consumer's cancel() (this can fire from a sync controller's
      // onCancel/onDone).
    }
  }

  /// Wraps [events] so the stream's termination fires [disconnect] exactly once:
  /// `onDone` → `null`, `onError` → the error (then the error is forwarded),
  /// consumer `onCancel` → `null`.
  ///
  /// A single-subscription `StreamController` (mirroring `abortOnCancel`) is the
  /// only primitive that observes a consumer cancel as a side-effect hook — a
  /// `try/finally` in the terminal's `async*` would not, because `abortOnCancel`
  /// strands the cancel. Slotted **inside** `abortOnCancel`, so the sub-50ms TCP
  /// abort still fires first and independently (the disconnect callback is
  /// fire-and-forget and cannot extend the budget). Pause/resume pass straight
  /// through for backpressure.
  Stream<AgUiEvent> track(Stream<AgUiEvent> events) {
    final controller = StreamController<AgUiEvent>(sync: true);
    StreamSubscription<AgUiEvent>? subscription;
    controller
      ..onListen = () {
        subscription = events.listen(
          controller.add,
          onError: (Object error, StackTrace stackTrace) {
            // Fire the disconnect *before* forwarding so an error cause wins the
            // once-guard over a trailing `onDone`'s `null`. Not closed here on
            // purpose: every upstream is `async*`/`buildStage`-backed and emits
            // `done` after an error, so `onDone` below closes the controller and
            // cancels the subscription — mirroring `abortOnCancel`.
            disconnect(error);
            controller.addError(error, stackTrace);
          },
          onDone: () {
            disconnect(null);
            controller.close();
          },
        );
      }
      ..onPause = () {
        subscription?.pause();
      }
      ..onResume = () {
        subscription?.resume();
      }
      ..onCancel = () {
        disconnect(null);
        final upstream = subscription;
        subscription = null;
        return upstream?.cancel();
      };
    return controller.stream;
  }
}
