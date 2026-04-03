import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'retry.dart';
import '../clients/notifications_api_client.dart';
import '../api_responses.dart' as r;

part 'notifications_providers.g.dart';

@riverpod
NotificationsApiClient notificationsApiClient(Ref ref) {
  throw UnimplementedError('Provide a Dio instance via override');
}

@Riverpod(retry: retry)
class ListNotifications extends _$ListNotifications {
  @override
  FutureOr<r.ListNotificationsResponse> build() async {
    final client = ref.watch(notificationsApiClientProvider);
    return client.listNotifications();
  }
}
