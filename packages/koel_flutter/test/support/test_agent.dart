import 'package:koel_core/koel_core.dart';
import 'package:koel_test/koel_test.dart';

/// A [MockAgent] that streams `"Hello world"` as **two** `TEXT_MESSAGE_CONTENT`
/// deltas, so a test can observe accumulation (`pendingMessage` goes
/// `'Hello'` → `'Hello world'`) and the `running` → `idle` phase transition on
/// `RUN_FINISHED`.
MockAgent streamingHelloAgent() => MockAgent.programmatic()
    .runStarted()
    .event(const TextMessageStartEvent(messageId: 'm1', role: 'assistant'))
    .event(const TextMessageContentEvent(messageId: 'm1', delta: 'Hello'))
    .event(const TextMessageContentEvent(messageId: 'm1', delta: ' world'))
    .event(const TextMessageEndEvent(messageId: 'm1'))
    .runFinished()
    .build();

/// The assistant text a UI renders from a [ChatState] snapshot: the in-flight
/// [ChatState.pendingMessage] while streaming, else the last committed assistant
/// turn. Shared by the widget integration tests so every framework asserts the
/// same observable string.
String assistantText(ChatState s) {
  final pending = s.pendingMessage?.content;
  if (pending != null && pending.isNotEmpty) return pending;
  final committed = s.messages.where((m) => m.role == MessageRole.assistant);
  return committed.isEmpty ? '' : committed.last.content;
}
