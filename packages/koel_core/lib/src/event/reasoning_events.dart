part of 'ag_ui_event.dart';

/// `REASONING_START` — opens a reasoning (chain-of-thought) span identified by
/// [messageId], closed by [ReasoningEndEvent]. The reasoning message stream
/// ([ReasoningMessageStartEvent]→…→[ReasoningMessageEndEvent]) lives between them.
@freezed
abstract class ReasoningStartEvent extends AgUiEvent
    with _$ReasoningStartEvent {
  const ReasoningStartEvent._() : super();

  const factory ReasoningStartEvent({required String messageId}) =
      _ReasoningStartEvent;

  /// Decodes a `REASONING_START` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `messageId` is absent.
  static ReasoningStartEvent fromJson(Map<String, dynamic> json) =>
      ReasoningStartEvent(messageId: _requireString(json, 'messageId'));

  Map<String, dynamic> toJson() => {
    'type': 'REASONING_START',
    'messageId': messageId,
  };
}

/// `REASONING_END` — closes the reasoning span identified by [messageId].
@freezed
abstract class ReasoningEndEvent extends AgUiEvent with _$ReasoningEndEvent {
  const ReasoningEndEvent._() : super();

  const factory ReasoningEndEvent({required String messageId}) =
      _ReasoningEndEvent;

  /// Decodes a `REASONING_END` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `messageId` is absent.
  static ReasoningEndEvent fromJson(Map<String, dynamic> json) =>
      ReasoningEndEvent(messageId: _requireString(json, 'messageId'));

  Map<String, dynamic> toJson() => {
    'type': 'REASONING_END',
    'messageId': messageId,
  };
}

/// `REASONING_MESSAGE_START` — opens a streamed reasoning message. The canonical
/// long form: [ReasoningMessageContentEvent] deltas follow, closed by
/// [ReasoningMessageEndEvent], all sharing [messageId].
///
/// [role] stays a permissive `String` at the wire boundary (the spec narrows it
/// to the literal `"reasoning"`); the typed role vocabulary lives on `Message`,
/// not on transient stream events.
@freezed
abstract class ReasoningMessageStartEvent extends AgUiEvent
    with _$ReasoningMessageStartEvent {
  const ReasoningMessageStartEvent._() : super();

  const factory ReasoningMessageStartEvent({
    required String messageId,
    required String role,
  }) = _ReasoningMessageStartEvent;

  /// Decodes a `REASONING_MESSAGE_START` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `messageId`/`role` is absent.
  static ReasoningMessageStartEvent fromJson(Map<String, dynamic> json) =>
      ReasoningMessageStartEvent(
        messageId: _requireString(json, 'messageId'),
        role: _requireString(json, 'role'),
      );

  Map<String, dynamic> toJson() => {
    'type': 'REASONING_MESSAGE_START',
    'messageId': messageId,
    'role': role,
  };
}

/// `REASONING_MESSAGE_CONTENT` — one streamed [delta] of the reasoning message
/// identified by [messageId]. The consumer concatenates deltas in order.
@freezed
abstract class ReasoningMessageContentEvent extends AgUiEvent
    with _$ReasoningMessageContentEvent {
  const ReasoningMessageContentEvent._() : super();

  const factory ReasoningMessageContentEvent({
    required String messageId,
    required String delta,
  }) = _ReasoningMessageContentEvent;

  /// Decodes a `REASONING_MESSAGE_CONTENT` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `messageId`/`delta` is absent.
  static ReasoningMessageContentEvent fromJson(Map<String, dynamic> json) =>
      ReasoningMessageContentEvent(
        messageId: _requireString(json, 'messageId'),
        delta: _requireString(json, 'delta'),
      );

  Map<String, dynamic> toJson() => {
    'type': 'REASONING_MESSAGE_CONTENT',
    'messageId': messageId,
    'delta': delta,
  };
}

/// `REASONING_MESSAGE_END` — closes the streamed reasoning message identified by
/// [messageId].
@freezed
abstract class ReasoningMessageEndEvent extends AgUiEvent
    with _$ReasoningMessageEndEvent {
  const ReasoningMessageEndEvent._() : super();

  const factory ReasoningMessageEndEvent({required String messageId}) =
      _ReasoningMessageEndEvent;

  /// Decodes a `REASONING_MESSAGE_END` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `messageId` is absent.
  static ReasoningMessageEndEvent fromJson(Map<String, dynamic> json) =>
      ReasoningMessageEndEvent(messageId: _requireString(json, 'messageId'));

  Map<String, dynamic> toJson() => {
    'type': 'REASONING_MESSAGE_END',
    'messageId': messageId,
  };
}

/// `REASONING_MESSAGE_CHUNK` — the convenience wire shape (all fields optional)
/// the `chunks` pipeline stage (Story 2.11) expands into
/// [ReasoningMessageStartEvent]→[ReasoningMessageContentEvent]→[ReasoningMessageEndEvent]
/// using [messageId]+[delta]. Story 2.7 ships only the typed value; the
/// expansion is Story 2.11. Unlike `TEXT_MESSAGE_CHUNK`, the reasoning chunk
/// carries no `role`.
///
/// [toJson] omits every absent optional, so an empty chunk serializes to
/// `{'type': 'REASONING_MESSAGE_CHUNK'}` and round-trips to all-`null`.
@freezed
abstract class ReasoningMessageChunkEvent extends AgUiEvent
    with _$ReasoningMessageChunkEvent {
  const ReasoningMessageChunkEvent._() : super();

  const factory ReasoningMessageChunkEvent({String? messageId, String? delta}) =
      _ReasoningMessageChunkEvent;

  /// Decodes a `REASONING_MESSAGE_CHUNK` wire payload. All fields are optional;
  /// an empty payload decodes to all-`null` without throwing.
  static ReasoningMessageChunkEvent fromJson(Map<String, dynamic> json) =>
      ReasoningMessageChunkEvent(
        messageId: _optionalString(json, 'messageId'),
        delta: _optionalString(json, 'delta'),
      );

  Map<String, dynamic> toJson() => {
    'type': 'REASONING_MESSAGE_CHUNK',
    if (messageId != null) 'messageId': messageId,
    if (delta != null) 'delta': delta,
  };
}

/// `REASONING_ENCRYPTED_VALUE` — an opaque provider reasoning blob (Anthropic /
/// OpenAI zero-retention chain-of-thought) that must round-trip **verbatim** or
/// the provider rejects the next request (FR-A9). Keyed by [entityId] (echoed
/// back via `RunAgentInput.reasoningEcho` in a later run, accumulated by the
/// reducer in Story 2.12) and [subtype] (`"tool-call"` or `"message"`, kept a
/// permissive `String`).
///
/// The blob is carried twice on purpose: [encryptedValue] is the decoded bytes
/// for the typed `reasoningEcho: Map<String, Uint8List>` surface, and
/// [encryptedValueBase64] is the **original wire string preserved verbatim**.
/// [toJson] echoes [encryptedValueBase64] back to wire key `encryptedValue` and
/// **never** re-encodes [encryptedValue] — `base64Encode(base64Decode(s))` is
/// not guaranteed to reproduce `s` (padding/whitespace/alphabet), so re-encoding
/// would break the byte-exact wire round-trip. The bytes are **never inspected**.
/// `Uint8List` gets byte-deep `==` from freezed (it is an `Iterable<int>`), so
/// two events carrying equal bytes compare equal.
@freezed
abstract class ReasoningEncryptedValueEvent extends AgUiEvent
    with _$ReasoningEncryptedValueEvent {
  const ReasoningEncryptedValueEvent._() : super();

  const factory ReasoningEncryptedValueEvent({
    required String entityId,
    required String subtype,
    required Uint8List encryptedValue,
    required String encryptedValueBase64,
  }) = _ReasoningEncryptedValueEvent;

  /// Decodes a `REASONING_ENCRYPTED_VALUE` wire payload. Reads the base64
  /// `encryptedValue` string once — preserving it verbatim on
  /// [encryptedValueBase64] and decoding it to bytes on [encryptedValue]. Throws
  /// [ProtocolError]`(protocolMalformed)` when `entityId`/`subtype`/`encryptedValue`
  /// is absent, or when `encryptedValue` is not valid base64.
  static ReasoningEncryptedValueEvent fromJson(Map<String, dynamic> json) {
    final base64 = _requireString(json, 'encryptedValue');
    return ReasoningEncryptedValueEvent(
      entityId: _requireString(json, 'entityId'),
      subtype: _requireString(json, 'subtype'),
      encryptedValue: _decodeBase64(base64),
      encryptedValueBase64: base64,
    );
  }

  Map<String, dynamic> toJson() => {
    'type': 'REASONING_ENCRYPTED_VALUE',
    'subtype': subtype,
    'entityId': entityId,
    'encryptedValue': encryptedValueBase64,
  };
}
