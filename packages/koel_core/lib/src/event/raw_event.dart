part of 'ag_ui_event.dart';

/// `RAW` — an opaque passthrough event whose [payload] koel never inspects,
/// validates, or redacts: it flows verbatim from the wire through the pipeline
/// to subscribers. The escape hatch for provider-specific events that pre-date
/// or sit outside koel's typed families.
///
/// **Wire-key divergence:** the payload lives under wire key `event` (AG-UI
/// `RawEvent.event`), surfaced here as [payload] — the same hand-rolled
/// remap pattern as `StateSnapshotEvent.state ↔ snapshot`. The optional
/// [source] (wire `source`) tags the payload's origin; it round-trips when
/// present and is omitted when absent. koel narrows AG-UI's `event: any` to a
/// JSON object: a non-object `event` is outside koel's typed model and decodes
/// to [ProtocolError]`(protocolMalformed)`.
///
/// **PII:** [payload] is never scrubbed here. Consumers own any sensitive data
/// it carries; a default-OFF `PIIRedactionInterceptor` (Epic 4, `koel_http`) is
/// the opt-in redaction seam. Prefer [CustomEvent] for a provider's *declared*
/// structured extension (`name` + `value`); reach for [RawEvent] only for
/// genuinely opaque upstream passthrough.
///
/// [payload] compares deeply (freezed wraps the `Map` field with
/// `DeepCollectionEquality`), so two events carrying content-equal payloads are
/// `==`.
@freezed
abstract class RawEvent extends AgUiEvent with _$RawEvent {
  const RawEvent._() : super();

  /// Constructs a `RAW` passthrough event carrying the opaque [payload] and
  /// optional [source] tag.
  const factory RawEvent({
    required Map<String, dynamic> payload,
    String? source,
  }) = _RawEvent;

  /// Decodes a `RAW` wire payload. Reads the opaque object from wire key
  /// `event` into [payload] and the optional `source` tag. Throws
  /// [ProtocolError]`(protocolMalformed)` when `event` is absent or not a JSON
  /// object, or when `source` is present as a non-`String`.
  static RawEvent fromJson(Map<String, dynamic> json) => RawEvent(
    payload: _requireMap(json, 'event'),
    source: _optionalString(json, 'source'),
  );

  /// Serializes to the `RAW` wire shape.
  Map<String, dynamic> toJson() => {
    'type': 'RAW',
    'event': payload,
    if (source != null) 'source': source,
  };
}
