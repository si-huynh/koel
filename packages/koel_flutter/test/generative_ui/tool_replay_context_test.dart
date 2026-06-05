import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koel_flutter/koel_flutter.dart';

void main() {
  group('of — replay path (AC4)', () {
    testWidgets('reads isReplaying == true under a replay scope', (
      tester,
    ) async {
      late final bool replaying;

      await tester.pumpWidget(
        ToolReplayContext(
          isReplaying: true,
          child: Builder(
            builder: (context) {
              replaying = ToolReplayContext.of(context).isReplaying;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(replaying, isTrue);
    });
  });

  group('of — live default, no ancestor (AC4)', () {
    testWidgets('returns isReplaying == false and does not throw', (
      tester,
    ) async {
      late final ToolReplayContext resolved;

      await tester.pumpWidget(
        Builder(
          builder: (context) {
            resolved = ToolReplayContext.of(context);
            return const SizedBox.shrink();
          },
        ),
      );

      expect(tester.takeException(), isNull);
      expect(resolved.isReplaying, isFalse);
    });
  });

  group('updateShouldNotify (AC4)', () {
    testWidgets('flipping isReplaying rebuilds dependents once; '
        're-publishing the same value rebuilds nothing', (tester) async {
      var builds = 0;
      late void Function(bool) setReplaying;

      await tester.pumpWidget(
        _Swapper(
          initial: false,
          register: (fn) => setReplaying = fn,
          child: Builder(
            builder: (context) {
              builds++;
              // Subscribing read: depend on the scope so a flip rebuilds us.
              context.dependOnInheritedWidgetOfExactType<ToolReplayContext>();
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      expect(builds, 1);

      // false → true → one dependent rebuild.
      setReplaying(true);
      await tester.pump();
      expect(builds, 2);

      // Re-publish the SAME value → updateShouldNotify false → no rebuild.
      setReplaying(true);
      await tester.pump();
      expect(builds, 2);
    });
  });
}

/// Hosts a [ToolReplayContext] whose `isReplaying` can be swapped via
/// [register]'s callback, so a test rebuilds the **scope** (not the descendant)
/// and observes `updateShouldNotify`-driven dependent rebuilds.
class _Swapper extends StatefulWidget {
  const _Swapper({
    required this.initial,
    required this.register,
    required this.child,
  });

  final bool initial;
  final void Function(void Function(bool)) register;
  final Widget child;

  @override
  State<_Swapper> createState() => _SwapperState();
}

class _SwapperState extends State<_Swapper> {
  late bool _replaying = widget.initial;

  @override
  void initState() {
    super.initState();
    widget.register((next) => setState(() => _replaying = next));
  }

  @override
  Widget build(BuildContext context) =>
      ToolReplayContext(isReplaying: _replaying, child: widget.child);
}
