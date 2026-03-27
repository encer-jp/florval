import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/upload_result.dart' as _m;
import '../models/bad_request_error.dart' as _m;
import '../models/unauthorized_error.dart' as _m;

part 'upload_file_response.freezed.dart';

@freezed
sealed class UploadFileResponse with _$UploadFileResponse {
  const factory UploadFileResponse.created(_m.UploadResult data) = UploadFileResponseCreated;
  const factory UploadFileResponse.badRequest(_m.BadRequestError data) = UploadFileResponseBadRequest;
  const factory UploadFileResponse.unauthorized(_m.UnauthorizedError data) = UploadFileResponseUnauthorized;
  const factory UploadFileResponse.unknown(int statusCode, dynamic body) = UploadFileResponseUnknown;
}
