# koel_runtime

CopilotKit runtime backend bridge for [koel](https://github.com/si-huynh/koel),
the premium Dart/Flutter SDK for the AG-UI protocol. `koel_runtime` adapts the
[CopilotKit](https://www.copilotkit.ai) Next.js runtime to koel's typed AG-UI
event stream — POSTing the `generateCopilotResponse` GraphQL mutation and
reconstructing AG-UI events from the runtime's `multipart/mixed` GraphQL
Incremental Delivery response.

## Getting started

```dart
// pubspec.yaml:  dart pub add koel_runtime
import 'package:koel_runtime/koel_runtime.dart';

final agent = CopilotRuntimeAgent(
  // The FULL GraphQL endpoint, used verbatim — nothing is appended.
  graphqlEndpoint: Uri.parse('https://your-app.example/api/copilotkit'),
  // REQUIRED: the name of the registered runtime agent this run dispatches to.
  agentName: 'your_agent',
);

await for (final event in agent.run(input)) {
  // RUN_STARTED → <message/tool/state events> → RUN_FINISHED
}
```

`CopilotRuntimeAgent` `implements AbstractAgent` directly (it is independent of
`koel_http` — no SSE transport stack); it hand-rolls its POST + multipart parse
over `package:http`. Failures never throw from `run`: a connection error, a
non-2xx status, or a malformed body reaches the consumer as a single terminal
`RunErrorEvent` carrying a typed `KoelError` (refined by
`CopilotRuntimeErrorClassifier`).

### `agentName` is required

There is no safe default: without `agentName` the runtime falls through to its
service adapter and `ExperimentalEmptyAdapter` throws. It names *your* registered
agent — knowable only at construction — so a hard-coded default would silently
mis-target every real deployment.

### Runtime version pin: `@copilotkit/runtime@1.8.14`

This bridge targets the **multipart/`@defer` GraphQL** transport of the CopilotKit
App Router runtime. `1.8.14` is the last stable release that speaks it: every
version `>= 1.52.0` switches the App Router to the v2 protocol (Hono JSON
method-call, no multipart GraphQL), which is **out of scope** for this adapter. A
stable 2.x does not yet exist (only a `2.0.0-next.1` prerelease). Pin your runtime
to `<= 1.8.14` to use `koel_runtime`.

### Divergence: the runtime swallows `RUN_ERROR`

When an agent-side failure raises an AG-UI `RUN_ERROR` *inside* the runtime, the
runtime ends the stream with `status:{code:Success}` and drops the remaining
output — it emits no GraphQL `errors` (`SPIKE-CK-FRAMING`). So an in-agent
`RUN_ERROR` is **unobservable** on the copilotkit wire: `koel_runtime` is a
**transport-conformance target**, not an AG-UI-event-matrix source. The full
AG-UI event-type matrix (including `RUN_ERROR`) is carried by the AG-UI dojo
captures + the synthesized conformance corpus. `CopilotRuntimeErrorClassifier`
classifies the genuinely observable surfaces — transport/parser throws and HTTP
statuses (401/403/429 → business codes, the documented internal 500 →
`agentInternal`).

## Documentation

API reference is on the pub.dev API tab (`dart doc`). Guides will live on the
koel docs site (framework pending — `OQ-Docs-Framework`). See the repo-root
[README](../../README.md) for the package map.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
