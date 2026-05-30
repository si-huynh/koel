import 'dart:async';

import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/pipeline/stage_support.dart';
import 'package:test/test.dart';

// Throws synchronously from onEvent — the consumer-supplied-reducer hazard the
// buildStage guard backstops (deferred-work #2).
class _ThrowOnEventStage extends PipelineStage {
  @override
  void onEvent(AgUiEvent event, EventSink<AgUiEvent> out) =>
      throw StateError('event boom');
}

// Passes events through, then throws from the completion flush.
class _ThrowOnDoneStage extends PipelineStage {
  @override
  void onEvent(AgUiEvent event, EventSink<AgUiEvent> out) => out.add(event);

  @override
  void onDone(EventSink<AgUiEvent> out) => throw StateError('done boom');
}

const _started = RunStartedEvent(threadId: 't', runId: 'r');
const _finished = RunFinishedEvent(threadId: 't', runId: 'r');

void main() {
  group('buildStage — throw-guard (deferred #2)', () {
    test(
      'an onEvent throw surfaces as a stream error then closes (no hang)',
      () async {
        final out = Stream<AgUiEvent>.fromIterable(const [
          _started,
          _finished,
        ]).transform(buildStage(_ThrowOnEventStage.new));

        // The throw becomes addError + close — the controller does not stay open
        // and hang the consumer.
        await expectLater(
          out,
          emitsInOrder([emitsError(isStateError), emitsDone]),
        );
      },
    );

    test(
      'an onDone throw surfaces as a stream error after the passed-through events',
      () async {
        final out = Stream<AgUiEvent>.fromIterable(const [
          _started,
        ]).transform(buildStage(_ThrowOnDoneStage.new));

        await expectLater(
          out,
          emitsInOrder([_started, emitsError(isStateError), emitsDone]),
        );
      },
    );
  });
}
