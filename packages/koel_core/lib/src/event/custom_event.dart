part of 'ag_ui_event.dart';

/// `CUSTOM` — a provider- or consumer-declared extension event: a named
/// [value] outside koel's typed families, carried by the protocol as a
/// first-class shape (AG-UI `CustomEvent` = `name` + `value`).
///
/// Use [CustomEvent] for a *declared* structured extension keyed by [name]
/// (e.g. `name: "predictive_state"`); use [RawEvent] for genuinely opaque
/// upstream passthrough. koel does not interpret [name] or [value] — both flow
/// through verbatim.
///
/// [value] holds AG-UI's `value: any`, so it is typed `Object?` and accepts any
/// JSON value (object, list, string, number, bool, or `null`). Despite the
/// `Object?` static type, freezed compares it with `DeepCollectionEquality` at
/// runtime: two `CustomEvent`s built from separate but content-equal maps or
/// lists **are** `==` (and share a `hashCode`); scalars compare by value as
/// usual. `value` is always emitted (even when `null`) so an explicit wire
/// `null` round-trips.
@freezed
abstract class CustomEvent extends AgUiEvent with _$CustomEvent {
  const CustomEvent._() : super();

  /// Constructs a `CUSTOM` extension event keyed by [name] carrying [value].
  const factory CustomEvent({required String name, required Object? value}) =
      _CustomEvent;

  /// Decodes a `CUSTOM` wire payload. Throws
  /// [ProtocolError]`(protocolMalformed)` when `name` is absent or not a
  /// `String`. [value] is read as-is (any JSON value is valid, including
  /// `null`), so it is not guarded.
  static CustomEvent fromJson(Map<String, dynamic> json) =>
      CustomEvent(name: _requireString(json, 'name'), value: json['value']);

  /// Serializes to the `CUSTOM` wire shape.
  Map<String, dynamic> toJson() => {
    'type': 'CUSTOM',
    'name': name,
    'value': value,
  };
}
