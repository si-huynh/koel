// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_definition.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ToolDefinition _$ToolDefinitionFromJson(Map<String, dynamic> json) =>
    _ToolDefinition(
      name: json['name'] as String,
      description: json['description'] as String,
      parameters:
          json['parameters'] as Map<String, dynamic>? ??
          const <String, dynamic>{},
    );

Map<String, dynamic> _$ToolDefinitionToJson(_ToolDefinition instance) =>
    <String, dynamic>{
      'name': instance.name,
      'description': instance.description,
      'parameters': instance.parameters,
    };
