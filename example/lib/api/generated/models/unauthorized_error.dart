// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:freezed_annotation/freezed_annotation.dart';

part 'unauthorized_error.freezed.dart';
part 'unauthorized_error.g.dart';

@freezed
abstract class UnauthorizedError with _$UnauthorizedError {
  const factory UnauthorizedError({
    required String message,
  }) = _UnauthorizedError;

  factory UnauthorizedError.fromJson(Map<String, dynamic> json) => _$UnauthorizedErrorFromJson(json);
}
