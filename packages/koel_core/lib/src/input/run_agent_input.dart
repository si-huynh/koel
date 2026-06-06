import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../context/context.dart';
import '../message/message.dart';
import '../tool/tool_definition.dart';

part 'run_agent_input.freezed.dart';

/// The wire payload that initiates an agent run.
///
/// Immutable and structurally compared. freezed generates `==`/`hashCode` with
/// `DeepCollectionEquality`, so [state], [messages], [tools], [context] and
/// [forwardedProps] compare deeply — and because [Uint8List] is an
/// `Iterable<int>`, [reasoningEcho] gets **byte-deep** equality for free: two
/// inputs whose blobs hold distinct byte buffers with identical contents are
/// `==`. Mutate via [copyWith] only.
///
/// [reasoningEcho] carries opaque reasoning blobs to echo back so providers can
/// replay reasoning: keys are reasoning ids from prior runs, values are the byte
/// blobs verbatim — never inspected, round-tripped as-is.
///
/// JSON (de)serialization is intentionally **not** in this story: the wire codec
/// needs a base64 `Uint8List` converter and lands with the transport that posts
/// this payload (Epic 4, `koel_http`).
@freezed
abstract class RunAgentInput with _$RunAgentInput {
  /// Constructs a run payload under [threadId]/[runId], carrying the [state],
  /// [messages], [tools], [context], [forwardedProps], and optional
  /// [reasoningEcho].
  const factory RunAgentInput({
    required String threadId,
    required String runId,
    @Default(<String, dynamic>{}) Map<String, dynamic> state,
    @Default(<Message>[]) List<Message> messages,
    @Default(<ToolDefinition>[]) List<ToolDefinition> tools,
    @Default(<Context>[]) List<Context> context,
    @Default(<String, dynamic>{}) Map<String, dynamic> forwardedProps,
    Map<String, Uint8List>? reasoningEcho,
  }) = _RunAgentInput;
}
