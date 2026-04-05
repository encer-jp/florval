import 'package:riverpod/experimental/mutation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'retry.dart';
import '../clients/tasks_api_client.dart';
import '../models/list_tasks_status.dart';
import '../models/list_tasks_priority.dart';
import '../models/create_task_request.dart';
import '../models/update_task_request.dart';
import '../api_responses.dart' as r;

part 'tasks_providers.g.dart';

@riverpod
TasksApiClient tasksApiClient(Ref ref) {
  throw UnimplementedError('Provide a Dio instance via override');
}

@Riverpod(retry: retry)
class ListTasks extends _$ListTasks {
  @override
  FutureOr<r.ListTasksResponse> build({
    ListTasksStatus? status,
    ListTasksPriority? priority,
    String? assigneeId,
    String? triggerError,
  }) {
    final client = ref.watch(tasksApiClientProvider);
    return client.listTasks(
        status: status,
        priority: priority,
        assigneeId: assigneeId,
        triggerError: triggerError);
  }
}

/// Mutation for createTask (POST /tasks)
final createTaskMutation = Mutation<r.CreateTaskResponse>();

/// Executes createTask mutation.
Future<r.CreateTaskResponse> createTask(
  MutationTarget ref, {
  required CreateTaskRequest body,
}) {
  return createTaskMutation.run(ref, (tsx) async {
    final client = tsx.get(tasksApiClientProvider);
    final result = await client.createTask(body: body);
    return result;
  });
}

@Riverpod(retry: retry)
class GetTask extends _$GetTask {
  @override
  FutureOr<r.GetTaskResponse> build({
    required String id,
  }) {
    final client = ref.watch(tasksApiClientProvider);
    return client.getTask(id: id);
  }
}

/// Mutation for updateTask (PUT /tasks/{id})
final updateTaskMutation = Mutation<r.UpdateTaskResponse>();

/// Executes updateTask mutation.
Future<r.UpdateTaskResponse> updateTask(
  MutationTarget ref, {
  required String id,
  required UpdateTaskRequest body,
}) {
  return updateTaskMutation.run(ref, (tsx) async {
    final client = tsx.get(tasksApiClientProvider);
    final result = await client.updateTask(id: id, body: body);
    return result;
  });
}

/// Mutation for deleteTask (DELETE /tasks/{id})
final deleteTaskMutation = Mutation<r.DeleteTaskResponse>();

/// Executes deleteTask mutation.
Future<r.DeleteTaskResponse> deleteTask(
  MutationTarget ref, {
  required String id,
}) {
  return deleteTaskMutation.run(ref, (tsx) async {
    final client = tsx.get(tasksApiClientProvider);
    final result = await client.deleteTask(id: id);
    return result;
  });
}
