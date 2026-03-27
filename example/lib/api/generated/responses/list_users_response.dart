import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/paginated_users.dart' as _m;
import '../models/unauthorized_error.dart' as _m;

part 'list_users_response.freezed.dart';

@freezed
sealed class ListUsersResponse with _$ListUsersResponse {
  const factory ListUsersResponse.success(_m.PaginatedUsers data) = ListUsersResponseSuccess;
  const factory ListUsersResponse.unauthorized(_m.UnauthorizedError data) = ListUsersResponseUnauthorized;
  const factory ListUsersResponse.unknown(int statusCode, dynamic body) = ListUsersResponseUnknown;
}
