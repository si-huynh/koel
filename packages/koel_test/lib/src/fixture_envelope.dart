import 'dart:convert';

/// Decodes one fixture event line into its wire-`type` label and `payload`
/// object, throwing a [source]-naming [FormatException] — never an opaque
/// `TypeError` — when the `{type, timestamp, payload}` envelope is corrupt.
///
/// The shared guard behind both `FixtureLoader`'s and `ConformanceRunner`'s
/// per-line decode. It became reachable in Epic 5: live captures can emit a
/// partial/truncated line (a valid-JSON line that is not an object, lacks a
/// `payload`, has a non-object `payload`, or whose `payload.type` is absent or
/// not a `String`) — the 3.3 + 3.5 deferral cluster. Before this guard those
/// shapes surfaced as an unchecked-cast `TypeError` with no fixture context.
///
/// [source] names the fixture or corpus (e.g. `fixture "text_only_run"`),
/// [lineNo] is the 1-based event-line index, and the raw [line] rides the
/// thrown exception's `source` for an actionable message. Invalid JSON throws
/// its own (already loud) `FormatException` from [jsonDecode] before this guard.
({String type, Map<String, dynamic> payload}) decodeFixtureEvent(
  String source,
  int lineNo,
  String line,
) {
  final decoded = jsonDecode(line);
  if (decoded is! Map<String, dynamic>) {
    throw FormatException(
      '$source line $lineNo: event line is not a JSON object',
      line,
    );
  }
  final payload = decoded['payload'];
  if (payload is! Map<String, dynamic>) {
    throw FormatException(
      '$source line $lineNo: missing or non-object `payload`',
      line,
    );
  }
  final type = payload['type'];
  if (type is! String) {
    throw FormatException(
      '$source line $lineNo: payload `type` is missing or not a String',
      line,
    );
  }
  return (type: type, payload: payload);
}
