import 'package:freezed_annotation/freezed_annotation.dart';

part 'task_assigned_payload.freezed.dart';
part 'task_assigned_payload.g.dart';

@freezed
abstract class TaskAssignedPayload with _$TaskAssignedPayload {
  const factory TaskAssignedPayload({
    required String type,
    @JsonKey(name: 'task_id')
    required String taskId,
    @JsonKey(name: 'task_title')
    required String taskTitle,
    @JsonKey(name: 'assigned_by')
    required String assignedBy,
  }) = _TaskAssignedPayload;

  factory TaskAssignedPayload.fromJson(Map<String, dynamic> json) => _$TaskAssignedPayloadFromJson(json);
}
