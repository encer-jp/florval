import '../models/project.dart' as m;
import '../models/unauthorized_error.dart' as m;
import '../models/not_found_error.dart' as m;

sealed class GetProjectResponse {
  const GetProjectResponse();

  const factory GetProjectResponse.success(m.Project data) =
      GetProjectResponseSuccess;
  const factory GetProjectResponse.unauthorized(m.UnauthorizedError data) =
      GetProjectResponseUnauthorized;
  const factory GetProjectResponse.notFound(m.NotFoundError data) =
      GetProjectResponseNotFound;
  const factory GetProjectResponse.unknown(int statusCode, dynamic body) =
      GetProjectResponseUnknown;
}

class GetProjectResponseSuccess extends GetProjectResponse {
  final m.Project data;
  const GetProjectResponseSuccess(this.data);
}

class GetProjectResponseUnauthorized extends GetProjectResponse {
  final m.UnauthorizedError data;
  const GetProjectResponseUnauthorized(this.data);
}

class GetProjectResponseNotFound extends GetProjectResponse {
  final m.NotFoundError data;
  const GetProjectResponseNotFound(this.data);
}

class GetProjectResponseUnknown extends GetProjectResponse {
  final int statusCode;
  final dynamic body;
  const GetProjectResponseUnknown(this.statusCode, this.body);
}
