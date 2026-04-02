// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:json_annotation/json_annotation.dart';

enum UpdateTaskRequestPriority {
  @JsonValue('low')
  low,
  @JsonValue('medium')
  medium,
  @JsonValue('high')
  high,
  @JsonValue('urgent')
  urgent;

  String get jsonValue => switch (this) {
    UpdateTaskRequestPriority.low => 'low',
    UpdateTaskRequestPriority.medium => 'medium',
    UpdateTaskRequestPriority.high => 'high',
    UpdateTaskRequestPriority.urgent => 'urgent',
  };

  static UpdateTaskRequestPriority fromJsonValue(String value) =>
      values.firstWhere((e) => e.jsonValue == value);
}
