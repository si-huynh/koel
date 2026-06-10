// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'state_conflict.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$StateConflict {

 List<JsonPatchOp> get incomingPatches; Map<String, dynamic> get localState; Map<String, dynamic> get snapshotState;
/// Create a copy of StateConflict
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StateConflictCopyWith<StateConflict> get copyWith => _$StateConflictCopyWithImpl<StateConflict>(this as StateConflict, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StateConflict&&const DeepCollectionEquality().equals(other.incomingPatches, incomingPatches)&&const DeepCollectionEquality().equals(other.localState, localState)&&const DeepCollectionEquality().equals(other.snapshotState, snapshotState));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(incomingPatches),const DeepCollectionEquality().hash(localState),const DeepCollectionEquality().hash(snapshotState));

@override
String toString() {
  return 'StateConflict(incomingPatches: $incomingPatches, localState: $localState, snapshotState: $snapshotState)';
}


}

/// @nodoc
abstract mixin class $StateConflictCopyWith<$Res>  {
  factory $StateConflictCopyWith(StateConflict value, $Res Function(StateConflict) _then) = _$StateConflictCopyWithImpl;
@useResult
$Res call({
 List<JsonPatchOp> incomingPatches, Map<String, dynamic> localState, Map<String, dynamic> snapshotState
});




}
/// @nodoc
class _$StateConflictCopyWithImpl<$Res>
    implements $StateConflictCopyWith<$Res> {
  _$StateConflictCopyWithImpl(this._self, this._then);

  final StateConflict _self;
  final $Res Function(StateConflict) _then;

/// Create a copy of StateConflict
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? incomingPatches = null,Object? localState = null,Object? snapshotState = null,}) {
  return _then(_self.copyWith(
incomingPatches: null == incomingPatches ? _self.incomingPatches : incomingPatches // ignore: cast_nullable_to_non_nullable
as List<JsonPatchOp>,localState: null == localState ? _self.localState : localState // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,snapshotState: null == snapshotState ? _self.snapshotState : snapshotState // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [StateConflict].
extension StateConflictPatterns on StateConflict {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StateConflict value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StateConflict() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StateConflict value)  $default,){
final _that = this;
switch (_that) {
case _StateConflict():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StateConflict value)?  $default,){
final _that = this;
switch (_that) {
case _StateConflict() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<JsonPatchOp> incomingPatches,  Map<String, dynamic> localState,  Map<String, dynamic> snapshotState)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StateConflict() when $default != null:
return $default(_that.incomingPatches,_that.localState,_that.snapshotState);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<JsonPatchOp> incomingPatches,  Map<String, dynamic> localState,  Map<String, dynamic> snapshotState)  $default,) {final _that = this;
switch (_that) {
case _StateConflict():
return $default(_that.incomingPatches,_that.localState,_that.snapshotState);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<JsonPatchOp> incomingPatches,  Map<String, dynamic> localState,  Map<String, dynamic> snapshotState)?  $default,) {final _that = this;
switch (_that) {
case _StateConflict() when $default != null:
return $default(_that.incomingPatches,_that.localState,_that.snapshotState);case _:
  return null;

}
}

}

/// @nodoc


class _StateConflict implements StateConflict {
  const _StateConflict({required final  List<JsonPatchOp> incomingPatches, required final  Map<String, dynamic> localState, required final  Map<String, dynamic> snapshotState}): _incomingPatches = incomingPatches,_localState = localState,_snapshotState = snapshotState;
  

 final  List<JsonPatchOp> _incomingPatches;
@override List<JsonPatchOp> get incomingPatches {
  if (_incomingPatches is EqualUnmodifiableListView) return _incomingPatches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_incomingPatches);
}

 final  Map<String, dynamic> _localState;
@override Map<String, dynamic> get localState {
  if (_localState is EqualUnmodifiableMapView) return _localState;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_localState);
}

 final  Map<String, dynamic> _snapshotState;
@override Map<String, dynamic> get snapshotState {
  if (_snapshotState is EqualUnmodifiableMapView) return _snapshotState;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_snapshotState);
}


/// Create a copy of StateConflict
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StateConflictCopyWith<_StateConflict> get copyWith => __$StateConflictCopyWithImpl<_StateConflict>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StateConflict&&const DeepCollectionEquality().equals(other._incomingPatches, _incomingPatches)&&const DeepCollectionEquality().equals(other._localState, _localState)&&const DeepCollectionEquality().equals(other._snapshotState, _snapshotState));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_incomingPatches),const DeepCollectionEquality().hash(_localState),const DeepCollectionEquality().hash(_snapshotState));

@override
String toString() {
  return 'StateConflict(incomingPatches: $incomingPatches, localState: $localState, snapshotState: $snapshotState)';
}


}

/// @nodoc
abstract mixin class _$StateConflictCopyWith<$Res> implements $StateConflictCopyWith<$Res> {
  factory _$StateConflictCopyWith(_StateConflict value, $Res Function(_StateConflict) _then) = __$StateConflictCopyWithImpl;
@override @useResult
$Res call({
 List<JsonPatchOp> incomingPatches, Map<String, dynamic> localState, Map<String, dynamic> snapshotState
});




}
/// @nodoc
class __$StateConflictCopyWithImpl<$Res>
    implements _$StateConflictCopyWith<$Res> {
  __$StateConflictCopyWithImpl(this._self, this._then);

  final _StateConflict _self;
  final $Res Function(_StateConflict) _then;

/// Create a copy of StateConflict
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? incomingPatches = null,Object? localState = null,Object? snapshotState = null,}) {
  return _then(_StateConflict(
incomingPatches: null == incomingPatches ? _self._incomingPatches : incomingPatches // ignore: cast_nullable_to_non_nullable
as List<JsonPatchOp>,localState: null == localState ? _self._localState : localState // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,snapshotState: null == snapshotState ? _self._snapshotState : snapshotState // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
