# koel example

A minimal, generic chat app built on the [`koel`](../packages/koel) meta-package —
the quickstart path that re-exports `koel_core` + `koel_http` + `koel_flutter`.
It composes the opinionated UI layer (`koel_widgets`: `MessageBubble`, `ChatInput`,
`FollowUpList`) over a `KoelChatController` under a `KoelClientScope`, themed with
`KoelTheme`. No business domain — just a chat surface.

## Run it

```sh
cd example
flutter run
```

It runs on all six targets (iOS, Android, web, macOS, Windows, Linux).

The demo ships with an **offline mock agent** so it runs with zero backend:

```dart
MockAgent _demoAgent() => MockAgent.programmatic()
    .runStarted()
    .textMessage('Hello, world!')
    .runFinished()
    .build();
```

Because the mock replays a **fixed script**, every message you send streams back
the same `"Hello, world!"` reply — so the thread fills with repeated identical
assistant turns (each replay also reuses the mock's fixed message id, so the
duplicate bubbles even share an id). That is a mock artifact, not a koel behavior —
a real backend gives dynamic, per-turn replies.

## Swap in a real backend

Replace `_demoAgent()` in [`lib/main.dart`](lib/main.dart) with the backend adapter
that matches your server. Each adapter **is** an `HttpAgent` (it extends one and
talks AG-UI to your endpoint) — you construct it directly, you do not wrap an
`HttpAgent`:

```dart
import 'package:koel_agno/koel_agno.dart'; // or koel_langgraph / koel_runtime

final agent = AgnoAgent(baseURL: Uri.parse('https://your-backend'));
```

- **Agno** → `AgnoAgent(baseURL: …)` (`package:koel_agno`) — POSTs to `baseURL/agno-chat`.
- **LangGraph** → `LangGraphAgent(deploymentUrl: …)` (`package:koel_langgraph`) — `deploymentUrl` is the full AG-UI endpoint.
- **CopilotKit (v2, native AG-UI/SSE)** → `CopilotRuntimeAgent(endpoint: …, agentName: …)` (`package:koel_runtime`).

Then drop the `koel_test` dependency — the mock is only for the offline demo.
