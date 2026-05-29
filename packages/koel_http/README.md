# koel_http

HTTP transport for [koel](https://github.com/si-huynh/koel), the premium
Dart/Flutter SDK for the AG-UI protocol. `koel_http` provides the
framework-free `HttpAgent`, a streaming Server-Sent Events (SSE) parser, and the
transport interceptors (retry, auth, logging, Sentry/PII redaction) that turn an
AG-UI HTTP endpoint into a `koel_core` event stream.

## Getting started

```dart
// pubspec.yaml:  dart pub add koel_http
import 'package:koel_http/koel_http.dart';

final agent = HttpAgent(endpoint: Uri.parse('https://your-backend/agui'));
```

Most apps use the [`koel`](../koel) meta-package. The transport and interceptors
land across Epic 4.

## Documentation

API reference is on the pub.dev API tab (`dart doc`). Guides will live on the
koel docs site (framework pending — `OQ-Docs-Framework`). See the repo-root
[README](../../README.md) for the package map.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
