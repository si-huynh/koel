// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'trace_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TraceEntry {

 DateTime get timestamp; TracePhase get phase; Duration get runDuration; AgUiEvent? get event;
/// Create a copy of TraceEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TraceEntryCopyWith<TraceEntry> get copyWith => _$TraceEntryCopyWithImpl<TraceEntry>(this as TraceEntry, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TraceEntry&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.runDuration, runDuration) || other.runDuration == runDuration)&&(identical(other.event, event) || other.event == event));
}


@override
int get hashCode => Object.hash(runtimeType,timestamp,phase,runDuration,event);

@override
String toString() {
  return 'TraceEntry(timestamp: $timestamp, phase: $phase, runDuration: $runDuration, event: $event)';
}


}

/// @nodoc
abstract mixin class $TraceEntryCopyWith<$Res>  {
  factory $TraceEntryCopyWith(TraceEntry value, $Res Function(TraceEntry) _then) = _$TraceEntryCopyWithImpl;
@useResult
$Res call({
 DateTime timestamp, TracePhase phase, Duration runDuration, AgUiEvent? event
});




}
/// @nodoc
class _$TraceEntryCopyWithImpl<$Res>
    implements $TraceEntryCopyWith<$Res> {
  _$TraceEntryCopyWithImpl(this._self, this._then);

  final TraceEntry _self;
  final $Res Function(TraceEntry) _then;

/// Create a copy of TraceEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? timestamp = null,Object? phase = null,Object? runDuration = null,Object? event = freezed,}) {
  return _then(_self.copyWith(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as TracePhase,runDuration: null == runDuration ? _self.runDuration : runDuration // ignore: cast_nullable_to_non_nullable
as Duration,event: freezed == event ? _self.event : event // ignore: cast_nullable_to_non_nullable
as AgUiEvent?,
  ));
}

}


/// Adds pattern-matching-related methods to [TraceEntry].
extension TraceEntryPatterns on TraceEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TraceEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TraceEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TraceEntry value)  $default,){
final _that = this;
switch (_that) {
case _TraceEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TraceEntry value)?  $default,){
final _that = this;
switch (_that) {
case _TraceEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime timestamp,  TracePhase phase,  Duration runDuration,  AgUiEvent? event)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TraceEntry() when $default != null:
return $default(_that.timestamp,_that.phase,_that.runDuration,_that.event);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime timestamp,  TracePhase phase,  Duration runDuration,  AgUiEvent? event)  $default,) {final _that = this;
switch (_that) {
case _TraceEntry():
return $default(_that.timestamp,_that.phase,_that.runDuration,_that.event);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime timestamp,  TracePhase phase,  Duration runDuration,  AgUiEvent? event)?  $default,) {final _that = this;
switch (_that) {
case _TraceEntry() when $default != null:
return $default(_that.timestamp,_that.phase,_that.runDuration,_that.event);case _:
  return null;

}
}

}

/// @nodoc


class _TraceEntry implements TraceEntry {
  const _TraceEntry({required this.timestamp, required this.phase, required this.runDuration, this.event});
  

@override final  DateTime timestamp;
@override final  TracePhase phase;
@override final  Duration runDuration;
@override final  AgUiEvent? event;

/// Create a copy of TraceEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TraceEntryCopyWith<_TraceEntry> get copyWith => __$TraceEntryCopyWithImpl<_TraceEntry>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TraceEntry&&(identical(other.timestamp, timestamp) || other.timestamp == timestamp)&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.runDuration, runDuration) || other.runDuration == runDuration)&&(identical(other.event, event) || other.event == event));
}


@override
int get hashCode => Object.hash(runtimeType,timestamp,phase,runDuration,event);

@override
String toString() {
  return 'TraceEntry(timestamp: $timestamp, phase: $phase, runDuration: $runDuration, event: $event)';
}


}

/// @nodoc
abstract mixin class _$TraceEntryCopyWith<$Res> implements $TraceEntryCopyWith<$Res> {
  factory _$TraceEntryCopyWith(_TraceEntry value, $Res Function(_TraceEntry) _then) = __$TraceEntryCopyWithImpl;
@override @useResult
$Res call({
 DateTime timestamp, TracePhase phase, Duration runDuration, AgUiEvent? event
});




}
/// @nodoc
class __$TraceEntryCopyWithImpl<$Res>
    implements _$TraceEntryCopyWith<$Res> {
  __$TraceEntryCopyWithImpl(this._self, this._then);

  final _TraceEntry _self;
  final $Res Function(_TraceEntry) _then;

/// Create a copy of TraceEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? timestamp = null,Object? phase = null,Object? runDuration = null,Object? event = freezed,}) {
  return _then(_TraceEntry(
timestamp: null == timestamp ? _self.timestamp : timestamp // ignore: cast_nullable_to_non_nullable
as DateTime,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as TracePhase,runDuration: null == runDuration ? _self.runDuration : runDuration // ignore: cast_nullable_to_non_nullable
as Duration,event: freezed == event ? _self.event : event // ignore: cast_nullable_to_non_nullable
as AgUiEvent?,
  ));
}


}

// dart format on
