// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ag_ui_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$UnknownAgUiEvent {

 String get type; Map<String, dynamic> get rawJson;
/// Create a copy of UnknownAgUiEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UnknownAgUiEventCopyWith<UnknownAgUiEvent> get copyWith => _$UnknownAgUiEventCopyWithImpl<UnknownAgUiEvent>(this as UnknownAgUiEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UnknownAgUiEvent&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other.rawJson, rawJson));
}


@override
int get hashCode => Object.hash(runtimeType,type,const DeepCollectionEquality().hash(rawJson));

@override
String toString() {
  return 'UnknownAgUiEvent(type: $type, rawJson: $rawJson)';
}


}

/// @nodoc
abstract mixin class $UnknownAgUiEventCopyWith<$Res>  {
  factory $UnknownAgUiEventCopyWith(UnknownAgUiEvent value, $Res Function(UnknownAgUiEvent) _then) = _$UnknownAgUiEventCopyWithImpl;
@useResult
$Res call({
 String type, Map<String, dynamic> rawJson
});




}
/// @nodoc
class _$UnknownAgUiEventCopyWithImpl<$Res>
    implements $UnknownAgUiEventCopyWith<$Res> {
  _$UnknownAgUiEventCopyWithImpl(this._self, this._then);

  final UnknownAgUiEvent _self;
  final $Res Function(UnknownAgUiEvent) _then;

/// Create a copy of UnknownAgUiEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? type = null,Object? rawJson = null,}) {
  return _then(_self.copyWith(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,rawJson: null == rawJson ? _self.rawJson : rawJson // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [UnknownAgUiEvent].
extension UnknownAgUiEventPatterns on UnknownAgUiEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UnknownAgUiEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UnknownAgUiEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UnknownAgUiEvent value)  $default,){
final _that = this;
switch (_that) {
case _UnknownAgUiEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UnknownAgUiEvent value)?  $default,){
final _that = this;
switch (_that) {
case _UnknownAgUiEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String type,  Map<String, dynamic> rawJson)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UnknownAgUiEvent() when $default != null:
return $default(_that.type,_that.rawJson);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String type,  Map<String, dynamic> rawJson)  $default,) {final _that = this;
switch (_that) {
case _UnknownAgUiEvent():
return $default(_that.type,_that.rawJson);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String type,  Map<String, dynamic> rawJson)?  $default,) {final _that = this;
switch (_that) {
case _UnknownAgUiEvent() when $default != null:
return $default(_that.type,_that.rawJson);case _:
  return null;

}
}

}

/// @nodoc


class _UnknownAgUiEvent extends UnknownAgUiEvent {
  const _UnknownAgUiEvent({required this.type, required final  Map<String, dynamic> rawJson}): _rawJson = rawJson,super._();
  

@override final  String type;
 final  Map<String, dynamic> _rawJson;
@override Map<String, dynamic> get rawJson {
  if (_rawJson is EqualUnmodifiableMapView) return _rawJson;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_rawJson);
}


/// Create a copy of UnknownAgUiEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UnknownAgUiEventCopyWith<_UnknownAgUiEvent> get copyWith => __$UnknownAgUiEventCopyWithImpl<_UnknownAgUiEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UnknownAgUiEvent&&(identical(other.type, type) || other.type == type)&&const DeepCollectionEquality().equals(other._rawJson, _rawJson));
}


@override
int get hashCode => Object.hash(runtimeType,type,const DeepCollectionEquality().hash(_rawJson));

@override
String toString() {
  return 'UnknownAgUiEvent(type: $type, rawJson: $rawJson)';
}


}

/// @nodoc
abstract mixin class _$UnknownAgUiEventCopyWith<$Res> implements $UnknownAgUiEventCopyWith<$Res> {
  factory _$UnknownAgUiEventCopyWith(_UnknownAgUiEvent value, $Res Function(_UnknownAgUiEvent) _then) = __$UnknownAgUiEventCopyWithImpl;
@override @useResult
$Res call({
 String type, Map<String, dynamic> rawJson
});




}
/// @nodoc
class __$UnknownAgUiEventCopyWithImpl<$Res>
    implements _$UnknownAgUiEventCopyWith<$Res> {
  __$UnknownAgUiEventCopyWithImpl(this._self, this._then);

  final _UnknownAgUiEvent _self;
  final $Res Function(_UnknownAgUiEvent) _then;

/// Create a copy of UnknownAgUiEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? type = null,Object? rawJson = null,}) {
  return _then(_UnknownAgUiEvent(
type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,rawJson: null == rawJson ? _self._rawJson : rawJson // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

/// @nodoc
mixin _$RunStartedEvent {

 String get threadId; String get runId; String? get parentRunId;
/// Create a copy of RunStartedEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RunStartedEventCopyWith<RunStartedEvent> get copyWith => _$RunStartedEventCopyWithImpl<RunStartedEvent>(this as RunStartedEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RunStartedEvent&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.runId, runId) || other.runId == runId)&&(identical(other.parentRunId, parentRunId) || other.parentRunId == parentRunId));
}


@override
int get hashCode => Object.hash(runtimeType,threadId,runId,parentRunId);

@override
String toString() {
  return 'RunStartedEvent(threadId: $threadId, runId: $runId, parentRunId: $parentRunId)';
}


}

/// @nodoc
abstract mixin class $RunStartedEventCopyWith<$Res>  {
  factory $RunStartedEventCopyWith(RunStartedEvent value, $Res Function(RunStartedEvent) _then) = _$RunStartedEventCopyWithImpl;
@useResult
$Res call({
 String threadId, String runId, String? parentRunId
});




}
/// @nodoc
class _$RunStartedEventCopyWithImpl<$Res>
    implements $RunStartedEventCopyWith<$Res> {
  _$RunStartedEventCopyWithImpl(this._self, this._then);

  final RunStartedEvent _self;
  final $Res Function(RunStartedEvent) _then;

/// Create a copy of RunStartedEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? threadId = null,Object? runId = null,Object? parentRunId = freezed,}) {
  return _then(_self.copyWith(
threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String,runId: null == runId ? _self.runId : runId // ignore: cast_nullable_to_non_nullable
as String,parentRunId: freezed == parentRunId ? _self.parentRunId : parentRunId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RunStartedEvent].
extension RunStartedEventPatterns on RunStartedEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RunStartedEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RunStartedEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RunStartedEvent value)  $default,){
final _that = this;
switch (_that) {
case _RunStartedEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RunStartedEvent value)?  $default,){
final _that = this;
switch (_that) {
case _RunStartedEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String threadId,  String runId,  String? parentRunId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RunStartedEvent() when $default != null:
return $default(_that.threadId,_that.runId,_that.parentRunId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String threadId,  String runId,  String? parentRunId)  $default,) {final _that = this;
switch (_that) {
case _RunStartedEvent():
return $default(_that.threadId,_that.runId,_that.parentRunId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String threadId,  String runId,  String? parentRunId)?  $default,) {final _that = this;
switch (_that) {
case _RunStartedEvent() when $default != null:
return $default(_that.threadId,_that.runId,_that.parentRunId);case _:
  return null;

}
}

}

/// @nodoc


class _RunStartedEvent extends RunStartedEvent {
  const _RunStartedEvent({required this.threadId, required this.runId, this.parentRunId}): super._();
  

@override final  String threadId;
@override final  String runId;
@override final  String? parentRunId;

/// Create a copy of RunStartedEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RunStartedEventCopyWith<_RunStartedEvent> get copyWith => __$RunStartedEventCopyWithImpl<_RunStartedEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RunStartedEvent&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.runId, runId) || other.runId == runId)&&(identical(other.parentRunId, parentRunId) || other.parentRunId == parentRunId));
}


@override
int get hashCode => Object.hash(runtimeType,threadId,runId,parentRunId);

@override
String toString() {
  return 'RunStartedEvent(threadId: $threadId, runId: $runId, parentRunId: $parentRunId)';
}


}

/// @nodoc
abstract mixin class _$RunStartedEventCopyWith<$Res> implements $RunStartedEventCopyWith<$Res> {
  factory _$RunStartedEventCopyWith(_RunStartedEvent value, $Res Function(_RunStartedEvent) _then) = __$RunStartedEventCopyWithImpl;
@override @useResult
$Res call({
 String threadId, String runId, String? parentRunId
});




}
/// @nodoc
class __$RunStartedEventCopyWithImpl<$Res>
    implements _$RunStartedEventCopyWith<$Res> {
  __$RunStartedEventCopyWithImpl(this._self, this._then);

  final _RunStartedEvent _self;
  final $Res Function(_RunStartedEvent) _then;

/// Create a copy of RunStartedEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? threadId = null,Object? runId = null,Object? parentRunId = freezed,}) {
  return _then(_RunStartedEvent(
threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String,runId: null == runId ? _self.runId : runId // ignore: cast_nullable_to_non_nullable
as String,parentRunId: freezed == parentRunId ? _self.parentRunId : parentRunId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$RunFinishedEvent {

 String get threadId; String get runId; Object? get result;
/// Create a copy of RunFinishedEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RunFinishedEventCopyWith<RunFinishedEvent> get copyWith => _$RunFinishedEventCopyWithImpl<RunFinishedEvent>(this as RunFinishedEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RunFinishedEvent&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.runId, runId) || other.runId == runId)&&const DeepCollectionEquality().equals(other.result, result));
}


@override
int get hashCode => Object.hash(runtimeType,threadId,runId,const DeepCollectionEquality().hash(result));

@override
String toString() {
  return 'RunFinishedEvent(threadId: $threadId, runId: $runId, result: $result)';
}


}

/// @nodoc
abstract mixin class $RunFinishedEventCopyWith<$Res>  {
  factory $RunFinishedEventCopyWith(RunFinishedEvent value, $Res Function(RunFinishedEvent) _then) = _$RunFinishedEventCopyWithImpl;
@useResult
$Res call({
 String threadId, String runId, Object? result
});




}
/// @nodoc
class _$RunFinishedEventCopyWithImpl<$Res>
    implements $RunFinishedEventCopyWith<$Res> {
  _$RunFinishedEventCopyWithImpl(this._self, this._then);

  final RunFinishedEvent _self;
  final $Res Function(RunFinishedEvent) _then;

/// Create a copy of RunFinishedEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? threadId = null,Object? runId = null,Object? result = freezed,}) {
  return _then(_self.copyWith(
threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String,runId: null == runId ? _self.runId : runId // ignore: cast_nullable_to_non_nullable
as String,result: freezed == result ? _self.result : result ,
  ));
}

}


/// Adds pattern-matching-related methods to [RunFinishedEvent].
extension RunFinishedEventPatterns on RunFinishedEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RunFinishedEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RunFinishedEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RunFinishedEvent value)  $default,){
final _that = this;
switch (_that) {
case _RunFinishedEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RunFinishedEvent value)?  $default,){
final _that = this;
switch (_that) {
case _RunFinishedEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String threadId,  String runId,  Object? result)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RunFinishedEvent() when $default != null:
return $default(_that.threadId,_that.runId,_that.result);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String threadId,  String runId,  Object? result)  $default,) {final _that = this;
switch (_that) {
case _RunFinishedEvent():
return $default(_that.threadId,_that.runId,_that.result);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String threadId,  String runId,  Object? result)?  $default,) {final _that = this;
switch (_that) {
case _RunFinishedEvent() when $default != null:
return $default(_that.threadId,_that.runId,_that.result);case _:
  return null;

}
}

}

/// @nodoc


class _RunFinishedEvent extends RunFinishedEvent {
  const _RunFinishedEvent({required this.threadId, required this.runId, this.result}): super._();
  

@override final  String threadId;
@override final  String runId;
@override final  Object? result;

/// Create a copy of RunFinishedEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RunFinishedEventCopyWith<_RunFinishedEvent> get copyWith => __$RunFinishedEventCopyWithImpl<_RunFinishedEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RunFinishedEvent&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.runId, runId) || other.runId == runId)&&const DeepCollectionEquality().equals(other.result, result));
}


@override
int get hashCode => Object.hash(runtimeType,threadId,runId,const DeepCollectionEquality().hash(result));

@override
String toString() {
  return 'RunFinishedEvent(threadId: $threadId, runId: $runId, result: $result)';
}


}

/// @nodoc
abstract mixin class _$RunFinishedEventCopyWith<$Res> implements $RunFinishedEventCopyWith<$Res> {
  factory _$RunFinishedEventCopyWith(_RunFinishedEvent value, $Res Function(_RunFinishedEvent) _then) = __$RunFinishedEventCopyWithImpl;
@override @useResult
$Res call({
 String threadId, String runId, Object? result
});




}
/// @nodoc
class __$RunFinishedEventCopyWithImpl<$Res>
    implements _$RunFinishedEventCopyWith<$Res> {
  __$RunFinishedEventCopyWithImpl(this._self, this._then);

  final _RunFinishedEvent _self;
  final $Res Function(_RunFinishedEvent) _then;

/// Create a copy of RunFinishedEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? threadId = null,Object? runId = null,Object? result = freezed,}) {
  return _then(_RunFinishedEvent(
threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String,runId: null == runId ? _self.runId : runId // ignore: cast_nullable_to_non_nullable
as String,result: freezed == result ? _self.result : result ,
  ));
}


}

/// @nodoc
mixin _$RunErrorEvent {

 KoelError get error;
/// Create a copy of RunErrorEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RunErrorEventCopyWith<RunErrorEvent> get copyWith => _$RunErrorEventCopyWithImpl<RunErrorEvent>(this as RunErrorEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RunErrorEvent&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'RunErrorEvent(error: $error)';
}


}

/// @nodoc
abstract mixin class $RunErrorEventCopyWith<$Res>  {
  factory $RunErrorEventCopyWith(RunErrorEvent value, $Res Function(RunErrorEvent) _then) = _$RunErrorEventCopyWithImpl;
@useResult
$Res call({
 KoelError error
});




}
/// @nodoc
class _$RunErrorEventCopyWithImpl<$Res>
    implements $RunErrorEventCopyWith<$Res> {
  _$RunErrorEventCopyWithImpl(this._self, this._then);

  final RunErrorEvent _self;
  final $Res Function(RunErrorEvent) _then;

/// Create a copy of RunErrorEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? error = null,}) {
  return _then(_self.copyWith(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as KoelError,
  ));
}

}


/// Adds pattern-matching-related methods to [RunErrorEvent].
extension RunErrorEventPatterns on RunErrorEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RunErrorEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RunErrorEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RunErrorEvent value)  $default,){
final _that = this;
switch (_that) {
case _RunErrorEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RunErrorEvent value)?  $default,){
final _that = this;
switch (_that) {
case _RunErrorEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( KoelError error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RunErrorEvent() when $default != null:
return $default(_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( KoelError error)  $default,) {final _that = this;
switch (_that) {
case _RunErrorEvent():
return $default(_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( KoelError error)?  $default,) {final _that = this;
switch (_that) {
case _RunErrorEvent() when $default != null:
return $default(_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _RunErrorEvent extends RunErrorEvent {
  const _RunErrorEvent({required this.error}): super._();
  

@override final  KoelError error;

/// Create a copy of RunErrorEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RunErrorEventCopyWith<_RunErrorEvent> get copyWith => __$RunErrorEventCopyWithImpl<_RunErrorEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RunErrorEvent&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,error);

@override
String toString() {
  return 'RunErrorEvent(error: $error)';
}


}

/// @nodoc
abstract mixin class _$RunErrorEventCopyWith<$Res> implements $RunErrorEventCopyWith<$Res> {
  factory _$RunErrorEventCopyWith(_RunErrorEvent value, $Res Function(_RunErrorEvent) _then) = __$RunErrorEventCopyWithImpl;
@override @useResult
$Res call({
 KoelError error
});




}
/// @nodoc
class __$RunErrorEventCopyWithImpl<$Res>
    implements _$RunErrorEventCopyWith<$Res> {
  __$RunErrorEventCopyWithImpl(this._self, this._then);

  final _RunErrorEvent _self;
  final $Res Function(_RunErrorEvent) _then;

/// Create a copy of RunErrorEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? error = null,}) {
  return _then(_RunErrorEvent(
error: null == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as KoelError,
  ));
}


}

/// @nodoc
mixin _$StepStartedEvent {

 String get stepName;
/// Create a copy of StepStartedEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StepStartedEventCopyWith<StepStartedEvent> get copyWith => _$StepStartedEventCopyWithImpl<StepStartedEvent>(this as StepStartedEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StepStartedEvent&&(identical(other.stepName, stepName) || other.stepName == stepName));
}


@override
int get hashCode => Object.hash(runtimeType,stepName);

@override
String toString() {
  return 'StepStartedEvent(stepName: $stepName)';
}


}

/// @nodoc
abstract mixin class $StepStartedEventCopyWith<$Res>  {
  factory $StepStartedEventCopyWith(StepStartedEvent value, $Res Function(StepStartedEvent) _then) = _$StepStartedEventCopyWithImpl;
@useResult
$Res call({
 String stepName
});




}
/// @nodoc
class _$StepStartedEventCopyWithImpl<$Res>
    implements $StepStartedEventCopyWith<$Res> {
  _$StepStartedEventCopyWithImpl(this._self, this._then);

  final StepStartedEvent _self;
  final $Res Function(StepStartedEvent) _then;

/// Create a copy of StepStartedEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stepName = null,}) {
  return _then(_self.copyWith(
stepName: null == stepName ? _self.stepName : stepName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [StepStartedEvent].
extension StepStartedEventPatterns on StepStartedEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StepStartedEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StepStartedEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StepStartedEvent value)  $default,){
final _that = this;
switch (_that) {
case _StepStartedEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StepStartedEvent value)?  $default,){
final _that = this;
switch (_that) {
case _StepStartedEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String stepName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StepStartedEvent() when $default != null:
return $default(_that.stepName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String stepName)  $default,) {final _that = this;
switch (_that) {
case _StepStartedEvent():
return $default(_that.stepName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String stepName)?  $default,) {final _that = this;
switch (_that) {
case _StepStartedEvent() when $default != null:
return $default(_that.stepName);case _:
  return null;

}
}

}

/// @nodoc


class _StepStartedEvent extends StepStartedEvent {
  const _StepStartedEvent({required this.stepName}): super._();
  

@override final  String stepName;

/// Create a copy of StepStartedEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StepStartedEventCopyWith<_StepStartedEvent> get copyWith => __$StepStartedEventCopyWithImpl<_StepStartedEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StepStartedEvent&&(identical(other.stepName, stepName) || other.stepName == stepName));
}


@override
int get hashCode => Object.hash(runtimeType,stepName);

@override
String toString() {
  return 'StepStartedEvent(stepName: $stepName)';
}


}

/// @nodoc
abstract mixin class _$StepStartedEventCopyWith<$Res> implements $StepStartedEventCopyWith<$Res> {
  factory _$StepStartedEventCopyWith(_StepStartedEvent value, $Res Function(_StepStartedEvent) _then) = __$StepStartedEventCopyWithImpl;
@override @useResult
$Res call({
 String stepName
});




}
/// @nodoc
class __$StepStartedEventCopyWithImpl<$Res>
    implements _$StepStartedEventCopyWith<$Res> {
  __$StepStartedEventCopyWithImpl(this._self, this._then);

  final _StepStartedEvent _self;
  final $Res Function(_StepStartedEvent) _then;

/// Create a copy of StepStartedEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stepName = null,}) {
  return _then(_StepStartedEvent(
stepName: null == stepName ? _self.stepName : stepName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$StepFinishedEvent {

 String get stepName;
/// Create a copy of StepFinishedEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StepFinishedEventCopyWith<StepFinishedEvent> get copyWith => _$StepFinishedEventCopyWithImpl<StepFinishedEvent>(this as StepFinishedEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StepFinishedEvent&&(identical(other.stepName, stepName) || other.stepName == stepName));
}


@override
int get hashCode => Object.hash(runtimeType,stepName);

@override
String toString() {
  return 'StepFinishedEvent(stepName: $stepName)';
}


}

/// @nodoc
abstract mixin class $StepFinishedEventCopyWith<$Res>  {
  factory $StepFinishedEventCopyWith(StepFinishedEvent value, $Res Function(StepFinishedEvent) _then) = _$StepFinishedEventCopyWithImpl;
@useResult
$Res call({
 String stepName
});




}
/// @nodoc
class _$StepFinishedEventCopyWithImpl<$Res>
    implements $StepFinishedEventCopyWith<$Res> {
  _$StepFinishedEventCopyWithImpl(this._self, this._then);

  final StepFinishedEvent _self;
  final $Res Function(StepFinishedEvent) _then;

/// Create a copy of StepFinishedEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? stepName = null,}) {
  return _then(_self.copyWith(
stepName: null == stepName ? _self.stepName : stepName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [StepFinishedEvent].
extension StepFinishedEventPatterns on StepFinishedEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StepFinishedEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StepFinishedEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StepFinishedEvent value)  $default,){
final _that = this;
switch (_that) {
case _StepFinishedEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StepFinishedEvent value)?  $default,){
final _that = this;
switch (_that) {
case _StepFinishedEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String stepName)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StepFinishedEvent() when $default != null:
return $default(_that.stepName);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String stepName)  $default,) {final _that = this;
switch (_that) {
case _StepFinishedEvent():
return $default(_that.stepName);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String stepName)?  $default,) {final _that = this;
switch (_that) {
case _StepFinishedEvent() when $default != null:
return $default(_that.stepName);case _:
  return null;

}
}

}

/// @nodoc


class _StepFinishedEvent extends StepFinishedEvent {
  const _StepFinishedEvent({required this.stepName}): super._();
  

@override final  String stepName;

/// Create a copy of StepFinishedEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StepFinishedEventCopyWith<_StepFinishedEvent> get copyWith => __$StepFinishedEventCopyWithImpl<_StepFinishedEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StepFinishedEvent&&(identical(other.stepName, stepName) || other.stepName == stepName));
}


@override
int get hashCode => Object.hash(runtimeType,stepName);

@override
String toString() {
  return 'StepFinishedEvent(stepName: $stepName)';
}


}

/// @nodoc
abstract mixin class _$StepFinishedEventCopyWith<$Res> implements $StepFinishedEventCopyWith<$Res> {
  factory _$StepFinishedEventCopyWith(_StepFinishedEvent value, $Res Function(_StepFinishedEvent) _then) = __$StepFinishedEventCopyWithImpl;
@override @useResult
$Res call({
 String stepName
});




}
/// @nodoc
class __$StepFinishedEventCopyWithImpl<$Res>
    implements _$StepFinishedEventCopyWith<$Res> {
  __$StepFinishedEventCopyWithImpl(this._self, this._then);

  final _StepFinishedEvent _self;
  final $Res Function(_StepFinishedEvent) _then;

/// Create a copy of StepFinishedEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? stepName = null,}) {
  return _then(_StepFinishedEvent(
stepName: null == stepName ? _self.stepName : stepName // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$TextMessageStartEvent {

 String get messageId; String get role;
/// Create a copy of TextMessageStartEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextMessageStartEventCopyWith<TextMessageStartEvent> get copyWith => _$TextMessageStartEventCopyWithImpl<TextMessageStartEvent>(this as TextMessageStartEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TextMessageStartEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.role, role) || other.role == role));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,role);

@override
String toString() {
  return 'TextMessageStartEvent(messageId: $messageId, role: $role)';
}


}

/// @nodoc
abstract mixin class $TextMessageStartEventCopyWith<$Res>  {
  factory $TextMessageStartEventCopyWith(TextMessageStartEvent value, $Res Function(TextMessageStartEvent) _then) = _$TextMessageStartEventCopyWithImpl;
@useResult
$Res call({
 String messageId, String role
});




}
/// @nodoc
class _$TextMessageStartEventCopyWithImpl<$Res>
    implements $TextMessageStartEventCopyWith<$Res> {
  _$TextMessageStartEventCopyWithImpl(this._self, this._then);

  final TextMessageStartEvent _self;
  final $Res Function(TextMessageStartEvent) _then;

/// Create a copy of TextMessageStartEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? role = null,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TextMessageStartEvent].
extension TextMessageStartEventPatterns on TextMessageStartEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TextMessageStartEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TextMessageStartEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TextMessageStartEvent value)  $default,){
final _that = this;
switch (_that) {
case _TextMessageStartEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TextMessageStartEvent value)?  $default,){
final _that = this;
switch (_that) {
case _TextMessageStartEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId,  String role)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TextMessageStartEvent() when $default != null:
return $default(_that.messageId,_that.role);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId,  String role)  $default,) {final _that = this;
switch (_that) {
case _TextMessageStartEvent():
return $default(_that.messageId,_that.role);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId,  String role)?  $default,) {final _that = this;
switch (_that) {
case _TextMessageStartEvent() when $default != null:
return $default(_that.messageId,_that.role);case _:
  return null;

}
}

}

/// @nodoc


class _TextMessageStartEvent extends TextMessageStartEvent {
  const _TextMessageStartEvent({required this.messageId, required this.role}): super._();
  

@override final  String messageId;
@override final  String role;

/// Create a copy of TextMessageStartEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TextMessageStartEventCopyWith<_TextMessageStartEvent> get copyWith => __$TextMessageStartEventCopyWithImpl<_TextMessageStartEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TextMessageStartEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.role, role) || other.role == role));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,role);

@override
String toString() {
  return 'TextMessageStartEvent(messageId: $messageId, role: $role)';
}


}

/// @nodoc
abstract mixin class _$TextMessageStartEventCopyWith<$Res> implements $TextMessageStartEventCopyWith<$Res> {
  factory _$TextMessageStartEventCopyWith(_TextMessageStartEvent value, $Res Function(_TextMessageStartEvent) _then) = __$TextMessageStartEventCopyWithImpl;
@override @useResult
$Res call({
 String messageId, String role
});




}
/// @nodoc
class __$TextMessageStartEventCopyWithImpl<$Res>
    implements _$TextMessageStartEventCopyWith<$Res> {
  __$TextMessageStartEventCopyWithImpl(this._self, this._then);

  final _TextMessageStartEvent _self;
  final $Res Function(_TextMessageStartEvent) _then;

/// Create a copy of TextMessageStartEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? role = null,}) {
  return _then(_TextMessageStartEvent(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$TextMessageContentEvent {

 String get messageId; String get delta;
/// Create a copy of TextMessageContentEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextMessageContentEventCopyWith<TextMessageContentEvent> get copyWith => _$TextMessageContentEventCopyWithImpl<TextMessageContentEvent>(this as TextMessageContentEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TextMessageContentEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.delta, delta) || other.delta == delta));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,delta);

@override
String toString() {
  return 'TextMessageContentEvent(messageId: $messageId, delta: $delta)';
}


}

/// @nodoc
abstract mixin class $TextMessageContentEventCopyWith<$Res>  {
  factory $TextMessageContentEventCopyWith(TextMessageContentEvent value, $Res Function(TextMessageContentEvent) _then) = _$TextMessageContentEventCopyWithImpl;
@useResult
$Res call({
 String messageId, String delta
});




}
/// @nodoc
class _$TextMessageContentEventCopyWithImpl<$Res>
    implements $TextMessageContentEventCopyWith<$Res> {
  _$TextMessageContentEventCopyWithImpl(this._self, this._then);

  final TextMessageContentEvent _self;
  final $Res Function(TextMessageContentEvent) _then;

/// Create a copy of TextMessageContentEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? delta = null,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,delta: null == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TextMessageContentEvent].
extension TextMessageContentEventPatterns on TextMessageContentEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TextMessageContentEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TextMessageContentEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TextMessageContentEvent value)  $default,){
final _that = this;
switch (_that) {
case _TextMessageContentEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TextMessageContentEvent value)?  $default,){
final _that = this;
switch (_that) {
case _TextMessageContentEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId,  String delta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TextMessageContentEvent() when $default != null:
return $default(_that.messageId,_that.delta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId,  String delta)  $default,) {final _that = this;
switch (_that) {
case _TextMessageContentEvent():
return $default(_that.messageId,_that.delta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId,  String delta)?  $default,) {final _that = this;
switch (_that) {
case _TextMessageContentEvent() when $default != null:
return $default(_that.messageId,_that.delta);case _:
  return null;

}
}

}

/// @nodoc


class _TextMessageContentEvent extends TextMessageContentEvent {
  const _TextMessageContentEvent({required this.messageId, required this.delta}): super._();
  

@override final  String messageId;
@override final  String delta;

/// Create a copy of TextMessageContentEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TextMessageContentEventCopyWith<_TextMessageContentEvent> get copyWith => __$TextMessageContentEventCopyWithImpl<_TextMessageContentEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TextMessageContentEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.delta, delta) || other.delta == delta));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,delta);

@override
String toString() {
  return 'TextMessageContentEvent(messageId: $messageId, delta: $delta)';
}


}

/// @nodoc
abstract mixin class _$TextMessageContentEventCopyWith<$Res> implements $TextMessageContentEventCopyWith<$Res> {
  factory _$TextMessageContentEventCopyWith(_TextMessageContentEvent value, $Res Function(_TextMessageContentEvent) _then) = __$TextMessageContentEventCopyWithImpl;
@override @useResult
$Res call({
 String messageId, String delta
});




}
/// @nodoc
class __$TextMessageContentEventCopyWithImpl<$Res>
    implements _$TextMessageContentEventCopyWith<$Res> {
  __$TextMessageContentEventCopyWithImpl(this._self, this._then);

  final _TextMessageContentEvent _self;
  final $Res Function(_TextMessageContentEvent) _then;

/// Create a copy of TextMessageContentEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? delta = null,}) {
  return _then(_TextMessageContentEvent(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,delta: null == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$TextMessageEndEvent {

 String get messageId;
/// Create a copy of TextMessageEndEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextMessageEndEventCopyWith<TextMessageEndEvent> get copyWith => _$TextMessageEndEventCopyWithImpl<TextMessageEndEvent>(this as TextMessageEndEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TextMessageEndEvent&&(identical(other.messageId, messageId) || other.messageId == messageId));
}


@override
int get hashCode => Object.hash(runtimeType,messageId);

@override
String toString() {
  return 'TextMessageEndEvent(messageId: $messageId)';
}


}

/// @nodoc
abstract mixin class $TextMessageEndEventCopyWith<$Res>  {
  factory $TextMessageEndEventCopyWith(TextMessageEndEvent value, $Res Function(TextMessageEndEvent) _then) = _$TextMessageEndEventCopyWithImpl;
@useResult
$Res call({
 String messageId
});




}
/// @nodoc
class _$TextMessageEndEventCopyWithImpl<$Res>
    implements $TextMessageEndEventCopyWith<$Res> {
  _$TextMessageEndEventCopyWithImpl(this._self, this._then);

  final TextMessageEndEvent _self;
  final $Res Function(TextMessageEndEvent) _then;

/// Create a copy of TextMessageEndEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [TextMessageEndEvent].
extension TextMessageEndEventPatterns on TextMessageEndEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TextMessageEndEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TextMessageEndEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TextMessageEndEvent value)  $default,){
final _that = this;
switch (_that) {
case _TextMessageEndEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TextMessageEndEvent value)?  $default,){
final _that = this;
switch (_that) {
case _TextMessageEndEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TextMessageEndEvent() when $default != null:
return $default(_that.messageId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId)  $default,) {final _that = this;
switch (_that) {
case _TextMessageEndEvent():
return $default(_that.messageId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId)?  $default,) {final _that = this;
switch (_that) {
case _TextMessageEndEvent() when $default != null:
return $default(_that.messageId);case _:
  return null;

}
}

}

/// @nodoc


class _TextMessageEndEvent extends TextMessageEndEvent {
  const _TextMessageEndEvent({required this.messageId}): super._();
  

@override final  String messageId;

/// Create a copy of TextMessageEndEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TextMessageEndEventCopyWith<_TextMessageEndEvent> get copyWith => __$TextMessageEndEventCopyWithImpl<_TextMessageEndEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TextMessageEndEvent&&(identical(other.messageId, messageId) || other.messageId == messageId));
}


@override
int get hashCode => Object.hash(runtimeType,messageId);

@override
String toString() {
  return 'TextMessageEndEvent(messageId: $messageId)';
}


}

/// @nodoc
abstract mixin class _$TextMessageEndEventCopyWith<$Res> implements $TextMessageEndEventCopyWith<$Res> {
  factory _$TextMessageEndEventCopyWith(_TextMessageEndEvent value, $Res Function(_TextMessageEndEvent) _then) = __$TextMessageEndEventCopyWithImpl;
@override @useResult
$Res call({
 String messageId
});




}
/// @nodoc
class __$TextMessageEndEventCopyWithImpl<$Res>
    implements _$TextMessageEndEventCopyWith<$Res> {
  __$TextMessageEndEventCopyWithImpl(this._self, this._then);

  final _TextMessageEndEvent _self;
  final $Res Function(_TextMessageEndEvent) _then;

/// Create a copy of TextMessageEndEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,}) {
  return _then(_TextMessageEndEvent(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$TextMessageChunkEvent {

 String? get messageId; String? get role; String? get delta;
/// Create a copy of TextMessageChunkEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TextMessageChunkEventCopyWith<TextMessageChunkEvent> get copyWith => _$TextMessageChunkEventCopyWithImpl<TextMessageChunkEvent>(this as TextMessageChunkEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TextMessageChunkEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.role, role) || other.role == role)&&(identical(other.delta, delta) || other.delta == delta));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,role,delta);

@override
String toString() {
  return 'TextMessageChunkEvent(messageId: $messageId, role: $role, delta: $delta)';
}


}

/// @nodoc
abstract mixin class $TextMessageChunkEventCopyWith<$Res>  {
  factory $TextMessageChunkEventCopyWith(TextMessageChunkEvent value, $Res Function(TextMessageChunkEvent) _then) = _$TextMessageChunkEventCopyWithImpl;
@useResult
$Res call({
 String? messageId, String? role, String? delta
});




}
/// @nodoc
class _$TextMessageChunkEventCopyWithImpl<$Res>
    implements $TextMessageChunkEventCopyWith<$Res> {
  _$TextMessageChunkEventCopyWithImpl(this._self, this._then);

  final TextMessageChunkEvent _self;
  final $Res Function(TextMessageChunkEvent) _then;

/// Create a copy of TextMessageChunkEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = freezed,Object? role = freezed,Object? delta = freezed,}) {
  return _then(_self.copyWith(
messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,delta: freezed == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [TextMessageChunkEvent].
extension TextMessageChunkEventPatterns on TextMessageChunkEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TextMessageChunkEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TextMessageChunkEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TextMessageChunkEvent value)  $default,){
final _that = this;
switch (_that) {
case _TextMessageChunkEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TextMessageChunkEvent value)?  $default,){
final _that = this;
switch (_that) {
case _TextMessageChunkEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? messageId,  String? role,  String? delta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TextMessageChunkEvent() when $default != null:
return $default(_that.messageId,_that.role,_that.delta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? messageId,  String? role,  String? delta)  $default,) {final _that = this;
switch (_that) {
case _TextMessageChunkEvent():
return $default(_that.messageId,_that.role,_that.delta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? messageId,  String? role,  String? delta)?  $default,) {final _that = this;
switch (_that) {
case _TextMessageChunkEvent() when $default != null:
return $default(_that.messageId,_that.role,_that.delta);case _:
  return null;

}
}

}

/// @nodoc


class _TextMessageChunkEvent extends TextMessageChunkEvent {
  const _TextMessageChunkEvent({this.messageId, this.role, this.delta}): super._();
  

@override final  String? messageId;
@override final  String? role;
@override final  String? delta;

/// Create a copy of TextMessageChunkEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TextMessageChunkEventCopyWith<_TextMessageChunkEvent> get copyWith => __$TextMessageChunkEventCopyWithImpl<_TextMessageChunkEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TextMessageChunkEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.role, role) || other.role == role)&&(identical(other.delta, delta) || other.delta == delta));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,role,delta);

@override
String toString() {
  return 'TextMessageChunkEvent(messageId: $messageId, role: $role, delta: $delta)';
}


}

/// @nodoc
abstract mixin class _$TextMessageChunkEventCopyWith<$Res> implements $TextMessageChunkEventCopyWith<$Res> {
  factory _$TextMessageChunkEventCopyWith(_TextMessageChunkEvent value, $Res Function(_TextMessageChunkEvent) _then) = __$TextMessageChunkEventCopyWithImpl;
@override @useResult
$Res call({
 String? messageId, String? role, String? delta
});




}
/// @nodoc
class __$TextMessageChunkEventCopyWithImpl<$Res>
    implements _$TextMessageChunkEventCopyWith<$Res> {
  __$TextMessageChunkEventCopyWithImpl(this._self, this._then);

  final _TextMessageChunkEvent _self;
  final $Res Function(_TextMessageChunkEvent) _then;

/// Create a copy of TextMessageChunkEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = freezed,Object? role = freezed,Object? delta = freezed,}) {
  return _then(_TextMessageChunkEvent(
messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,delta: freezed == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$ToolCallStartEvent {

 String get toolCallId; String get toolCallName; String? get parentMessageId;
/// Create a copy of ToolCallStartEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolCallStartEventCopyWith<ToolCallStartEvent> get copyWith => _$ToolCallStartEventCopyWithImpl<ToolCallStartEvent>(this as ToolCallStartEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolCallStartEvent&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.toolCallName, toolCallName) || other.toolCallName == toolCallName)&&(identical(other.parentMessageId, parentMessageId) || other.parentMessageId == parentMessageId));
}


@override
int get hashCode => Object.hash(runtimeType,toolCallId,toolCallName,parentMessageId);

@override
String toString() {
  return 'ToolCallStartEvent(toolCallId: $toolCallId, toolCallName: $toolCallName, parentMessageId: $parentMessageId)';
}


}

/// @nodoc
abstract mixin class $ToolCallStartEventCopyWith<$Res>  {
  factory $ToolCallStartEventCopyWith(ToolCallStartEvent value, $Res Function(ToolCallStartEvent) _then) = _$ToolCallStartEventCopyWithImpl;
@useResult
$Res call({
 String toolCallId, String toolCallName, String? parentMessageId
});




}
/// @nodoc
class _$ToolCallStartEventCopyWithImpl<$Res>
    implements $ToolCallStartEventCopyWith<$Res> {
  _$ToolCallStartEventCopyWithImpl(this._self, this._then);

  final ToolCallStartEvent _self;
  final $Res Function(ToolCallStartEvent) _then;

/// Create a copy of ToolCallStartEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? toolCallId = null,Object? toolCallName = null,Object? parentMessageId = freezed,}) {
  return _then(_self.copyWith(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,toolCallName: null == toolCallName ? _self.toolCallName : toolCallName // ignore: cast_nullable_to_non_nullable
as String,parentMessageId: freezed == parentMessageId ? _self.parentMessageId : parentMessageId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ToolCallStartEvent].
extension ToolCallStartEventPatterns on ToolCallStartEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolCallStartEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolCallStartEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolCallStartEvent value)  $default,){
final _that = this;
switch (_that) {
case _ToolCallStartEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolCallStartEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ToolCallStartEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String toolCallId,  String toolCallName,  String? parentMessageId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolCallStartEvent() when $default != null:
return $default(_that.toolCallId,_that.toolCallName,_that.parentMessageId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String toolCallId,  String toolCallName,  String? parentMessageId)  $default,) {final _that = this;
switch (_that) {
case _ToolCallStartEvent():
return $default(_that.toolCallId,_that.toolCallName,_that.parentMessageId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String toolCallId,  String toolCallName,  String? parentMessageId)?  $default,) {final _that = this;
switch (_that) {
case _ToolCallStartEvent() when $default != null:
return $default(_that.toolCallId,_that.toolCallName,_that.parentMessageId);case _:
  return null;

}
}

}

/// @nodoc


class _ToolCallStartEvent extends ToolCallStartEvent {
  const _ToolCallStartEvent({required this.toolCallId, required this.toolCallName, this.parentMessageId}): super._();
  

@override final  String toolCallId;
@override final  String toolCallName;
@override final  String? parentMessageId;

/// Create a copy of ToolCallStartEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolCallStartEventCopyWith<_ToolCallStartEvent> get copyWith => __$ToolCallStartEventCopyWithImpl<_ToolCallStartEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolCallStartEvent&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.toolCallName, toolCallName) || other.toolCallName == toolCallName)&&(identical(other.parentMessageId, parentMessageId) || other.parentMessageId == parentMessageId));
}


@override
int get hashCode => Object.hash(runtimeType,toolCallId,toolCallName,parentMessageId);

@override
String toString() {
  return 'ToolCallStartEvent(toolCallId: $toolCallId, toolCallName: $toolCallName, parentMessageId: $parentMessageId)';
}


}

/// @nodoc
abstract mixin class _$ToolCallStartEventCopyWith<$Res> implements $ToolCallStartEventCopyWith<$Res> {
  factory _$ToolCallStartEventCopyWith(_ToolCallStartEvent value, $Res Function(_ToolCallStartEvent) _then) = __$ToolCallStartEventCopyWithImpl;
@override @useResult
$Res call({
 String toolCallId, String toolCallName, String? parentMessageId
});




}
/// @nodoc
class __$ToolCallStartEventCopyWithImpl<$Res>
    implements _$ToolCallStartEventCopyWith<$Res> {
  __$ToolCallStartEventCopyWithImpl(this._self, this._then);

  final _ToolCallStartEvent _self;
  final $Res Function(_ToolCallStartEvent) _then;

/// Create a copy of ToolCallStartEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = null,Object? toolCallName = null,Object? parentMessageId = freezed,}) {
  return _then(_ToolCallStartEvent(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,toolCallName: null == toolCallName ? _self.toolCallName : toolCallName // ignore: cast_nullable_to_non_nullable
as String,parentMessageId: freezed == parentMessageId ? _self.parentMessageId : parentMessageId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$ToolCallArgsEvent {

 String get toolCallId; String get delta;
/// Create a copy of ToolCallArgsEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolCallArgsEventCopyWith<ToolCallArgsEvent> get copyWith => _$ToolCallArgsEventCopyWithImpl<ToolCallArgsEvent>(this as ToolCallArgsEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolCallArgsEvent&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.delta, delta) || other.delta == delta));
}


@override
int get hashCode => Object.hash(runtimeType,toolCallId,delta);

@override
String toString() {
  return 'ToolCallArgsEvent(toolCallId: $toolCallId, delta: $delta)';
}


}

/// @nodoc
abstract mixin class $ToolCallArgsEventCopyWith<$Res>  {
  factory $ToolCallArgsEventCopyWith(ToolCallArgsEvent value, $Res Function(ToolCallArgsEvent) _then) = _$ToolCallArgsEventCopyWithImpl;
@useResult
$Res call({
 String toolCallId, String delta
});




}
/// @nodoc
class _$ToolCallArgsEventCopyWithImpl<$Res>
    implements $ToolCallArgsEventCopyWith<$Res> {
  _$ToolCallArgsEventCopyWithImpl(this._self, this._then);

  final ToolCallArgsEvent _self;
  final $Res Function(ToolCallArgsEvent) _then;

/// Create a copy of ToolCallArgsEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? toolCallId = null,Object? delta = null,}) {
  return _then(_self.copyWith(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,delta: null == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ToolCallArgsEvent].
extension ToolCallArgsEventPatterns on ToolCallArgsEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolCallArgsEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolCallArgsEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolCallArgsEvent value)  $default,){
final _that = this;
switch (_that) {
case _ToolCallArgsEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolCallArgsEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ToolCallArgsEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String toolCallId,  String delta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolCallArgsEvent() when $default != null:
return $default(_that.toolCallId,_that.delta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String toolCallId,  String delta)  $default,) {final _that = this;
switch (_that) {
case _ToolCallArgsEvent():
return $default(_that.toolCallId,_that.delta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String toolCallId,  String delta)?  $default,) {final _that = this;
switch (_that) {
case _ToolCallArgsEvent() when $default != null:
return $default(_that.toolCallId,_that.delta);case _:
  return null;

}
}

}

/// @nodoc


class _ToolCallArgsEvent extends ToolCallArgsEvent {
  const _ToolCallArgsEvent({required this.toolCallId, required this.delta}): super._();
  

@override final  String toolCallId;
@override final  String delta;

/// Create a copy of ToolCallArgsEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolCallArgsEventCopyWith<_ToolCallArgsEvent> get copyWith => __$ToolCallArgsEventCopyWithImpl<_ToolCallArgsEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolCallArgsEvent&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.delta, delta) || other.delta == delta));
}


@override
int get hashCode => Object.hash(runtimeType,toolCallId,delta);

@override
String toString() {
  return 'ToolCallArgsEvent(toolCallId: $toolCallId, delta: $delta)';
}


}

/// @nodoc
abstract mixin class _$ToolCallArgsEventCopyWith<$Res> implements $ToolCallArgsEventCopyWith<$Res> {
  factory _$ToolCallArgsEventCopyWith(_ToolCallArgsEvent value, $Res Function(_ToolCallArgsEvent) _then) = __$ToolCallArgsEventCopyWithImpl;
@override @useResult
$Res call({
 String toolCallId, String delta
});




}
/// @nodoc
class __$ToolCallArgsEventCopyWithImpl<$Res>
    implements _$ToolCallArgsEventCopyWith<$Res> {
  __$ToolCallArgsEventCopyWithImpl(this._self, this._then);

  final _ToolCallArgsEvent _self;
  final $Res Function(_ToolCallArgsEvent) _then;

/// Create a copy of ToolCallArgsEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = null,Object? delta = null,}) {
  return _then(_ToolCallArgsEvent(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,delta: null == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ToolCallEndEvent {

 String get toolCallId;
/// Create a copy of ToolCallEndEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolCallEndEventCopyWith<ToolCallEndEvent> get copyWith => _$ToolCallEndEventCopyWithImpl<ToolCallEndEvent>(this as ToolCallEndEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolCallEndEvent&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId));
}


@override
int get hashCode => Object.hash(runtimeType,toolCallId);

@override
String toString() {
  return 'ToolCallEndEvent(toolCallId: $toolCallId)';
}


}

/// @nodoc
abstract mixin class $ToolCallEndEventCopyWith<$Res>  {
  factory $ToolCallEndEventCopyWith(ToolCallEndEvent value, $Res Function(ToolCallEndEvent) _then) = _$ToolCallEndEventCopyWithImpl;
@useResult
$Res call({
 String toolCallId
});




}
/// @nodoc
class _$ToolCallEndEventCopyWithImpl<$Res>
    implements $ToolCallEndEventCopyWith<$Res> {
  _$ToolCallEndEventCopyWithImpl(this._self, this._then);

  final ToolCallEndEvent _self;
  final $Res Function(ToolCallEndEvent) _then;

/// Create a copy of ToolCallEndEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? toolCallId = null,}) {
  return _then(_self.copyWith(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ToolCallEndEvent].
extension ToolCallEndEventPatterns on ToolCallEndEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolCallEndEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolCallEndEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolCallEndEvent value)  $default,){
final _that = this;
switch (_that) {
case _ToolCallEndEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolCallEndEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ToolCallEndEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String toolCallId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolCallEndEvent() when $default != null:
return $default(_that.toolCallId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String toolCallId)  $default,) {final _that = this;
switch (_that) {
case _ToolCallEndEvent():
return $default(_that.toolCallId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String toolCallId)?  $default,) {final _that = this;
switch (_that) {
case _ToolCallEndEvent() when $default != null:
return $default(_that.toolCallId);case _:
  return null;

}
}

}

/// @nodoc


class _ToolCallEndEvent extends ToolCallEndEvent {
  const _ToolCallEndEvent({required this.toolCallId}): super._();
  

@override final  String toolCallId;

/// Create a copy of ToolCallEndEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolCallEndEventCopyWith<_ToolCallEndEvent> get copyWith => __$ToolCallEndEventCopyWithImpl<_ToolCallEndEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolCallEndEvent&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId));
}


@override
int get hashCode => Object.hash(runtimeType,toolCallId);

@override
String toString() {
  return 'ToolCallEndEvent(toolCallId: $toolCallId)';
}


}

/// @nodoc
abstract mixin class _$ToolCallEndEventCopyWith<$Res> implements $ToolCallEndEventCopyWith<$Res> {
  factory _$ToolCallEndEventCopyWith(_ToolCallEndEvent value, $Res Function(_ToolCallEndEvent) _then) = __$ToolCallEndEventCopyWithImpl;
@override @useResult
$Res call({
 String toolCallId
});




}
/// @nodoc
class __$ToolCallEndEventCopyWithImpl<$Res>
    implements _$ToolCallEndEventCopyWith<$Res> {
  __$ToolCallEndEventCopyWithImpl(this._self, this._then);

  final _ToolCallEndEvent _self;
  final $Res Function(_ToolCallEndEvent) _then;

/// Create a copy of ToolCallEndEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = null,}) {
  return _then(_ToolCallEndEvent(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ToolCallResultEvent {

 String get messageId; String get toolCallId; String get content; String? get role;
/// Create a copy of ToolCallResultEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolCallResultEventCopyWith<ToolCallResultEvent> get copyWith => _$ToolCallResultEventCopyWithImpl<ToolCallResultEvent>(this as ToolCallResultEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolCallResultEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.content, content) || other.content == content)&&(identical(other.role, role) || other.role == role));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,toolCallId,content,role);

@override
String toString() {
  return 'ToolCallResultEvent(messageId: $messageId, toolCallId: $toolCallId, content: $content, role: $role)';
}


}

/// @nodoc
abstract mixin class $ToolCallResultEventCopyWith<$Res>  {
  factory $ToolCallResultEventCopyWith(ToolCallResultEvent value, $Res Function(ToolCallResultEvent) _then) = _$ToolCallResultEventCopyWithImpl;
@useResult
$Res call({
 String messageId, String toolCallId, String content, String? role
});




}
/// @nodoc
class _$ToolCallResultEventCopyWithImpl<$Res>
    implements $ToolCallResultEventCopyWith<$Res> {
  _$ToolCallResultEventCopyWithImpl(this._self, this._then);

  final ToolCallResultEvent _self;
  final $Res Function(ToolCallResultEvent) _then;

/// Create a copy of ToolCallResultEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? toolCallId = null,Object? content = null,Object? role = freezed,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ToolCallResultEvent].
extension ToolCallResultEventPatterns on ToolCallResultEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolCallResultEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolCallResultEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolCallResultEvent value)  $default,){
final _that = this;
switch (_that) {
case _ToolCallResultEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolCallResultEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ToolCallResultEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId,  String toolCallId,  String content,  String? role)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolCallResultEvent() when $default != null:
return $default(_that.messageId,_that.toolCallId,_that.content,_that.role);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId,  String toolCallId,  String content,  String? role)  $default,) {final _that = this;
switch (_that) {
case _ToolCallResultEvent():
return $default(_that.messageId,_that.toolCallId,_that.content,_that.role);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId,  String toolCallId,  String content,  String? role)?  $default,) {final _that = this;
switch (_that) {
case _ToolCallResultEvent() when $default != null:
return $default(_that.messageId,_that.toolCallId,_that.content,_that.role);case _:
  return null;

}
}

}

/// @nodoc


class _ToolCallResultEvent extends ToolCallResultEvent {
  const _ToolCallResultEvent({required this.messageId, required this.toolCallId, required this.content, this.role}): super._();
  

@override final  String messageId;
@override final  String toolCallId;
@override final  String content;
@override final  String? role;

/// Create a copy of ToolCallResultEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolCallResultEventCopyWith<_ToolCallResultEvent> get copyWith => __$ToolCallResultEventCopyWithImpl<_ToolCallResultEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolCallResultEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.content, content) || other.content == content)&&(identical(other.role, role) || other.role == role));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,toolCallId,content,role);

@override
String toString() {
  return 'ToolCallResultEvent(messageId: $messageId, toolCallId: $toolCallId, content: $content, role: $role)';
}


}

/// @nodoc
abstract mixin class _$ToolCallResultEventCopyWith<$Res> implements $ToolCallResultEventCopyWith<$Res> {
  factory _$ToolCallResultEventCopyWith(_ToolCallResultEvent value, $Res Function(_ToolCallResultEvent) _then) = __$ToolCallResultEventCopyWithImpl;
@override @useResult
$Res call({
 String messageId, String toolCallId, String content, String? role
});




}
/// @nodoc
class __$ToolCallResultEventCopyWithImpl<$Res>
    implements _$ToolCallResultEventCopyWith<$Res> {
  __$ToolCallResultEventCopyWithImpl(this._self, this._then);

  final _ToolCallResultEvent _self;
  final $Res Function(_ToolCallResultEvent) _then;

/// Create a copy of ToolCallResultEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? toolCallId = null,Object? content = null,Object? role = freezed,}) {
  return _then(_ToolCallResultEvent(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,role: freezed == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$ToolCallChunkEvent {

 String? get toolCallId; String? get toolCallName; String? get parentMessageId; String? get delta;
/// Create a copy of ToolCallChunkEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ToolCallChunkEventCopyWith<ToolCallChunkEvent> get copyWith => _$ToolCallChunkEventCopyWithImpl<ToolCallChunkEvent>(this as ToolCallChunkEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ToolCallChunkEvent&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.toolCallName, toolCallName) || other.toolCallName == toolCallName)&&(identical(other.parentMessageId, parentMessageId) || other.parentMessageId == parentMessageId)&&(identical(other.delta, delta) || other.delta == delta));
}


@override
int get hashCode => Object.hash(runtimeType,toolCallId,toolCallName,parentMessageId,delta);

@override
String toString() {
  return 'ToolCallChunkEvent(toolCallId: $toolCallId, toolCallName: $toolCallName, parentMessageId: $parentMessageId, delta: $delta)';
}


}

/// @nodoc
abstract mixin class $ToolCallChunkEventCopyWith<$Res>  {
  factory $ToolCallChunkEventCopyWith(ToolCallChunkEvent value, $Res Function(ToolCallChunkEvent) _then) = _$ToolCallChunkEventCopyWithImpl;
@useResult
$Res call({
 String? toolCallId, String? toolCallName, String? parentMessageId, String? delta
});




}
/// @nodoc
class _$ToolCallChunkEventCopyWithImpl<$Res>
    implements $ToolCallChunkEventCopyWith<$Res> {
  _$ToolCallChunkEventCopyWithImpl(this._self, this._then);

  final ToolCallChunkEvent _self;
  final $Res Function(ToolCallChunkEvent) _then;

/// Create a copy of ToolCallChunkEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? toolCallId = freezed,Object? toolCallName = freezed,Object? parentMessageId = freezed,Object? delta = freezed,}) {
  return _then(_self.copyWith(
toolCallId: freezed == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String?,toolCallName: freezed == toolCallName ? _self.toolCallName : toolCallName // ignore: cast_nullable_to_non_nullable
as String?,parentMessageId: freezed == parentMessageId ? _self.parentMessageId : parentMessageId // ignore: cast_nullable_to_non_nullable
as String?,delta: freezed == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ToolCallChunkEvent].
extension ToolCallChunkEventPatterns on ToolCallChunkEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ToolCallChunkEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ToolCallChunkEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ToolCallChunkEvent value)  $default,){
final _that = this;
switch (_that) {
case _ToolCallChunkEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ToolCallChunkEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ToolCallChunkEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? toolCallId,  String? toolCallName,  String? parentMessageId,  String? delta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ToolCallChunkEvent() when $default != null:
return $default(_that.toolCallId,_that.toolCallName,_that.parentMessageId,_that.delta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? toolCallId,  String? toolCallName,  String? parentMessageId,  String? delta)  $default,) {final _that = this;
switch (_that) {
case _ToolCallChunkEvent():
return $default(_that.toolCallId,_that.toolCallName,_that.parentMessageId,_that.delta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? toolCallId,  String? toolCallName,  String? parentMessageId,  String? delta)?  $default,) {final _that = this;
switch (_that) {
case _ToolCallChunkEvent() when $default != null:
return $default(_that.toolCallId,_that.toolCallName,_that.parentMessageId,_that.delta);case _:
  return null;

}
}

}

/// @nodoc


class _ToolCallChunkEvent extends ToolCallChunkEvent {
  const _ToolCallChunkEvent({this.toolCallId, this.toolCallName, this.parentMessageId, this.delta}): super._();
  

@override final  String? toolCallId;
@override final  String? toolCallName;
@override final  String? parentMessageId;
@override final  String? delta;

/// Create a copy of ToolCallChunkEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ToolCallChunkEventCopyWith<_ToolCallChunkEvent> get copyWith => __$ToolCallChunkEventCopyWithImpl<_ToolCallChunkEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ToolCallChunkEvent&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.toolCallName, toolCallName) || other.toolCallName == toolCallName)&&(identical(other.parentMessageId, parentMessageId) || other.parentMessageId == parentMessageId)&&(identical(other.delta, delta) || other.delta == delta));
}


@override
int get hashCode => Object.hash(runtimeType,toolCallId,toolCallName,parentMessageId,delta);

@override
String toString() {
  return 'ToolCallChunkEvent(toolCallId: $toolCallId, toolCallName: $toolCallName, parentMessageId: $parentMessageId, delta: $delta)';
}


}

/// @nodoc
abstract mixin class _$ToolCallChunkEventCopyWith<$Res> implements $ToolCallChunkEventCopyWith<$Res> {
  factory _$ToolCallChunkEventCopyWith(_ToolCallChunkEvent value, $Res Function(_ToolCallChunkEvent) _then) = __$ToolCallChunkEventCopyWithImpl;
@override @useResult
$Res call({
 String? toolCallId, String? toolCallName, String? parentMessageId, String? delta
});




}
/// @nodoc
class __$ToolCallChunkEventCopyWithImpl<$Res>
    implements _$ToolCallChunkEventCopyWith<$Res> {
  __$ToolCallChunkEventCopyWithImpl(this._self, this._then);

  final _ToolCallChunkEvent _self;
  final $Res Function(_ToolCallChunkEvent) _then;

/// Create a copy of ToolCallChunkEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? toolCallId = freezed,Object? toolCallName = freezed,Object? parentMessageId = freezed,Object? delta = freezed,}) {
  return _then(_ToolCallChunkEvent(
toolCallId: freezed == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String?,toolCallName: freezed == toolCallName ? _self.toolCallName : toolCallName // ignore: cast_nullable_to_non_nullable
as String?,parentMessageId: freezed == parentMessageId ? _self.parentMessageId : parentMessageId // ignore: cast_nullable_to_non_nullable
as String?,delta: freezed == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$StateSnapshotEvent {

 Map<String, dynamic> get state;
/// Create a copy of StateSnapshotEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StateSnapshotEventCopyWith<StateSnapshotEvent> get copyWith => _$StateSnapshotEventCopyWithImpl<StateSnapshotEvent>(this as StateSnapshotEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StateSnapshotEvent&&const DeepCollectionEquality().equals(other.state, state));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(state));

@override
String toString() {
  return 'StateSnapshotEvent(state: $state)';
}


}

/// @nodoc
abstract mixin class $StateSnapshotEventCopyWith<$Res>  {
  factory $StateSnapshotEventCopyWith(StateSnapshotEvent value, $Res Function(StateSnapshotEvent) _then) = _$StateSnapshotEventCopyWithImpl;
@useResult
$Res call({
 Map<String, dynamic> state
});




}
/// @nodoc
class _$StateSnapshotEventCopyWithImpl<$Res>
    implements $StateSnapshotEventCopyWith<$Res> {
  _$StateSnapshotEventCopyWithImpl(this._self, this._then);

  final StateSnapshotEvent _self;
  final $Res Function(StateSnapshotEvent) _then;

/// Create a copy of StateSnapshotEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? state = null,}) {
  return _then(_self.copyWith(
state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}

}


/// Adds pattern-matching-related methods to [StateSnapshotEvent].
extension StateSnapshotEventPatterns on StateSnapshotEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StateSnapshotEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StateSnapshotEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StateSnapshotEvent value)  $default,){
final _that = this;
switch (_that) {
case _StateSnapshotEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StateSnapshotEvent value)?  $default,){
final _that = this;
switch (_that) {
case _StateSnapshotEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, dynamic> state)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StateSnapshotEvent() when $default != null:
return $default(_that.state);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, dynamic> state)  $default,) {final _that = this;
switch (_that) {
case _StateSnapshotEvent():
return $default(_that.state);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, dynamic> state)?  $default,) {final _that = this;
switch (_that) {
case _StateSnapshotEvent() when $default != null:
return $default(_that.state);case _:
  return null;

}
}

}

/// @nodoc


class _StateSnapshotEvent extends StateSnapshotEvent {
  const _StateSnapshotEvent({required final  Map<String, dynamic> state}): _state = state,super._();
  

 final  Map<String, dynamic> _state;
@override Map<String, dynamic> get state {
  if (_state is EqualUnmodifiableMapView) return _state;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_state);
}


/// Create a copy of StateSnapshotEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StateSnapshotEventCopyWith<_StateSnapshotEvent> get copyWith => __$StateSnapshotEventCopyWithImpl<_StateSnapshotEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StateSnapshotEvent&&const DeepCollectionEquality().equals(other._state, _state));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_state));

@override
String toString() {
  return 'StateSnapshotEvent(state: $state)';
}


}

/// @nodoc
abstract mixin class _$StateSnapshotEventCopyWith<$Res> implements $StateSnapshotEventCopyWith<$Res> {
  factory _$StateSnapshotEventCopyWith(_StateSnapshotEvent value, $Res Function(_StateSnapshotEvent) _then) = __$StateSnapshotEventCopyWithImpl;
@override @useResult
$Res call({
 Map<String, dynamic> state
});




}
/// @nodoc
class __$StateSnapshotEventCopyWithImpl<$Res>
    implements _$StateSnapshotEventCopyWith<$Res> {
  __$StateSnapshotEventCopyWithImpl(this._self, this._then);

  final _StateSnapshotEvent _self;
  final $Res Function(_StateSnapshotEvent) _then;

/// Create a copy of StateSnapshotEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? state = null,}) {
  return _then(_StateSnapshotEvent(
state: null == state ? _self._state : state // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

/// @nodoc
mixin _$StateDeltaEvent {

 List<JsonPatchOp> get patches;
/// Create a copy of StateDeltaEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StateDeltaEventCopyWith<StateDeltaEvent> get copyWith => _$StateDeltaEventCopyWithImpl<StateDeltaEvent>(this as StateDeltaEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StateDeltaEvent&&const DeepCollectionEquality().equals(other.patches, patches));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(patches));

@override
String toString() {
  return 'StateDeltaEvent(patches: $patches)';
}


}

/// @nodoc
abstract mixin class $StateDeltaEventCopyWith<$Res>  {
  factory $StateDeltaEventCopyWith(StateDeltaEvent value, $Res Function(StateDeltaEvent) _then) = _$StateDeltaEventCopyWithImpl;
@useResult
$Res call({
 List<JsonPatchOp> patches
});




}
/// @nodoc
class _$StateDeltaEventCopyWithImpl<$Res>
    implements $StateDeltaEventCopyWith<$Res> {
  _$StateDeltaEventCopyWithImpl(this._self, this._then);

  final StateDeltaEvent _self;
  final $Res Function(StateDeltaEvent) _then;

/// Create a copy of StateDeltaEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? patches = null,}) {
  return _then(_self.copyWith(
patches: null == patches ? _self.patches : patches // ignore: cast_nullable_to_non_nullable
as List<JsonPatchOp>,
  ));
}

}


/// Adds pattern-matching-related methods to [StateDeltaEvent].
extension StateDeltaEventPatterns on StateDeltaEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StateDeltaEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StateDeltaEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StateDeltaEvent value)  $default,){
final _that = this;
switch (_that) {
case _StateDeltaEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StateDeltaEvent value)?  $default,){
final _that = this;
switch (_that) {
case _StateDeltaEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<JsonPatchOp> patches)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StateDeltaEvent() when $default != null:
return $default(_that.patches);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<JsonPatchOp> patches)  $default,) {final _that = this;
switch (_that) {
case _StateDeltaEvent():
return $default(_that.patches);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<JsonPatchOp> patches)?  $default,) {final _that = this;
switch (_that) {
case _StateDeltaEvent() when $default != null:
return $default(_that.patches);case _:
  return null;

}
}

}

/// @nodoc


class _StateDeltaEvent extends StateDeltaEvent {
  const _StateDeltaEvent({required final  List<JsonPatchOp> patches}): _patches = patches,super._();
  

 final  List<JsonPatchOp> _patches;
@override List<JsonPatchOp> get patches {
  if (_patches is EqualUnmodifiableListView) return _patches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_patches);
}


/// Create a copy of StateDeltaEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StateDeltaEventCopyWith<_StateDeltaEvent> get copyWith => __$StateDeltaEventCopyWithImpl<_StateDeltaEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StateDeltaEvent&&const DeepCollectionEquality().equals(other._patches, _patches));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_patches));

@override
String toString() {
  return 'StateDeltaEvent(patches: $patches)';
}


}

/// @nodoc
abstract mixin class _$StateDeltaEventCopyWith<$Res> implements $StateDeltaEventCopyWith<$Res> {
  factory _$StateDeltaEventCopyWith(_StateDeltaEvent value, $Res Function(_StateDeltaEvent) _then) = __$StateDeltaEventCopyWithImpl;
@override @useResult
$Res call({
 List<JsonPatchOp> patches
});




}
/// @nodoc
class __$StateDeltaEventCopyWithImpl<$Res>
    implements _$StateDeltaEventCopyWith<$Res> {
  __$StateDeltaEventCopyWithImpl(this._self, this._then);

  final _StateDeltaEvent _self;
  final $Res Function(_StateDeltaEvent) _then;

/// Create a copy of StateDeltaEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? patches = null,}) {
  return _then(_StateDeltaEvent(
patches: null == patches ? _self._patches : patches // ignore: cast_nullable_to_non_nullable
as List<JsonPatchOp>,
  ));
}


}

/// @nodoc
mixin _$MessagesSnapshotEvent {

 List<Message> get messages;
/// Create a copy of MessagesSnapshotEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MessagesSnapshotEventCopyWith<MessagesSnapshotEvent> get copyWith => _$MessagesSnapshotEventCopyWithImpl<MessagesSnapshotEvent>(this as MessagesSnapshotEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MessagesSnapshotEvent&&const DeepCollectionEquality().equals(other.messages, messages));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(messages));

@override
String toString() {
  return 'MessagesSnapshotEvent(messages: $messages)';
}


}

/// @nodoc
abstract mixin class $MessagesSnapshotEventCopyWith<$Res>  {
  factory $MessagesSnapshotEventCopyWith(MessagesSnapshotEvent value, $Res Function(MessagesSnapshotEvent) _then) = _$MessagesSnapshotEventCopyWithImpl;
@useResult
$Res call({
 List<Message> messages
});




}
/// @nodoc
class _$MessagesSnapshotEventCopyWithImpl<$Res>
    implements $MessagesSnapshotEventCopyWith<$Res> {
  _$MessagesSnapshotEventCopyWithImpl(this._self, this._then);

  final MessagesSnapshotEvent _self;
  final $Res Function(MessagesSnapshotEvent) _then;

/// Create a copy of MessagesSnapshotEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messages = null,}) {
  return _then(_self.copyWith(
messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<Message>,
  ));
}

}


/// Adds pattern-matching-related methods to [MessagesSnapshotEvent].
extension MessagesSnapshotEventPatterns on MessagesSnapshotEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MessagesSnapshotEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MessagesSnapshotEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MessagesSnapshotEvent value)  $default,){
final _that = this;
switch (_that) {
case _MessagesSnapshotEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MessagesSnapshotEvent value)?  $default,){
final _that = this;
switch (_that) {
case _MessagesSnapshotEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Message> messages)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MessagesSnapshotEvent() when $default != null:
return $default(_that.messages);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Message> messages)  $default,) {final _that = this;
switch (_that) {
case _MessagesSnapshotEvent():
return $default(_that.messages);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Message> messages)?  $default,) {final _that = this;
switch (_that) {
case _MessagesSnapshotEvent() when $default != null:
return $default(_that.messages);case _:
  return null;

}
}

}

/// @nodoc


class _MessagesSnapshotEvent extends MessagesSnapshotEvent {
  const _MessagesSnapshotEvent({required final  List<Message> messages}): _messages = messages,super._();
  

 final  List<Message> _messages;
@override List<Message> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}


/// Create a copy of MessagesSnapshotEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MessagesSnapshotEventCopyWith<_MessagesSnapshotEvent> get copyWith => __$MessagesSnapshotEventCopyWithImpl<_MessagesSnapshotEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _MessagesSnapshotEvent&&const DeepCollectionEquality().equals(other._messages, _messages));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_messages));

@override
String toString() {
  return 'MessagesSnapshotEvent(messages: $messages)';
}


}

/// @nodoc
abstract mixin class _$MessagesSnapshotEventCopyWith<$Res> implements $MessagesSnapshotEventCopyWith<$Res> {
  factory _$MessagesSnapshotEventCopyWith(_MessagesSnapshotEvent value, $Res Function(_MessagesSnapshotEvent) _then) = __$MessagesSnapshotEventCopyWithImpl;
@override @useResult
$Res call({
 List<Message> messages
});




}
/// @nodoc
class __$MessagesSnapshotEventCopyWithImpl<$Res>
    implements _$MessagesSnapshotEventCopyWith<$Res> {
  __$MessagesSnapshotEventCopyWithImpl(this._self, this._then);

  final _MessagesSnapshotEvent _self;
  final $Res Function(_MessagesSnapshotEvent) _then;

/// Create a copy of MessagesSnapshotEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messages = null,}) {
  return _then(_MessagesSnapshotEvent(
messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<Message>,
  ));
}


}

/// @nodoc
mixin _$ActivitySnapshotEvent {

 String get messageId; String get activityType; Map<String, dynamic> get content; bool? get replace;
/// Create a copy of ActivitySnapshotEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivitySnapshotEventCopyWith<ActivitySnapshotEvent> get copyWith => _$ActivitySnapshotEventCopyWithImpl<ActivitySnapshotEvent>(this as ActivitySnapshotEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivitySnapshotEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.activityType, activityType) || other.activityType == activityType)&&const DeepCollectionEquality().equals(other.content, content)&&(identical(other.replace, replace) || other.replace == replace));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,activityType,const DeepCollectionEquality().hash(content),replace);

@override
String toString() {
  return 'ActivitySnapshotEvent(messageId: $messageId, activityType: $activityType, content: $content, replace: $replace)';
}


}

/// @nodoc
abstract mixin class $ActivitySnapshotEventCopyWith<$Res>  {
  factory $ActivitySnapshotEventCopyWith(ActivitySnapshotEvent value, $Res Function(ActivitySnapshotEvent) _then) = _$ActivitySnapshotEventCopyWithImpl;
@useResult
$Res call({
 String messageId, String activityType, Map<String, dynamic> content, bool? replace
});




}
/// @nodoc
class _$ActivitySnapshotEventCopyWithImpl<$Res>
    implements $ActivitySnapshotEventCopyWith<$Res> {
  _$ActivitySnapshotEventCopyWithImpl(this._self, this._then);

  final ActivitySnapshotEvent _self;
  final $Res Function(ActivitySnapshotEvent) _then;

/// Create a copy of ActivitySnapshotEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? activityType = null,Object? content = null,Object? replace = freezed,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,activityType: null == activityType ? _self.activityType : activityType // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,replace: freezed == replace ? _self.replace : replace // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}

}


/// Adds pattern-matching-related methods to [ActivitySnapshotEvent].
extension ActivitySnapshotEventPatterns on ActivitySnapshotEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivitySnapshotEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivitySnapshotEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivitySnapshotEvent value)  $default,){
final _that = this;
switch (_that) {
case _ActivitySnapshotEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivitySnapshotEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ActivitySnapshotEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId,  String activityType,  Map<String, dynamic> content,  bool? replace)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivitySnapshotEvent() when $default != null:
return $default(_that.messageId,_that.activityType,_that.content,_that.replace);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId,  String activityType,  Map<String, dynamic> content,  bool? replace)  $default,) {final _that = this;
switch (_that) {
case _ActivitySnapshotEvent():
return $default(_that.messageId,_that.activityType,_that.content,_that.replace);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId,  String activityType,  Map<String, dynamic> content,  bool? replace)?  $default,) {final _that = this;
switch (_that) {
case _ActivitySnapshotEvent() when $default != null:
return $default(_that.messageId,_that.activityType,_that.content,_that.replace);case _:
  return null;

}
}

}

/// @nodoc


class _ActivitySnapshotEvent extends ActivitySnapshotEvent {
  const _ActivitySnapshotEvent({required this.messageId, required this.activityType, required final  Map<String, dynamic> content, this.replace}): _content = content,super._();
  

@override final  String messageId;
@override final  String activityType;
 final  Map<String, dynamic> _content;
@override Map<String, dynamic> get content {
  if (_content is EqualUnmodifiableMapView) return _content;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_content);
}

@override final  bool? replace;

/// Create a copy of ActivitySnapshotEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivitySnapshotEventCopyWith<_ActivitySnapshotEvent> get copyWith => __$ActivitySnapshotEventCopyWithImpl<_ActivitySnapshotEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivitySnapshotEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.activityType, activityType) || other.activityType == activityType)&&const DeepCollectionEquality().equals(other._content, _content)&&(identical(other.replace, replace) || other.replace == replace));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,activityType,const DeepCollectionEquality().hash(_content),replace);

@override
String toString() {
  return 'ActivitySnapshotEvent(messageId: $messageId, activityType: $activityType, content: $content, replace: $replace)';
}


}

/// @nodoc
abstract mixin class _$ActivitySnapshotEventCopyWith<$Res> implements $ActivitySnapshotEventCopyWith<$Res> {
  factory _$ActivitySnapshotEventCopyWith(_ActivitySnapshotEvent value, $Res Function(_ActivitySnapshotEvent) _then) = __$ActivitySnapshotEventCopyWithImpl;
@override @useResult
$Res call({
 String messageId, String activityType, Map<String, dynamic> content, bool? replace
});




}
/// @nodoc
class __$ActivitySnapshotEventCopyWithImpl<$Res>
    implements _$ActivitySnapshotEventCopyWith<$Res> {
  __$ActivitySnapshotEventCopyWithImpl(this._self, this._then);

  final _ActivitySnapshotEvent _self;
  final $Res Function(_ActivitySnapshotEvent) _then;

/// Create a copy of ActivitySnapshotEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? activityType = null,Object? content = null,Object? replace = freezed,}) {
  return _then(_ActivitySnapshotEvent(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,activityType: null == activityType ? _self.activityType : activityType // ignore: cast_nullable_to_non_nullable
as String,content: null == content ? _self._content : content // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,replace: freezed == replace ? _self.replace : replace // ignore: cast_nullable_to_non_nullable
as bool?,
  ));
}


}

/// @nodoc
mixin _$ActivityDeltaEvent {

 String get messageId; String get activityType; List<JsonPatchOp> get patches;
/// Create a copy of ActivityDeltaEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActivityDeltaEventCopyWith<ActivityDeltaEvent> get copyWith => _$ActivityDeltaEventCopyWithImpl<ActivityDeltaEvent>(this as ActivityDeltaEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActivityDeltaEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.activityType, activityType) || other.activityType == activityType)&&const DeepCollectionEquality().equals(other.patches, patches));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,activityType,const DeepCollectionEquality().hash(patches));

@override
String toString() {
  return 'ActivityDeltaEvent(messageId: $messageId, activityType: $activityType, patches: $patches)';
}


}

/// @nodoc
abstract mixin class $ActivityDeltaEventCopyWith<$Res>  {
  factory $ActivityDeltaEventCopyWith(ActivityDeltaEvent value, $Res Function(ActivityDeltaEvent) _then) = _$ActivityDeltaEventCopyWithImpl;
@useResult
$Res call({
 String messageId, String activityType, List<JsonPatchOp> patches
});




}
/// @nodoc
class _$ActivityDeltaEventCopyWithImpl<$Res>
    implements $ActivityDeltaEventCopyWith<$Res> {
  _$ActivityDeltaEventCopyWithImpl(this._self, this._then);

  final ActivityDeltaEvent _self;
  final $Res Function(ActivityDeltaEvent) _then;

/// Create a copy of ActivityDeltaEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? activityType = null,Object? patches = null,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,activityType: null == activityType ? _self.activityType : activityType // ignore: cast_nullable_to_non_nullable
as String,patches: null == patches ? _self.patches : patches // ignore: cast_nullable_to_non_nullable
as List<JsonPatchOp>,
  ));
}

}


/// Adds pattern-matching-related methods to [ActivityDeltaEvent].
extension ActivityDeltaEventPatterns on ActivityDeltaEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActivityDeltaEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActivityDeltaEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActivityDeltaEvent value)  $default,){
final _that = this;
switch (_that) {
case _ActivityDeltaEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActivityDeltaEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ActivityDeltaEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId,  String activityType,  List<JsonPatchOp> patches)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActivityDeltaEvent() when $default != null:
return $default(_that.messageId,_that.activityType,_that.patches);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId,  String activityType,  List<JsonPatchOp> patches)  $default,) {final _that = this;
switch (_that) {
case _ActivityDeltaEvent():
return $default(_that.messageId,_that.activityType,_that.patches);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId,  String activityType,  List<JsonPatchOp> patches)?  $default,) {final _that = this;
switch (_that) {
case _ActivityDeltaEvent() when $default != null:
return $default(_that.messageId,_that.activityType,_that.patches);case _:
  return null;

}
}

}

/// @nodoc


class _ActivityDeltaEvent extends ActivityDeltaEvent {
  const _ActivityDeltaEvent({required this.messageId, required this.activityType, required final  List<JsonPatchOp> patches}): _patches = patches,super._();
  

@override final  String messageId;
@override final  String activityType;
 final  List<JsonPatchOp> _patches;
@override List<JsonPatchOp> get patches {
  if (_patches is EqualUnmodifiableListView) return _patches;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_patches);
}


/// Create a copy of ActivityDeltaEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActivityDeltaEventCopyWith<_ActivityDeltaEvent> get copyWith => __$ActivityDeltaEventCopyWithImpl<_ActivityDeltaEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActivityDeltaEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.activityType, activityType) || other.activityType == activityType)&&const DeepCollectionEquality().equals(other._patches, _patches));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,activityType,const DeepCollectionEquality().hash(_patches));

@override
String toString() {
  return 'ActivityDeltaEvent(messageId: $messageId, activityType: $activityType, patches: $patches)';
}


}

/// @nodoc
abstract mixin class _$ActivityDeltaEventCopyWith<$Res> implements $ActivityDeltaEventCopyWith<$Res> {
  factory _$ActivityDeltaEventCopyWith(_ActivityDeltaEvent value, $Res Function(_ActivityDeltaEvent) _then) = __$ActivityDeltaEventCopyWithImpl;
@override @useResult
$Res call({
 String messageId, String activityType, List<JsonPatchOp> patches
});




}
/// @nodoc
class __$ActivityDeltaEventCopyWithImpl<$Res>
    implements _$ActivityDeltaEventCopyWith<$Res> {
  __$ActivityDeltaEventCopyWithImpl(this._self, this._then);

  final _ActivityDeltaEvent _self;
  final $Res Function(_ActivityDeltaEvent) _then;

/// Create a copy of ActivityDeltaEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? activityType = null,Object? patches = null,}) {
  return _then(_ActivityDeltaEvent(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,activityType: null == activityType ? _self.activityType : activityType // ignore: cast_nullable_to_non_nullable
as String,patches: null == patches ? _self._patches : patches // ignore: cast_nullable_to_non_nullable
as List<JsonPatchOp>,
  ));
}


}

/// @nodoc
mixin _$ReasoningStartEvent {

 String get messageId;
/// Create a copy of ReasoningStartEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReasoningStartEventCopyWith<ReasoningStartEvent> get copyWith => _$ReasoningStartEventCopyWithImpl<ReasoningStartEvent>(this as ReasoningStartEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReasoningStartEvent&&(identical(other.messageId, messageId) || other.messageId == messageId));
}


@override
int get hashCode => Object.hash(runtimeType,messageId);

@override
String toString() {
  return 'ReasoningStartEvent(messageId: $messageId)';
}


}

/// @nodoc
abstract mixin class $ReasoningStartEventCopyWith<$Res>  {
  factory $ReasoningStartEventCopyWith(ReasoningStartEvent value, $Res Function(ReasoningStartEvent) _then) = _$ReasoningStartEventCopyWithImpl;
@useResult
$Res call({
 String messageId
});




}
/// @nodoc
class _$ReasoningStartEventCopyWithImpl<$Res>
    implements $ReasoningStartEventCopyWith<$Res> {
  _$ReasoningStartEventCopyWithImpl(this._self, this._then);

  final ReasoningStartEvent _self;
  final $Res Function(ReasoningStartEvent) _then;

/// Create a copy of ReasoningStartEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ReasoningStartEvent].
extension ReasoningStartEventPatterns on ReasoningStartEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReasoningStartEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReasoningStartEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReasoningStartEvent value)  $default,){
final _that = this;
switch (_that) {
case _ReasoningStartEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReasoningStartEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ReasoningStartEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReasoningStartEvent() when $default != null:
return $default(_that.messageId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId)  $default,) {final _that = this;
switch (_that) {
case _ReasoningStartEvent():
return $default(_that.messageId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId)?  $default,) {final _that = this;
switch (_that) {
case _ReasoningStartEvent() when $default != null:
return $default(_that.messageId);case _:
  return null;

}
}

}

/// @nodoc


class _ReasoningStartEvent extends ReasoningStartEvent {
  const _ReasoningStartEvent({required this.messageId}): super._();
  

@override final  String messageId;

/// Create a copy of ReasoningStartEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReasoningStartEventCopyWith<_ReasoningStartEvent> get copyWith => __$ReasoningStartEventCopyWithImpl<_ReasoningStartEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReasoningStartEvent&&(identical(other.messageId, messageId) || other.messageId == messageId));
}


@override
int get hashCode => Object.hash(runtimeType,messageId);

@override
String toString() {
  return 'ReasoningStartEvent(messageId: $messageId)';
}


}

/// @nodoc
abstract mixin class _$ReasoningStartEventCopyWith<$Res> implements $ReasoningStartEventCopyWith<$Res> {
  factory _$ReasoningStartEventCopyWith(_ReasoningStartEvent value, $Res Function(_ReasoningStartEvent) _then) = __$ReasoningStartEventCopyWithImpl;
@override @useResult
$Res call({
 String messageId
});




}
/// @nodoc
class __$ReasoningStartEventCopyWithImpl<$Res>
    implements _$ReasoningStartEventCopyWith<$Res> {
  __$ReasoningStartEventCopyWithImpl(this._self, this._then);

  final _ReasoningStartEvent _self;
  final $Res Function(_ReasoningStartEvent) _then;

/// Create a copy of ReasoningStartEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,}) {
  return _then(_ReasoningStartEvent(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ReasoningEndEvent {

 String get messageId;
/// Create a copy of ReasoningEndEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReasoningEndEventCopyWith<ReasoningEndEvent> get copyWith => _$ReasoningEndEventCopyWithImpl<ReasoningEndEvent>(this as ReasoningEndEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReasoningEndEvent&&(identical(other.messageId, messageId) || other.messageId == messageId));
}


@override
int get hashCode => Object.hash(runtimeType,messageId);

@override
String toString() {
  return 'ReasoningEndEvent(messageId: $messageId)';
}


}

/// @nodoc
abstract mixin class $ReasoningEndEventCopyWith<$Res>  {
  factory $ReasoningEndEventCopyWith(ReasoningEndEvent value, $Res Function(ReasoningEndEvent) _then) = _$ReasoningEndEventCopyWithImpl;
@useResult
$Res call({
 String messageId
});




}
/// @nodoc
class _$ReasoningEndEventCopyWithImpl<$Res>
    implements $ReasoningEndEventCopyWith<$Res> {
  _$ReasoningEndEventCopyWithImpl(this._self, this._then);

  final ReasoningEndEvent _self;
  final $Res Function(ReasoningEndEvent) _then;

/// Create a copy of ReasoningEndEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ReasoningEndEvent].
extension ReasoningEndEventPatterns on ReasoningEndEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReasoningEndEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReasoningEndEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReasoningEndEvent value)  $default,){
final _that = this;
switch (_that) {
case _ReasoningEndEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReasoningEndEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ReasoningEndEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReasoningEndEvent() when $default != null:
return $default(_that.messageId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId)  $default,) {final _that = this;
switch (_that) {
case _ReasoningEndEvent():
return $default(_that.messageId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId)?  $default,) {final _that = this;
switch (_that) {
case _ReasoningEndEvent() when $default != null:
return $default(_that.messageId);case _:
  return null;

}
}

}

/// @nodoc


class _ReasoningEndEvent extends ReasoningEndEvent {
  const _ReasoningEndEvent({required this.messageId}): super._();
  

@override final  String messageId;

/// Create a copy of ReasoningEndEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReasoningEndEventCopyWith<_ReasoningEndEvent> get copyWith => __$ReasoningEndEventCopyWithImpl<_ReasoningEndEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReasoningEndEvent&&(identical(other.messageId, messageId) || other.messageId == messageId));
}


@override
int get hashCode => Object.hash(runtimeType,messageId);

@override
String toString() {
  return 'ReasoningEndEvent(messageId: $messageId)';
}


}

/// @nodoc
abstract mixin class _$ReasoningEndEventCopyWith<$Res> implements $ReasoningEndEventCopyWith<$Res> {
  factory _$ReasoningEndEventCopyWith(_ReasoningEndEvent value, $Res Function(_ReasoningEndEvent) _then) = __$ReasoningEndEventCopyWithImpl;
@override @useResult
$Res call({
 String messageId
});




}
/// @nodoc
class __$ReasoningEndEventCopyWithImpl<$Res>
    implements _$ReasoningEndEventCopyWith<$Res> {
  __$ReasoningEndEventCopyWithImpl(this._self, this._then);

  final _ReasoningEndEvent _self;
  final $Res Function(_ReasoningEndEvent) _then;

/// Create a copy of ReasoningEndEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,}) {
  return _then(_ReasoningEndEvent(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ReasoningMessageStartEvent {

 String get messageId; String get role;
/// Create a copy of ReasoningMessageStartEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReasoningMessageStartEventCopyWith<ReasoningMessageStartEvent> get copyWith => _$ReasoningMessageStartEventCopyWithImpl<ReasoningMessageStartEvent>(this as ReasoningMessageStartEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReasoningMessageStartEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.role, role) || other.role == role));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,role);

@override
String toString() {
  return 'ReasoningMessageStartEvent(messageId: $messageId, role: $role)';
}


}

/// @nodoc
abstract mixin class $ReasoningMessageStartEventCopyWith<$Res>  {
  factory $ReasoningMessageStartEventCopyWith(ReasoningMessageStartEvent value, $Res Function(ReasoningMessageStartEvent) _then) = _$ReasoningMessageStartEventCopyWithImpl;
@useResult
$Res call({
 String messageId, String role
});




}
/// @nodoc
class _$ReasoningMessageStartEventCopyWithImpl<$Res>
    implements $ReasoningMessageStartEventCopyWith<$Res> {
  _$ReasoningMessageStartEventCopyWithImpl(this._self, this._then);

  final ReasoningMessageStartEvent _self;
  final $Res Function(ReasoningMessageStartEvent) _then;

/// Create a copy of ReasoningMessageStartEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? role = null,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ReasoningMessageStartEvent].
extension ReasoningMessageStartEventPatterns on ReasoningMessageStartEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReasoningMessageStartEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReasoningMessageStartEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReasoningMessageStartEvent value)  $default,){
final _that = this;
switch (_that) {
case _ReasoningMessageStartEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReasoningMessageStartEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ReasoningMessageStartEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId,  String role)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReasoningMessageStartEvent() when $default != null:
return $default(_that.messageId,_that.role);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId,  String role)  $default,) {final _that = this;
switch (_that) {
case _ReasoningMessageStartEvent():
return $default(_that.messageId,_that.role);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId,  String role)?  $default,) {final _that = this;
switch (_that) {
case _ReasoningMessageStartEvent() when $default != null:
return $default(_that.messageId,_that.role);case _:
  return null;

}
}

}

/// @nodoc


class _ReasoningMessageStartEvent extends ReasoningMessageStartEvent {
  const _ReasoningMessageStartEvent({required this.messageId, required this.role}): super._();
  

@override final  String messageId;
@override final  String role;

/// Create a copy of ReasoningMessageStartEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReasoningMessageStartEventCopyWith<_ReasoningMessageStartEvent> get copyWith => __$ReasoningMessageStartEventCopyWithImpl<_ReasoningMessageStartEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReasoningMessageStartEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.role, role) || other.role == role));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,role);

@override
String toString() {
  return 'ReasoningMessageStartEvent(messageId: $messageId, role: $role)';
}


}

/// @nodoc
abstract mixin class _$ReasoningMessageStartEventCopyWith<$Res> implements $ReasoningMessageStartEventCopyWith<$Res> {
  factory _$ReasoningMessageStartEventCopyWith(_ReasoningMessageStartEvent value, $Res Function(_ReasoningMessageStartEvent) _then) = __$ReasoningMessageStartEventCopyWithImpl;
@override @useResult
$Res call({
 String messageId, String role
});




}
/// @nodoc
class __$ReasoningMessageStartEventCopyWithImpl<$Res>
    implements _$ReasoningMessageStartEventCopyWith<$Res> {
  __$ReasoningMessageStartEventCopyWithImpl(this._self, this._then);

  final _ReasoningMessageStartEvent _self;
  final $Res Function(_ReasoningMessageStartEvent) _then;

/// Create a copy of ReasoningMessageStartEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? role = null,}) {
  return _then(_ReasoningMessageStartEvent(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ReasoningMessageContentEvent {

 String get messageId; String get delta;
/// Create a copy of ReasoningMessageContentEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReasoningMessageContentEventCopyWith<ReasoningMessageContentEvent> get copyWith => _$ReasoningMessageContentEventCopyWithImpl<ReasoningMessageContentEvent>(this as ReasoningMessageContentEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReasoningMessageContentEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.delta, delta) || other.delta == delta));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,delta);

@override
String toString() {
  return 'ReasoningMessageContentEvent(messageId: $messageId, delta: $delta)';
}


}

/// @nodoc
abstract mixin class $ReasoningMessageContentEventCopyWith<$Res>  {
  factory $ReasoningMessageContentEventCopyWith(ReasoningMessageContentEvent value, $Res Function(ReasoningMessageContentEvent) _then) = _$ReasoningMessageContentEventCopyWithImpl;
@useResult
$Res call({
 String messageId, String delta
});




}
/// @nodoc
class _$ReasoningMessageContentEventCopyWithImpl<$Res>
    implements $ReasoningMessageContentEventCopyWith<$Res> {
  _$ReasoningMessageContentEventCopyWithImpl(this._self, this._then);

  final ReasoningMessageContentEvent _self;
  final $Res Function(ReasoningMessageContentEvent) _then;

/// Create a copy of ReasoningMessageContentEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? delta = null,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,delta: null == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ReasoningMessageContentEvent].
extension ReasoningMessageContentEventPatterns on ReasoningMessageContentEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReasoningMessageContentEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReasoningMessageContentEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReasoningMessageContentEvent value)  $default,){
final _that = this;
switch (_that) {
case _ReasoningMessageContentEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReasoningMessageContentEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ReasoningMessageContentEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId,  String delta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReasoningMessageContentEvent() when $default != null:
return $default(_that.messageId,_that.delta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId,  String delta)  $default,) {final _that = this;
switch (_that) {
case _ReasoningMessageContentEvent():
return $default(_that.messageId,_that.delta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId,  String delta)?  $default,) {final _that = this;
switch (_that) {
case _ReasoningMessageContentEvent() when $default != null:
return $default(_that.messageId,_that.delta);case _:
  return null;

}
}

}

/// @nodoc


class _ReasoningMessageContentEvent extends ReasoningMessageContentEvent {
  const _ReasoningMessageContentEvent({required this.messageId, required this.delta}): super._();
  

@override final  String messageId;
@override final  String delta;

/// Create a copy of ReasoningMessageContentEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReasoningMessageContentEventCopyWith<_ReasoningMessageContentEvent> get copyWith => __$ReasoningMessageContentEventCopyWithImpl<_ReasoningMessageContentEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReasoningMessageContentEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.delta, delta) || other.delta == delta));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,delta);

@override
String toString() {
  return 'ReasoningMessageContentEvent(messageId: $messageId, delta: $delta)';
}


}

/// @nodoc
abstract mixin class _$ReasoningMessageContentEventCopyWith<$Res> implements $ReasoningMessageContentEventCopyWith<$Res> {
  factory _$ReasoningMessageContentEventCopyWith(_ReasoningMessageContentEvent value, $Res Function(_ReasoningMessageContentEvent) _then) = __$ReasoningMessageContentEventCopyWithImpl;
@override @useResult
$Res call({
 String messageId, String delta
});




}
/// @nodoc
class __$ReasoningMessageContentEventCopyWithImpl<$Res>
    implements _$ReasoningMessageContentEventCopyWith<$Res> {
  __$ReasoningMessageContentEventCopyWithImpl(this._self, this._then);

  final _ReasoningMessageContentEvent _self;
  final $Res Function(_ReasoningMessageContentEvent) _then;

/// Create a copy of ReasoningMessageContentEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? delta = null,}) {
  return _then(_ReasoningMessageContentEvent(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,delta: null == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ReasoningMessageEndEvent {

 String get messageId;
/// Create a copy of ReasoningMessageEndEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReasoningMessageEndEventCopyWith<ReasoningMessageEndEvent> get copyWith => _$ReasoningMessageEndEventCopyWithImpl<ReasoningMessageEndEvent>(this as ReasoningMessageEndEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReasoningMessageEndEvent&&(identical(other.messageId, messageId) || other.messageId == messageId));
}


@override
int get hashCode => Object.hash(runtimeType,messageId);

@override
String toString() {
  return 'ReasoningMessageEndEvent(messageId: $messageId)';
}


}

/// @nodoc
abstract mixin class $ReasoningMessageEndEventCopyWith<$Res>  {
  factory $ReasoningMessageEndEventCopyWith(ReasoningMessageEndEvent value, $Res Function(ReasoningMessageEndEvent) _then) = _$ReasoningMessageEndEventCopyWithImpl;
@useResult
$Res call({
 String messageId
});




}
/// @nodoc
class _$ReasoningMessageEndEventCopyWithImpl<$Res>
    implements $ReasoningMessageEndEventCopyWith<$Res> {
  _$ReasoningMessageEndEventCopyWithImpl(this._self, this._then);

  final ReasoningMessageEndEvent _self;
  final $Res Function(ReasoningMessageEndEvent) _then;

/// Create a copy of ReasoningMessageEndEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ReasoningMessageEndEvent].
extension ReasoningMessageEndEventPatterns on ReasoningMessageEndEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReasoningMessageEndEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReasoningMessageEndEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReasoningMessageEndEvent value)  $default,){
final _that = this;
switch (_that) {
case _ReasoningMessageEndEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReasoningMessageEndEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ReasoningMessageEndEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String messageId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReasoningMessageEndEvent() when $default != null:
return $default(_that.messageId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String messageId)  $default,) {final _that = this;
switch (_that) {
case _ReasoningMessageEndEvent():
return $default(_that.messageId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String messageId)?  $default,) {final _that = this;
switch (_that) {
case _ReasoningMessageEndEvent() when $default != null:
return $default(_that.messageId);case _:
  return null;

}
}

}

/// @nodoc


class _ReasoningMessageEndEvent extends ReasoningMessageEndEvent {
  const _ReasoningMessageEndEvent({required this.messageId}): super._();
  

@override final  String messageId;

/// Create a copy of ReasoningMessageEndEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReasoningMessageEndEventCopyWith<_ReasoningMessageEndEvent> get copyWith => __$ReasoningMessageEndEventCopyWithImpl<_ReasoningMessageEndEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReasoningMessageEndEvent&&(identical(other.messageId, messageId) || other.messageId == messageId));
}


@override
int get hashCode => Object.hash(runtimeType,messageId);

@override
String toString() {
  return 'ReasoningMessageEndEvent(messageId: $messageId)';
}


}

/// @nodoc
abstract mixin class _$ReasoningMessageEndEventCopyWith<$Res> implements $ReasoningMessageEndEventCopyWith<$Res> {
  factory _$ReasoningMessageEndEventCopyWith(_ReasoningMessageEndEvent value, $Res Function(_ReasoningMessageEndEvent) _then) = __$ReasoningMessageEndEventCopyWithImpl;
@override @useResult
$Res call({
 String messageId
});




}
/// @nodoc
class __$ReasoningMessageEndEventCopyWithImpl<$Res>
    implements _$ReasoningMessageEndEventCopyWith<$Res> {
  __$ReasoningMessageEndEventCopyWithImpl(this._self, this._then);

  final _ReasoningMessageEndEvent _self;
  final $Res Function(_ReasoningMessageEndEvent) _then;

/// Create a copy of ReasoningMessageEndEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,}) {
  return _then(_ReasoningMessageEndEvent(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$ReasoningMessageChunkEvent {

 String? get messageId; String? get delta;
/// Create a copy of ReasoningMessageChunkEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReasoningMessageChunkEventCopyWith<ReasoningMessageChunkEvent> get copyWith => _$ReasoningMessageChunkEventCopyWithImpl<ReasoningMessageChunkEvent>(this as ReasoningMessageChunkEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReasoningMessageChunkEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.delta, delta) || other.delta == delta));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,delta);

@override
String toString() {
  return 'ReasoningMessageChunkEvent(messageId: $messageId, delta: $delta)';
}


}

/// @nodoc
abstract mixin class $ReasoningMessageChunkEventCopyWith<$Res>  {
  factory $ReasoningMessageChunkEventCopyWith(ReasoningMessageChunkEvent value, $Res Function(ReasoningMessageChunkEvent) _then) = _$ReasoningMessageChunkEventCopyWithImpl;
@useResult
$Res call({
 String? messageId, String? delta
});




}
/// @nodoc
class _$ReasoningMessageChunkEventCopyWithImpl<$Res>
    implements $ReasoningMessageChunkEventCopyWith<$Res> {
  _$ReasoningMessageChunkEventCopyWithImpl(this._self, this._then);

  final ReasoningMessageChunkEvent _self;
  final $Res Function(ReasoningMessageChunkEvent) _then;

/// Create a copy of ReasoningMessageChunkEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = freezed,Object? delta = freezed,}) {
  return _then(_self.copyWith(
messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,delta: freezed == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ReasoningMessageChunkEvent].
extension ReasoningMessageChunkEventPatterns on ReasoningMessageChunkEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReasoningMessageChunkEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReasoningMessageChunkEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReasoningMessageChunkEvent value)  $default,){
final _that = this;
switch (_that) {
case _ReasoningMessageChunkEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReasoningMessageChunkEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ReasoningMessageChunkEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? messageId,  String? delta)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReasoningMessageChunkEvent() when $default != null:
return $default(_that.messageId,_that.delta);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? messageId,  String? delta)  $default,) {final _that = this;
switch (_that) {
case _ReasoningMessageChunkEvent():
return $default(_that.messageId,_that.delta);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? messageId,  String? delta)?  $default,) {final _that = this;
switch (_that) {
case _ReasoningMessageChunkEvent() when $default != null:
return $default(_that.messageId,_that.delta);case _:
  return null;

}
}

}

/// @nodoc


class _ReasoningMessageChunkEvent extends ReasoningMessageChunkEvent {
  const _ReasoningMessageChunkEvent({this.messageId, this.delta}): super._();
  

@override final  String? messageId;
@override final  String? delta;

/// Create a copy of ReasoningMessageChunkEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReasoningMessageChunkEventCopyWith<_ReasoningMessageChunkEvent> get copyWith => __$ReasoningMessageChunkEventCopyWithImpl<_ReasoningMessageChunkEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReasoningMessageChunkEvent&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.delta, delta) || other.delta == delta));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,delta);

@override
String toString() {
  return 'ReasoningMessageChunkEvent(messageId: $messageId, delta: $delta)';
}


}

/// @nodoc
abstract mixin class _$ReasoningMessageChunkEventCopyWith<$Res> implements $ReasoningMessageChunkEventCopyWith<$Res> {
  factory _$ReasoningMessageChunkEventCopyWith(_ReasoningMessageChunkEvent value, $Res Function(_ReasoningMessageChunkEvent) _then) = __$ReasoningMessageChunkEventCopyWithImpl;
@override @useResult
$Res call({
 String? messageId, String? delta
});




}
/// @nodoc
class __$ReasoningMessageChunkEventCopyWithImpl<$Res>
    implements _$ReasoningMessageChunkEventCopyWith<$Res> {
  __$ReasoningMessageChunkEventCopyWithImpl(this._self, this._then);

  final _ReasoningMessageChunkEvent _self;
  final $Res Function(_ReasoningMessageChunkEvent) _then;

/// Create a copy of ReasoningMessageChunkEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = freezed,Object? delta = freezed,}) {
  return _then(_ReasoningMessageChunkEvent(
messageId: freezed == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as String?,delta: freezed == delta ? _self.delta : delta // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$ReasoningEncryptedValueEvent {

 String get entityId; String get subtype; Uint8List get encryptedValue; String get encryptedValueBase64;
/// Create a copy of ReasoningEncryptedValueEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReasoningEncryptedValueEventCopyWith<ReasoningEncryptedValueEvent> get copyWith => _$ReasoningEncryptedValueEventCopyWithImpl<ReasoningEncryptedValueEvent>(this as ReasoningEncryptedValueEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReasoningEncryptedValueEvent&&(identical(other.entityId, entityId) || other.entityId == entityId)&&(identical(other.subtype, subtype) || other.subtype == subtype)&&const DeepCollectionEquality().equals(other.encryptedValue, encryptedValue)&&(identical(other.encryptedValueBase64, encryptedValueBase64) || other.encryptedValueBase64 == encryptedValueBase64));
}


@override
int get hashCode => Object.hash(runtimeType,entityId,subtype,const DeepCollectionEquality().hash(encryptedValue),encryptedValueBase64);

@override
String toString() {
  return 'ReasoningEncryptedValueEvent(entityId: $entityId, subtype: $subtype, encryptedValue: $encryptedValue, encryptedValueBase64: $encryptedValueBase64)';
}


}

/// @nodoc
abstract mixin class $ReasoningEncryptedValueEventCopyWith<$Res>  {
  factory $ReasoningEncryptedValueEventCopyWith(ReasoningEncryptedValueEvent value, $Res Function(ReasoningEncryptedValueEvent) _then) = _$ReasoningEncryptedValueEventCopyWithImpl;
@useResult
$Res call({
 String entityId, String subtype, Uint8List encryptedValue, String encryptedValueBase64
});




}
/// @nodoc
class _$ReasoningEncryptedValueEventCopyWithImpl<$Res>
    implements $ReasoningEncryptedValueEventCopyWith<$Res> {
  _$ReasoningEncryptedValueEventCopyWithImpl(this._self, this._then);

  final ReasoningEncryptedValueEvent _self;
  final $Res Function(ReasoningEncryptedValueEvent) _then;

/// Create a copy of ReasoningEncryptedValueEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? entityId = null,Object? subtype = null,Object? encryptedValue = null,Object? encryptedValueBase64 = null,}) {
  return _then(_self.copyWith(
entityId: null == entityId ? _self.entityId : entityId // ignore: cast_nullable_to_non_nullable
as String,subtype: null == subtype ? _self.subtype : subtype // ignore: cast_nullable_to_non_nullable
as String,encryptedValue: null == encryptedValue ? _self.encryptedValue : encryptedValue // ignore: cast_nullable_to_non_nullable
as Uint8List,encryptedValueBase64: null == encryptedValueBase64 ? _self.encryptedValueBase64 : encryptedValueBase64 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ReasoningEncryptedValueEvent].
extension ReasoningEncryptedValueEventPatterns on ReasoningEncryptedValueEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReasoningEncryptedValueEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReasoningEncryptedValueEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReasoningEncryptedValueEvent value)  $default,){
final _that = this;
switch (_that) {
case _ReasoningEncryptedValueEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReasoningEncryptedValueEvent value)?  $default,){
final _that = this;
switch (_that) {
case _ReasoningEncryptedValueEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String entityId,  String subtype,  Uint8List encryptedValue,  String encryptedValueBase64)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReasoningEncryptedValueEvent() when $default != null:
return $default(_that.entityId,_that.subtype,_that.encryptedValue,_that.encryptedValueBase64);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String entityId,  String subtype,  Uint8List encryptedValue,  String encryptedValueBase64)  $default,) {final _that = this;
switch (_that) {
case _ReasoningEncryptedValueEvent():
return $default(_that.entityId,_that.subtype,_that.encryptedValue,_that.encryptedValueBase64);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String entityId,  String subtype,  Uint8List encryptedValue,  String encryptedValueBase64)?  $default,) {final _that = this;
switch (_that) {
case _ReasoningEncryptedValueEvent() when $default != null:
return $default(_that.entityId,_that.subtype,_that.encryptedValue,_that.encryptedValueBase64);case _:
  return null;

}
}

}

/// @nodoc


class _ReasoningEncryptedValueEvent extends ReasoningEncryptedValueEvent {
  const _ReasoningEncryptedValueEvent({required this.entityId, required this.subtype, required this.encryptedValue, required this.encryptedValueBase64}): super._();
  

@override final  String entityId;
@override final  String subtype;
@override final  Uint8List encryptedValue;
@override final  String encryptedValueBase64;

/// Create a copy of ReasoningEncryptedValueEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReasoningEncryptedValueEventCopyWith<_ReasoningEncryptedValueEvent> get copyWith => __$ReasoningEncryptedValueEventCopyWithImpl<_ReasoningEncryptedValueEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReasoningEncryptedValueEvent&&(identical(other.entityId, entityId) || other.entityId == entityId)&&(identical(other.subtype, subtype) || other.subtype == subtype)&&const DeepCollectionEquality().equals(other.encryptedValue, encryptedValue)&&(identical(other.encryptedValueBase64, encryptedValueBase64) || other.encryptedValueBase64 == encryptedValueBase64));
}


@override
int get hashCode => Object.hash(runtimeType,entityId,subtype,const DeepCollectionEquality().hash(encryptedValue),encryptedValueBase64);

@override
String toString() {
  return 'ReasoningEncryptedValueEvent(entityId: $entityId, subtype: $subtype, encryptedValue: $encryptedValue, encryptedValueBase64: $encryptedValueBase64)';
}


}

/// @nodoc
abstract mixin class _$ReasoningEncryptedValueEventCopyWith<$Res> implements $ReasoningEncryptedValueEventCopyWith<$Res> {
  factory _$ReasoningEncryptedValueEventCopyWith(_ReasoningEncryptedValueEvent value, $Res Function(_ReasoningEncryptedValueEvent) _then) = __$ReasoningEncryptedValueEventCopyWithImpl;
@override @useResult
$Res call({
 String entityId, String subtype, Uint8List encryptedValue, String encryptedValueBase64
});




}
/// @nodoc
class __$ReasoningEncryptedValueEventCopyWithImpl<$Res>
    implements _$ReasoningEncryptedValueEventCopyWith<$Res> {
  __$ReasoningEncryptedValueEventCopyWithImpl(this._self, this._then);

  final _ReasoningEncryptedValueEvent _self;
  final $Res Function(_ReasoningEncryptedValueEvent) _then;

/// Create a copy of ReasoningEncryptedValueEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? entityId = null,Object? subtype = null,Object? encryptedValue = null,Object? encryptedValueBase64 = null,}) {
  return _then(_ReasoningEncryptedValueEvent(
entityId: null == entityId ? _self.entityId : entityId // ignore: cast_nullable_to_non_nullable
as String,subtype: null == subtype ? _self.subtype : subtype // ignore: cast_nullable_to_non_nullable
as String,encryptedValue: null == encryptedValue ? _self.encryptedValue : encryptedValue // ignore: cast_nullable_to_non_nullable
as Uint8List,encryptedValueBase64: null == encryptedValueBase64 ? _self.encryptedValueBase64 : encryptedValueBase64 // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc
mixin _$RawEvent {

 Map<String, dynamic> get payload; String? get source;
/// Create a copy of RawEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RawEventCopyWith<RawEvent> get copyWith => _$RawEventCopyWithImpl<RawEvent>(this as RawEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RawEvent&&const DeepCollectionEquality().equals(other.payload, payload)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(payload),source);

@override
String toString() {
  return 'RawEvent(payload: $payload, source: $source)';
}


}

/// @nodoc
abstract mixin class $RawEventCopyWith<$Res>  {
  factory $RawEventCopyWith(RawEvent value, $Res Function(RawEvent) _then) = _$RawEventCopyWithImpl;
@useResult
$Res call({
 Map<String, dynamic> payload, String? source
});




}
/// @nodoc
class _$RawEventCopyWithImpl<$Res>
    implements $RawEventCopyWith<$Res> {
  _$RawEventCopyWithImpl(this._self, this._then);

  final RawEvent _self;
  final $Res Function(RawEvent) _then;

/// Create a copy of RawEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? payload = null,Object? source = freezed,}) {
  return _then(_self.copyWith(
payload: null == payload ? _self.payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [RawEvent].
extension RawEventPatterns on RawEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RawEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RawEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RawEvent value)  $default,){
final _that = this;
switch (_that) {
case _RawEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RawEvent value)?  $default,){
final _that = this;
switch (_that) {
case _RawEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Map<String, dynamic> payload,  String? source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RawEvent() when $default != null:
return $default(_that.payload,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Map<String, dynamic> payload,  String? source)  $default,) {final _that = this;
switch (_that) {
case _RawEvent():
return $default(_that.payload,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Map<String, dynamic> payload,  String? source)?  $default,) {final _that = this;
switch (_that) {
case _RawEvent() when $default != null:
return $default(_that.payload,_that.source);case _:
  return null;

}
}

}

/// @nodoc


class _RawEvent extends RawEvent {
  const _RawEvent({required final  Map<String, dynamic> payload, this.source}): _payload = payload,super._();
  

 final  Map<String, dynamic> _payload;
@override Map<String, dynamic> get payload {
  if (_payload is EqualUnmodifiableMapView) return _payload;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_payload);
}

@override final  String? source;

/// Create a copy of RawEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RawEventCopyWith<_RawEvent> get copyWith => __$RawEventCopyWithImpl<_RawEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RawEvent&&const DeepCollectionEquality().equals(other._payload, _payload)&&(identical(other.source, source) || other.source == source));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_payload),source);

@override
String toString() {
  return 'RawEvent(payload: $payload, source: $source)';
}


}

/// @nodoc
abstract mixin class _$RawEventCopyWith<$Res> implements $RawEventCopyWith<$Res> {
  factory _$RawEventCopyWith(_RawEvent value, $Res Function(_RawEvent) _then) = __$RawEventCopyWithImpl;
@override @useResult
$Res call({
 Map<String, dynamic> payload, String? source
});




}
/// @nodoc
class __$RawEventCopyWithImpl<$Res>
    implements _$RawEventCopyWith<$Res> {
  __$RawEventCopyWithImpl(this._self, this._then);

  final _RawEvent _self;
  final $Res Function(_RawEvent) _then;

/// Create a copy of RawEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? payload = null,Object? source = freezed,}) {
  return _then(_RawEvent(
payload: null == payload ? _self._payload : payload // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,source: freezed == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$CustomEvent {

 String get name; Object? get value;
/// Create a copy of CustomEvent
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CustomEventCopyWith<CustomEvent> get copyWith => _$CustomEventCopyWithImpl<CustomEvent>(this as CustomEvent, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CustomEvent&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.value, value));
}


@override
int get hashCode => Object.hash(runtimeType,name,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'CustomEvent(name: $name, value: $value)';
}


}

/// @nodoc
abstract mixin class $CustomEventCopyWith<$Res>  {
  factory $CustomEventCopyWith(CustomEvent value, $Res Function(CustomEvent) _then) = _$CustomEventCopyWithImpl;
@useResult
$Res call({
 String name, Object? value
});




}
/// @nodoc
class _$CustomEventCopyWithImpl<$Res>
    implements $CustomEventCopyWith<$Res> {
  _$CustomEventCopyWithImpl(this._self, this._then);

  final CustomEvent _self;
  final $Res Function(CustomEvent) _then;

/// Create a copy of CustomEvent
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? value = freezed,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,
  ));
}

}


/// Adds pattern-matching-related methods to [CustomEvent].
extension CustomEventPatterns on CustomEvent {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CustomEvent value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CustomEvent() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CustomEvent value)  $default,){
final _that = this;
switch (_that) {
case _CustomEvent():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CustomEvent value)?  $default,){
final _that = this;
switch (_that) {
case _CustomEvent() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  Object? value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CustomEvent() when $default != null:
return $default(_that.name,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  Object? value)  $default,) {final _that = this;
switch (_that) {
case _CustomEvent():
return $default(_that.name,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  Object? value)?  $default,) {final _that = this;
switch (_that) {
case _CustomEvent() when $default != null:
return $default(_that.name,_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _CustomEvent extends CustomEvent {
  const _CustomEvent({required this.name, required this.value}): super._();
  

@override final  String name;
@override final  Object? value;

/// Create a copy of CustomEvent
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CustomEventCopyWith<_CustomEvent> get copyWith => __$CustomEventCopyWithImpl<_CustomEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CustomEvent&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.value, value));
}


@override
int get hashCode => Object.hash(runtimeType,name,const DeepCollectionEquality().hash(value));

@override
String toString() {
  return 'CustomEvent(name: $name, value: $value)';
}


}

/// @nodoc
abstract mixin class _$CustomEventCopyWith<$Res> implements $CustomEventCopyWith<$Res> {
  factory _$CustomEventCopyWith(_CustomEvent value, $Res Function(_CustomEvent) _then) = __$CustomEventCopyWithImpl;
@override @useResult
$Res call({
 String name, Object? value
});




}
/// @nodoc
class __$CustomEventCopyWithImpl<$Res>
    implements _$CustomEventCopyWith<$Res> {
  __$CustomEventCopyWithImpl(this._self, this._then);

  final _CustomEvent _self;
  final $Res Function(_CustomEvent) _then;

/// Create a copy of CustomEvent
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? value = freezed,}) {
  return _then(_CustomEvent(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,value: freezed == value ? _self.value : value ,
  ));
}


}

// dart format on
