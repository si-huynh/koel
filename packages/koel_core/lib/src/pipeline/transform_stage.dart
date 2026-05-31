import 'dart:async';

import '../event/ag_ui_event.dart';

/// Pipeline stage 4 — applies consumer-registered
/// `StreamTransformer<AgUiEvent, AgUiEvent>` instances in registration order,
/// **after** `applyStage` so transforms see the post-reduce stream (Addendum
/// F.4). This is the extension seam for PII redaction, language translation,
/// custom telemetry, and A/B event tagging.
///
/// Registration is via `KoelClient.transforms` (Story 2.14). With **no
/// transforms registered** this stage is a pure pass-through — the identity it
/// is today; its position as the final stage in the locked composition order is
/// its contract until then.
final StreamTransformer<AgUiEvent, AgUiEvent> transformStage =
    StreamTransformer.fromBind((events) => events);
