import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod/experimental/mutation.dart';

import '../api/generated/api.dart';
import '../api/generated/api_responses.dart' as r;

class MutationTab extends ConsumerStatefulWidget {
  const MutationTab({super.key});

  @override
  ConsumerState<MutationTab> createState() => _MutationTabState();
}

class _MutationTabState extends ConsumerState<MutationTab> {
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(listTasksProvider());
    final mutationState = ref.watch(createTaskMutation);

    return Column(
      children: [
        Expanded(
          flex: 3,
          child: tasksAsync.when(
            data: (value) => _buildTaskList(value),
            error: (error, _) => Center(child: Text('Error: $error')),
            loading: () => const Center(child: CircularProgressIndicator()),
          ),
        ),
        const Divider(height: 1),
        _buildCreateTaskForm(mutationState),
      ],
    );
  }

  Widget _buildTaskList(r.ListTasksResponse value) {
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
      case r.ListTasksResponseServerError(:final data):
        return Center(child: Text('Server error: ${data.message}'));
      case r.ListTasksResponseUnknown(:final statusCode, :final body):
        return Center(child: Text('Unknown error: $statusCode $body'));
    }
  }

  Widget _buildCreateTaskForm(
      MutationState<r.CreateTaskResponse> mutationState) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Create Task', style: theme.textTheme.titleMedium),
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
                onPressed:
                    mutationState.isPending ? null : () => _onCreateTask(),
                child: mutationState.isPending
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
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _onCreateTask() async {
    final title = _titleController.text.trim();
    final response = await createTask(
      ref,
      body: CreateTaskRequest(
        title: title.isEmpty ? '' : title,
        tags: ['showcase'],
      ),
    );
    if (!mounted) return;
    switch (response) {
      case r.CreateTaskResponseCreated(:final data):
        _titleController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created: ${data.title}')),
        );
      case r.CreateTaskResponseUnprocessableEntity(:final data):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Validation error: ${data.message}'),
            backgroundColor: Colors.orange,
          ),
        );
      case r.CreateTaskResponseUnknown(:final statusCode, :final body):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error $statusCode: $body'),
            backgroundColor: Colors.red,
          ),
        );
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
}
