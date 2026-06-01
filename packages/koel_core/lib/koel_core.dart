/// AG-UI protocol kernel for Dart — the framework-free core every other koel
/// package builds on.
///
/// This barrel is the **public 1.x contract** of `koel_core`: every symbol
/// reachable through it is a one-way door (AR-15 / NFR-13). It surfaces the
/// three-layer client API, the sealed `AgUiEvent` union, the sealed `KoelError`
/// hierarchy, the `ChatState` reduction seam, session persistence, and the
/// value-level protocol types (events, messages, tools, JSON Patch operations) —
/// and deliberately **nothing else**. The wire deserializer and the JSON Patch
/// *applier* are kernel machinery: consumers reach them through
/// `KoelClient`/`ChatSession`, never directly, so they stay in `lib/src/` off
/// the contract. The pipeline stays internal too, with **one** carve-out:
/// `chunksStage`, the `*_CHUNK` → `START`/`CONTENT`/`END` synthesizer, is public
/// because a sibling *transport* package (`koel_http`, `HttpAgent.synthesizeChunks`,
/// Addendum F.2) must reuse the single F.2 source of truth rather than fork it.
/// `verifyStage`/`applyStage`/`transformStage` remain internal — nothing outside
/// the pipeline composes them.
///
/// Import this file — never a `package:koel_core/src/...` path (the internals
/// are unstable across minor versions). Exports are grouped by subsystem in
/// dependency order.
library;

// ---- Client: the three-layer consumable API (F-A2) ------------------------
// koel_client.dart `part`s in chat_session.dart, so this single export surfaces
// KoelClient, BackpressurePolicy, and ChatSession together.
export 'src/client/koel_client.dart';

// ---- Agent: the backend-bridge SPI and its wiring seams -------------------
export 'src/agent/abstract_agent.dart';
export 'src/agent/agent_subscriber.dart';
export 'src/agent/interceptor.dart';

// ---- Event: the sealed AG-UI union --------------------------------------
// ag_ui_event.dart `part`s in every concrete subtype (the ~28 typed families +
// UnknownAgUiEvent) and the private wire codec, so this single export surfaces
// the whole closed union. The event registry and top-level deserializer
// (event_deserializer.dart) stay internal — consumers receive typed events from
// the stream — but `AgUiEvent.fromWire` is the public decode seam for
// stored-trace tooling (koel_test's FixtureLoader, koel_devtools replay). It
// surfaces automatically with the already-exported AgUiEvent; no extra export.
export 'src/event/ag_ui_event.dart';

// ---- Error: the sealed failure hierarchy + classification seam ------------
export 'src/error/error_classifier.dart';
export 'src/error/koel_error.dart';
export 'src/error/koel_error_code.dart';

// ---- State: the folded ChatState and its reduction seam -------------------
export 'src/state/chat_state.dart';
export 'src/state/chat_state_reducer.dart';
export 'src/state/composed_reducer.dart';
export 'src/state/state_conflict.dart';
export 'src/state/tool_call.dart';

// ---- Session: persistence contract + the in-memory default ----------------
export 'src/session/in_memory_session_storage.dart';
export 'src/session/session_storage.dart';

// ---- Input / message / tool: the value-level protocol types ---------------
export 'src/input/run_agent_input.dart';
export 'src/message/message.dart';
export 'src/tool/tool_definition.dart';

// ---- JSON Patch: the operation union carried by STATE_DELTA ----------------
// Only the value-level operations (JsonPatchOp + subtypes) are public — they
// appear in StateDeltaEvent.patches and StateConflict.incomingPatches. The
// applier (JsonPatch) and pointer (JsonPointer) stay internal.
export 'src/json_patch/json_patch_op.dart';

// ---- Pipeline: the transport-reusable chunk synthesizer -------------------
// `chunksStage` is the ONE pipeline stage on the public contract: a sibling
// transport (koel_http's `HttpAgent.synthesizeChunks`) reuses this single
// Addendum F.2 source of truth instead of forking the envelope logic. verify/
// apply/transform stay internal (lib/src/) — they are reached through the
// client, never composed directly.
export 'src/pipeline/chunks_stage.dart';
