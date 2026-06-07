---
id: interrupt-resume
title: Interrupt & resume
---

# Interrupt & resume

LangGraph runs can pause on an `interrupt` — a human-in-the-loop checkpoint.
`koel_langgraph` surfaces the pause as a canonical AG-UI `CUSTOM` event
(`name: "on_interrupt"`) on the run stream; you read its value and reopen the run
on the same thread.

```dart
import 'package:koel_core/koel_core.dart';
import 'package:koel_langgraph/koel_langgraph.dart' show LangGraphAgent;

final agent = LangGraphAgent(
  deploymentUrl: Uri.parse('http://localhost:8003/agent'),
);

// Watch the raw event stream for the interrupt.
await for (final event in agent.run(input)) {
  if (event is CustomEvent && event.name == 'on_interrupt') {
    final question = event.value; // whatever the graph paused to ask
    // ... surface `question` to the user, collect an answer ...
    break;
  }
}

// Reopen the run on the same thread with the human's decision.
final resumed = agent.resume(input.threadId, {'approved': true});
await for (final event in resumed) {
  // the run continues from the checkpoint
}
```

## How resume works

`resume(threadId, resumeValue)` POSTs the value to the same deployment and
reopens the SSE stream. LangGraph rebuilds run state **server-side** from its
checkpoint — koel performs no client-side state reconstruction, so the
`resumeValue` is the only thing you send.

## Scope

koel ships **surface-level** interrupt/resume in 1.x: the pause surfaces, you
answer, the run resumes. **Deep** (stateful sub-tree) interrupt/resume is a v2
concern, tracked as `OQ-LangGraph-Graduation`.

See [Connect LangGraph](./connect-langgraph.md) for the agent setup and
[Events](../concepts/events.md) for the `CUSTOM` family.
