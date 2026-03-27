import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/notification.dart' as _m;
import '../models/unauthorized_error.dart' as _m;

part 'list_notifications_response.freezed.dart';

@freezed
sealed class ListNotificationsResponse with _$ListNotificationsResponse {
  const factory ListNotificationsResponse.success(List<_m.Notification> data) = ListNotificationsResponseSuccess;
  const factory ListNotificationsResponse.unauthorized(_m.UnauthorizedError data) = ListNotificationsResponseUnauthorized;
  const factory ListNotificationsResponse.unknown(int statusCode, dynamic body) = ListNotificationsResponseUnknown;
}
