import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'api_dio_provider.dart';
import 'retry.dart';
import '../clients/notifications_api_client.dart';
import '../api_responses.dart' as r;

part 'notifications_providers.g.dart';

@riverpod
NotificationsApiClient notificationsApiClient(Ref ref) {
  return NotificationsApiClient(ref.watch(apiDioProvider));
}

@Riverpod(retry: retry)
class ListNotifications extends _$ListNotifications {
  @override
  FutureOr<r.ListNotificationsResponse> build() {
    final client = ref.watch(notificationsApiClientProvider);
    return client.listNotifications();
  }
}
