# koel

**koel** is a premium Dart/Flutter SDK for the [AG-UI protocol](https://github.com/ag-ui-protocol/ag-ui) — the open standard for streaming agent-to-UI events used by CopilotKit. It is a clean-slate, multi-package SDK (not an application) that turns an AG-UI agent backend into a typed, testable, Flutter-ready chat experience: sealed event unions, a four-stage event pipeline, framework-free HTTP/SSE transport, backend bridges (Agno, LangGraph, CopilotKit runtime), Flutter glue, widget primitives, and a DevTools extension.

## Quickstart

```dart
// pubspec.yaml:  dart pub add koel
import 'package:koel/koel.dart';

final client = KoelClient(
  agent: HttpAgent(url: Uri.parse('https://your-backend/agui')),
);

final session = client.newSession();
session.stream.listen((state) {
  print(state.messages.last.content); // streamed assistant output
});
await session.send('Hello, agent!');
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

Full guides, concept docs, recipes, the migration guide, and the adapter cookbook
are on the [koel docs site](https://si-huynh.github.io/koel/) (built with
Docusaurus — see [`docs/ADR-001-docs-framework.md`](docs/ADR-001-docs-framework.md)).
The API reference is on each package's pub.dev API tab (`dart doc`); the
per-package READMEs (linked in the table above) are the quick reference.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for the Melos monorepo workflow.

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE) (a copy ships in every package).
