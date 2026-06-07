import 'dart:async';

import 'package:flutter/material.dart';
// The quickstart barrel: KoelClient + KoelChatController + KoelClientScope (and
// HttpAgent for the README swap) all arrive through this single import — the
// path this example exists to showcase. Widgets are NOT re-exported by the meta,
// so they come from their own package below (architecture §2:512-514, D1).
import 'package:koel/koel.dart'
    show KoelChatController, KoelClient, KoelClientScope;
import 'package:koel_test/koel_test.dart' show MockAgent;
import 'package:koel_widgets/koel_widgets.dart';

/// Boots the demo.
void main() => runApp(const KoelExampleApp());

/// A deterministic offline agent replaying the `text_only_run` sequence verbatim
/// (RUN_STARTED → assistant "Hello, world!" → RUN_FINISHED).
///
/// This is the **programmatic** twin of `MockAgent.fromFixture('text_only_run')`:
/// the fixture loader resolves its asset via `Isolate.resolvePackageUri`, a
/// `dart:io`/VM-only path that throws under `flutter test`/`flutter run`/
/// `flutter build` and has no resolvable file in a compiled app. The programmatic
/// builder needs neither, so the demo runs identically under the smoke test and a
/// real `flutter run` on every platform. (Stories 6.1, 6.7, and 7.4 made this
/// exact substitution for the same constraint.) The agent is reusable across
/// runs, so each `send` replays the same canned reply — a fixed-script mock
/// artifact, resolved by swapping in a real backend (see README).
MockAgent _demoAgent() => MockAgent.programmatic()
    .runStarted()
    .textMessage('Hello, world!')
    .runFinished()
    .build();

/// The example root: a themed [MaterialApp] under a [KoelClientScope], hosting
/// the chat surface.
///
/// Owns the **full lifecycle** of the [KoelClient] and [KoelChatController] it
/// creates — wired in [State.initState], torn down (controller then client) in
/// [State.dispose]. The widget that *creates* a controller is the one that
/// disposes it; a child screen never disposes an injected dependency it does not
/// own. This is the correct-ownership reference.
class KoelExampleApp extends StatefulWidget {
  /// Creates the demo app; it builds and owns its own client and controller.
  const KoelExampleApp({super.key});

  @override
  State<KoelExampleApp> createState() => _KoelExampleAppState();
}

class _KoelExampleAppState extends State<KoelExampleApp> {
  late final KoelClient _client;
  late final KoelChatController _controller;

  @override
  void initState() {
    super.initState();
    _client = KoelClient(agent: _demoAgent());
    _controller = KoelChatController(session: _client.newSession());
    // Open on a live conversation; the mock ignores the prompt and always
    // replays "Hello, world!".
    unawaited(_controller.send('Hello!'));
  }

  @override
  void dispose() {
    // This widget created both, so it disposes both: the controller first (it
    // only cancels its own listener), then the client (which closes every
    // session it minted, including the controller's). LIFO.
    _controller.dispose();
    _client.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => KoelClientScope(
    client: _client,
    // KoelClientScope exposes the client to any deeper widget that needs ambient
    // access (KoelClientScope.of(context)); this small demo also passes the
    // controller down directly.
    child: MaterialApp(
      title: 'koel example',
      debugShowCheckedModeBanner: false,
      // The single hook that themes every koel widget below.
      theme: ThemeData(extensions: [KoelTheme.light()]),
      home: _ChatScreen(controller: _controller),
    ),
  );
}

/// The chat screen — a message list over [KoelChatController.state], a row of
/// generic follow-up suggestions, and the composer, all driving the one
/// controller. Does **not** own the controller's lifecycle: [KoelExampleApp]
/// created it and disposes it.
class _ChatScreen extends StatelessWidget {
  const _ChatScreen({required this.controller});

  final KoelChatController controller;

  // Generic chat, zero business domain (AR-22 / PRD §13 D-5).
  static const _suggestions = [
    'Tell me a joke',
    'Show me code',
    'Summarize this',
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('koel')),
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
