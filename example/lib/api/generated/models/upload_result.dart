// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:freezed_annotation/freezed_annotation.dart';

part 'upload_result.freezed.dart';
part 'upload_result.g.dart';

@freezed
abstract class UploadResult with _$UploadResult {
  const factory UploadResult({
    required String id,
    required String filename,
    required int size,
    @JsonKey(name: 'content_type')
    required String contentType,
    required String url,
    @JsonKey(name: 'uploaded_at')
    required DateTime uploadedAt,
  }) = _UploadResult;

  factory UploadResult.fromJson(Map<String, dynamic> json) => _$UploadResultFromJson(json);
}
