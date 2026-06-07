---
id: generative-ui
title: Generative (tool-driven) UI
---

# Generative (tool-driven) UI

When an agent calls a tool, you often want to render a real widget for it — a
weather card, a confirmation form, a chart — instead of plain text. The
`WidgetResolver` (from `koel_flutter`) maps a tool-call name to a widget builder.

```dart
import 'package:flutter/material.dart';
import 'package:koel_core/koel_core.dart' show ToolCallStartEvent;
import 'package:koel_flutter/koel_flutter.dart' show WidgetResolver;

final resolver = WidgetResolver(
  // tool name → builder. The builder receives the ToolCallStartEvent, so it can
  // read the call's name (and, as args stream in, drive a richer widget).
  {
    'show_weather': (context, toolCall) => WeatherCard(call: toolCall),
    'confirm_action': (context, toolCall) => ConfirmForm(call: toolCall),
  },
  // Optional fallback for an unregistered tool name; omit it and the resolver
  // renders the built-in UnknownGenerativeUI placeholder instead.
  onUnknown: (context, toolCall) => Text('Unhandled tool: ${toolCall.toolCallName}'),
);

// In your message list, when you encounter a tool call:
Widget buildToolCall(BuildContext context, ToolCallStartEvent call) =>
    resolver.resolve(context, call);
```

`resolve` is **total** — an absent or unregistered name never throws; it falls
through to `onUnknown`, then to `UnknownGenerativeUI`, which surfaces the
unhandled name so the gap is debuggable.

## Replay-safe side effects

A tool widget often performs a side effect (send an email, charge a card). During
**time-travel replay** that effect must not fire again. `ToolReplayContext` is an
`InheritedWidget` carrying an `isReplaying` flag; read it before acting:

```dart
import 'package:koel_flutter/koel_flutter.dart' show ToolReplayContext;

if (!ToolReplayContext.of(context).isReplaying) {
  await sendTheEmail(); // skipped under replay
}
```

`ToolReplayContext.of` is **total**: with no ancestor it returns a live default
(`isReplaying: false`) — the correct reading in normal (non-replay) operation,
where no replay scope is mounted.
