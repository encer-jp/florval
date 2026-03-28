import 'package:freezed_annotation/freezed_annotation.dart';

import 'create_task_request_status.dart';
import 'create_task_request_priority.dart';

part 'create_task_request.freezed.dart';
part 'create_task_request.g.dart';

@freezed
abstract class CreateTaskRequest with _$CreateTaskRequest {
  const factory CreateTaskRequest({
    required String title,
    String? description,
    CreateTaskRequestStatus? status,
    CreateTaskRequestPriority? priority,
    @JsonKey(name: 'assignee_id')
    String? assigneeId,
    @JsonKey(name: 'due_date')
    DateTime? dueDate,
    List<String>? tags,
  }) = _CreateTaskRequest;

  factory CreateTaskRequest.fromJson(Map<String, dynamic> json) => _$CreateTaskRequestFromJson(json);
}
