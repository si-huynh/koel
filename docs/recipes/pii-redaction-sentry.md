---
id: pii-redaction-sentry
title: PII redaction & Sentry
---

# PII redaction & Sentry

When conversations carry personal data, redact it before it reaches a log or a
crash report. `PIIRedactionInterceptor` strips text matching configured patterns;
`SentryBreadcrumbInterceptor` emits run-lifecycle breadcrumbs to Sentry.

```dart
import 'package:koel/koel.dart' show HttpAgent, KoelClient;
import 'package:koel_http/koel_http.dart'
    show LoggingInterceptor, PIIRedactionInterceptor, SentryBreadcrumbInterceptor;
import 'package:logging/logging.dart' show Level;

final client = KoelClient(
  agent: HttpAgent(url: Uri.parse('https://your-backend.example/agui')),
  interceptors: [
    // Redact FIRST, so neither the logger nor Sentry below ever sees raw PII.
    PIIRedactionInterceptor(patterns: [
      RegExp(r'[\w.+-]+@[\w-]+\.[\w.-]+'),       // emails
      RegExp(r'\b\d{3}-\d{2}-\d{4}\b'),          // US SSNs
    ]),
    LoggingInterceptor(level: Level.INFO),
    SentryBreadcrumbInterceptor(),               // uses the ambient Sentry Hub
  ],
);
```

## Order is the whole point

The chain is applied outside-in, so place `PIIRedactionInterceptor` **before**
any interceptor that records or transmits — the logger and the Sentry breadcrumb
interceptor then only ever see redacted text. A redactor placed after a logger
redacts nothing useful.

## Sentry

`SentryBreadcrumbInterceptor` emits breadcrumbs for the run lifecycle to the
ambient Sentry `Hub` (initialize Sentry in your app as usual). Pass an explicit
`hub:` to target a non-default hub in tests.

See [Interceptors](../concepts/interceptors.md) for the full chain model.
