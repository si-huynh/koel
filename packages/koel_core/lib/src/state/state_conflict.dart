import 'package:freezed_annotation/freezed_annotation.dart';

import '../error/koel_error.dart';
import '../error/koel_error_code.dart';
import '../json_patch/json_patch.dart';
import '../json_patch/json_patch_op.dart';

part 'state_conflict.freezed.dart';

/// A detected state divergence: a `STATE_DELTA` whose [incomingPatches] touch a
/// path the consumer mutated locally since the last `STATE_SNAPSHOT` (F-A8).
///
/// The apply stage builds this and hands it to the registered
/// [StateConflictResolver] (Story 2.14 wiring); the resolver's output replaces
/// the conflicting slice of the next `ChatState.state` (Addendum C.1 step 3).
/// An in-memory descriptor only — never serialized — so it is freezed with no
/// JSON codec, mirroring `ChatState`. [incomingPatches] and both maps compare
/// deeply (freezed `DeepCollectionEquality`).
///
/// [localState] is the current state carrying the local mutations;
/// [snapshotState] is the state as of the last snapshot (the common ancestor a
/// merge resolver diffs against — the default [LastWriterWinsResolver] ignores
/// it).
@freezed
abstract class StateConflict with _$StateConflict {
  const factory StateConflict({
    required List<JsonPatchOp> incomingPatches,
    required Map<String, dynamic> localState,
    required Map<String, dynamic> snapshotState,
  }) = _StateConflict;
}

/// The F-A8 resolution policy: given a detected [StateConflict], returns the
/// state map the next `ChatState.state` should carry.
///
/// Pure and synchronous — no I/O, no state of its own. This is the seam
/// consumers swap to inject a custom strategy (e.g. a three-way merge that reads
/// [StateConflict.snapshotState]); the SDK default is [LastWriterWinsResolver].
abstract class StateConflictResolver {
  Map<String, dynamic> resolve(StateConflict conflict);
}

/// The default [StateConflictResolver]: the incoming delta is the last writer,
/// so it wins. Applies [StateConflict.incomingPatches] **verbatim** onto
/// [StateConflict.localState] via [JsonPatch.apply] — no merge against the
/// snapshot. (`snapshotState` exists for smarter resolvers; this one ignores
/// it.) This makes conflict resolution a no-op relative to plain application:
/// the conflict machinery exists so *other* resolvers can do better.
///
/// **Throws** [ProtocolError]`(protocolMalformed)` when the patches are
/// inapplicable to `localState`, or when a root-replacing op yields a non-object
/// root (`JsonPatch.apply` returns `Object?`; a resolved state must be a JSON
/// object). Unlike `DefaultChatStateReducer`, `resolve` returns a bare `Map` and
/// has nowhere to fold an error, so it propagates — the apply-stage wiring
/// (Story 2.14) catches it and folds it into `ChatState.error`, exactly as the
/// reducer's `STATE_DELTA` branch already does.
class LastWriterWinsResolver implements StateConflictResolver {
  const LastWriterWinsResolver();

  @override
  Map<String, dynamic> resolve(StateConflict conflict) {
    final next = JsonPatch.apply(conflict.localState, conflict.incomingPatches);
    if (next is! Map<String, dynamic>) {
      throw ProtocolError(
        message: 'STATE_DELTA replaced the state root with a non-object',
        code: KoelErrorCode.protocolMalformed,
        cause: conflict.incomingPatches,
      );
    }
    return next;
  }
}
