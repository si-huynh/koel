part of 'ag_ui_event.dart';

/// `STATE_SNAPSHOT` — a full replacement of the shared agent state (cold start
/// or resync). The reducer (Story 2.12) replaces `ChatState.state` wholesale
/// with [state].
///
/// **Wire-key divergence:** the Dart field is [state] (per Addendum §A.1) but
/// the wire key is `snapshot`. Typed `Map<String, dynamic>` because AG-UI state
/// is a JSON object — the same shape `RunAgentInput.state` carries and
/// `JsonPatch.apply` folds [StateDeltaEvent] patches onto. The nested object is
/// compared deeply via freezed's `DeepCollectionEquality`.
@freezed
abstract class StateSnapshotEvent extends AgUiEvent with _$StateSnapshotEvent {
  const StateSnapshotEvent._() : super();

  /// Constructs a `STATE_SNAPSHOT` event carrying the full replacement [state].
  const factory StateSnapshotEvent({required Map<String, dynamic> state}) =
      _StateSnapshotEvent;

  /// Decodes a `STATE_SNAPSHOT` wire payload (wire key `snapshot`). Throws
  /// [ProtocolError]`(protocolMalformed)` when `snapshot` is absent or not a
  /// JSON object.
  static StateSnapshotEvent fromJson(Map<String, dynamic> json) =>
      StateSnapshotEvent(state: _requireMap(json, 'snapshot'));

  /// Serializes to the `STATE_SNAPSHOT` wire shape.
  Map<String, dynamic> toJson() => {
    'type': 'STATE_SNAPSHOT',
    'snapshot': state,
  };
}

/// `STATE_DELTA` — an incremental mutation of the shared agent state as RFC 6902
/// JSON Patch ops the reducer (Story 2.12) folds onto the current state via
/// `JsonPatch.apply`. This event only **transports** the [patches]; the
/// empty-patches and invalid-op rejection is the verify stage's job (Story 2.11
/// / Addendum F.1), so an empty `delta` decodes to an empty [patches] list here.
///
/// **Wire-key divergence:** the Dart field is [patches] (per Addendum §A.1,
/// consuming the Story-2.4 [JsonPatchOp] union) but the wire key is `delta`.
@freezed
abstract class StateDeltaEvent extends AgUiEvent with _$StateDeltaEvent {
  const StateDeltaEvent._() : super();

  /// Constructs a `STATE_DELTA` event carrying the RFC 6902 [patches].
  const factory StateDeltaEvent({required List<JsonPatchOp> patches}) =
      _StateDeltaEvent;

  /// Decodes a `STATE_DELTA` wire payload (wire key `delta`, an array of RFC
  /// 6902 ops). Throws [ProtocolError]`(protocolMalformed)` when `delta` is
  /// absent, not an array, holds a non-object element, or carries a malformed
  /// op (via [JsonPatchOp.fromJson]).
  static StateDeltaEvent fromJson(Map<String, dynamic> json) => StateDeltaEvent(
    patches: _decodeObjectList(json, 'delta', JsonPatchOp.fromJson),
  );

  /// Serializes to the `STATE_DELTA` wire shape.
  Map<String, dynamic> toJson() => {
    'type': 'STATE_DELTA',
    'delta': [for (final patch in patches) patch.toJson()],
  };
}

/// `MESSAGES_SNAPSHOT` — a full replay of the conversation history, replacing
/// `ChatState.messages` wholesale (Story 2.12). [messages] consumes the
/// Story-2.1 [Message] leaf type and delegates element (de)serialization to its
/// own codec, so every field — including `DateTime` and the optional
/// `toolCallId`/`name` — round-trips without information loss.
@freezed
abstract class MessagesSnapshotEvent extends AgUiEvent
    with _$MessagesSnapshotEvent {
  const MessagesSnapshotEvent._() : super();

  /// Constructs a `MESSAGES_SNAPSHOT` event carrying the full [messages] replay.
  const factory MessagesSnapshotEvent({required List<Message> messages}) =
      _MessagesSnapshotEvent;

  /// Decodes a `MESSAGES_SNAPSHOT` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `messages` is absent, not an
  /// array, or holds a non-object element; per-message decoding delegates to
  /// [Message.fromJson].
  static MessagesSnapshotEvent fromJson(Map<String, dynamic> json) =>
      MessagesSnapshotEvent(
        messages: _decodeObjectList(json, 'messages', Message.fromJson),
      );

  /// Serializes to the `MESSAGES_SNAPSHOT` wire shape.
  Map<String, dynamic> toJson() => {
    'type': 'MESSAGES_SNAPSHOT',
    'messages': [for (final message in messages) message.toJson()],
  };
}
