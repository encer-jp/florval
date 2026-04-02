// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:json_annotation/json_annotation.dart';

enum ProjectInvitedPayloadType {
  @JsonValue('project_invited')
  projectInvited;

  String get jsonValue => switch (this) {
    ProjectInvitedPayloadType.projectInvited => 'project_invited',
  };

  static ProjectInvitedPayloadType fromJsonValue(String value) =>
      values.firstWhere((e) => e.jsonValue == value);
}
