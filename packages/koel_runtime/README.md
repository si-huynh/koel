# koel_runtime

CopilotKit runtime backend bridge for [koel](https://github.com/si-huynh/koel),
the premium Dart/Flutter SDK for the AG-UI protocol. `koel_runtime` adapts the
[CopilotKit](https://www.copilotkit.ai) Next.js runtime to koel's typed event
stream — including its multipart/GraphQL stream parser — verified against
captured fixtures and the CopilotKit dojo via the conformance runner.

## Getting started

```dart
// pubspec.yaml:  dart pub add koel_runtime
import 'package:koel_runtime/koel_runtime.dart';
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
