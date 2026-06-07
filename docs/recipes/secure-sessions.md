---
id: secure-sessions
title: Secure sessions
---

# Secure sessions

`SecureSessionStorage` is a drop-in, **encrypted-at-rest** alternative to
`HiveSessionStorage` with the *same API* and the *same JSON wire shape* — back it
with `flutter_secure_storage` when conversations may carry PII.

```dart
import 'package:koel/koel.dart' show KoelClient;
import 'package:koel_flutter/koel_flutter.dart' show SecureSessionStorage;

final client = KoelClient(
  agent: myAgent,
  sessionStorage: SecureSessionStorage(),   // or inject a tuned instance
);
```

Save and resume are identical to [Persist sessions](./persist-sessions.md) —
`persist()`, `load()`, `clear()`, and seeding a resumed session via `initial`. A
state written by Hive can be read by the secure store and vice versa: one wire
shape across all three storages.

## Namespacing

Keys are namespaced under a reserved `koel_session.` prefix. If you inject a
`FlutterSecureStorage` that also holds your app's own secrets, koel enumerates and
deletes **only its own** keys — *reserved* cuts both ways, so do not store your
own keys under that prefix.

## Platform setup is yours

Unlike Hive there is no koel-side init; what secure storage needs is **platform**
setup:

| Platform | Backing store | You must |
| --- | --- | --- |
| iOS / macOS | Keychain | Add the Keychain Sharing entitlement; mind accessibility before first unlock. |
| Android | KeyStore | `minSdkVersion 23`; disable auto-backup for the keys. |
| Web | WebCrypto over `localStorage` | HTTPS or `localhost` only. Not hardware-backed. |
| Windows | DPAPI | Ship the VC++ build tools at build time. |
| Linux | `libsecret` | Requires an active keyring (GNOME Keyring, KDE Wallet, …). |

See the [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage)
docs for per-platform options.
