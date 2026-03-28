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
