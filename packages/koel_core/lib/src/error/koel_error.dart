import 'package:freezed_annotation/freezed_annotation.dart';

import 'koel_error_code.dart';

part 'koel_error.freezed.dart';

/// Root of the sealed koel error union — the single typed failure model the SDK
/// classifies every raw failure into (F-A5).
///
/// Adapters **never throw** a [KoelError]; they emit it inside a `RunErrorEvent`
/// on the agent stream (Story 2.5). The `implements Exception` marker exists
/// only for the synchronous programmer-error paths the SDK does throw on — e.g.
/// an invalid `Uri` handed to `KoelClient(...)` — never for in-band run
/// failures (architecture §5).
///
/// `sealed` restricts subtyping to this library, so the union is closed at
/// compile time: `{ TransportError, ProtocolError, AgentError, BusinessError }`.
/// A `switch` over a [KoelError] is therefore exhaustive, and `koel_lints`'
/// `exhaustive_switch_must_have_default` forces consumers to keep a `default:`
/// arm — the seam that keeps their switches non-crashing when a minor version
/// adds a subtype (forward-compat policy FC-2 / FR-A12). That `sealed` contract
/// is also why all four subtypes live in this same file: a sealed type can only
/// be extended within the library that declares it.
///
/// Each subtype is freezed-generated for structural `==`/`hashCode`/`copyWith`;
/// [code] carries the typed [KoelErrorCode] vocabulary orthogonally to the
/// subtype. Construct via a subtype's `const` factory; mutate via `copyWith`.
sealed class KoelError implements Exception {
  const KoelError();

  /// Human-readable, classification-focused summary — sentence-cased, no
  /// trailing period (it is data, not a log line). Never embeds unescaped
  /// user-controlled input (architecture §5).
  String get message;

  /// The typed code locating this failure within [KoelErrorCode]'s vocabulary.
  KoelErrorCode get code;

  /// The originating raw failure (the caught exception, a status payload, …),
  /// preserved verbatim for diagnostics. Often non-serializable, which is why
  /// [KoelError] carries no JSON codec in this story.
  Object? get cause;
}

/// A failure at the network/transport boundary — connection refused, timed
/// out, TLS handshake failed, or the stream closed mid-flight.
///
/// [statusCode] is the HTTP status when one is available (a status-code-aware
/// classifier in `koel_http` populates it); `null` for pre-response failures
/// like a refused socket.
@freezed
abstract class TransportError extends KoelError with _$TransportError {
  const TransportError._() : super();

  const factory TransportError({
    required String message,
    required KoelErrorCode code,
    Object? cause,
    int? statusCode,
  }) = _TransportError;
}

/// A failure in the AG-UI protocol itself — a malformed payload, an
/// unrecognized event, or a version drift the SDK cannot reconcile.
///
/// [eventType] names the wire event involved when the failure is tied to a
/// specific frame (e.g. the `type` that failed to parse); `null` otherwise.
@freezed
abstract class ProtocolError extends KoelError with _$ProtocolError {
  const ProtocolError._() : super();

  const factory ProtocolError({
    required String message,
    required KoelErrorCode code,
    Object? cause,
    String? eventType,
  }) = _ProtocolError;
}

/// A failure originating inside the agent's execution — it refused the request,
/// a tool call failed, or it errored internally. Also the least-wrong home for
/// an unclassifiable failure ([KoelErrorCode.unknown]), since an opaque error is
/// — from the SDK's vantage — a failure at the agent-execution boundary.
///
/// [agentCode] is the backend-specific error code when the agent supplies one;
/// `null` otherwise.
@freezed
abstract class AgentError extends KoelError with _$AgentError {
  const AgentError._() : super();

  const factory AgentError({
    required String message,
    required KoelErrorCode code,
    Object? cause,
    String? agentCode,
  }) = _AgentError;
}

/// A failure carrying business/policy semantics — quota exceeded, rate limited,
/// authentication required, or access forbidden.
///
/// [details] holds structured, backend-supplied context (e.g. `retryAfter`,
/// quota limits); defaults to an empty map and is compared deeply.
@freezed
abstract class BusinessError extends KoelError with _$BusinessError {
  const BusinessError._() : super();

  const factory BusinessError({
    required String message,
    required KoelErrorCode code,
    Object? cause,
    @Default(<String, dynamic>{}) Map<String, dynamic> details,
  }) = _BusinessError;
}
