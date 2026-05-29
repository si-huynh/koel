# koel_core

Foundation package for [koel](https://github.com/si-huynh/koel), the premium
Dart/Flutter SDK for the AG-UI protocol. `koel_core` is pure Dart (no Flutter
dependency) and defines the protocol kernel: the sealed `AgUiEvent` union, the
sealed `KoelError` hierarchy, the four-stage event pipeline, the interceptor
chain, the chat-state reducer, and the `KoelClient` / `ChatSession` API.

## Getting started

```dart
// pubspec.yaml:  dart pub add koel_core
import 'package:koel_core/koel_core.dart';
```

Most apps use the [`koel`](../koel) meta-package rather than depending on
`koel_core` directly. The event kernel, pipeline, and client API land across
Epic 2.

## Documentation

API reference is published on the pub.dev API tab (`dart doc`). Guides and
concept docs will live on the koel docs site (framework pending —
`OQ-Docs-Framework`). See the repo-root [README](../../README.md) for the
package map.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Credits

Credit to the community [`ag_ui`](https://pub.dev/packages/ag_ui) 0.1.0 package
as the genre's first attempt at an AG-UI client for Dart. koel is a clean-slate
rewrite with no migration obligation.

> **Tracking:** this credit is pending `OQ-AGUI-License` verification
> (license-compatibility check of `ag_ui` 0.1.0), which gates the first
> *published* README crediting it. Cleared in Epic 9 (FR-I3).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
