import 'package:dio/dio.dart';

import '../models/task.dart';
import '../models/unauthorized_error.dart';
import '../models/server_error.dart';
import '../models/validation_error.dart';
import '../models/create_task_request.dart';
import '../models/not_found_error.dart';
import '../models/update_task_request.dart';
import '../api_responses.dart' as _r;

class TasksApiClient {
  final Dio _dio;

  TasksApiClient(this._dio);

  Future<_r.ListTasksResponse> listTasks({
    String? status,
    String? priority,
    String? assigneeId,
    String? triggerError,
  }) async {
    try {
      final response = await _dio.get('/tasks',
        queryParameters: {
          if (status != null) 'status': status,
          if (priority != null) 'priority': priority,
          if (assigneeId != null) 'assignee_id': assigneeId,
          if (triggerError != null) 'trigger_error': triggerError,
        },
      );
      switch (response.statusCode) {
        case 200:
          return _r.ListTasksResponse.success((response.data as List).map((e) => Task.fromJson(e as Map<String, dynamic>)).toList());
        case 401:
          return _r.ListTasksResponse.unauthorized(UnauthorizedError.fromJson(response.data as Map<String, dynamic>));
        case 500:
          return _r.ListTasksResponse.serverError(ServerError.fromJson(response.data as Map<String, dynamic>));
        default:
          return _r.ListTasksResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 401:
          return _r.ListTasksResponse.unauthorized(UnauthorizedError.fromJson(e.response!.data as Map<String, dynamic>));
        case 500:
          return _r.ListTasksResponse.serverError(ServerError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return _r.ListTasksResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<_r.CreateTaskResponse> createTask({
    required CreateTaskRequest body,
  }) async {
    try {
      final response = await _dio.post('/tasks',
        data: body.toJson(),
      );
      switch (response.statusCode) {
        case 201:
          return _r.CreateTaskResponse.created(Task.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return _r.CreateTaskResponse.unauthorized(UnauthorizedError.fromJson(response.data as Map<String, dynamic>));
        case 422:
          return _r.CreateTaskResponse.unprocessableEntity(ValidationError.fromJson(response.data as Map<String, dynamic>));
        default:
          return _r.CreateTaskResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 401:
          return _r.CreateTaskResponse.unauthorized(UnauthorizedError.fromJson(e.response!.data as Map<String, dynamic>));
        case 422:
          return _r.CreateTaskResponse.unprocessableEntity(ValidationError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return _r.CreateTaskResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<_r.GetTaskResponse> getTask({
    required String id,
  }) async {
    try {
      final response = await _dio.get('/tasks/$id',
      );
      switch (response.statusCode) {
        case 200:
          return _r.GetTaskResponse.success(Task.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return _r.GetTaskResponse.unauthorized(UnauthorizedError.fromJson(response.data as Map<String, dynamic>));
        case 404:
          return _r.GetTaskResponse.notFound(NotFoundError.fromJson(response.data as Map<String, dynamic>));
        default:
          return _r.GetTaskResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 401:
          return _r.GetTaskResponse.unauthorized(UnauthorizedError.fromJson(e.response!.data as Map<String, dynamic>));
        case 404:
          return _r.GetTaskResponse.notFound(NotFoundError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return _r.GetTaskResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<_r.UpdateTaskResponse> updateTask({
    required String id,
    required UpdateTaskRequest body,
  }) async {
    try {
      final response = await _dio.put('/tasks/$id',
        data: body.toJson(),
      );
      switch (response.statusCode) {
        case 200:
          return _r.UpdateTaskResponse.success(Task.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return _r.UpdateTaskResponse.unauthorized(UnauthorizedError.fromJson(response.data as Map<String, dynamic>));
        case 404:
          return _r.UpdateTaskResponse.notFound(NotFoundError.fromJson(response.data as Map<String, dynamic>));
        case 422:
          return _r.UpdateTaskResponse.unprocessableEntity(ValidationError.fromJson(response.data as Map<String, dynamic>));
        default:
          return _r.UpdateTaskResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 401:
          return _r.UpdateTaskResponse.unauthorized(UnauthorizedError.fromJson(e.response!.data as Map<String, dynamic>));
        case 404:
          return _r.UpdateTaskResponse.notFound(NotFoundError.fromJson(e.response!.data as Map<String, dynamic>));
        case 422:
          return _r.UpdateTaskResponse.unprocessableEntity(ValidationError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return _r.UpdateTaskResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<_r.DeleteTaskResponse> deleteTask({
    required String id,
  }) async {
    try {
      final response = await _dio.delete('/tasks/$id',
      );
      switch (response.statusCode) {
        case 204:
          return _r.DeleteTaskResponse.noContent();
        case 401:
          return _r.DeleteTaskResponse.unauthorized(UnauthorizedError.fromJson(response.data as Map<String, dynamic>));
        case 404:
          return _r.DeleteTaskResponse.notFound(NotFoundError.fromJson(response.data as Map<String, dynamic>));
        default:
          return _r.DeleteTaskResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 401:
          return _r.DeleteTaskResponse.unauthorized(UnauthorizedError.fromJson(e.response!.data as Map<String, dynamic>));
        case 404:
          return _r.DeleteTaskResponse.notFound(NotFoundError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return _r.DeleteTaskResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }
}
