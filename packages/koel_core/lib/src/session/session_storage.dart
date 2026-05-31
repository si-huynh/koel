import '../state/chat_state.dart';

/// Persistence SPI for [ChatState] keyed by `threadId` (F-D1).
///
/// The contract is intentionally a four-method key-value store: it is what a
/// consumer needs to resume a conversation across app launches, and no more.
/// The surface is `async` because the real adapters do I/O — `HiveSessionStorage`
/// (disk box) and `SecureSessionStorage` (`flutter_secure_storage`), both Epic 6;
/// `InMemorySessionStorage` is the dependency-free reference impl that completes
/// each future synchronously.
///
/// **Error channel.** An adapter surfaces an I/O failure by completing its future
/// with an error — the consumer's `ErrorClassifier` maps it to a `KoelError` at
/// the call site. `SessionStorage` itself does **not** wrap failures: persistence
/// is below the classifier seam, not part of it. Absence is **not** an error —
/// [load] of an unknown thread completes with `null`, and [delete] of an absent
/// thread is a no-op.
abstract class SessionStorage {
  /// Persists [state] under [threadId], overwriting any prior value for that
  /// thread (last write wins per thread).
  Future<void> save(String threadId, ChatState state);

  /// Returns the persisted [ChatState] for [threadId], or `null` when no state
  /// has been saved under that key. Never throws for a missing key.
  Future<ChatState?> load(String threadId);

  /// Removes any persisted state for [threadId]. Idempotent — deleting an absent
  /// thread completes normally.
  Future<void> delete(String threadId);

  /// Returns a snapshot of the persisted thread ids. The caller owns the
  /// returned list (mutating it never touches the store) and **must not** rely
  /// on its ordering — adapters make no ordering guarantee.
  Future<List<String>> listThreads();
}
