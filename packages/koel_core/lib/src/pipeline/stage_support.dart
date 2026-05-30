import 'dart:async';

import '../event/ag_ui_event.dart';

/// A stateful pipeline stage: handles one input event at a time (emitting zero
/// or more events via the sink) and optionally flushes trailing events when the
/// source completes. Subclasses hold per-subscription state as fields.
///
/// Internal to the pipeline — [buildStage] turns a fresh instance per
/// subscription into a [StreamTransformer]. Stages that are 1→{0,1} pure maps
/// (no completion flush) simply leave [onDone] at its empty default.
abstract class PipelineStage {
  /// Processes [event], emitting any synthesized/forwarded events to [out].
  void onEvent(AgUiEvent event, EventSink<AgUiEvent> out);

  /// Flushes any trailing events held in state when the source completes.
  void onDone(EventSink<AgUiEvent> out) {}
}

/// Wraps a per-subscription [PipelineStage] into a single-subscription,
/// cancellation- and backpressure-correct `StreamTransformer<AgUiEvent,
/// AgUiEvent>`.
///
/// [create] runs once per `listen`, so each subscription gets its own stage
/// instance with fresh state. The backing [StreamController] forwards the full
/// lifecycle to the upstream subscription — `pause`/`resume` propagate
/// backpressure (N-6), and `cancel` tears the upstream down deterministically
/// (no stranded cancel, unlike an `async*` `await for`). Upstream errors flow
/// straight through ([EventSink.addError]) — protocol *violations* surface as
/// `RunErrorEvent` values inside a stage, but a stream-borne *error* is the
/// interceptor chain's concern, not the pipeline's.
///
/// **Throw-guard (deferred-work #3).** A synchronous throw from [PipelineStage.onEvent]
/// or [PipelineStage.onDone] is converted to `controller.addError` and the
/// controller is closed — rather than escaping to the zone and leaving the
/// controller open, which would hang the downstream consumer forever. On an
/// `onEvent` throw the upstream subscription is also cancelled, so no further
/// event lands on the now-closed controller. The SDK's own stages
/// (`chunks`/`verify`/`transform`, identity `apply`) provably never throw, so
/// this is behavior-preserving for them; it backstops the consumer-supplied
/// reducer the `reducingApplyStage` runs.
StreamTransformer<AgUiEvent, AgUiEvent> buildStage(
  PipelineStage Function() create,
) {
  return StreamTransformer.fromBind((source) {
    final stage = create();
    late StreamSubscription<AgUiEvent> subscription;
    late StreamController<AgUiEvent> controller;
    controller = StreamController<AgUiEvent>(
      onListen: () {
        subscription = source.listen(
          (event) {
            try {
              stage.onEvent(event, controller);
            } catch (error, stack) {
              controller
                ..addError(error, stack)
                ..close();
              subscription.cancel();
            }
          },
          onError: controller.addError,
          onDone: () {
            try {
              stage.onDone(controller);
            } catch (error, stack) {
              controller.addError(error, stack);
            }
            controller.close();
          },
        );
      },
      onPause: () => subscription.pause(),
      onResume: () => subscription.resume(),
      onCancel: () => subscription.cancel(),
    );
    return controller.stream;
  });
}
