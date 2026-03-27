import '../models/task.dart' as _m;
import '../models/unauthorized_error.dart' as _m;
import '../models/not_found_error.dart' as _m;

sealed class GetTaskResponse {
  const GetTaskResponse();

  const factory GetTaskResponse.success(_m.Task data) = GetTaskResponseSuccess;
  const factory GetTaskResponse.unauthorized(_m.UnauthorizedError data) = GetTaskResponseUnauthorized;
  const factory GetTaskResponse.notFound(_m.NotFoundError data) = GetTaskResponseNotFound;
  const factory GetTaskResponse.unknown(int statusCode, dynamic body) = GetTaskResponseUnknown;
}

class GetTaskResponseSuccess extends GetTaskResponse {
  final _m.Task data;
  const GetTaskResponseSuccess(this.data);
}

class GetTaskResponseUnauthorized extends GetTaskResponse {
  final _m.UnauthorizedError data;
  const GetTaskResponseUnauthorized(this.data);
}

class GetTaskResponseNotFound extends GetTaskResponse {
  final _m.NotFoundError data;
  const GetTaskResponseNotFound(this.data);
}

class GetTaskResponseUnknown extends GetTaskResponse {
  final int statusCode;
  final dynamic body;
  const GetTaskResponseUnknown(this.statusCode, this.body);
}
