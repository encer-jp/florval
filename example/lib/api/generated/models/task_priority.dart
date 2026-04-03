import 'package:json_annotation/json_annotation.dart';

enum TaskPriority {
  @JsonValue('low')
  low,
  @JsonValue('medium')
  medium,
  @JsonValue('high')
  high,
  @JsonValue('urgent')
  urgent;

  String get jsonValue => switch (this) {
        TaskPriority.low => 'low',
        TaskPriority.medium => 'medium',
        TaskPriority.high => 'high',
        TaskPriority.urgent => 'urgent',
      };

  static TaskPriority fromJsonValue(String value) =>
      values.firstWhere((e) => e.jsonValue == value);
}
