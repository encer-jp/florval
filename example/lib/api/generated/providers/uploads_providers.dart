import 'package:dio/dio.dart';
import 'package:riverpod/experimental/mutation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'api_dio_provider.dart';
import '../clients/uploads_api_client.dart';
import '../api_responses.dart' as r;

part 'uploads_providers.g.dart';

@riverpod
UploadsApiClient uploadsApiClient(Ref ref) {
  return UploadsApiClient(ref.watch(apiDioProvider));
}

/// Mutation for uploadFile (POST /uploads)
final uploadFileMutation = Mutation<r.UploadFileResponse>();

/// Executes uploadFile mutation.
Future<r.UploadFileResponse> uploadFile(
  MutationTarget ref, {
  required MultipartFile file,
  String? description,
}) {
  return uploadFileMutation.run(ref, (tsx) async {
    final client = tsx.get(uploadsApiClientProvider);
    final result =
        await client.uploadFile(file: file, description: description);
    return result;
  });
}
