import 'package:freezed_annotation/freezed_annotation.dart';

part 'context.freezed.dart';
part 'context.g.dart';

/// A piece of contextual information supplied to the agent for a run.
///
/// One element of `RunAgentInput.context`, which the AG-UI protocol types as a
/// `List<Context>` (not a map): each entry pairs a human-readable [description]
/// with its [value]. Immutable and structurally compared; mutate via `copyWith`
/// only. Round-trips through `toJson`/`fromJson` as `{description, value}`.
@freezed
abstract class Context with _$Context {
  /// Constructs a context entry describing [value] under [description].
  const factory Context({required String description, required String value}) =
      _Context;

  /// Decodes a [Context] from its JSON map.
  factory Context.fromJson(Map<String, dynamic> json) =>
      _$ContextFromJson(json);
}
