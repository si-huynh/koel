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
    @JsonKey(fromJson: _contentFromWire) required String content,
    @JsonKey(
      fromJson: _timestampFromWire,
      toJson: _timestampToWire,
      includeIfNull: false,
    )
    required DateTime timestamp,
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
DateTime _timestampFromWire(Object? wire) =>
    wire == null ? _epochSentinel : DateTime.parse(wire as String);

/// Encodes [Message.timestamp] for `toJson`, the inverse of [_timestampFromWire].
///
/// A [timestamp] equal to the [_epochSentinel] is the "wire carried none" marker
/// (set by [_timestampFromWire] on an absent value, and by the reducer for a
/// not-yet-instant streamed message — `chat_state_reducer.dart`'s `_epoch`, the
/// same value). Returning `null` for it, paired with `@JsonKey(includeIfNull:
/// false)`, **omits** the key — so decoding a `timestamp`-less wire message then
/// re-encoding it (a `MESSAGES_SNAPSHOT` replay, or a `ChatState` persisted to
/// Hive in Epic 6) round-trips faithfully instead of fabricating a
/// `1970-01-01T00:00:00.000Z` the backend never sent. A real instant encodes as
/// ISO-8601, exactly as before.
String? _timestampToWire(DateTime timestamp) =>
    timestamp == _epochSentinel ? null : timestamp.toIso8601String();

/// The UTC Unix epoch — the sentinel a `timestamp`-less wire [Message] decodes to
/// and the value [_timestampToWire] omits on re-encode. `DateTime` is not a
/// `const` expression, so this is a top-level `final`, not a class constant.
final _epochSentinel = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// Decodes the wire `content` for [Message.fromJson].
///
/// An assistant message that carries tool calls has no textual `content` on the
/// AG-UI wire — a dojo `MESSAGES_SNAPSHOT` assistant turn streams `{role,
/// toolCalls}` with `content` absent — and the canonical AG-UI `Message` shape
/// leaves it optional. An absent/`null` wire value defaults to the empty string
/// so decoding canonical wire never throws and the field's non-nullable
/// invariant is preserved for every consumer (parallel to [_timestampFromWire],
/// the Story 5.6 tolerance); a present non-`String` value surfaces a
/// caller-visible throw (caught as `ProtocolError` inside a `MESSAGES_SNAPSHOT`)
/// rather than being coerced — speculative parsing this kernel deliberately
/// avoids.
String _contentFromWire(Object? wire) => wire == null ? '' : wire as String;
