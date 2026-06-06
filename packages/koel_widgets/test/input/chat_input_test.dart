import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koel_widgets/koel_widgets.dart';

/// A `MaterialApp` host carrying a `KoelTheme` in its `ThemeData.extensions` —
/// `DefaultTextEditingShortcuts` is mounted by `WidgetsApp`, so the Enter
/// override sits below it.
Widget _host(Widget child, {KoelTheme? theme}) => MaterialApp(
  theme: ThemeData(extensions: [?theme]),
  home: Scaffold(body: child),
);

EditableText _editable(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText));

void main() {
  group('auto-grow', () {
    testWidgets('defaults to minLines 1 / maxLines 5', (tester) async {
      await tester.pumpWidget(
        _host(ChatInput(onSubmit: (_) {}), theme: KoelTheme.light()),
      );
      final e = _editable(tester);
      expect(e.minLines, 1);
      expect(e.maxLines, 5);
    });

    testWidgets('respects a maxLines override', (tester) async {
      await tester.pumpWidget(
        _host(
          ChatInput(onSubmit: (_) {}, maxLines: 3),
          theme: KoelTheme.light(),
        ),
      );
      expect(_editable(tester).maxLines, 3);
    });

    test('rejects a maxLines below 1 at construction', () {
      expect(
        () => ChatInput(onSubmit: (_) {}, maxLines: 0),
        throwsAssertionError,
      );
    });
  });

  group('submit', () {
    testWidgets('Enter submits trimmed content and clears the field', (
      tester,
    ) async {
      String? submitted;
      await tester.pumpWidget(
        _host(
          ChatInput(onSubmit: (c) => submitted = c),
          theme: KoelTheme.light(),
        ),
      );
      await tester.enterText(find.byType(EditableText), '  hello  ');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      // Delivered trimmed (AC1 + the onSubmit dartdoc), not the raw padded text.
      expect(submitted, 'hello');
      expect(_editable(tester).controller.text, isEmpty);
    });

    testWidgets('Shift+Enter is not intercepted, so it does not submit', (
      tester,
    ) async {
      // `SingleActivator(enter)` is modifier-exact: with Shift held it does not
      // match the submit shortcut, so the key falls through to the field (the
      // engine then inserts the newline — exercised by goldens/integration, not
      // simulable from raw key events here). The contract this widget owns is
      // "Shift+Enter must not submit", and the text is preserved (not cleared).
      var submitCount = 0;
      await tester.pumpWidget(
        _host(
          ChatInput(onSubmit: (_) => submitCount++),
          theme: KoelTheme.light(),
        ),
      );
      await tester.enterText(find.byType(EditableText), 'line1');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      expect(submitCount, 0, reason: 'Shift+Enter must not submit');
      expect(_editable(tester).controller.text, 'line1');
    });

    testWidgets('blank/whitespace submit is suppressed', (tester) async {
      var submitCount = 0;
      await tester.pumpWidget(
        _host(
          ChatInput(onSubmit: (_) => submitCount++),
          theme: KoelTheme.light(),
        ),
      );
      await tester.enterText(find.byType(EditableText), '   ');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(submitCount, 0);
    });
  });

  group('attachment slot', () {
    testWidgets('renders the passed widget when non-null', (tester) async {
      await tester.pumpWidget(
        _host(
          ChatInput(
            onSubmit: (_) {},
            attachmentSlot: const Icon(Icons.attach_file, key: Key('attach')),
          ),
          theme: KoelTheme.light(),
        ),
      );
      expect(find.byKey(const Key('attach')), findsOneWidget);
    });

    testWidgets('shows no slot when null', (tester) async {
      await tester.pumpWidget(
        _host(ChatInput(onSubmit: (_) {}), theme: KoelTheme.light()),
      );
      expect(find.byKey(const Key('attach')), findsNothing);
    });
  });

  group('placeholder', () {
    testWidgets('shows while empty, hides after typing', (tester) async {
      await tester.pumpWidget(
        _host(
          ChatInput(onSubmit: (_) {}, placeholder: 'Ask anything'),
          theme: KoelTheme.light(),
        ),
      );
      expect(find.text('Ask anything'), findsOneWidget);

      await tester.enterText(find.byType(EditableText), 'x');
      await tester.pump();
      expect(find.text('Ask anything'), findsNothing);
    });
  });

  testWidgets('renders under a bare CupertinoApp without a KoelTheme', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(child: ChatInput(onSubmit: (_) {})),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byType(EditableText), findsOneWidget);
  });
}
