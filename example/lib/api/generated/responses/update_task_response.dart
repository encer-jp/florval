import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/task.dart' as _m;
import '../models/unauthorized_error.dart' as _m;
import '../models/not_found_error.dart' as _m;
import '../models/validation_error.dart' as _m;

part 'update_task_response.freezed.dart';

@freezed
sealed class UpdateTaskResponse with _$UpdateTaskResponse {
  const factory UpdateTaskResponse.success(_m.Task data) = UpdateTaskResponseSuccess;
  const factory UpdateTaskResponse.unauthorized(_m.UnauthorizedError data) = UpdateTaskResponseUnauthorized;
  const factory UpdateTaskResponse.notFound(_m.NotFoundError data) = UpdateTaskResponseNotFound;
  const factory UpdateTaskResponse.unprocessableEntity(_m.ValidationError data) = UpdateTaskResponseUnprocessableEntity;
  const factory UpdateTaskResponse.unknown(int statusCode, dynamic body) = UpdateTaskResponseUnknown;
}
