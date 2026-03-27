import '../models/paginated_users.dart' as _m;
import '../models/unauthorized_error.dart' as _m;

sealed class ListUsersResponse {
  const ListUsersResponse();

  const factory ListUsersResponse.success(_m.PaginatedUsers data) = ListUsersResponseSuccess;
  const factory ListUsersResponse.unauthorized(_m.UnauthorizedError data) = ListUsersResponseUnauthorized;
  const factory ListUsersResponse.unknown(int statusCode, dynamic body) = ListUsersResponseUnknown;
}

class ListUsersResponseSuccess extends ListUsersResponse {
  final _m.PaginatedUsers data;
  const ListUsersResponseSuccess(this.data);
}

class ListUsersResponseUnauthorized extends ListUsersResponse {
  final _m.UnauthorizedError data;
  const ListUsersResponseUnauthorized(this.data);
}

class ListUsersResponseUnknown extends ListUsersResponse {
  final int statusCode;
  final dynamic body;
  const ListUsersResponseUnknown(this.statusCode, this.body);
}
