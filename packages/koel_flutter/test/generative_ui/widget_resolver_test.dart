import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_flutter/koel_flutter.dart';

void main() {
  // Pumps [child] under a minimal, theme-free surface so widgets needing a text
  // direction (e.g. UnknownGenerativeUI's Text) render without Material.
  Future<void> pumpSurface(WidgetTester tester, Widget child) =>
      tester.pumpWidget(
        Directionality(textDirection: TextDirection.ltr, child: child),
      );

  ToolCallStartEvent start(String name) =>
      ToolCallStartEvent(toolCallId: 'c1', toolCallName: name);

  group('resolve — registered builder (AC1, AC2)', () {
    testWidgets('returns and renders the registered widget for the name', (
      tester,
    ) async {
      final resolver = WidgetResolver({
        'chart': (context, toolCall) => const _ChartStub(),
      });

      late final Widget resolved;
      await pumpSurface(
        tester,
        Builder(
          builder: (context) {
            resolved = resolver.resolve(context, start('chart'));
            return resolved;
          },
        ),
      );

      expect(resolved, isA<_ChartStub>());
      expect(tester.takeException(), isNull);
      expect(find.byType(_ChartStub), findsOneWidget);
    });
  });

  group('resolve — unregistered name falls back (AC3)', () {
    testWidgets(
      'with no onUnknown, renders UnknownGenerativeUI naming the tool',
      (tester) async {
        final resolver = WidgetResolver({
          'chart': (context, toolCall) => const _ChartStub(),
        });

        await pumpSurface(
          tester,
          Builder(
            builder: (context) => resolver.resolve(context, start('unknown')),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(UnknownGenerativeUI), findsOneWidget);
        expect(find.byType(_ChartStub), findsNothing);
        expect(find.textContaining('Unhandled generative UI'), findsOneWidget);
      },
    );

    testWidgets('with onUnknown supplied, renders that builder instead', (
      tester,
    ) async {
      final resolver = WidgetResolver({
        'chart': (context, toolCall) => const _ChartStub(),
      }, onUnknown: (context, toolCall) => const _FallbackStub());

      await pumpSurface(
        tester,
        Builder(
          builder: (context) => resolver.resolve(context, start('unknown')),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(_FallbackStub), findsOneWidget);
      expect(find.byType(UnknownGenerativeUI), findsNothing);
    });
  });
}

class _ChartStub extends StatelessWidget {
  const _ChartStub();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _FallbackStub extends StatelessWidget {
  const _FallbackStub();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
