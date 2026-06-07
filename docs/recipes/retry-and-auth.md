---
id: retry-and-auth
title: Retry & auth
---

# Retry & auth

Retry and auth are interceptors, layered around the transport. Order matters: the
first in the list is the outermost wrapper, so put `RetryInterceptor` first to
re-run the whole call (re-stamping auth on each attempt).

```dart
import 'package:koel/koel.dart' show HttpAgent, KoelClient;
import 'package:koel_http/koel_http.dart'
    show AuthInterceptor, RetryInterceptor;

final client = KoelClient(
  agent: HttpAgent(url: Uri.parse('https://your-backend.example/agui')),
  interceptors: [
    RetryInterceptor(),                                   // outermost
    AuthInterceptor(headers: () async => {
          'Authorization': 'Bearer ${await tokenStore.read()}',
        }),
  ],
);
```

## Retry policy

`RetryInterceptor` backs off exponentially with jitter and only retries
*transient* transport failures — a parsed in-band `RUN_ERROR` is the agent's
answer, not a transport fault, so it is never retried.

```dart
RetryInterceptor(
  maxAttempts: 5,
  baseDelay: const Duration(seconds: 1),
  maxDelay: const Duration(seconds: 30),
  jitter: 0.2,
);
```

## Auth from an async provider

`AuthInterceptor` takes a `headers` provider called per attempt, so a token
refreshed between retries is picked up automatically. Return whatever header map
your backend expects:

```dart
AuthInterceptor(headers: () async => {'x-api-key': await keyStore.read()});
```

For a known backend, the bridge package already wires its convention —
[`AgnoAgent(token:)`](./connect-agno.md),
[`LangGraphAgent(apiKey:)`](./connect-langgraph.md) — so you rarely add
`AuthInterceptor` by hand there.
