---
id: cancel-a-run
title: Cancel a run
---

# Cancel a run

A run in flight can be aborted with `cancel()` — on the session, or on the
`KoelChatController` in Flutter. Cancellation is **fire-and-forget by contract**:
it returns immediately and a stalled transport can never hang it.

```dart
final session = client.newSession();

// Start a run but do not await it.
final pending = session.send('Write a very long essay');

// Later — a stop button, a navigation away, a timeout:
session.cancel();
```

In Flutter, the controller forwards it:

```dart
ElevatedButton(
  onPressed: controller.isStreaming ? controller.cancel : null,
  child: const Text('Stop'),
);
```

## What cancel guarantees

- **Sub-budget teardown.** The transport socket is torn down within the abort
  budget (NFR-8) — not whenever the stream generator next wakes.
- **No event escapes post-cancel.** Once cancelled, no further `AgUiEvent`
  reaches your listeners, even from a backend that keeps sending.
- **It can never hang.** `cancel()` does not await the teardown, so a backend
  that ignores the abort cannot block your UI.

This is the koel house [cancel-correct stream teardown
pattern](../patterns/stream-cancellation.md) — read it if you are writing your own
transport or adapter, where you must implement the same guarantees.

## Disposal cancels too

Disposing the controller (or the client) cancels any run in flight as part of
teardown — you do not need a separate `cancel()` before `dispose()`. The widget
that creates the controller is the one that disposes it.
