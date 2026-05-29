/// The typed failure vocabulary classified onto every [KoelError].
///
/// Each value names a specific, recognizable failure mode, grouped by the
/// [KoelError] subtype family it most often pairs with: transport, protocol,
/// agent, business, and a [unknown] catch-all. A [DefaultErrorClassifier] maps
/// raw Dart exception shapes onto these codes (Addendum A.1, F-A5).
///
/// Unlike a `switch` over the sealed [KoelError] class — which `koel_lints`
/// mandates carry a `default:` arm — a `switch` over this enum is **not**
/// lint-enforced. Adapter packages extend the effective code space by
/// convention (a backend may surface codes this enum does not yet name), so
/// forcing exhaustiveness here would be wrong.
enum KoelErrorCode {
  // transport
  transportTimeout,
  transportClosed,
  transportRefused,
  transportTlsFail,

  // protocol
  protocolUnknownEvent,
  protocolMalformed,
  protocolVersionDrift,

  // agent
  agentRefused,
  agentToolFailed,
  agentInternal,

  // business
  businessQuotaExceeded,
  businessRateLimited,
  businessAuth,
  businessForbidden,

  // catch-all
  unknown,
}
