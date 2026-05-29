part of 'ag_ui_event.dart';

/// Forward-compat fallback member of the [AgUiEvent] union: the typed home for
/// any wire event whose `type` the current `koel_core` event registry does not
/// recognize (FR-A6 / FC-1).
///
/// Produced exclusively by `deserializeAgUiEvent` when a wire `type` has no
/// registered factory — never constructed from a `fromJson`. [rawJson] is the
/// **verbatim** wire payload (the entire decoded map, including the `type` key),
/// held untouched so a later story can re-emit the event byte-for-byte; the SDK
/// never inspects it. This is why [UnknownAgUiEvent] is freezed-only with no
/// `toJson`: a generated codec would wrap it as `{"type": …, "rawJson": …}` and
/// break that round-trip.
///
/// Structurally compared: freezed generates `==`/`hashCode` with
/// `DeepCollectionEquality`, so [rawJson] compares deeply (nested maps/lists
/// included) — two instances holding distinct but content-equal maps are `==`.
/// Mutate via [copyWith] only.
///
/// [rawJson]'s top level is an unmodifiable view, but **nested** maps/lists are
/// shared with the map `deserializeAgUiEvent` was handed — do not mutate them
/// (e.g. `event.rawJson['payload']['x'] = …`), as that corrupts this value
/// object's cached structural equality. The wire payload is byte-for-byte
/// faithful as long as no one writes through to those nested values.
///
/// From Story 2.10 the pipeline routes each [UnknownAgUiEvent] to
/// `AgentSubscriber.onUnknownEvent`; that callback does not exist yet.
@freezed
abstract class UnknownAgUiEvent extends AgUiEvent with _$UnknownAgUiEvent {
  const UnknownAgUiEvent._() : super();

  const factory UnknownAgUiEvent({
    required String type,
    required Map<String, dynamic> rawJson,
  }) = _UnknownAgUiEvent;
}
