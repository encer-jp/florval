import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/pet.dart';

part 'find_pets_by_status_response.freezed.dart';

@freezed
sealed class FindPetsByStatusResponse with _$FindPetsByStatusResponse {
  const factory FindPetsByStatusResponse.success(List<Pet> data) = FindPetsByStatusResponseSuccess;
  const factory FindPetsByStatusResponse.badRequest() = FindPetsByStatusResponseBadRequest;
  const factory FindPetsByStatusResponse.unknown(int statusCode, dynamic body) = FindPetsByStatusResponseUnknown;
}
