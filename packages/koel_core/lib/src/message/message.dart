import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// Author of a [Message] in the AG-UI conversation.
enum MessageRole {
  /// A message authored by the end user.
  user,

  /// A message authored by the assistant.
  assistant,

  /// A system/instruction message.
  system,

  /// A tool-result message.
  tool,
}

/// A single conversation message — the element type of
/// `RunAgentInput.messages` (and, from Story 2.12, `ChatState.messages`).
///
/// Immutable and structurally compared: two [Message]s with equal field values
/// are `==` (freezed generates `==`/`hashCode` over every field, so distinct
/// [DateTime] instances at the same instant compare equal). Mutate via
/// [copyWith] only.
///
/// [toolCallId] and [name] are populated for tool-role messages per the AG-UI
/// `Message` shape; they are `null` for plain user/assistant/system turns.
@freezed
abstract class Message with _$Message {
  /// Constructs a message identified by [id], authored by [role], carrying
  /// [content] at [timestamp], with optional [toolCallId] and [name].
  const factory Message({
    required String id,
    required MessageRole role,
    required String content,
    @JsonKey(fromJson: _timestampFromWire) required DateTime timestamp,
    String? toolCallId,
    String? name,
  }) = _Message;

  /// Decodes a [Message] from its JSON map.
  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}

/// Decodes the wire `timestamp` for [Message.fromJson].
///
/// `timestamp` is a koel addition — the canonical AG-UI `Message` does not carry
/// it (see `agnoMessageToWire`/`langGraphMessageToWire`, whose encode side omits
/// it by default). So a backend-sourced message — e.g. a `MESSAGES_SNAPSHOT`
/// replay streamed by LangGraph or any native-AG-UI backend — arrives without
/// one. An absent/`null` wire value defaults to the epoch sentinel
/// (`1970-01-01T00:00:00Z`) so decoding canonical wire — where `timestamp` is
/// either absent or an ISO-8601 string — never throws and stays deterministic
/// (the field's non-nullable invariant is preserved for every consumer); a
/// present value is parsed as ISO-8601, exactly as before. A present
/// *non-canonical* value (e.g. an epoch number, an empty string) surfaces a
/// caller-visible throw rather than being coerced — inside a `MESSAGES_SNAPSHOT`
/// the decoder catches it as `ProtocolError(protocolMalformed)`; coercing such
/// shapes would be speculative parsing this kernel deliberately avoids.
DateTime _timestampFromWire(Object? wire) => wire == null
    ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
    : DateTime.parse(wire as String);
