import 'package:json_annotation/json_annotation.dart';

enum ListTasksStatus {
  @JsonValue('todo')
  todo,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('done')
  done;

  String get jsonValue => switch (this) {
        ListTasksStatus.todo => 'todo',
        ListTasksStatus.inProgress => 'in_progress',
        ListTasksStatus.done => 'done',
      };

  static ListTasksStatus fromJsonValue(String value) =>
      values.firstWhere((e) => e.jsonValue == value);
}
