import '../models/task.dart' as m;
import '../models/unauthorized_error.dart' as m;
import '../models/not_found_error.dart' as m;
import '../models/validation_error.dart' as m;

sealed class UpdateTaskResponse {
  const UpdateTaskResponse();

  const factory UpdateTaskResponse.success(m.Task data) =
      UpdateTaskResponseSuccess;
  const factory UpdateTaskResponse.unauthorized(m.UnauthorizedError data) =
      UpdateTaskResponseUnauthorized;
  const factory UpdateTaskResponse.notFound(m.NotFoundError data) =
      UpdateTaskResponseNotFound;
  const factory UpdateTaskResponse.unprocessableEntity(m.ValidationError data) =
      UpdateTaskResponseUnprocessableEntity;
  const factory UpdateTaskResponse.unknown(int statusCode, dynamic body) =
      UpdateTaskResponseUnknown;
}

class UpdateTaskResponseSuccess extends UpdateTaskResponse {
  final m.Task data;
  const UpdateTaskResponseSuccess(this.data);
}

class UpdateTaskResponseUnauthorized extends UpdateTaskResponse {
  final m.UnauthorizedError data;
  const UpdateTaskResponseUnauthorized(this.data);
}

class UpdateTaskResponseNotFound extends UpdateTaskResponse {
  final m.NotFoundError data;
  const UpdateTaskResponseNotFound(this.data);
}

class UpdateTaskResponseUnprocessableEntity extends UpdateTaskResponse {
  final m.ValidationError data;
  const UpdateTaskResponseUnprocessableEntity(this.data);
}

class UpdateTaskResponseUnknown extends UpdateTaskResponse {
  final int statusCode;
  final dynamic body;
  const UpdateTaskResponseUnknown(this.statusCode, this.body);
}
