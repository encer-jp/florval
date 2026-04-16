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

  final authClient = AuthApiClient(dio);
  final tasksClient = TasksApiClient(dio);
  final usersClient = UsersApiClient(dio);
  final projectsClient = ProjectsApiClient(dio);
  final notificationsClient = NotificationsApiClient(dio);

  // 1. Login
  print('=== 1. POST /auth/login ===');
  final loginResp = await authClient.login(
    body: LoginRequest(email: 'demo@example.com', password: 'password'),
  );
  switch (loginResp) {
    case r.LoginResponseSuccess(:final data):
      print('OK: ${data.user.name} (token: ${data.token.substring(0, 20)}...)');
      dio.options.headers['Authorization'] = 'Bearer ${data.token}';
    default:
      print('FAIL: $loginResp');
      return;
  }

  // 2. List Tasks
  print('\n=== 2. GET /tasks ===');
  final tasksResp = await tasksClient.listTasks();
  switch (tasksResp) {
    case r.ListTasksResponseSuccess(:final data):
      print('OK: ${data.length} tasks');
    default:
      print('FAIL: $tasksResp');
  }

  // 3. Create Task
  print('\n=== 3. POST /tasks ===');
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

  // 4. 404
  print('\n=== 4. GET /tasks/{id} (404) ===');
  final notFoundResp = await tasksClient.getTask(
    id: '00000000-0000-0000-0000-000000000000',
  );
  switch (notFoundResp) {
    case r.GetTaskResponseNotFound(:final data):
      print('OK (expected): ${data.message}');
    default:
      print('UNEXPECTED: $notFoundResp');
  }

  // 5. 500
  print('\n=== 5. GET /tasks?trigger_error=true ===');
  final errorResp = await tasksClient.listTasks(triggerError: 'true');
  switch (errorResp) {
    case r.ListTasksResponseServerError(:final data):
      print('OK (expected): ${data.message} [${data.code}]');
    default:
      print('UNEXPECTED: $errorResp');
  }

  // 6. Pagination
  print('\n=== 6. GET /users?page=1&limit=3 ===');
  final usersResp = await usersClient.listUsers(page: 1, limit: 3);
  switch (usersResp) {
    case r.ListUsersResponseSuccess(:final data):
      print(
          'OK: ${data.data.length}/${data.total} users (page ${data.page}/${data.totalPages})');
    default:
      print('FAIL: $usersResp');
  }

  // 7. Projects (nested)
  print('\n=== 7. GET /projects ===');
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

  // 8. Notifications (oneOf + discriminator)
  print('\n=== 8. GET /notifications ===');
  final notifResp = await notificationsClient.listNotifications();
  switch (notifResp) {
    case r.ListNotificationsResponseSuccess(:final data):
      final types = data.map((n) => n.type).toSet();
      print('OK: ${data.length} notifications, types: $types');
    default:
      print('FAIL: $notifResp');
  }

  // 9. Delete
  if (taskId != null) {
    print('\n=== 9. DELETE /tasks/$taskId ===');
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
