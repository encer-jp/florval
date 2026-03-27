import 'package:dio/dio.dart';

import '../models/upload_result.dart';
import '../models/bad_request_error.dart';
import '../models/unauthorized_error.dart';
import '../api_responses.dart' as r;

class UploadsApiClient {
  final Dio _dio;

  UploadsApiClient(this._dio);

  Future<r.UploadFileResponse> uploadFile({
    required MultipartFile file,
    String? description,
  }) async {
    try {
      final response = await _dio.post('/uploads',
        data: FormData.fromMap({
          'file': file,
          if (description != null) 'description': description,
        }),
      );
      switch (response.statusCode) {
        case 201:
          return r.UploadFileResponse.created(UploadResult.fromJson(response.data as Map<String, dynamic>));
        case 400:
          return r.UploadFileResponse.badRequest(BadRequestError.fromJson(response.data as Map<String, dynamic>));
        case 401:
          return r.UploadFileResponse.unauthorized(UnauthorizedError.fromJson(response.data as Map<String, dynamic>));
        default:
          return r.UploadFileResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 400:
          return r.UploadFileResponse.badRequest(BadRequestError.fromJson(e.response!.data as Map<String, dynamic>));
        case 401:
          return r.UploadFileResponse.unauthorized(UnauthorizedError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return r.UploadFileResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }
}
