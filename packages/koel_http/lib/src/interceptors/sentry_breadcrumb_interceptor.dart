import 'dart:async';

import 'package:koel_core/koel_core.dart';
import 'package:sentry/sentry.dart';

/// Adds one Sentry breadcrumb per `AgUiEvent` flowing through a run, so a
/// consumer's later-captured Sentry errors carry the AG-UI run trail that led to
/// them (Story 4.7 / FR-I2). **Default-OFF** — it is never in `HttpAgent`'s
/// default chain and emits nothing unless a consumer (a) adds it to
/// `HttpAgent(interceptors: …)` **and** (b) has called `Sentry.init` in their
/// app. Even then, breadcrumbs only leave the device when an actual Sentry event
/// is captured: this interceptor generates no standalone network traffic, so "no
/// silent telemetry" holds.
///
/// ```dart
/// await Sentry.init((o) => o.dsn = '<your dsn>');     // consumer's app owns this
/// HttpAgent(
///   url: endpoint,
///   interceptors: [SentryBreadcrumbInterceptor()],
/// );
/// ```
///
/// **No PII in breadcrumbs — ever.** A breadcrumb carries the event *type* (and,
/// for a terminal error, the [KoelErrorCode]) — never message text, tool
/// arguments, tool results, reasoning, or `input.forwardedProps` (which may hold
/// the Story-4.5 reserved auth-headers key). Shipping a `delta` to Sentry would
/// leak exactly the content `PIIRedactionInterceptor` exists to scrub, so the
/// breadcrumb payload is deliberately content-free.
///
/// **A side channel that never breaks the run.** Breadcrumb delivery is fire-
/// and-forget and best-effort: a disabled hub (no `Sentry.init`) is a silent
/// no-op, and any failure adding the breadcrumb is swallowed — the event stream
/// is the source of truth, telemetry is not. The stream is forwarded untouched.
///
/// `final` — there is no Epic-5 subclass (unlike `AuthInterceptor`).
final class SentryBreadcrumbInterceptor implements Interceptor {
  /// Creates an interceptor that records a breadcrumb per event to [hub],
  /// defaulting to the ambient Sentry hub ([HubAdapter] forwards to whatever the
  /// consumer's `Sentry.init` configured). The [hub] seam exists for testing —
  /// inject a recorder — and is not a feature flag.
  SentryBreadcrumbInterceptor({Hub? hub}) : _hub = hub ?? HubAdapter();

  final Hub _hub;

  static const String _category = 'koel.event';

  @override
  Stream<AgUiEvent> intercept(InterceptorChain chain, RunAgentInput input) {
    // A per-event side effect over a pure pass-through: `.map` returns each
    // event unchanged after dropping a breadcrumb. A terminal `RunErrorEvent` is
    // just another event the `.map` sees. No `StreamController` wrapper — there
    // is no lifecycle or cancellation to observe, and `.map` forwards cancel
    // transparently.
    return chain.proceed(input).map((event) {
      _breadcrumb(event);
      return event;
    });
  }

  /// Records a content-free breadcrumb for [event]. Fire-and-forget: the async
  /// `addBreadcrumb` is not awaited (it must not stall the stream) and any error
  /// — including an async rejection — is swallowed so telemetry stays
  /// transparent to the run.
  void _breadcrumb(AgUiEvent event) {
    final crumb = Breadcrumb(
      category: _category,
      message: event.runtimeType.toString(),
      level: event is RunErrorEvent ? SentryLevel.error : SentryLevel.info,
      data: event is RunErrorEvent ? {'code': event.error.code.name} : null,
    );
    try {
      unawaited(_hub.addBreadcrumb(crumb).catchError((Object _) {}));
    } on Object {
      // Swallowed by design — a faulty hub must never disrupt the run.
    }
  }
}
