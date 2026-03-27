import 'package:freezed_annotation/freezed_annotation.dart';

part 'bad_request_error.freezed.dart';
part 'bad_request_error.g.dart';

@freezed
abstract class BadRequestError with _$BadRequestError {
  const factory BadRequestError({
    required String message,
  }) = _BadRequestError;

  factory BadRequestError.fromJson(Map<String, dynamic> json) => _$BadRequestErrorFromJson(json);
}
