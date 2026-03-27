import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/task.dart' as _m;
import '../models/unauthorized_error.dart' as _m;
import '../models/not_found_error.dart' as _m;

part 'get_task_response.freezed.dart';

@freezed
sealed class GetTaskResponse with _$GetTaskResponse {
  const factory GetTaskResponse.success(_m.Task data) = GetTaskResponseSuccess;
  const factory GetTaskResponse.unauthorized(_m.UnauthorizedError data) = GetTaskResponseUnauthorized;
  const factory GetTaskResponse.notFound(_m.NotFoundError data) = GetTaskResponseNotFound;
  const factory GetTaskResponse.unknown(int statusCode, dynamic body) = GetTaskResponseUnknown;
}
