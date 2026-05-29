import 'ag_ui_event.dart';

/// The single source of truth mapping an AG-UI wire `type` string to the
/// factory that decodes its payload into a concrete [AgUiEvent] — the "current
/// `koel_core` event registry" that FC-1 checks unknown events against.
///
/// A `const` map, edited at authoring time, is deliberate: there is no runtime
/// `register(...)` call, no mutable global, no init-order coupling. Stories
/// 2.5–2.8 grow the union by adding one entry per wire `type` here (e.g.
/// `'RUN_STARTED': RunStartedEvent.fromJson`); [deserializeAgUiEvent] needs no
/// other change. In this story the map is empty, so every wire `type` falls
/// through to [UnknownAgUiEvent].
const Map<String, AgUiEvent Function(Map<String, dynamic>)> eventTypeRegistry =
    {};

/// Decodes one raw AG-UI wire event into the typed [AgUiEvent] union.
///
/// Looks up `json['type']` in [eventTypeRegistry]: a registered `String` type
/// delegates to its factory; anything else — an unregistered type, a missing
/// `type` key, or a non-`String` `type` — returns
/// `UnknownAgUiEvent(type: …, rawJson: json)` and **never throws** (FR-A6 /
/// FC-1: the SDK does not crash on forward-compat or malformed-but-present wire
/// data). The fallback's `type` is the wire string, or `''` when absent or
/// non-`String`; `rawJson` is the input map verbatim, so the event round-trips
/// byte-for-byte.
///
/// Pure and synchronous. `koel_http`'s SSE parser (Epic 4) is a consumer of
/// this function, not a reimplementation — `koel_core` owns deserialization
/// because the pipeline and reducer operate without any transport.
///
/// **Ownership:** the returned event aliases `json` — `rawJson` holds the same
/// map (freezed wraps its top level unmodifiable, but nested maps/lists stay
/// shared). Callers must not retain or mutate `json` after the call; treat
/// ownership as transferred. `koel_http`'s SSE parser satisfies this by
/// decoding a fresh map per event. (No defensive copy is taken: it would cost
/// an allocation per event on budget phones for a guarantee real callers do
/// not need.)
AgUiEvent deserializeAgUiEvent(Map<String, dynamic> json) {
  final type = json['type'];
  if (type is String) {
    final factory = eventTypeRegistry[type];
    if (factory != null) return factory(json);
    return UnknownAgUiEvent(type: type, rawJson: json);
  }
  return UnknownAgUiEvent(type: '', rawJson: json);
}
