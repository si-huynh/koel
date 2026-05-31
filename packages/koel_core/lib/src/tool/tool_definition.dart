import 'package:freezed_annotation/freezed_annotation.dart';

part 'tool_definition.freezed.dart';
part 'tool_definition.g.dart';

/// A tool the agent is permitted to call during a run.
///
/// [parameters] is a JSON Schema object (`Map<String, dynamic>`) in v1 — the
/// tool-parameter DSL is intentionally deferred (OQ-Tool-Param-DSL). Immutable
/// and structurally compared, including deep equality over the nested
/// [parameters] map; mutate via [copyWith] only.
@freezed
abstract class ToolDefinition with _$ToolDefinition {
  /// Constructs a tool the agent may call, named [name] with [description] and a
  /// JSON Schema [parameters] object.
  const factory ToolDefinition({
    required String name,
    required String description,
    @Default(<String, dynamic>{}) Map<String, dynamic> parameters,
  }) = _ToolDefinition;

  /// Decodes a [ToolDefinition] from its JSON map.
  factory ToolDefinition.fromJson(Map<String, dynamic> json) =>
      _$ToolDefinitionFromJson(json);
}
