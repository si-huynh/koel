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

## Documentation

API reference is on the pub.dev API tab (`dart doc`). Guides will live on the
koel docs site (framework pending — `OQ-Docs-Framework`). See the repo-root
[README](../../README.md) for the package map.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
