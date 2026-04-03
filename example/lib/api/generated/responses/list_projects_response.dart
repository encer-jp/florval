import '../models/project.dart' as m;
import '../models/unauthorized_error.dart' as m;

sealed class ListProjectsResponse {
  const ListProjectsResponse();

  const factory ListProjectsResponse.success(List<m.Project> data) =
      ListProjectsResponseSuccess;
  const factory ListProjectsResponse.unauthorized(m.UnauthorizedError data) =
      ListProjectsResponseUnauthorized;
  const factory ListProjectsResponse.unknown(int statusCode, dynamic body) =
      ListProjectsResponseUnknown;
}

class ListProjectsResponseSuccess extends ListProjectsResponse {
  final List<m.Project> data;
  const ListProjectsResponseSuccess(this.data);
}

class ListProjectsResponseUnauthorized extends ListProjectsResponse {
  final m.UnauthorizedError data;
  const ListProjectsResponseUnauthorized(this.data);
}

class ListProjectsResponseUnknown extends ListProjectsResponse {
  final int statusCode;
  final dynamic body;
  const ListProjectsResponseUnknown(this.statusCode, this.body);
}
