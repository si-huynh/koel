import 'dart:convert';
import 'dart:typed_data';

import 'package:freezed_annotation/freezed_annotation.dart';

import '../error/koel_error.dart';
import '../error/koel_error_code.dart';
import '../json_patch/json_patch_op.dart';
import '../message/message.dart';

part 'unknown_event.dart';
part 'event_codec.dart';
part 'run_events.dart';
part 'step_events.dart';
part 'text_message_events.dart';
part 'tool_call_events.dart';
part 'state_events.dart';
part 'activity_events.dart';
part 'reasoning_events.dart';
part 'ag_ui_event.freezed.dart';

/// Root of the AG-UI event union — the canonical stream element every
/// [AbstractAgent] emits.
///
/// `sealed` restricts subtyping to this library, so the set of event types is
/// closed and known at compile time: a `switch` over an [AgUiEvent] is
/// exhaustive, and `koel_lints`' `exhaustive_switch_must_have_default` forces
/// consumers to keep a `default:` arm — the seam that keeps their `switch`es
/// non-crashing when a minor version adds a member (forward-compat policy FC-2).
///
/// The `sealed` rule is also why every concrete subtype is a `part of` this
/// library (its own file under `lib/src/event/`, e.g. [UnknownAgUiEvent] in
/// `unknown_event.dart`) rather than an importing library: a sealed type can
/// only be extended within the library that declares it. Subtypes are
/// constructed from the wire by `deserializeAgUiEvent` in
/// `event_deserializer.dart`. The only subtype that always exists is
/// [UnknownAgUiEvent], the forward-compat fallback any unrecognized wire `type`
/// resolves to (FR-A6 / FC-1). The typed event families (`RUN_*`,
/// `TEXT_MESSAGE_*`, `TOOL_CALL_*`, …) join the union as parts in Stories
/// 2.5–2.8.
sealed class AgUiEvent {
  const AgUiEvent();
}
