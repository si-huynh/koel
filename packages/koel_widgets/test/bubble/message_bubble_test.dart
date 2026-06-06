import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_widgets/koel_widgets.dart';
// Internal variants are not exported from the barrel; same-package tests reach
// them via their `src/` path for `find.byType` assertions.
import 'package:koel_widgets/src/bubble/cupertino_bubble.dart';
import 'package:koel_widgets/src/bubble/material_bubble.dart';

Message _msg(MessageRole role, String content) => Message(
  id: 'm1',
  role: role,
  content: content,
  timestamp: DateTime.utc(2020),
);

/// A `MaterialApp` host with a forced [platform], a `KoelTheme` [theme] in its
/// `ThemeData.extensions`, and an explicit [brightness].
Widget _host({
  required Widget child,
  required TargetPlatform platform,
  required KoelTheme theme,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: ThemeData(
    platform: platform,
    brightness: brightness,
    extensions: [theme],
  ),
  home: Scaffold(body: Center(child: child)),
);

/// The fill of the (single) `Material` inside the rendered `MaterialBubble`.
Color _materialFill(WidgetTester tester) => tester
    .widget<Material>(
      find.descendant(
        of: find.byType(MaterialBubble),
        matching: find.byType(Material),
      ),
    )
    .color!;

void main() {
  group('variant selection', () {
    testWidgets('auto-picks Cupertino on iOS', (tester) async {
      await tester.pumpWidget(
        _host(
          platform: TargetPlatform.iOS,
          theme: KoelTheme.light(),
          child: MessageBubble(_msg(MessageRole.user, 'hi')),
        ),
      );
      expect(find.byType(CupertinoBubble), findsOneWidget);
      expect(find.byType(MaterialBubble), findsNothing);
    });

    testWidgets('auto-picks Material on Android', (tester) async {
      await tester.pumpWidget(
        _host(
          platform: TargetPlatform.android,
          theme: KoelTheme.light(),
          child: MessageBubble(_msg(MessageRole.user, 'hi')),
        ),
      );
      expect(find.byType(MaterialBubble), findsOneWidget);
      expect(find.byType(CupertinoBubble), findsNothing);
    });

    testWidgets('explicit BubbleStyle.material overrides an Apple platform', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(
          platform: TargetPlatform.iOS,
          theme: KoelTheme.light(),
          child: MessageBubble(
            _msg(MessageRole.user, 'hi'),
            style: BubbleStyle.material,
          ),
        ),
      );
      expect(find.byType(MaterialBubble), findsOneWidget);
      expect(find.byType(CupertinoBubble), findsNothing);
    });

    testWidgets(
      'explicit BubbleStyle.cupertino overrides a non-Apple platform',
      (tester) async {
        await tester.pumpWidget(
          _host(
            platform: TargetPlatform.android,
            theme: KoelTheme.light(),
            child: MessageBubble(
              _msg(MessageRole.user, 'hi'),
              style: BubbleStyle.cupertino,
            ),
          ),
        );
        expect(find.byType(CupertinoBubble), findsOneWidget);
        expect(find.byType(MaterialBubble), findsNothing);
      },
    );
  });

  group('role mapping', () {
    testWidgets('user paints the user fill', (tester) async {
      final theme = KoelTheme.light();
      await tester.pumpWidget(
        _host(
          platform: TargetPlatform.android,
          theme: theme,
          child: MessageBubble(_msg(MessageRole.user, 'hi')),
        ),
      );
      expect(_materialFill(tester), theme.colors.messageBubbleUser);
    });

    testWidgets('assistant / system / tool all paint the assistant fill', (
      tester,
    ) async {
      final theme = KoelTheme.light();
      for (final role in [
        MessageRole.assistant,
        MessageRole.system,
        MessageRole.tool,
      ]) {
        await tester.pumpWidget(
          _host(
            platform: TargetPlatform.android,
            theme: theme,
            child: MessageBubble(_msg(role, 'hi')),
          ),
        );
        expect(
          _materialFill(tester),
          theme.colors.messageBubbleAssistant,
          reason: '$role should map to the assistant slot',
        );
      }
    });
  });

  group('segment rendering', () {
    testWidgets('renders mixed prose + fenced code segments', (tester) async {
      final theme = KoelTheme.light();
      await tester.pumpWidget(
        _host(
          platform: TargetPlatform.android,
          theme: theme,
          child: MessageBubble(
            _msg(MessageRole.assistant, 'before\n```dart\nx();\n```\nafter'),
          ),
        ),
      );

      expect(find.text('before'), findsOneWidget);
      expect(find.text('after'), findsOneWidget);
      expect(find.text('x();'), findsOneWidget);

      // The code run keeps its monospace `codeText` family…
      final codeText = tester.widget<Text>(find.text('x();'));
      expect(codeText.style?.fontFamily, 'monospace');

      // …and sits on the `codeBlockBackground` surface.
      final onCodeSurface = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .any(
            (d) =>
                (d.decoration as BoxDecoration).color ==
                theme.colors.codeBlockBackground,
          );
      expect(onCodeSurface, isTrue);
    });

    testWidgets('prose run takes the role on-colour', (tester) async {
      final theme = KoelTheme.light();
      await tester.pumpWidget(
        _host(
          platform: TargetPlatform.android,
          theme: theme,
          child: MessageBubble(_msg(MessageRole.user, 'hi')),
        ),
      );
      final prose = tester.widget<Text>(find.text('hi'));
      expect(prose.style?.color, theme.colors.onMessageBubbleUser);
    });
  });

  group('null-KoelTheme resilience', () {
    testWidgets('renders under a bare CupertinoApp (no extension, no throw)', (
      tester,
    ) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(child: MessageBubble(_msg(MessageRole.assistant, 'hi'))),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('hi'), findsOneWidget);
      // The light default is the fallback under a (light) CupertinoApp.
      expect(
        _materialFill(tester),
        KoelTheme.light().colors.messageBubbleAssistant,
      );
    });

    testWidgets('fallback honours dark brightness when no KoelTheme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            platform: TargetPlatform.android,
            brightness: Brightness.dark,
          ),
          home: Scaffold(
            body: Center(child: MessageBubble(_msg(MessageRole.user, 'hi'))),
          ),
        ),
      );
      expect(_materialFill(tester), KoelTheme.dark().colors.messageBubbleUser);
    });
  });

  group('empty content', () {
    testWidgets('empty content paints no bubble surface', (tester) async {
      // An assistant-with-tool-calls turn decodes to `content == ''` ⇒ no
      // segments ⇒ the bubble must collapse, not paint an empty padded pill.
      await tester.pumpWidget(
        _host(
          platform: TargetPlatform.android,
          theme: KoelTheme.light(),
          child: MessageBubble(_msg(MessageRole.assistant, '')),
        ),
      );
      expect(find.byType(MaterialBubble), findsNothing);
      expect(find.byType(CupertinoBubble), findsNothing);
    });
  });
}
