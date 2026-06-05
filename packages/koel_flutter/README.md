# koel_flutter

Flutter glue for [koel](https://github.com/si-huynh/koel), the premium
Dart/Flutter SDK for the AG-UI protocol. `koel_flutter` bridges `koel_core` into
the widget tree: a `KoelChatController`, a `KoelClientScope`, Hive and secure
session storage, a message-content parser, and the widget resolver for
generative (tool-driven) UI.

## Getting started

```dart
// pubspec.yaml:  flutter pub add koel_flutter
import 'package:koel_flutter/koel_flutter.dart';
```

Requires Flutter 3.35.0+ (the release that ships Dart 3.9.0). Most apps use the
[`koel`](../koel) meta-package. The controller, scope, and storage land across
Epic 6.

## Session persistence

`HiveSessionStorage` persists each `ChatState` (including an interrupted
mid-stream turn) to a `hive_ce` box, so conversations survive app restarts. It
stores JSON — no Hive `TypeAdapter` — keyed by `threadId`.

Your app initializes Hive **once** at startup, before constructing the storage.
koel depends only on the `hive_ce` runtime; add `hive_ce_flutter` yourself for
`initFlutter` (it manages the per-platform storage location):

```dart
// pubspec.yaml:  flutter pub add hive_ce_flutter
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

await Hive.initFlutter();                       // once, at app startup
final storage = HiveSessionStorage(boxName: 'koel_sessions');
```

Pure-Dart callers use `Hive.init(path)` instead. (Deeper per-platform storage
caveats and a secure alternative arrive with `SecureSessionStorage`.)

## Documentation

API reference is on the pub.dev API tab (`dart doc`). Guides will live on the
koel docs site (framework pending — `OQ-Docs-Framework`). See the repo-root
[README](../../README.md) for the package map.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
