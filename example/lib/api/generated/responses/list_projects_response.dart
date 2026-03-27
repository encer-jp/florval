import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/project.dart' as _m;
import '../models/unauthorized_error.dart' as _m;

part 'list_projects_response.freezed.dart';

@freezed
sealed class ListProjectsResponse with _$ListProjectsResponse {
  const factory ListProjectsResponse.success(List<_m.Project> data) = ListProjectsResponseSuccess;
  const factory ListProjectsResponse.unauthorized(_m.UnauthorizedError data) = ListProjectsResponseUnauthorized;
  const factory ListProjectsResponse.unknown(int statusCode, dynamic body) = ListProjectsResponseUnknown;
}
