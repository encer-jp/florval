import 'package:freezed_annotation/freezed_annotation.dart';

part 'comment_added_payload.freezed.dart';
part 'comment_added_payload.g.dart';

@freezed
abstract class CommentAddedPayload with _$CommentAddedPayload {
  const factory CommentAddedPayload({
    required String type,
    @JsonKey(name: 'task_id')
    required String taskId,
    @JsonKey(name: 'task_title')
    required String taskTitle,
    @JsonKey(name: 'comment_text')
    required String commentText,
    @JsonKey(name: 'commented_by')
    required String commentedBy,
  }) = _CommentAddedPayload;

  factory CommentAddedPayload.fromJson(Map<String, dynamic> json) => _$CommentAddedPayloadFromJson(json);
}
