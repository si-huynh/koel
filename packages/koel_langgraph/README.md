# koel_langgraph

LangGraph backend bridge for [koel](https://github.com/si-huynh/koel), the
premium Dart/Flutter SDK for the AG-UI protocol. `koel_langgraph` adapts a
[LangGraph](https://github.com/langchain-ai/langgraph) agent backend to koel's
typed event stream — protocol conversion plus first-class interrupt/resume
surfacing — verified against captured fixtures via the conformance runner.

## Getting started

```dart
// pubspec.yaml:  dart pub add koel_langgraph
import 'package:koel_langgraph/koel_langgraph.dart';
```

The bridge lands in Epic 5.

## Interrupt-resume

`koel_langgraph` ships **surface-level** interrupt-resume in v1. When a LangGraph
run pauses on an `interrupt`, the pause surfaces on the `run()` stream as a
canonical AG-UI `CUSTOM` event (`name: "on_interrupt"`). The consumer reads that
value and reopens the run on the same thread:

```dart
final resumed = agent.resume(threadId, {'approved': true});
```

`resume` POSTs the value to the same deployment and reopens the SSE stream;
LangGraph rebuilds run state **server-side** from its checkpoint — koel performs
no client-side state reconstruction.

**Deep** (stateful sub-tree) interrupt-resume defers to v2, tracked as
`OQ-LangGraph-Graduation` in the koel open-questions registry (linkable once the
docs site lands — `OQ-Docs-Framework`).

## Documentation

API reference is on the pub.dev API tab (`dart doc`). Guides will live on the
koel docs site (framework pending — `OQ-Docs-Framework`). See the repo-root
[README](../../README.md) for the package map.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
