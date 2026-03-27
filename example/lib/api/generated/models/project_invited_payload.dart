import 'package:freezed_annotation/freezed_annotation.dart';

part 'project_invited_payload.freezed.dart';
part 'project_invited_payload.g.dart';

@freezed
abstract class ProjectInvitedPayload with _$ProjectInvitedPayload {
  const factory ProjectInvitedPayload({
    required String type,
    @JsonKey(name: 'project_id')
    required String projectId,
    @JsonKey(name: 'project_name')
    required String projectName,
    @JsonKey(name: 'invited_by')
    required String invitedBy,
  }) = _ProjectInvitedPayload;

  factory ProjectInvitedPayload.fromJson(Map<String, dynamic> json) => _$ProjectInvitedPayloadFromJson(json);
}
