import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/generated/api.dart';
import '../api/generated/api_responses.dart' as r;

class ErrorTab extends ConsumerStatefulWidget {
  final Dio dio;
  const ErrorTab({super.key, required this.dio});

  @override
  ConsumerState<ErrorTab> createState() => _ErrorTabState();
}

class _ErrorTabState extends ConsumerState<ErrorTab> {
  final _results = <_ErrorTestResult>[];
  bool _isRunning = false;

  Future<void> _runTest(String label, Future<_ErrorTestResult> Function() test) async {
    setState(() => _isRunning = true);
    try {
      final result = await test();
      setState(() => _results.add(result));
    } catch (e) {
      setState(() => _results.add(_ErrorTestResult(
        label: label,
        statusCode: 0,
        typeName: 'Exception',
        detail: e.toString(),
      )));
    } finally {
      setState(() => _isRunning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Button list
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trigger API Errors', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                'Each button triggers a different HTTP status code. '
                'florval\'s sealed Union types allow exhaustive pattern matching.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildTestButton(
                    label: '200 Success',
                    icon: Icons.check_circle,
                    color: Colors.green,
                    onPressed: () => _runTest('200 Success', _test200),
                  ),
                  _buildTestButton(
                    label: '401 Unauthorized',
                    icon: Icons.lock,
                    color: Colors.orange,
                    onPressed: () => _runTest('401 Unauthorized', _test401),
                  ),
                  _buildTestButton(
                    label: '404 Not Found',
                    icon: Icons.search_off,
                    color: Colors.orange.shade700,
                    onPressed: () => _runTest('404 Not Found', _test404),
                  ),
                  _buildTestButton(
                    label: '422 Validation',
                    icon: Icons.warning_amber,
                    color: Colors.deepOrange,
                    onPressed: () => _runTest('422 Validation', _test422),
                  ),
                  _buildTestButton(
                    label: '500 Server Error',
                    icon: Icons.error,
                    color: Colors.red,
                    onPressed: () => _runTest('500 Server Error', _test500),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_results.isNotEmpty)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _results.clear()),
                    child: const Text('Clear results'),
                  ),
                ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Results
        Expanded(
          child: _results.isEmpty
              ? Center(
                  child: Text(
                    'Press a button above to trigger an API call',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final result = _results[_results.length - 1 - index];
                    return _buildResultCard(result);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTestButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: _isRunning ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: color,
      ),
    );
  }

  Widget _buildResultCard(_ErrorTestResult result) {
    return Card(
      color: _colorForStatus(result.statusCode),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.white.withValues(alpha: 0.8),
          child: Text(
            '${result.statusCode}',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: _textColorForStatus(result.statusCode),
            ),
          ),
        ),
        title: Text(
          '${result.label} — ${result.typeName}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(result.detail, maxLines: 3, overflow: TextOverflow.ellipsis),
      ),
    );
  }

  Color _colorForStatus(int code) {
    if (code >= 200 && code < 300) return Colors.green.shade50;
    if (code >= 400 && code < 500) return Colors.orange.shade50;
    if (code >= 500) return Colors.red.shade50;
    return Colors.grey.shade100;
  }

  Color _textColorForStatus(int code) {
    if (code >= 200 && code < 300) return Colors.green.shade800;
    if (code >= 400 && code < 500) return Colors.orange.shade800;
    if (code >= 500) return Colors.red.shade800;
    return Colors.grey.shade800;
  }

  // --- Test implementations ---

  Future<_ErrorTestResult> _test200() async {
    final client = ref.read(tasksApiClientProvider);
    final response = await client.listTasks();
    switch (response) {
      case r.ListTasksResponseSuccess(:final data):
        return _ErrorTestResult(
          label: '200 Success',
          statusCode: 200,
          typeName: 'ListTasksResponseSuccess',
          detail: '${data.length} tasks returned',
        );
      case r.ListTasksResponseUnauthorized(:final data):
        return _ErrorTestResult(
          label: '200 Success',
          statusCode: 401,
          typeName: 'ListTasksResponseUnauthorized',
          detail: data.message,
        );
      case r.ListTasksResponseServerError(:final data):
        return _ErrorTestResult(
          label: '200 Success',
          statusCode: 500,
          typeName: 'ListTasksResponseServerError',
          detail: data.message,
        );
      case r.ListTasksResponseUnknown(:final statusCode, :final body):
        return _ErrorTestResult(
          label: '200 Success',
          statusCode: statusCode,
          typeName: 'ListTasksResponseUnknown',
          detail: '$body',
        );
    }
  }

  Future<_ErrorTestResult> _test401() async {
    // Use a Dio without auth header to trigger 401
    final noAuthDio = Dio(BaseOptions(
      baseUrl: widget.dio.options.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    final client = TasksApiClient(noAuthDio);
    final response = await client.listTasks();
    switch (response) {
      case r.ListTasksResponseUnauthorized(:final data):
        return _ErrorTestResult(
          label: '401 Unauthorized',
          statusCode: 401,
          typeName: 'ListTasksResponseUnauthorized',
          detail: data.message,
        );
      case r.ListTasksResponseSuccess(:final data):
        return _ErrorTestResult(
          label: '401 Unauthorized',
          statusCode: 200,
          typeName: 'ListTasksResponseSuccess (unexpected)',
          detail: '${data.length} tasks',
        );
      case r.ListTasksResponseServerError(:final data):
        return _ErrorTestResult(
          label: '401 Unauthorized',
          statusCode: 500,
          typeName: 'ListTasksResponseServerError',
          detail: data.message,
        );
      case r.ListTasksResponseUnknown(:final statusCode, :final body):
        return _ErrorTestResult(
          label: '401 Unauthorized',
          statusCode: statusCode,
          typeName: 'ListTasksResponseUnknown',
          detail: '$body',
        );
    }
  }

  Future<_ErrorTestResult> _test404() async {
    final client = ref.read(tasksApiClientProvider);
    final response = await client.getTask(id: '00000000-0000-0000-0000-000000000000');
    switch (response) {
      case r.GetTaskResponseNotFound(:final data):
        return _ErrorTestResult(
          label: '404 Not Found',
          statusCode: 404,
          typeName: 'GetTaskResponseNotFound',
          detail: data.message,
        );
      case r.GetTaskResponseSuccess(:final data):
        return _ErrorTestResult(
          label: '404 Not Found',
          statusCode: 200,
          typeName: 'GetTaskResponseSuccess (unexpected)',
          detail: data.title,
        );
      case r.GetTaskResponseUnauthorized(:final data):
        return _ErrorTestResult(
          label: '404 Not Found',
          statusCode: 401,
          typeName: 'GetTaskResponseUnauthorized',
          detail: data.message,
        );
      case r.GetTaskResponseUnknown(:final statusCode, :final body):
        return _ErrorTestResult(
          label: '404 Not Found',
          statusCode: statusCode,
          typeName: 'GetTaskResponseUnknown',
          detail: '$body',
        );
    }
  }

  Future<_ErrorTestResult> _test422() async {
    final client = ref.read(tasksApiClientProvider);
    // Send empty title to trigger validation error
    final response = await client.createTask(
      body: CreateTaskRequest(title: ''),
    );
    switch (response) {
      case r.CreateTaskResponseUnprocessableEntity(:final data):
        return _ErrorTestResult(
          label: '422 Validation',
          statusCode: 422,
          typeName: 'CreateTaskResponseUnprocessableEntity',
          detail: '${data.message}: ${data.errors.map((e) => '${e['field']}: ${e['message']}').join(', ')}',
        );
      case r.CreateTaskResponseCreated(:final data):
        return _ErrorTestResult(
          label: '422 Validation',
          statusCode: 201,
          typeName: 'CreateTaskResponseCreated (unexpected)',
          detail: 'Created: ${data.title}',
        );
      case r.CreateTaskResponseUnauthorized(:final data):
        return _ErrorTestResult(
          label: '422 Validation',
          statusCode: 401,
          typeName: 'CreateTaskResponseUnauthorized',
          detail: data.message,
        );
      case r.CreateTaskResponseUnknown(:final statusCode, :final body):
        return _ErrorTestResult(
          label: '422 Validation',
          statusCode: statusCode,
          typeName: 'CreateTaskResponseUnknown',
          detail: '$body',
        );
    }
  }

  Future<_ErrorTestResult> _test500() async {
    final client = ref.read(tasksApiClientProvider);
    final response = await client.listTasks(triggerError: 'true');
    switch (response) {
      case r.ListTasksResponseServerError(:final data):
        return _ErrorTestResult(
          label: '500 Server Error',
          statusCode: 500,
          typeName: 'ListTasksResponseServerError',
          detail: '${data.message} [${data.code}]',
        );
      case r.ListTasksResponseSuccess(:final data):
        return _ErrorTestResult(
          label: '500 Server Error',
          statusCode: 200,
          typeName: 'ListTasksResponseSuccess (unexpected)',
          detail: '${data.length} tasks',
        );
      case r.ListTasksResponseUnauthorized(:final data):
        return _ErrorTestResult(
          label: '500 Server Error',
          statusCode: 401,
          typeName: 'ListTasksResponseUnauthorized',
          detail: data.message,
        );
      case r.ListTasksResponseUnknown(:final statusCode, :final body):
        return _ErrorTestResult(
          label: '500 Server Error',
          statusCode: statusCode,
          typeName: 'ListTasksResponseUnknown',
          detail: '$body',
        );
    }
  }
}

class _ErrorTestResult {
  final String label;
  final int statusCode;
  final String typeName;
  final String detail;

  _ErrorTestResult({
    required this.label,
    required this.statusCode,
    required this.typeName,
    required this.detail,
  });
}
