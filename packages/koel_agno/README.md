# koel_agno

Agno backend bridge for [koel](https://github.com/si-huynh/koel), the premium
Dart/Flutter SDK for the AG-UI protocol. `koel_agno` adapts an
[Agno](https://github.com/agno-agi/agno) agent backend to koel's typed event
stream — message conversion, an auth interceptor, and an error classifier tuned
to Agno's wire shape — verified against captured fixtures via the conformance
runner.

## Getting started

```dart
// pubspec.yaml:  dart pub add koel_agno
import 'package:koel_agno/koel_agno.dart';
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
