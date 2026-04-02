// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:freezed_annotation/freezed_annotation.dart';

part 'validation_error.freezed.dart';
part 'validation_error.g.dart';

@freezed
abstract class ValidationError with _$ValidationError {
  const factory ValidationError({
    required String message,
    required List<Map<String, dynamic>> errors,
  }) = _ValidationError;

  factory ValidationError.fromJson(Map<String, dynamic> json) => _$ValidationErrorFromJson(json);
}
