import 'package:koel_http/koel_http.dart';

/// Default-ON Bearer auth for a CopilotKit v2 runtime (FR-G4, Addendum A.5) —
/// composed onto every `CopilotRuntimeAgent` run unless the caller overrides it.
///
/// A thin specialization of [AuthInterceptor]: it resolves a fixed Bearer header
/// from the constructor `token` rather than an async callback. When `token` is
/// `null` or blank (empty/whitespace — e.g. an unset env var defaulting to `''`)
/// it is a true no-op (no `Authorization` header reaches the wire), which is the
/// right default for the open v2 runtime. Otherwise every request carries
/// `Authorization: Bearer <token>`. All the header-injection
/// plumbing — the reserved `forwardedProps` carrier, body-stripping so the token
/// never hits the wire body, per-retry re-resolution, secret-free error wrapping
/// — is inherited from [AuthInterceptor] unchanged.
///
/// **Why default-ON is safe.** The CopilotKit v2 reference runtime
/// (`@copilotkit/runtime@1.59.4`, `SPIKE-CK-V2`) is **open by default** — its
/// AG-UI `/agent/{agentName}/run` route enforces no auth. So a default Bearer is
/// a harmless client convention, not a requirement: `token` is optional, and a
/// deployment that wants enforcement fronts the runtime with its own middleware
/// (which returns 401/403 — see `CopilotRuntimeErrorClassifier`).
class CopilotRuntimeAuthInterceptor extends AuthInterceptor {
  /// Creates a Bearer-auth interceptor for [token]. A `null` or blank
  /// (empty/whitespace) [token] yields a no-op (no header); any other [token]
  /// injects an `Authorization: Bearer <token.trim()>` header on every run
  /// (surrounding whitespace is trimmed — a padded token is a caller typo, never
  /// a valid token, and an un-trimmed trailing newline would be a header-injection
  /// vector).
  CopilotRuntimeAuthInterceptor({required String? token})
    : super(
        headers: () async => token == null || token.trim().isEmpty
            ? const <String, String>{}
            : {'Authorization': 'Bearer ${token.trim()}'},
      );
}
