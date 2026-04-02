// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:json_annotation/json_annotation.dart';

enum UpdateTaskRequestStatus {
  @JsonValue('todo')
  todo,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('done')
  done;

  String get jsonValue => switch (this) {
    UpdateTaskRequestStatus.todo => 'todo',
    UpdateTaskRequestStatus.inProgress => 'in_progress',
    UpdateTaskRequestStatus.done => 'done',
  };

  static UpdateTaskRequestStatus fromJsonValue(String value) =>
      values.firstWhere((e) => e.jsonValue == value);
}
