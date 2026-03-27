import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'cursor_paginated_users.freezed.dart';
part 'cursor_paginated_users.g.dart';

@freezed
abstract class CursorPaginatedUsers with _$CursorPaginatedUsers {
  const factory CursorPaginatedUsers({
    required List<User> items,
    required String? nextCursor,
    required bool hasMore,
  }) = _CursorPaginatedUsers;

  factory CursorPaginatedUsers.fromJson(Map<String, dynamic> json) => _$CursorPaginatedUsersFromJson(json);
}
