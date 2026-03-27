import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/user.dart' as _m;
import '../models/unauthorized_error.dart' as _m;
import '../models/not_found_error.dart' as _m;

part 'get_user_response.freezed.dart';

@freezed
sealed class GetUserResponse with _$GetUserResponse {
  const factory GetUserResponse.success(_m.User data) = GetUserResponseSuccess;
  const factory GetUserResponse.unauthorized(_m.UnauthorizedError data) = GetUserResponseUnauthorized;
  const factory GetUserResponse.notFound(_m.NotFoundError data) = GetUserResponseNotFound;
  const factory GetUserResponse.unknown(int statusCode, dynamic body) = GetUserResponseUnknown;
}
