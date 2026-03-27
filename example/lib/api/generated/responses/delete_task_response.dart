import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/unauthorized_error.dart' as _m;
import '../models/not_found_error.dart' as _m;

part 'delete_task_response.freezed.dart';

@freezed
sealed class DeleteTaskResponse with _$DeleteTaskResponse {
  const factory DeleteTaskResponse.noContent() = DeleteTaskResponseNoContent;
  const factory DeleteTaskResponse.unauthorized(_m.UnauthorizedError data) = DeleteTaskResponseUnauthorized;
  const factory DeleteTaskResponse.notFound(_m.NotFoundError data) = DeleteTaskResponseNotFound;
  const factory DeleteTaskResponse.unknown(int statusCode, dynamic body) = DeleteTaskResponseUnknown;
}
