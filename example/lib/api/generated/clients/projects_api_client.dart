import 'package:dio/dio.dart';

import '../models/project.dart';
import '../models/unauthorized_error.dart';
import '../models/validation_error.dart';
import '../models/create_project_request.dart';
import '../models/not_found_error.dart';
import '../api_responses.dart' as _r;

class ProjectsApiClient {
  final Dio _dio;

  ProjectsApiClient(this._dio);

  Future<_r.ListProjectsResponse> listProjects() async {
    try {
      final response = await _dio.get('/projects',
      );
      switch (response.statusCode) {
        case 200:
          return _r.ListProjectsResponse.success((response.data as List).map((e) => Project.fromJson(e as Map<String, dynamic>)).toList());
        case 401:
          return _r.ListProjectsResponse.unauthorized(UnauthorizedError.fromJson(response.data as Map<String, dynamic>));
        default:
          return _r.ListProjectsResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 401:
          return _r.ListProjectsResponse.unauthorized(UnauthorizedError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return _r.ListProjectsResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<_r.CreateProjectResponse> createProject({
    required CreateProjectRequest body,
  }) async {
    try {
      final response = await _dio.post('/projects',
        data: body.toJson(),
      );
      switch (response.statusCode) {
        case 201:
          return _r.CreateProjectResponse.created(Project.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return _r.CreateProjectResponse.unauthorized(UnauthorizedError.fromJson(response.data as Map<String, dynamic>));
        case 422:
          return _r.CreateProjectResponse.unprocessableEntity(ValidationError.fromJson(response.data as Map<String, dynamic>));
        default:
          return _r.CreateProjectResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 401:
          return _r.CreateProjectResponse.unauthorized(UnauthorizedError.fromJson(e.response!.data as Map<String, dynamic>));
        case 422:
          return _r.CreateProjectResponse.unprocessableEntity(ValidationError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return _r.CreateProjectResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<_r.GetProjectResponse> getProject({
    required String id,
  }) async {
    try {
      final response = await _dio.get('/projects/$id',
      );
      switch (response.statusCode) {
        case 200:
          return _r.GetProjectResponse.success(Project.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return _r.GetProjectResponse.unauthorized(UnauthorizedError.fromJson(response.data as Map<String, dynamic>));
        case 404:
          return _r.GetProjectResponse.notFound(NotFoundError.fromJson(response.data as Map<String, dynamic>));
        default:
          return _r.GetProjectResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 401:
          return _r.GetProjectResponse.unauthorized(UnauthorizedError.fromJson(e.response!.data as Map<String, dynamic>));
        case 404:
          return _r.GetProjectResponse.notFound(NotFoundError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return _r.GetProjectResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }
}
