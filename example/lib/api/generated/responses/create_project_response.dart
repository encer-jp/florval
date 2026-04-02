// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import '../models/project.dart' as m;
import '../models/unauthorized_error.dart' as m;
import '../models/validation_error.dart' as m;

sealed class CreateProjectResponse {
  const CreateProjectResponse();

  const factory CreateProjectResponse.created(m.Project data) = CreateProjectResponseCreated;
  const factory CreateProjectResponse.unauthorized(m.UnauthorizedError data) = CreateProjectResponseUnauthorized;
  const factory CreateProjectResponse.unprocessableEntity(m.ValidationError data) = CreateProjectResponseUnprocessableEntity;
  const factory CreateProjectResponse.unknown(int statusCode, dynamic body) = CreateProjectResponseUnknown;
}

class CreateProjectResponseCreated extends CreateProjectResponse {
  final m.Project data;
  const CreateProjectResponseCreated(this.data);
}

class CreateProjectResponseUnauthorized extends CreateProjectResponse {
  final m.UnauthorizedError data;
  const CreateProjectResponseUnauthorized(this.data);
}

class CreateProjectResponseUnprocessableEntity extends CreateProjectResponse {
  final m.ValidationError data;
  const CreateProjectResponseUnprocessableEntity(this.data);
}

class CreateProjectResponseUnknown extends CreateProjectResponse {
  final int statusCode;
  final dynamic body;
  const CreateProjectResponseUnknown(this.statusCode, this.body);
}
