import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/task.dart' as _m;
import '../models/unauthorized_error.dart' as _m;
import '../models/server_error.dart' as _m;

part 'list_tasks_response.freezed.dart';

@freezed
sealed class ListTasksResponse with _$ListTasksResponse {
  const factory ListTasksResponse.success(List<_m.Task> data) = ListTasksResponseSuccess;
  const factory ListTasksResponse.unauthorized(_m.UnauthorizedError data) = ListTasksResponseUnauthorized;
  const factory ListTasksResponse.serverError(_m.ServerError data) = ListTasksResponseServerError;
  const factory ListTasksResponse.unknown(int statusCode, dynamic body) = ListTasksResponseUnknown;
}
