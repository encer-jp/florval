import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'api_dio_provider.dart';
import 'retry.dart';
import '../clients/users_api_client.dart';
import '../api_responses.dart' as r;

part 'users_providers.g.dart';

@riverpod
UsersApiClient usersApiClient(Ref ref) {
  return UsersApiClient(ref.watch(apiDioProvider));
}

@Riverpod(retry: retry)
class ListUsers extends _$ListUsers {
  @override
  FutureOr<r.ListUsersResponse> build({
    int? page,
    int? limit,
    String? search,
  }) {
    final client = ref.watch(usersApiClientProvider);
    return client.listUsers(page: page, limit: limit, search: search);
  }
}

@Riverpod(retry: retry)
class GetUser extends _$GetUser {
  @override
  FutureOr<r.GetUserResponse> build({
    required String id,
  }) {
    final client = ref.watch(usersApiClientProvider);
    return client.getUser(id: id);
  }
}
