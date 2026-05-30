import 'dart:async';

import '../error/error_classifier.dart';
import '../event/ag_ui_event.dart';
import '../input/run_agent_input.dart';
import 'abstract_agent.dart';

/// A single cross-cutting stage wrapped around agent execution — auth, retry,
/// logging, telemetry, anything that observes or rewrites a run without being
/// the run itself (FR-A4). The contract lives here in `koel_core`; the six
/// built-ins (`AuthInterceptor`, `RetryInterceptor`, …) ship in `koel_http`.
///
/// Interceptors compose into an ordered [InterceptorChain]. For a registered
/// list `[A, B, C]` they run **forward** on the way in — `A.intercept` →
/// `B.intercept` → `C.intercept` → `AbstractAgent.run` — and **unwind in
/// reverse** as each delegated stream drains.
///
/// An implementation MUST call [InterceptorChain.proceed] exactly once to
/// continue the chain (optionally transforming `input` first — the auth/retry
/// pattern), or return a substitute stream to short-circuit it. It MAY wrap the
/// returned stream (`chain.proceed(input).map(...)`) to transform the events the
/// run emits.
///
/// Do **not** catch-and-swallow errors: the chain converts every throw — whether
/// raised synchronously from [intercept] or surfaced through the delegated
/// stream — into a terminal `RunErrorEvent` via the configured
/// [ErrorClassifier]. Swallowing one hides a failure the consumer must see.
///
/// ```dart
/// class TimingInterceptor implements Interceptor {
///   @override
///   Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input) {
///     final start = DateTime.now();
///     return chain.proceed(input).map((event) {
///       _record(DateTime.now().difference(start));
///       return event;
///     });
///   }
/// }
/// ```
abstract class Interceptor {
  /// Wraps the execution of [input], delegating to [chain] to reach the next
  /// interceptor (or the terminal agent). Returns the — possibly transformed —
  /// event stream the run produces.
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input);
}

/// Drives an ordered [Interceptor] list around a terminal [AbstractAgent].
///
/// The chain is an immutable cursor: each [proceed] dispatches to the
/// interceptor at the current position, or to `agent.run` once the list is
/// exhausted, handing the invoked interceptor a fresh chain advanced one step.
/// Construction (interceptor list, terminal agent, classifier) happens once at
/// the head; `KoelClient` owns that wiring in Story 2.14 — until then a chain is
/// built directly, which is all this story needs.
///
/// **Error policy (the kernel invariant — architecture §5).** Adapters never let
/// a raw `throw` cross into consumer code. [proceed] upholds that for the whole
/// chain: any error — a synchronous throw while an interceptor builds its
/// stream, or an error surfaced through a delegated stream — is classified into
/// a `KoelError` and emitted as a single terminal `RunErrorEvent`. Nothing
/// escapes as an uncaught exception, and the events emitted before the failure
/// are preserved.
///
/// Cancellation is transparent: cancelling the subscription to a [proceed]
/// stream cancels the delegated stream beneath it. There is no `RunErrorEvent`
/// on cancel — a cancelled run is not a failed one.
class InterceptorChain {
  /// Builds the head of a chain that runs [interceptors] in order around
  /// [agent]. [errorClassifier] maps any thrown failure to the typed
  /// `KoelError` carried by the terminal `RunErrorEvent`; the framework-free
  /// [DefaultErrorClassifier] is the default, and `KoelClient` injects its own
  /// in Story 2.14.
  InterceptorChain({
    required List<Interceptor> interceptors,
    required AbstractAgent agent,
    ErrorClassifier errorClassifier = const DefaultErrorClassifier(),
  }) : this._(interceptors, agent, errorClassifier, 0);

  InterceptorChain._(
    this._interceptors,
    this._agent,
    this._classifier,
    this._index,
  );

  final List<Interceptor> _interceptors;
  final AbstractAgent _agent;
  final ErrorClassifier _classifier;
  final int _index;

  /// Runs the next stage of the chain for [input]: the interceptor at the
  /// current position, or the terminal agent once the list is exhausted.
  ///
  /// Preserves the delegated stream's subscription model — single-subscription
  /// for an [AbstractAgent.run] that honours its single-listener contract
  /// (architecture §4), which the chain neither broadens nor narrows. Any throw
  /// from the delegated stage — raised synchronously while
  /// [Interceptor.intercept] builds its stream, or surfaced as an error through
  /// that stream — is classified and emitted as a trailing `RunErrorEvent`,
  /// after which the stream closes normally.
  Stream<AgUiEvent> proceed(RunAgentInput input) {
    final Stream<AgUiEvent> downstream;
    try {
      downstream = _index < _interceptors.length
          ? _interceptors[_index].intercept(_advance(), input)
          : _agent.run(input);
    } catch (error, stack) {
      // A synchronous throw while building the stream (a non-`async*`
      // interceptor that throws outright).
      return Stream<AgUiEvent>.value(_runError(error, stack, input));
    }
    // A stream-borne error: a transformer converts it to a terminal
    // `RunErrorEvent` value. `yield*`/`await for` are both wrong here — the
    // former routes the error past any `catch`, the latter strands an in-flight
    // `cancel()` on a pending `await`. The transformer is a plain pipe, so
    // cancellation propagates to [downstream] untouched.
    return downstream.transform(
      StreamTransformer<AgUiEvent, AgUiEvent>.fromHandlers(
        handleError: (error, stack, sink) {
          sink
            ..add(_runError(error, stack, input))
            ..close();
        },
      ),
    );
  }

  RunErrorEvent _runError(
    Object error,
    StackTrace stack,
    RunAgentInput input,
  ) => RunErrorEvent(error: _classifier.classify(error, stack, input));

  InterceptorChain _advance() =>
      InterceptorChain._(_interceptors, _agent, _classifier, _index + 1);
}
