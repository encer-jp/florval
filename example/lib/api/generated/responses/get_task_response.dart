// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import '../models/task.dart' as m;
import '../models/unauthorized_error.dart' as m;
import '../models/not_found_error.dart' as m;

sealed class GetTaskResponse {
  const GetTaskResponse();

  const factory GetTaskResponse.success(m.Task data) = GetTaskResponseSuccess;
  const factory GetTaskResponse.unauthorized(m.UnauthorizedError data) = GetTaskResponseUnauthorized;
  const factory GetTaskResponse.notFound(m.NotFoundError data) = GetTaskResponseNotFound;
  const factory GetTaskResponse.unknown(int statusCode, dynamic body) = GetTaskResponseUnknown;
}

class GetTaskResponseSuccess extends GetTaskResponse {
  final m.Task data;
  const GetTaskResponseSuccess(this.data);
}

class GetTaskResponseUnauthorized extends GetTaskResponse {
  final m.UnauthorizedError data;
  const GetTaskResponseUnauthorized(this.data);
}

class GetTaskResponseNotFound extends GetTaskResponse {
  final m.NotFoundError data;
  const GetTaskResponseNotFound(this.data);
}

class GetTaskResponseUnknown extends GetTaskResponse {
  final int statusCode;
  final dynamic body;
  const GetTaskResponseUnknown(this.statusCode, this.body);
}
