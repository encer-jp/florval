import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/experimental/mutation.dart';

import '../api/generated/api.dart';
import '../api/generated/api_responses.dart' as r;

class MutationTab extends ConsumerStatefulWidget {
  final Dio dio;
  const MutationTab({super.key, required this.dio});

  @override
  ConsumerState<MutationTab> createState() => _MutationTabState();
}

class _MutationTabState extends ConsumerState<MutationTab> {
  bool _loggedIn = false;
  bool _loggingIn = false;
  String? _loginError;
  final _titleController = TextEditingController();
  DateTime? _lastRefreshed;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _doLogin() async {
    setState(() {
      _loggingIn = true;
      _loginError = null;
    });

    final authClient = ref.read(authApiClientProvider);
    final response = await authClient.login(
      body: LoginRequest(email: 'demo@example.com', password: 'password'),
    );
    switch (response) {
      case r.LoginResponseSuccess(:final data):
        widget.dio.options.headers['Authorization'] = 'Bearer ${data.token}';
        setState(() {
          _loggedIn = true;
          _loggingIn = false;
        });
      case r.LoginResponseUnauthorized(:final data):
        setState(() {
          _loginError = data.message;
          _loggingIn = false;
        });
      case r.LoginResponseUnknown(:final statusCode, :final body):
        setState(() {
          _loginError = 'Unknown error: $statusCode $body';
          _loggingIn = false;
        });
    }
  }

  Future<void> _doLogout() async {
    widget.dio.options.headers.remove('Authorization');
    setState(() {
      _loggedIn = false;
      _loginError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_loggedIn) {
      return _buildLoginView();
    }
    return _buildTaskCrudView();
  }

  Widget _buildLoginView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Login to access tasks',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'demo@example.com / password',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: _loggingIn ? null : _doLogin,
                child: _loggingIn
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Login'),
              ),
            ),
            if (_loginError != null) ...[
              const SizedBox(height: 12),
              Text(_loginError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTaskCrudView() {
    final tasksAsync = ref.watch(listTasksProvider());
    final mutationState = ref.watch(createTaskMutation);

    // Track when the list refreshes
    if (tasksAsync is AsyncData) {
      _lastRefreshed = DateTime.now();
    }

    return Column(
      children: [
        // Header bar with logout
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              const Text('Logged in as demo@example.com'),
              const Spacer(),
              if (_lastRefreshed != null)
                Text(
                  'Last refreshed: ${_formatTime(_lastRefreshed!)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: _doLogout,
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Logout'),
              ),
            ],
          ),
        ),

        // Task list (upper half)
        Expanded(
          flex: 3,
          child: _buildTaskList(tasksAsync),
        ),

        const Divider(height: 1),

        // Create task form (lower part)
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Create Task', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'Task title',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: mutationState.isLoading
                        ? null
                        : () async {
                            final title = _titleController.text.trim();
                            final response = await createTask(
                              ref,
                              body: CreateTaskRequest(
                                title: title.isEmpty ? '' : title,
                                tags: ['showcase'],
                              ),
                            );
                            switch (response) {
                              case r.CreateTaskResponseCreated(:final data):
                                _titleController.clear();
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Created: ${data.title}')),
                                  );
                                }
                              case r.CreateTaskResponseUnprocessableEntity(:final data):
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Validation error: ${data.message}'),
                                      backgroundColor: Colors.orange,
                                    ),
                                  );
                                }
                              case r.CreateTaskResponseUnauthorized(:final data):
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Unauthorized: ${data.message}'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              case r.CreateTaskResponseUnknown(:final statusCode, :final body):
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error $statusCode: $body'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                            }
                          },
                    child: mutationState.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create Task'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'After creation, the task list auto-refreshes (autoInvalidate)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTaskList(AsyncValue<r.ListTasksResponse> tasksAsync) {
    switch (tasksAsync) {
      case AsyncData(:final value):
        switch (value) {
          case r.ListTasksResponseSuccess(:final data):
            if (data.isEmpty) {
              return const Center(child: Text('No tasks found'));
            }
            return ListView.builder(
              itemCount: data.length,
              itemBuilder: (context, index) {
                final task = data[index];
                return ListTile(
                  leading: _statusIcon(task.status),
                  title: Text(task.title),
                  subtitle: Text('${task.priority} priority'),
                  trailing: Chip(
                    label: Text(task.status),
                    backgroundColor: _statusColor(task.status),
                  ),
                );
              },
            );
          case r.ListTasksResponseUnauthorized(:final data):
            return Center(child: Text('Unauthorized: ${data.message}'));
          case r.ListTasksResponseServerError(:final data):
            return Center(child: Text('Server error: ${data.message}'));
          case r.ListTasksResponseUnknown(:final statusCode, :final body):
            return Center(child: Text('Unknown error: $statusCode $body'));
        }
      case AsyncError(:final error):
        return Center(child: Text('Error: $error'));
      case AsyncLoading():
        return const Center(child: CircularProgressIndicator());
    }
  }

  Icon _statusIcon(String status) {
    switch (status) {
      case 'todo':
        return const Icon(Icons.radio_button_unchecked, color: Colors.grey);
      case 'in_progress':
        return const Icon(Icons.timelapse, color: Colors.blue);
      case 'done':
        return const Icon(Icons.check_circle, color: Colors.green);
      default:
        return const Icon(Icons.help_outline);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'todo':
        return Colors.grey.shade200;
      case 'in_progress':
        return Colors.blue.shade100;
      case 'done':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade200;
    }
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }
}
