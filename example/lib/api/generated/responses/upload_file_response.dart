import '../models/upload_result.dart' as _m;
import '../models/bad_request_error.dart' as _m;
import '../models/unauthorized_error.dart' as _m;

sealed class UploadFileResponse {
  const UploadFileResponse();

  const factory UploadFileResponse.created(_m.UploadResult data) = UploadFileResponseCreated;
  const factory UploadFileResponse.badRequest(_m.BadRequestError data) = UploadFileResponseBadRequest;
  const factory UploadFileResponse.unauthorized(_m.UnauthorizedError data) = UploadFileResponseUnauthorized;
  const factory UploadFileResponse.unknown(int statusCode, dynamic body) = UploadFileResponseUnknown;
}

class UploadFileResponseCreated extends UploadFileResponse {
  final _m.UploadResult data;
  const UploadFileResponseCreated(this.data);
}

class UploadFileResponseBadRequest extends UploadFileResponse {
  final _m.BadRequestError data;
  const UploadFileResponseBadRequest(this.data);
}

class UploadFileResponseUnauthorized extends UploadFileResponse {
  final _m.UnauthorizedError data;
  const UploadFileResponseUnauthorized(this.data);
}

class UploadFileResponseUnknown extends UploadFileResponse {
  final int statusCode;
  final dynamic body;
  const UploadFileResponseUnknown(this.statusCode, this.body);
}
