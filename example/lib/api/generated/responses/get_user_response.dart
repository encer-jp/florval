import '../models/user.dart' as m;
import '../models/unauthorized_error.dart' as m;
import '../models/not_found_error.dart' as m;

sealed class GetUserResponse {
  const GetUserResponse();

  const factory GetUserResponse.success(m.User data) = GetUserResponseSuccess;
  const factory GetUserResponse.unauthorized(m.UnauthorizedError data) = GetUserResponseUnauthorized;
  const factory GetUserResponse.notFound(m.NotFoundError data) = GetUserResponseNotFound;
  const factory GetUserResponse.unknown(int statusCode, dynamic body) = GetUserResponseUnknown;
}

class GetUserResponseSuccess extends GetUserResponse {
  final m.User data;
  const GetUserResponseSuccess(this.data);
}

class GetUserResponseUnauthorized extends GetUserResponse {
  final m.UnauthorizedError data;
  const GetUserResponseUnauthorized(this.data);
}

class GetUserResponseNotFound extends GetUserResponse {
  final m.NotFoundError data;
  const GetUserResponseNotFound(this.data);
}

class GetUserResponseUnknown extends GetUserResponse {
  final int statusCode;
  final dynamic body;
  const GetUserResponseUnknown(this.statusCode, this.body);
}
