import 'dart:async';
import 'dart:math';

import 'package:koel_core/koel_core.dart';
import 'package:meta/meta.dart';

/// Re-runs a failed run with exponential backoff + jitter, emitting a
/// [`ConnectionResumed`](RetryInterceptor.connectionResumedEventName) marker on a
/// recovered reconnect and a terminal `TransportError(transportClosed)` on
/// exhaustion (FR-B4 / NFR-7).
///
/// **How retry actually works here.** `InterceptorChain.proceed` never lets a
/// failure escape as a `throw`: it converts every downstream error into a
/// trailing `RunErrorEvent` *value* and closes the stream normally
/// (`koel_core` `interceptor.dart`). So this interceptor does **not** `try/catch`
/// a delegated run — it **watches the delegated stream for a terminal
/// `RunErrorEvent`** and, when one is retryable, re-calls `chain.proceed(input)`.
/// Each such call re-invokes the rest of the chain and the transport terminal —
/// a brand-new POST / reconnect. A partial first attempt may already have
/// delivered `RunStartedEvent` + content before failing; the re-run delivers a
/// fresh `RunStartedEvent…`. That duplication is **by design** — subscribers see
/// every attempt (architecture §Cross-Cutting #3); base AG-UI/SSE has no resume
/// token, so there is no mid-stream resume to attempt.
///
/// **`maxAttempts` counts reconnects, not total connections.** The initial
/// connection is attempt 0; the first retry is attempt 1. With `maxAttempts: n`,
/// the `(n+1)`-th failure exhausts the budget and surfaces the terminal error.
///
/// **`ConnectionResumed` is a `CustomEvent`, not a new event type.** The
/// `AgUiEvent` union is `sealed`; adding a subtype is a protocol-surface change.
/// A recovered reconnect prepends `CustomEvent(name:
/// [connectionResumedEventName], value: {'attempt': n})` before the first domain
/// event it produces — lazily, so a reconnect that fails before yielding data
/// emits none.
///
/// **Default retry predicate.** Without a `shouldRetry`, only `TransportError`
/// (all four transport codes are transient) is retried; `BusinessError`,
/// `ProtocolError`, and `AgentError` surface immediately, unchanged. A supplied
/// `shouldRetry(error, attempt)` receives the typed `KoelError` and the 1-based
/// retry index; returning `false` short-circuits with no backoff.
final class RetryInterceptor implements Interceptor {
  /// Creates a retry interceptor (the canonical public surface, Addendum A.2).
  ///
  /// [maxAttempts] is the maximum number of **reconnects** after the initial
  /// connection; [baseDelay] is the first backoff step, doubled each retry and
  /// clamped to [maxDelay]; [jitter] is the symmetric randomization *fraction*
  /// (e.g. `0.2` ⇒ ±20%). [shouldRetry] gates which failures retry; when null,
  /// only `TransportError` is retried.
  RetryInterceptor({
    this.maxAttempts = 5,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.jitter = 0.2,
    bool Function(Object error, int attempt)? shouldRetry,
  }) : assert(maxAttempts >= 0, 'maxAttempts must be non-negative'),
       assert(!baseDelay.isNegative, 'baseDelay must be non-negative'),
       assert(jitter >= 0, 'jitter must be a non-negative fraction'),
       _shouldRetry = shouldRetry ?? _retryTransient,
       _onReconnectAttempt = null,
       _random = Random();

  /// The `HttpAgent`-only bridge constructor: identical to the public ctor plus
  /// an [onReconnectAttempt] observer fired once per scheduled retry with the
  /// 1-based attempt index and the actual jittered delay.
  ///
  /// `@internal` because the observer belongs to `HttpAgent(onReconnectAttempt:)`
  /// — the public surface (A.2) carries no callback. Not barrel-exported;
  /// consumers reach the engine through the public ctor or `HttpAgent(retry:)`.
  @internal
  RetryInterceptor.forAgent({
    this.maxAttempts = 5,
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(seconds: 30),
    this.jitter = 0.2,
    bool Function(Object error, int attempt)? shouldRetry,
    void Function(int attempt, Duration delay)? onReconnectAttempt,
  }) : assert(maxAttempts >= 0, 'maxAttempts must be non-negative'),
       assert(!baseDelay.isNegative, 'baseDelay must be non-negative'),
       assert(jitter >= 0, 'jitter must be a non-negative fraction'),
       _shouldRetry = shouldRetry ?? _retryTransient,
       _onReconnectAttempt = onReconnectAttempt,
       _random = Random();

  /// The `CustomEvent.name` of the reconnect marker prepended to the first event
  /// of a recovered reconnect. koel does not interpret it; a consumer matches it
  /// to render a "reconnected" affordance.
  static const String connectionResumedEventName = 'koel.connection_resumed';

  /// Maximum reconnects after the initial connection; the `(maxAttempts+1)`-th
  /// failure exhausts the budget.
  final int maxAttempts;

  /// First backoff step, doubled each retry and clamped to [maxDelay].
  final Duration baseDelay;

  /// Upper bound the doubled *base* step is clamped to before jitter is applied.
  /// Because jitter scales the clamped base, the final delay may exceed this by
  /// the jitter fraction (e.g. up to `maxDelay·1.2` at `jitter: 0.2`).
  final Duration maxDelay;

  /// Symmetric jitter fraction applied to each delay (`0.2` ⇒ ±20%).
  final double jitter;

  final bool Function(Object error, int attempt) _shouldRetry;
  final void Function(int attempt, Duration delay)? _onReconnectAttempt;
  final Random _random;

  @override
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input) {
    // A single downstream controller fronts many sequential inner subscriptions
    // (one per attempt). `async*`/`await for` is the wrong tool: it strands a
    // pending `cancel()` on the backoff `await` and cannot inject
    // `ConnectionResumed` cleanly — the same lesson 4.3 hit with `SseParser`.
    final controller = StreamController<AgUiEvent>(sync: true);
    StreamSubscription<AgUiEvent>? sub;
    Timer? backoff;
    var attempt = 0; // 0 = initial connection; N ≥ 1 = the Nth reconnect.
    var cancelled = false;

    void subscribe() {
      var firstEventSeen = false;
      sub = chain
          .proceed(input)
          .listen(
            (event) {
              if (event is RunErrorEvent) {
                // Failure arrives as a terminal value, not a throw. Cancel the inner
                // stream first so its trailing `onDone` cannot close [controller]
                // out from under a scheduled retry.
                final held = event;
                final live = sub;
                sub = null;
                live?.cancel();

                final nextAttempt = attempt + 1; // 1-based index of the retry.
                final bool retryable;
                try {
                  retryable = _shouldRetry(held.error, nextAttempt);
                } catch (error, stack) {
                  // A throwing predicate cannot decide. Surface it as a terminal
                  // error (the chain transformer maps the stream error to a
                  // `RunErrorEvent`) rather than strand the run: an uncaught throw
                  // here would escape to the zone and leave [controller] open
                  // forever, hanging the consumer.
                  controller
                    ..addError(error, stack)
                    ..close();
                  return;
                }
                if (!retryable) {
                  // Non-retryable: forward the original failure unchanged.
                  controller
                    ..add(held)
                    ..close();
                } else if (attempt < maxAttempts) {
                  // Retryable with budget remaining: back off, then reconnect.
                  final delay = retryBackoff(
                    nextAttempt,
                    baseDelay: baseDelay,
                    maxDelay: maxDelay,
                    jitter: jitter,
                    random: _random,
                  );
                  // Fire-and-forget telemetry: a throwing observer must not abort
                  // a recoverable run (or hang it via an uncaught zone error).
                  try {
                    _onReconnectAttempt?.call(nextAttempt, delay);
                  } catch (_) {
                    // Deliberately swallowed: the reconnect proceeds regardless.
                  }
                  backoff = Timer(delay, () {
                    backoff = null;
                    if (cancelled) return;
                    attempt = nextAttempt;
                    subscribe();
                  });
                } else {
                  // Retryable but the reconnect budget is spent: a terminal
                  // transportClosed carrying the last failure as its cause.
                  controller
                    ..add(
                      RunErrorEvent(
                        error: TransportError(
                          message:
                              'Reconnect attempts exhausted after $maxAttempts '
                              'retries',
                          code: KoelErrorCode.transportClosed,
                          cause: held.error,
                        ),
                      ),
                    )
                    ..close();
                }
                return;
              }
              // A real domain event. The first one of a reconnect attempt proves the
              // reconnect produced data — prepend the resume marker (lazy: an attempt
              // that fails before yielding data emits none).
              if (attempt >= 1 && !firstEventSeen) {
                controller.add(
                  CustomEvent(
                    name: connectionResumedEventName,
                    value: {'attempt': attempt},
                  ),
                );
              }
              firstEventSeen = true;
              controller.add(event);
            },
            // The chain converts errors to terminal values, so this should not fire;
            // forward rather than swallow if the contract is ever broken upstream.
            onError: controller.addError,
            onDone: () {
              // Clean completion (success path): nothing held to act on.
              sub = null;
              controller.close();
            },
          );
    }

    controller
      ..onListen = subscribe
      ..onPause = () {
        sub?.pause();
      }
      ..onResume = () {
        sub?.resume();
      }
      ..onCancel = () {
        // A cancel mid-backoff must abort the wait and never reconnect; a cancel
        // mid-attempt tears the live connection down. Nothing is awaited on the
        // return path (4.3 invariant) beyond the inner cancel, which itself
        // never blocks (it bottoms out in `abortOnCancel`).
        cancelled = true;
        backoff?.cancel();
        backoff = null;
        final live = sub;
        sub = null;
        return live?.cancel();
      };

    return controller.stream;
  }
}

/// The default `RetryInterceptor.shouldRetry`: only `TransportError` is
/// transient. `businessAuth` (a `BusinessError`) — and every `ProtocolError` /
/// `AgentError` — is a terminal condition that re-POSTing cannot fix, so it
/// surfaces immediately.
bool _retryTransient(Object error, int attempt) => error is TransportError;

/// The pure, deterministic backoff schedule: `min(maxDelay, baseDelay·2^(n-1))`
/// scaled by a symmetric jitter factor in `[1−jitter, 1+jitter)`. [attempt] is
/// 1-based; [random] is injected so a seeded `Random` makes tests deterministic.
///
/// Integer-microsecond math (no float `pow`) avoids `Duration` drift; the
/// doubling clamps at [maxDelay] before it can overflow a 64-bit int.
@visibleForTesting
Duration retryBackoff(
  int attempt, {
  required Duration baseDelay,
  required Duration maxDelay,
  required double jitter,
  required Random random,
}) {
  final maxMicros = maxDelay.inMicroseconds;
  var base = baseDelay.inMicroseconds;
  for (var step = 1; step < attempt && base < maxMicros; step++) {
    base <<= 1;
  }
  if (base > maxMicros) base = maxMicros;
  // nextDouble() ∈ [0,1) ⇒ factor ∈ [1−jitter, 1+jitter).
  final factor = 1 + (random.nextDouble() * 2 - 1) * jitter;
  final micros = (base * factor).round();
  return Duration(microseconds: micros < 0 ? 0 : micros);
}
