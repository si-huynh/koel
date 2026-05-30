part of 'ag_ui_event.dart';

/// Internal codec glue (not public surface): returns [json]'s [key] as a
/// `String`, or throws [ProtocolError]`(protocolMalformed)` when it is absent or
/// not a `String`. The shared required-member guard every hand-rolled event
/// `fromJson` calls — mirrors `JsonPatchOp.fromJson`'s `req` helper.
String _requireString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw ProtocolError(
    message: 'AG-UI event missing required string member: $key',
    code: KoelErrorCode.protocolMalformed,
    cause: json,
  );
}

/// Internal codec glue (not public surface): returns [json]'s [key] as a
/// `String?` — `null` when the member is absent or `null`, the `String` when
/// present, or throws [ProtocolError]`(protocolMalformed)` when present as a
/// non-`String`. The optional-member counterpart to [_requireString]: it keeps
/// the "malformed payload of a known type → `ProtocolError`" contract uniform
/// across required and optional fields, so a mistyped optional surfaces the same
/// typed error instead of leaking a raw `TypeError` from a bare `as String?`.
String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw ProtocolError(
    message: 'AG-UI event member is not a string: $key',
    code: KoelErrorCode.protocolMalformed,
    cause: json,
  );
}

/// Internal codec glue (not public surface): maps a wire `code` string to its
/// [KoelErrorCode] by `name`, falling back to [KoelErrorCode.unknown] for an
/// absent, non-`String`, or unrecognized code. Used only by [RunErrorEvent]'s
/// decoder; the original wire string is preserved separately in
/// `AgentError.agentCode`.
KoelErrorCode _koelErrorCodeFromWire(Object? raw) {
  if (raw is! String) return KoelErrorCode.unknown;
  return _koelErrorCodeByName[raw] ?? KoelErrorCode.unknown;
}

/// [KoelErrorCode] indexed by wire `name`, built once — an O(1) lookup replacing
/// a per-event linear scan over `KoelErrorCode.values` on the `RUN_ERROR` path.
final Map<String, KoelErrorCode> _koelErrorCodeByName = {
  for (final code in KoelErrorCode.values) code.name: code,
};
