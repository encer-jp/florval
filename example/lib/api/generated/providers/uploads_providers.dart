import 'package:dio/dio.dart';
import 'package:riverpod/experimental/mutation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../clients/uploads_api_client.dart';
import '../api_responses.dart' as _r;

part 'uploads_providers.g.dart';

@riverpod
UploadsApiClient uploadsApiClient(Ref ref) {
  throw UnimplementedError('Provide a Dio instance via override');
}

/// Mutation for uploadFile (POST /uploads)
final uploadFileMutation = Mutation<_r.UploadFileResponse>();

/// Executes uploadFile mutation.
Future<_r.UploadFileResponse> uploadFile(
  MutationTarget ref, {
  required MultipartFile file,
  String? description,
}) async {
  return uploadFileMutation.run(ref, (tsx) async {
    final client = tsx.get(uploadsApiClientProvider);
    final result = await client.uploadFile(file: file, description: description);
    return result;
  });
}

