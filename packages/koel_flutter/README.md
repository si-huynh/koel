# koel_flutter

[![pub package](https://img.shields.io/pub/v/koel_flutter.svg)](https://pub.dev/packages/koel_flutter)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://github.com/si-huynh/koel/actions/workflows/ci.yml/badge.svg)](https://github.com/si-huynh/koel/actions/workflows/ci.yml)

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

Requires Flutter 3.38.0+ (the release that ships Dart 3.11.0). Most apps use the
[`koel`](../koel) meta-package.

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

Pure-Dart callers use `Hive.init(path)` instead.

### Secure persistence

`SecureSessionStorage` is a drop-in, **encrypted-at-rest** alternative with the
*same API* and the *same JSON wire-shape* as `HiveSessionStorage` — back it with
`flutter_secure_storage` when conversations may carry PII. Keys are namespaced
under a reserved `koel_session.` prefix, so if you inject a `FlutterSecureStorage`
that also holds your app's secrets, koel enumerates and deletes **only its own**
(*reserved* cuts both ways — don't store your own keys under that prefix):

```dart
final storage = SecureSessionStorage();        // or inject a tuned instance
```

Unlike Hive there is no koel-side init. What secure storage needs is **platform**
setup, and that is your responsibility:

| Platform      | Backing store | You must                                                                                         |
| ------------- | ------------- | ------------------------------------------------------------------------------------------------ |
| iOS / macOS   | Keychain      | Add the Keychain Sharing entitlement; mind data accessibility before first unlock (cold start). On older iOS, Keychain entries can survive app uninstall. |
| Android       | KeyStore      | `minSdkVersion 23`; disable auto-backup for the keys (else restore fails to decrypt). Data is cleared on factory reset / "clear app data". |
| Web           | WebCrypto over `localStorage` | HTTPS or `localhost` only. **Not hardware-backed** — weaker than the native stores. |
| Windows       | DPAPI         | Ship with the VC++ build tools available at build time.                                          |
| Linux         | `libsecret`   | Requires an active keyring (GNOME Keyring, KDE Wallet, …) running on the target.                  |

See the [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)
docs for per-platform options.

## Platform support

`koel_flutter` targets all six Flutter platforms. The library itself is
`dart:io`-free, so it compiles and renders on **web** as well as native — the
[`ci.yml`](../../.github/workflows/ci.yml) `flutter-smoke` matrix proves this on
every PR (NFR-11) with a render smoke test:

| Platform                | CI lane                                         | Notes |
| ----------------------- | ----------------------------------------------- | ----- |
| macOS / Linux / Windows | `flutter test` (host)                           | Build + render on each desktop toolchain. |
| Web                     | `flutter test --platform chrome` (headless)     | Compiles to JS and runs in Chrome — verifies the **`dart:io`-free** path. On web, `dart:io` is unavailable: use programmatic agents (`MockAgent.programmatic()`), **not** `MockAgent.fromFixture`, which reads fixtures through `dart:io` and is VM/native-only. |
| iOS / Android           | Epic 9 device matrix                            | Need a booted simulator/emulator; the full 10-package × 6-platform device matrix (AR-17) lives in Epic 9. A no-plugin render smoke shares the desktop lanes' Dart frontend, so it adds no marginal coverage here — plugin-channel divergence for storage is covered by the Hive/secure-storage tests. |

## Documentation

Guides are on the [koel docs site](https://si-huynh.github.io/koel/) — see
[Sessions](https://si-huynh.github.io/koel/concepts/sessions),
[Persist sessions](https://si-huynh.github.io/koel/recipes/persist-sessions), and
[Generative UI](https://si-huynh.github.io/koel/recipes/generative-ui). The API
reference is on the pub.dev API tab (`dart doc`); see the repo-root
[README](../../README.md) for the package map.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## License

MIT © 2026 Si Huynh. See [LICENSE](LICENSE).
