import 'package:dio/dio.dart';

import '../models/task.dart';
import '../models/unauthorized_error.dart';
import '../models/server_error.dart';
import '../models/list_tasks_status.dart';
import '../models/list_tasks_priority.dart';
import '../models/validation_error.dart';
import '../models/create_task_request.dart';
import '../models/not_found_error.dart';
import '../models/update_task_request.dart';
import '../api_responses.dart' as r;

class TasksApiClient {
  final Dio _dio;

  TasksApiClient(this._dio);

  Future<r.ListTasksResponse> listTasks({
    ListTasksStatus? status,
    ListTasksPriority? priority,
    String? assigneeId,
    String? triggerError,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/tasks',
        queryParameters: {
          if (status != null) 'status': status.jsonValue,
          if (priority != null) 'priority': priority.jsonValue,
          if (assigneeId != null) 'assignee_id': assigneeId,
          if (triggerError != null) 'trigger_error': triggerError,
        },
      );
      switch (response.statusCode) {
        case 200:
          return r.ListTasksResponse.success((response.data as List)
              .map((e) => Task.fromJson(e as Map<String, dynamic>))
              .toList());
        case 401:
          return r.ListTasksResponse.unauthorized(UnauthorizedError.fromJson(
              response.data as Map<String, dynamic>));
        case 500:
          return r.ListTasksResponse.serverError(
              ServerError.fromJson(response.data as Map<String, dynamic>));
        default:
          return r.ListTasksResponse.unknown(
              response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
          case 401:
            return r.ListTasksResponse.unauthorized(UnauthorizedError.fromJson(
                e.response!.data as Map<String, dynamic>));
          case 500:
            return r.ListTasksResponse.serverError(
                ServerError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return r.ListTasksResponse.unknown(
                e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<r.CreateTaskResponse> createTask({
    required CreateTaskRequest body,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/tasks',
        data: body.toJson(),
      );
      switch (response.statusCode) {
        case 201:
          return r.CreateTaskResponse.created(
              Task.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return r.CreateTaskResponse.unauthorized(UnauthorizedError.fromJson(
              response.data as Map<String, dynamic>));
        case 422:
          return r.CreateTaskResponse.unprocessableEntity(
              ValidationError.fromJson(response.data as Map<String, dynamic>));
        default:
          return r.CreateTaskResponse.unknown(
              response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
          case 401:
            return r.CreateTaskResponse.unauthorized(UnauthorizedError.fromJson(
                e.response!.data as Map<String, dynamic>));
          case 422:
            return r.CreateTaskResponse.unprocessableEntity(
                ValidationError.fromJson(
                    e.response!.data as Map<String, dynamic>));
          default:
            return r.CreateTaskResponse.unknown(
                e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<r.GetTaskResponse> getTask({
    required String id,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/tasks/$id',
      );
      switch (response.statusCode) {
        case 200:
          return r.GetTaskResponse.success(
              Task.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return r.GetTaskResponse.unauthorized(UnauthorizedError.fromJson(
              response.data as Map<String, dynamic>));
        case 404:
          return r.GetTaskResponse.notFound(
              NotFoundError.fromJson(response.data as Map<String, dynamic>));
        default:
          return r.GetTaskResponse.unknown(
              response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
          case 401:
            return r.GetTaskResponse.unauthorized(UnauthorizedError.fromJson(
                e.response!.data as Map<String, dynamic>));
          case 404:
            return r.GetTaskResponse.notFound(NotFoundError.fromJson(
                e.response!.data as Map<String, dynamic>));
          default:
            return r.GetTaskResponse.unknown(
                e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<r.UpdateTaskResponse> updateTask({
    required String id,
    required UpdateTaskRequest body,
  }) async {
    try {
      final response = await _dio.put<Map<String, dynamic>>(
        '/tasks/$id',
        data: body.toJson(),
      );
      switch (response.statusCode) {
        case 200:
          return r.UpdateTaskResponse.success(
              Task.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return r.UpdateTaskResponse.unauthorized(UnauthorizedError.fromJson(
              response.data as Map<String, dynamic>));
        case 404:
          return r.UpdateTaskResponse.notFound(
              NotFoundError.fromJson(response.data as Map<String, dynamic>));
        case 422:
          return r.UpdateTaskResponse.unprocessableEntity(
              ValidationError.fromJson(response.data as Map<String, dynamic>));
        default:
          return r.UpdateTaskResponse.unknown(
              response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
          case 401:
            return r.UpdateTaskResponse.unauthorized(UnauthorizedError.fromJson(
                e.response!.data as Map<String, dynamic>));
          case 404:
            return r.UpdateTaskResponse.notFound(NotFoundError.fromJson(
                e.response!.data as Map<String, dynamic>));
          case 422:
            return r.UpdateTaskResponse.unprocessableEntity(
                ValidationError.fromJson(
                    e.response!.data as Map<String, dynamic>));
          default:
            return r.UpdateTaskResponse.unknown(
                e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<r.DeleteTaskResponse> deleteTask({
    required String id,
  }) async {
    try {
      final response = await _dio.delete<Map<String, dynamic>>(
        '/tasks/$id',
      );
      switch (response.statusCode) {
        case 204:
          return r.DeleteTaskResponse.noContent();
        case 401:
          return r.DeleteTaskResponse.unauthorized(UnauthorizedError.fromJson(
              response.data as Map<String, dynamic>));
        case 404:
          return r.DeleteTaskResponse.notFound(
              NotFoundError.fromJson(response.data as Map<String, dynamic>));
        default:
          return r.DeleteTaskResponse.unknown(
              response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
          case 401:
            return r.DeleteTaskResponse.unauthorized(UnauthorizedError.fromJson(
                e.response!.data as Map<String, dynamic>));
          case 404:
            return r.DeleteTaskResponse.notFound(NotFoundError.fromJson(
                e.response!.data as Map<String, dynamic>));
          default:
            return r.DeleteTaskResponse.unknown(
                e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }
}
