@Tags(['golden'])
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koel_widgets/koel_widgets.dart';

// Deterministic empty composer showing its placeholder — no focus, so no
// blinking-cursor timer, so the golden is stable.
const _input = ChatInput(onSubmit: _noop, placeholder: 'Message…');

void _noop(String _) {}

Widget _materialHost({
  required KoelTheme theme,
  required Brightness brightness,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: ThemeData(brightness: brightness, extensions: [theme]),
  home: const Scaffold(
    body: Center(
      child: Padding(padding: EdgeInsets.all(16), child: _input),
    ),
  ),
);

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(420, 160);
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
      matchesGoldenFile('chat_input_light.png'),
    );
  });

  testWidgets('dark', (tester) async {
    await tester.pumpWidget(
      _materialHost(theme: KoelTheme.dark(), brightness: Brightness.dark),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('chat_input_dark.png'),
    );
  });

  // No KoelTheme attached: a bare CupertinoApp carries no Material `Theme`
  // extension, so this locks the null-fallback's pixels (resolveKoelTheme →
  // brightness-appropriate default).
  testWidgets('null-theme fallback (bare CupertinoApp)', (tester) async {
    await tester.pumpWidget(
      const CupertinoApp(
        debugShowCheckedModeBanner: false,
        home: Center(
          child: Padding(padding: EdgeInsets.all(16), child: _input),
        ),
      ),
    );
    await expectLater(
      find.byType(CupertinoApp),
      matchesGoldenFile('chat_input_fallback.png'),
    );
  });
}
