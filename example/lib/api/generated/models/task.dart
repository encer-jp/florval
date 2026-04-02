// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:freezed_annotation/freezed_annotation.dart';

import 'task_status.dart';
import 'task_priority.dart';
import 'user.dart';

part 'task.freezed.dart';
part 'task.g.dart';

@freezed
abstract class Task with _$Task {
  const factory Task({
    required String id,
    required String title,
    required String? description,
    required TaskStatus status,
    required TaskPriority priority,
    @JsonKey(name: 'assignee_id')
    required String? assigneeId,
    required User? assignee,
    required List<String> tags,
    @JsonKey(name: 'due_date')
    required DateTime? dueDate,
    @JsonKey(name: 'created_at')
    required DateTime createdAt,
    @JsonKey(name: 'updated_at')
    required DateTime updatedAt,
  }) = _Task;

  factory Task.fromJson(Map<String, dynamic> json) => _$TaskFromJson(json);
}
