import 'package:dio/dio.dart';
import 'api/generated/api.dart';
import 'api/generated/api_responses.dart' as r;

void main() async {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:3000',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  final tasksClient = TasksApiClient(dio);
  final usersClient = UsersApiClient(dio);
  final projectsClient = ProjectsApiClient(dio);
  final notificationsClient = NotificationsApiClient(dio);

  // 1. List Tasks
  print('=== 1. GET /tasks ===');
  final tasksResp = await tasksClient.listTasks();
  switch (tasksResp) {
    case r.ListTasksResponseSuccess(:final data):
      print('OK: ${data.length} tasks');
    default:
      print('FAIL: $tasksResp');
  }

  // 2. Create Task
  print('\n=== 2. POST /tasks ===');
  String? taskId;
  final createResp = await tasksClient.createTask(
    body: CreateTaskRequest(title: 'Test task', tags: ['test']),
  );
  switch (createResp) {
    case r.CreateTaskResponseCreated(:final data):
      taskId = data.id;
      print('OK: "${data.title}" (${data.id})');
    default:
      print('FAIL: $createResp');
  }

  // 3. 404
  print('\n=== 3. GET /tasks/{id} (404) ===');
  final notFoundResp = await tasksClient.getTask(
    id: '00000000-0000-0000-0000-000000000000',
  );
  switch (notFoundResp) {
    case r.GetTaskResponseNotFound(:final data):
      print('OK (expected): ${data.message}');
    default:
      print('UNEXPECTED: $notFoundResp');
  }

  // 4. 500
  print('\n=== 4. GET /tasks?simulate_status=500 ===');
  final errorResp = await tasksClient.listTasks(simulateStatus: 500);
  switch (errorResp) {
    case r.ListTasksResponseServerError(:final data):
      print('OK (expected): ${data.message} [${data.code}]');
    default:
      print('UNEXPECTED: $errorResp');
  }

  // 5. Cursor-based Pagination
  print('\n=== 5. GET /users?limit=3 (cursor-based) ===');
  final usersResp = await usersClient.listUsers(limit: 3);
  switch (usersResp) {
    case r.ListUsersResponseSuccess(:final data):
      print(
          'OK: ${data.items.length} users (hasMore: ${data.hasMore}, nextCursor: ${data.nextCursor})');
      for (final user in data.items) {
        print('  - ${user.name} (${user.role})');
      }
    default:
      print('FAIL: $usersResp');
  }

  // 6. Projects (nested)
  print('\n=== 6. GET /projects ===');
  final projResp = await projectsClient.listProjects();
  switch (projResp) {
    case r.ListProjectsResponseSuccess(:final data):
      for (final p in data) {
        print(
            '  ${p.name} (owner: ${p.owner.name}, members: ${p.members.length})');
      }
      print('OK: ${data.length} projects');
    default:
      print('FAIL: $projResp');
  }

  // 7. Notifications (oneOf + discriminator)
  print('\n=== 7. GET /notifications ===');
  final notifResp = await notificationsClient.listNotifications();
  switch (notifResp) {
    case r.ListNotificationsResponseSuccess(:final data):
      final types = data.map((n) => n.type).toSet();
      print('OK: ${data.length} notifications, types: $types');
    default:
      print('FAIL: $notifResp');
  }

  // 8. Delete
  if (taskId != null) {
    print('\n=== 8. DELETE /tasks/$taskId ===');
    final delResp = await tasksClient.deleteTask(id: taskId);
    switch (delResp) {
      case r.DeleteTaskResponseNoContent():
        print('OK: deleted');
      default:
        print('FAIL: $delResp');
    }
  }

  print('\n=== Done ===');
}
