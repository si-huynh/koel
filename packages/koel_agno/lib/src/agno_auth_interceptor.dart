import 'package:koel_http/koel_http.dart';

/// Default-ON Bearer auth for agno backends (FR-C1, Addendum A.3) — composed
/// onto every [AgnoAgent] run unless the caller overrides it.
///
/// A thin specialization of [AuthInterceptor]: it resolves a fixed Bearer header
/// from the constructor [token] rather than an async callback. When [token] is
/// `null` or blank (empty/whitespace — e.g. an unset env var defaulting to `''`)
/// it is a true no-op (no `Authorization` header reaches the wire), which is the
/// right default for open dev deployments. Otherwise every request carries
/// `Authorization: Bearer <token>`. All the header-injection
/// plumbing — the reserved `forwardedProps` carrier, body-stripping so the token
/// never hits the wire body, per-retry re-resolution, secret-free error wrapping
/// — is inherited from [AuthInterceptor] unchanged.
///
/// **Why default-ON is safe (OQ-Agno-Auth, resolved).** The agno reference
/// backend (`agno 2.6.10`) enforces **zero auth** on its AG-UI route — it ignores
/// the `Authorization` header entirely. So a default Bearer is a harmless client
/// convention, not a requirement: [token] is optional, and a deployment that
/// wants enforcement adds its own opt-in middleware (which returns 401/403 — see
/// `AgnoErrorClassifier`). Stays default-ON per the resolved spike.
class AgnoAuthInterceptor extends AuthInterceptor {
  /// Creates a Bearer-auth interceptor for [token]. A `null` or blank
  /// (empty/whitespace) [token] yields a no-op (no header); any other [token]
  /// injects an `Authorization: Bearer …` header carrying it on every run.
  AgnoAuthInterceptor({required String? token})
    : super(
        headers: () async => token == null || token.trim().isEmpty
            ? const <String, String>{}
            : {'Authorization': 'Bearer $token'},
      );
}
