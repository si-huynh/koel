import 'package:koel_core/koel_core.dart';
import 'package:koel_http/koel_http.dart';

import 'agno_auth_interceptor.dart';
import 'conversion/message_conversion.dart';
import 'error/agno_error_classifier.dart';

/// `HttpAgent` targeting an Agno backend's `POST baseURL/agno-chat` route — one
/// constructor call connects a Flutter/Dart app to Agno (FR-C1, Addendum A.3).
///
/// agno is **native AG-UI** (`SPIKE-AGNO`): it parses koel's camelCase
/// `RunAgentInput` directly and streams canonical AG-UI SSE back. So the response
/// path is pure inherited [HttpAgent] behavior (no event reshaping), and the only
/// request-side work is normalizing koel's [Message] superset down to canonical
/// AG-UI — done by overriding the [HttpAgent.encodeBody] seam for `messages`
/// alone (see [AgnoConversionOptions]).
class AgnoAgent extends HttpAgent {
  /// Connects to the Agno backend rooted at [baseURL]; runs POST to
  /// `baseURL/agno-chat` (the join is trailing-slash-safe).
  ///
  /// [token] wires a default-ON [AgnoAuthInterceptor] (Bearer auth) prepended to
  /// the chain — outermost, so a caller-supplied inner `AuthInterceptor` in
  /// [interceptors] wins the merge. [client] forwards straight
  /// to [HttpAgent]; [conversion] tunes message normalization (defaults to a
  /// const [AgnoConversionOptions]).
  AgnoAgent({
    required Uri baseURL,
    this.token,
    super.client,
    List<Interceptor>? interceptors,
    AgnoConversionOptions? conversion,
  }) : _conversion = conversion ?? const AgnoConversionOptions(),
       super(
         url: _agnoChatEndpoint(baseURL),
         interceptors: [
           AgnoAuthInterceptor(token: token),
           ...?interceptors,
         ],
       );

  /// The bearer token injected by the default-ON [AgnoAuthInterceptor] as an
  /// `Authorization: Bearer …` header on every run. `null` (the default) or a
  /// blank token leaves the interceptor a no-op — the right default for open
  /// agno deployments.
  final String? token;

  final AgnoConversionOptions _conversion;

  /// Joins [baseURL] with the `agno-chat` route segment, trailing-slash-safe:
  /// both `http://host:8002` and `http://host:8002/` resolve to
  /// `http://host:8002/agno-chat`. Raw concat and `Uri.resolve` both mishandle a
  /// trailing slash or an empty base path; rebuilding the path segments does not.
  ///
  /// Fails fast on a [baseURL] that cannot name an HTTP POST target — a non-`http(s)`
  /// scheme, or no authority (relative URI, no host) — with an [ArgumentError] at
  /// construction, rather than building a nonsense endpoint that fails opaquely at
  /// transport. Any query/fragment on [baseURL] is preserved as-is (a fragment is
  /// never transmitted; a query may be a legitimate part of some deployments' base).
  static Uri _agnoChatEndpoint(Uri baseURL) {
    if (!baseURL.isScheme('http') && !baseURL.isScheme('https')) {
      throw ArgumentError.value(
        baseURL,
        'baseURL',
        'must be an absolute http(s) URL (e.g. http://host:8002)',
      );
    }
    if (!baseURL.hasAuthority) {
      throw ArgumentError.value(
        baseURL,
        'baseURL',
        'must have an authority (host)',
      );
    }
    return baseURL.replace(
      pathSegments: [
        ...baseURL.pathSegments.where((segment) => segment.isNotEmpty),
        'agno-chat',
      ],
    );
  }

  @override
  Map<String, dynamic> encodeBody(RunAgentInput input) => <String, dynamic>{
    ...super.encodeBody(input),
    'messages': [
      for (final message in input.messages)
        agnoMessageToWire(message, _conversion),
    ],
  };

  @override
  ErrorClassifier errorClassifier() => const AgnoErrorClassifier();
}
