import 'dart:async';

import 'package:flutter/material.dart';
import 'package:koel_core/koel_core.dart' show KoelClient;
import 'package:koel_flutter/koel_flutter.dart' show KoelChatController;
import 'package:koel_test/koel_test.dart' show MockAgent;
import 'package:koel_widgets/koel_widgets.dart';

/// A deterministic agent replaying the `text_only_run` sequence verbatim
/// (RUN_STARTED → assistant "Hello, world!" → RUN_FINISHED).
///
/// This is the **programmatic** twin of `MockAgent.fromFixture('text_only_run')`,
/// chosen over the fixture loader because `FixtureLoader` resolves its asset via
/// `Isolate.resolvePackageUri` — a `dart:io`/VM-only path that throws under
/// `flutter test` (flutter_tester) and has no resolvable file in a compiled app.
/// The programmatic builder needs neither, so the demo runs identically under the
/// smoke test and a real `flutter run`. Same fixture→programmatic substitution
/// Stories 6.1 and 6.7 made for the same constraint.
MockAgent demoAgent() => MockAgent.programmatic()
    .runStarted()
    .textMessage('Hello, world!')
    .runFinished()
    .build();

/// Boots the demo.
void main() => runApp(const KoelWidgetsExampleApp());

/// The example's root: a themed [MaterialApp] hosting the chat surface.
///
/// Owns the **full lifecycle** of the [KoelClient] and [KoelChatController] it
/// creates — wired in [State.initState], torn down (controller then client) in
/// [State.dispose]. The reference therefore models correct ownership: the widget
/// that *creates* a controller is the one that disposes it, rather than a child
/// screen disposing an injected dependency it does not own.
class KoelWidgetsExampleApp extends StatefulWidget {
  /// Creates the demo app; it builds and owns its own controller and client.
  const KoelWidgetsExampleApp({super.key});

  @override
  State<KoelWidgetsExampleApp> createState() => _KoelWidgetsExampleAppState();
}

class _KoelWidgetsExampleAppState extends State<KoelWidgetsExampleApp> {
  late final KoelClient _client;
  late final KoelChatController _controller;

  @override
  void initState() {
    super.initState();
    _client = KoelClient(agent: demoAgent());
    _controller = KoelChatController(session: _client.newSession());
    // Kick off one turn so the demo opens on a live conversation; the fixture
    // ignores the prompt and always replays "Hello, world!".
    unawaited(_controller.send('Hello!'));
  }

  @override
  void dispose() {
    // This widget created both, so it disposes both: the controller first (it
    // only cancels its own listener), then the client (which closes every
    // session it minted, including the controller's).
    _controller.dispose();
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'koel_widgets example',
    debugShowCheckedModeBanner: false,
    // The single hook that themes every koel widget below.
    theme: ThemeData(extensions: [KoelTheme.light()]),
    home: _ChatScreen(controller: _controller),
  );
}

/// The chat screen — a message list over [KoelChatController.state], a row of
/// static follow-up suggestions, and the composer, all driving the one
/// controller. Does **not** own the controller's lifecycle:
/// [KoelWidgetsExampleApp] created it and disposes it.
class _ChatScreen extends StatelessWidget {
  const _ChatScreen({required this.controller});

  final KoelChatController controller;

  static const _suggestions = [
    'Tell me a joke',
    'Summarize this',
    'Show me code',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('koel_widgets')),
    body: ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final messages = controller.state.messages;
        return Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: MessageBubble(messages[i]),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: FollowUpList(
                suggestions: _suggestions,
                onSelected: controller.send,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: ChatInput(
                onSubmit: controller.send,
                placeholder: 'Message koel…',
              ),
            ),
          ],
        );
      },
    ),
  );
}
