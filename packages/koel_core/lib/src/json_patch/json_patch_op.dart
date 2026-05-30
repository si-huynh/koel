import 'package:freezed_annotation/freezed_annotation.dart';

import '../error/koel_error.dart';
import '../error/koel_error_code.dart';

part 'json_patch_op.freezed.dart';

/// One RFC 6902 JSON Patch operation — the typed, value-comparable unit a
/// `STATE_DELTA` carries (`StateDeltaEvent.patches: List<JsonPatchOp>`, Story
/// 2.6) and [JsonPatch.apply] folds into a state document.
///
/// The union is sealed and closed at compile time:
/// `{ AddOp, RemoveOp, ReplaceOp, MoveOp, CopyOp, TestOp }` — one subtype per
/// RFC 6902 §4 operation. Unlike [KoelError]/`AgUiEvent`, this is an internal
/// apply-engine type, **not** a consumer-facing forward-compat surface, so it
/// is deliberately absent from `koel_lints`' exhaustive-switch name set; a
/// `switch` over it needs no `default:`.
///
/// Each subtype is freezed-generated for structural `==`/`hashCode`/`copyWith`;
/// the `value` fields are `Object?` (an arbitrary decoded-JSON value) compared
/// **deeply** via freezed's `DeepCollectionEquality`. Construct via a subtype's
/// `const` factory or decode wire JSON via [JsonPatchOp.fromJson]; serialize via
/// [toJson]. (De)serialization is hand-rolled rather than `json_serializable`:
/// RFC 6902 is a discriminated union keyed on `op`, which the generator does not
/// model cleanly — so this library emits only `*.freezed.dart`, no `*.g.dart`.
sealed class JsonPatchOp {
  const JsonPatchOp();

  /// Decodes one wire patch operation, dispatching on the RFC 6902 `op`
  /// discriminator.
  ///
  /// Throws [ProtocolError]`(KoelErrorCode.protocolMalformed)` when `op` is
  /// missing/unrecognized or a member the op requires is absent — `path` (all
  /// ops), `value` (`add`/`replace`/`test`), or `from` (`move`/`copy`). A
  /// present-but-`null` `value` is preserved (RFC distinguishes "member absent"
  /// from "member is JSON null").
  factory JsonPatchOp.fromJson(Map<String, dynamic> json) {
    Never malformed(String why) => throw ProtocolError(
      message: why,
      code: KoelErrorCode.protocolMalformed,
      cause: json,
    );

    String req(String k) {
      final v = json[k];
      if (v is String) return v;
      malformed('JSON Patch op missing required string member: $k');
    }

    Object? reqValue() => json.containsKey('value')
        ? json['value']
        : malformed('JSON Patch op missing required member: value');

    return switch (json['op']) {
      'add' => AddOp(path: req('path'), value: reqValue()),
      'remove' => RemoveOp(path: req('path')),
      'replace' => ReplaceOp(path: req('path'), value: reqValue()),
      'move' => MoveOp(from: req('from'), path: req('path')),
      'copy' => CopyOp(from: req('from'), path: req('path')),
      'test' => TestOp(path: req('path'), value: reqValue()),
      final op => malformed('Unknown JSON Patch op: $op'),
    };
  }

  /// Serializes back to the RFC 6902 wire shape (`{'op': …, 'path': …, …}`),
  /// the inverse of [JsonPatchOp.fromJson]. Consumed by `StateDeltaEvent`'s wire
  /// codec in Story 2.6.
  Map<String, dynamic> toJson();
}

/// RFC 6902 `add`: inserts [value] at [path] — replacing an existing object
/// member, inserting into an array (shifting later elements), appending when the
/// final token is `-`, or replacing the whole document when [path] is `""`.
@freezed
abstract class AddOp extends JsonPatchOp with _$AddOp {
  const AddOp._() : super();

  const factory AddOp({required String path, Object? value}) = _AddOp;

  @override
  Map<String, dynamic> toJson() => {'op': 'add', 'path': path, 'value': value};
}

/// RFC 6902 `remove`: deletes the value at [path]. The target must exist.
@freezed
abstract class RemoveOp extends JsonPatchOp with _$RemoveOp {
  const RemoveOp._() : super();

  const factory RemoveOp({required String path}) = _RemoveOp;

  @override
  Map<String, dynamic> toJson() => {'op': 'remove', 'path': path};
}

/// RFC 6902 `replace`: sets the value at [path] to [value]. Equivalent to a
/// `remove` followed by an `add`; the target must already exist.
@freezed
abstract class ReplaceOp extends JsonPatchOp with _$ReplaceOp {
  const ReplaceOp._() : super();

  const factory ReplaceOp({required String path, Object? value}) = _ReplaceOp;

  @override
  Map<String, dynamic> toJson() => {
    'op': 'replace',
    'path': path,
    'value': value,
  };
}

/// RFC 6902 `move`: removes the value at [from] and adds it at [path]. [from]
/// must exist and must not be a proper prefix of [path] (a location cannot be
/// moved into one of its own children).
@freezed
abstract class MoveOp extends JsonPatchOp with _$MoveOp {
  const MoveOp._() : super();

  const factory MoveOp({required String from, required String path}) = _MoveOp;

  @override
  Map<String, dynamic> toJson() => {'op': 'move', 'from': from, 'path': path};
}

/// RFC 6902 `copy`: deep-copies the value at [from] and adds it at [path].
/// [from] must exist.
@freezed
abstract class CopyOp extends JsonPatchOp with _$CopyOp {
  const CopyOp._() : super();

  const factory CopyOp({required String from, required String path}) = _CopyOp;

  @override
  Map<String, dynamic> toJson() => {'op': 'copy', 'from': from, 'path': path};
}

/// RFC 6902 `test`: asserts the value at [path] is deeply equal to [value].
/// A mismatch (or a missing [path]) fails the entire patch.
@freezed
abstract class TestOp extends JsonPatchOp with _$TestOp {
  const TestOp._() : super();

  const factory TestOp({required String path, Object? value}) = _TestOp;

  @override
  Map<String, dynamic> toJson() => {'op': 'test', 'path': path, 'value': value};
}
