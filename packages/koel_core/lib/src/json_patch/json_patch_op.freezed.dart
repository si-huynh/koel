// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'json_patch_op.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AddOp {

 String get path; Object? get value;
/// Create a copy of AddOp
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AddOpCopyWith<AddOp> get copyWith => _$AddOpCopyWithImpl<AddOp>(this as AddOp, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AddOp&&(identical(other.path, path) || other.path == path)&&const DeepCollectionEquality().equals(other.value, value));
}


@override
int get hashCode => Object.hash(runtimeType,path,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'AddOp(path: $path, value: $value)';
}


}

/// @nodoc
abstract mixin class $AddOpCopyWith<$Res>  {
  factory $AddOpCopyWith(AddOp value, $Res Function(AddOp) _then) = _$AddOpCopyWithImpl;
@useResult
$Res call({
 String path, Object? value
});




}
/// @nodoc
class _$AddOpCopyWithImpl<$Res>
    implements $AddOpCopyWith<$Res> {
  _$AddOpCopyWithImpl(this._self, this._then);

  final AddOp _self;
  final $Res Function(AddOp) _then;

/// Create a copy of AddOp
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? value = freezed,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,
  ));
}

}


/// Adds pattern-matching-related methods to [AddOp].
extension AddOpPatterns on AddOp {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AddOp value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AddOp() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AddOp value)  $default,){
final _that = this;
switch (_that) {
case _AddOp():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AddOp value)?  $default,){
final _that = this;
switch (_that) {
case _AddOp() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  Object? value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AddOp() when $default != null:
return $default(_that.path,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  Object? value)  $default,) {final _that = this;
switch (_that) {
case _AddOp():
return $default(_that.path,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  Object? value)?  $default,) {final _that = this;
switch (_that) {
case _AddOp() when $default != null:
return $default(_that.path,_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _AddOp extends AddOp {
  const _AddOp({required this.path, this.value}): super._();
  

@override final  String path;
@override final  Object? value;

/// Create a copy of AddOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AddOpCopyWith<_AddOp> get copyWith => __$AddOpCopyWithImpl<_AddOp>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AddOp&&(identical(other.path, path) || other.path == path)&&const DeepCollectionEquality().equals(other.value, value));
}


@override
int get hashCode => Object.hash(runtimeType,path,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'AddOp(path: $path, value: $value)';
}


}

/// @nodoc
abstract mixin class _$AddOpCopyWith<$Res> implements $AddOpCopyWith<$Res> {
  factory _$AddOpCopyWith(_AddOp value, $Res Function(_AddOp) _then) = __$AddOpCopyWithImpl;
@override @useResult
$Res call({
 String path, Object? value
});




}
/// @nodoc
class __$AddOpCopyWithImpl<$Res>
    implements _$AddOpCopyWith<$Res> {
  __$AddOpCopyWithImpl(this._self, this._then);

  final _AddOp _self;
  final $Res Function(_AddOp) _then;

/// Create a copy of AddOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? value = freezed,}) {
  return _then(_AddOp(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,
  ));
}


}

/// @nodoc
mixin _$RemoveOp {

 String get path;
/// Create a copy of RemoveOp
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RemoveOpCopyWith<RemoveOp> get copyWith => _$RemoveOpCopyWithImpl<RemoveOp>(this as RemoveOp, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RemoveOp&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'RemoveOp(path: $path)';
}


}

/// @nodoc
abstract mixin class $RemoveOpCopyWith<$Res>  {
  factory $RemoveOpCopyWith(RemoveOp value, $Res Function(RemoveOp) _then) = _$RemoveOpCopyWithImpl;
@useResult
$Res call({
 String path
});




}
/// @nodoc
class _$RemoveOpCopyWithImpl<$Res>
    implements $RemoveOpCopyWith<$Res> {
  _$RemoveOpCopyWithImpl(this._self, this._then);

  final RemoveOp _self;
  final $Res Function(RemoveOp) _then;

/// Create a copy of RemoveOp
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [RemoveOp].
extension RemoveOpPatterns on RemoveOp {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RemoveOp value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RemoveOp() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RemoveOp value)  $default,){
final _that = this;
switch (_that) {
case _RemoveOp():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RemoveOp value)?  $default,){
final _that = this;
switch (_that) {
case _RemoveOp() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RemoveOp() when $default != null:
return $default(_that.path);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path)  $default,) {final _that = this;
switch (_that) {
case _RemoveOp():
return $default(_that.path);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path)?  $default,) {final _that = this;
switch (_that) {
case _RemoveOp() when $default != null:
return $default(_that.path);case _:
  return null;

}
}

}

/// @nodoc


class _RemoveOp extends RemoveOp {
  const _RemoveOp({required this.path}): super._();
  

@override final  String path;

/// Create a copy of RemoveOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RemoveOpCopyWith<_RemoveOp> get copyWith => __$RemoveOpCopyWithImpl<_RemoveOp>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RemoveOp&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,path);

@override
String toString() {
  return 'RemoveOp(path: $path)';
}


}

/// @nodoc
abstract mixin class _$RemoveOpCopyWith<$Res> implements $RemoveOpCopyWith<$Res> {
  factory _$RemoveOpCopyWith(_RemoveOp value, $Res Function(_RemoveOp) _then) = __$RemoveOpCopyWithImpl;
@override @useResult
$Res call({
 String path
});




}
/// @nodoc
class __$RemoveOpCopyWithImpl<$Res>
    implements _$RemoveOpCopyWith<$Res> {
  __$RemoveOpCopyWithImpl(this._self, this._then);

  final _RemoveOp _self;
  final $Res Function(_RemoveOp) _then;

/// Create a copy of RemoveOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,}) {
  return _then(_RemoveOp(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ReplaceOp {

 String get path; Object? get value;
/// Create a copy of ReplaceOp
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReplaceOpCopyWith<ReplaceOp> get copyWith => _$ReplaceOpCopyWithImpl<ReplaceOp>(this as ReplaceOp, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReplaceOp&&(identical(other.path, path) || other.path == path)&&const DeepCollectionEquality().equals(other.value, value));
}


@override
int get hashCode => Object.hash(runtimeType,path,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'ReplaceOp(path: $path, value: $value)';
}


}

/// @nodoc
abstract mixin class $ReplaceOpCopyWith<$Res>  {
  factory $ReplaceOpCopyWith(ReplaceOp value, $Res Function(ReplaceOp) _then) = _$ReplaceOpCopyWithImpl;
@useResult
$Res call({
 String path, Object? value
});




}
/// @nodoc
class _$ReplaceOpCopyWithImpl<$Res>
    implements $ReplaceOpCopyWith<$Res> {
  _$ReplaceOpCopyWithImpl(this._self, this._then);

  final ReplaceOp _self;
  final $Res Function(ReplaceOp) _then;

/// Create a copy of ReplaceOp
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? value = freezed,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,
  ));
}

}


/// Adds pattern-matching-related methods to [ReplaceOp].
extension ReplaceOpPatterns on ReplaceOp {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReplaceOp value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReplaceOp() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReplaceOp value)  $default,){
final _that = this;
switch (_that) {
case _ReplaceOp():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReplaceOp value)?  $default,){
final _that = this;
switch (_that) {
case _ReplaceOp() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  Object? value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReplaceOp() when $default != null:
return $default(_that.path,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  Object? value)  $default,) {final _that = this;
switch (_that) {
case _ReplaceOp():
return $default(_that.path,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  Object? value)?  $default,) {final _that = this;
switch (_that) {
case _ReplaceOp() when $default != null:
return $default(_that.path,_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _ReplaceOp extends ReplaceOp {
  const _ReplaceOp({required this.path, this.value}): super._();
  

@override final  String path;
@override final  Object? value;

/// Create a copy of ReplaceOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReplaceOpCopyWith<_ReplaceOp> get copyWith => __$ReplaceOpCopyWithImpl<_ReplaceOp>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReplaceOp&&(identical(other.path, path) || other.path == path)&&const DeepCollectionEquality().equals(other.value, value));
}


@override
int get hashCode => Object.hash(runtimeType,path,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'ReplaceOp(path: $path, value: $value)';
}


}

/// @nodoc
abstract mixin class _$ReplaceOpCopyWith<$Res> implements $ReplaceOpCopyWith<$Res> {
  factory _$ReplaceOpCopyWith(_ReplaceOp value, $Res Function(_ReplaceOp) _then) = __$ReplaceOpCopyWithImpl;
@override @useResult
$Res call({
 String path, Object? value
});




}
/// @nodoc
class __$ReplaceOpCopyWithImpl<$Res>
    implements _$ReplaceOpCopyWith<$Res> {
  __$ReplaceOpCopyWithImpl(this._self, this._then);

  final _ReplaceOp _self;
  final $Res Function(_ReplaceOp) _then;

/// Create a copy of ReplaceOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? value = freezed,}) {
  return _then(_ReplaceOp(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,
  ));
}


}

/// @nodoc
mixin _$MoveOp {

 String get from; String get path;
/// Create a copy of MoveOp
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MoveOpCopyWith<MoveOp> get copyWith => _$MoveOpCopyWithImpl<MoveOp>(this as MoveOp, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MoveOp&&(identical(other.from, from) || other.from == from)&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,from,path);

@override
String toString() {
  return 'MoveOp(from: $from, path: $path)';
}


}

/// @nodoc
abstract mixin class $MoveOpCopyWith<$Res>  {
  factory $MoveOpCopyWith(MoveOp value, $Res Function(MoveOp) _then) = _$MoveOpCopyWithImpl;
@useResult
$Res call({
 String from, String path
});




}
/// @nodoc
class _$MoveOpCopyWithImpl<$Res>
    implements $MoveOpCopyWith<$Res> {
  _$MoveOpCopyWithImpl(this._self, this._then);

  final MoveOp _self;
  final $Res Function(MoveOp) _then;

/// Create a copy of MoveOp
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? from = null,Object? path = null,}) {
  return _then(_self.copyWith(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [MoveOp].
extension MoveOpPatterns on MoveOp {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MoveOp value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MoveOp() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MoveOp value)  $default,){
final _that = this;
switch (_that) {
case _MoveOp():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MoveOp value)?  $default,){
final _that = this;
switch (_that) {
case _MoveOp() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String from,  String path)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MoveOp() when $default != null:
return $default(_that.from,_that.path);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String from,  String path)  $default,) {final _that = this;
switch (_that) {
case _MoveOp():
return $default(_that.from,_that.path);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String from,  String path)?  $default,) {final _that = this;
switch (_that) {
case _MoveOp() when $default != null:
return $default(_that.from,_that.path);case _:
  return null;

}
}

}

/// @nodoc


class _MoveOp extends MoveOp {
  const _MoveOp({required this.from, required this.path}): super._();
  

@override final  String from;
@override final  String path;

/// Create a copy of MoveOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MoveOpCopyWith<_MoveOp> get copyWith => __$MoveOpCopyWithImpl<_MoveOp>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MoveOp&&(identical(other.from, from) || other.from == from)&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,from,path);

@override
String toString() {
  return 'MoveOp(from: $from, path: $path)';
}


}

/// @nodoc
abstract mixin class _$MoveOpCopyWith<$Res> implements $MoveOpCopyWith<$Res> {
  factory _$MoveOpCopyWith(_MoveOp value, $Res Function(_MoveOp) _then) = __$MoveOpCopyWithImpl;
@override @useResult
$Res call({
 String from, String path
});




}
/// @nodoc
class __$MoveOpCopyWithImpl<$Res>
    implements _$MoveOpCopyWith<$Res> {
  __$MoveOpCopyWithImpl(this._self, this._then);

  final _MoveOp _self;
  final $Res Function(_MoveOp) _then;

/// Create a copy of MoveOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? from = null,Object? path = null,}) {
  return _then(_MoveOp(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$CopyOp {

 String get from; String get path;
/// Create a copy of CopyOp
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CopyOpCopyWith<CopyOp> get copyWith => _$CopyOpCopyWithImpl<CopyOp>(this as CopyOp, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CopyOp&&(identical(other.from, from) || other.from == from)&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,from,path);

@override
String toString() {
  return 'CopyOp(from: $from, path: $path)';
}


}

/// @nodoc
abstract mixin class $CopyOpCopyWith<$Res>  {
  factory $CopyOpCopyWith(CopyOp value, $Res Function(CopyOp) _then) = _$CopyOpCopyWithImpl;
@useResult
$Res call({
 String from, String path
});




}
/// @nodoc
class _$CopyOpCopyWithImpl<$Res>
    implements $CopyOpCopyWith<$Res> {
  _$CopyOpCopyWithImpl(this._self, this._then);

  final CopyOp _self;
  final $Res Function(CopyOp) _then;

/// Create a copy of CopyOp
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? from = null,Object? path = null,}) {
  return _then(_self.copyWith(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [CopyOp].
extension CopyOpPatterns on CopyOp {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CopyOp value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CopyOp() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CopyOp value)  $default,){
final _that = this;
switch (_that) {
case _CopyOp():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CopyOp value)?  $default,){
final _that = this;
switch (_that) {
case _CopyOp() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String from,  String path)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CopyOp() when $default != null:
return $default(_that.from,_that.path);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String from,  String path)  $default,) {final _that = this;
switch (_that) {
case _CopyOp():
return $default(_that.from,_that.path);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String from,  String path)?  $default,) {final _that = this;
switch (_that) {
case _CopyOp() when $default != null:
return $default(_that.from,_that.path);case _:
  return null;

}
}

}

/// @nodoc


class _CopyOp extends CopyOp {
  const _CopyOp({required this.from, required this.path}): super._();
  

@override final  String from;
@override final  String path;

/// Create a copy of CopyOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CopyOpCopyWith<_CopyOp> get copyWith => __$CopyOpCopyWithImpl<_CopyOp>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CopyOp&&(identical(other.from, from) || other.from == from)&&(identical(other.path, path) || other.path == path));
}


@override
int get hashCode => Object.hash(runtimeType,from,path);

@override
String toString() {
  return 'CopyOp(from: $from, path: $path)';
}


}

/// @nodoc
abstract mixin class _$CopyOpCopyWith<$Res> implements $CopyOpCopyWith<$Res> {
  factory _$CopyOpCopyWith(_CopyOp value, $Res Function(_CopyOp) _then) = __$CopyOpCopyWithImpl;
@override @useResult
$Res call({
 String from, String path
});




}
/// @nodoc
class __$CopyOpCopyWithImpl<$Res>
    implements _$CopyOpCopyWith<$Res> {
  __$CopyOpCopyWithImpl(this._self, this._then);

  final _CopyOp _self;
  final $Res Function(_CopyOp) _then;

/// Create a copy of CopyOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? from = null,Object? path = null,}) {
  return _then(_CopyOp(
from: null == from ? _self.from : from // ignore: cast_nullable_to_non_nullable
as String,path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$TestOp {

 String get path; Object? get value;
/// Create a copy of TestOp
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TestOpCopyWith<TestOp> get copyWith => _$TestOpCopyWithImpl<TestOp>(this as TestOp, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TestOp&&(identical(other.path, path) || other.path == path)&&const DeepCollectionEquality().equals(other.value, value));
}


@override
int get hashCode => Object.hash(runtimeType,path,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'TestOp(path: $path, value: $value)';
}


}

/// @nodoc
abstract mixin class $TestOpCopyWith<$Res>  {
  factory $TestOpCopyWith(TestOp value, $Res Function(TestOp) _then) = _$TestOpCopyWithImpl;
@useResult
$Res call({
 String path, Object? value
});




}
/// @nodoc
class _$TestOpCopyWithImpl<$Res>
    implements $TestOpCopyWith<$Res> {
  _$TestOpCopyWithImpl(this._self, this._then);

  final TestOp _self;
  final $Res Function(TestOp) _then;

/// Create a copy of TestOp
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? path = null,Object? value = freezed,}) {
  return _then(_self.copyWith(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,
  ));
}

}


/// Adds pattern-matching-related methods to [TestOp].
extension TestOpPatterns on TestOp {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TestOp value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TestOp() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TestOp value)  $default,){
final _that = this;
switch (_that) {
case _TestOp():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TestOp value)?  $default,){
final _that = this;
switch (_that) {
case _TestOp() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String path,  Object? value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TestOp() when $default != null:
return $default(_that.path,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String path,  Object? value)  $default,) {final _that = this;
switch (_that) {
case _TestOp():
return $default(_that.path,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String path,  Object? value)?  $default,) {final _that = this;
switch (_that) {
case _TestOp() when $default != null:
return $default(_that.path,_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _TestOp extends TestOp {
  const _TestOp({required this.path, this.value}): super._();
  

@override final  String path;
@override final  Object? value;

/// Create a copy of TestOp
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TestOpCopyWith<_TestOp> get copyWith => __$TestOpCopyWithImpl<_TestOp>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TestOp&&(identical(other.path, path) || other.path == path)&&const DeepCollectionEquality().equals(other.value, value));
}


@override
int get hashCode => Object.hash(runtimeType,path,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'TestOp(path: $path, value: $value)';
}


}

/// @nodoc
abstract mixin class _$TestOpCopyWith<$Res> implements $TestOpCopyWith<$Res> {
  factory _$TestOpCopyWith(_TestOp value, $Res Function(_TestOp) _then) = __$TestOpCopyWithImpl;
@override @useResult
$Res call({
 String path, Object? value
});




}
/// @nodoc
class __$TestOpCopyWithImpl<$Res>
    implements _$TestOpCopyWith<$Res> {
  __$TestOpCopyWithImpl(this._self, this._then);

  final _TestOp _self;
  final $Res Function(_TestOp) _then;

/// Create a copy of TestOp
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? path = null,Object? value = freezed,}) {
  return _then(_TestOp(
path: null == path ? _self.path : path // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,
  ));
}


}

// dart format on
