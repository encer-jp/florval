import '../models/upload_result.dart' as m;
import '../models/bad_request_error.dart' as m;

sealed class UploadFileResponse {
  const UploadFileResponse();

  const factory UploadFileResponse.created(m.UploadResult data) = UploadFileResponseCreated;
  const factory UploadFileResponse.badRequest(m.BadRequestError data) = UploadFileResponseBadRequest;
  const factory UploadFileResponse.unknown(int statusCode, dynamic body) = UploadFileResponseUnknown;
}

class UploadFileResponseCreated extends UploadFileResponse {
  final m.UploadResult data;
  const UploadFileResponseCreated(this.data);
}

class UploadFileResponseBadRequest extends UploadFileResponse {
  final m.BadRequestError data;
  const UploadFileResponseBadRequest(this.data);
}

class UploadFileResponseUnknown extends UploadFileResponse {
  final int statusCode;
  final dynamic body;
  const UploadFileResponseUnknown(this.statusCode, this.body);
}
