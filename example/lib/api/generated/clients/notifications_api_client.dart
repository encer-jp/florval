import 'package:dio/dio.dart';

import '../models/notification.dart';
import '../models/unauthorized_error.dart';
import '../api_responses.dart' as _r;

class NotificationsApiClient {
  final Dio _dio;

  NotificationsApiClient(this._dio);

  Future<_r.ListNotificationsResponse> listNotifications() async {
    try {
      final response = await _dio.get('/notifications',
      );
      switch (response.statusCode) {
        case 200:
          return _r.ListNotificationsResponse.success((response.data as List).map((e) => Notification.fromJson(e as Map<String, dynamic>)).toList());
        case 401:
          return _r.ListNotificationsResponse.unauthorized(UnauthorizedError.fromJson(response.data as Map<String, dynamic>));
        default:
          return _r.ListNotificationsResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 401:
          return _r.ListNotificationsResponse.unauthorized(UnauthorizedError.fromJson(e.response!.data as Map<String, dynamic>));
          default:
            return _r.ListNotificationsResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }
}
