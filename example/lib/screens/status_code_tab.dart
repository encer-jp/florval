import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/generated/api.dart';
import '../api/generated/api_responses.dart' as r;

class StatusCodeTab extends ConsumerStatefulWidget {
  const StatusCodeTab({super.key});

  @override
  ConsumerState<StatusCodeTab> createState() => _StatusCodeTabState();
}

class _StatusCodeTabState extends ConsumerState<StatusCodeTab> {
  int _selectedStatus = 200;
  _RequestResult? _result;
  bool _isLoading = false;

  Future<void> _sendRequest() async {
    setState(() {
      _isLoading = true;
      _result = null;
    });

    await Future.delayed(const Duration(milliseconds: 1200));

    final client = ref.read(tasksApiClientProvider);

    switch (_selectedStatus) {
      case 200:
        final response = await client.listTasks();
        setState(() {
          _result = switch (response) {
            r.ListTasksResponseSuccess(:final data) => _RequestResult(
                statusCode: 200,
                typeName: 'ListTasksResponseSuccess',
                detail: '${data.length} tasks returned',
                isSuccess: true,
              ),
            r.ListTasksResponseServerError(:final data) => _RequestResult(
                statusCode: 500,
                typeName: 'ListTasksResponseServerError',
                detail: '${data.message} [${data.code}]',
                isSuccess: false,
              ),
            r.ListTasksResponseUnknown(:final statusCode, :final body) =>
              _RequestResult(
                statusCode: statusCode,
                typeName: 'ListTasksResponseUnknown',
                detail: '$body',
                isSuccess: false,
              ),
          };
        });
      case 404:
        final response = await client.getTask(
          id: '00000000-0000-0000-0000-000000000000',
        );
        setState(() {
          _result = switch (response) {
            r.GetTaskResponseSuccess(:final data) => _RequestResult(
                statusCode: 200,
                typeName: 'GetTaskResponseSuccess',
                detail: data.title,
                isSuccess: true,
              ),
            r.GetTaskResponseNotFound(:final data) => _RequestResult(
                statusCode: 404,
                typeName: 'GetTaskResponseNotFound',
                detail: data.message,
                isSuccess: false,
              ),
            r.GetTaskResponseUnknown(:final statusCode, :final body) =>
              _RequestResult(
                statusCode: statusCode,
                typeName: 'GetTaskResponseUnknown',
                detail: '$body',
                isSuccess: false,
              ),
          };
        });
      case 422:
        final response = await client.createTask(
          body: CreateTaskRequest(title: ''),
        );
        setState(() {
          _result = switch (response) {
            r.CreateTaskResponseCreated(:final data) => _RequestResult(
                statusCode: 201,
                typeName: 'CreateTaskResponseCreated',
                detail: 'Created: ${data.title}',
                isSuccess: true,
              ),
            r.CreateTaskResponseUnprocessableEntity(:final data) =>
              _RequestResult(
                statusCode: 422,
                typeName: 'CreateTaskResponseUnprocessableEntity',
                detail:
                    '${data.message}: ${data.errors.map((e) => '${e['field']}: ${e['message']}').join(', ')}',
                isSuccess: false,
              ),
            r.CreateTaskResponseUnknown(:final statusCode, :final body) =>
              _RequestResult(
                statusCode: statusCode,
                typeName: 'CreateTaskResponseUnknown',
                detail: '$body',
                isSuccess: false,
              ),
          };
        });
      case 500:
        final response = await client.listTasks(simulateStatus: 500);
        setState(() {
          _result = switch (response) {
            r.ListTasksResponseSuccess(:final data) => _RequestResult(
                statusCode: 200,
                typeName: 'ListTasksResponseSuccess',
                detail: '${data.length} tasks',
                isSuccess: true,
              ),
            r.ListTasksResponseServerError(:final data) => _RequestResult(
                statusCode: 500,
                typeName: 'ListTasksResponseServerError',
                detail: '${data.message} [${data.code}]',
                isSuccess: false,
              ),
            r.ListTasksResponseUnknown(:final statusCode, :final body) =>
              _RequestResult(
                statusCode: statusCode,
                typeName: 'ListTasksResponseUnknown',
                detail: '$body',
                isSuccess: false,
              ),
          };
        });
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 200, label: Text('200')),
              ButtonSegment(value: 404, label: Text('404')),
              ButtonSegment(value: 422, label: Text('422')),
              ButtonSegment(value: 500, label: Text('500')),
            ],
            selected: {_selectedStatus},
            onSelectionChanged: (selected) {
              setState(() {
                _selectedStatus = selected.first;
                _result = null;
              });
            },
          ),
          const SizedBox(height: 16),
          Text(
            _descriptionForStatus(_selectedStatus),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 200,
            height: 48,
            child: FilledButton(
              onPressed: _isLoading ? null : _sendRequest,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Send Request'),
            ),
          ),
          const SizedBox(height: 32),
          if (_result != null)
            Expanded(child: _buildResultCard(_result!))
          else
            Expanded(
              child: Center(
                child: Text(
                  'Select a status code and send a request',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildResultCard(_RequestResult result) {
    final theme = Theme.of(context);
    final color = result.isSuccess ? Colors.green : Colors.red;

    return Card(
      color: color.withValues(alpha: 0.05),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Text(
                    '${result.statusCode}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.typeName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                result.detail,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'monospace',
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Pattern matched via sealed class:',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                'case ${result.typeName}(:final data) =>',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontFamily: 'monospace',
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _descriptionForStatus(int status) {
    switch (status) {
      case 200:
        return 'GET /tasks - List all tasks successfully';
      case 404:
        return 'GET /tasks/{id} - Request a non-existent task';
      case 422:
        return 'POST /tasks - Create task with empty title (validation error)';
      case 500:
        return 'GET /tasks?simulate_status=500 - Trigger server error';
      default:
        return '';
    }
  }
}

class _RequestResult {
  final int statusCode;
  final String typeName;
  final String detail;
  final bool isSuccess;

  _RequestResult({
    required this.statusCode,
    required this.typeName,
    required this.detail,
    required this.isSuccess,
  });
}
