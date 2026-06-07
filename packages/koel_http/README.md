# koel_http

[![pub package](https://img.shields.io/pub/v/koel_http.svg)](https://pub.dev/packages/koel_http)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/si-huynh/koel/actions/workflows/ci.yml/badge.svg)](https://github.com/si-huynh/koel/actions/workflows/ci.yml)

HTTP transport for [koel](https://github.com/si-huynh/koel), the premium
Dart/Flutter SDK for the AG-UI protocol. `koel_http` provides the
framework-free `HttpAgent`, a streaming Server-Sent Events (SSE) parser, and the
transport interceptors (retry, auth, logging, Sentry/PII redaction) that turn an
AG-UI HTTP endpoint into a `koel_core` event stream.

## Getting started

```dart
// pubspec.yaml:  dart pub add koel_http
import 'package:koel_http/koel_http.dart';

final agent = HttpAgent(url: Uri.parse('https://your-backend/agui'));
```

Most apps use the [`koel`](../koel) meta-package.

## Documentation

Guides are on the [koel docs site](https://si-huynh.github.io/koel/) — see
[Connect an HTTP backend](https://si-huynh.github.io/koel/recipes/connect-http-backend)
and [Interceptors](https://si-huynh.github.io/koel/concepts/interceptors). The
API reference is on the pub.dev API tab (`dart doc`); see the repo-root
[README](../../README.md) for the package map.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
