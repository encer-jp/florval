import 'package:dio/dio.dart';

import '../models/project.dart';
import '../models/unauthorized_error.dart';
import '../models/validation_error.dart';
import '../models/create_project_request.dart';
import '../models/not_found_error.dart';
import '../api_responses.dart' as r;

class ProjectsApiClient {
  final Dio _dio;

  ProjectsApiClient(this._dio);

  Future<r.ListProjectsResponse> listProjects() async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/projects',
      );
      switch (response.statusCode) {
        case 200:
          return r.ListProjectsResponse.success((response.data as List)
              .map((e) => Project.fromJson(e as Map<String, dynamic>))
              .toList());
        case 401:
          return r.ListProjectsResponse.unauthorized(UnauthorizedError.fromJson(
              response.data as Map<String, dynamic>));
        default:
          return r.ListProjectsResponse.unknown(
              response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
          case 401:
            return r.ListProjectsResponse.unauthorized(
                UnauthorizedError.fromJson(
                    e.response!.data as Map<String, dynamic>));
          default:
            return r.ListProjectsResponse.unknown(
                e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<r.CreateProjectResponse> createProject({
    required CreateProjectRequest body,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/projects',
        data: body.toJson(),
      );
      switch (response.statusCode) {
        case 201:
          return r.CreateProjectResponse.created(
              Project.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return r.CreateProjectResponse.unauthorized(
              UnauthorizedError.fromJson(
                  response.data as Map<String, dynamic>));
        case 422:
          return r.CreateProjectResponse.unprocessableEntity(
              ValidationError.fromJson(response.data as Map<String, dynamic>));
        default:
          return r.CreateProjectResponse.unknown(
              response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
          case 401:
            return r.CreateProjectResponse.unauthorized(
                UnauthorizedError.fromJson(
                    e.response!.data as Map<String, dynamic>));
          case 422:
            return r.CreateProjectResponse.unprocessableEntity(
                ValidationError.fromJson(
                    e.response!.data as Map<String, dynamic>));
          default:
            return r.CreateProjectResponse.unknown(
                e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<r.GetProjectResponse> getProject({
    required String id,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/projects/$id',
      );
      switch (response.statusCode) {
        case 200:
          return r.GetProjectResponse.success(
              Project.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return r.GetProjectResponse.unauthorized(UnauthorizedError.fromJson(
              response.data as Map<String, dynamic>));
        case 404:
          return r.GetProjectResponse.notFound(
              NotFoundError.fromJson(response.data as Map<String, dynamic>));
        default:
          return r.GetProjectResponse.unknown(
              response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
          case 401:
            return r.GetProjectResponse.unauthorized(UnauthorizedError.fromJson(
                e.response!.data as Map<String, dynamic>));
          case 404:
            return r.GetProjectResponse.notFound(NotFoundError.fromJson(
                e.response!.data as Map<String, dynamic>));
          default:
            return r.GetProjectResponse.unknown(
                e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }
}
