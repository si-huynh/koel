// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'conformance_report.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ConformanceFailure {

 String get eventType; AgUiEvent get expected; AgUiEvent? get actual; KoelError? get error;
/// Create a copy of ConformanceFailure
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConformanceFailureCopyWith<ConformanceFailure> get copyWith => _$ConformanceFailureCopyWithImpl<ConformanceFailure>(this as ConformanceFailure, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConformanceFailure&&(identical(other.eventType, eventType) || other.eventType == eventType)&&(identical(other.expected, expected) || other.expected == expected)&&(identical(other.actual, actual) || other.actual == actual)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,eventType,expected,actual,error);

@override
String toString() {
  return 'ConformanceFailure(eventType: $eventType, expected: $expected, actual: $actual, error: $error)';
}


}

/// @nodoc
abstract mixin class $ConformanceFailureCopyWith<$Res>  {
  factory $ConformanceFailureCopyWith(ConformanceFailure value, $Res Function(ConformanceFailure) _then) = _$ConformanceFailureCopyWithImpl;
@useResult
$Res call({
 String eventType, AgUiEvent expected, AgUiEvent? actual, KoelError? error
});




}
/// @nodoc
class _$ConformanceFailureCopyWithImpl<$Res>
    implements $ConformanceFailureCopyWith<$Res> {
  _$ConformanceFailureCopyWithImpl(this._self, this._then);

  final ConformanceFailure _self;
  final $Res Function(ConformanceFailure) _then;

/// Create a copy of ConformanceFailure
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? eventType = null,Object? expected = null,Object? actual = freezed,Object? error = freezed,}) {
  return _then(_self.copyWith(
eventType: null == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as String,expected: null == expected ? _self.expected : expected // ignore: cast_nullable_to_non_nullable
as AgUiEvent,actual: freezed == actual ? _self.actual : actual // ignore: cast_nullable_to_non_nullable
as AgUiEvent?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as KoelError?,
  ));
}

}


/// Adds pattern-matching-related methods to [ConformanceFailure].
extension ConformanceFailurePatterns on ConformanceFailure {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConformanceFailure value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConformanceFailure() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConformanceFailure value)  $default,){
final _that = this;
switch (_that) {
case _ConformanceFailure():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConformanceFailure value)?  $default,){
final _that = this;
switch (_that) {
case _ConformanceFailure() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String eventType,  AgUiEvent expected,  AgUiEvent? actual,  KoelError? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConformanceFailure() when $default != null:
return $default(_that.eventType,_that.expected,_that.actual,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String eventType,  AgUiEvent expected,  AgUiEvent? actual,  KoelError? error)  $default,) {final _that = this;
switch (_that) {
case _ConformanceFailure():
return $default(_that.eventType,_that.expected,_that.actual,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String eventType,  AgUiEvent expected,  AgUiEvent? actual,  KoelError? error)?  $default,) {final _that = this;
switch (_that) {
case _ConformanceFailure() when $default != null:
return $default(_that.eventType,_that.expected,_that.actual,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _ConformanceFailure implements ConformanceFailure {
  const _ConformanceFailure({required this.eventType, required this.expected, this.actual, this.error});
  

@override final  String eventType;
@override final  AgUiEvent expected;
@override final  AgUiEvent? actual;
@override final  KoelError? error;

/// Create a copy of ConformanceFailure
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConformanceFailureCopyWith<_ConformanceFailure> get copyWith => __$ConformanceFailureCopyWithImpl<_ConformanceFailure>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConformanceFailure&&(identical(other.eventType, eventType) || other.eventType == eventType)&&(identical(other.expected, expected) || other.expected == expected)&&(identical(other.actual, actual) || other.actual == actual)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,eventType,expected,actual,error);

@override
String toString() {
  return 'ConformanceFailure(eventType: $eventType, expected: $expected, actual: $actual, error: $error)';
}


}

/// @nodoc
abstract mixin class _$ConformanceFailureCopyWith<$Res> implements $ConformanceFailureCopyWith<$Res> {
  factory _$ConformanceFailureCopyWith(_ConformanceFailure value, $Res Function(_ConformanceFailure) _then) = __$ConformanceFailureCopyWithImpl;
@override @useResult
$Res call({
 String eventType, AgUiEvent expected, AgUiEvent? actual, KoelError? error
});




}
/// @nodoc
class __$ConformanceFailureCopyWithImpl<$Res>
    implements _$ConformanceFailureCopyWith<$Res> {
  __$ConformanceFailureCopyWithImpl(this._self, this._then);

  final _ConformanceFailure _self;
  final $Res Function(_ConformanceFailure) _then;

/// Create a copy of ConformanceFailure
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? eventType = null,Object? expected = null,Object? actual = freezed,Object? error = freezed,}) {
  return _then(_ConformanceFailure(
eventType: null == eventType ? _self.eventType : eventType // ignore: cast_nullable_to_non_nullable
as String,expected: null == expected ? _self.expected : expected // ignore: cast_nullable_to_non_nullable
as AgUiEvent,actual: freezed == actual ? _self.actual : actual // ignore: cast_nullable_to_non_nullable
as AgUiEvent?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as KoelError?,
  ));
}


}

/// @nodoc
mixin _$ConformanceReport {

 List<String> get passed; List<ConformanceFailure> get failed; String get agentName; Duration get runDuration;
/// Create a copy of ConformanceReport
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ConformanceReportCopyWith<ConformanceReport> get copyWith => _$ConformanceReportCopyWithImpl<ConformanceReport>(this as ConformanceReport, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ConformanceReport&&const DeepCollectionEquality().equals(other.passed, passed)&&const DeepCollectionEquality().equals(other.failed, failed)&&(identical(other.agentName, agentName) || other.agentName == agentName)&&(identical(other.runDuration, runDuration) || other.runDuration == runDuration));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(passed),const DeepCollectionEquality().hash(failed),agentName,runDuration);

@override
String toString() {
  return 'ConformanceReport(passed: $passed, failed: $failed, agentName: $agentName, runDuration: $runDuration)';
}


}

/// @nodoc
abstract mixin class $ConformanceReportCopyWith<$Res>  {
  factory $ConformanceReportCopyWith(ConformanceReport value, $Res Function(ConformanceReport) _then) = _$ConformanceReportCopyWithImpl;
@useResult
$Res call({
 List<String> passed, List<ConformanceFailure> failed, String agentName, Duration runDuration
});




}
/// @nodoc
class _$ConformanceReportCopyWithImpl<$Res>
    implements $ConformanceReportCopyWith<$Res> {
  _$ConformanceReportCopyWithImpl(this._self, this._then);

  final ConformanceReport _self;
  final $Res Function(ConformanceReport) _then;

/// Create a copy of ConformanceReport
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? passed = null,Object? failed = null,Object? agentName = null,Object? runDuration = null,}) {
  return _then(_self.copyWith(
passed: null == passed ? _self.passed : passed // ignore: cast_nullable_to_non_nullable
as List<String>,failed: null == failed ? _self.failed : failed // ignore: cast_nullable_to_non_nullable
as List<ConformanceFailure>,agentName: null == agentName ? _self.agentName : agentName // ignore: cast_nullable_to_non_nullable
as String,runDuration: null == runDuration ? _self.runDuration : runDuration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}

}


/// Adds pattern-matching-related methods to [ConformanceReport].
extension ConformanceReportPatterns on ConformanceReport {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ConformanceReport value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ConformanceReport() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ConformanceReport value)  $default,){
final _that = this;
switch (_that) {
case _ConformanceReport():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ConformanceReport value)?  $default,){
final _that = this;
switch (_that) {
case _ConformanceReport() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<String> passed,  List<ConformanceFailure> failed,  String agentName,  Duration runDuration)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ConformanceReport() when $default != null:
return $default(_that.passed,_that.failed,_that.agentName,_that.runDuration);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<String> passed,  List<ConformanceFailure> failed,  String agentName,  Duration runDuration)  $default,) {final _that = this;
switch (_that) {
case _ConformanceReport():
return $default(_that.passed,_that.failed,_that.agentName,_that.runDuration);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<String> passed,  List<ConformanceFailure> failed,  String agentName,  Duration runDuration)?  $default,) {final _that = this;
switch (_that) {
case _ConformanceReport() when $default != null:
return $default(_that.passed,_that.failed,_that.agentName,_that.runDuration);case _:
  return null;

}
}

}

/// @nodoc


class _ConformanceReport implements ConformanceReport {
  const _ConformanceReport({required final  List<String> passed, required final  List<ConformanceFailure> failed, required this.agentName, required this.runDuration}): _passed = passed,_failed = failed;
  

 final  List<String> _passed;
@override List<String> get passed {
  if (_passed is EqualUnmodifiableListView) return _passed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_passed);
}

 final  List<ConformanceFailure> _failed;
@override List<ConformanceFailure> get failed {
  if (_failed is EqualUnmodifiableListView) return _failed;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_failed);
}

@override final  String agentName;
@override final  Duration runDuration;

/// Create a copy of ConformanceReport
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ConformanceReportCopyWith<_ConformanceReport> get copyWith => __$ConformanceReportCopyWithImpl<_ConformanceReport>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ConformanceReport&&const DeepCollectionEquality().equals(other._passed, _passed)&&const DeepCollectionEquality().equals(other._failed, _failed)&&(identical(other.agentName, agentName) || other.agentName == agentName)&&(identical(other.runDuration, runDuration) || other.runDuration == runDuration));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_passed),const DeepCollectionEquality().hash(_failed),agentName,runDuration);

@override
String toString() {
  return 'ConformanceReport(passed: $passed, failed: $failed, agentName: $agentName, runDuration: $runDuration)';
}


}

/// @nodoc
abstract mixin class _$ConformanceReportCopyWith<$Res> implements $ConformanceReportCopyWith<$Res> {
  factory _$ConformanceReportCopyWith(_ConformanceReport value, $Res Function(_ConformanceReport) _then) = __$ConformanceReportCopyWithImpl;
@override @useResult
$Res call({
 List<String> passed, List<ConformanceFailure> failed, String agentName, Duration runDuration
});




}
/// @nodoc
class __$ConformanceReportCopyWithImpl<$Res>
    implements _$ConformanceReportCopyWith<$Res> {
  __$ConformanceReportCopyWithImpl(this._self, this._then);

  final _ConformanceReport _self;
  final $Res Function(_ConformanceReport) _then;

/// Create a copy of ConformanceReport
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? passed = null,Object? failed = null,Object? agentName = null,Object? runDuration = null,}) {
  return _then(_ConformanceReport(
passed: null == passed ? _self._passed : passed // ignore: cast_nullable_to_non_nullable
as List<String>,failed: null == failed ? _self._failed : failed // ignore: cast_nullable_to_non_nullable
as List<ConformanceFailure>,agentName: null == agentName ? _self.agentName : agentName // ignore: cast_nullable_to_non_nullable
as String,runDuration: null == runDuration ? _self.runDuration : runDuration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}


}

// dart format on
