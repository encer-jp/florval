import 'package:freezed_annotation/freezed_annotation.dart';

part 'validation_error_errors_item.freezed.dart';
part 'validation_error_errors_item.g.dart';

@freezed
abstract class ValidationErrorErrorsItem with _$ValidationErrorErrorsItem {
  const factory ValidationErrorErrorsItem({
    required String field,
    required String message,
  }) = _ValidationErrorErrorsItem;

  factory ValidationErrorErrorsItem.fromJson(Map<String, dynamic> json) =>
      _$ValidationErrorErrorsItemFromJson(json);
}
