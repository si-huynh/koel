import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_flutter/koel_flutter.dart';

import 'package:provider/provider.dart' as provider;
import 'package:flutter_bloc/flutter_bloc.dart' as bloc;
import 'package:flutter_riverpod/flutter_riverpod.dart' as riverpod;
import 'package:get/get.dart' as getx;

import '../support/test_agent.dart';

/// Drives the same observable contract against whatever host widget a framework
/// builds: idle → `send` flips `isStreaming` true synchronously → after the run
/// settles, `isStreaming` is false and the streamed assistant text is on screen.
/// The single source of truth is the **unmodified** [KoelChatController] — every
/// framework reaches it through its own `Listenable` bridge, none touches the
/// controller's code (FR-D4).
Future<void> driveHello(WidgetTester tester, KoelChatController c) async {
  expect(c.isStreaming, isFalse);
  unawaited(c.send('hi'));
  expect(c.isStreaming, isTrue);
  await tester.pumpAndSettle();
  expect(c.isStreaming, isFalse);
  expect(find.textContaining('Hello world'), findsOneWidget);
}

void main() {
  // Wiring whose controller the *test* owns (manual dispose, controller-first).
  KoelChatController wireOwned() {
    final client = KoelClient(agent: streamingHelloAgent());
    final controller = KoelChatController(session: client.newSession());
    addTearDown(() {
      controller.dispose();
      client.dispose();
    });
    return controller;
  }

  // AC3 — provider's ChangeNotifierProvider + an AnimatedBuilder listening to it,
  // including the explicit false→true→false streaming transition.
  testWidgets('provider: ChangeNotifierProvider + AnimatedBuilder', (
    tester,
  ) async {
    final controller = wireOwned();
    await tester.pumpWidget(
      provider.ChangeNotifierProvider<KoelChatController>.value(
        value: controller,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              final c = provider.Provider.of<KoelChatController>(
                context,
                listen: false,
              );
              return AnimatedBuilder(
                animation: c,
                builder: (_, _) => Text(
                  assistantText(c.state),
                  textDirection: TextDirection.ltr,
                ),
              );
            },
          ),
        ),
      ),
    );
    await driveHello(tester, controller);
  });

  // AC4 — Bloc via a BlocProvider.value adapter. BlocProvider needs a BlocBase,
  // and provider's debug guard rejects a raw ChangeNotifier in a plain Provider,
  // so a ~6-line external Cubit mirrors controller state into Bloc — the
  // controller itself stays untouched (the "adapter" the AC names).
  testWidgets('bloc: BlocProvider.value (Cubit adapter)', (tester) async {
    final controller = wireOwned();
    final adapter = _ControllerCubit(controller);
    addTearDown(adapter.close);

    await tester.pumpWidget(
      bloc.BlocProvider<_ControllerCubit>.value(
        value: adapter,
        child: MaterialApp(
          home: bloc.BlocBuilder<_ControllerCubit, ChatState>(
            builder: (context, state) =>
                Text(assistantText(state), textDirection: TextDirection.ltr),
          ),
        ),
      ),
    );
    await driveHello(tester, controller);
  });

  // AC4 — Riverpod via its ChangeNotifierProvider, which both provides and
  // listens. It takes ownership (disposes the notifier when the scope unmounts),
  // so the test does NOT manually dispose the controller here.
  testWidgets('riverpod: ChangeNotifierProvider', (tester) async {
    final client = KoelClient(agent: streamingHelloAgent());
    final controller = KoelChatController(session: client.newSession());
    addTearDown(client.dispose); // riverpod owns the controller's dispose
    final ctlProvider = riverpod.ChangeNotifierProvider<KoelChatController>(
      (ref) => controller,
    );

    await tester.pumpWidget(
      riverpod.ProviderScope(
        child: MaterialApp(
          home: riverpod.Consumer(
            builder: (context, ref, _) {
              final c = ref.watch(ctlProvider);
              return Text(
                assistantText(c.state),
                textDirection: TextDirection.ltr,
              );
            },
          ),
        ),
      ),
    );
    await driveHello(tester, controller);
  });

  // AC4 — GetX: Get.put for DI, AnimatedBuilder for reactivity over the plain
  // Listenable. Get.reset clears the registry afterward.
  testWidgets('getx: Get.put', (tester) async {
    final controller = wireOwned();
    final c = getx.Get.put(controller);
    addTearDown(getx.Get.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: c,
          builder: (_, _) =>
              Text(assistantText(c.state), textDirection: TextDirection.ltr),
        ),
      ),
    );
    await driveHello(tester, controller);
  });

  // AC4 — plain setState: a StatefulWidget subscribing in initState. The truest
  // "no framework at all" path.
  testWidgets('setState: addListener → setState', (tester) async {
    final controller = wireOwned();
    await tester.pumpWidget(MaterialApp(home: _SetStateHost(controller)));
    await driveHello(tester, controller);
  });
}

/// Minimal external adapter: mirrors [KoelChatController] state into a Bloc
/// [bloc.Cubit] so it can be provided via `BlocProvider.value`. The controller
/// is not modified — this lives entirely outside it.
class _ControllerCubit extends bloc.Cubit<ChatState> {
  _ControllerCubit(this._controller) : super(_controller.state) {
    _controller.addListener(_sync);
  }

  final KoelChatController _controller;

  void _sync() => emit(_controller.state);

  @override
  Future<void> close() {
    _controller.removeListener(_sync);
    return super.close();
  }
}

class _SetStateHost extends StatefulWidget {
  const _SetStateHost(this.controller);

  final KoelChatController controller;

  @override
  State<_SetStateHost> createState() => _SetStateHostState();
}

class _SetStateHostState extends State<_SetStateHost> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) => Text(
    assistantText(widget.controller.state),
    textDirection: TextDirection.ltr,
  );
}
