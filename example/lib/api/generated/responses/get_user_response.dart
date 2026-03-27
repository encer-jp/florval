import '../models/user.dart' as _m;
import '../models/unauthorized_error.dart' as _m;
import '../models/not_found_error.dart' as _m;

sealed class GetUserResponse {
  const GetUserResponse();

  const factory GetUserResponse.success(_m.User data) = GetUserResponseSuccess;
  const factory GetUserResponse.unauthorized(_m.UnauthorizedError data) = GetUserResponseUnauthorized;
  const factory GetUserResponse.notFound(_m.NotFoundError data) = GetUserResponseNotFound;
  const factory GetUserResponse.unknown(int statusCode, dynamic body) = GetUserResponseUnknown;
}

class GetUserResponseSuccess extends GetUserResponse {
  final _m.User data;
  const GetUserResponseSuccess(this.data);
}

class GetUserResponseUnauthorized extends GetUserResponse {
  final _m.UnauthorizedError data;
  const GetUserResponseUnauthorized(this.data);
}

class GetUserResponseNotFound extends GetUserResponse {
  final _m.NotFoundError data;
  const GetUserResponseNotFound(this.data);
}

class GetUserResponseUnknown extends GetUserResponse {
  final int statusCode;
  final dynamic body;
  const GetUserResponseUnknown(this.statusCode, this.body);
}
