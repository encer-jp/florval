import '../models/login_response.dart' as m;
import '../models/unauthorized_error.dart' as m;

sealed class LoginResponse {
  const LoginResponse();

  const factory LoginResponse.success(m.LoginResponse data) = LoginResponseSuccess;
  const factory LoginResponse.unauthorized(m.UnauthorizedError data) = LoginResponseUnauthorized;
  const factory LoginResponse.unknown(int statusCode, dynamic body) = LoginResponseUnknown;
}

class LoginResponseSuccess extends LoginResponse {
  final m.LoginResponse data;
  const LoginResponseSuccess(this.data);
}

class LoginResponseUnauthorized extends LoginResponse {
  final m.UnauthorizedError data;
  const LoginResponseUnauthorized(this.data);
}

class LoginResponseUnknown extends LoginResponse {
  final int statusCode;
  final dynamic body;
  const LoginResponseUnknown(this.statusCode, this.body);
}
