part of 'ag_ui_event.dart';

/// `STEP_STARTED` — the agent entered a named step within a run (a tool phase, a
/// planning stage, …). Brackets the step with [StepFinishedEvent].
@freezed
abstract class StepStartedEvent extends AgUiEvent with _$StepStartedEvent {
  const StepStartedEvent._() : super();

  /// Constructs a `STEP_STARTED` event naming the entered [stepName].
  const factory StepStartedEvent({required String stepName}) =
      _StepStartedEvent;

  /// Decodes a `STEP_STARTED` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `stepName` is absent.
  static StepStartedEvent fromJson(Map<String, dynamic> json) =>
      StepStartedEvent(stepName: _requireString(json, 'stepName'));

  /// Serializes to the `STEP_STARTED` wire shape.
  Map<String, dynamic> toJson() => {
    'type': 'STEP_STARTED',
    'stepName': stepName,
  };
}

/// `STEP_FINISHED` — the agent left the named step. Its [stepName] must match
/// the prior [StepStartedEvent]; that cross-event pairing invariant is enforced
/// by the verify pipeline stage in Story 2.11, not by this transient value.
@freezed
abstract class StepFinishedEvent extends AgUiEvent with _$StepFinishedEvent {
  const StepFinishedEvent._() : super();

  /// Constructs a `STEP_FINISHED` event naming the left [stepName].
  const factory StepFinishedEvent({required String stepName}) =
      _StepFinishedEvent;

  /// Decodes a `STEP_FINISHED` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `stepName` is absent.
  static StepFinishedEvent fromJson(Map<String, dynamic> json) =>
      StepFinishedEvent(stepName: _requireString(json, 'stepName'));

  /// Serializes to the `STEP_FINISHED` wire shape.
  Map<String, dynamic> toJson() => {
    'type': 'STEP_FINISHED',
    'stepName': stepName,
  };
}
