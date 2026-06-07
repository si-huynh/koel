---
id: connect-copilotkit-runtime
title: Connect CopilotKit runtime
---

# Connect CopilotKit runtime

[`koel_runtime`](https://pub.dev/packages/koel_runtime) bridges the
[CopilotKit](https://www.copilotkit.ai) runtime (v2, native AG-UI over SSE). It
POSTs the complete `RunAgentInput` to the runtime's run route and parses the
`text/event-stream` response — the same wire Agno and LangGraph speak.

```dart
import 'package:koel_core/koel_core.dart' show KoelClient;
import 'package:koel_runtime/koel_runtime.dart' show CopilotRuntimeAgent;

final client = KoelClient(
  agent: CopilotRuntimeAgent(
    // The runtime BASE path; the run route /agent/{agentName}/run is appended.
    endpoint: Uri.parse('https://your-app.example/api/copilotkit'),
    // REQUIRED: the registered runtime agent this run dispatches to.
    agentName: 'your_agent',
    // OPTIONAL: a Bearer token (the v2 runtime is open by default — null no-ops).
    authToken: null,
  ),
);

final session = client.newSession();
await session.send('Summarize my open issues');
```

## `agentName` is required

There is no safe default: the run route is `/agent/{agentName}/run`, naming
*your* registered agent — knowable only at construction — so a hard-coded default
would silently mis-target every real deployment.

## Version pin

CopilotKit **v2 (`>= 1.52`)** is native AG-UI over SSE (reference-verified at
`@copilotkit/runtime@1.59.4`). The legacy multipart/`@defer` GraphQL transport of
`<= 1.8.14` reached EOL and is **removed** — koel_runtime no longer bridges it.
v2 is a transparent AG-UI passthrough, so it surfaces the full event matrix
(including `STATE_DELTA` and on-wire `RUN_ERROR`), the same 25/28 contract every
native adapter shares. See [Events](../concepts/events.md).

`CopilotRuntimeAgent extends HttpAgent` and overrides only `encodeBody` and
`errorClassifier` — the pattern in the [Adapter Cookbook](../adapter-cookbook.md).
