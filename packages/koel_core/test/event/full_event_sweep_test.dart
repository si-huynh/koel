import 'dart:convert';
import 'dart:io';

import 'package:koel_core/src/event/ag_ui_event.dart';
import 'package:koel_core/src/event/event_deserializer.dart';
import 'package:test/test.dart';

/// Story 2.8 integration sweep: one canonical wire example of every registered
/// AG-UI event type, exercised together. Proves the sealed [AgUiEvent] union is
/// closed end-to-end — every line lands on a typed subtype, round-trips, and
/// the registry has no orphans. `Directory.current` is the package root under
/// `dart test`, so the fixture path resolves from there.
void main() {
  group('full event sweep', () {
    final lines = File(
      'test/event/full_event_sweep.jsonl',
    ).readAsLinesSync().where((line) => line.trim().isNotEmpty).toList();

    test('fixture has one line per registered wire type', () {
      expect(lines.length, eventTypeRegistry.length);
    });

    test('every line deserializes to a non-Unknown typed subtype', () {
      for (final line in lines) {
        final json = jsonDecode(line) as Map<String, dynamic>;
        final event = deserializeAgUiEvent(json);
        expect(
          event,
          isNot(isA<UnknownAgUiEvent>()),
          reason: 'line did not map to a typed subtype: $line',
        );
      }
    });

    test(
      'every event round-trips through toJson() → fromJson() structurally',
      () {
        for (final line in lines) {
          final json = jsonDecode(line) as Map<String, dynamic>;
          final event = deserializeAgUiEvent(json);
          expect(
            deserializeAgUiEvent(_encode(event)),
            equals(event),
            reason: 'round-trip changed the event: $line',
          );
        }
      },
    );

    test('fixture covers every registered wire type with no orphans', () {
      final fixtureTypes = {
        for (final line in lines)
          (jsonDecode(line) as Map<String, dynamic>)['type'] as String,
      };
      expect(fixtureTypes, unorderedEquals(eventTypeRegistry.keys));
    });
  });
}

/// Re-encodes a [deserializeAgUiEvent] result (statically the sealed root) to
/// its wire JSON. The root declares no `toJson` — each subtype owns its codec —
/// so re-serialization dispatches over the union. The trailing `_` arm is the
/// forward-compat default `exhaustive_switch_must_have_default` requires; the
/// sweep never reaches it (every fixture line is a registered typed family,
/// never [UnknownAgUiEvent]).
Map<String, dynamic> _encode(AgUiEvent event) => switch (event) {
  RunStartedEvent() => event.toJson(),
  RunFinishedEvent() => event.toJson(),
  RunErrorEvent() => event.toJson(),
  StepStartedEvent() => event.toJson(),
  StepFinishedEvent() => event.toJson(),
  TextMessageStartEvent() => event.toJson(),
  TextMessageContentEvent() => event.toJson(),
  TextMessageEndEvent() => event.toJson(),
  TextMessageChunkEvent() => event.toJson(),
  ToolCallStartEvent() => event.toJson(),
  ToolCallArgsEvent() => event.toJson(),
  ToolCallEndEvent() => event.toJson(),
  ToolCallResultEvent() => event.toJson(),
  ToolCallChunkEvent() => event.toJson(),
  StateSnapshotEvent() => event.toJson(),
  StateDeltaEvent() => event.toJson(),
  MessagesSnapshotEvent() => event.toJson(),
  ActivitySnapshotEvent() => event.toJson(),
  ActivityDeltaEvent() => event.toJson(),
  ReasoningStartEvent() => event.toJson(),
  ReasoningEndEvent() => event.toJson(),
  ReasoningMessageStartEvent() => event.toJson(),
  ReasoningMessageContentEvent() => event.toJson(),
  ReasoningMessageEndEvent() => event.toJson(),
  ReasoningMessageChunkEvent() => event.toJson(),
  ReasoningEncryptedValueEvent() => event.toJson(),
  RawEvent() => event.toJson(),
  CustomEvent() => event.toJson(),
  _ => throw StateError(
    'sweep produced a non-typed event: ${event.runtimeType}',
  ),
};
