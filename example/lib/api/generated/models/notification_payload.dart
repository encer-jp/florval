import 'task_assigned_payload.dart';
import 'comment_added_payload.dart';
import 'project_invited_payload.dart';

sealed class NotificationPayload {
  const NotificationPayload();

  const factory NotificationPayload.taskAssignedPayload(TaskAssignedPayload data) = NotificationPayloadTaskAssignedPayload;
  const factory NotificationPayload.commentAddedPayload(CommentAddedPayload data) = NotificationPayloadCommentAddedPayload;
  const factory NotificationPayload.projectInvitedPayload(ProjectInvitedPayload data) = NotificationPayloadProjectInvitedPayload;

  factory NotificationPayload.fromJson(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'task_assigned':
        return NotificationPayload.taskAssignedPayload(TaskAssignedPayload.fromJson(json));
      case 'comment_added':
        return NotificationPayload.commentAddedPayload(CommentAddedPayload.fromJson(json));
      case 'project_invited':
        return NotificationPayload.projectInvitedPayload(ProjectInvitedPayload.fromJson(json));
      default:
        throw UnimplementedError('Unknown type: ${json["type"]}');
    }
  }

  Map<String, dynamic> toJson() => switch (this) {
    NotificationPayloadTaskAssignedPayload(:final data) => data.toJson(),
    NotificationPayloadCommentAddedPayload(:final data) => data.toJson(),
    NotificationPayloadProjectInvitedPayload(:final data) => data.toJson(),
  };
}

class NotificationPayloadTaskAssignedPayload extends NotificationPayload {
  final TaskAssignedPayload data;
  const NotificationPayloadTaskAssignedPayload(this.data);
}

class NotificationPayloadCommentAddedPayload extends NotificationPayload {
  final CommentAddedPayload data;
  const NotificationPayloadCommentAddedPayload(this.data);
}

class NotificationPayloadProjectInvitedPayload extends NotificationPayload {
  final ProjectInvitedPayload data;
  const NotificationPayloadProjectInvitedPayload(this.data);
}

