import 'package:koel_http/koel_http.dart';

/// Default-ON `x-api-key` auth for LangGraph deployments (FR-C2, Addendum A.4) —
/// composed onto every `LangGraphAgent` run unless the caller overrides it.
///
/// A thin specialization of [AuthInterceptor]: it resolves a fixed `x-api-key`
/// header from the constructor `apiKey` rather than an async callback. When
/// `apiKey` is `null` or blank (empty/whitespace — e.g. an unset env var
/// defaulting to `''`) it is a true no-op (no `x-api-key` header reaches the
/// wire), the right default for the open local deployment. Otherwise every
/// request carries `x-api-key: <apiKey>` — the key value (surrounding
/// whitespace trimmed), *not* a `Bearer`-prefixed token: LangGraph uses the
/// LangGraph-Platform `x-api-key`
/// convention, not agno's `Authorization: Bearer`. All the header-injection
/// plumbing — the reserved `forwardedProps` carrier, body-stripping so the key
/// never hits the wire body, per-retry re-resolution, secret-free error wrapping
/// — is inherited from [AuthInterceptor] unchanged.
///
/// **Why default-ON is safe (SPIKE-LG-AUTH, resolved).** `ag-ui-langgraph==0.0.37`
/// ships **zero built-in auth** on its AG-UI route — a grep of the package source
/// finds no api-key / `Authorization` / 401 / 403 handling (it reads only the
/// `accept` header). The `x-api-key` header is a koel-side convention: the
/// reference backend enforces it via an opt-in `LANGGRAPH_API_KEY` toggle (missing
/// → 401, wrong → 403, empty → open). So a default `x-api-key` is a harmless client
/// convention — `apiKey` is optional, and a deployment that wants enforcement flips
/// its toggle (then 401/403, mapped by Story 5.6's classifier). Stays default-ON
/// per the resolved spike.
class LangGraphAuthInterceptor extends AuthInterceptor {
  /// Creates an `x-api-key` auth interceptor for [apiKey]. A `null` or blank
  /// (empty/whitespace) [apiKey] yields a no-op (no header); any other [apiKey]
  /// injects an `x-api-key: <apiKey.trim()>` header on every run (surrounding
  /// whitespace is trimmed — a padded key is a caller typo, never a valid key,
  /// and an un-trimmed trailing newline would be a header-injection vector).
  LangGraphAuthInterceptor({required String? apiKey})
    : super(
        headers: () async => apiKey == null || apiKey.trim().isEmpty
            ? const <String, String>{}
            : {'x-api-key': apiKey.trim()},
      );
}
