import 'package:freezed_annotation/freezed_annotation.dart';

import 'user.dart';

part 'paginated_users.freezed.dart';
part 'paginated_users.g.dart';

@freezed
abstract class PaginatedUsers with _$PaginatedUsers {
  const factory PaginatedUsers({
    required List<User> data,
    required int page,
    required int limit,
    required int total,
    @JsonKey(name: 'total_pages')
    required int totalPages,
  }) = _PaginatedUsers;

  factory PaginatedUsers.fromJson(Map<String, dynamic> json) => _$PaginatedUsersFromJson(json);
}
