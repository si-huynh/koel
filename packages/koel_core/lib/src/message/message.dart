import 'package:freezed_annotation/freezed_annotation.dart';

part 'message.freezed.dart';
part 'message.g.dart';

/// Author of a [Message] in the AG-UI conversation.
enum MessageRole { user, assistant, system, tool }

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
  const factory Message({
    required String id,
    required MessageRole role,
    required String content,
    required DateTime timestamp,
    String? toolCallId,
    String? name,
  }) = _Message;

  factory Message.fromJson(Map<String, dynamic> json) =>
      _$MessageFromJson(json);
}
