/// Declarative retry/backoff configuration for an [HttpAgent] reconnection.
///
/// In Story 4.2 this is a **pure immutable data holder** — it exists so the
/// `HttpAgent({RetryPolicy? retry, …})` constructor parameter (a public,
/// one-way-door type) compiles and is exported from the barrel. The
/// backoff/jitter/reconnect **engine** that consumes these fields — and the
/// `onReconnectAttempt`/`ConnectionResumed` wiring — lands in **Story 4.4**
/// (Retry interceptor); the field set here mirrors what that story needs.
final class RetryPolicy {
  /// Constructs a retry policy. Defaults describe a conservative
  /// exponential-backoff schedule that Story 4.4 will implement against.
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
