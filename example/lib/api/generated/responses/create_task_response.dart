import '../models/task.dart' as _m;
import '../models/unauthorized_error.dart' as _m;
import '../models/validation_error.dart' as _m;

sealed class CreateTaskResponse {
  const CreateTaskResponse();

  const factory CreateTaskResponse.created(_m.Task data) = CreateTaskResponseCreated;
  const factory CreateTaskResponse.unauthorized(_m.UnauthorizedError data) = CreateTaskResponseUnauthorized;
  const factory CreateTaskResponse.unprocessableEntity(_m.ValidationError data) = CreateTaskResponseUnprocessableEntity;
  const factory CreateTaskResponse.unknown(int statusCode, dynamic body) = CreateTaskResponseUnknown;
}

class CreateTaskResponseCreated extends CreateTaskResponse {
  final _m.Task data;
  const CreateTaskResponseCreated(this.data);
}

class CreateTaskResponseUnauthorized extends CreateTaskResponse {
  final _m.UnauthorizedError data;
  const CreateTaskResponseUnauthorized(this.data);
}

class CreateTaskResponseUnprocessableEntity extends CreateTaskResponse {
  final _m.ValidationError data;
  const CreateTaskResponseUnprocessableEntity(this.data);
}

class CreateTaskResponseUnknown extends CreateTaskResponse {
  final int statusCode;
  final dynamic body;
  const CreateTaskResponseUnknown(this.statusCode, this.body);
}
