import '../models/task.dart' as m;
import '../models/unauthorized_error.dart' as m;
import '../models/validation_error.dart' as m;

sealed class CreateTaskResponse {
  const CreateTaskResponse();

  const factory CreateTaskResponse.created(m.Task data) =
      CreateTaskResponseCreated;
  const factory CreateTaskResponse.unauthorized(m.UnauthorizedError data) =
      CreateTaskResponseUnauthorized;
  const factory CreateTaskResponse.unprocessableEntity(m.ValidationError data) =
      CreateTaskResponseUnprocessableEntity;
  const factory CreateTaskResponse.unknown(int statusCode, dynamic body) =
      CreateTaskResponseUnknown;
}

class CreateTaskResponseCreated extends CreateTaskResponse {
  final m.Task data;
  const CreateTaskResponseCreated(this.data);
}

class CreateTaskResponseUnauthorized extends CreateTaskResponse {
  final m.UnauthorizedError data;
  const CreateTaskResponseUnauthorized(this.data);
}

class CreateTaskResponseUnprocessableEntity extends CreateTaskResponse {
  final m.ValidationError data;
  const CreateTaskResponseUnprocessableEntity(this.data);
}

class CreateTaskResponseUnknown extends CreateTaskResponse {
  final int statusCode;
  final dynamic body;
  const CreateTaskResponseUnknown(this.statusCode, this.body);
}
