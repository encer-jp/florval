import 'package:freezed_annotation/freezed_annotation.dart';

import 'update_task_request_status.dart';
import 'update_task_request_priority.dart';
import '../core/json_optional.dart';

part 'update_task_request.freezed.dart';

@Freezed(fromJson: false, toJson: false)
abstract class UpdateTaskRequest with _$UpdateTaskRequest {
  const UpdateTaskRequest._();

  const factory UpdateTaskRequest({
    required String title,
    @Default(JsonOptional<String>.absent()) JsonOptional<String> description,
    required UpdateTaskRequestStatus status,
    required UpdateTaskRequestPriority priority,
    @JsonKey(name: 'assignee_id')
    @Default(JsonOptional<String>.absent()) JsonOptional<String> assigneeId,
    @JsonKey(name: 'due_date')
    @Default(JsonOptional<DateTime>.absent()) JsonOptional<DateTime> dueDate,
    @Default(JsonOptional<List<String>>.absent()) JsonOptional<List<String>> tags,
  }) = _UpdateTaskRequest;

  factory UpdateTaskRequest.fromJson(Map<String, dynamic> json) {
    return UpdateTaskRequest(
      title: json['title'] as String,
      description: json.containsKey('description')
          ? JsonOptional.value(json['description'] as String?)
          : const JsonOptional<String>.absent(),
      status: UpdateTaskRequestStatus.fromJsonValue(json['status'] as String),
      priority: UpdateTaskRequestPriority.fromJsonValue(json['priority'] as String),
      assigneeId: json.containsKey('assignee_id')
          ? JsonOptional.value(json['assignee_id'] as String?)
          : const JsonOptional<String>.absent(),
      dueDate: json.containsKey('due_date')
          ? JsonOptional.value(json['due_date'] != null ? DateTime.parse(json['due_date'] as String) : null)
          : const JsonOptional<DateTime>.absent(),
      tags: json.containsKey('tags')
          ? JsonOptional.value((json['tags'] as List<dynamic>?)?.map((e) => e as String).toList())
          : const JsonOptional<List<String>>.absent(),
    );
  }

  Map<String, dynamic> toJson() {
    final json = <String, dynamic>{};
    json['title'] = title;
    if (description is JsonOptionalValue<String>) {
      json['description'] = (description as JsonOptionalValue<String>).value;
    }
    json['status'] = status.jsonValue;
    json['priority'] = priority.jsonValue;
    if (assigneeId is JsonOptionalValue<String>) {
      json['assignee_id'] = (assigneeId as JsonOptionalValue<String>).value;
    }
    if (dueDate is JsonOptionalValue<DateTime>) {
      json['due_date'] = (dueDate as JsonOptionalValue<DateTime>).value?.toIso8601String();
    }
    if (tags is JsonOptionalValue<List<String>>) {
      json['tags'] = (tags as JsonOptionalValue<List<String>>).value;
    }
    return json;
  }
}
