// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:json_annotation/json_annotation.dart';

enum NotificationType {
  @JsonValue('task_assigned')
  taskAssigned,
  @JsonValue('comment_added')
  commentAdded,
  @JsonValue('project_invited')
  projectInvited;

  String get jsonValue => switch (this) {
    NotificationType.taskAssigned => 'task_assigned',
    NotificationType.commentAdded => 'comment_added',
    NotificationType.projectInvited => 'project_invited',
  };

  static NotificationType fromJsonValue(String value) =>
      values.firstWhere((e) => e.jsonValue == value);
}
