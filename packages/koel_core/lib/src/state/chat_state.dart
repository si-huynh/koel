import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../error/koel_error.dart';
import '../message/message.dart';
import 'tool_call.dart';

part 'chat_state.freezed.dart';

/// Lifecycle phase of the current run, folded from the `RUN_*`/`STEP_*` events.
///
/// `idle` before a run and after `RUN_FINISHED`; `running` inside a run;
/// `stepRunning` inside a `STEP_*` span; `error` after a `RUN_ERROR` or an
/// inapplicable `STATE_DELTA`; `cancelled` when a run is cancelled by the client
/// (Epic 4 transport). The reducer never invents `cancelled` itself — there is
/// no cancel *event*; the cancellation seam sets it.
enum RunPhase {
  /// No run is active (before a run and after `RUN_FINISHED`).
  idle,

  /// A run is in progress.
  running,

  /// Execution is inside a `STEP_*` span.
  stepRunning,

  /// The last run failed (`RUN_ERROR` or an inapplicable `STATE_DELTA`).
  error,

  /// The run was cancelled by the client.
  cancelled,
}

/// An immutable snapshot of a conversation — the value the reducer folds events
/// into (FR-D2). The `apply` pipeline stage surfaces it as a side accumulation;
/// it is never serialized here (persistence is Story 2.13 / Epic 6).
///
/// Structurally compared: freezed generates `==`/`hashCode` with
/// `DeepCollectionEquality`, so [messages], [pendingToolCalls], [state] and
/// [reasoningEcho] compare deeply — and because [Uint8List] is an
/// `Iterable<int>`, [reasoningEcho] gets **byte-deep** equality for free (the
/// same property `RunAgentInput.reasoningEcho` relies on). That const-comparable
/// equality is what makes `ChatState` Riverpod-friendly and time-travel replay
/// (re-folding events `[0..N]`) correct. Mutate via [copyWith] only — the
/// reducer never mutates a `ChatState` in place.
///
/// [messages] is committed conversation history; [pendingMessage] is the
/// in-flight streamed assistant turn (committed to [messages] on
/// `TEXT_MESSAGE_END`); [pendingToolCalls] are in-flight tool invocations;
/// [state] is the shared JSON agent state; [reasoningEcho] accumulates opaque
/// provider reasoning blobs keyed by entity id (echoed into the next run's
/// `RunAgentInput.reasoningEcho`, FR-A9); [error] holds the last folded failure;
/// [phase] is the run lifecycle position.
@freezed
abstract class ChatState with _$ChatState {
  /// Constructs a conversation snapshot from [messages], [pendingMessage],
  /// [pendingToolCalls], [state], [reasoningEcho], [error], and [phase] — each
  /// defaulting to its empty/idle value.
  const factory ChatState({
    @Default(<Message>[]) List<Message> messages,
    Message? pendingMessage,
    @Default(<ToolCall>[]) List<ToolCall> pendingToolCalls,
    @Default(<String, dynamic>{}) Map<String, dynamic> state,
    @Default(<String, Uint8List>{}) Map<String, Uint8List> reasoningEcho,
    KoelError? error,
    @Default(RunPhase.idle) RunPhase phase,
  }) = _ChatState;
}
