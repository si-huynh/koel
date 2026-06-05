import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:koel_core/koel_core.dart';

/// A [SessionStorage] that persists each [ChatState] as a JSON string in a
/// `hive_ce` box, keyed by `threadId` (F-D1) — so a conversation, including an
/// interrupted mid-stream turn, survives an app restart.
///
/// Each state is stored as `jsonEncode(state.toJson())` in a `Box<String>`; on
/// [load] it is decoded via [ChatState.fromJson]. This deliberately uses **no**
/// Hive `TypeAdapter`/`typeId` — the JSON wire-shape (pinned by the koel_core
/// codec) is the persistence contract, sidestepping Hive's binary versioning.
///
/// **The consumer must initialize Hive before use.** This storage opens a box
/// but never sets Hive's storage path — that is `Hive.initFlutter()` (from
/// `hive_ce_flutter`, in a Flutter app) or `Hive.init(path)` (pure-Dart), a
/// one-time app-startup concern the caller owns (D7). `koel_flutter` depends
/// only on the `hive_ce` runtime; the consumer adds `hive_ce_flutter` itself.
///
/// The four [SessionStorage] guarantees hold exactly: [save] is last-write-wins
/// per thread, [load] of an unknown thread returns `null` (never throws on
/// absence), [delete] is idempotent, and [listThreads] hands back a fresh,
/// unordered snapshot the caller owns. I/O failures surface by completing the
/// returned future with an error — persistence sits below the classifier seam,
/// so this adapter does not wrap them in a [KoelError].
class HiveSessionStorage implements SessionStorage {
  /// Creates a storage over the `hive_ce` box named [boxName]. Synchronous: the
  /// box is opened lazily on first use, so Hive need not be initialized yet at
  /// construction time (only before the first [save]/[load]/[delete]/
  /// [listThreads]).
  HiveSessionStorage({required String boxName}) : _boxName = boxName;

  final String _boxName;

  /// The box open, computed once and cached. Re-opening an already-open box
  /// throws in Hive, so the open is guarded by [HiveInterface.isBoxOpen]: a box
  /// already open under [_boxName] is reused rather than re-opened. The box is
  /// koel-owned — String keys, `Box<String>` values. The reuse guard targets
  /// koel's own re-instantiation (a second [HiveSessionStorage] over the same
  /// box); it does not adopt a box the consumer pre-opened under a *different*
  /// type, since [HiveInterface.isBoxOpen] matches by name only and
  /// `Hive.box<String>` would then throw on the type mismatch.
  late final Future<Box<String>> _box = _openBox();

  Future<Box<String>> _openBox() => Hive.isBoxOpen(_boxName)
      ? Future.value(Hive.box<String>(_boxName))
      : Hive.openBox<String>(_boxName);

  /// Persists [state] under [threadId] as a JSON string, overwriting any prior
  /// value for that thread (last write wins).
  @override
  Future<void> save(String threadId, ChatState state) async {
    final box = await _box;
    await box.put(threadId, jsonEncode(state.toJson()));
  }

  /// Returns the [ChatState] persisted under [threadId], or `null` when none has
  /// been saved. Never throws for a missing key.
  @override
  Future<ChatState?> load(String threadId) async {
    final raw = (await _box).get(threadId);
    if (raw == null) return null;
    return ChatState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  /// Removes any persisted state for [threadId]. Idempotent — deleting an absent
  /// thread completes normally (`Box.delete` of an absent key is a no-op).
  @override
  Future<void> delete(String threadId) async {
    await (await _box).delete(threadId);
  }

  /// Returns a fresh snapshot of the persisted thread ids. The caller owns the
  /// returned list, and adapters make no ordering guarantee.
  @override
  Future<List<String>> listThreads() async =>
      (await _box).keys.cast<String>().toList();
}
