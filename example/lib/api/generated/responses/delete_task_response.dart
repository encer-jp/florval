import '../models/unauthorized_error.dart' as _m;
import '../models/not_found_error.dart' as _m;

sealed class DeleteTaskResponse {
  const DeleteTaskResponse();

  const factory DeleteTaskResponse.noContent() = DeleteTaskResponseNoContent;
  const factory DeleteTaskResponse.unauthorized(_m.UnauthorizedError data) = DeleteTaskResponseUnauthorized;
  const factory DeleteTaskResponse.notFound(_m.NotFoundError data) = DeleteTaskResponseNotFound;
  const factory DeleteTaskResponse.unknown(int statusCode, dynamic body) = DeleteTaskResponseUnknown;
}

class DeleteTaskResponseNoContent extends DeleteTaskResponse {
  const DeleteTaskResponseNoContent();
}

class DeleteTaskResponseUnauthorized extends DeleteTaskResponse {
  final _m.UnauthorizedError data;
  const DeleteTaskResponseUnauthorized(this.data);
}

class DeleteTaskResponseNotFound extends DeleteTaskResponse {
  final _m.NotFoundError data;
  const DeleteTaskResponseNotFound(this.data);
}

class DeleteTaskResponseUnknown extends DeleteTaskResponse {
  final int statusCode;
  final dynamic body;
  const DeleteTaskResponseUnknown(this.statusCode, this.body);
}
