import 'package:json_annotation/json_annotation.dart';

enum CommentAddedPayloadType {
  @JsonValue('comment_added')
  commentAdded;

  String get jsonValue => switch (this) {
    CommentAddedPayloadType.commentAdded => 'comment_added',
  };

  static CommentAddedPayloadType fromJsonValue(String value) =>
      values.firstWhere((e) => e.jsonValue == value);
}
