import 'package:riverpod/experimental/mutation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'retry.dart';
import '../clients/pet_api_client.dart';
import '../models/pet.dart';
import '../responses/find_pets_by_status_response.dart';
import '../responses/get_pet_by_id_response.dart';
import '../responses/delete_pet_response.dart';
import '../responses/add_pet_response.dart';
import '../responses/search_pets_response.dart';

part 'pet_providers.g.dart';

@riverpod
PetApiClient petApiClient(Ref ref) {
  throw UnimplementedError('Provide a Dio instance via override');
}

@Riverpod(retry: retry)
class FindPetsByStatus extends _$FindPetsByStatus {
  @override
  FutureOr<FindPetsByStatusResponse> build({
    String? status,
  }) async {
    final client = ref.watch(petApiClientProvider);
    return client.findPetsByStatus(status: status);
  }
}

@Riverpod(retry: retry)
class GetPetById extends _$GetPetById {
  @override
  FutureOr<GetPetByIdResponse> build({
    required int petId,
  }) async {
    final client = ref.watch(petApiClientProvider);
    return client.getPetById(petId: petId);
  }
}

/// Mutation for deletePet (DELETE /pet/{petId})
final deletePetMutation = Mutation<DeletePetResponse>();

/// Executes deletePet mutation and invalidates related GET providers.
Future<DeletePetResponse> deletePet(
  MutationTarget ref, {
  required int petId,
}) async {
  return deletePetMutation.run(ref, (tsx) async {
    final client = tsx.get(petApiClientProvider);
    final result = await client.deletePet(petId: petId);
    ref.container.invalidate(findPetsByStatusProvider);
    ref.container.invalidate(getPetByIdProvider);
    ref.container.invalidate(searchPetsProvider);
    return result;
  });
}

/// Mutation for addPet (POST /pet)
final addPetMutation = Mutation<AddPetResponse>();

/// Executes addPet mutation and invalidates related GET providers.
Future<AddPetResponse> addPet(
  MutationTarget ref, {
  required Pet body,
}) async {
  return addPetMutation.run(ref, (tsx) async {
    final client = tsx.get(petApiClientProvider);
    final result = await client.addPet(body: body);
    ref.container.invalidate(findPetsByStatusProvider);
    ref.container.invalidate(getPetByIdProvider);
    ref.container.invalidate(searchPetsProvider);
    return result;
  });
}

@Riverpod(retry: retry)
class SearchPets extends _$SearchPets {
  @override
  FutureOr<SearchPetsResponse> build({
    String? query,
    int? limit,
    String? after,
  }) async {
    final client = ref.watch(petApiClientProvider);
    return client.searchPets(query: query, limit: limit, after: after);
  }
}

