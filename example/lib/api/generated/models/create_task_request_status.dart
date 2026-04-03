import 'package:json_annotation/json_annotation.dart';

enum CreateTaskRequestStatus {
  @JsonValue('todo')
  todo,
  @JsonValue('in_progress')
  inProgress,
  @JsonValue('done')
  done;

  String get jsonValue => switch (this) {
        CreateTaskRequestStatus.todo => 'todo',
        CreateTaskRequestStatus.inProgress => 'in_progress',
        CreateTaskRequestStatus.done => 'done',
      };

  static CreateTaskRequestStatus fromJsonValue(String value) =>
      values.firstWhere((e) => e.jsonValue == value);
}
