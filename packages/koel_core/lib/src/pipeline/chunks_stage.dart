import 'dart:async';

import '../event/ag_ui_event.dart';
import 'stage_support.dart';

/// Pipeline stage 1 — synthesizes the streaming `*_CHUNK` convenience shapes
/// into the canonical `START` → `CONTENT`/`ARGS` → `END` triplets every
/// downstream stage and consumer expects (Addendum F.2). Runs **before**
/// `verifyStage` because verify checks the `START`/`END` pairing this stage
/// creates.
///
/// **What it synthesizes.** For a run of [ToolCallChunkEvent]s sharing a
/// `toolCallId`: the first emits a [ToolCallStartEvent]; each subsequent one
/// emits a [ToolCallArgsEvent]; and the trailing marker — the next non-chunk
/// event, a chunk opening a *different* tool call, or stream completion — emits a
/// [ToolCallEndEvent]. [TextMessageChunkEvent] is handled the same way, keyed by
/// `messageId`, producing [TextMessageStartEvent] / [TextMessageContentEvent] /
/// [TextMessageEndEvent], and [ReasoningMessageChunkEvent] likewise, keyed by
/// `messageId`, producing [ReasoningMessageStartEvent] /
/// [ReasoningMessageContentEvent] / [ReasoningMessageEndEvent]. A first chunk
/// that *also* carries a `delta` emits the `START` and then immediately the
/// `ARGS`/`CONTENT` for that delta — synthesis never drops wire data.
///
/// **Independent envelopes.** A tool-call envelope, a text-message envelope, and
/// a reasoning-message envelope live in separate id namespaces and may be open at
/// the same time. Each chunk family only touches its own envelope. A genuinely
/// non-chunk event closes *all* open envelopes (emitting each `END` before the
/// triggering event passes through).
///
/// **Defaulting.** A [ToolCallStartEvent] requires a `toolCallName` and the start
/// events require a `role`, but the chunk shapes make these optional or absent
/// (a reasoning chunk carries no `role` at all). Synthesis must produce a *valid*
/// typed event, so a missing tool name defaults to `''` and a missing/absent role
/// defaults to `'assistant'` (text) / `'reasoning'` (reasoning).
///
/// **What it drops.** A `*_CHUNK` whose keying id (`toolCallId` / `messageId`)
/// is `null` carries no addressable payload, so it is dropped silently and does
/// not disturb any open envelope. This stage emits **no** [RunErrorEvent] —
/// shape *transformation* is its only job; shape *validation* (orphan `END`,
/// `ARGS` outside an envelope, an empty `messageId` on a text/reasoning event)
/// belongs to `verifyStage`, which runs next precisely so it sees the pairs this
/// stage synthesizes.
///
/// **Lifecycle.** Stateful per subscription, single-subscription, and
/// cancellation/backpressure-correct via [buildStage]. On completion it flushes
/// the trailing `END` for any still-open envelope before closing.
final StreamTransformer<AgUiEvent, AgUiEvent> chunksStage = buildStage(
  _ChunksStage.new,
);

class _ChunksStage extends PipelineStage {
  String? _openToolCallId;
  String? _openMessageId;
  String? _openReasoningId;

  @override
  void onEvent(AgUiEvent event, EventSink<AgUiEvent> out) {
    switch (event) {
      case ToolCallChunkEvent(:final toolCallId):
        // Un-addressable chunk: drop without disturbing any open envelope
        // (Story 2.11 Design Decision 4).
        if (toolCallId == null) return;
        if (toolCallId == _openToolCallId) {
          out.add(
            ToolCallArgsEvent(toolCallId: toolCallId, delta: event.delta ?? ''),
          );
        } else {
          final previous = _openToolCallId;
          if (previous != null) {
            out.add(ToolCallEndEvent(toolCallId: previous));
          }
          out.add(
            ToolCallStartEvent(
              toolCallId: toolCallId,
              toolCallName: event.toolCallName ?? '',
              parentMessageId: event.parentMessageId,
            ),
          );
          _openToolCallId = toolCallId;
          if (event.delta != null) {
            out.add(
              ToolCallArgsEvent(toolCallId: toolCallId, delta: event.delta!),
            );
          }
        }
      case TextMessageChunkEvent(:final messageId):
        if (messageId == null) return;
        if (messageId == _openMessageId) {
          out.add(
            TextMessageContentEvent(
              messageId: messageId,
              delta: event.delta ?? '',
            ),
          );
        } else {
          final previous = _openMessageId;
          if (previous != null) {
            out.add(TextMessageEndEvent(messageId: previous));
          }
          out.add(
            TextMessageStartEvent(
              messageId: messageId,
              role: event.role ?? 'assistant',
            ),
          );
          _openMessageId = messageId;
          if (event.delta != null) {
            out.add(
              TextMessageContentEvent(
                messageId: messageId,
                delta: event.delta!,
              ),
            );
          }
        }
      case ReasoningMessageChunkEvent(:final messageId):
        if (messageId == null) return;
        if (messageId == _openReasoningId) {
          out.add(
            ReasoningMessageContentEvent(
              messageId: messageId,
              delta: event.delta ?? '',
            ),
          );
        } else {
          final previous = _openReasoningId;
          if (previous != null) {
            out.add(ReasoningMessageEndEvent(messageId: previous));
          }
          // Reasoning chunks carry no `role`; default to 'reasoning'.
          out.add(
            ReasoningMessageStartEvent(messageId: messageId, role: 'reasoning'),
          );
          _openReasoningId = messageId;
          if (event.delta != null) {
            out.add(
              ReasoningMessageContentEvent(
                messageId: messageId,
                delta: event.delta!,
              ),
            );
          }
        }
      default:
        // A non-chunk event closes every open envelope, then flows on canonical.
        _flush(out);
        out.add(event);
    }
  }

  @override
  void onDone(EventSink<AgUiEvent> out) => _flush(out);

  void _flush(EventSink<AgUiEvent> out) {
    final tool = _openToolCallId;
    if (tool != null) {
      out.add(ToolCallEndEvent(toolCallId: tool));
      _openToolCallId = null;
    }
    final message = _openMessageId;
    if (message != null) {
      out.add(TextMessageEndEvent(messageId: message));
      _openMessageId = null;
    }
    final reasoning = _openReasoningId;
    if (reasoning != null) {
      out.add(ReasoningMessageEndEvent(messageId: reasoning));
      _openReasoningId = null;
    }
  }
}
