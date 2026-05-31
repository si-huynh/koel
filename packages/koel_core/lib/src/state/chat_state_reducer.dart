import '../error/koel_error.dart';
import '../error/koel_error_code.dart';
import '../event/ag_ui_event.dart';
import '../json_patch/json_patch.dart';
import '../message/message.dart';
import 'chat_state.dart';
import 'tool_call.dart';

/// The pure fold that drives the `apply` pipeline stage: given the current
/// [ChatState] and one canonical [AgUiEvent], it returns the next state.
///
/// `reduce` is the F-D2 reduction seam — replaceable (swap in a custom reducer),
/// composable (see `ComposedReducer`), and **pure**: it never mutates its
/// [ChatState] argument and is deterministic (no wall-clock, no RNG), which is
/// what keeps [ChatState] const-comparable and time-travel replay correct.
abstract class ChatStateReducer {
  /// Folds one [event] onto [state], returning the next [ChatState].
  ChatState reduce(ChatState state, AgUiEvent event);
}

/// Deterministic sentinel timestamp for synthesized streaming messages.
///
/// The typed `TEXT_MESSAGE_*` events carry no timestamp, but [Message] requires
/// one. The reducer must not reach for `DateTime.now()` — that would make
/// `reduce` non-deterministic and break the purity/determinism contract. Real
/// wall-clock timestamps arrive on `MESSAGES_SNAPSHOT` (backend-stamped) or are
/// re-stamped by the controller/persistence layer (Epic 6).
///
/// `DateTime.fromMillisecondsSinceEpoch` is not a `const` constructor, so this
/// is a lazily-initialized top-level `final`, not a `const`.
final _epoch = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

/// Maps the permissive wire `role` string onto the typed [MessageRole],
/// defaulting to [MessageRole.assistant] for the spec-narrowed streaming case
/// (and any unrecognized value).
MessageRole _roleFrom(String role) => switch (role) {
  'user' => MessageRole.user,
  'assistant' => MessageRole.assistant,
  'system' => MessageRole.system,
  'tool' => MessageRole.tool,
  _ => MessageRole.assistant,
};

/// The default `ChatStateReducer` — folds the **canonical** AG-UI stream (the
/// post-`chunks`, post-`verify` events) into [ChatState] per the Addendum A.1 /
/// C.1 fold contract.
///
/// **Total:** it never lets a `throw` escape. The one branch that can fail —
/// `STATE_DELTA`, whose ops can be individually valid yet inapplicable to the
/// current state — catches the [ProtocolError] `JsonPatch.apply` throws and
/// folds it into [ChatState.error] + [RunPhase.error]. Minting in-stream errors
/// is the `verify` stage's job (C.1 step 2); `apply`'s job is to fold (step 3).
///
/// **Pure:** every branch returns `state.copyWith(...)`; collections are rebuilt
/// (`[...state.messages, m]`, `{...state.reasoningEcho, id: bytes}`), never
/// mutated in place. `JsonPatch.apply` is non-mutating + atomic, so even the
/// `STATE_DELTA` fold leaves `state.state` untouched.
///
/// **Post-chunks input:** this reducer assumes Start/Content|Args/End triplets,
/// not the `*_CHUNK` convenience frames — the `chunks` stage expands those
/// upstream, so the `*ChunkEvent` arms live in the no-op `default:` (defensive
/// homing) rather than re-implementing chunk accumulation here.
class DefaultChatStateReducer implements ChatStateReducer {
  /// Const default constructor.
  const DefaultChatStateReducer();

  @override
  ChatState reduce(ChatState state, AgUiEvent event) {
    switch (event) {
      // ---- Run / step lifecycle → phase transitions -----------------------
      case RunStartedEvent():
        // A new run clears prior transients + error; messages history persists.
        return state.copyWith(
          phase: RunPhase.running,
          error: null,
          pendingMessage: null,
          pendingToolCalls: const [],
        );
      case RunFinishedEvent():
        return state.copyWith(phase: RunPhase.idle);
      case RunErrorEvent(:final error):
        // event.error is already a KoelError (an AgentError from decode).
        return state.copyWith(error: error, phase: RunPhase.error);
      case StepStartedEvent():
        return state.copyWith(phase: RunPhase.stepRunning);
      case StepFinishedEvent():
        return state.copyWith(phase: RunPhase.running);

      // ---- Streamed assistant message → pendingMessage accumulation -------
      case TextMessageStartEvent(:final messageId, :final role):
        return state.copyWith(
          pendingMessage: Message(
            id: messageId,
            role: _roleFrom(role),
            content: '',
            timestamp: _epoch,
          ),
        );
      case TextMessageContentEvent(:final delta):
        final pending = state.pendingMessage;
        if (pending == null) return state; // Content with no Start → no-op.
        return state.copyWith(
          pendingMessage: pending.copyWith(content: pending.content + delta),
        );
      case TextMessageEndEvent():
        final pending = state.pendingMessage;
        if (pending == null) return state; // End with no Start → no-op.
        return state.copyWith(
          messages: [...state.messages, pending],
          pendingMessage: null,
        );

      // ---- Tool calls → pendingToolCalls lifecycle ------------------------
      case ToolCallStartEvent(
        :final toolCallId,
        :final toolCallName,
        :final parentMessageId,
      ):
        return state.copyWith(
          pendingToolCalls: [
            ...state.pendingToolCalls,
            ToolCall(
              id: toolCallId,
              name: toolCallName,
              parentMessageId: parentMessageId,
            ),
          ],
        );
      case ToolCallArgsEvent(:final toolCallId, :final delta):
        final index = state.pendingToolCalls.indexWhere(
          (c) => c.id == toolCallId,
        );
        if (index == -1) return state; // No open call → no-op.
        final calls = [...state.pendingToolCalls];
        final call = calls[index];
        calls[index] = call.copyWith(arguments: call.arguments + delta);
        return state.copyWith(pendingToolCalls: calls);
      case ToolCallEndEvent():
        // End only closes the args stream; the call stays pending until a
        // result resolves it. No membership change.
        return state;
      case ToolCallResultEvent(:final toolCallId):
        final calls = [
          for (final c in state.pendingToolCalls)
            if (c.id != toolCallId) c,
        ];
        if (calls.length == state.pendingToolCalls.length) {
          return state; // No matching call → no-op.
        }
        // The call is resolved; tool-result history is sourced from
        // MESSAGES_SNAPSHOT / the next run's messages, not synthesized here.
        return state.copyWith(pendingToolCalls: calls);

      // ---- Shared agent state --------------------------------------------
      case StateSnapshotEvent():
        return state.copyWith(state: event.state); // Wholesale replace.
      case StateDeltaEvent(:final patches):
        try {
          final next = JsonPatch.apply(state.state, patches);
          if (next is! Map<String, dynamic>) {
            // RFC 6902 lets a root-replacing op (`path: ""`) change the
            // top-level type (json_patch.dart:17-19), but ChatState.state is a
            // JSON object — a non-object root is inapplicable. Fold it like any
            // other malformed delta rather than letting the cast `throw` escape;
            // the reducer is total.
            return state.copyWith(
              error: const ProtocolError(
                message:
                    'STATE_DELTA replaced the state root with a non-object',
                code: KoelErrorCode.protocolMalformed,
              ),
              phase: RunPhase.error,
            );
          }
          return state.copyWith(state: next);
        } on ProtocolError catch (e) {
          // Inapplicable patch — fold the failure into state, never rethrow.
          return state.copyWith(error: e, phase: RunPhase.error);
        }
      case MessagesSnapshotEvent(:final messages):
        // Snapshot supersedes the streaming buffer.
        return state.copyWith(messages: messages, pendingMessage: null);

      // ---- Reasoning echo blobs ------------------------------------------
      case ReasoningEncryptedValueEvent(:final entityId, :final encryptedValue):
        return state.copyWith(
          reasoningEcho: {...state.reasoningEcho, entityId: encryptedValue},
        );

      // ---- No-op families + forward-compat fallback -----------------------
      // Homes UnknownAgUiEvent, RawEvent, CustomEvent, Activity{Snapshot,Delta},
      // Reasoning{Start,End,Message{Start,Content,End,Chunk}}, and the
      // Text/ToolCall *ChunkEvents (never reach apply post-chunks). Also the
      // koel_lints exhaustive_switch_must_have_default arm.
      default:
        return state;
    }
  }
}
