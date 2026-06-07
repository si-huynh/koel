---
id: interceptors
title: Interceptors
---

# Interceptors

An `Interceptor` is a composable hook around a run. The chain wraps the
transport: each interceptor can observe or rewrite the outgoing request, then
observe or transform the incoming event stream, before handing off to the next.
This is how retry, auth, logging, and redaction are added without touching the
transport or the agent.

```dart
import 'package:koel/koel.dart' show HttpAgent, KoelClient;
import 'package:koel_http/koel_http.dart'
    show AuthInterceptor, RetryInterceptor;

final client = KoelClient(
  agent: HttpAgent(url: Uri.parse('https://your-backend.example/agui')),
  interceptors: [
    RetryInterceptor(),                                  // outermost: re-runs the whole call
    AuthInterceptor(headers: () async => {               // innermost: stamps headers
          'Authorization': 'Bearer ${await tokenStore.read()}',
        }),
  ],
);
```

## Ordering: outermost wins

The list is applied in order, so the **first** interceptor is the outermost
wrapper. A `RetryInterceptor` placed first re-runs everything inside it
(including re-stamping auth on each attempt). A caller-supplied `AuthInterceptor`
is prepended outermost of the auth pair so it wins the header merge over a
bridge's default auth. When in doubt: read the order top-to-bottom as
"outside-in".

## The built-in interceptors (koel_http)

| Interceptor | What it does |
| --- | --- |
| `RetryInterceptor` | Re-runs the call on transient transport failure, with backoff (`RetryPolicy`). |
| `AuthInterceptor` | Stamps headers from an async provider (`headers: () async => {...}`) — e.g. a Bearer token fetched per call. |
| `LoggingInterceptor` | Structured request/response logging via `package:logging` (`level:`). |
| `EventTraceInterceptor` | Records each event into a `TraceEntry` `sink:` for devtools/debugging. |
| `PIIRedactionInterceptor` | Redacts text matching configured `patterns:` before it reaches a log. |
| `SentryBreadcrumbInterceptor` | Emits Sentry breadcrumbs for the run lifecycle (`hub:`). |

The transport-layer interceptors live in `koel_http`; the chain framework
(`Interceptor`) is `koel_core`, so a non-HTTP adapter reuses the same contract.

## Four-stage pipeline

Under the interceptor chain, every event flows through koel_core's fixed
four-stage pipeline — **verify → apply → transform → chunk-synthesize**. Only the
chunk-synthesis stage (`chunksStage`, which normalizes the `*_CHUNK` shapes, see
[Events](./events.md)) is public, because a sibling transport reuses that one
source of truth. The verify/apply/transform stages stay internal — you reach
their effect through `KoelClient`/`ChatSession`, never by composing them
directly.

## Writing your own

An interceptor is a plain class implementing `Interceptor`. The
[Adapter Cookbook](../adapter-cookbook.md) walks through a custom auth/error
interceptor against the conformance contract; the recipes
[retry &amp; auth](../recipes/retry-and-auth.md) and
[PII redaction](../recipes/pii-redaction-sentry.md) show the built-ins in use.
