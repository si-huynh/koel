import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koel_widgets/koel_widgets.dart';

Widget _host(Widget child, {KoelTheme? theme}) => MaterialApp(
  theme: ThemeData(extensions: [?theme]),
  home: Scaffold(body: child),
);

void main() {
  testWidgets('renders one pill per suggestion', (tester) async {
    await tester.pumpWidget(
      _host(
        FollowUpList(suggestions: const ['a', 'b', 'c'], onSelected: (_) {}),
        theme: KoelTheme.light(),
      ),
    );
    expect(find.text('a'), findsOneWidget);
    expect(find.text('b'), findsOneWidget);
    expect(find.text('c'), findsOneWidget);
  });

  testWidgets('tapping a pill reports its suggestion', (tester) async {
    String? picked;
    await tester.pumpWidget(
      _host(
        FollowUpList(
          suggestions: const ['first', 'second'],
          onSelected: (s) => picked = s,
        ),
        theme: KoelTheme.light(),
      ),
    );
    await tester.tap(find.text('second'));
    expect(picked, 'second');
  });

  testWidgets('is horizontally scrollable', (tester) async {
    await tester.pumpWidget(
      _host(
        FollowUpList(suggestions: const ['a', 'b'], onSelected: (_) {}),
        theme: KoelTheme.light(),
      ),
    );
    final scroll = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(scroll.scrollDirection, Axis.horizontal);
  });

  testWidgets('separates pills by the theme followUpGap', (tester) async {
    final theme = KoelTheme.light().copyWith(
      spacing: KoelTheme.light().spacing.copyWith(followUpGap: 24),
    );
    await tester.pumpWidget(
      _host(
        FollowUpList(suggestions: const ['a', 'b'], onSelected: (_) {}),
        theme: theme,
      ),
    );
    // One gap between two pills.
    final gap = tester.widget<SizedBox>(
      find.descendant(
        of: find.byType(FollowUpList),
        matching: find.byType(SizedBox),
      ),
    );
    expect(gap.width, 24);
  });

  testWidgets('empty suggestions render nothing', (tester) async {
    await tester.pumpWidget(
      _host(
        FollowUpList(suggestions: const [], onSelected: (_) {}),
        theme: KoelTheme.light(),
      ),
    );
    expect(find.byType(SingleChildScrollView), findsNothing);
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('renders under a bare CupertinoApp without a KoelTheme', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: FollowUpList(suggestions: const ['x'], onSelected: (_) {}),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('x'), findsOneWidget);
  });
}
