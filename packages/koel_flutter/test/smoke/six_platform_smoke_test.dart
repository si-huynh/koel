// Six-platform smoke test (Story 6.7, NFR-11) — the first widget test the
// monorepo runs across multiple Flutter platforms in CI (macOS, Linux, Windows
// on the host flutter_tester; web via `flutter test --platform chrome`). It
// wires the full Flutter glue stack — KoelClientScope publishing a KoelClient →
// KoelChatController → an agent — over a minimal widget and asserts the streamed
// assistant turn renders, so a Dart-platform divergence (notably `dart:io`
// absent on web) surfaces immediately.
//
// Plain `flutter_test` on purpose (NOT `integration_test`): koel_flutter is a
// library package with no platform folders, where `integration_test` cannot run
// without per-lane `flutter create` + device infra. A pure-render smoke needs
// none of that — `flutter test` (host VM) and `flutter test --platform chrome`
// (dart2js + headless Chrome) prove compile + render + the native-vs-web/dart:io
// divergence that NFR-11 actually targets. See the story Completion Notes.
//
// The agent is a **local, web-safe** `AbstractAgent` (koel_core only). It must
// NOT use `MockAgent` from koel_test: `mock_agent.dart` imports `fixture_loader.
// dart`, which imports `dart:io` — that transitive import alone fails the
// dart2js web compile, defeating the web lane. koel_core and koel_flutter are
// `dart:io`-free, so importing only them keeps the web compile clean.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koel_core/koel_core.dart';
import 'package:koel_flutter/koel_flutter.dart';

/// A web-safe [AbstractAgent] that streams `"Hello world"` as **two**
/// `TEXT_MESSAGE_CONTENT` deltas — the same `RUN_STARTED → TEXT_MESSAGE_* →
/// RUN_FINISHED` shape as `test/support/test_agent.dart`'s `streamingHelloAgent`,
/// reproduced locally (no koel_test import) so the test compiles for web. Replay
/// is verbatim and ignores [input], exactly like the blessed `MockAgent`.
final class _HelloAgent implements AbstractAgent {
  const _HelloAgent();

  @override
  Stream<AgUiEvent> run(RunAgentInput input) async* {
    yield RunStartedEvent(threadId: 'smoke-thread', runId: 'smoke-run');
    yield TextMessageStartEvent(messageId: 'm1', role: 'assistant');
    yield TextMessageContentEvent(messageId: 'm1', delta: 'Hello');
    yield TextMessageContentEvent(messageId: 'm1', delta: ' world');
    yield TextMessageEndEvent(messageId: 'm1');
    yield RunFinishedEvent(threadId: 'smoke-thread', runId: 'smoke-run');
  }
}

/// The assistant text a UI renders from a [ChatState]: the in-flight
/// [ChatState.pendingMessage] while streaming, else the last committed assistant
/// turn. Mirrors `test/support/test_agent.dart`'s `assistantText`.
String _assistantText(ChatState s) {
  final pending = s.pendingMessage?.content;
  if (pending != null && pending.isNotEmpty) return pending;
  final committed = s.messages.where((m) => m.role == MessageRole.assistant);
  return committed.isEmpty ? '' : committed.last.content;
}

void main() {
  testWidgets('smoke: scope + controller + agent renders streamed turn', (
    tester,
  ) async {
    final client = KoelClient(agent: const _HelloAgent());
    final controller = KoelChatController(session: client.newSession());
    addTearDown(() {
      controller.dispose(); // controller-first, then the client it rides on
      client.dispose();
    });

    await tester.pumpWidget(
      KoelClientScope(
        client: client,
        child: MaterialApp(
          home: AnimatedBuilder(
            animation: controller,
            builder: (_, _) => Text(
              _assistantText(controller.state),
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
      ),
    );

    // Idle → send flips isStreaming synchronously → settle → text on screen,
    // back to idle (the observable contract, mirroring driveHello).
    expect(controller.isStreaming, isFalse);
    unawaited(controller.send('hi'));
    expect(controller.isStreaming, isTrue);
    await tester.pumpAndSettle();
    expect(find.textContaining('Hello world'), findsOneWidget);
    expect(controller.isStreaming, isFalse);
  });
}
