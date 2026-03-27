import '../models/notification.dart' as m;

sealed class ListNotificationsResponse {
  const ListNotificationsResponse();

  const factory ListNotificationsResponse.success(List<m.Notification> data) = ListNotificationsResponseSuccess;
  const factory ListNotificationsResponse.unknown(int statusCode, dynamic body) = ListNotificationsResponseUnknown;
}

class ListNotificationsResponseSuccess extends ListNotificationsResponse {
  final List<m.Notification> data;
  const ListNotificationsResponseSuccess(this.data);
}

class ListNotificationsResponseUnknown extends ListNotificationsResponse {
  final int statusCode;
  final dynamic body;
  const ListNotificationsResponseUnknown(this.statusCode, this.body);
}
