import 'package:koel_core/koel_core.dart';

/// The (deliberately tiny) knobs for normalizing a koel [Message] onto the agno
/// wire.
///
/// agno is **native AG-UI** (`SPIKE-AGNO`, `../koel_backend/backends/agno/CONTRACT.md`):
/// its route handler parses koel's camelCase `RunAgentInput` directly and emits
/// canonical AG-UI SSE — there is no foreign chat shape to reshape into. The one
/// genuine reconciliation is that koel's [Message] is a *superset* of the AG-UI
/// message: it carries a [Message.timestamp] that AG-UI does not define (koel
/// added it for `ChatState.messages`). So the only real variance point is whether
/// to leak that koel-internal field onto a foreign wire — hence the single knob.
///
/// No speculative options (CLAUDE.md: no "just-in-case" params): agno needs
/// nothing beyond canonical AG-UI, and a wider surface would be vestigial.
class AgnoConversionOptions {
  /// Creates conversion options; [includeTimestamp] defaults to `false` so the
  /// koel-only `timestamp` field stays off the canonical AG-UI wire.
  const AgnoConversionOptions({this.includeTimestamp = false});

  /// When `true`, [agnoMessageToWire] emits koel's non-AG-UI [Message.timestamp]
  /// as an ISO-8601 string. Default `false`: the agno wire is canonical AG-UI,
  /// which has no `timestamp`.
  final bool includeTimestamp;
}

/// Normalizes a koel [Message] down to a canonical AG-UI wire map for agno.
///
/// Emits `{id, role, content}` always; adds `toolCallId`/`name` **only when
/// non-null** (an unset field is *absent*, never an explicit `null`); adds
/// `timestamp` (ISO-8601) **only when** [AgnoConversionOptions.includeTimestamp].
/// The role string is `MessageRole.name`, which is identity with AG-UI's role
/// vocabulary (`user`/`assistant`/`system`/`tool`).
Map<String, dynamic> agnoMessageToWire(
  Message message,
  AgnoConversionOptions options,
) => <String, dynamic>{
  'id': message.id,
  'role': message.role.name,
  'content': message.content,
  if (message.toolCallId != null) 'toolCallId': message.toolCallId,
  if (message.name != null) 'name': message.name,
  if (options.includeTimestamp)
    'timestamp': message.timestamp.toIso8601String(),
};
