@Tags(['golden'])
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koel_widgets/koel_widgets.dart';

// A fixed set of suggestion pills. Deterministic strings, no time/random.
const _follow = FollowUpList(
  suggestions: ['Summarize', 'Explain like I am five', 'Show code'],
  onSelected: _noop,
);

void _noop(String _) {}

Widget _materialHost({
  required KoelTheme theme,
  required Brightness brightness,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(brightness: brightness, extensions: [theme]),
  home: const Scaffold(
    body: Center(
      child: Padding(padding: EdgeInsets.all(16), child: _follow),
    ),
  ),
);

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(420, 120);
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

  testWidgets('light', (tester) async {
    await tester.pumpWidget(
      _materialHost(theme: KoelTheme.light(), brightness: Brightness.light),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('follow_up_list_light.png'),
    );
  });

  testWidgets('dark', (tester) async {
    await tester.pumpWidget(
      _materialHost(theme: KoelTheme.dark(), brightness: Brightness.dark),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('follow_up_list_dark.png'),
    );
  });

  // No KoelTheme attached — locks the null-fallback's pixels (bare CupertinoApp).
  testWidgets('null-theme fallback (bare CupertinoApp)', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: Center(
          child: Padding(padding: EdgeInsets.all(16), child: _follow),
        ),
      ),
    );
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('follow_up_list_fallback.png'),
    );
  });
}
