// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'run_agent_input.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RunAgentInput {

 String get threadId; String get runId; Map<String, dynamic> get state; List<Message> get messages; List<ToolDefinition> get tools; List<Context> get context; Map<String, dynamic> get forwardedProps; Map<String, Uint8List>? get reasoningEcho;
/// Create a copy of RunAgentInput
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RunAgentInputCopyWith<RunAgentInput> get copyWith => _$RunAgentInputCopyWithImpl<RunAgentInput>(this as RunAgentInput, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RunAgentInput&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.runId, runId) || other.runId == runId)&&const DeepCollectionEquality().equals(other.state, state)&&const DeepCollectionEquality().equals(other.messages, messages)&&const DeepCollectionEquality().equals(other.tools, tools)&&const DeepCollectionEquality().equals(other.context, context)&&const DeepCollectionEquality().equals(other.forwardedProps, forwardedProps)&&const DeepCollectionEquality().equals(other.reasoningEcho, reasoningEcho));
}


@override
int get hashCode => Object.hash(runtimeType,threadId,runId,const DeepCollectionEquality().hash(state),const DeepCollectionEquality().hash(messages),const DeepCollectionEquality().hash(tools),const DeepCollectionEquality().hash(context),const DeepCollectionEquality().hash(forwardedProps),const DeepCollectionEquality().hash(reasoningEcho));

@override
String toString() {
  return 'RunAgentInput(threadId: $threadId, runId: $runId, state: $state, messages: $messages, tools: $tools, context: $context, forwardedProps: $forwardedProps, reasoningEcho: $reasoningEcho)';
}


}

/// @nodoc
abstract mixin class $RunAgentInputCopyWith<$Res>  {
  factory $RunAgentInputCopyWith(RunAgentInput value, $Res Function(RunAgentInput) _then) = _$RunAgentInputCopyWithImpl;
@useResult
$Res call({
 String threadId, String runId, Map<String, dynamic> state, List<Message> messages, List<ToolDefinition> tools, List<Context> context, Map<String, dynamic> forwardedProps, Map<String, Uint8List>? reasoningEcho
});




}
/// @nodoc
class _$RunAgentInputCopyWithImpl<$Res>
    implements $RunAgentInputCopyWith<$Res> {
  _$RunAgentInputCopyWithImpl(this._self, this._then);

  final RunAgentInput _self;
  final $Res Function(RunAgentInput) _then;

/// Create a copy of RunAgentInput
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? threadId = null,Object? runId = null,Object? state = null,Object? messages = null,Object? tools = null,Object? context = null,Object? forwardedProps = null,Object? reasoningEcho = freezed,}) {
  return _then(_self.copyWith(
threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String,runId: null == runId ? _self.runId : runId // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<Message>,tools: null == tools ? _self.tools : tools // ignore: cast_nullable_to_non_nullable
as List<ToolDefinition>,context: null == context ? _self.context : context // ignore: cast_nullable_to_non_nullable
as List<Context>,forwardedProps: null == forwardedProps ? _self.forwardedProps : forwardedProps // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,reasoningEcho: freezed == reasoningEcho ? _self.reasoningEcho : reasoningEcho // ignore: cast_nullable_to_non_nullable
as Map<String, Uint8List>?,
  ));
}

}


/// Adds pattern-matching-related methods to [RunAgentInput].
extension RunAgentInputPatterns on RunAgentInput {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RunAgentInput value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RunAgentInput() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RunAgentInput value)  $default,){
final _that = this;
switch (_that) {
case _RunAgentInput():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RunAgentInput value)?  $default,){
final _that = this;
switch (_that) {
case _RunAgentInput() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String threadId,  String runId,  Map<String, dynamic> state,  List<Message> messages,  List<ToolDefinition> tools,  List<Context> context,  Map<String, dynamic> forwardedProps,  Map<String, Uint8List>? reasoningEcho)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RunAgentInput() when $default != null:
return $default(_that.threadId,_that.runId,_that.state,_that.messages,_that.tools,_that.context,_that.forwardedProps,_that.reasoningEcho);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String threadId,  String runId,  Map<String, dynamic> state,  List<Message> messages,  List<ToolDefinition> tools,  List<Context> context,  Map<String, dynamic> forwardedProps,  Map<String, Uint8List>? reasoningEcho)  $default,) {final _that = this;
switch (_that) {
case _RunAgentInput():
return $default(_that.threadId,_that.runId,_that.state,_that.messages,_that.tools,_that.context,_that.forwardedProps,_that.reasoningEcho);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String threadId,  String runId,  Map<String, dynamic> state,  List<Message> messages,  List<ToolDefinition> tools,  List<Context> context,  Map<String, dynamic> forwardedProps,  Map<String, Uint8List>? reasoningEcho)?  $default,) {final _that = this;
switch (_that) {
case _RunAgentInput() when $default != null:
return $default(_that.threadId,_that.runId,_that.state,_that.messages,_that.tools,_that.context,_that.forwardedProps,_that.reasoningEcho);case _:
  return null;

}
}

}

/// @nodoc


class _RunAgentInput implements RunAgentInput {
  const _RunAgentInput({required this.threadId, required this.runId, final  Map<String, dynamic> state = const <String, dynamic>{}, final  List<Message> messages = const <Message>[], final  List<ToolDefinition> tools = const <ToolDefinition>[], final  List<Context> context = const <Context>[], final  Map<String, dynamic> forwardedProps = const <String, dynamic>{}, final  Map<String, Uint8List>? reasoningEcho}): _state = state,_messages = messages,_tools = tools,_context = context,_forwardedProps = forwardedProps,_reasoningEcho = reasoningEcho;
  

@override final  String threadId;
@override final  String runId;
 final  Map<String, dynamic> _state;
@override@JsonKey() Map<String, dynamic> get state {
  if (_state is EqualUnmodifiableMapView) return _state;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_state);
}

 final  List<Message> _messages;
@override@JsonKey() List<Message> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

 final  List<ToolDefinition> _tools;
@override@JsonKey() List<ToolDefinition> get tools {
  if (_tools is EqualUnmodifiableListView) return _tools;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tools);
}

 final  List<Context> _context;
@override@JsonKey() List<Context> get context {
  if (_context is EqualUnmodifiableListView) return _context;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_context);
}

 final  Map<String, dynamic> _forwardedProps;
@override@JsonKey() Map<String, dynamic> get forwardedProps {
  if (_forwardedProps is EqualUnmodifiableMapView) return _forwardedProps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_forwardedProps);
}

 final  Map<String, Uint8List>? _reasoningEcho;
@override Map<String, Uint8List>? get reasoningEcho {
  final value = _reasoningEcho;
  if (value == null) return null;
  if (_reasoningEcho is EqualUnmodifiableMapView) return _reasoningEcho;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}


/// Create a copy of RunAgentInput
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RunAgentInputCopyWith<_RunAgentInput> get copyWith => __$RunAgentInputCopyWithImpl<_RunAgentInput>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RunAgentInput&&(identical(other.threadId, threadId) || other.threadId == threadId)&&(identical(other.runId, runId) || other.runId == runId)&&const DeepCollectionEquality().equals(other._state, _state)&&const DeepCollectionEquality().equals(other._messages, _messages)&&const DeepCollectionEquality().equals(other._tools, _tools)&&const DeepCollectionEquality().equals(other._context, _context)&&const DeepCollectionEquality().equals(other._forwardedProps, _forwardedProps)&&const DeepCollectionEquality().equals(other._reasoningEcho, _reasoningEcho));
}


@override
int get hashCode => Object.hash(runtimeType,threadId,runId,const DeepCollectionEquality().hash(_state),const DeepCollectionEquality().hash(_messages),const DeepCollectionEquality().hash(_tools),const DeepCollectionEquality().hash(_context),const DeepCollectionEquality().hash(_forwardedProps),const DeepCollectionEquality().hash(_reasoningEcho));

@override
String toString() {
  return 'RunAgentInput(threadId: $threadId, runId: $runId, state: $state, messages: $messages, tools: $tools, context: $context, forwardedProps: $forwardedProps, reasoningEcho: $reasoningEcho)';
}


}

/// @nodoc
abstract mixin class _$RunAgentInputCopyWith<$Res> implements $RunAgentInputCopyWith<$Res> {
  factory _$RunAgentInputCopyWith(_RunAgentInput value, $Res Function(_RunAgentInput) _then) = __$RunAgentInputCopyWithImpl;
@override @useResult
$Res call({
 String threadId, String runId, Map<String, dynamic> state, List<Message> messages, List<ToolDefinition> tools, List<Context> context, Map<String, dynamic> forwardedProps, Map<String, Uint8List>? reasoningEcho
});




}
/// @nodoc
class __$RunAgentInputCopyWithImpl<$Res>
    implements _$RunAgentInputCopyWith<$Res> {
  __$RunAgentInputCopyWithImpl(this._self, this._then);

  final _RunAgentInput _self;
  final $Res Function(_RunAgentInput) _then;

/// Create a copy of RunAgentInput
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? threadId = null,Object? runId = null,Object? state = null,Object? messages = null,Object? tools = null,Object? context = null,Object? forwardedProps = null,Object? reasoningEcho = freezed,}) {
  return _then(_RunAgentInput(
threadId: null == threadId ? _self.threadId : threadId // ignore: cast_nullable_to_non_nullable
as String,runId: null == runId ? _self.runId : runId // ignore: cast_nullable_to_non_nullable
as String,state: null == state ? _self._state : state // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<Message>,tools: null == tools ? _self._tools : tools // ignore: cast_nullable_to_non_nullable
as List<ToolDefinition>,context: null == context ? _self._context : context // ignore: cast_nullable_to_non_nullable
as List<Context>,forwardedProps: null == forwardedProps ? _self._forwardedProps : forwardedProps // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,reasoningEcho: freezed == reasoningEcho ? _self._reasoningEcho : reasoningEcho // ignore: cast_nullable_to_non_nullable
as Map<String, Uint8List>?,
  ));
}


}

// dart format on
