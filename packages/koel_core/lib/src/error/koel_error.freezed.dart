// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'koel_error.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TransportError {

 String get message; KoelErrorCode get code; Object? get cause; int? get statusCode;
/// Create a copy of TransportError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TransportErrorCopyWith<TransportError> get copyWith => _$TransportErrorCopyWithImpl<TransportError>(this as TransportError, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TransportError&&(identical(other.message, message) || other.message == message)&&(identical(other.code, code) || other.code == code)&&const DeepCollectionEquality().equals(other.cause, cause)&&(identical(other.statusCode, statusCode) || other.statusCode == statusCode));
}


@override
int get hashCode => Object.hash(runtimeType,message,code,const DeepCollectionEquality().hash(cause),statusCode);

@override
String toString() {
  return 'TransportError(message: $message, code: $code, cause: $cause, statusCode: $statusCode)';
}


}

/// @nodoc
abstract mixin class $TransportErrorCopyWith<$Res>  {
  factory $TransportErrorCopyWith(TransportError value, $Res Function(TransportError) _then) = _$TransportErrorCopyWithImpl;
@useResult
$Res call({
 String message, KoelErrorCode code, Object? cause, int? statusCode
});




}
/// @nodoc
class _$TransportErrorCopyWithImpl<$Res>
    implements $TransportErrorCopyWith<$Res> {
  _$TransportErrorCopyWithImpl(this._self, this._then);

  final TransportError _self;
  final $Res Function(TransportError) _then;

/// Create a copy of TransportError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? code = null,Object? cause = freezed,Object? statusCode = freezed,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as KoelErrorCode,cause: freezed == cause ? _self.cause : cause ,statusCode: freezed == statusCode ? _self.statusCode : statusCode // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [TransportError].
extension TransportErrorPatterns on TransportError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TransportError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TransportError() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TransportError value)  $default,){
final _that = this;
switch (_that) {
case _TransportError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TransportError value)?  $default,){
final _that = this;
switch (_that) {
case _TransportError() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message,  KoelErrorCode code,  Object? cause,  int? statusCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TransportError() when $default != null:
return $default(_that.message,_that.code,_that.cause,_that.statusCode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message,  KoelErrorCode code,  Object? cause,  int? statusCode)  $default,) {final _that = this;
switch (_that) {
case _TransportError():
return $default(_that.message,_that.code,_that.cause,_that.statusCode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message,  KoelErrorCode code,  Object? cause,  int? statusCode)?  $default,) {final _that = this;
switch (_that) {
case _TransportError() when $default != null:
return $default(_that.message,_that.code,_that.cause,_that.statusCode);case _:
  return null;

}
}

}

/// @nodoc


class _TransportError extends TransportError {
  const _TransportError({required this.message, required this.code, this.cause, this.statusCode}): super._();
  

@override final  String message;
@override final  KoelErrorCode code;
@override final  Object? cause;
@override final  int? statusCode;

/// Create a copy of TransportError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TransportErrorCopyWith<_TransportError> get copyWith => __$TransportErrorCopyWithImpl<_TransportError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TransportError&&(identical(other.message, message) || other.message == message)&&(identical(other.code, code) || other.code == code)&&const DeepCollectionEquality().equals(other.cause, cause)&&(identical(other.statusCode, statusCode) || other.statusCode == statusCode));
}


@override
int get hashCode => Object.hash(runtimeType,message,code,const DeepCollectionEquality().hash(cause),statusCode);

@override
String toString() {
  return 'TransportError(message: $message, code: $code, cause: $cause, statusCode: $statusCode)';
}


}

/// @nodoc
abstract mixin class _$TransportErrorCopyWith<$Res> implements $TransportErrorCopyWith<$Res> {
  factory _$TransportErrorCopyWith(_TransportError value, $Res Function(_TransportError) _then) = __$TransportErrorCopyWithImpl;
@override @useResult
$Res call({
 String message, KoelErrorCode code, Object? cause, int? statusCode
});




}
/// @nodoc
class __$TransportErrorCopyWithImpl<$Res>
    implements _$TransportErrorCopyWith<$Res> {
  __$TransportErrorCopyWithImpl(this._self, this._then);

  final _TransportError _self;
  final $Res Function(_TransportError) _then;

/// Create a copy of TransportError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? code = null,Object? cause = freezed,Object? statusCode = freezed,}) {
  return _then(_TransportError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as KoelErrorCode,cause: freezed == cause ? _self.cause : cause ,statusCode: freezed == statusCode ? _self.statusCode : statusCode // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$ProtocolError {

 String get message; KoelErrorCode get code; Object? get cause; String? get eventType;
/// Create a copy of ProtocolError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProtocolErrorCopyWith<ProtocolError> get copyWith => _$ProtocolErrorCopyWithImpl<ProtocolError>(this as ProtocolError, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProtocolError&&(identical(other.message, message) || other.message == message)&&(identical(other.code, code) || other.code == code)&&const DeepCollectionEquality().equals(other.cause, cause)&&(identical(other.eventType, eventType) || other.eventType == eventType));
}


@override
int get hashCode => Object.hash(runtimeType,message,code,const DeepCollectionEquality().hash(cause),eventType);

@override
String toString() {
  return 'ProtocolError(message: $message, code: $code, cause: $cause, eventType: $eventType)';
}


}

/// @nodoc
abstract mixin class $ProtocolErrorCopyWith<$Res>  {
  factory $ProtocolErrorCopyWith(ProtocolError value, $Res Function(ProtocolError) _then) = _$ProtocolErrorCopyWithImpl;
@useResult
$Res call({
 String message, KoelErrorCode code, Object? cause, String? eventType
});




}
/// @nodoc
class _$ProtocolErrorCopyWithImpl<$Res>
    implements $ProtocolErrorCopyWith<$Res> {
  _$ProtocolErrorCopyWithImpl(this._self, this._then);

  final ProtocolError _self;
  final $Res Function(ProtocolError) _then;

/// Create a copy of ProtocolError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? code = null,Object? cause = freezed,Object? eventType = freezed,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as KoelErrorCode,cause: freezed == cause ? _self.cause : cause ,eventType: freezed == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProtocolError].
extension ProtocolErrorPatterns on ProtocolError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProtocolError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProtocolError() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProtocolError value)  $default,){
final _that = this;
switch (_that) {
case _ProtocolError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProtocolError value)?  $default,){
final _that = this;
switch (_that) {
case _ProtocolError() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message,  KoelErrorCode code,  Object? cause,  String? eventType)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProtocolError() when $default != null:
return $default(_that.message,_that.code,_that.cause,_that.eventType);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message,  KoelErrorCode code,  Object? cause,  String? eventType)  $default,) {final _that = this;
switch (_that) {
case _ProtocolError():
return $default(_that.message,_that.code,_that.cause,_that.eventType);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message,  KoelErrorCode code,  Object? cause,  String? eventType)?  $default,) {final _that = this;
switch (_that) {
case _ProtocolError() when $default != null:
return $default(_that.message,_that.code,_that.cause,_that.eventType);case _:
  return null;

}
}

}

/// @nodoc


class _ProtocolError extends ProtocolError {
  const _ProtocolError({required this.message, required this.code, this.cause, this.eventType}): super._();
  

@override final  String message;
@override final  KoelErrorCode code;
@override final  Object? cause;
@override final  String? eventType;

/// Create a copy of ProtocolError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProtocolErrorCopyWith<_ProtocolError> get copyWith => __$ProtocolErrorCopyWithImpl<_ProtocolError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProtocolError&&(identical(other.message, message) || other.message == message)&&(identical(other.code, code) || other.code == code)&&const DeepCollectionEquality().equals(other.cause, cause)&&(identical(other.eventType, eventType) || other.eventType == eventType));
}


@override
int get hashCode => Object.hash(runtimeType,message,code,const DeepCollectionEquality().hash(cause),eventType);

@override
String toString() {
  return 'ProtocolError(message: $message, code: $code, cause: $cause, eventType: $eventType)';
}


}

/// @nodoc
abstract mixin class _$ProtocolErrorCopyWith<$Res> implements $ProtocolErrorCopyWith<$Res> {
  factory _$ProtocolErrorCopyWith(_ProtocolError value, $Res Function(_ProtocolError) _then) = __$ProtocolErrorCopyWithImpl;
@override @useResult
$Res call({
 String message, KoelErrorCode code, Object? cause, String? eventType
});




}
/// @nodoc
class __$ProtocolErrorCopyWithImpl<$Res>
    implements _$ProtocolErrorCopyWith<$Res> {
  __$ProtocolErrorCopyWithImpl(this._self, this._then);

  final _ProtocolError _self;
  final $Res Function(_ProtocolError) _then;

/// Create a copy of ProtocolError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? code = null,Object? cause = freezed,Object? eventType = freezed,}) {
  return _then(_ProtocolError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as KoelErrorCode,cause: freezed == cause ? _self.cause : cause ,eventType: freezed == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$AgentError {

 String get message; KoelErrorCode get code; Object? get cause; String? get agentCode;
/// Create a copy of AgentError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AgentErrorCopyWith<AgentError> get copyWith => _$AgentErrorCopyWithImpl<AgentError>(this as AgentError, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AgentError&&(identical(other.message, message) || other.message == message)&&(identical(other.code, code) || other.code == code)&&const DeepCollectionEquality().equals(other.cause, cause)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode));
}


@override
int get hashCode => Object.hash(runtimeType,message,code,const DeepCollectionEquality().hash(cause),agentCode);

@override
String toString() {
  return 'AgentError(message: $message, code: $code, cause: $cause, agentCode: $agentCode)';
}


}

/// @nodoc
abstract mixin class $AgentErrorCopyWith<$Res>  {
  factory $AgentErrorCopyWith(AgentError value, $Res Function(AgentError) _then) = _$AgentErrorCopyWithImpl;
@useResult
$Res call({
 String message, KoelErrorCode code, Object? cause, String? agentCode
});




}
/// @nodoc
class _$AgentErrorCopyWithImpl<$Res>
    implements $AgentErrorCopyWith<$Res> {
  _$AgentErrorCopyWithImpl(this._self, this._then);

  final AgentError _self;
  final $Res Function(AgentError) _then;

/// Create a copy of AgentError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? code = null,Object? cause = freezed,Object? agentCode = freezed,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as KoelErrorCode,cause: freezed == cause ? _self.cause : cause ,agentCode: freezed == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [AgentError].
extension AgentErrorPatterns on AgentError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AgentError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AgentError() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AgentError value)  $default,){
final _that = this;
switch (_that) {
case _AgentError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AgentError value)?  $default,){
final _that = this;
switch (_that) {
case _AgentError() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message,  KoelErrorCode code,  Object? cause,  String? agentCode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AgentError() when $default != null:
return $default(_that.message,_that.code,_that.cause,_that.agentCode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message,  KoelErrorCode code,  Object? cause,  String? agentCode)  $default,) {final _that = this;
switch (_that) {
case _AgentError():
return $default(_that.message,_that.code,_that.cause,_that.agentCode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message,  KoelErrorCode code,  Object? cause,  String? agentCode)?  $default,) {final _that = this;
switch (_that) {
case _AgentError() when $default != null:
return $default(_that.message,_that.code,_that.cause,_that.agentCode);case _:
  return null;

}
}

}

/// @nodoc


class _AgentError extends AgentError {
  const _AgentError({required this.message, required this.code, this.cause, this.agentCode}): super._();
  

@override final  String message;
@override final  KoelErrorCode code;
@override final  Object? cause;
@override final  String? agentCode;

/// Create a copy of AgentError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AgentErrorCopyWith<_AgentError> get copyWith => __$AgentErrorCopyWithImpl<_AgentError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AgentError&&(identical(other.message, message) || other.message == message)&&(identical(other.code, code) || other.code == code)&&const DeepCollectionEquality().equals(other.cause, cause)&&(identical(other.agentCode, agentCode) || other.agentCode == agentCode));
}


@override
int get hashCode => Object.hash(runtimeType,message,code,const DeepCollectionEquality().hash(cause),agentCode);

@override
String toString() {
  return 'AgentError(message: $message, code: $code, cause: $cause, agentCode: $agentCode)';
}


}

/// @nodoc
abstract mixin class _$AgentErrorCopyWith<$Res> implements $AgentErrorCopyWith<$Res> {
  factory _$AgentErrorCopyWith(_AgentError value, $Res Function(_AgentError) _then) = __$AgentErrorCopyWithImpl;
@override @useResult
$Res call({
 String message, KoelErrorCode code, Object? cause, String? agentCode
});




}
/// @nodoc
class __$AgentErrorCopyWithImpl<$Res>
    implements _$AgentErrorCopyWith<$Res> {
  __$AgentErrorCopyWithImpl(this._self, this._then);

  final _AgentError _self;
  final $Res Function(_AgentError) _then;

/// Create a copy of AgentError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? code = null,Object? cause = freezed,Object? agentCode = freezed,}) {
  return _then(_AgentError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as KoelErrorCode,cause: freezed == cause ? _self.cause : cause ,agentCode: freezed == agentCode ? _self.agentCode : agentCode // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$BusinessError {

 String get message; KoelErrorCode get code; Object? get cause; Map<String, dynamic> get details;
/// Create a copy of BusinessError
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BusinessErrorCopyWith<BusinessError> get copyWith => _$BusinessErrorCopyWithImpl<BusinessError>(this as BusinessError, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BusinessError&&(identical(other.message, message) || other.message == message)&&(identical(other.code, code) || other.code == code)&&const DeepCollectionEquality().equals(other.cause, cause)&&const DeepCollectionEquality().equals(other.details, details));
}


@override
int get hashCode => Object.hash(runtimeType,message,code,const DeepCollectionEquality().hash(cause),const DeepCollectionEquality().hash(details));

@override
String toString() {
  return 'BusinessError(message: $message, code: $code, cause: $cause, details: $details)';
}


}

/// @nodoc
abstract mixin class $BusinessErrorCopyWith<$Res>  {
  factory $BusinessErrorCopyWith(BusinessError value, $Res Function(BusinessError) _then) = _$BusinessErrorCopyWithImpl;
@useResult
$Res call({
 String message, KoelErrorCode code, Object? cause, Map<String, dynamic> details
});




}
/// @nodoc
class _$BusinessErrorCopyWithImpl<$Res>
    implements $BusinessErrorCopyWith<$Res> {
  _$BusinessErrorCopyWithImpl(this._self, this._then);

  final BusinessError _self;
  final $Res Function(BusinessError) _then;

/// Create a copy of BusinessError
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? code = null,Object? cause = freezed,Object? details = null,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as KoelErrorCode,cause: freezed == cause ? _self.cause : cause ,details: null == details ? _self.details : details // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [BusinessError].
extension BusinessErrorPatterns on BusinessError {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BusinessError value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BusinessError() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BusinessError value)  $default,){
final _that = this;
switch (_that) {
case _BusinessError():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BusinessError value)?  $default,){
final _that = this;
switch (_that) {
case _BusinessError() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String message,  KoelErrorCode code,  Object? cause,  Map<String, dynamic> details)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BusinessError() when $default != null:
return $default(_that.message,_that.code,_that.cause,_that.details);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String message,  KoelErrorCode code,  Object? cause,  Map<String, dynamic> details)  $default,) {final _that = this;
switch (_that) {
case _BusinessError():
return $default(_that.message,_that.code,_that.cause,_that.details);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String message,  KoelErrorCode code,  Object? cause,  Map<String, dynamic> details)?  $default,) {final _that = this;
switch (_that) {
case _BusinessError() when $default != null:
return $default(_that.message,_that.code,_that.cause,_that.details);case _:
  return null;

}
}

}

/// @nodoc


class _BusinessError extends BusinessError {
  const _BusinessError({required this.message, required this.code, this.cause, final  Map<String, dynamic> details = const <String, dynamic>{}}): _details = details,super._();
  

@override final  String message;
@override final  KoelErrorCode code;
@override final  Object? cause;
 final  Map<String, dynamic> _details;
@override@JsonKey() Map<String, dynamic> get details {
  if (_details is EqualUnmodifiableMapView) return _details;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_details);
}


/// Create a copy of BusinessError
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BusinessErrorCopyWith<_BusinessError> get copyWith => __$BusinessErrorCopyWithImpl<_BusinessError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BusinessError&&(identical(other.message, message) || other.message == message)&&(identical(other.code, code) || other.code == code)&&const DeepCollectionEquality().equals(other.cause, cause)&&const DeepCollectionEquality().equals(other._details, _details));
}


@override
int get hashCode => Object.hash(runtimeType,message,code,const DeepCollectionEquality().hash(cause),const DeepCollectionEquality().hash(_details));

@override
String toString() {
  return 'BusinessError(message: $message, code: $code, cause: $cause, details: $details)';
}


}

/// @nodoc
abstract mixin class _$BusinessErrorCopyWith<$Res> implements $BusinessErrorCopyWith<$Res> {
  factory _$BusinessErrorCopyWith(_BusinessError value, $Res Function(_BusinessError) _then) = __$BusinessErrorCopyWithImpl;
@override @useResult
$Res call({
 String message, KoelErrorCode code, Object? cause, Map<String, dynamic> details
});




}
/// @nodoc
class __$BusinessErrorCopyWithImpl<$Res>
    implements _$BusinessErrorCopyWith<$Res> {
  __$BusinessErrorCopyWithImpl(this._self, this._then);

  final _BusinessError _self;
  final $Res Function(_BusinessError) _then;

/// Create a copy of BusinessError
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? code = null,Object? cause = freezed,Object? details = null,}) {
  return _then(_BusinessError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,code: null == code ? _self.code : code // ignore: cast_nullable_to_non_nullable
as KoelErrorCode,cause: freezed == cause ? _self.cause : cause ,details: null == details ? _self._details : details // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
