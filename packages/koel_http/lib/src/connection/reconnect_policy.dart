/// Declarative retry/backoff configuration for an `HttpAgent` reconnection — the
/// convenience entry point to the `RetryInterceptor` engine (Story 4.4).
///
/// A pure immutable data holder: `HttpAgent(retry: RetryPolicy(…))` maps it to a
/// `RetryInterceptor` and prepends that interceptor to the run, bridging
/// `HttpAgent(onReconnectAttempt:)` into the engine. The bool [jitter] maps to
/// the engine's symmetric *fraction* — `true` ⇒ ±20% (`0.2`), `false` ⇒ none
/// (`0.0`).
///
/// **Two entry points, two default sets — by design.** This holder keeps its
/// own shipped 4.2 defaults (3 / 500ms / 30s / jitter-on); the standalone
/// `RetryInterceptor()` carries the canonical Addendum A.2 defaults
/// (5 / 1s / 30s / `0.2`) and also exposes `shouldRetry`, which this convenience
/// shape does not. Reach for the explicit `RetryInterceptor` in
/// `HttpAgent(interceptors:)` when you need per-error retry control.
final class RetryPolicy {
  /// Constructs a retry policy. Defaults describe a conservative
  /// exponential-backoff schedule the `RetryInterceptor` engine implements.
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.jitter = true,
  });

  /// Maximum reconnection attempts before the run surfaces a terminal error.
  final int maxAttempts;

  /// Base delay for the first backoff step; later steps grow from it.
  final Duration baseDelay;

  /// Upper bound a backoff delay is clamped to.
  final Duration maxDelay;

  /// Whether to apply randomized jitter to each backoff delay.
  final bool jitter;
}
