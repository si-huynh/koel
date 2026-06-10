// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_call.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ToolCall _$ToolCallFromJson(Map<String, dynamic> json) => _ToolCall(
  id: json['id'] as String,
  name: json['name'] as String,
  arguments: json['arguments'] as String? ?? '',
  parentMessageId: json['parentMessageId'] as String?,
);

Map<String, dynamic> _$ToolCallToJson(_ToolCall instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'arguments': instance.arguments,
  'parentMessageId': instance.parentMessageId,
};
