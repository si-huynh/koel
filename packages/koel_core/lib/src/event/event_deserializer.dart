import 'ag_ui_event.dart';

/// The single source of truth mapping an AG-UI wire `type` string to the
/// factory that decodes its payload into a concrete [AgUiEvent] — the "current
/// `koel_core` event registry" that FC-1 checks unknown events against.
///
/// A `const` map, edited at authoring time, is deliberate: there is no runtime
/// `register(...)` call, no mutable global, no init-order coupling. Stories
/// 2.5–2.8 grow the union by adding one entry per wire `type` here; the value
/// is a `static fromJson` tear-off (a compile-time constant) and
/// [deserializeAgUiEvent] needs no other change. Story 2.5 registered the nine
/// lifecycle + text-message types; Story 2.6 added the eight tool-call + state +
/// messages-snapshot types; Story 2.7 adds the nine activity + reasoning types
/// (26 of the ~28-type union — `RAW` + `CUSTOM` remain for Story 2.8). Any wire
/// `type` not listed here — including the deprecated upstream `THINKING_*`
/// aliases koel deliberately does not model — still falls through to
/// [UnknownAgUiEvent].
const Map<String, AgUiEvent Function(Map<String, dynamic>)> eventTypeRegistry =
    {
      'RUN_STARTED': RunStartedEvent.fromJson,
      'RUN_FINISHED': RunFinishedEvent.fromJson,
      'RUN_ERROR': RunErrorEvent.fromJson,
      'STEP_STARTED': StepStartedEvent.fromJson,
      'STEP_FINISHED': StepFinishedEvent.fromJson,
      'TEXT_MESSAGE_START': TextMessageStartEvent.fromJson,
      'TEXT_MESSAGE_CONTENT': TextMessageContentEvent.fromJson,
      'TEXT_MESSAGE_END': TextMessageEndEvent.fromJson,
      'TEXT_MESSAGE_CHUNK': TextMessageChunkEvent.fromJson,
      'TOOL_CALL_START': ToolCallStartEvent.fromJson,
      'TOOL_CALL_ARGS': ToolCallArgsEvent.fromJson,
      'TOOL_CALL_END': ToolCallEndEvent.fromJson,
      'TOOL_CALL_RESULT': ToolCallResultEvent.fromJson,
      'TOOL_CALL_CHUNK': ToolCallChunkEvent.fromJson,
      'STATE_SNAPSHOT': StateSnapshotEvent.fromJson,
      'STATE_DELTA': StateDeltaEvent.fromJson,
      'MESSAGES_SNAPSHOT': MessagesSnapshotEvent.fromJson,
      'ACTIVITY_SNAPSHOT': ActivitySnapshotEvent.fromJson,
      'ACTIVITY_DELTA': ActivityDeltaEvent.fromJson,
      'REASONING_START': ReasoningStartEvent.fromJson,
      'REASONING_END': ReasoningEndEvent.fromJson,
      'REASONING_MESSAGE_START': ReasoningMessageStartEvent.fromJson,
      'REASONING_MESSAGE_CONTENT': ReasoningMessageContentEvent.fromJson,
      'REASONING_MESSAGE_END': ReasoningMessageEndEvent.fromJson,
      'REASONING_MESSAGE_CHUNK': ReasoningMessageChunkEvent.fromJson,
      'REASONING_ENCRYPTED_VALUE': ReasoningEncryptedValueEvent.fromJson,
    };

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
