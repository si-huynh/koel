# koel

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
  agent: HttpAgent(endpoint: Uri.parse('https://your-backend/agui')),
);
```

## Documentation

See the repo-root [README](../../README.md) and the koel docs site (framework
pending — `OQ-Docs-Framework`). API reference is on the pub.dev API tab.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
