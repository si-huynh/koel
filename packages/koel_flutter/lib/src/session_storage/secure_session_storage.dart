import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:koel_core/koel_core.dart';

/// A [SessionStorage] that persists each [ChatState] **encrypted at rest** via
/// `flutter_secure_storage` (F-D1) — the drop-in, PII-safe sibling of
/// `HiveSessionStorage` with the *same* API and the *same* wire-shape.
///
/// Each state is stored as `jsonEncode(state.toJson())` and decoded via
/// [ChatState.fromJson] — the exact koel_core v1.0.0 JSON contract Hive pins, so
/// a state saved by one adapter loads in the other (modulo the store). There is
/// **no** secure-only serialization.
///
/// `flutter_secure_storage` is a **flat, single-namespace** key→value store the
/// consumer may share with their own secrets (they inject the instance). So
/// every persisted key is namespaced under a reserved [_keyPrefix]
/// (`koel_session.$threadId`), and [listThreads] is [FlutterSecureStorage.readAll]
/// filtered to that prefix (stripped). koel therefore enumerates and deletes
/// **only its own** keys — a co-resident `app_auth_token` is never returned by
/// [listThreads] nor removed by [delete], and `deleteAll` is **never** called.
///
/// Unlike Hive there is **no koel-side init step** — `flutter_secure_storage`
/// needs no storage-path setup from koel. What it needs is *platform* setup
/// (iOS/macOS Keychain entitlement, Android KeyStore min-API/backup config,
/// Windows VC++ build deps, an active Linux keyring), which is the **consumer's**
/// responsibility — see the package README's per-platform caveat table (N-11).
///
/// The four [SessionStorage] guarantees hold exactly: [save] is last-write-wins
/// per thread, [load] of an unknown thread returns `null` (never throws on
/// absence), [delete] is idempotent, and [listThreads] hands back a fresh,
/// unordered snapshot the caller owns. I/O and decode failures surface by
/// completing the returned future with an error — persistence sits below the
/// classifier seam, so this adapter does not wrap them in a [KoelError].
class SecureSessionStorage implements SessionStorage {
  /// Creates a storage over [storage], defaulting to `const FlutterSecureStorage()`
  /// (platform defaults). The consumer injects an instance to share or to tune
  /// per-platform options; koel performs no initialization on it.
  SecureSessionStorage({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  /// koel-reserved key namespace within the (possibly app-shared) secure store.
  /// Every session is stored under `'$_keyPrefix$threadId'`; nothing outside the
  /// prefix is read, listed, or deleted by this adapter. *Reserved* is a contract
  /// on the consumer too: koel owns this prefix end-to-end, so a shared store's
  /// other secrets **must not** use it — any `koel_session.`-prefixed key is
  /// treated as a koel thread ([listThreads] enumerates it, [delete] can remove it).
  static const _keyPrefix = 'koel_session.';

  String _key(String threadId) => '$_keyPrefix$threadId';

  /// Persists [state] under [threadId] as a JSON string, overwriting any prior
  /// value for that thread (last write wins).
  @override
  Future<void> save(String threadId, ChatState state) async {
    await _storage.write(
      key: _key(threadId),
      value: jsonEncode(state.toJson()),
    );
  }

  /// Returns the [ChatState] persisted under [threadId], or `null` when none has
  /// been saved. Never throws for a missing key.
  @override
  Future<ChatState?> load(String threadId) async {
    final raw = await _storage.read(key: _key(threadId));
    if (raw == null) return null;
    return ChatState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Removes any persisted state for [threadId]. Idempotent — deleting an absent
  /// thread completes normally — and removes only koel's prefixed key, never the
  /// consumer's other secrets (`deleteAll` is never called).
  @override
  Future<void> delete(String threadId) async {
    await _storage.delete(key: _key(threadId));
  }

  /// Returns a fresh snapshot of the persisted thread ids — the whole store read
  /// back, narrowed to koel's prefixed keys with the prefix stripped, so a shared
  /// store's foreign keys are excluded. The caller owns the returned list, and
  /// this adapter makes no ordering guarantee.
  @override
  Future<List<String>> listThreads() async {
    final all = await _storage.readAll();
    return [
      for (final k in all.keys)
        if (k.startsWith(_keyPrefix)) k.substring(_keyPrefix.length),
    ];
  }
}
