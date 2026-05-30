import '../error/koel_error.dart';
import '../error/koel_error_code.dart';
import 'json_patch_op.dart';
import 'json_pointer.dart';

/// Strict-mode RFC 6902 JSON Patch application — the vendor-inline replacement
/// for the stale `package:json_patch` (architecture AR-6 / Bonus decision).
///
/// Non-instantiable; the engine is the single static [apply].
class JsonPatch {
  const JsonPatch._();

  /// Applies [patches] to [document] in order and returns the resulting tree.
  ///
  /// **When to use:** folding a `STATE_DELTA`'s `patches` into a state map.
  /// AG-UI state is a JSON object, so callers pass a `Map<String, dynamic>` and
  /// cast the `Object?` result; the signature is `Object?` because RFC 6902
  /// allows array/scalar roots and a root-replacing op (`path: ""`) that changes
  /// the top-level type — which the conformance suite exercises.
  ///
  /// **Non-mutating + atomic:** [document] is deep-copied first and only the
  /// copy is mutated, so the caller's object graph is never touched. On the
  /// first failing op the copy is discarded and a [ProtocolError] is thrown —
  /// a partially-applied patch is never observable. This is the contract the
  /// reducer-purity test in Story 2.12 relies on.
  ///
  /// **Errors:** throws [ProtocolError]`(KoelErrorCode.protocolMalformed)` for
  /// any RFC violation — a missing target (`remove`/`replace`/`test`/`move`/
  /// `copy`), a failed `test`, an out-of-range or non-integer array index, a
  /// `move` into its own descendant, or a syntactically invalid pointer.
  ///
  /// ```dart
  /// final next = JsonPatch.apply(state, const [
  ///   AddOp(path: '/items/-', value: 'x'),
  ///   ReplaceOp(path: '/count', value: 3),
  /// ]) as Map<String, dynamic>;
  /// ```
  static Object? apply(Object? document, List<JsonPatchOp> patches) {
    var root = _deepCopy(document);
    for (final op in patches) {
      root = switch (op) {
        AddOp(:final path, :final value) => _add(
          root,
          parseJsonPointer(path),
          value,
          op,
        ),
        RemoveOp(:final path) => _remove(root, parseJsonPointer(path), op),
        ReplaceOp(:final path, :final value) => _replace(
          root,
          parseJsonPointer(path),
          value,
          op,
        ),
        MoveOp(:final from, :final path) => _move(root, from, path, op),
        CopyOp(:final from, :final path) => _copy(root, from, path, op),
        TestOp(:final path, :final value) => _test(
          root,
          parseJsonPointer(path),
          value,
          op,
        ),
      };
    }
    return root;
  }

  static Never _fail(String why, JsonPatchOp op) => throw ProtocolError(
    message: why,
    code: KoelErrorCode.protocolMalformed,
    cause: op,
  );

  /// Recursively clones JSON containers; scalars (immutable) pass through.
  ///
  /// A `Map` with a non-`String` key is not valid JSON, so it surfaces as a
  /// [ProtocolError]`(protocolMalformed)` rather than the raw `TypeError` an
  /// `as String` cast would throw — keeping `apply`'s single-error-type
  /// contract intact for documents built outside the `fromJson` path.
  static Object? _deepCopy(Object? node) {
    if (node is Map) {
      final copy = <String, dynamic>{};
      for (final entry in node.entries) {
        final key = entry.key;
        if (key is! String) {
          throw ProtocolError(
            message: 'JSON object key is not a string: $key',
            code: KoelErrorCode.protocolMalformed,
            cause: node,
          );
        }
        copy[key] = _deepCopy(entry.value);
      }
      return copy;
    }
    if (node is List) {
      return <dynamic>[for (final element in node) _deepCopy(element)];
    }
    return node;
  }

  static Object? _add(
    Object? root,
    List<String> tokens,
    Object? value,
    JsonPatchOp op,
  ) {
    if (tokens.isEmpty) return value; // RFC 6902: add to "" replaces the doc.
    final parent = resolvePointer(root, tokens.sublist(0, tokens.length - 1));
    final key = tokens.last;
    switch (parent) {
      case final Map<String, dynamic> map:
        map[key] = value;
      case final List<dynamic> list:
        if (key == endOfArrayToken) {
          list.add(value);
        } else {
          final index = parseArrayIndex(key);
          if (index == null || index > list.length) {
            _fail('add: invalid array index "$key"', op);
          }
          list.insert(index, value);
        }
      default:
        _fail('add: target parent does not exist', op);
    }
    return root;
  }

  static Object? _remove(Object? root, List<String> tokens, JsonPatchOp op) {
    if (tokens.isEmpty) _fail('remove: cannot remove the whole document', op);
    final parent = resolvePointer(root, tokens.sublist(0, tokens.length - 1));
    final key = tokens.last;
    switch (parent) {
      case final Map<String, dynamic> map when map.containsKey(key):
        map.remove(key);
      case final List<dynamic> list:
        final index = parseArrayIndex(key);
        if (index == null || index >= list.length) {
          _fail('remove: invalid array index "$key"', op);
        }
        list.removeAt(index);
      default:
        _fail('remove: target does not exist', op);
    }
    return root;
  }

  static Object? _replace(
    Object? root,
    List<String> tokens,
    Object? value,
    JsonPatchOp op,
  ) {
    // RFC 6902: replace at "" replaces the whole document.
    if (tokens.isEmpty) return value;
    final parent = resolvePointer(root, tokens.sublist(0, tokens.length - 1));
    final key = tokens.last;
    switch (parent) {
      case final Map<String, dynamic> map when map.containsKey(key):
        map[key] = value;
      case final List<dynamic> list:
        final index = parseArrayIndex(key);
        if (index == null || index >= list.length) {
          _fail('replace: invalid array index "$key"', op);
        }
        list[index] = value;
      default:
        _fail('replace: target does not exist', op);
    }
    return root;
  }

  static Object? _move(Object? root, String from, String path, JsonPatchOp op) {
    final fromTokens = parseJsonPointer(from);
    final pathTokens = parseJsonPointer(path);
    final moved = resolvePointer(root, fromTokens);
    if (identical(moved, missing)) _fail('move: "from" does not exist', op);
    if (_isProperPrefix(fromTokens, pathTokens)) {
      _fail('move: cannot move a location into its own child', op);
    }
    final removed = _remove(root, fromTokens, op);
    return _add(removed, pathTokens, moved, op);
  }

  static Object? _copy(Object? root, String from, String path, JsonPatchOp op) {
    final fromTokens = parseJsonPointer(from);
    final pathTokens = parseJsonPointer(path);
    final source = resolvePointer(root, fromTokens);
    if (identical(source, missing)) _fail('copy: "from" does not exist', op);
    return _add(root, pathTokens, _deepCopy(source), op);
  }

  static Object? _test(
    Object? root,
    List<String> tokens,
    Object? value,
    JsonPatchOp op,
  ) {
    final actual = resolvePointer(root, tokens);
    if (identical(actual, missing)) _fail('test: target does not exist', op);
    if (!_deepEquals(actual, value)) _fail('test: value mismatch', op);
    return root;
  }

  /// Whether [prefix] is a strict ancestor of [full] (every token matches and
  /// [full] is longer) — the RFC 6902 `move`-into-own-child guard.
  static bool _isProperPrefix(List<String> prefix, List<String> full) {
    if (prefix.length >= full.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (prefix[i] != full[i]) return false;
    }
    return true;
  }

  /// Structural equality over decoded-JSON values (maps unordered, lists
  /// ordered, scalars via `==` so `1 == 1.0`). Hand-rolled to keep `koel_core`
  /// dependency-free; mirrors `DeepCollectionEquality` semantics for JSON.
  static bool _deepEquals(Object? a, Object? b) {
    if (identical(a, b)) return true;
    if (a is Map && b is Map) {
      if (a.length != b.length) return false;
      for (final key in a.keys) {
        if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) return false;
      }
      return true;
    }
    if (a is List && b is List) {
      if (a.length != b.length) return false;
      for (var i = 0; i < a.length; i++) {
        if (!_deepEquals(a[i], b[i])) return false;
      }
      return true;
    }
    return a == b;
  }
}
