import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'retry.dart';
import '../clients/users_api_client.dart';
import '../models/cursor_paginated_users.dart';
import '../models/paginated_data.dart';
import '../models/api_exception.dart';
import '../models/user.dart';
import '../api_responses.dart' as r;

part 'users_providers.g.dart';

@riverpod
UsersApiClient usersApiClient(Ref ref) {
  throw UnimplementedError('Provide a Dio instance via override');
}

@Riverpod(retry: retry)
class ListUsers extends _$ListUsers {
  final List<User> _allItems = [];
  String? _nextCursor;
  bool _hasMore = true;

  @override
  FutureOr<PaginatedData<User, CursorPaginatedUsers>> build({
    int? limit,
    String? search,
  }) async {
    _allItems.clear();
    _nextCursor = null;
    _hasMore = true;

    final client = ref.watch(usersApiClientProvider);
    final response = await client.listUsers(limit: limit, search: search);

    switch (response) {
      case r.ListUsersResponseSuccess(:final data):
        _allItems.addAll(data.items);
        _nextCursor = data.nextCursor;
        _hasMore = data.nextCursor != null;
        return PaginatedData(
          items: List.unmodifiable(_allItems),
          nextCursor: _nextCursor,
          hasMore: _hasMore,
          lastPage: data,
        );
      default:
        throw ApiException(response);
    }
  }

  Future<void> fetchMore() async {
    if (!_hasMore || _nextCursor == null) return;

    final client = ref.read(usersApiClientProvider);
    final response = await client.listUsers(limit: limit, search: search, after: _nextCursor);

    switch (response) {
      case r.ListUsersResponseSuccess(:final data):
        _allItems.addAll(data.items);
        _nextCursor = data.nextCursor;
        _hasMore = data.nextCursor != null;
        state = AsyncData(PaginatedData(
          items: List.unmodifiable(_allItems),
          nextCursor: _nextCursor,
          hasMore: _hasMore,
          lastPage: data,
        ));
      default:
        state = AsyncError(ApiException(response), StackTrace.current);
    }
  }
}

@Riverpod(retry: retry)
class GetUser extends _$GetUser {
  @override
  FutureOr<r.GetUserResponse> build({
    required String id,
  }) async {
    final client = ref.watch(usersApiClientProvider);
    return client.getUser(id: id);
  }
}
