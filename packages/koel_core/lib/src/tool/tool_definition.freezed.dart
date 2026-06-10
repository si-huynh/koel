// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tool_definition.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ToolDefinition {

 String get name; String get description; Map<String, dynamic> get parameters;
/// Create a copy of ToolDefinition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolDefinitionCopyWith<ToolDefinition> get copyWith => _$ToolDefinitionCopyWithImpl<ToolDefinition>(this as ToolDefinition, _$identity);

  /// Serializes this ToolDefinition to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolDefinition&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.parameters, parameters));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(parameters));

@override
String toString() {
  return 'ToolDefinition(name: $name, description: $description, parameters: $parameters)';
}


}

/// @nodoc
abstract mixin class $ToolDefinitionCopyWith<$Res>  {
  factory $ToolDefinitionCopyWith(ToolDefinition value, $Res Function(ToolDefinition) _then) = _$ToolDefinitionCopyWithImpl;
@useResult
$Res call({
 String name, String description, Map<String, dynamic> parameters
});




}
/// @nodoc
class _$ToolDefinitionCopyWithImpl<$Res>
    implements $ToolDefinitionCopyWith<$Res> {
  _$ToolDefinitionCopyWithImpl(this._self, this._then);

  final ToolDefinition _self;
  final $Res Function(ToolDefinition) _then;

/// Create a copy of ToolDefinition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? description = null,Object? parameters = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,parameters: null == parameters ? _self.parameters : parameters // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [ToolDefinition].
extension ToolDefinitionPatterns on ToolDefinition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolDefinition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolDefinition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolDefinition value)  $default,){
final _that = this;
switch (_that) {
case _ToolDefinition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolDefinition value)?  $default,){
final _that = this;
switch (_that) {
case _ToolDefinition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  String description,  Map<String, dynamic> parameters)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolDefinition() when $default != null:
return $default(_that.name,_that.description,_that.parameters);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  String description,  Map<String, dynamic> parameters)  $default,) {final _that = this;
switch (_that) {
case _ToolDefinition():
return $default(_that.name,_that.description,_that.parameters);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  String description,  Map<String, dynamic> parameters)?  $default,) {final _that = this;
switch (_that) {
case _ToolDefinition() when $default != null:
return $default(_that.name,_that.description,_that.parameters);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ToolDefinition implements ToolDefinition {
  const _ToolDefinition({required this.name, required this.description, final  Map<String, dynamic> parameters = const <String, dynamic>{}}): _parameters = parameters;
  factory _ToolDefinition.fromJson(Map<String, dynamic> json) => _$ToolDefinitionFromJson(json);

@override final  String name;
@override final  String description;
 final  Map<String, dynamic> _parameters;
@override@JsonKey() Map<String, dynamic> get parameters {
  if (_parameters is EqualUnmodifiableMapView) return _parameters;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_parameters);
}


/// Create a copy of ToolDefinition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolDefinitionCopyWith<_ToolDefinition> get copyWith => __$ToolDefinitionCopyWithImpl<_ToolDefinition>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ToolDefinitionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolDefinition&&(identical(other.name, name) || other.name == name)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other._parameters, _parameters));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,description,const DeepCollectionEquality().hash(_parameters));

@override
String toString() {
  return 'ToolDefinition(name: $name, description: $description, parameters: $parameters)';
}


}

/// @nodoc
abstract mixin class _$ToolDefinitionCopyWith<$Res> implements $ToolDefinitionCopyWith<$Res> {
  factory _$ToolDefinitionCopyWith(_ToolDefinition value, $Res Function(_ToolDefinition) _then) = __$ToolDefinitionCopyWithImpl;
@override @useResult
$Res call({
 String name, String description, Map<String, dynamic> parameters
});




}
/// @nodoc
class __$ToolDefinitionCopyWithImpl<$Res>
    implements _$ToolDefinitionCopyWith<$Res> {
  __$ToolDefinitionCopyWithImpl(this._self, this._then);

  final _ToolDefinition _self;
  final $Res Function(_ToolDefinition) _then;

/// Create a copy of ToolDefinition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? description = null,Object? parameters = null,}) {
  return _then(_ToolDefinition(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,parameters: null == parameters ? _self._parameters : parameters // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
