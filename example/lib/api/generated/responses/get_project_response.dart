import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/project.dart' as _m;
import '../models/unauthorized_error.dart' as _m;
import '../models/not_found_error.dart' as _m;

part 'get_project_response.freezed.dart';

@freezed
sealed class GetProjectResponse with _$GetProjectResponse {
  const factory GetProjectResponse.success(_m.Project data) = GetProjectResponseSuccess;
  const factory GetProjectResponse.unauthorized(_m.UnauthorizedError data) = GetProjectResponseUnauthorized;
  const factory GetProjectResponse.notFound(_m.NotFoundError data) = GetProjectResponseNotFound;
  const factory GetProjectResponse.unknown(int statusCode, dynamic body) = GetProjectResponseUnknown;
}
