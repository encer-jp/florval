// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:freezed_annotation/freezed_annotation.dart';

part 'create_project_request.freezed.dart';
part 'create_project_request.g.dart';

@freezed
abstract class CreateProjectRequest with _$CreateProjectRequest {
  const factory CreateProjectRequest({
    required String name,
    String? description,
    @JsonKey(name: 'member_ids')
    required List<String> memberIds,
  }) = _CreateProjectRequest;

  factory CreateProjectRequest.fromJson(Map<String, dynamic> json) => _$CreateProjectRequestFromJson(json);
}
