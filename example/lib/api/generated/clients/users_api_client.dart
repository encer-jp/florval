// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:dio/dio.dart';

import '../models/paginated_users.dart';
import '../models/unauthorized_error.dart';
import '../models/user.dart';
import '../models/not_found_error.dart';
import '../api_responses.dart' as r;

class UsersApiClient {
  final Dio _dio;

  UsersApiClient(this._dio);

  Future<r.ListUsersResponse> listUsers({
    int? page,
    int? limit,
    String? search,
  }) async {
    try {
      final response = await _dio.get('/users',
        queryParameters: {
          if (page != null) 'page': page,
          if (limit != null) 'limit': limit,
          if (search != null) 'search': search,
        },
      );
      switch (response.statusCode) {
        case 200:
          return r.ListUsersResponse.success(PaginatedUsers.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return r.ListUsersResponse.unauthorized(UnauthorizedError.fromJson(response.data as Map<String, dynamic>));
        default:
          return r.ListUsersResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 401:
          return r.ListUsersResponse.unauthorized(UnauthorizedError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return r.ListUsersResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<r.GetUserResponse> getUser({
    required String id,
  }) async {
    try {
      final response = await _dio.get('/users/$id',
      );
      switch (response.statusCode) {
        case 200:
          return r.GetUserResponse.success(User.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return r.GetUserResponse.unauthorized(UnauthorizedError.fromJson(response.data as Map<String, dynamic>));
        case 404:
          return r.GetUserResponse.notFound(NotFoundError.fromJson(response.data as Map<String, dynamic>));
        default:
          return r.GetUserResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 401:
          return r.GetUserResponse.unauthorized(UnauthorizedError.fromJson(e.response!.data as Map<String, dynamic>));
        case 404:
          return r.GetUserResponse.notFound(NotFoundError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return r.GetUserResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }
}
