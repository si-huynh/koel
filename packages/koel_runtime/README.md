# koel_runtime

[![pub package](https://img.shields.io/pub/v/koel_runtime.svg)](https://pub.dev/packages/koel_runtime)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/si-huynh/koel/actions/workflows/ci.yml/badge.svg)](https://github.com/si-huynh/koel/actions/workflows/ci.yml)

CopilotKit runtime backend bridge for [koel](https://github.com/si-huynh/koel),
the premium Dart/Flutter SDK for the AG-UI protocol. `koel_runtime` adapts the
[CopilotKit](https://www.copilotkit.ai) runtime to koel's typed AG-UI event
stream over **native SSE** — `CopilotRuntimeAgent extends HttpAgent`, POSTing the
complete `RunAgentInput` to `{endpoint}/agent/{agentName}/run` and parsing the
`text/event-stream` response the runtime emits. It is the **same wire**
agno/langgraph speak, so it rides koel_http's `SseParser`/`HttpAgent` directly —
no GraphQL parser, no stateful converter.

## Getting started

```dart
// pubspec.yaml:  dart pub add koel_runtime
import 'package:koel_runtime/koel_runtime.dart';

final agent = CopilotRuntimeAgent(
  // The runtime BASE path; the run route `/agent/{agentName}/run` is appended.
  endpoint: Uri.parse('https://your-app.example/api/copilotkit'),
  // REQUIRED: the name of the registered runtime agent this run dispatches to.
  agentName: 'your_agent',
  // OPTIONAL: a Bearer token (the v2 runtime is open by default — null no-ops).
  authToken: null,
);

await for (final event in agent.run(input)) {
  // RUN_STARTED → <message/tool/state events> → RUN_FINISHED
}
```

`CopilotRuntimeAgent extends HttpAgent` — it inherits koel_http's full transport
stack (SSE parse, timeouts, cancellation, retry/auth interceptors) and overrides
only two seams: `encodeBody` (normalizes koel's `Message` superset down to
canonical AG-UI for the `messages` array) and `errorClassifier`. Failures never
throw from `run`: a connection error, a non-2xx status, or a malformed body
reaches the consumer as a single terminal `RunErrorEvent` carrying a typed
`KoelError` (refined by `CopilotRuntimeErrorClassifier`).

### `agentName` is required

There is no safe default: the v2 run route is `/agent/{agentName}/run`, naming
*your* registered agent — knowable only at construction — so a hard-coded default
would silently mis-target every real deployment.

### Runtime version pin: `@copilotkit/runtime ≥1.52` (reference-verified `1.59.4`)

CopilotKit v2 (`>= 1.52`) is **native AG-UI over SSE**: `POST
{basePath}/agent/{agentName}/run` returns a `text/event-stream` of canonical
AG-UI events (`data: {type,...}`). The reference backend is verified at
`@copilotkit/runtime@1.59.4` (`SPIKE-CK-V2`). The legacy multipart/`@defer`
**GraphQL** transport of `<= 1.8.14` reached EOL and is **removed** — koel_runtime
no longer bridges it (Story 5.11, SCP-2026-06-05). The runtime's `parseRunRequest`
requires the **complete** `RunAgentInput` (`threadId`/`runId`/`state`/`messages`/
`tools`/`context`/`forwardedProps` all present); `HttpAgent.encodeBody` already
serializes all of them, so this is free.

### Event surface: the full AG-UI matrix (25/28, no 7/28 partition)

v2 is a **transparent AG-UI passthrough** — every `data:` frame is a canonical
AG-UI event the inherited `SseParser` yields verbatim. So koel_runtime surfaces
the same full matrix agno/langgraph do, with **no lossy partition**:
`STATE_SNAPSHOT` **+ `STATE_DELTA`**, `RUN_ERROR` on the wire, `STEP_*`,
`MESSAGES_SNAPSHOT`, reasoning, `ACTIVITY`, `RAW`, `CUSTOM` — all pass through.

The only types not reproduced verbatim are the 3 `*_CHUNK` convenience shapes
(`TEXT_MESSAGE_CHUNK`, `TOOL_CALL_CHUNK`, `REASONING_MESSAGE_CHUNK`): koel_http's
default-on `synthesizeChunks` (Story 4.8) normalizes them into their
`START`/`CONTENT`/`END` triplets *at the transport*, so an HTTP adapter sees long
form — the fixed **25/28** contract shared with every native-AG-UI adapter, not a
bridge limitation. A real runtime never emits chunk shapes anyway.

> **Historical note.** Through `<= 1.8.14` koel_runtime bridged CopilotKit's
> multipart/`@defer` GraphQL transport, which represented only **7 of 28** AG-UI
> types — it collapsed `STATE_DELTA` into the preceding snapshot and **swallowed**
> in-agent `RUN_ERROR` (ending the stream `status:Success`). v2's native SSE
> delivers both on the wire; the `state_delta_basic` + `error_path` conformance
> fixtures are the verbatim proof. The GraphQL parser/converter are preserved at
> the `archive/koel-runtime-graphql` git tag.

## Documentation

Guides are on the [koel docs site](https://si-huynh.github.io/koel/) — see
[Connect CopilotKit runtime](https://si-huynh.github.io/koel/recipes/connect-copilotkit-runtime).
The API reference is on the pub.dev API tab (`dart doc`); see the repo-root
[README](../../README.md) for the package map.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
