---
id: sessions
title: Sessions
---

# Sessions

A `ChatSession` is one conversation thread. You mint one from a `KoelClient`:

```dart
final client = KoelClient(agent: myAgent);
final session = client.newSession();           // auto-assigned threadId
final resumed = client.newSession(threadId: 'thread-42'); // a named thread
```

Each session owns its `threadId`, its folded `ChatState`, and the run in flight.
`client.dispose()` cancels and disposes **every** session it minted — the client
is the lifecycle owner, so you never track sessions individually for teardown.

## The session API

| Member | Type | Purpose |
| --- | --- | --- |
| `state` | `ChatState` | the latest fold (see [The reducer](./reducer.md)) |
| `stream` | `Stream<ChatState>` | a new state after each applied event |
| `events` | `Stream<AgUiEvent>` | the raw event stream, pre-fold |
| `send(content, {tools})` | `Future<void>` | start a run with a user message |
| `cancel()` | `void` | abort the run in flight (sub-budget, non-blocking) |
| `persist()` | `Future<void>` | save the current state to the configured storage |
| `clear()` | `Future<void>` | delete the persisted state for this thread |

`cancel()` is fire-and-forget by contract — a stalled transport can never hang
it. The mechanism is the [cancel-correct teardown pattern](../patterns/stream-cancellation.md).

## Persistence

By default a `KoelClient` keeps state in memory (`InMemorySessionStorage`). To
survive app restarts, give it a `SessionStorage`:

- **`HiveSessionStorage`** (`koel_flutter`) — JSON-over-`hive_ce`, keyed by
  `threadId`. See [Persist sessions](../recipes/persist-sessions.md).
- **`SecureSessionStorage`** (`koel_flutter`) — the same API and wire shape,
  encrypted at rest via `flutter_secure_storage`. See
  [Secure sessions](../recipes/secure-sessions.md).

Resume is **explicit**: `newSession` is synchronous and cannot `await` a load, so
you load the persisted `ChatState` and pass it as `initial`:

```dart
final saved = await storage.load('thread-42');
final session = client.newSession(threadId: 'thread-42', initial: saved);
```

In Flutter, `KoelChatController` automates this load/seed dance — you construct it
with a session and it wires the rest.

## Storage contract

`SessionStorage` is a tiny interface — `save`, `load`, `delete` over a
`threadId -> ChatState`. The JSON codec is `koel_core`'s, so all three
implementations share one wire shape: a session persisted by Hive can be read
back by the secure store and vice versa. Note `ChatState.error` is deliberately
**not** persisted — a stale error banner across a restart is wrong; persistence
restores the conversation, not a live failure.
