import 'package:riverpod/experimental/mutation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'api_dio_provider.dart';
import '../clients/auth_api_client.dart';
import '../models/login_request.dart';
import '../api_responses.dart' as r;

part 'auth_providers.g.dart';

@riverpod
AuthApiClient authApiClient(Ref ref) {
  return AuthApiClient(ref.watch(apiDioProvider));
}

/// Mutation for login (POST /auth/login)
final loginMutation = Mutation<r.LoginResponse>();

/// Executes login mutation.
Future<r.LoginResponse> login(
  MutationTarget ref, {
  required LoginRequest body,
}) {
  return loginMutation.run(ref, (tsx) async {
    final client = tsx.get(authApiClientProvider);
    final result = await client.login(body: body);
    return result;
  });
}
