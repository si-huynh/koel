---
id: quickstart-offline
title: Quickstart (offline)
---

# Quickstart (offline)

Run a full koel conversation with no backend. `koel_test`'s `MockAgent` replays a
scripted event sequence, so the wiring is byte-identical to production — only the
agent differs. This is the fastest way to see the event → reducer → state flow,
and the basis of every widget test.

```dart
import 'package:koel/koel.dart' show KoelClient;
import 'package:koel_test/koel_test.dart' show MockAgent;

Future<void> main() async {
  final agent = MockAgent.programmatic()
      .runStarted()
      .textMessage('Hello, world!')
      .runFinished()
      .build();

  final client = KoelClient(agent: agent);
  final session = client.newSession();

  await session.send('Hi!'); // the mock ignores the prompt, replays its script
  print(session.state.messages.last.content); // → Hello, world!

  client.dispose();
}
```

## Watch the state fold

`session.stream` emits a fresh `ChatState` after each event. Listen to it to see
the message stream in mid-flight:

```dart
final sub = session.stream.listen((state) {
  print('phase=${state.phase} messages=${state.messages.length}');
});
await session.send('Hi!');
await sub.cancel();
```

## Why programmatic, not a fixture

`MockAgent.fromFixture(name)` loads a recorded JSONL trace, but its loader uses
`Isolate.resolvePackageUri` — a `dart:io`/VM-only path that throws under
`flutter test`/`flutter run` and on web. `MockAgent.programmatic()` needs none of
that, so it runs identically everywhere. Use `fromFixture` only in pure-Dart VM
tests; use `programmatic` in Flutter and on web.

Next: swap the agent for a real backend — [Connect an HTTP backend](./connect-http-backend.md).
