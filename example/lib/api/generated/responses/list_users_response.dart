import '../models/cursor_paginated_users.dart' as m;

sealed class ListUsersResponse {
  const ListUsersResponse();

  const factory ListUsersResponse.success(m.CursorPaginatedUsers data) = ListUsersResponseSuccess;
  const factory ListUsersResponse.unknown(int statusCode, dynamic body) = ListUsersResponseUnknown;
}

class ListUsersResponseSuccess extends ListUsersResponse {
  final m.CursorPaginatedUsers data;
  const ListUsersResponseSuccess(this.data);
}

class ListUsersResponseUnknown extends ListUsersResponse {
  final int statusCode;
  final dynamic body;
  const ListUsersResponseUnknown(this.statusCode, this.body);
}
