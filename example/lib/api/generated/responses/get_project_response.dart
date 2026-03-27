import '../models/project.dart' as _m;
import '../models/unauthorized_error.dart' as _m;
import '../models/not_found_error.dart' as _m;

sealed class GetProjectResponse {
  const GetProjectResponse();

  const factory GetProjectResponse.success(_m.Project data) = GetProjectResponseSuccess;
  const factory GetProjectResponse.unauthorized(_m.UnauthorizedError data) = GetProjectResponseUnauthorized;
  const factory GetProjectResponse.notFound(_m.NotFoundError data) = GetProjectResponseNotFound;
  const factory GetProjectResponse.unknown(int statusCode, dynamic body) = GetProjectResponseUnknown;
}

class GetProjectResponseSuccess extends GetProjectResponse {
  final _m.Project data;
  const GetProjectResponseSuccess(this.data);
}

class GetProjectResponseUnauthorized extends GetProjectResponse {
  final _m.UnauthorizedError data;
  const GetProjectResponseUnauthorized(this.data);
}

class GetProjectResponseNotFound extends GetProjectResponse {
  final _m.NotFoundError data;
  const GetProjectResponseNotFound(this.data);
}

class GetProjectResponseUnknown extends GetProjectResponse {
  final int statusCode;
  final dynamic body;
  const GetProjectResponseUnknown(this.statusCode, this.body);
}
