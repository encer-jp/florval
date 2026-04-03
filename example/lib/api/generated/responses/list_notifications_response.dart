import '../models/notification.dart' as m;
import '../models/unauthorized_error.dart' as m;

sealed class ListNotificationsResponse {
  const ListNotificationsResponse();

  const factory ListNotificationsResponse.success(List<m.Notification> data) =
      ListNotificationsResponseSuccess;
  const factory ListNotificationsResponse.unauthorized(
      m.UnauthorizedError data) = ListNotificationsResponseUnauthorized;
  const factory ListNotificationsResponse.unknown(
      int statusCode, dynamic body) = ListNotificationsResponseUnknown;
}

class ListNotificationsResponseSuccess extends ListNotificationsResponse {
  final List<m.Notification> data;
  const ListNotificationsResponseSuccess(this.data);
}

class ListNotificationsResponseUnauthorized extends ListNotificationsResponse {
  final m.UnauthorizedError data;
  const ListNotificationsResponseUnauthorized(this.data);
}

class ListNotificationsResponseUnknown extends ListNotificationsResponse {
  final int statusCode;
  final dynamic body;
  const ListNotificationsResponseUnknown(this.statusCode, this.body);
}
