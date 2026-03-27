import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/pet.dart';

part 'add_pet_response.freezed.dart';

@freezed
sealed class AddPetResponse with _$AddPetResponse {
  const factory AddPetResponse.success(Pet data) = AddPetResponseSuccess;
  const factory AddPetResponse.badRequest() = AddPetResponseBadRequest;
  const factory AddPetResponse.unprocessableEntity() = AddPetResponseUnprocessableEntity;
  const factory AddPetResponse.unknown(int statusCode, dynamic body) = AddPetResponseUnknown;
}
