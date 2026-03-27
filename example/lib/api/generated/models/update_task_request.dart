import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_task_request.freezed.dart';
part 'update_task_request.g.dart';

@freezed
abstract class UpdateTaskRequest with _$UpdateTaskRequest {
  const factory UpdateTaskRequest({
    required String title,
    String? description,
    required String status,
    required String priority,
    @JsonKey(name: 'assignee_id')
    String? assigneeId,
    @JsonKey(name: 'due_date')
    DateTime? dueDate,
    List<String>? tags,
  }) = _UpdateTaskRequest;

  factory UpdateTaskRequest.fromJson(Map<String, dynamic> json) => _$UpdateTaskRequestFromJson(json);
}
