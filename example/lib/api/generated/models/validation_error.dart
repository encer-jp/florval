import 'package:freezed_annotation/freezed_annotation.dart';

import 'validation_error_errors_item.dart';

part 'validation_error.freezed.dart';
part 'validation_error.g.dart';

@freezed
abstract class ValidationError with _$ValidationError {
  const factory ValidationError({
    required String message,
    required List<ValidationErrorErrorsItem> errors,
  }) = _ValidationError;

  factory ValidationError.fromJson(Map<String, dynamic> json) =>
      _$ValidationErrorFromJson(json);
}
