import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api/generated/api.dart';
import 'api/generated/api_responses.dart' as r;

void main() {
  final dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:3000',
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        authApiClientProvider.overrideWithValue(AuthApiClient(dio)),
        tasksApiClientProvider.overrideWithValue(TasksApiClient(dio)),
        usersApiClientProvider.overrideWithValue(UsersApiClient(dio)),
        projectsApiClientProvider.overrideWithValue(ProjectsApiClient(dio)),
        notificationsApiClientProvider
            .overrideWithValue(NotificationsApiClient(dio)),
        uploadsApiClientProvider.overrideWithValue(UploadsApiClient(dio)),
      ],
      child: DemoApp(dio: dio),
    ),
  );
}

class DemoApp extends StatelessWidget {
  final Dio dio;
  const DemoApp({super.key, required this.dio});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Florval Demo API Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
      ),
      home: DemoHomePage(dio: dio),
    );
  }
}

class DemoHomePage extends ConsumerStatefulWidget {
  final Dio dio;
  const DemoHomePage({super.key, required this.dio});

  @override
  ConsumerState<DemoHomePage> createState() => _DemoHomePageState();
}

class _DemoHomePageState extends ConsumerState<DemoHomePage> {
  final _logBuffer = <String>[];
  bool _isRunning = false;

  void _log(String message) {
    setState(() {
      _logBuffer.add(message);
    });
  }

  Future<void> _runVerification() async {
    setState(() {
      _logBuffer.clear();
      _isRunning = true;
    });

    final authClient = ref.read(authApiClientProvider);
    final tasksClient = ref.read(tasksApiClientProvider);
    final usersClient = ref.read(usersApiClientProvider);
    final projectsClient = ref.read(projectsApiClientProvider);
    final notificationsClient = ref.read(notificationsApiClientProvider);

    // --- Test 1: Login ---
    _log('=== Test 1: POST /auth/login ===');
    try {
      final loginResp = await authClient.login(
        body: LoginRequest(email: 'demo@example.com', password: 'password'),
      );
      switch (loginResp) {
        case r.LoginResponseSuccess(:final data):
          final token = data.token;
          _log('SUCCESS: Logged in as ${data.user.name}');
          _log('  Token: ${token.substring(0, 20)}...');
          // Set auth header on the shared Dio instance
          widget.dio.options.headers['Authorization'] = 'Bearer $token';
        case r.LoginResponseUnauthorized(:final data):
          _log('UNAUTHORIZED: ${data.message}');
          _log('Cannot continue without token');
          setState(() => _isRunning = false);
          return;
        case r.LoginResponseUnknown(:final statusCode, :final body):
          _log('UNKNOWN: status=$statusCode body=$body');
          setState(() => _isRunning = false);
          return;
      }
    } catch (e) {
      _log('ERROR: $e');
      setState(() => _isRunning = false);
      return;
    }

    // --- Test 2: List Tasks ---
    _log('');
    _log('=== Test 2: GET /tasks ===');
    try {
      final tasksResp = await tasksClient.listTasks();
      switch (tasksResp) {
        case r.ListTasksResponseSuccess(:final data):
          _log('SUCCESS: Found ${data.length} tasks');
          if (data.isNotEmpty) {
            final first = data.first;
            _log('  First: "${first.title}" [${first.status}/${first.priority}]');
          }
        case r.ListTasksResponseUnauthorized(:final data):
          _log('UNAUTHORIZED: ${data.message}');
        case r.ListTasksResponseServerError(:final data):
          _log('SERVER ERROR: ${data.message}');
        case r.ListTasksResponseUnknown(:final statusCode, :final body):
          _log('UNKNOWN: status=$statusCode body=$body');
      }
    } catch (e) {
      _log('ERROR: $e');
    }

    // --- Test 3: Create Task ---
    _log('');
    _log('=== Test 3: POST /tasks ===');
    String? createdTaskId;
    try {
      final createResp = await tasksClient.createTask(
        body: CreateTaskRequest(
          title: 'Florval verification task',
          description: 'Created by main.dart verification',
          tags: ['test', 'florval'],
        ),
      );
      switch (createResp) {
        case r.CreateTaskResponseCreated(:final data):
          createdTaskId = data.id;
          _log('SUCCESS: Created task "${data.title}" (id: ${data.id})');
        case r.CreateTaskResponseUnauthorized(:final data):
          _log('UNAUTHORIZED: ${data.message}');
        case r.CreateTaskResponseUnprocessableEntity(:final data):
          _log('VALIDATION ERROR: ${data.message}');
        case r.CreateTaskResponseUnknown(:final statusCode, :final body):
          _log('UNKNOWN: status=$statusCode body=$body');
      }
    } catch (e) {
      _log('ERROR: $e');
    }

    // --- Test 4: Get Task (404) ---
    _log('');
    _log('=== Test 4: GET /tasks/{id} (non-existent) ===');
    try {
      final notFoundResp = await tasksClient.getTask(
        id: '00000000-0000-0000-0000-000000000000',
      );
      switch (notFoundResp) {
        case r.GetTaskResponseSuccess(:final data):
          _log('SUCCESS (unexpected): ${data.title}');
        case r.GetTaskResponseUnauthorized():
          _log('UNAUTHORIZED');
        case r.GetTaskResponseNotFound(:final data):
          _log('NOT FOUND (expected): ${data.message}');
        case r.GetTaskResponseUnknown(:final statusCode, :final body):
          _log('UNKNOWN: status=$statusCode body=$body');
      }
    } catch (e) {
      _log('ERROR: $e');
    }

    // --- Test 5: Server Error ---
    _log('');
    _log('=== Test 5: GET /tasks?trigger_error=true ===');
    try {
      final errorResp = await tasksClient.listTasks(triggerError: 'true');
      switch (errorResp) {
        case r.ListTasksResponseServerError(:final data):
          _log('SERVER ERROR (expected): ${data.message} [${data.code}]');
        case r.ListTasksResponseSuccess(:final data):
          _log('SUCCESS (unexpected): ${data.length} tasks');
        default:
          _log('OTHER: $errorResp');
      }
    } catch (e) {
      _log('ERROR: $e');
    }

    // --- Test 6: Users with Pagination ---
    _log('');
    _log('=== Test 6: GET /users?page=1&limit=5 ===');
    try {
      final usersResp = await usersClient.listUsers(page: 1, limit: 5);
      switch (usersResp) {
        case r.ListUsersResponseSuccess(:final data):
          _log('SUCCESS: ${data.data.length} users (total: ${data.total}, pages: ${data.totalPages})');
          for (final user in data.data) {
            _log('  - ${user.name} (${user.role})');
          }
        case r.ListUsersResponseUnauthorized(:final data):
          _log('UNAUTHORIZED: ${data.message}');
        case r.ListUsersResponseUnknown(:final statusCode, :final body):
          _log('UNKNOWN: status=$statusCode body=$body');
      }
    } catch (e) {
      _log('ERROR: $e');
    }

    // --- Test 7: Projects (nested objects) ---
    _log('');
    _log('=== Test 7: GET /projects ===');
    try {
      final projectsResp = await projectsClient.listProjects();
      switch (projectsResp) {
        case r.ListProjectsResponseSuccess(:final data):
          _log('SUCCESS: ${data.length} projects');
          for (final project in data) {
            _log('  - ${project.name} (owner: ${project.owner.name}, members: ${project.members.length})');
          }
        case r.ListProjectsResponseUnauthorized(:final data):
          _log('UNAUTHORIZED: ${data.message}');
        case r.ListProjectsResponseUnknown(:final statusCode, :final body):
          _log('UNKNOWN: status=$statusCode body=$body');
      }
    } catch (e) {
      _log('ERROR: $e');
    }

    // --- Test 8: Notifications (oneOf + discriminator) ---
    _log('');
    _log('=== Test 8: GET /notifications (oneOf + discriminator) ===');
    try {
      final notifResp = await notificationsClient.listNotifications();
      switch (notifResp) {
        case r.ListNotificationsResponseSuccess(:final data):
          _log('SUCCESS: ${data.length} notifications');
          for (final n in data.take(3)) {
            _log('  - [${n.type}] read=${n.isRead}');
          }
        case r.ListNotificationsResponseUnauthorized(:final data):
          _log('UNAUTHORIZED: ${data.message}');
        case r.ListNotificationsResponseUnknown(:final statusCode, :final body):
          _log('UNKNOWN: status=$statusCode body=$body');
      }
    } catch (e) {
      _log('ERROR: $e');
    }

    // --- Test 9: Delete created task ---
    if (createdTaskId != null) {
      _log('');
      _log('=== Test 9: DELETE /tasks/$createdTaskId ===');
      try {
        final deleteResp = await tasksClient.deleteTask(id: createdTaskId);
        switch (deleteResp) {
          case r.DeleteTaskResponseNoContent():
            _log('SUCCESS: Deleted task $createdTaskId');
          case r.DeleteTaskResponseUnauthorized(:final data):
            _log('UNAUTHORIZED: ${data.message}');
          case r.DeleteTaskResponseNotFound(:final data):
            _log('NOT FOUND: ${data.message}');
          case r.DeleteTaskResponseUnknown(:final statusCode, :final body):
            _log('UNKNOWN: status=$statusCode body=$body');
        }
      } catch (e) {
        _log('ERROR: $e');
      }
    }

    _log('');
    _log('=== Verification Complete ===');

    setState(() {
      _isRunning = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Florval Demo API Verification'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connects to demo-api at http://localhost:3000',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _isRunning ? null : _runVerification,
              child: Text(_isRunning ? 'Running...' : 'Run Verification'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _logBuffer.isEmpty
                        ? 'Press "Run Verification" to start...\n\n'
                            'Make sure demo-api is running:\n'
                            '  cd demo-api && npm run dev'
                        : _logBuffer.join('\n'),
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 13,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
