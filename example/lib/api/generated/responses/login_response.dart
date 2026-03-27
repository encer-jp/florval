import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/login_response.dart' as _m;
import '../models/unauthorized_error.dart' as _m;

part 'login_response.freezed.dart';

@freezed
sealed class LoginResponse with _$LoginResponse {
  const factory LoginResponse.success(_m.LoginResponse data) = LoginResponseSuccess;
  const factory LoginResponse.unauthorized(_m.UnauthorizedError data) = LoginResponseUnauthorized;
  const factory LoginResponse.unknown(int statusCode, dynamic body) = LoginResponseUnknown;
}
