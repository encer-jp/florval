import 'package:json_annotation/json_annotation.dart';

enum UserRole {
  @JsonValue('admin')
  admin,
  @JsonValue('member')
  member,
  @JsonValue('viewer')
  viewer;

  String get jsonValue => switch (this) {
    UserRole.admin => 'admin',
    UserRole.member => 'member',
    UserRole.viewer => 'viewer',
  };

  static UserRole fromJsonValue(String value) =>
      values.firstWhere((e) => e.jsonValue == value);
}
