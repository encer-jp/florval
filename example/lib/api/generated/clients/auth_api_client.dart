import 'package:dio/dio.dart';

import '../models/login_response.dart';
import '../models/unauthorized_error.dart';
import '../models/login_request.dart';
import '../api_responses.dart' as _r;

class AuthApiClient {
  final Dio _dio;

  AuthApiClient(this._dio);

  Future<_r.LoginResponse> login({
    required LoginRequest body,
  }) async {
    try {
      final response = await _dio.post('/auth/login',
        data: body.toJson(),
      );
      switch (response.statusCode) {
        case 200:
          return _r.LoginResponse.success(LoginResponse.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return _r.LoginResponse.unauthorized(UnauthorizedError.fromJson(response.data as Map<String, dynamic>));
        default:
          return _r.LoginResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 401:
          return _r.LoginResponse.unauthorized(UnauthorizedError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return _r.LoginResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }
}
