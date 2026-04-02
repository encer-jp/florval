// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:freezed_annotation/freezed_annotation.dart';

part 'server_error.freezed.dart';
part 'server_error.g.dart';

@freezed
abstract class ServerError with _$ServerError {
  const factory ServerError({
    required String message,
    required String code,
  }) = _ServerError;

  factory ServerError.fromJson(Map<String, dynamic> json) => _$ServerErrorFromJson(json);
}
