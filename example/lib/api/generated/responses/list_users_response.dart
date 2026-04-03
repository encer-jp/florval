import '../models/paginated_users.dart' as m;
import '../models/unauthorized_error.dart' as m;

sealed class ListUsersResponse {
  const ListUsersResponse();

  const factory ListUsersResponse.success(m.PaginatedUsers data) =
      ListUsersResponseSuccess;
  const factory ListUsersResponse.unauthorized(m.UnauthorizedError data) =
      ListUsersResponseUnauthorized;
  const factory ListUsersResponse.unknown(int statusCode, dynamic body) =
      ListUsersResponseUnknown;
}

class ListUsersResponseSuccess extends ListUsersResponse {
  final m.PaginatedUsers data;
  const ListUsersResponseSuccess(this.data);
}

class ListUsersResponseUnauthorized extends ListUsersResponse {
  final m.UnauthorizedError data;
  const ListUsersResponseUnauthorized(this.data);
}

class ListUsersResponseUnknown extends ListUsersResponse {
  final int statusCode;
  final dynamic body;
  const ListUsersResponseUnknown(this.statusCode, this.body);
}
