// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import '../models/unauthorized_error.dart' as m;
import '../models/not_found_error.dart' as m;

sealed class DeleteTaskResponse {
  const DeleteTaskResponse();

  const factory DeleteTaskResponse.noContent() = DeleteTaskResponseNoContent;
  const factory DeleteTaskResponse.unauthorized(m.UnauthorizedError data) = DeleteTaskResponseUnauthorized;
  const factory DeleteTaskResponse.notFound(m.NotFoundError data) = DeleteTaskResponseNotFound;
  const factory DeleteTaskResponse.unknown(int statusCode, dynamic body) = DeleteTaskResponseUnknown;
}

class DeleteTaskResponseNoContent extends DeleteTaskResponse {
  const DeleteTaskResponseNoContent();
}

class DeleteTaskResponseUnauthorized extends DeleteTaskResponse {
  final m.UnauthorizedError data;
  const DeleteTaskResponseUnauthorized(this.data);
}

class DeleteTaskResponseNotFound extends DeleteTaskResponse {
  final m.NotFoundError data;
  const DeleteTaskResponseNotFound(this.data);
}

class DeleteTaskResponseUnknown extends DeleteTaskResponse {
  final int statusCode;
  final dynamic body;
  const DeleteTaskResponseUnknown(this.statusCode, this.body);
}
