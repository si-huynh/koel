# koel_test

[![pub package](https://img.shields.io/pub/v/koel_test.svg)](https://pub.dev/packages/koel_test)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/si-huynh/koel/actions/workflows/ci.yml/badge.svg)](https://github.com/si-huynh/koel/actions/workflows/ci.yml)

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

## Documentation

Guides are on the [koel docs site](https://si-huynh.github.io/koel/) — see the
[Quickstart (offline)](https://si-huynh.github.io/koel/recipes/quickstart-offline)
and the [Adapter Cookbook](https://si-huynh.github.io/koel/adapter-cookbook) for
the conformance runner. The API reference is on the pub.dev API tab (`dart doc`);
see the repo-root [README](../../README.md) for the package map.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
