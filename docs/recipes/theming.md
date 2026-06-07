---
id: theming
title: Theme the widgets
---

# Theme the widgets

`koel_widgets` ships themeable chat building blocks — `MessageBubble`,
`ChatInput`, `FollowUpList` — in both Material 3 and Cupertino styles. One
`KoelTheme`, attached as a `ThemeExtension`, drives all of them.

```dart
import 'package:flutter/material.dart';
import 'package:koel_widgets/koel_widgets.dart';

MaterialApp(
  // The single hook that themes every koel widget below.
  theme: ThemeData(extensions: [KoelTheme.light()]),
  darkTheme: ThemeData.dark().copyWith(extensions: [KoelTheme.dark()]),
  home: const ChatScreen(),
);
```

`KoelTheme.light()` / `KoelTheme.dark()` are ready-made palettes; `copyWith` lets
you override individual slots (colors, text styles, spacing). The widgets read the
theme from the ambient `ThemeExtension`, with a brightness-appropriate fallback if
none is attached — so they render even under a bare `CupertinoApp`.

## The widgets

```dart
// A rendered message — pass a koel_core Message; style is auto-picked from the
// platform, or forced with BubbleStyle.material / BubbleStyle.cupertino.
MessageBubble(message);
MessageBubble(message, style: BubbleStyle.cupertino);

// The composer. Enter submits (Shift+Enter on hardware keyboards inserts a
// newline); the trailing slot is yours (e.g. an attachment button).
ChatInput(
  onSubmit: (text) => controller.send(text), // text is trimmed for you
  placeholder: 'Message koel…',
  attachmentSlot: const Icon(Icons.attach_file),
);

// Tappable follow-up suggestions.
FollowUpList(
  suggestions: const ['Tell me a joke', 'Show me code', 'Summarize this'],
  onSelected: (suggestion) => controller.send(suggestion),
);
```

## Wiring it to a controller

Drive the message list from a `KoelChatController` (see
[Quickstart](./quickstart-offline.md) and the
[`example/`](https://github.com/si-huynh/koel/tree/main/example) app) and feed
each `Message` to a `MessageBubble`. `ChatInput.onSubmit` and
`FollowUpList.onSelected` both call `controller.send`, so the composer and the
suggestions share one path into the session.
