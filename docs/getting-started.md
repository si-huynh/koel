---
id: getting-started
title: Getting Started
slug: /
---

# Getting Started

**koel** is a premium Dart/Flutter SDK for the [AG-UI protocol](https://github.com/ag-ui-protocol) — the
agent-to-UI event protocol behind CopilotKit. It gives you typed AG-UI events, a
framework-free HTTP/SSE transport, a folded `ChatState`, and Flutter glue, so a
chat surface backed by any AG-UI agent is a few lines rather than a protocol
implementation.

koel is a faithful, contract-first port of the AG-UI standard: every public
symbol is a one-way door, every error reaches a surface, and the sealed event
union is exhaustive. There is no hidden state and no silent failure path.

## Install

For most apps, depend on the `koel` meta-package — it re-exports `koel_core`,
`koel_http`, and `koel_flutter` so a single dependency gives you the whole
quickstart path.

```bash
dart pub add koel
# or, in a Flutter app:
flutter pub add koel
```

Widgets ship separately (they are not re-exported by the meta-package), so add
`koel_widgets` when you want the prebuilt chat UI:

```bash
flutter pub add koel_widgets
```

## Your first run (offline)

You do not need a backend to see koel work. `koel_test`'s `MockAgent` replays a
canned event sequence, so the wiring is identical to production — only the agent
changes.

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

  await session.send('Hi!'); // the mock ignores the prompt and replays its script
  print(session.state.messages.last.content); // → Hello, world!

  client.dispose();
}
```

`KoelClient` owns the agent and every session it mints; disposing the client
tears them all down. `ChatSession.state` is the folded `ChatState` after the
reducer has applied the run's events — see [The reducer](./concepts/reducer.md).

## Swap in a real backend

The only line that changes is the agent. Point an `HttpAgent` at any AG-UI SSE
endpoint:

```dart
import 'package:koel/koel.dart' show HttpAgent, KoelClient;

final client = KoelClient(
  agent: HttpAgent(url: Uri.parse('https://your-backend.example/agui')),
);
```

For a specific backend, use its bridge package — [`koel_agno`](./recipes/connect-agno.md),
[`koel_langgraph`](./recipes/connect-langgraph.md), or
[`koel_runtime`](./recipes/connect-copilotkit-runtime.md) (CopilotKit). They all
speak the same native AG-UI/SSE wire and expose the same `KoelClient` API.

## In Flutter

Drive a chat UI from a `KoelChatController` (a `ChangeNotifier` over the
session's state) and the `koel_widgets` building blocks:

```dart
import 'package:koel/koel.dart' show KoelChatController, KoelClient;
import 'package:koel_test/koel_test.dart' show MockAgent;

final client = KoelClient(agent: MockAgent.programmatic().runStarted().runFinished().build());
final controller = KoelChatController(session: client.newSession());
// ListenableBuilder(listenable: controller, builder: ...) rebuilds on each
// ChatState fold. Dispose the controller, then the client, in State.dispose().
```

The runnable reference app is at
[`example/`](https://github.com/si-huynh/koel/tree/main/example) in the repo.

## Where to next

- **[Concepts](./concepts/events.md)** — events, interceptors, the reducer, and
  sessions, one page each.
- **[Recipes](./recipes/quickstart-offline.md)** — 14 working scenarios, from
  connecting a backend to generative UI.
- **[Adapter Cookbook](./adapter-cookbook.md)** — write your own backend bridge
  against the conformance contract.
- **[Migration Guide](./migration-guide.md)** — the 1.x forward-compatibility
  policy.
- **[API Reference](./api-reference.md)** — the per-package `dart doc` on pub.dev.
