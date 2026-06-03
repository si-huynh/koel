import 'package:koel_core/koel_core.dart';

/// Normalizes a koel [Message] down to a canonical AG-UI wire map for LangGraph.
///
/// `ag-ui-langgraph` (the FastAPI integration koel targets, `==0.0.37`) is
/// **native AG-UI on both edges** (`../koel_backend/backends/langgraph/CONTRACT.md`,
/// SPIKE-LG-RESUME): its `POST /agent` route parses koel's camelCase
/// `RunAgentInput` directly and streams canonical AG-UI SSE back via the protocol
/// `EventEncoder`. The LangGraph-events↔AG-UI translation (channels, `thread_state`,
/// checkpoint envelopes) happens **server-side inside that package** — none of it
/// crosses the koel wire. So there is no "LangGraph protocol" to convert here.
///
/// The one genuine reconciliation is identical to agno's: koel's [Message] is a
/// *superset* of the AG-UI message — it carries a [Message.timestamp] that AG-UI
/// does not define (koel added it for `ChatState.messages`). This normalizer drops
/// that koel-only field so the wire stays canonical AG-UI.
///
/// Emits `{id, role, content}` always; adds `toolCallId`/`name` **only when
/// non-null** (an unset field is *absent*, never an explicit `null`). The role
/// string is [MessageRole.name], identity with AG-UI's role vocabulary
/// (`user`/`assistant`/`system`/`tool`).
///
/// Unlike agno there is **no options type**: Addendum A.4's `LangGraphAgent`
/// constructor exposes no `conversion` knob, so a `LangGraphConversionOptions`
/// would be unreachable vestigial surface (CLAUDE.md: no "just-in-case").
Map<String, dynamic> langGraphMessageToWire(Message message) =>
    <String, dynamic>{
      'id': message.id,
      'role': message.role.name,
      'content': message.content,
      if (message.toolCallId != null) 'toolCallId': message.toolCallId,
      if (message.name != null) 'name': message.name,
    };
