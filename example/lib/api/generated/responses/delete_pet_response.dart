import 'package:freezed_annotation/freezed_annotation.dart';

part 'delete_pet_response.freezed.dart';

@freezed
sealed class DeletePetResponse with _$DeletePetResponse {
  const factory DeletePetResponse.success() = DeletePetResponseSuccess;
  const factory DeletePetResponse.badRequest() = DeletePetResponseBadRequest;
  const factory DeletePetResponse.notFound() = DeletePetResponseNotFound;
  const factory DeletePetResponse.unknown(int statusCode, dynamic body) = DeletePetResponseUnknown;
}
