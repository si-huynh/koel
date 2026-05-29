# koel

**koel** is a premium Dart/Flutter SDK for the [AG-UI protocol](https://github.com/ag-ui-protocol/ag-ui) — the open standard for streaming agent-to-UI events used by CopilotKit. It is a clean-slate, multi-package SDK (not an application) that turns an AG-UI agent backend into a typed, testable, Flutter-ready chat experience: sealed event unions, a four-stage event pipeline, framework-free HTTP/SSE transport, backend bridges (Agno, LangGraph, CopilotKit runtime), Flutter glue, widget primitives, and a DevTools extension.

## Quickstart

```dart
// pubspec.yaml:  dart pub add koel
import 'package:koel/koel.dart';

final client = KoelClient(
  agent: HttpAgent(endpoint: Uri.parse('https://your-backend/agui')),
);

final session = client.chatSession(threadId: 'demo');
await for (final state in session.run('Hello, agent!')) {
  print(state.messages.last.content); // streamed assistant output
}
```

> The quickstart above is the target `koel` meta-package surface; the underlying
> packages land across Epics 2–9. See each package's CHANGELOG for current status.

## Packages

This is a Melos-managed monorepo. Each package is designed to be independently
publishable; during pre-1.0 development every package carries `publish_to: none`
as a safety guard, lifted at the v1.0.0 lock-step publish (Epic 9):

| Package | Role |
| --- | --- |
| [`koel`](packages/koel) | Meta-package re-exporting `koel_core` + `koel_http` + `koel_flutter` (the quickstart path) |
| [`koel_core`](packages/koel_core) | Foundation: AG-UI events, four-stage pipeline, errors, chat state |
| [`koel_http`](packages/koel_http) | Transport: `HttpAgent`, SSE parser, interceptors |
| [`koel_lints`](packages/koel_lints) | Analyzer plugin enforcing koel's mandatory rules |
| [`koel_agno`](packages/koel_agno) | Backend bridge: Agno |
| [`koel_langgraph`](packages/koel_langgraph) | Backend bridge: LangGraph |
| [`koel_runtime`](packages/koel_runtime) | Backend bridge: CopilotKit Next.js runtime |
| [`koel_flutter`](packages/koel_flutter) | Flutter glue: controller, scope, session storage |
| [`koel_widgets`](packages/koel_widgets) | UI primitives: Material 3 + Cupertino |
| [`koel_devtools`](packages/koel_devtools) | DevTools extension + observer |
| [`koel_test`](packages/koel_test) | Fixtures, `MockAgent`, conformance runner |

Per-package changelogs live in each package's `CHANGELOG.md` (see the table links above); release-coordination notes are in the repo-root [CHANGELOG.md](CHANGELOG.md).

## Documentation

Full guides, concept docs, and the API reference will be hosted on the docs site
(framework selection pending — tracked as `OQ-Docs-Framework`). Until then, the
pub.dev API tab (`dart doc`) and per-package READMEs are the reference.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the Melos monorepo workflow.

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE) (a copy ships in every package).
