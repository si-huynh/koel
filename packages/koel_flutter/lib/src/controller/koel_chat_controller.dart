import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:koel_core/koel_core.dart';

/// The lowest-common-denominator Flutter binding (FR-D4): a [ChangeNotifier]
/// skin over one [ChatSession] that any state-management framework — Bloc,
/// Riverpod, GetX, `provider`, or plain `setState` — consumes through its
/// standard `Listenable` bridge with **one line and no adapter**.
///
/// It owns nothing but its own subscription. The [session] is injected, so its
/// owner (typically the [KoelClient] that created it via `newSession`) keeps the
/// lifecycle — [dispose] cancels only this controller's listener and never
/// disposes the session (the client's own `dispose` cancels every session it
/// made; double-dispose would be wrong). [state] reads straight through to
/// `session.state`, so there is exactly one source of truth and no second copy
/// to drift; the listener's whole job is to relay [notifyListeners] on each
/// folded snapshot.
///
/// Cancel-correct teardown (house pattern `docs/patterns/stream-cancellation.md`):
/// [cancel] delegates to the session's non-blocking `cancel()` and [dispose]
/// cancels the subscription without `await`ing any transport teardown — a stalled
/// backend can never hang this controller.
class KoelChatController extends ChangeNotifier {
  /// Binds to [session] and subscribes to its [ChatSession.stream] immediately,
  /// relaying every folded [ChatState] as a [notifyListeners] tick.
  KoelChatController({required ChatSession session}) : _session = session {
    _sub = _session.stream.listen((_) {
      // The session never emits after its own dispose; the [_disposed] guard
      // covers the controller being disposed mid-flight, before its cancel lands.
      if (!_disposed) notifyListeners();
    });
  }

  final ChatSession _session;
  late final StreamSubscription<ChatState> _sub;
  bool _disposed = false;

  /// The current folded conversation snapshot — a synchronous read straight from
  /// the session (always current; the no-replay broadcast stream only drives the
  /// [notifyListeners] ticks).
  ChatState get state => _session.state;

  /// `true` while a run is in flight — `RunPhase.running` or inside a `STEP_*`
  /// span (`RunPhase.stepRunning`). `false` for idle, error, and cancelled.
  bool get isStreaming =>
      state.phase == RunPhase.running || state.phase == RunPhase.stepRunning;

  /// Sends a user turn and runs the agent; the returned future completes when the
  /// run finishes (so `await controller.send(...)` waits for the turn).
  Future<void> send(String content) => _session.send(content);

  /// Cancels the in-flight run. Synchronous and non-blocking — the session flips
  /// to `RunPhase.cancelled` immediately and the change relays through the stream.
  void cancel() => _session.cancel();

  /// Resets the conversation to a fresh idle state and deletes any persisted copy.
  Future<void> clear() => _session.clear();

  /// Cancels this controller's subscription and releases its [ChangeNotifier]
  /// listeners. Does **not** dispose the injected [session] — its owner does.
  ///
  /// Idempotent: a second call is a no-op. Stock [ChangeNotifier.dispose]
  /// asserts on a double-dispose, but a controller can have two plausible
  /// disposers (e.g. Riverpod's `ChangeNotifierProvider` owns teardown *and* the
  /// app holds a reference), so the existing [_disposed] latch guards re-entry.
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _sub.cancel();
    super.dispose();
  }
}
