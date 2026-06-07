@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_widgets/koel_widgets.dart';

// A fixed assistant turn with MIXED segments — prose + a fenced code block — so
// each golden exercises both the `bodyText` and `codeText`/code-surface paths
// (Story 7.2). Deterministic: fixed id, fixed UTC timestamp, no time/random.
final _mixed = Message(
  id: 'g1',
  role: MessageRole.assistant,
  content: 'Here is a snippet:\n```dart\nvoid main() {}\n```',
  timestamp: DateTime.utc(2020),
);

// A long assistant turn whose prose runs far past the reading-width cap, so its
// golden proves the bubble surface stops at the cap on a wide window (AI-7.1)
// rather than stretching edge-to-edge (the role `Align` stays meaningful).
final _wideProse = Message(
  id: 'g2',
  role: MessageRole.assistant,
  content:
      'The koel message bubble caps its reading width on a wide desktop or web '
      'window so a long answer never stretches edge to edge and the role '
      'alignment keeps its meaning across every supported platform.',
  timestamp: DateTime.utc(2020),
);

// A fenced block holding one unbreakable token wider than the bubble, so its
// golden proves the code scrolls within the capped surface instead of clipping
// or forcing the bubble past the cap (AI-7.1).
final _longCode = Message(
  id: 'g3',
  role: MessageRole.assistant,
  content: '```\n${'koeltoken' * 30}\n```',
  timestamp: DateTime.utc(2020),
);

/// Widens the surface for the AI-7.1 goldens so the cap is visible (the default
/// 420px setUp surface is below the cap, where it would be a no-op).
void _useWideSurface() {
  final view = TestWidgetsFlutterBinding.ensureInitialized()
      .platformDispatcher
      .views
      .first;
  view.physicalSize = const Size(1000, 320);
  view.devicePixelRatio = 1;
}

/// A `MaterialApp` host carrying [theme] in `ThemeData.extensions` so the bubble
/// reads real tokens. [style] forces the design language, so a Material host is
/// fine for the Cupertino variant too.
Widget _host({
  required KoelTheme theme,
  required Brightness brightness,
  required BubbleStyle style,
  Message? message,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(brightness: brightness, extensions: [theme]),
  home: Scaffold(
    body: Center(child: MessageBubble(message ?? _mixed, style: style)),
  ),
);

void main() {
  // A small, fixed surface keeps every golden stable and compact.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(420, 200);
    view.devicePixelRatio = 1;
  });
  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('material × light', (tester) async {
    await tester.pumpWidget(
      _host(
        theme: KoelTheme.light(),
        brightness: Brightness.light,
        style: BubbleStyle.material,
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('message_bubble_material_light.png'),
    );
  });

  testWidgets('material × dark', (tester) async {
    await tester.pumpWidget(
      _host(
        theme: KoelTheme.dark(),
        brightness: Brightness.dark,
        style: BubbleStyle.material,
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('message_bubble_material_dark.png'),
    );
  });

  testWidgets('cupertino × light', (tester) async {
    await tester.pumpWidget(
      _host(
        theme: KoelTheme.light(),
        brightness: Brightness.light,
        style: BubbleStyle.cupertino,
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('message_bubble_cupertino_light.png'),
    );
  });

  testWidgets('cupertino × dark', (tester) async {
    await tester.pumpWidget(
      _host(
        theme: KoelTheme.dark(),
        brightness: Brightness.dark,
        style: BubbleStyle.cupertino,
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('message_bubble_cupertino_dark.png'),
    );
  });

  // AI-7.1 goldens — rendered on a wide surface so the cap is visible.
  testWidgets('wide prose is capped (material × light)', (tester) async {
    _useWideSurface();
    await tester.pumpWidget(
      _host(
        theme: KoelTheme.light(),
        brightness: Brightness.light,
        style: BubbleStyle.material,
        message: _wideProse,
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('message_bubble_wide_prose_capped.png'),
    );
  });

  testWidgets('long code scrolls within the cap (material × light)', (
    tester,
  ) async {
    _useWideSurface();
    await tester.pumpWidget(
      _host(
        theme: KoelTheme.light(),
        brightness: Brightness.light,
        style: BubbleStyle.material,
        message: _longCode,
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('message_bubble_long_code_scroll.png'),
    );
  });
}
