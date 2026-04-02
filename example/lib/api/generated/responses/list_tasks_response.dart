// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import '../models/task.dart' as m;
import '../models/unauthorized_error.dart' as m;
import '../models/server_error.dart' as m;

sealed class ListTasksResponse {
  const ListTasksResponse();

  const factory ListTasksResponse.success(List<m.Task> data) = ListTasksResponseSuccess;
  const factory ListTasksResponse.unauthorized(m.UnauthorizedError data) = ListTasksResponseUnauthorized;
  const factory ListTasksResponse.serverError(m.ServerError data) = ListTasksResponseServerError;
  const factory ListTasksResponse.unknown(int statusCode, dynamic body) = ListTasksResponseUnknown;
}

class ListTasksResponseSuccess extends ListTasksResponse {
  final List<m.Task> data;
  const ListTasksResponseSuccess(this.data);
}

class ListTasksResponseUnauthorized extends ListTasksResponse {
  final m.UnauthorizedError data;
  const ListTasksResponseUnauthorized(this.data);
}

class ListTasksResponseServerError extends ListTasksResponse {
  final m.ServerError data;
  const ListTasksResponseServerError(this.data);
}

class ListTasksResponseUnknown extends ListTasksResponse {
  final int statusCode;
  final dynamic body;
  const ListTasksResponseUnknown(this.statusCode, this.body);
}
