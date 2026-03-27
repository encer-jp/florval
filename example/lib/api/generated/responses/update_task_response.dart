import '../models/task.dart' as _m;
import '../models/unauthorized_error.dart' as _m;
import '../models/not_found_error.dart' as _m;
import '../models/validation_error.dart' as _m;

sealed class UpdateTaskResponse {
  const UpdateTaskResponse();

  const factory UpdateTaskResponse.success(_m.Task data) = UpdateTaskResponseSuccess;
  const factory UpdateTaskResponse.unauthorized(_m.UnauthorizedError data) = UpdateTaskResponseUnauthorized;
  const factory UpdateTaskResponse.notFound(_m.NotFoundError data) = UpdateTaskResponseNotFound;
  const factory UpdateTaskResponse.unprocessableEntity(_m.ValidationError data) = UpdateTaskResponseUnprocessableEntity;
  const factory UpdateTaskResponse.unknown(int statusCode, dynamic body) = UpdateTaskResponseUnknown;
}

class UpdateTaskResponseSuccess extends UpdateTaskResponse {
  final _m.Task data;
  const UpdateTaskResponseSuccess(this.data);
}

class UpdateTaskResponseUnauthorized extends UpdateTaskResponse {
  final _m.UnauthorizedError data;
  const UpdateTaskResponseUnauthorized(this.data);
}

class UpdateTaskResponseNotFound extends UpdateTaskResponse {
  final _m.NotFoundError data;
  const UpdateTaskResponseNotFound(this.data);
}

class UpdateTaskResponseUnprocessableEntity extends UpdateTaskResponse {
  final _m.ValidationError data;
  const UpdateTaskResponseUnprocessableEntity(this.data);
}

class UpdateTaskResponseUnknown extends UpdateTaskResponse {
  final int statusCode;
  final dynamic body;
  const UpdateTaskResponseUnknown(this.statusCode, this.body);
}
