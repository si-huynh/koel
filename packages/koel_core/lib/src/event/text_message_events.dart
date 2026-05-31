part of 'ag_ui_event.dart';

/// `TEXT_MESSAGE_START` — opens a streamed assistant message. The canonical
/// long form: [TextMessageContentEvent] deltas follow, closed by
/// [TextMessageEndEvent], all sharing [messageId].
///
/// [role] stays a permissive `String` at the wire boundary (the spec narrows it
/// to `"assistant"`); the typed `MessageRole` enum lives on `Message`, not on
/// transient stream events.
@freezed
abstract class TextMessageStartEvent extends AgUiEvent
    with _$TextMessageStartEvent {
  const TextMessageStartEvent._() : super();

  /// Constructs a `TEXT_MESSAGE_START` event opening the streamed message keyed
  /// by [messageId] with [role].
  const factory TextMessageStartEvent({
    required String messageId,
    required String role,
  }) = _TextMessageStartEvent;

  /// Decodes a `TEXT_MESSAGE_START` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `messageId`/`role` is absent.
  static TextMessageStartEvent fromJson(Map<String, dynamic> json) =>
      TextMessageStartEvent(
        messageId: _requireString(json, 'messageId'),
        role: _requireString(json, 'role'),
      );

  /// Serializes to the `TEXT_MESSAGE_START` wire shape.
  Map<String, dynamic> toJson() => {
    'type': 'TEXT_MESSAGE_START',
    'messageId': messageId,
    'role': role,
  };
}

/// `TEXT_MESSAGE_CONTENT` — one streamed [delta] of the message identified by
/// [messageId]. The reducer concatenates deltas in order (Story 2.12).
@freezed
abstract class TextMessageContentEvent extends AgUiEvent
    with _$TextMessageContentEvent {
  const TextMessageContentEvent._() : super();

  /// Constructs a `TEXT_MESSAGE_CONTENT` event carrying one [delta] of the
  /// message keyed by [messageId].
  const factory TextMessageContentEvent({
    required String messageId,
    required String delta,
  }) = _TextMessageContentEvent;

  /// Decodes a `TEXT_MESSAGE_CONTENT` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `messageId`/`delta` is absent.
  static TextMessageContentEvent fromJson(Map<String, dynamic> json) =>
      TextMessageContentEvent(
        messageId: _requireString(json, 'messageId'),
        delta: _requireString(json, 'delta'),
      );

  /// Serializes to the `TEXT_MESSAGE_CONTENT` wire shape.
  Map<String, dynamic> toJson() => {
    'type': 'TEXT_MESSAGE_CONTENT',
    'messageId': messageId,
    'delta': delta,
  };
}

/// `TEXT_MESSAGE_END` — closes the streamed message identified by [messageId].
@freezed
abstract class TextMessageEndEvent extends AgUiEvent
    with _$TextMessageEndEvent {
  const TextMessageEndEvent._() : super();

  /// Constructs a `TEXT_MESSAGE_END` event closing the streamed message keyed by
  /// [messageId].
  const factory TextMessageEndEvent({required String messageId}) =
      _TextMessageEndEvent;

  /// Decodes a `TEXT_MESSAGE_END` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `messageId` is absent.
  static TextMessageEndEvent fromJson(Map<String, dynamic> json) =>
      TextMessageEndEvent(messageId: _requireString(json, 'messageId'));

  /// Serializes to the `TEXT_MESSAGE_END` wire shape.
  Map<String, dynamic> toJson() => {
    'type': 'TEXT_MESSAGE_END',
    'messageId': messageId,
  };
}

/// `TEXT_MESSAGE_CHUNK` — the convenience wire shape (all fields optional) the
/// `chunks` pipeline stage (Story 2.11) expands into
/// [TextMessageStartEvent]→[TextMessageContentEvent]→[TextMessageEndEvent] using
/// [messageId]+[role]+[delta]. Story 2.5 ships only the typed value; the
/// expansion and the "must carry `messageId`" verify rule (Addendum F.1) are
/// Story 2.11.
///
/// [toJson] omits every absent optional, so an empty chunk serializes to
/// `{'type': 'TEXT_MESSAGE_CHUNK'}` and round-trips to all-`null`.
@freezed
abstract class TextMessageChunkEvent extends AgUiEvent
    with _$TextMessageChunkEvent {
  const TextMessageChunkEvent._() : super();

  /// Constructs a `TEXT_MESSAGE_CHUNK` convenience event from the optional
  /// [messageId], [role], and [delta].
  const factory TextMessageChunkEvent({
    String? messageId,
    String? role,
    String? delta,
  }) = _TextMessageChunkEvent;

  /// Decodes a `TEXT_MESSAGE_CHUNK` wire payload. All fields are optional; an
  /// empty payload decodes to all-`null` without throwing.
  static TextMessageChunkEvent fromJson(Map<String, dynamic> json) =>
      TextMessageChunkEvent(
        messageId: _optionalString(json, 'messageId'),
        role: _optionalString(json, 'role'),
        delta: _optionalString(json, 'delta'),
      );

  /// Serializes to the `TEXT_MESSAGE_CHUNK` wire shape.
  Map<String, dynamic> toJson() => {
    'type': 'TEXT_MESSAGE_CHUNK',
    if (messageId != null) 'messageId': messageId,
    if (role != null) 'role': role,
    if (delta != null) 'delta': delta,
  };
}
