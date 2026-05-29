# koel_devtools

DevTools extension for [koel](https://github.com/si-huynh/koel), the premium
Dart/Flutter SDK for the AG-UI protocol. `koel_devtools` ships an in-app
observer (a ring buffer over the event stream) and a Flutter DevTools extension
with stream, history (time-travel replay), inspector, network, and export
panels for debugging AG-UI sessions.

## Getting started

```dart
// pubspec.yaml:  flutter pub add --dev koel_devtools
import 'package:koel_devtools/koel_devtools.dart';
```

Requires Flutter 3.35.0+ (the release that ships Dart 3.9.0). The observer and
extension panels land across Epic 8.

## Documentation

API reference is on the pub.dev API tab (`dart doc`). Guides will live on the
koel docs site (framework pending — `OQ-Docs-Framework`). See the repo-root
[README](../../README.md) for the package map.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
