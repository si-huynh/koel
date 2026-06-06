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

/// A `MaterialApp` host carrying [theme] in `ThemeData.extensions` so the bubble
/// reads real tokens. [style] forces the design language, so a Material host is
/// fine for the Cupertino variant too.
Widget _host({
  required KoelTheme theme,
  required Brightness brightness,
  required BubbleStyle style,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(brightness: brightness, extensions: [theme]),
  home: Scaffold(
    body: Center(child: MessageBubble(_mixed, style: style)),
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
}
