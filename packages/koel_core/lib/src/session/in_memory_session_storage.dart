import '../state/chat_state.dart';
import 'session_storage.dart';

/// Process-lifetime [SessionStorage] backed by a plain in-process `Map` — the
/// zero-dependency reference impl, the fallback when no persistent adapter is
/// configured, and what `koel_test`/examples wire.
///
/// State lives only for the life of this object; it is **not** persisted across
/// restarts. Correctness is trivial because [ChatState] is deeply immutable
/// (freezed unmodifiable collections, opaque `Uint8List` blobs): a stored value
/// cannot be mutated by the caller and a returned value cannot be mutated under
/// the store, so this impl holds and hands back references with **no** defensive
/// copy and **no** serialization. Every future completes synchronously — there
/// is no I/O to await.
class InMemorySessionStorage implements SessionStorage {
  final Map<String, ChatState> _store = {};

  @override
  Future<void> save(String threadId, ChatState state) {
    _store[threadId] = state;
    return Future<void>.value();
  }

  @override
  Future<ChatState?> load(String threadId) => Future.value(_store[threadId]);

  @override
  Future<void> delete(String threadId) {
    _store.remove(threadId);
    return Future<void>.value();
  }

  // `_store.keys` is a live view; `.toList()` hands the caller a stable snapshot.
  @override
  Future<List<String>> listThreads() => Future.value(_store.keys.toList());
}
