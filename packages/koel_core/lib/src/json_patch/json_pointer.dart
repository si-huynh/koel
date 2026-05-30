import '../error/koel_error.dart';
import '../error/koel_error_code.dart';

/// The RFC 6902 §4 "end-of-array" reference token (`-`) — the final token of an
/// `add`/`move`/`copy` target that means "append after the last array element".
/// Never a valid read index (see [parseArrayIndex]).
const String endOfArrayToken = '-';

/// Sentinel returned by [resolvePointer] when a reference cannot be resolved —
/// a parent along the path is absent, an array index is out of range, or a
/// token walks into a scalar. Distinct from a genuine JSON `null` value, which
/// resolves to `null`, so callers tell "absent" from "present-but-null" with
/// `identical(result, missing)`.
const Object missing = _Missing();

class _Missing {
  const _Missing();
}

/// Parses an RFC 6901 JSON Pointer into its reference tokens, unescaped.
///
/// `''` → `[]` (the whole document). A non-empty pointer must begin with `/`;
/// each `/`-separated segment is unescaped by replacing `~1`→`/` **then**
/// `~0`→`~` (RFC 6901 §4 mandates that order — decoding `~0` first would
/// mistranslate `~01`). `/` alone yields a single empty-string token (the `""`
/// object member).
///
/// Throws [ProtocolError]`(KoelErrorCode.protocolMalformed)` when a non-empty
/// pointer does not start with `/` — the only purely syntactic pointer error;
/// all *semantic* failures (missing target, bad index) surface later via
/// [resolvePointer]'s [missing] sentinel or the apply engine.
List<String> parseJsonPointer(String pointer) {
  if (pointer.isEmpty) return const [];
  if (!pointer.startsWith('/')) {
    throw ProtocolError(
      message: 'Invalid JSON Pointer (must be empty or start with "/")',
      code: KoelErrorCode.protocolMalformed,
      cause: pointer,
    );
  }
  return pointer
      .substring(1)
      .split('/')
      .map((t) => t.replaceAll('~1', '/').replaceAll('~0', '~'))
      .toList(growable: false);
}

/// Parses an array-index reference token per RFC 6901: a non-negative decimal
/// integer with **no leading zeros**. Returns the index, or `null` for any
/// token that is not a valid read index — including [endOfArrayToken], a
/// leading-zero form (`01`), a negative (`-1`), a fraction (`1.0`), a
/// non-numeric token, the empty string, or an all-digit token that overflows
/// the platform `int` (`int.tryParse` → `null`; matters on web, where `int` is
/// double-backed). Callers treat `null` as an out-of-range/invalid index, which
/// the apply engine surfaces as `ProtocolError(protocolMalformed)`.
int? parseArrayIndex(String token) {
  if (token.isEmpty) return null;
  if (token == '0') return 0;
  // Reject leading zero (anything starting with '0' that is not exactly "0").
  if (token.codeUnitAt(0) == 0x30) return null;
  for (final unit in token.codeUnits) {
    if (unit < 0x30 || unit > 0x39) return null;
  }
  // All-digit, no leading zero — int.tryParse fails only on overflow.
  return int.tryParse(token);
}

/// Walks [tokens] into [document] and returns the referenced value, or the
/// [missing] sentinel when the reference cannot be resolved. Never throws.
///
/// An empty [tokens] list returns [document] itself (the whole-document
/// reference). At each step the current node must be a `Map<String, dynamic>`
/// (member lookup) or a `List` (index lookup via [parseArrayIndex]); a missing
/// key, an out-of-range or non-integer index, or a walk into a scalar all yield
/// [missing]. A token resolving to JSON `null` returns `null`, not [missing].
Object? resolvePointer(Object? document, List<String> tokens) {
  Object? node = document;
  for (final token in tokens) {
    switch (node) {
      case final Map<String, dynamic> map when map.containsKey(token):
        node = map[token];
      case final List<dynamic> list:
        final index = parseArrayIndex(token);
        if (index == null || index >= list.length) return missing;
        node = list[index];
      default:
        return missing;
    }
  }
  return node;
}
