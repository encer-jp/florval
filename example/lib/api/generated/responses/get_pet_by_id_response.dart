import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/pet.dart';

part 'get_pet_by_id_response.freezed.dart';

@freezed
sealed class GetPetByIdResponse with _$GetPetByIdResponse {
  const factory GetPetByIdResponse.success(Pet data) = GetPetByIdResponseSuccess;
  const factory GetPetByIdResponse.badRequest() = GetPetByIdResponseBadRequest;
  const factory GetPetByIdResponse.notFound() = GetPetByIdResponseNotFound;
  const factory GetPetByIdResponse.unknown(int statusCode, dynamic body) = GetPetByIdResponseUnknown;
}
