// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_state.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ChatState _$ChatStateFromJson(Map<String, dynamic> json) => _ChatState(
  messages:
      (json['messages'] as List<dynamic>?)
          ?.map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <Message>[],
  pendingMessage: json['pendingMessage'] == null
      ? null
      : Message.fromJson(json['pendingMessage'] as Map<String, dynamic>),
  pendingToolCalls:
      (json['pendingToolCalls'] as List<dynamic>?)
          ?.map((e) => ToolCall.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <ToolCall>[],
  state: json['state'] as Map<String, dynamic>? ?? const <String, dynamic>{},
  reasoningEcho: json['reasoningEcho'] == null
      ? const <String, Uint8List>{}
      : _reasoningEchoFromWire(json['reasoningEcho']),
  phase: $enumDecodeNullable(_$RunPhaseEnumMap, json['phase']) ?? RunPhase.idle,
);

Map<String, dynamic> _$ChatStateToJson(
  _ChatState instance,
) => <String, dynamic>{
  'messages': instance.messages.map((e) => e.toJson()).toList(),
  'pendingMessage': instance.pendingMessage?.toJson(),
  'pendingToolCalls': instance.pendingToolCalls.map((e) => e.toJson()).toList(),
  'state': instance.state,
  'reasoningEcho': _reasoningEchoToWire(instance.reasoningEcho),
  'phase': _$RunPhaseEnumMap[instance.phase]!,
};

const _$RunPhaseEnumMap = {
  RunPhase.idle: 'idle',
  RunPhase.running: 'running',
  RunPhase.stepRunning: 'stepRunning',
  RunPhase.error: 'error',
  RunPhase.cancelled: 'cancelled',
};
