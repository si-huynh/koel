part of 'ag_ui_event.dart';

/// `TOOL_CALL_START` — the agent has begun a tool invocation. Opens the
/// streaming call: N×[ToolCallArgsEvent] deltas follow, closed by
/// [ToolCallEndEvent], all sharing [toolCallId].
///
/// [toolCallName] is the tool being invoked; [parentMessageId] links the call to
/// the assistant message that triggered it (`null` for a top-level call).
@freezed
abstract class ToolCallStartEvent extends AgUiEvent with _$ToolCallStartEvent {
  const ToolCallStartEvent._() : super();

  const factory ToolCallStartEvent({
    required String toolCallId,
    required String toolCallName,
    String? parentMessageId,
  }) = _ToolCallStartEvent;

  /// Decodes a `TOOL_CALL_START` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `toolCallId`/`toolCallName` is
  /// absent.
  static ToolCallStartEvent fromJson(Map<String, dynamic> json) =>
      ToolCallStartEvent(
        toolCallId: _requireString(json, 'toolCallId'),
        toolCallName: _requireString(json, 'toolCallName'),
        parentMessageId: _optionalString(json, 'parentMessageId'),
      );

  Map<String, dynamic> toJson() => {
    'type': 'TOOL_CALL_START',
    'toolCallId': toolCallId,
    'toolCallName': toolCallName,
    if (parentMessageId != null) 'parentMessageId': parentMessageId,
  };
}

/// `TOOL_CALL_ARGS` — one streamed [delta] of the tool-call arguments for
/// [toolCallId]. The argument deltas are JSON fragments; concatenate them in
/// order to reconstruct the complete arguments JSON string (the `chunks`/reducer
/// stages own that assembly, not this event).
@freezed
abstract class ToolCallArgsEvent extends AgUiEvent with _$ToolCallArgsEvent {
  const ToolCallArgsEvent._() : super();

  const factory ToolCallArgsEvent({
    required String toolCallId,
    required String delta,
  }) = _ToolCallArgsEvent;

  /// Decodes a `TOOL_CALL_ARGS` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `toolCallId`/`delta` is absent.
  static ToolCallArgsEvent fromJson(Map<String, dynamic> json) =>
      ToolCallArgsEvent(
        toolCallId: _requireString(json, 'toolCallId'),
        delta: _requireString(json, 'delta'),
      );

  Map<String, dynamic> toJson() => {
    'type': 'TOOL_CALL_ARGS',
    'toolCallId': toolCallId,
    'delta': delta,
  };
}

/// `TOOL_CALL_END` — closes the streamed tool call identified by [toolCallId].
@freezed
abstract class ToolCallEndEvent extends AgUiEvent with _$ToolCallEndEvent {
  const ToolCallEndEvent._() : super();

  const factory ToolCallEndEvent({required String toolCallId}) =
      _ToolCallEndEvent;

  /// Decodes a `TOOL_CALL_END` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `toolCallId` is absent.
  static ToolCallEndEvent fromJson(Map<String, dynamic> json) =>
      ToolCallEndEvent(toolCallId: _requireString(json, 'toolCallId'));

  Map<String, dynamic> toJson() => {
    'type': 'TOOL_CALL_END',
    'toolCallId': toolCallId,
  };
}

/// `TOOL_CALL_RESULT` — the result of a tool invocation, emitted by the agent
/// when it executes a backend tool itself (the frontend-tool path instead
/// returns a `role: "tool"` [Message] on the next run). [content] is the result
/// payload as a string; [messageId] identifies the result message and
/// [toolCallId] links it back to the originating call.
///
/// [role] stays a permissive `String?` at the wire boundary (the spec narrows it
/// to `"tool"`); it is **not** defaulted on decode, so an absent `role`
/// round-trips to absent. The typed `MessageRole` enum lives on `Message`, not
/// on transient stream events.
@freezed
abstract class ToolCallResultEvent extends AgUiEvent
    with _$ToolCallResultEvent {
  const ToolCallResultEvent._() : super();

  const factory ToolCallResultEvent({
    required String messageId,
    required String toolCallId,
    required String content,
    String? role,
  }) = _ToolCallResultEvent;

  /// Decodes a `TOOL_CALL_RESULT` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when
  /// `messageId`/`toolCallId`/`content` is absent.
  static ToolCallResultEvent fromJson(Map<String, dynamic> json) =>
      ToolCallResultEvent(
        messageId: _requireString(json, 'messageId'),
        toolCallId: _requireString(json, 'toolCallId'),
        content: _requireString(json, 'content'),
        role: _optionalString(json, 'role'),
      );

  Map<String, dynamic> toJson() => {
    'type': 'TOOL_CALL_RESULT',
    'messageId': messageId,
    'toolCallId': toolCallId,
    'content': content,
    if (role != null) 'role': role,
  };
}

/// `TOOL_CALL_CHUNK` — the convenience wire shape (all fields optional) the
/// `chunks` pipeline stage (Story 2.11) expands into
/// [ToolCallStartEvent]→[ToolCallArgsEvent]→[ToolCallEndEvent] using
/// [toolCallId]+[toolCallName]+[parentMessageId]+[delta] per Addendum F.2. Story
/// 2.6 ships only the typed value; the expansion and the "must carry
/// `toolCallId`" verify rule (Addendum F.1) are Story 2.11.
///
/// [toJson] omits every absent optional, so an empty chunk serializes to
/// `{'type': 'TOOL_CALL_CHUNK'}` and round-trips to all-`null`.
@freezed
abstract class ToolCallChunkEvent extends AgUiEvent with _$ToolCallChunkEvent {
  const ToolCallChunkEvent._() : super();

  const factory ToolCallChunkEvent({
    String? toolCallId,
    String? toolCallName,
    String? parentMessageId,
    String? delta,
  }) = _ToolCallChunkEvent;

  /// Decodes a `TOOL_CALL_CHUNK` wire payload. All fields are optional; an empty
  /// payload decodes to all-`null` without throwing.
  static ToolCallChunkEvent fromJson(Map<String, dynamic> json) =>
      ToolCallChunkEvent(
        toolCallId: _optionalString(json, 'toolCallId'),
        toolCallName: _optionalString(json, 'toolCallName'),
        parentMessageId: _optionalString(json, 'parentMessageId'),
        delta: _optionalString(json, 'delta'),
      );

  Map<String, dynamic> toJson() => {
    'type': 'TOOL_CALL_CHUNK',
    if (toolCallId != null) 'toolCallId': toolCallId,
    if (toolCallName != null) 'toolCallName': toolCallName,
    if (parentMessageId != null) 'parentMessageId': parentMessageId,
    if (delta != null) 'delta': delta,
  };
}
