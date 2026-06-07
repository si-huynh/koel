# koel_agno

[![pub package](https://img.shields.io/pub/v/koel_agno.svg)](https://pub.dev/packages/koel_agno)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/si-huynh/koel/actions/workflows/ci.yml/badge.svg)](https://github.com/si-huynh/koel/actions/workflows/ci.yml)

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

## Authentication

`AgnoAgent`'s `token` is optional, and the `AgnoAuthInterceptor` is **default-ON**
as a harmless convention: stock agno enforces **zero auth** on its AG-UI route
(CORS only — `OQ-Agno-Auth` resolved against `agno==2.6.10`), so an open
deployment simply ignores the `Authorization` header. Pass a `token` only when
your deployment adds its own auth middleware (which then returns `401`/`403`,
mapped to `businessAuth`/`businessForbidden` by `AgnoErrorClassifier`):

```dart
final agent = AgnoAgent(baseURL: Uri.parse('https://my-agno.example'), token: 'xyz');
```

## Documentation

Guides are on the [koel docs site](https://si-huynh.github.io/koel/) — see
[Connect Agno](https://si-huynh.github.io/koel/recipes/connect-agno). The API
reference is on the pub.dev API tab (`dart doc`); see the repo-root
[README](../../README.md) for the package map.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
