import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/task.dart' as _m;
import '../models/unauthorized_error.dart' as _m;
import '../models/validation_error.dart' as _m;

part 'create_task_response.freezed.dart';

@freezed
sealed class CreateTaskResponse with _$CreateTaskResponse {
  const factory CreateTaskResponse.created(_m.Task data) = CreateTaskResponseCreated;
  const factory CreateTaskResponse.unauthorized(_m.UnauthorizedError data) = CreateTaskResponseUnauthorized;
  const factory CreateTaskResponse.unprocessableEntity(_m.ValidationError data) = CreateTaskResponseUnprocessableEntity;
  const factory CreateTaskResponse.unknown(int statusCode, dynamic body) = CreateTaskResponseUnknown;
}
