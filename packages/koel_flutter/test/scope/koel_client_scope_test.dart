import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_flutter/koel_flutter.dart';

import '../support/test_agent.dart';

void main() {
  // A real, disposable client to publish. The scope never disposes it (it does
  // not own it), so the test owns the teardown.
  KoelClient newClient() {
    final client = KoelClient(agent: streamingHelloAgent());
    addTearDown(client.dispose);
    return client;
  }

  group('of(context) — AC2', () {
    testWidgets('resolves the nearest ancestor scope\'s client', (
      tester,
    ) async {
      final client = newClient();
      late final KoelClient resolved;

      await tester.pumpWidget(
        KoelClientScope(
          client: client,
          child: Builder(
            builder: (context) {
              resolved = KoelClientScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(identical(resolved, client), isTrue);
    });
  });

  group('updateShouldNotify — AC3', () {
    testWidgets('swapping to a different client rebuilds dependents exactly '
        'once; the same client does not rebuild', (tester) async {
      final clientA = newClient();
      final clientB = newClient();

      var builds = 0;
      KoelClient? seen;
      late void Function(KoelClient) swap;

      await tester.pumpWidget(
        _Swapper(
          initial: clientA,
          register: (fn) => swap = fn,
          child: Builder(
            builder: (context) {
              builds++;
              seen = KoelClientScope.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(builds, 1);
      expect(identical(seen, clientA), isTrue);

      // Swap to a DIFFERENT instance → updateShouldNotify true → exactly one
      // dependent rebuild.
      swap(clientB);
      await tester.pump();
      expect(builds, 2);
      expect(identical(seen, clientB), isTrue);

      // Re-publish the SAME instance → updateShouldNotify false → no rebuild.
      swap(clientB);
      await tester.pump();
      expect(builds, 2);
    });
  });

  group('of(context) with no ancestor — AC4', () {
    testWidgets('throws a remediating FlutterError', (tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            KoelClientScope.of(context);
            return const SizedBox();
          },
        ),
      );

      final error = tester.takeException();
      expect(error, isA<FlutterError>());
      expect(
        error.toString(),
        allOf(contains('KoelClientScope'), contains('Wrap your app')),
      );
    });
  });
}

/// Hosts a [KoelClientScope] whose `client` can be swapped via [register]'s
/// callback, so a test can rebuild the **scope** (not the descendant) with a new
/// client and observe `updateShouldNotify`-driven dependent rebuilds.
class _Swapper extends StatefulWidget {
  const _Swapper({
    required this.initial,
    required this.register,
    required this.child,
  });

  final KoelClient initial;
  final void Function(void Function(KoelClient)) register;
  final Widget child;

  @override
  State<_Swapper> createState() => _SwapperState();
}

class _SwapperState extends State<_Swapper> {
  late KoelClient _client = widget.initial;

  @override
  void initState() {
    super.initState();
    widget.register((next) => setState(() => _client = next));
  }

  @override
  Widget build(BuildContext context) =>
      KoelClientScope(client: _client, child: widget.child);
}
