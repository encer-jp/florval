// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:freezed_annotation/freezed_annotation.dart';

part 'not_found_error.freezed.dart';
part 'not_found_error.g.dart';

@freezed
abstract class NotFoundError with _$NotFoundError {
  const factory NotFoundError({
    required String message,
  }) = _NotFoundError;

  factory NotFoundError.fromJson(Map<String, dynamic> json) => _$NotFoundErrorFromJson(json);
}
