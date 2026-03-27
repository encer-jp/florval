import '../models/login_response.dart' as _m;
import '../models/unauthorized_error.dart' as _m;

sealed class LoginResponse {
  const LoginResponse();

  const factory LoginResponse.success(_m.LoginResponse data) = LoginResponseSuccess;
  const factory LoginResponse.unauthorized(_m.UnauthorizedError data) = LoginResponseUnauthorized;
  const factory LoginResponse.unknown(int statusCode, dynamic body) = LoginResponseUnknown;
}

class LoginResponseSuccess extends LoginResponse {
  final _m.LoginResponse data;
  const LoginResponseSuccess(this.data);
}

class LoginResponseUnauthorized extends LoginResponse {
  final _m.UnauthorizedError data;
  const LoginResponseUnauthorized(this.data);
}

class LoginResponseUnknown extends LoginResponse {
  final int statusCode;
  final dynamic body;
  const LoginResponseUnknown(this.statusCode, this.body);
}
