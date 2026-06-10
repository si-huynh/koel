// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ChatState {

 List<Message> get messages; Message? get pendingMessage; List<ToolCall> get pendingToolCalls; Map<String, dynamic> get state;@JsonKey(toJson: _reasoningEchoToWire, fromJson: _reasoningEchoFromWire) Map<String, Uint8List> get reasoningEcho;/// The last folded failure. **Not persisted**: [KoelError] is intentionally
/// codec-less (its [KoelError.cause] is often non-serializable), and a
/// failed run's error is stale across an app restart — FR-D1 restores the
/// conversation, not a live error banner. Excluded from the JSON codec, so a
/// state reloaded from persistence always has `error == null` (even one
/// persisted while [phase] was [RunPhase.error]).
@JsonKey(includeToJson: false, includeFromJson: false) KoelError? get error; RunPhase get phase;
/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatStateCopyWith<ChatState> get copyWith => _$ChatStateCopyWithImpl<ChatState>(this as ChatState, _$identity);

  /// Serializes this ChatState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatState&&const DeepCollectionEquality().equals(other.messages, messages)&&(identical(other.pendingMessage, pendingMessage) || other.pendingMessage == pendingMessage)&&const DeepCollectionEquality().equals(other.pendingToolCalls, pendingToolCalls)&&const DeepCollectionEquality().equals(other.state, state)&&const DeepCollectionEquality().equals(other.reasoningEcho, reasoningEcho)&&(identical(other.error, error) || other.error == error)&&(identical(other.phase, phase) || other.phase == phase));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(messages),pendingMessage,const DeepCollectionEquality().hash(pendingToolCalls),const DeepCollectionEquality().hash(state),const DeepCollectionEquality().hash(reasoningEcho),error,phase);

@override
String toString() {
  return 'ChatState(messages: $messages, pendingMessage: $pendingMessage, pendingToolCalls: $pendingToolCalls, state: $state, reasoningEcho: $reasoningEcho, error: $error, phase: $phase)';
}


}

/// @nodoc
abstract mixin class $ChatStateCopyWith<$Res>  {
  factory $ChatStateCopyWith(ChatState value, $Res Function(ChatState) _then) = _$ChatStateCopyWithImpl;
@useResult
$Res call({
 List<Message> messages, Message? pendingMessage, List<ToolCall> pendingToolCalls, Map<String, dynamic> state,@JsonKey(toJson: _reasoningEchoToWire, fromJson: _reasoningEchoFromWire) Map<String, Uint8List> reasoningEcho,@JsonKey(includeToJson: false, includeFromJson: false) KoelError? error, RunPhase phase
});


$MessageCopyWith<$Res>? get pendingMessage;

}
/// @nodoc
class _$ChatStateCopyWithImpl<$Res>
    implements $ChatStateCopyWith<$Res> {
  _$ChatStateCopyWithImpl(this._self, this._then);

  final ChatState _self;
  final $Res Function(ChatState) _then;

/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messages = null,Object? pendingMessage = freezed,Object? pendingToolCalls = null,Object? state = null,Object? reasoningEcho = null,Object? error = freezed,Object? phase = null,}) {
  return _then(_self.copyWith(
messages: null == messages ? _self.messages : messages // ignore: cast_nullable_to_non_nullable
as List<Message>,pendingMessage: freezed == pendingMessage ? _self.pendingMessage : pendingMessage // ignore: cast_nullable_to_non_nullable
as Message?,pendingToolCalls: null == pendingToolCalls ? _self.pendingToolCalls : pendingToolCalls // ignore: cast_nullable_to_non_nullable
as List<ToolCall>,state: null == state ? _self.state : state // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,reasoningEcho: null == reasoningEcho ? _self.reasoningEcho : reasoningEcho // ignore: cast_nullable_to_non_nullable
as Map<String, Uint8List>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as KoelError?,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as RunPhase,
  ));
}
/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageCopyWith<$Res>? get pendingMessage {
    if (_self.pendingMessage == null) {
    return null;
  }

  return $MessageCopyWith<$Res>(_self.pendingMessage!, (value) {
    return _then(_self.copyWith(pendingMessage: value));
  });
}
}


/// Adds pattern-matching-related methods to [ChatState].
extension ChatStatePatterns on ChatState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ChatState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ChatState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ChatState value)  $default,){
final _that = this;
switch (_that) {
case _ChatState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ChatState value)?  $default,){
final _that = this;
switch (_that) {
case _ChatState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Message> messages,  Message? pendingMessage,  List<ToolCall> pendingToolCalls,  Map<String, dynamic> state, @JsonKey(toJson: _reasoningEchoToWire, fromJson: _reasoningEchoFromWire)  Map<String, Uint8List> reasoningEcho, @JsonKey(includeToJson: false, includeFromJson: false)  KoelError? error,  RunPhase phase)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ChatState() when $default != null:
return $default(_that.messages,_that.pendingMessage,_that.pendingToolCalls,_that.state,_that.reasoningEcho,_that.error,_that.phase);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Message> messages,  Message? pendingMessage,  List<ToolCall> pendingToolCalls,  Map<String, dynamic> state, @JsonKey(toJson: _reasoningEchoToWire, fromJson: _reasoningEchoFromWire)  Map<String, Uint8List> reasoningEcho, @JsonKey(includeToJson: false, includeFromJson: false)  KoelError? error,  RunPhase phase)  $default,) {final _that = this;
switch (_that) {
case _ChatState():
return $default(_that.messages,_that.pendingMessage,_that.pendingToolCalls,_that.state,_that.reasoningEcho,_that.error,_that.phase);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Message> messages,  Message? pendingMessage,  List<ToolCall> pendingToolCalls,  Map<String, dynamic> state, @JsonKey(toJson: _reasoningEchoToWire, fromJson: _reasoningEchoFromWire)  Map<String, Uint8List> reasoningEcho, @JsonKey(includeToJson: false, includeFromJson: false)  KoelError? error,  RunPhase phase)?  $default,) {final _that = this;
switch (_that) {
case _ChatState() when $default != null:
return $default(_that.messages,_that.pendingMessage,_that.pendingToolCalls,_that.state,_that.reasoningEcho,_that.error,_that.phase);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ChatState implements ChatState {
  const _ChatState({final  List<Message> messages = const <Message>[], this.pendingMessage, final  List<ToolCall> pendingToolCalls = const <ToolCall>[], final  Map<String, dynamic> state = const <String, dynamic>{}, @JsonKey(toJson: _reasoningEchoToWire, fromJson: _reasoningEchoFromWire) final  Map<String, Uint8List> reasoningEcho = const <String, Uint8List>{}, @JsonKey(includeToJson: false, includeFromJson: false) this.error, this.phase = RunPhase.idle}): _messages = messages,_pendingToolCalls = pendingToolCalls,_state = state,_reasoningEcho = reasoningEcho;
  factory _ChatState.fromJson(Map<String, dynamic> json) => _$ChatStateFromJson(json);

 final  List<Message> _messages;
@override@JsonKey() List<Message> get messages {
  if (_messages is EqualUnmodifiableListView) return _messages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_messages);
}

@override final  Message? pendingMessage;
 final  List<ToolCall> _pendingToolCalls;
@override@JsonKey() List<ToolCall> get pendingToolCalls {
  if (_pendingToolCalls is EqualUnmodifiableListView) return _pendingToolCalls;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_pendingToolCalls);
}

 final  Map<String, dynamic> _state;
@override@JsonKey() Map<String, dynamic> get state {
  if (_state is EqualUnmodifiableMapView) return _state;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_state);
}

 final  Map<String, Uint8List> _reasoningEcho;
@override@JsonKey(toJson: _reasoningEchoToWire, fromJson: _reasoningEchoFromWire) Map<String, Uint8List> get reasoningEcho {
  if (_reasoningEcho is EqualUnmodifiableMapView) return _reasoningEcho;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_reasoningEcho);
}

/// The last folded failure. **Not persisted**: [KoelError] is intentionally
/// codec-less (its [KoelError.cause] is often non-serializable), and a
/// failed run's error is stale across an app restart — FR-D1 restores the
/// conversation, not a live error banner. Excluded from the JSON codec, so a
/// state reloaded from persistence always has `error == null` (even one
/// persisted while [phase] was [RunPhase.error]).
@override@JsonKey(includeToJson: false, includeFromJson: false) final  KoelError? error;
@override@JsonKey() final  RunPhase phase;

/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ChatStateCopyWith<_ChatState> get copyWith => __$ChatStateCopyWithImpl<_ChatState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ChatStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ChatState&&const DeepCollectionEquality().equals(other._messages, _messages)&&(identical(other.pendingMessage, pendingMessage) || other.pendingMessage == pendingMessage)&&const DeepCollectionEquality().equals(other._pendingToolCalls, _pendingToolCalls)&&const DeepCollectionEquality().equals(other._state, _state)&&const DeepCollectionEquality().equals(other._reasoningEcho, _reasoningEcho)&&(identical(other.error, error) || other.error == error)&&(identical(other.phase, phase) || other.phase == phase));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_messages),pendingMessage,const DeepCollectionEquality().hash(_pendingToolCalls),const DeepCollectionEquality().hash(_state),const DeepCollectionEquality().hash(_reasoningEcho),error,phase);

@override
String toString() {
  return 'ChatState(messages: $messages, pendingMessage: $pendingMessage, pendingToolCalls: $pendingToolCalls, state: $state, reasoningEcho: $reasoningEcho, error: $error, phase: $phase)';
}


}

/// @nodoc
abstract mixin class _$ChatStateCopyWith<$Res> implements $ChatStateCopyWith<$Res> {
  factory _$ChatStateCopyWith(_ChatState value, $Res Function(_ChatState) _then) = __$ChatStateCopyWithImpl;
@override @useResult
$Res call({
 List<Message> messages, Message? pendingMessage, List<ToolCall> pendingToolCalls, Map<String, dynamic> state,@JsonKey(toJson: _reasoningEchoToWire, fromJson: _reasoningEchoFromWire) Map<String, Uint8List> reasoningEcho,@JsonKey(includeToJson: false, includeFromJson: false) KoelError? error, RunPhase phase
});


@override $MessageCopyWith<$Res>? get pendingMessage;

}
/// @nodoc
class __$ChatStateCopyWithImpl<$Res>
    implements _$ChatStateCopyWith<$Res> {
  __$ChatStateCopyWithImpl(this._self, this._then);

  final _ChatState _self;
  final $Res Function(_ChatState) _then;

/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messages = null,Object? pendingMessage = freezed,Object? pendingToolCalls = null,Object? state = null,Object? reasoningEcho = null,Object? error = freezed,Object? phase = null,}) {
  return _then(_ChatState(
messages: null == messages ? _self._messages : messages // ignore: cast_nullable_to_non_nullable
as List<Message>,pendingMessage: freezed == pendingMessage ? _self.pendingMessage : pendingMessage // ignore: cast_nullable_to_non_nullable
as Message?,pendingToolCalls: null == pendingToolCalls ? _self._pendingToolCalls : pendingToolCalls // ignore: cast_nullable_to_non_nullable
as List<ToolCall>,state: null == state ? _self._state : state // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,reasoningEcho: null == reasoningEcho ? _self._reasoningEcho : reasoningEcho // ignore: cast_nullable_to_non_nullable
as Map<String, Uint8List>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as KoelError?,phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as RunPhase,
  ));
}

/// Create a copy of ChatState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MessageCopyWith<$Res>? get pendingMessage {
    if (_self.pendingMessage == null) {
    return null;
  }

  return $MessageCopyWith<$Res>(_self.pendingMessage!, (value) {
    return _then(_self.copyWith(pendingMessage: value));
  });
}
}

// dart format on
