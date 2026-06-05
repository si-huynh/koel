import 'package:koel_core/koel_core.dart';

/// Normalizes a koel [Message] down to a canonical AG-UI wire map for a
/// CopilotKit v2 runtime.
///
/// A CopilotKit ≥1.52 (v2) runtime is **native AG-UI over SSE** (`SPIKE-CK-V2`,
/// `@copilotkit/runtime@1.59.4`): its `POST {base}/agent/{agentName}/run` route
/// parses koel's camelCase `RunAgentInput` into `@ag-ui/core` message types and
/// streams canonical AG-UI SSE back — the *same* request edge agno/langgraph hit.
/// So there is no "CopilotKit protocol" to convert here (the legacy
/// `generateCopilotResponse` GraphQL bridge is gone, removed in Story 5.11).
///
/// The one genuine reconciliation is identical to agno's/langgraph's: koel's
/// [Message] is a *superset* of the AG-UI message — it carries a
/// [Message.timestamp] that AG-UI does not define (koel added it for
/// `ChatState.messages`). This normalizer drops that koel-only field so the wire
/// stays canonical AG-UI; inheriting the raw `message.toJson()` would leak
/// `timestamp` and rely on the runtime's zod silently stripping unknown keys
/// (unverified, and a 500 if strict).
///
/// Emits `{id, role, content}` always; adds `toolCallId`/`name` **only when
/// non-null** (an unset field is *absent*, never an explicit `null`). The role
/// string is `MessageRole.name`, identity with AG-UI's role vocabulary
/// (`user`/`assistant`/`system`/`tool`).
///
/// Like langgraph there is **no options type**: Addendum A.5's
/// `CopilotRuntimeAgent` constructor exposes no `conversion` knob, so a
/// `CopilotRuntimeConversionOptions` would be unreachable vestigial surface
/// (CLAUDE.md: no "just-in-case").
Map<String, dynamic> copilotRuntimeMessageToWire(Message message) =>
    <String, dynamic>{
      'id': message.id,
      'role': message.role.name,
      'content': message.content,
      if (message.toolCallId != null) 'toolCallId': message.toolCallId,
      if (message.name != null) 'name': message.name,
    };
