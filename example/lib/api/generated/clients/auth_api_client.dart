// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:dio/dio.dart';

import '../models/login_response.dart';
import '../models/unauthorized_error.dart';
import '../models/login_request.dart';
import '../api_responses.dart' as r;

class AuthApiClient {
  final Dio _dio;

  AuthApiClient(this._dio);

  Future<r.LoginResponse> login({
    required LoginRequest body,
  }) async {
    try {
      final response = await _dio.post('/auth/login',
        data: body.toJson(),
      );
      switch (response.statusCode) {
        case 200:
          return r.LoginResponse.success(LoginResponse.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return r.LoginResponse.unauthorized(UnauthorizedError.fromJson(response.data as Map<String, dynamic>));
        default:
          return r.LoginResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 401:
          return r.LoginResponse.unauthorized(UnauthorizedError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return r.LoginResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }
}
