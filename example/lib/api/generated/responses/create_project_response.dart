import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/project.dart' as _m;
import '../models/unauthorized_error.dart' as _m;
import '../models/validation_error.dart' as _m;

part 'create_project_response.freezed.dart';

@freezed
sealed class CreateProjectResponse with _$CreateProjectResponse {
  const factory CreateProjectResponse.created(_m.Project data) = CreateProjectResponseCreated;
  const factory CreateProjectResponse.unauthorized(_m.UnauthorizedError data) = CreateProjectResponseUnauthorized;
  const factory CreateProjectResponse.unprocessableEntity(_m.ValidationError data) = CreateProjectResponseUnprocessableEntity;
  const factory CreateProjectResponse.unknown(int statusCode, dynamic body) = CreateProjectResponseUnknown;
}
