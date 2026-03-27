import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/generated/api.dart';
import '../api/generated/api_responses.dart' as r;

class PaginationTab extends ConsumerStatefulWidget {
  const PaginationTab({super.key});

  @override
  ConsumerState<PaginationTab> createState() => _PaginationTabState();
}

class _PaginationTabState extends ConsumerState<PaginationTab> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(listUsersProvider(limit: 5).notifier).fetchMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(listUsersProvider(limit: 5));

    return Column(
      children: [
        // Info header
        Container(
          padding: const EdgeInsets.all(16),
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Cursor-based pagination with fetchMore(). Scroll to the bottom to load more users (5 per page).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),

        // Stats bar
        _buildStatsBar(usersAsync),

        const Divider(height: 1),

        // User list
        Expanded(child: _buildUserList(usersAsync)),
      ],
    );
  }

  Widget _buildStatsBar(AsyncValue<PaginatedData<User, CursorPaginatedUsers>> usersAsync) {
    return switch (usersAsync) {
      AsyncData(:final value) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Loaded: ${value.items.length} users',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 16),
              if (value.hasMore)
                Text(
                  'More available (cursor: ${value.nextCursor?.substring(0, 8)}...)',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                )
              else
                Text(
                  'All users loaded',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      _ => const SizedBox.shrink(),
    };
  }

  Widget _buildUserList(AsyncValue<PaginatedData<User, CursorPaginatedUsers>> usersAsync) {
    switch (usersAsync) {
      case AsyncData(:final value):
        return ListView.builder(
          controller: _scrollController,
          itemCount: value.items.length + (value.hasMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == value.items.length) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final user = value.items[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: _roleColor(user.role),
                child: Text(
                  user.name[0],
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(user.name),
              subtitle: Text(user.email),
              trailing: Chip(
                label: Text(user.role),
                backgroundColor: _roleColor(user.role).withValues(alpha: 0.15),
                side: BorderSide.none,
              ),
            );
          },
        );
      case AsyncError(:final error):
        if (error is ApiException) {
          final resp = error.response;
          if (resp is r.ListUsersResponseUnauthorized) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.lock, size: 48, color: Colors.orange),
                  const SizedBox(height: 8),
                  Text('Unauthorized: ${resp.data.message}'),
                  const SizedBox(height: 8),
                  const Text('Login via the Mutation tab first.'),
                ],
              ),
            );
          }
        }
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 8),
              Text('Error: $error'),
            ],
          ),
        );
      case AsyncLoading():
        return const Center(child: CircularProgressIndicator());
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return Colors.deepPurple;
      case 'member':
        return Colors.blue;
      case 'viewer':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
}
