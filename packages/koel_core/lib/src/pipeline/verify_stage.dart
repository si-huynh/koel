import 'dart:async';
import 'dart:convert';

import '../error/koel_error.dart';
import '../error/koel_error_code.dart';
import '../event/ag_ui_event.dart';
import 'stage_support.dart';

/// Pipeline stage 2 — cross-event protocol sanity over the already-synthesized,
/// already-typed stream (Addendum F.1). Runs **after** `chunksStage` so it sees
/// the `START`/`END` pairs chunk synthesis creates.
///
/// **On a violation** the offending event is **dropped** and a
/// `RunErrorEvent(ProtocolError(code: protocolMalformed, eventType: …))` is
/// emitted in its place. The stage never throws — a protocol violation is in-band
/// run data the consumer must see, not a programmer error (architecture §5; the
/// same no-throw invariant `InterceptorChain` upholds for thrown failures). Every
/// valid event passes through untouched.
///
/// **Rules enforced** (each drops + emits a `ProtocolError`):
/// - a [ToolCallEndEvent] whose `toolCallId` never had a matching
///   [ToolCallStartEvent] (orphan end);
/// - a [ToolCallArgsEvent] outside an open `START`/`END` envelope;
/// - a [StateDeltaEvent] carrying no patch operations;
/// - a [TextMessageStartEvent]/[TextMessageContentEvent]/[TextMessageEndEvent]
///   with an empty `messageId`;
/// - a [ReasoningEncryptedValueEvent] whose bytes do not decode from the base64
///   sibling it carries.
///
/// **Not re-validated here** (already guaranteed upstream, so re-checking would
/// be dead branches): individual RFC 6902 op validity (enforced by
/// `JsonPatchOp.fromJson` at decode — verify only checks *emptiness*),
/// required-field *presence* (the typed `fromJson` factories already rejected
/// absent ids — verify checks the *empty-string* degenerate that survives
/// `_requireString`), and raw JSON wire-shape (the SSE parser in `koel_http`).
///
/// **Lifecycle.** Stateful per subscription (the open-`START` id set),
/// single-subscription, cancellation/backpressure-correct via [buildStage].
final StreamTransformer<AgUiEvent, AgUiEvent> verifyStage = buildStage(
  _VerifyStage.new,
);

class _VerifyStage extends PipelineStage {
  final Set<String> _openToolCalls = {};

  @override
  void onEvent(AgUiEvent event, EventSink<AgUiEvent> out) {
    switch (event) {
      case ToolCallStartEvent(:final toolCallId):
        _openToolCalls.add(toolCallId);
        out.add(event);
      case ToolCallEndEvent(:final toolCallId):
        out.add(
          _openToolCalls.remove(toolCallId)
              ? event
              : _malformed(
                  'TOOL_CALL_END has no matching TOOL_CALL_START',
                  'TOOL_CALL_END',
                ),
        );
      case ToolCallArgsEvent(:final toolCallId):
        out.add(
          _openToolCalls.contains(toolCallId)
              ? event
              : _malformed(
                  'TOOL_CALL_ARGS arrived outside a START/END envelope',
                  'TOOL_CALL_ARGS',
                ),
        );
      case StateDeltaEvent(:final patches):
        out.add(
          patches.isEmpty
              ? _malformed(
                  'STATE_DELTA carries no patch operations',
                  'STATE_DELTA',
                )
              : event,
        );
      case TextMessageStartEvent(:final messageId):
        out.add(
          messageId.isEmpty
              ? _malformed(
                  'TEXT_MESSAGE_START is missing a messageId',
                  'TEXT_MESSAGE_START',
                )
              : event,
        );
      case TextMessageContentEvent(:final messageId):
        out.add(
          messageId.isEmpty
              ? _malformed(
                  'TEXT_MESSAGE_CONTENT is missing a messageId',
                  'TEXT_MESSAGE_CONTENT',
                )
              : event,
        );
      case TextMessageEndEvent(:final messageId):
        out.add(
          messageId.isEmpty
              ? _malformed(
                  'TEXT_MESSAGE_END is missing a messageId',
                  'TEXT_MESSAGE_END',
                )
              : event,
        );
      case ReasoningEncryptedValueEvent():
        out.add(
          _encryptedValueRoundTrips(event)
              ? event
              : _malformed(
                  'REASONING_ENCRYPTED_VALUE bytes do not decode from the '
                      'base64 sibling',
                  'REASONING_ENCRYPTED_VALUE',
                ),
        );
      default:
        out.add(event);
    }
  }
}

RunErrorEvent _malformed(String message, String eventType) => RunErrorEvent(
  error: ProtocolError(
    message: message,
    code: KoelErrorCode.protocolMalformed,
    eventType: eventType,
  ),
);

/// Whether the event's bytes decode from the base64 string it carries. Decodes
/// the held string and compares byte-for-byte rather than re-encoding the bytes —
/// `base64Encode(base64Decode(s))` is not always `s` (padding/whitespace
/// canonicalization), so a re-encode comparison would false-positive on a
/// non-canonical-but-valid wire string. A malformed base64 string (only
/// reachable for an event built off-wire by a buggy adapter, not via `fromJson`)
/// counts as a mismatch.
bool _encryptedValueRoundTrips(ReasoningEncryptedValueEvent event) {
  final List<int> decoded;
  try {
    decoded = base64Decode(event.encryptedValueBase64);
  } on FormatException {
    return false;
  }
  final bytes = event.encryptedValue;
  if (decoded.length != bytes.length) return false;
  for (var i = 0; i < decoded.length; i++) {
    if (decoded[i] != bytes[i]) return false;
  }
  return true;
}
