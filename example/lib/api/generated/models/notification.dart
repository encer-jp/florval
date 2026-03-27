import 'package:freezed_annotation/freezed_annotation.dart';

import 'notification_payload.dart';

part 'notification.freezed.dart';
part 'notification.g.dart';

@freezed
abstract class Notification with _$Notification {
  const factory Notification({
    required String id,
    required String type,
    required NotificationPayload payload,
    @JsonKey(name: 'created_at')
    required DateTime createdAt,
    @JsonKey(name: 'is_read')
    required bool isRead,
  }) = _Notification;

  factory Notification.fromJson(Map<String, dynamic> json) => _$NotificationFromJson(json);
}
