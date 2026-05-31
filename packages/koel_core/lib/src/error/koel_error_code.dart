/// The typed failure vocabulary classified onto every `KoelError`.
///
/// Each value names a specific, recognizable failure mode, grouped by the
/// `KoelError` subtype family it most often pairs with: transport, protocol,
/// agent, business, and a [unknown] catch-all. A `DefaultErrorClassifier` maps
/// raw Dart exception shapes onto these codes (Addendum A.1, F-A5).
///
/// Unlike a `switch` over the sealed `KoelError` class — which `koel_lints`
/// mandates carry a `default:` arm — a `switch` over this enum is **not**
/// lint-enforced. Adapter packages extend the effective code space by
/// convention (a backend may surface codes this enum does not yet name), so
/// forcing exhaustiveness here would be wrong.
enum KoelErrorCode {
  // transport
  /// The request exceeded its deadline before a response arrived.
  transportTimeout,

  /// The transport stream closed mid-flight.
  transportClosed,

  /// The connection was refused at the socket level.
  transportRefused,

  /// The TLS handshake failed.
  transportTlsFail,

  // protocol
  /// An AG-UI wire event the SDK does not recognize.
  protocolUnknownEvent,

  /// A malformed AG-UI payload that failed to parse.
  protocolMalformed,

  /// A protocol version drift the SDK cannot reconcile.
  protocolVersionDrift,

  // agent
  /// The agent refused to handle the request.
  agentRefused,

  /// A tool invocation inside the agent run failed.
  agentToolFailed,

  /// The agent errored internally.
  agentInternal,

  // business
  /// A usage quota was exceeded.
  businessQuotaExceeded,

  /// The caller was rate limited.
  businessRateLimited,

  /// Authentication is required or invalid.
  businessAuth,

  /// Access to the resource is forbidden.
  businessForbidden,

  // catch-all
  /// An unclassifiable failure that fits no other code.
  unknown,
}
