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
