import 'package:json_annotation/json_annotation.dart';

enum ListTasksPriority {
  @JsonValue('low')
  low,
  @JsonValue('medium')
  medium,
  @JsonValue('high')
  high,
  @JsonValue('urgent')
  urgent;

  String get jsonValue => switch (this) {
        ListTasksPriority.low => 'low',
        ListTasksPriority.medium => 'medium',
        ListTasksPriority.high => 'high',
        ListTasksPriority.urgent => 'urgent',
      };

  static ListTasksPriority fromJsonValue(String value) =>
      values.firstWhere((e) => e.jsonValue == value);
}
