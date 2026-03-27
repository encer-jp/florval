import '../models/project.dart' as _m;
import '../models/unauthorized_error.dart' as _m;
import '../models/validation_error.dart' as _m;

sealed class CreateProjectResponse {
  const CreateProjectResponse();

  const factory CreateProjectResponse.created(_m.Project data) = CreateProjectResponseCreated;
  const factory CreateProjectResponse.unauthorized(_m.UnauthorizedError data) = CreateProjectResponseUnauthorized;
  const factory CreateProjectResponse.unprocessableEntity(_m.ValidationError data) = CreateProjectResponseUnprocessableEntity;
  const factory CreateProjectResponse.unknown(int statusCode, dynamic body) = CreateProjectResponseUnknown;
}

class CreateProjectResponseCreated extends CreateProjectResponse {
  final _m.Project data;
  const CreateProjectResponseCreated(this.data);
}

class CreateProjectResponseUnauthorized extends CreateProjectResponse {
  final _m.UnauthorizedError data;
  const CreateProjectResponseUnauthorized(this.data);
}

class CreateProjectResponseUnprocessableEntity extends CreateProjectResponse {
  final _m.ValidationError data;
  const CreateProjectResponseUnprocessableEntity(this.data);
}

class CreateProjectResponseUnknown extends CreateProjectResponse {
  final int statusCode;
  final dynamic body;
  const CreateProjectResponseUnknown(this.statusCode, this.body);
}
