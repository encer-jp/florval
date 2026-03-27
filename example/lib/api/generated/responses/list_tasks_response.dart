import '../models/task.dart' as _m;
import '../models/unauthorized_error.dart' as _m;
import '../models/server_error.dart' as _m;

sealed class ListTasksResponse {
  const ListTasksResponse();

  const factory ListTasksResponse.success(List<_m.Task> data) = ListTasksResponseSuccess;
  const factory ListTasksResponse.unauthorized(_m.UnauthorizedError data) = ListTasksResponseUnauthorized;
  const factory ListTasksResponse.serverError(_m.ServerError data) = ListTasksResponseServerError;
  const factory ListTasksResponse.unknown(int statusCode, dynamic body) = ListTasksResponseUnknown;
}

class ListTasksResponseSuccess extends ListTasksResponse {
  final List<_m.Task> data;
  const ListTasksResponseSuccess(this.data);
}

class ListTasksResponseUnauthorized extends ListTasksResponse {
  final _m.UnauthorizedError data;
  const ListTasksResponseUnauthorized(this.data);
}

class ListTasksResponseServerError extends ListTasksResponse {
  final _m.ServerError data;
  const ListTasksResponseServerError(this.data);
}

class ListTasksResponseUnknown extends ListTasksResponse {
  final int statusCode;
  final dynamic body;
  const ListTasksResponseUnknown(this.statusCode, this.body);
}
