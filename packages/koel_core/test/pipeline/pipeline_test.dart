import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:koel_core/src/error/koel_error.dart';
import 'package:koel_core/src/error/koel_error_code.dart';
import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/json_patch/json_patch_op.dart';
import 'package:koel_core/src/pipeline/apply_stage.dart';
import 'package:koel_core/src/pipeline/chunks_stage.dart';
import 'package:koel_core/src/pipeline/pipeline.dart';
import 'package:koel_core/src/pipeline/transform_stage.dart';
import 'package:koel_core/src/pipeline/verify_stage.dart';
import 'package:test/test.dart';

Future<List<AgUiEvent>> _pipe(List<AgUiEvent> input) =>
    runPipeline(Stream<AgUiEvent>.fromIterable(input)).toList();

/// One canonical instance of every AG-UI event family, wired so chunk sequences
/// are self-contained and every verify rule passes — the AC4 happy-path sweep.
List<AgUiEvent> _validSweep() {
  final bytes = Uint8List.fromList([1, 2, 3, 250]);
  return [
    const RunStartedEvent(threadId: 't', runId: 'r'),
    const StepStartedEvent(stepName: 's'),
    const StepFinishedEvent(stepName: 's'),
    const TextMessageStartEvent(messageId: 'm1', role: 'assistant'),
    const TextMessageContentEvent(messageId: 'm1', delta: 'hi'),
    const TextMessageEndEvent(messageId: 'm1'),
    const TextMessageChunkEvent(
      messageId: 'm2',
      role: 'assistant',
      delta: 'he',
    ),
    const TextMessageChunkEvent(messageId: 'm2', delta: 'llo'),
    const ToolCallStartEvent(toolCallId: 'c1', toolCallName: 'search'),
    const ToolCallArgsEvent(toolCallId: 'c1', delta: '{}'),
    const ToolCallEndEvent(toolCallId: 'c1'),
    const ToolCallChunkEvent(
      toolCallId: 'c2',
      toolCallName: 'lookup',
      delta: '{',
    ),
    const ToolCallChunkEvent(toolCallId: 'c2', delta: '}'),
    const ToolCallResultEvent(messageId: 'mr', toolCallId: 'c1', content: 'ok'),
    const StateSnapshotEvent(state: {'count': 1}),
    const StateDeltaEvent(patches: [ReplaceOp(path: '/count', value: 2)]),
    const MessagesSnapshotEvent(messages: []),
    const ActivitySnapshotEvent(
      messageId: 'a1',
      activityType: 'checklist',
      content: {},
    ),
    const ActivityDeltaEvent(
      messageId: 'a1',
      activityType: 'checklist',
      patches: [AddOp(path: '/done', value: true)],
    ),
    const ReasoningStartEvent(messageId: 'r1'),
    const ReasoningMessageStartEvent(messageId: 'r1', role: 'reasoning'),
    const ReasoningMessageContentEvent(messageId: 'r1', delta: 'because'),
    const ReasoningMessageEndEvent(messageId: 'r1'),
    const ReasoningMessageChunkEvent(messageId: 'r2', delta: 'd'),
    ReasoningEncryptedValueEvent(
      entityId: 'e',
      subtype: 'message',
      encryptedValue: bytes,
      encryptedValueBase64: base64Encode(bytes),
    ),
    const ReasoningEndEvent(messageId: 'r1'),
    const RawEvent(payload: {'k': 1}, source: 'acme'),
    const CustomEvent(name: 'predictive_state', value: {'x': 1}),
    RunErrorEvent(
      error: AgentError(message: 'boom', code: KoelErrorCode.unknown),
    ),
    const RunFinishedEvent(threadId: 't', runId: 'r'),
  ];
}

void main() {
  group('runPipeline — composition', () {
    test(
      'a tool-call chunk sequence emerges as a canonical triplet, no errors',
      () async {
        final out = await _pipe([
          const ToolCallChunkEvent(
            toolCallId: 'a',
            toolCallName: 'search',
            delta: '{',
          ),
          const ToolCallChunkEvent(toolCallId: 'a', delta: '}'),
        ]);
        expect(out, [
          const ToolCallStartEvent(toolCallId: 'a', toolCallName: 'search'),
          const ToolCallArgsEvent(toolCallId: 'a', delta: '{'),
          const ToolCallArgsEvent(toolCallId: 'a', delta: '}'),
          const ToolCallEndEvent(toolCallId: 'a'),
        ]);
        expect(out.whereType<RunErrorEvent>(), isEmpty);
      },
    );

    test('apply and transform are pass-throughs (identity) today', () async {
      // A stream with no chunks and no verify violations must emerge byte-equal.
      final input = [
        const RunStartedEvent(threadId: 't', runId: 'r'),
        const StateSnapshotEvent(state: {'k': 1}),
        const RunFinishedEvent(threadId: 't', runId: 'r'),
      ];
      expect(await _pipe(input), input);
    });
  });

  group('runPipeline — full 28-family sweep (AC4)', () {
    test(
      'every family flows through to canonical events; verify adds no errors',
      () async {
        final out = await _pipe(_validSweep());

        // No raw chunk shapes survive — chunks synthesized them away.
        expect(out.whereType<ToolCallChunkEvent>(), isEmpty);
        expect(out.whereType<TextMessageChunkEvent>(), isEmpty);
        expect(out.whereType<ReasoningMessageChunkEvent>(), isEmpty);

        // The only RunErrorEvent is the one fed in — verify introduced none.
        expect(out.whereType<RunErrorEvent>(), hasLength(1));

        // Chunk synthesis actually ran inside the pipeline.
        expect(
          out.whereType<ToolCallStartEvent>().map((e) => e.toolCallId),
          containsAll(<String>['c1', 'c2']),
        );
        expect(
          out.whereType<TextMessageStartEvent>().map((e) => e.messageId),
          containsAll(<String>['m1', 'm2']),
        );
        // 'r1' is a real reasoning message; 'r2' was synthesized from a chunk.
        expect(
          out.whereType<ReasoningMessageStartEvent>().map((e) => e.messageId),
          containsAll(<String>['r1', 'r2']),
        );
      },
    );
  });

  group('runPipeline — stage order is locked', () {
    test('chunks must precede verify: verify validates synthesized events', () async {
      // An empty-messageId TEXT_MESSAGE_CHUNK: chunks synthesizes an empty-id
      // START/CONTENT/END triplet, which verify then rejects (empty messageId).
      final input = [const TextMessageChunkEvent(messageId: '', delta: 'x')];

      // Correct order (chunks → verify): the synthesized triplet is validated,
      // so all three empty-id events become ProtocolErrors.
      final correct = await _pipe(input);
      expect(correct.whereType<RunErrorEvent>(), hasLength(3));

      // Swapped order (verify → chunks): verify runs first and has no rule for a
      // raw *_CHUNK, so it passes; chunks then synthesizes the (now unvalidated)
      // triplet. Zero errors — observably different, proving the order matters.
      final swapped = await Stream<AgUiEvent>.fromIterable(input)
          .transform(verifyStage)
          .transform(chunksStage)
          .transform(applyStage)
          .transform(transformStage)
          .toList();
      expect(swapped.whereType<RunErrorEvent>(), isEmpty);
      expect(correct, isNot(swapped));
    });
  });

  group('runPipeline — degenerate inputs', () {
    test(
      'a null-id chunk is dropped and an empty STATE_DELTA errors',
      () async {
        final out = await _pipe([
          const ToolCallChunkEvent(toolCallId: null, delta: 'noise'),
          const StateDeltaEvent(patches: []),
        ]);
        expect(out, hasLength(1));
        final error = out.single;
        expect(error, isA<RunErrorEvent>());
        expect((error as RunErrorEvent).error, isA<ProtocolError>());
        expect((error.error as ProtocolError).eventType, 'STATE_DELTA');
      },
    );

    test('an empty input stream completes with no events', () async {
      expect(await _pipe([]), isEmpty);
    });
  });

  group('runPipeline — lifecycle', () {
    test('cancellation tears down the whole chain', () async {
      var upstreamCancelled = false;
      final controller = StreamController<AgUiEvent>(
        onCancel: () => upstreamCancelled = true,
      );
      final received = <AgUiEvent>[];
      final sub = runPipeline(controller.stream).listen(received.add);

      controller.add(const RunStartedEvent(threadId: 't', runId: 'r'));
      await pumpEventQueue();
      await sub.cancel();
      controller.add(const RunFinishedEvent(threadId: 't', runId: 'r'));
      await pumpEventQueue();

      expect(received, [const RunStartedEvent(threadId: 't', runId: 'r')]);
      expect(upstreamCancelled, isTrue);
    });
  });
}
