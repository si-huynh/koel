---
id: persist-sessions
title: Persist sessions
---

# Persist sessions

By default a `KoelClient` keeps conversation state in memory. To survive app
restarts, give it a `SessionStorage`. `HiveSessionStorage` (from `koel_flutter`)
persists each `ChatState` as JSON in a `hive_ce` box, keyed by `threadId`.

```dart
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:koel/koel.dart' show KoelClient;
import 'package:koel_flutter/koel_flutter.dart' show HiveSessionStorage;

Future<KoelClient> buildClient() async {
  await Hive.initFlutter();                       // once, at app startup
  final storage = HiveSessionStorage(boxName: 'koel_sessions');
  return KoelClient(agent: myAgent, sessionStorage: storage);
}
```

Add `hive_ce_flutter` yourself for `Hive.initFlutter()` — koel depends only on
the `hive_ce` runtime. Pure-Dart callers use `Hive.init(path)` instead.

## Save and resume

Persistence is **explicit** — call `persist()` when you want to checkpoint (e.g.
after each completed run):

```dart
final session = client.newSession(threadId: 'thread-42');
await session.send('Remember: my name is Si');
await session.persist();                          // checkpoint this thread
```

Resume is explicit too. `newSession` is synchronous, so it cannot `await` a load;
load the saved state and pass it as `initial`:

```dart
final saved = await storage.load('thread-42');
final resumed = client.newSession(threadId: 'thread-42', initial: saved);
```

`clear()` deletes a thread's persisted state.

## In Flutter

`KoelChatController` automates the load/seed dance — construct it with a session
and it wires resume for you. For encrypted-at-rest storage with the *same API*,
use [Secure sessions](./secure-sessions.md).
