// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Message _$MessageFromJson(Map<String, dynamic> json) => _Message(
  id: json['id'] as String,
  role: $enumDecode(_$MessageRoleEnumMap, json['role']),
  content: _contentFromWire(json['content']),
  timestamp: _timestampFromWire(json['timestamp']),
  toolCallId: json['toolCallId'] as String?,
  name: json['name'] as String?,
);

Map<String, dynamic> _$MessageToJson(_Message instance) => <String, dynamic>{
  'id': instance.id,
  'role': _$MessageRoleEnumMap[instance.role]!,
  'content': instance.content,
  'timestamp': ?_timestampToWire(instance.timestamp),
  'toolCallId': instance.toolCallId,
  'name': instance.name,
};

const _$MessageRoleEnumMap = {
  MessageRole.user: 'user',
  MessageRole.assistant: 'assistant',
  MessageRole.system: 'system',
  MessageRole.tool: 'tool',
};
