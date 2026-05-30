import 'package:freezed_annotation/freezed_annotation.dart';

part 'tool_call.freezed.dart';

/// An in-flight tool invocation accumulated by the reducer — the element type of
/// `ChatState.pendingToolCalls`.
///
/// Distinct from the transient `ToolCall*Event` stream events: those are the
/// wire frames (`TOOL_CALL_START`/`_ARGS`/`_END`/`_RESULT`), this is the
/// reducer's folded per-call accumulator. A `TOOL_CALL_START` appends one here;
/// each `TOOL_CALL_ARGS` concatenates its delta onto [arguments]; a
/// `TOOL_CALL_RESULT` removes the resolved call. [arguments] stays the raw
/// concatenated JSON-fragment string the wire ships — decoding the complete
/// arguments object is a consumer concern, not the kernel's.
///
/// Immutable and structurally compared (freezed generates `==`/`hashCode` over
/// every field). Mutate via [copyWith] only.
@freezed
abstract class ToolCall with _$ToolCall {
  const factory ToolCall({
    required String id,
    required String name,
    @Default('') String arguments,
    String? parentMessageId,
  }) = _ToolCall;
}
