// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:json_annotation/json_annotation.dart';

enum CreateTaskRequestPriority {
  @JsonValue('low')
  low,
  @JsonValue('medium')
  medium,
  @JsonValue('high')
  high,
  @JsonValue('urgent')
  urgent;

  String get jsonValue => switch (this) {
    CreateTaskRequestPriority.low => 'low',
    CreateTaskRequestPriority.medium => 'medium',
    CreateTaskRequestPriority.high => 'high',
    CreateTaskRequestPriority.urgent => 'urgent',
  };

  static CreateTaskRequestPriority fromJsonValue(String value) =>
      values.firstWhere((e) => e.jsonValue == value);
}
