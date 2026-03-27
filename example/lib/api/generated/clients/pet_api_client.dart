import 'package:dio/dio.dart';

import '../models/pet.dart';
import '../responses/find_pets_by_status_response.dart';
import '../responses/get_pet_by_id_response.dart';
import '../responses/delete_pet_response.dart';
import '../responses/add_pet_response.dart';
import '../responses/search_pets_response.dart';

class PetApiClient {
  final Dio _dio;

  PetApiClient(this._dio);

  Future<FindPetsByStatusResponse> findPetsByStatus({
    String? status,
  }) async {
    try {
      final response = await _dio.get('/pet/findByStatus',
        queryParameters: {
          if (status != null) 'status': status,
        },
      );
      switch (response.statusCode) {
        case 200:
          return FindPetsByStatusResponse.success((response.data as List).map((e) => Pet.fromJson(e as Map<String, dynamic>)).toList());
        case 400:
          return FindPetsByStatusResponse.badRequest();
        default:
          return FindPetsByStatusResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 400:
          return FindPetsByStatusResponse.badRequest();
          default:
            return FindPetsByStatusResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<GetPetByIdResponse> getPetById({
    required int petId,
  }) async {
    try {
      final response = await _dio.get('/pet/$petId',
      );
      switch (response.statusCode) {
        case 200:
          return GetPetByIdResponse.success(Pet.fromJson(response.data as Map<String, dynamic>));
        case 400:
          return GetPetByIdResponse.badRequest();
        case 404:
          return GetPetByIdResponse.notFound();
        default:
          return GetPetByIdResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 400:
          return GetPetByIdResponse.badRequest();
        case 404:
          return GetPetByIdResponse.notFound();
          default:
            return GetPetByIdResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<DeletePetResponse> deletePet({
    required int petId,
  }) async {
    try {
      final response = await _dio.delete('/pet/$petId',
        options: Options(responseType: ResponseType.plain),
      );
      switch (response.statusCode) {
        case 200:
          return DeletePetResponse.success();
        case 400:
          return DeletePetResponse.badRequest();
        case 404:
          return DeletePetResponse.notFound();
        default:
          return DeletePetResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 400:
          return DeletePetResponse.badRequest();
        case 404:
          return DeletePetResponse.notFound();
          default:
            return DeletePetResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<AddPetResponse> addPet({
    required Pet body,
  }) async {
    try {
      final response = await _dio.post('/pet',
        data: body.toJson(),
      );
      switch (response.statusCode) {
        case 200:
          return AddPetResponse.success(Pet.fromJson(response.data as Map<String, dynamic>));
        case 400:
          return AddPetResponse.badRequest();
        case 422:
          return AddPetResponse.unprocessableEntity();
        default:
          return AddPetResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 400:
          return AddPetResponse.badRequest();
        case 422:
          return AddPetResponse.unprocessableEntity();
          default:
            return AddPetResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }

  Future<SearchPetsResponse> searchPets({
    String? query,
    int? limit,
    String? after,
  }) async {
    try {
      final response = await _dio.get('/pet/search',
        queryParameters: {
          if (query != null) 'query': query,
          if (limit != null) 'limit': limit,
          if (after != null) 'after': after,
        },
      );
      switch (response.statusCode) {
        case 200:
          return SearchPetsResponse.success(response.data as Map<String, dynamic>);
        case 400:
          return SearchPetsResponse.badRequest();
        default:
          return SearchPetsResponse.unknown(response.statusCode ?? 0, response.data);
      }
    } on DioException catch (e) {
      if (e.response != null) {
        switch (e.response!.statusCode) {
        case 400:
          return SearchPetsResponse.badRequest();
          default:
            return SearchPetsResponse.unknown(e.response!.statusCode ?? 0, e.response!.data);
        }
      }
      rethrow;
    }
  }
}
