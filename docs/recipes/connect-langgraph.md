---
id: connect-langgraph
title: Connect LangGraph
---

# Connect LangGraph

[`koel_langgraph`](https://pub.dev/packages/koel_langgraph) bridges a
[LangGraph](https://github.com/langchain-ai/langgraph) backend, including
first-class interrupt/resume surfacing.

```dart
import 'package:koel_core/koel_core.dart' show KoelClient;
import 'package:koel_langgraph/koel_langgraph.dart' show LangGraphAgent;

final client = KoelClient(
  agent: LangGraphAgent(
    deploymentUrl: Uri.parse('http://localhost:8003/agent'),
  ),
);

final session = client.newSession();
await session.send('Draft a release note');
```

## The deployment URL is used verbatim

`deploymentUrl` is the **full** AG-UI POST endpoint — nothing is appended. Unlike
a base URL, LangGraph's route path is caller-configured
(`add_langgraph_fastapi_endpoint(..., path: ...)`), so koel assumes no canonical
suffix. Pass the exact endpoint your deployment exposes.

## Authentication

LangGraph ships no built-in auth on its AG-UI route, so `apiKey` is optional —
with `apiKey == null` (the default) or a blank value the interceptor is a no-op,
the right default for an open local deployment. Pass an `apiKey` only when your
deployment enforces one (returning `401`/`403`/`429`, mapped to
`businessAuth`/`businessForbidden`/`businessRateLimited`):

```dart
final agent = LangGraphAgent(
  deploymentUrl: Uri.parse('https://my-langgraph.example/agent'),
  apiKey: 'xyz',
);
```

The key is trimmed and injected as the `x-api-key` header, prepended outermost so
a caller-supplied inner auth wins the merge.

## Interrupt / resume

When a LangGraph run pauses on an `interrupt`, koel surfaces it as a `CUSTOM`
event and you reopen the run on the same thread — see
[Interrupt &amp; resume](./interrupt-resume.md).
