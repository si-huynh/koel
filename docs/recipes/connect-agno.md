---
id: connect-agno
title: Connect Agno
---

# Connect Agno

[`koel_agno`](https://pub.dev/packages/koel_agno) bridges an
[Agno](https://github.com/agno-agi/agno) backend: it shapes the request body for
Agno's AG-UI route and classifies Agno's failures into typed errors.

```dart
import 'package:koel_core/koel_core.dart' show KoelClient;
import 'package:koel_agno/koel_agno.dart' show AgnoAgent;

final client = KoelClient(
  agent: AgnoAgent(baseURL: Uri.parse('https://my-agno.example')),
);

final session = client.newSession();
await session.send('Plan a 3-day trip to Da Nang');
```

## Authentication

Stock Agno enforces **zero auth** on its AG-UI route (CORS only), so an open
deployment ignores any `Authorization` header — `AgnoAgent` is usable with no
token. The `AgnoAuthInterceptor` is default-on as a harmless convention: pass a
`token` only when your deployment adds its own auth middleware (which then
returns `401`/`403`, mapped to `businessAuth`/`businessForbidden` by
`AgnoErrorClassifier`):

```dart
final agent = AgnoAgent(
  baseURL: Uri.parse('https://my-agno.example'),
  token: 'xyz',
);
```

`AgnoAgent extends HttpAgent`, so it inherits the full transport stack
(SSE parse, timeouts, cancellation, retry). It overrides only `encodeBody` (the
Agno `messages` shape) and `errorClassifier`. To write your own bridge the same
way, see the [Adapter Cookbook](../adapter-cookbook.md).
