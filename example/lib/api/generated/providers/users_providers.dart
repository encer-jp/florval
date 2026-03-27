import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'retry.dart';
import '../clients/users_api_client.dart';
import '../api_responses.dart' as _r;

part 'users_providers.g.dart';

@riverpod
UsersApiClient usersApiClient(Ref ref) {
  throw UnimplementedError('Provide a Dio instance via override');
}

@Riverpod(retry: retry)
class ListUsers extends _$ListUsers {
  @override
  FutureOr<_r.ListUsersResponse> build({
    int? page,
    int? limit,
    String? search,
  }) async {
    final client = ref.watch(usersApiClientProvider);
    return client.listUsers(page: page, limit: limit, search: search);
  }
}

@Riverpod(retry: retry)
class GetUser extends _$GetUser {
  @override
  FutureOr<_r.GetUserResponse> build({
    required String id,
  }) async {
    final client = ref.watch(usersApiClientProvider);
    return client.getUser(id: id);
  }
}

