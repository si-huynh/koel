---
id: connect-http-backend
title: Connect an HTTP backend
---

# Connect an HTTP backend

Any backend that speaks AG-UI over Server-Sent Events works with `HttpAgent` — no
bridge package required. Point it at the SSE endpoint each run POSTs to:

```dart
import 'package:koel/koel.dart' show HttpAgent, KoelClient;

final client = KoelClient(
  agent: HttpAgent(url: Uri.parse('https://your-backend.example/agui')),
);

final session = client.newSession();
await session.send('What is the weather in Hanoi?');
```

`HttpAgent` owns the full transport: it POSTs the canonical `RunAgentInput`,
parses the `text/event-stream` response into typed `AgUiEvent`s, normalizes the
`*_CHUNK` shapes (`synthesizeChunks`, default-on), and surfaces transport
failures as a terminal `RunErrorEvent` carrying a typed `KoelError` — `run` never
throws.

## Tuning the transport

```dart
HttpAgent(
  url: Uri.parse('https://your-backend.example/agui'),
  connectTimeout: const Duration(seconds: 10), // await response headers
  readTimeout: const Duration(minutes: 2),     // max idle between bytes
  onConnect: () => print('connected'),
  onDisconnect: (cause) => print('disconnected: $cause'),
);
```

A timeout maps to a typed `transportTimeout` error rather than a raw exception.

## Add cross-cutting behavior

Retry, auth, logging, and redaction are interceptors, not constructor flags — see
[Retry &amp; auth](./retry-and-auth.md) and [Interceptors](../concepts/interceptors.md).

## Backend-specific bridges

If you run a known backend, its bridge package handles body-shape and
error-classification quirks for you:

- [Agno](./connect-agno.md) — `koel_agno`
- [LangGraph](./connect-langgraph.md) — `koel_langgraph`
- [CopilotKit runtime](./connect-copilotkit-runtime.md) — `koel_runtime`
