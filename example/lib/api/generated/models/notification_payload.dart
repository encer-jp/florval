import 'package:freezed_annotation/freezed_annotation.dart';

part 'notification_payload.freezed.dart';
part 'notification_payload.g.dart';

@Freezed(unionKey: 'type')
sealed class NotificationPayload with _$NotificationPayload {
  @FreezedUnionValue('task_assigned')
  const factory NotificationPayload.taskAssigned({
    @JsonKey(name: 'task_id')
    required String taskId,
    @JsonKey(name: 'task_title')
    required String taskTitle,
    @JsonKey(name: 'assigned_by')
    required String assignedBy,
  }) = NotificationPayloadTaskAssigned;
  @FreezedUnionValue('comment_added')
  const factory NotificationPayload.commentAdded({
    @JsonKey(name: 'task_id')
    required String taskId,
    @JsonKey(name: 'task_title')
    required String taskTitle,
    @JsonKey(name: 'comment_text')
    required String commentText,
    @JsonKey(name: 'commented_by')
    required String commentedBy,
  }) = NotificationPayloadCommentAdded;
  @FreezedUnionValue('project_invited')
  const factory NotificationPayload.projectInvited({
    @JsonKey(name: 'project_id')
    required String projectId,
    @JsonKey(name: 'project_name')
    required String projectName,
    @JsonKey(name: 'invited_by')
    required String invitedBy,
  }) = NotificationPayloadProjectInvited;

  factory NotificationPayload.fromJson(Map<String, dynamic> json) => _$NotificationPayloadFromJson(json);
}
