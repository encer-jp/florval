import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_task_request.freezed.dart';
part 'create_task_request.g.dart';

@freezed
abstract class CreateTaskRequest with _$CreateTaskRequest {
  const factory CreateTaskRequest({
    required String title,
    String? description,
    String? status,
    String? priority,
    @JsonKey(name: 'assignee_id')
    String? assigneeId,
    @JsonKey(name: 'due_date')
    DateTime? dueDate,
    List<String>? tags,
  }) = _CreateTaskRequest;

  factory CreateTaskRequest.fromJson(Map<String, dynamic> json) => _$CreateTaskRequestFromJson(json);
}
