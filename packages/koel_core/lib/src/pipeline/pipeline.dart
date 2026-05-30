import 'dart:async';

import '../event/ag_ui_event.dart';
import 'apply_stage.dart';
import 'chunks_stage.dart';
import 'transform_stage.dart';
import 'verify_stage.dart';

/// Runs [events] through the four-stage event pipeline in its **locked** order —
/// chunks → verify → apply → transform (FR-A11 / Addendum C.1) — and returns the
/// canonical stream every consumer sees.
///
/// The order is load-bearing and fixed: [chunksStage] synthesizes the `START`/
/// `END` pairs that [verifyStage] validates, so chunks must precede verify;
/// [applyStage] folds reducer state over the verified stream; [transformStage]
/// applies consumer transforms over the post-reduce stream. This is the single
/// site that composition lives, so the order is defined and tested in one place.
///
/// A pure `Stream<AgUiEvent>` → `Stream<AgUiEvent>` function: it knows nothing of
/// transport, persistence, or UI. `KoelClient` invokes it on the
/// post-interceptor stream.
///
/// [apply] swaps the apply stage (stage 3) so the two top-level consumers can
/// share this one backbone: `KoelClient.runRaw` passes nothing → the identity
/// [applyStage] (no reducer); `ChatSession` passes `reducingApplyStage(...)` →
/// the reducer fold. The chunks → verify → apply → transform order stays locked
/// in this single site regardless, so the order-assertion test guards it for
/// both paths.
Stream<AgUiEvent> runPipeline(
  Stream<AgUiEvent> events, {
  StreamTransformer<AgUiEvent, AgUiEvent>? apply,
}) => events
    .transform(chunksStage)
    .transform(verifyStage)
    .transform(apply ?? applyStage)
    .transform(transformStage);
