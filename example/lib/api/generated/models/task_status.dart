// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:json_annotation/json_annotation.dart';

enum TaskStatus {
  @JsonValue('todo')
  todo,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('done')
  done;

  String get jsonValue => switch (this) {
    TaskStatus.todo => 'todo',
    TaskStatus.inProgress => 'in_progress',
    TaskStatus.done => 'done',
  };

  static TaskStatus fromJsonValue(String value) =>
      values.firstWhere((e) => e.jsonValue == value);
}
