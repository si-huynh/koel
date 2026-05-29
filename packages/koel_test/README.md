# koel_test

Test harness for [koel](https://github.com/si-huynh/koel), the premium
Dart/Flutter SDK for the AG-UI protocol. `koel_test` provides the testing
toolkit: a `MockAgent`, a synthesized fixture set, a fixture loader, a
tool-handler test harness, and the conformance runner that backend bridges use
to prove they emit spec-correct AG-UI event sequences.

## Getting started

```dart
// pubspec.yaml:  dart pub add --dev koel_test
import 'package:koel_test/koel_test.dart';
```

The mock agent, fixtures, and conformance runner land across Epic 3.

## Documentation

API reference is on the pub.dev API tab (`dart doc`). Guides will live on the
koel docs site (framework pending — `OQ-Docs-Framework`). See the repo-root
[README](../../README.md) for the package map.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
