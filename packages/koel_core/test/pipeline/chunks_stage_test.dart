import 'dart:async';

import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/pipeline/chunks_stage.dart';
import 'package:test/test.dart';

Future<List<AgUiEvent>> _synthesize(List<AgUiEvent> input) =>
    Stream<AgUiEvent>.fromIterable(input).transform(chunksStage).toList();

void main() {
  group('chunksStage — tool-call synthesis (F.2)', () {
    test(
      'a lone id-only chunk synthesizes START then END on completion',
      () async {
        final out = await _synthesize([
          const ToolCallChunkEvent(toolCallId: 'a', toolCallName: 'search'),
        ]);
        expect(out, [
          const ToolCallStartEvent(toolCallId: 'a', toolCallName: 'search'),
          const ToolCallEndEvent(toolCallId: 'a'),
        ]);
      },
    );

    test(
      'a first chunk carrying a delta emits START then ARGS (no data lost)',
      () async {
        final out = await _synthesize([
          const ToolCallChunkEvent(
            toolCallId: 'a',
            toolCallName: 'search',
            delta: '{',
          ),
        ]);
        expect(out, [
          const ToolCallStartEvent(toolCallId: 'a', toolCallName: 'search'),
          const ToolCallArgsEvent(toolCallId: 'a', delta: '{'),
          const ToolCallEndEvent(toolCallId: 'a'),
        ]);
      },
    );

    test('subsequent chunks for the same id become ARGS deltas', () async {
      final out = await _synthesize([
        const ToolCallChunkEvent(
          toolCallId: 'a',
          toolCallName: 'search',
          delta: '{',
        ),
        const ToolCallChunkEvent(toolCallId: 'a', delta: '"q"'),
        const ToolCallChunkEvent(toolCallId: 'a', delta: '}'),
      ]);
      expect(out, [
        const ToolCallStartEvent(toolCallId: 'a', toolCallName: 'search'),
        const ToolCallArgsEvent(toolCallId: 'a', delta: '{'),
        const ToolCallArgsEvent(toolCallId: 'a', delta: '"q"'),
        const ToolCallArgsEvent(toolCallId: 'a', delta: '}'),
        const ToolCallEndEvent(toolCallId: 'a'),
      ]);
    });

    test(
      'a non-chunk event flushes the open END before passing through',
      () async {
        final out = await _synthesize([
          const ToolCallChunkEvent(toolCallId: 'a', toolCallName: 'search'),
          const RunFinishedEvent(threadId: 't', runId: 'r'),
        ]);
        expect(out, [
          const ToolCallStartEvent(toolCallId: 'a', toolCallName: 'search'),
          const ToolCallEndEvent(toolCallId: 'a'),
          const RunFinishedEvent(threadId: 't', runId: 'r'),
        ]);
      },
    );

    test('a chunk for a new id closes the previous tool call first', () async {
      final out = await _synthesize([
        const ToolCallChunkEvent(toolCallId: 'a', toolCallName: 'search'),
        const ToolCallChunkEvent(toolCallId: 'b', toolCallName: 'lookup'),
      ]);
      expect(out, [
        const ToolCallStartEvent(toolCallId: 'a', toolCallName: 'search'),
        const ToolCallEndEvent(toolCallId: 'a'),
        const ToolCallStartEvent(toolCallId: 'b', toolCallName: 'lookup'),
        const ToolCallEndEvent(toolCallId: 'b'),
      ]);
    });

    test(
      'a null-id chunk is dropped and leaves the open envelope intact',
      () async {
        final out = await _synthesize([
          const ToolCallChunkEvent(toolCallId: 'a', toolCallName: 'search'),
          const ToolCallChunkEvent(toolCallId: null, delta: 'noise'),
          const ToolCallChunkEvent(toolCallId: 'a', delta: 'y'),
        ]);
        expect(out, [
          const ToolCallStartEvent(toolCallId: 'a', toolCallName: 'search'),
          const ToolCallArgsEvent(toolCallId: 'a', delta: 'y'),
          const ToolCallEndEvent(toolCallId: 'a'),
        ]);
      },
    );

    test(
      'a missing toolCallName defaults to empty on the synthesized START',
      () async {
        final out = await _synthesize([
          const ToolCallChunkEvent(toolCallId: 'a'),
        ]);
        expect(out, [
          const ToolCallStartEvent(toolCallId: 'a', toolCallName: ''),
          const ToolCallEndEvent(toolCallId: 'a'),
        ]);
      },
    );
  });

  group('chunksStage — text-message synthesis (F.2)', () {
    test('a chunk with role + delta becomes START / CONTENT / END', () async {
      final out = await _synthesize([
        const TextMessageChunkEvent(
          messageId: 'm',
          role: 'assistant',
          delta: 'hi',
        ),
      ]);
      expect(out, [
        const TextMessageStartEvent(messageId: 'm', role: 'assistant'),
        const TextMessageContentEvent(messageId: 'm', delta: 'hi'),
        const TextMessageEndEvent(messageId: 'm'),
      ]);
    });

    test('a missing role defaults to assistant', () async {
      final out = await _synthesize([
        const TextMessageChunkEvent(messageId: 'm', delta: 'hi'),
      ]);
      expect(out, [
        const TextMessageStartEvent(messageId: 'm', role: 'assistant'),
        const TextMessageContentEvent(messageId: 'm', delta: 'hi'),
        const TextMessageEndEvent(messageId: 'm'),
      ]);
    });

    test('a null-id text chunk is dropped', () async {
      final out = await _synthesize([
        const TextMessageChunkEvent(messageId: null, delta: 'x'),
      ]);
      expect(out, isEmpty);
    });

    test(
      'a chunk for a new messageId closes the previous message first',
      () async {
        final out = await _synthesize([
          const TextMessageChunkEvent(messageId: 'm', delta: 'a'),
          const TextMessageChunkEvent(messageId: 'n', delta: 'b'),
        ]);
        expect(out, [
          const TextMessageStartEvent(messageId: 'm', role: 'assistant'),
          const TextMessageContentEvent(messageId: 'm', delta: 'a'),
          const TextMessageEndEvent(messageId: 'm'),
          const TextMessageStartEvent(messageId: 'n', role: 'assistant'),
          const TextMessageContentEvent(messageId: 'n', delta: 'b'),
          const TextMessageEndEvent(messageId: 'n'),
        ]);
      },
    );
  });

  group('chunksStage — reasoning-message synthesis (F.2)', () {
    test('a reasoning chunk becomes START / CONTENT / END', () async {
      final out = await _synthesize([
        const ReasoningMessageChunkEvent(messageId: 'r', delta: 'because'),
      ]);
      expect(out, [
        const ReasoningMessageStartEvent(messageId: 'r', role: 'reasoning'),
        const ReasoningMessageContentEvent(messageId: 'r', delta: 'because'),
        const ReasoningMessageEndEvent(messageId: 'r'),
      ]);
    });

    test('a null-id reasoning chunk is dropped', () async {
      final out = await _synthesize([
        const ReasoningMessageChunkEvent(messageId: null, delta: 'x'),
      ]);
      expect(out, isEmpty);
    });

    test(
      'a chunk for a new reasoning messageId closes the previous one first',
      () async {
        final out = await _synthesize([
          const ReasoningMessageChunkEvent(messageId: 'r', delta: 'a'),
          const ReasoningMessageChunkEvent(messageId: 's', delta: 'b'),
        ]);
        expect(out, [
          const ReasoningMessageStartEvent(messageId: 'r', role: 'reasoning'),
          const ReasoningMessageContentEvent(messageId: 'r', delta: 'a'),
          const ReasoningMessageEndEvent(messageId: 'r'),
          const ReasoningMessageStartEvent(messageId: 's', role: 'reasoning'),
          const ReasoningMessageContentEvent(messageId: 's', delta: 'b'),
          const ReasoningMessageEndEvent(messageId: 's'),
        ]);
      },
    );
  });

  group('chunksStage — passthrough + interleaving', () {
    test('non-chunk events pass through unchanged', () async {
      final out = await _synthesize([
        const RunStartedEvent(threadId: 't', runId: 'r'),
        const StepStartedEvent(stepName: 's'),
      ]);
      expect(out, [
        const RunStartedEvent(threadId: 't', runId: 'r'),
        const StepStartedEvent(stepName: 's'),
      ]);
    });

    test('a tool-call and a text-message envelope can be open at once', () async {
      final out = await _synthesize([
        const ToolCallChunkEvent(toolCallId: 'a', toolCallName: 'search'),
        const TextMessageChunkEvent(messageId: 'm', delta: 'hi'),
      ]);
      // The text chunk does NOT close the tool envelope (independent namespaces);
      // both flush on completion, tool first.
      expect(out, [
        const ToolCallStartEvent(toolCallId: 'a', toolCallName: 'search'),
        const TextMessageStartEvent(messageId: 'm', role: 'assistant'),
        const TextMessageContentEvent(messageId: 'm', delta: 'hi'),
        const ToolCallEndEvent(toolCallId: 'a'),
        const TextMessageEndEvent(messageId: 'm'),
      ]);
    });

    test(
      'tool-call, text-message, and reasoning envelopes are all independent',
      () async {
        final out = await _synthesize([
          const ToolCallChunkEvent(toolCallId: 'a', toolCallName: 'search'),
          const TextMessageChunkEvent(messageId: 'm', delta: 'hi'),
          const ReasoningMessageChunkEvent(messageId: 'r', delta: 'why'),
        ]);
        // None of the three chunks closes another's envelope; all flush on
        // completion in open order (tool, text, reasoning).
        expect(out, [
          const ToolCallStartEvent(toolCallId: 'a', toolCallName: 'search'),
          const TextMessageStartEvent(messageId: 'm', role: 'assistant'),
          const TextMessageContentEvent(messageId: 'm', delta: 'hi'),
          const ReasoningMessageStartEvent(messageId: 'r', role: 'reasoning'),
          const ReasoningMessageContentEvent(messageId: 'r', delta: 'why'),
          const ToolCallEndEvent(toolCallId: 'a'),
          const TextMessageEndEvent(messageId: 'm'),
          const ReasoningMessageEndEvent(messageId: 'r'),
        ]);
      },
    );

    test('an empty stream yields nothing', () async {
      expect(await _synthesize([]), isEmpty);
    });
  });

  group('chunksStage — lifecycle', () {
    test('cancellation mid-stream stops emission and cancels upstream', () async {
      var upstreamCancelled = false;
      final controller = StreamController<AgUiEvent>(
        onCancel: () => upstreamCancelled = true,
      );
      final received = <AgUiEvent>[];
      final sub = controller.stream.transform(chunksStage).listen(received.add);

      controller.add(const RunStartedEvent(threadId: 't', runId: 'r'));
      await pumpEventQueue();
      await sub.cancel();
      // An event added after cancel must not surface; upstream must be cancelled.
      controller.add(const RunFinishedEvent(threadId: 't', runId: 'r'));
      await pumpEventQueue();

      expect(received, [const RunStartedEvent(threadId: 't', runId: 'r')]);
      expect(upstreamCancelled, isTrue);
    });

    test('pause/resume propagate to upstream (backpressure, N-6)', () async {
      var upstreamPaused = false;
      final controller = StreamController<AgUiEvent>(
        onPause: () => upstreamPaused = true,
        onResume: () => upstreamPaused = false,
      );
      final sub = controller.stream.transform(chunksStage).listen((_) {});

      controller.add(const RunStartedEvent(threadId: 't', runId: 'r'));
      await pumpEventQueue();
      sub.pause();
      await pumpEventQueue();
      expect(upstreamPaused, isTrue);
      sub.resume();
      await pumpEventQueue();
      expect(upstreamPaused, isFalse);
      await sub.cancel();
    });
  });
}
