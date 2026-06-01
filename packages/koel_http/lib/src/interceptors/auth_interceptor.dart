import 'dart:async';

import 'package:koel_core/koel_core.dart';

/// Authenticates every run by composing an interceptor instead of configuring
/// the agent (FR-B2). Takes an async header-builder — a closure that can mint a
/// Bearer token, read a keychain, or refresh on demand — resolves it per run (or
/// per retry attempt, see below), and threads the resolved headers onto the
/// outgoing POST.
///
/// ```dart
/// HttpAgent(
///   url: endpoint,
///   interceptors: [
///     AuthInterceptor(headers: () async => {'Authorization': 'Bearer $token'}),
///   ],
/// );
/// ```
///
/// **The header-injection seam.** An [Interceptor] can only transform
/// `RunAgentInput → Stream<AgUiEvent>`; it has no direct path to the HTTP
/// request — the POST headers are built deep inside `HttpAgent`'s transport. The
/// carrier from interceptor to transport is therefore the [RunAgentInput]
/// itself: the resolved headers ride on `input.forwardedProps` under the
/// koel-reserved [transportHeadersKey]. `HttpAgent`'s transport extracts that
/// key, **strips it from the body before encoding** (so the token never reaches
/// the wire), and merges the headers into the request with the protocol headers
/// (`Content-Type`/`Accept`) winning. Stacked `AuthInterceptor`s compose — the
/// inner one's reserved map is read and merged, later keys winning.
///
/// **Once per run, or once per retry attempt — by ordering, not config.** The
/// surface is exactly one named param; "per-run vs per-attempt" is the
/// composition knob, not a flag. Plain `interceptors: [AuthInterceptor(...)]`
/// resolves once per run. With `HttpAgent(retry: ...)`, the auto-built
/// `RetryInterceptor` sits outermost and re-`proceed`s through this interceptor
/// on every reconnect, so the callback re-fires per attempt — the token-refresh
/// hook.
///
/// **A throwing callback becomes a terminal `RunErrorEvent`.** Any throw from
/// the callback is wrapped as a typed
/// `BusinessError(code: KoelErrorCode.businessAuth, cause: <original>)` and
/// surfaced through the stream; the [InterceptorChain] classifier passes the
/// already-typed error through unchanged to a single terminal `RunErrorEvent`.
/// The wrapper message is fixed and secret-free — no token is ever echoed into
/// an error (architecture §5). When resolution fails, no transport connection
/// opens (the failure precedes `chain.proceed`).
///
/// **Open for subclassing.** `class … implements Interceptor` (deliberately
/// **not** `final`): Epic-5's `AgnoAuthInterceptor extends AuthInterceptor`.
class AuthInterceptor implements Interceptor {
  /// Creates an interceptor that resolves [headers] per run/attempt and threads
  /// the result onto the outgoing request. [headers] is invoked each time the
  /// chain reaches this interceptor; its returned map is merged into the request
  /// headers under [transportHeadersKey] (protocol headers always win). A throw
  /// from [headers] surfaces as `RunErrorEvent(BusinessError(businessAuth))`.
  AuthInterceptor({required Future<Map<String, String>> Function() headers})
    : _headers = headers;

  final Future<Map<String, String>> Function() _headers;

  /// The koel-namespaced `forwardedProps` key under which resolved auth headers
  /// ride from this interceptor to `HttpAgent`'s transport.
  ///
  /// Transport-internal contract: written by [AuthInterceptor], consumed and
  /// **stripped** by the transport before the request body is encoded, so it is
  /// **never on the wire**. Public so Epic-5 adapters and the transport share one
  /// constant rather than a magic string. The value is a `Map<String, String>`
  /// (never JSON round-tripped — `forwardedProps` preserves runtime types).
  static const String transportHeadersKey = 'koel.transport.headers';

  @override
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input) {
    // Resolve asynchronously, then delegate. `Stream.fromFuture(...).asyncExpand`
    // is single-subscription and cancel-correct: a cancel during resolution
    // cancels the source and `chain.proceed` never runs (no transport opens); a
    // cancel during the delegated stream forwards to `chain.proceed`. A resolve
    // throw routes as a stream error the chain classifies (see [_resolve]).
    return Stream.fromFuture(_resolve()).asyncExpand((resolved) {
      // Merge over any reserved map a prior (inner) AuthInterceptor wrote, later
      // keys winning, so stacked auth interceptors compose.
      final prior = (input.forwardedProps[transportHeadersKey] as Map?)
          ?.cast<String, String>();
      return chain.proceed(
        input.copyWith(
          forwardedProps: {
            ...input.forwardedProps,
            transportHeadersKey: <String, String>{...?prior, ...resolved},
          },
        ),
      );
    });
  }

  /// Invokes the header builder, wrapping any throw as the typed
  /// `businessAuth` failure with a fixed, secret-free message and the original
  /// throw preserved as `cause` (and its stack via [Error.throwWithStackTrace]).
  Future<Map<String, String>> _resolve() async {
    try {
      return await _headers();
    } catch (error, stack) {
      Error.throwWithStackTrace(
        BusinessError(
          message: 'Authentication header resolution failed',
          code: KoelErrorCode.businessAuth,
          cause: error,
        ),
        stack,
      );
    }
  }
}
