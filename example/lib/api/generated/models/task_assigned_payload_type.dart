// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:json_annotation/json_annotation.dart';

enum TaskAssignedPayloadType {
  @JsonValue('task_assigned')
  taskAssigned;

  String get jsonValue => switch (this) {
    TaskAssignedPayloadType.taskAssigned => 'task_assigned',
  };

  static TaskAssignedPayloadType fromJsonValue(String value) =>
      values.firstWhere((e) => e.jsonValue == value);
}
