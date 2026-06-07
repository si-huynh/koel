# koel

[![pub package](https://img.shields.io/pub/v/koel.svg)](https://pub.dev/packages/koel)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/si-huynh/koel/actions/workflows/ci.yml/badge.svg)](https://github.com/si-huynh/koel/actions/workflows/ci.yml)

The meta-package for [koel](https://github.com/si-huynh/koel), the premium
Dart/Flutter SDK for the AG-UI protocol. `koel` re-exports `koel_core` +
`koel_http` + `koel_flutter` so that `dart pub add koel` gives you the complete
quickstart path — typed events, HTTP/SSE transport, and Flutter glue — from a
single dependency.

## Getting started

```dart
// pubspec.yaml:  dart pub add koel
import 'package:koel/koel.dart';

final client = KoelClient(
  agent: HttpAgent(url: Uri.parse('https://your-backend/agui')),
);
```

## Documentation

Guides, concepts, and recipes are on the [koel docs site](https://si-huynh.github.io/koel/).
The API reference is on the pub.dev API tab (`dart doc`); see the repo-root
[README](../../README.md) for the package map.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
