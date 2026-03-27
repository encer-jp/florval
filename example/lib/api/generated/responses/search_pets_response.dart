import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_pets_response.freezed.dart';

@freezed
sealed class SearchPetsResponse with _$SearchPetsResponse {
  const factory SearchPetsResponse.success(Map<String, dynamic> data) = SearchPetsResponseSuccess;
  const factory SearchPetsResponse.badRequest() = SearchPetsResponseBadRequest;
  const factory SearchPetsResponse.unknown(int statusCode, dynamic body) = SearchPetsResponseUnknown;
}
