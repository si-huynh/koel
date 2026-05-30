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

/// Internal codec glue (not public surface): returns [json]'s [key] as a
/// `Map<String, dynamic>`, or throws [ProtocolError]`(protocolMalformed)` when
/// it is absent or not a JSON object. The object-member counterpart to
/// [_requireString] — used for `STATE_SNAPSHOT.snapshot`, whose payload is a
/// state document the downstream reducer folds patches onto.
Map<String, dynamic> _requireMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  throw ProtocolError(
    message: 'AG-UI event missing required object member: $key',
    code: KoelErrorCode.protocolMalformed,
    cause: json,
  );
}

/// Internal codec glue (not public surface): decodes [json]'s [key] — a wire
/// array of JSON objects — into a `List<T>` by running each element through
/// [decode]. Throws [ProtocolError]`(protocolMalformed)` when the member is
/// absent, not a `List`, or holds an element that is not a
/// `Map<String, dynamic>`; an empty array decodes to an empty list (no throw).
/// If [decode] itself throws, a [ProtocolError] propagates unchanged (preserving
/// the leaf codec's precise message) while any other error — e.g. a raw
/// `TypeError`/`FormatException`/`ArgumentError` from a json_serializable leaf
/// such as [Message] — is normalized to [ProtocolError]`(protocolMalformed)`
/// carrying the original as `cause`, so a malformed element never leaks a raw
/// error past the codec boundary. The shared list-of-objects guard for
/// `STATE_DELTA.delta` (→ [JsonPatchOp]) and `MESSAGES_SNAPSHOT.messages`
/// (→ [Message]): every wire cast that can fail on malformed input raises the
/// typed error rather than leaking a raw `TypeError`.
List<T> _decodeObjectList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) decode,
) {
  final value = json[key];
  if (value is! List) {
    throw ProtocolError(
      message: 'AG-UI event missing required array member: $key',
      code: KoelErrorCode.protocolMalformed,
      cause: json,
    );
  }
  final result = <T>[];
  for (final element in value) {
    if (element is! Map<String, dynamic>) {
      throw ProtocolError(
        message: 'AG-UI event array member is not an object: $key',
        code: KoelErrorCode.protocolMalformed,
        cause: json,
      );
    }
    try {
      result.add(decode(element));
    } on ProtocolError {
      rethrow;
    } catch (error) {
      throw ProtocolError(
        message: 'AG-UI event array member could not be decoded: $key',
        code: KoelErrorCode.protocolMalformed,
        cause: error,
      );
    }
  }
  return result;
}

/// Internal codec glue (not public surface): returns [json]'s [key] as a
/// `bool?` — `null` when the member is absent or `null`, the `bool` when
/// present, or throws [ProtocolError]`(protocolMalformed)` when present as a
/// non-`bool`. The boolean counterpart to [_optionalString]: an optional wire
/// flag (e.g. `ACTIVITY_SNAPSHOT.replace`) stays absent-preserving so the
/// round-trip is lossless and any wire-applied default is left to the consumer,
/// while a mistyped flag surfaces the typed error instead of a raw `TypeError`.
bool? _optionalBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is bool) return value;
  throw ProtocolError(
    message: 'AG-UI event member is not a bool: $key',
    code: KoelErrorCode.protocolMalformed,
    cause: json,
  );
}

/// Internal codec glue (not public surface): decodes a base64 [wire] string to
/// its bytes, or throws [ProtocolError]`(protocolMalformed)` when it is not valid
/// base64 — never leaking the raw `FormatException` past the codec boundary (the
/// SF-1 lesson applied to the binary path). Used by
/// [ReasoningEncryptedValueEvent], whose decoded `Uint8List` feeds the typed
/// `reasoningEcho` surface while the original string is preserved verbatim for a
/// byte-exact wire round-trip (FR-A9). `base64Decode` is the *normalizing*
/// decoder: it accepts **both** the standard (`+`/`/`) and url-safe (`-`/`_`)
/// alphabets, so a base64url payload is decoded, not rejected — the decoded bytes
/// may carry a url-safe interpretation while the verbatim `encryptedValueBase64`
/// keeps the round-trip byte-exact regardless of alphabet. (This is *why* the
/// blob is never re-encoded from the bytes; see [ReasoningEncryptedValueEvent].)
Uint8List _decodeBase64(String wire) {
  try {
    return base64Decode(wire);
  } on FormatException catch (error) {
    throw ProtocolError(
      message: 'AG-UI event encryptedValue is not valid base64',
      code: KoelErrorCode.protocolMalformed,
      cause: error,
    );
  }
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
