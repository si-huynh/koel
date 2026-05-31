part of 'ag_ui_event.dart';

/// `ACTIVITY_SNAPSHOT` — a frontend-only structured-UI element (progress bar,
/// checklist, …) keyed by [messageId] and [activityType]. Activity content
/// never reaches the agent; it is rendered by the consumer surface (Epic 6/7).
///
/// [content] is the full activity payload (`Record<string, any>` on the wire);
/// the nested object is compared deeply via freezed's `DeepCollectionEquality`.
/// [replace] mirrors the wire flag (defaulting to `true` *on the wire*) but is
/// **not** defaulted here: an absent flag stays `null` so the round-trip is
/// lossless, and the snapshot-vs-merge decision is left to the consumer.
@freezed
abstract class ActivitySnapshotEvent extends AgUiEvent
    with _$ActivitySnapshotEvent {
  const ActivitySnapshotEvent._() : super();

  /// Constructs an `ACTIVITY_SNAPSHOT` event keyed by [messageId] and
  /// [activityType], carrying the full [content] and optional [replace] flag.
  const factory ActivitySnapshotEvent({
    required String messageId,
    required String activityType,
    required Map<String, dynamic> content,
    bool? replace,
  }) = _ActivitySnapshotEvent;

  /// Decodes an `ACTIVITY_SNAPSHOT` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `messageId`/`activityType` is
  /// absent or `content` is absent/not a JSON object; a present non-`bool`
  /// `replace` is likewise rejected (absent `replace` decodes to `null`).
  static ActivitySnapshotEvent fromJson(Map<String, dynamic> json) =>
      ActivitySnapshotEvent(
        messageId: _requireString(json, 'messageId'),
        activityType: _requireString(json, 'activityType'),
        content: _requireMap(json, 'content'),
        replace: _optionalBool(json, 'replace'),
      );

  /// Serializes to the `ACTIVITY_SNAPSHOT` wire shape.
  Map<String, dynamic> toJson() => {
    'type': 'ACTIVITY_SNAPSHOT',
    'messageId': messageId,
    'activityType': activityType,
    'content': content,
    if (replace != null) 'replace': replace,
  };
}

/// `ACTIVITY_DELTA` — an incremental mutation of a prior [ActivitySnapshotEvent]'s
/// content, carried as RFC 6902 JSON Patch ops the consumer folds onto the
/// activity. This event only **transports** the [patches]; the empty/invalid-op
/// rejection is the verify stage's job (Story 2.11 / Addendum F.1), so an empty
/// `patch` decodes to an empty [patches] list here.
///
/// **Wire-key divergence:** the Dart field is [patches] (per Addendum §A.1,
/// consuming the Story-2.4 [JsonPatchOp] union — the same op type
/// [StateDeltaEvent] uses) but the wire key is `patch`.
@freezed
abstract class ActivityDeltaEvent extends AgUiEvent with _$ActivityDeltaEvent {
  const ActivityDeltaEvent._() : super();

  /// Constructs an `ACTIVITY_DELTA` event keyed by [messageId] and
  /// [activityType], carrying the RFC 6902 [patches].
  const factory ActivityDeltaEvent({
    required String messageId,
    required String activityType,
    required List<JsonPatchOp> patches,
  }) = _ActivityDeltaEvent;

  /// Decodes an `ACTIVITY_DELTA` wire payload (wire key `patch`, an array of RFC
  /// 6902 ops). Throws [ProtocolError]`(protocolMalformed)` when
  /// `messageId`/`activityType` is absent, `patch` is absent/not an array, holds
  /// a non-object element, or carries a malformed op (via [JsonPatchOp.fromJson]).
  static ActivityDeltaEvent fromJson(Map<String, dynamic> json) =>
      ActivityDeltaEvent(
        messageId: _requireString(json, 'messageId'),
        activityType: _requireString(json, 'activityType'),
        patches: _decodeObjectList(json, 'patch', JsonPatchOp.fromJson),
      );

  /// Serializes to the `ACTIVITY_DELTA` wire shape.
  Map<String, dynamic> toJson() => {
    'type': 'ACTIVITY_DELTA',
    'messageId': messageId,
    'activityType': activityType,
    'patch': [for (final patch in patches) patch.toJson()],
  };
}
