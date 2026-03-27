import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:florval/src/config/florval_config.dart';
import 'package:florval/src/florval_runner.dart';

FlorvalConfig _makeConfig(String outputPath,
    {bool riverpodEnabled = false,
    List<PaginationConfig> pagination = const [],
    RiverpodRetryConfig? retry}) {
  return FlorvalConfig.fromArgs(
    schemaPath: 'test/fixtures/petstore.yaml',
    outputDirectory: outputPath,
    riverpod: RiverpodConfig(
      enabled: riverpodEnabled,
      pagination: pagination,
      retry: retry,
    ),
  );
}

void main() {
  group('E2E', () {
    late Directory outputDir;

    setUp(() {
      outputDir = Directory.systemTemp.createTempSync('florval_e2e_');
    });

    tearDown(() {
      if (outputDir.existsSync()) {
        outputDir.deleteSync(recursive: true);
      }
    });

    test('generates code from petstore.yaml', () {
      final config = _makeConfig(outputDir.path);

      FlorvalRunner().run(config);

      // Verify directory structure
      expect(Directory(p.join(outputDir.path, 'models')).existsSync(), isTrue);
      expect(
          Directory(p.join(outputDir.path, 'responses')).existsSync(), isTrue);
      expect(
          Directory(p.join(outputDir.path, 'clients')).existsSync(), isTrue);

      // Verify model files
      expect(
          File(p.join(outputDir.path, 'models', 'pet.dart')).existsSync(),
          isTrue);
      expect(
          File(p.join(outputDir.path, 'models', 'category.dart')).existsSync(),
          isTrue);
      expect(
          File(p.join(outputDir.path, 'models', 'error.dart')).existsSync(),
          isTrue);
      expect(
          File(p.join(outputDir.path, 'models', 'create_pet_request.dart'))
              .existsSync(),
          isTrue);
      expect(
          File(p.join(outputDir.path, 'models', 'validation_error.dart'))
              .existsSync(),
          isTrue);
      expect(
          File(p.join(outputDir.path, 'models', 'field_error.dart'))
              .existsSync(),
          isTrue);

      // Verify response files
      expect(
          File(p.join(outputDir.path, 'responses', 'list_pets_response.dart'))
              .existsSync(),
          isTrue);
      expect(
          File(p.join(outputDir.path, 'responses', 'create_pet_response.dart'))
              .existsSync(),
          isTrue);
      expect(
          File(p.join(outputDir.path, 'responses', 'get_pet_response.dart'))
              .existsSync(),
          isTrue);
      expect(
          File(p.join(outputDir.path, 'responses', 'update_pet_response.dart'))
              .existsSync(),
          isTrue);
      expect(
          File(p.join(outputDir.path, 'responses', 'delete_pet_response.dart'))
              .existsSync(),
          isTrue);
      expect(
          File(p.join(
                  outputDir.path, 'responses', 'upload_pet_photo_response.dart'))
              .existsSync(),
          isTrue);

      // Verify client files
      expect(
          File(p.join(outputDir.path, 'clients', 'pets_api_client.dart'))
              .existsSync(),
          isTrue);

      // Verify barrel files
      expect(
          File(p.join(outputDir.path, 'api.dart')).existsSync(), isTrue);
      expect(
          File(p.join(outputDir.path, 'api_models.dart')).existsSync(), isTrue);
      expect(
          File(p.join(outputDir.path, 'api_responses.dart')).existsSync(), isTrue);
      expect(
          File(p.join(outputDir.path, 'api_clients.dart')).existsSync(), isTrue);
    });

    test('generated models contain correct freezed syntax', () {
      final config = _makeConfig(outputDir.path);

      FlorvalRunner().run(config);

      final petCode =
          File(p.join(outputDir.path, 'models', 'pet.dart')).readAsStringSync();

      expect(petCode, contains('@freezed'));
      expect(petCode, contains('abstract class Pet with _\$Pet'));
      expect(petCode, contains('required int id,'));
      expect(petCode, contains('required String name,'));
      expect(petCode, contains('String? tag,'));
      expect(petCode, contains('Category? category,'));
      expect(petCode, contains('DateTime? createdAt,'));
      expect(petCode, contains(') = _Pet;'));
      expect(petCode, contains('factory Pet.fromJson'));
    });

    test('generated responses contain freezed sealed class syntax', () {
      final config = _makeConfig(outputDir.path);

      FlorvalRunner().run(config);

      final responseCode =
          File(p.join(outputDir.path, 'responses', 'get_pet_response.dart'))
              .readAsStringSync();

      expect(responseCode, contains('@freezed'));
      expect(responseCode, contains('sealed class GetPetResponse with _\$GetPetResponse'));
      expect(responseCode, contains("part 'get_pet_response.freezed.dart';"));
      expect(responseCode,
          contains('const factory GetPetResponse.success(_m.Pet data)'));
      expect(responseCode,
          contains('const factory GetPetResponse.notFound()'));
      expect(responseCode,
          contains('const factory GetPetResponse.serverError(_m.Error data)'));
      expect(responseCode, contains('const factory GetPetResponse.unknown('));
    });

    test('generated client contains dio calls with status code switching', () {
      final config = _makeConfig(outputDir.path);

      FlorvalRunner().run(config);

      final clientCode =
          File(p.join(outputDir.path, 'clients', 'pets_api_client.dart'))
              .readAsStringSync();

      expect(clientCode, contains('class PetsApiClient'));
      expect(clientCode, contains('final Dio _dio;'));
      expect(clientCode, contains('Future<_r.ListPetsResponse> listPets('));
      expect(clientCode, contains('Future<_r.GetPetResponse> getPet('));
      expect(clientCode, contains('Future<_r.CreatePetResponse> createPet('));
      expect(clientCode, contains('Future<_r.DeletePetResponse> deletePet('));
      expect(clientCode, contains('switch (response.statusCode)'));
      expect(clientCode, contains('on DioException catch (e)'));

      // Verify multipart endpoint
      expect(clientCode,
          contains('Future<_r.UploadPetPhotoResponse> uploadPetPhoto('));
      expect(clientCode, contains('required MultipartFile file,'));
      expect(clientCode, contains('String? description,'));
      expect(clientCode, contains('FormData.fromMap('));
    });

    test('barrel file exports all generated files', () {
      final config = _makeConfig(outputDir.path);

      FlorvalRunner().run(config);

      final barrelCode =
          File(p.join(outputDir.path, 'api.dart')).readAsStringSync();

      expect(barrelCode, contains("export 'models/pet.dart';"));
      expect(barrelCode, contains("export 'models/category.dart';"));
      expect(barrelCode, contains("export 'clients/pets_api_client.dart';"));
    });

    test('does not generate providers when riverpod is disabled', () {
      final config = _makeConfig(outputDir.path);

      FlorvalRunner().run(config);

      expect(
          Directory(p.join(outputDir.path, 'providers'))
              .listSync()
              .where((e) => e.path.endsWith('.dart'))
              .isEmpty,
          isTrue);
    });

    test('generates provider files when riverpod is enabled', () {
      final config = _makeConfig(outputDir.path, riverpodEnabled: true);

      FlorvalRunner().run(config);

      // Verify provider directory has files
      expect(
          File(p.join(outputDir.path, 'providers', 'pets_providers.dart'))
              .existsSync(),
          isTrue);
    });

    test('generated providers contain correct riverpod syntax', () {
      final config = _makeConfig(outputDir.path, riverpodEnabled: true);

      FlorvalRunner().run(config);

      final providerCode =
          File(p.join(outputDir.path, 'providers', 'pets_providers.dart'))
              .readAsStringSync();

      // Imports
      expect(providerCode,
          contains("import 'package:riverpod_annotation/riverpod_annotation.dart';"));
      expect(providerCode, contains("part 'pets_providers.g.dart';"));

      // Client provider
      expect(providerCode, contains('PetsApiClient petsApiClient('));

      // GET endpoints → Notifier
      expect(providerCode, contains('class ListPets extends _\$ListPets'));
      expect(providerCode, contains('class GetPet extends _\$GetPet'));

      // POST/PUT/DELETE → Mutation constants
      expect(providerCode, contains('final createPetMutation = Mutation<_r.CreatePetResponse>();'));
      expect(providerCode, contains('final updatePetMutation = Mutation<_r.UpdatePetResponse>();'));
      expect(providerCode, contains('final deletePetMutation = Mutation<_r.DeletePetResponse>();'));
      expect(providerCode, isNot(contains('class CreatePet extends _\$CreatePet')));
      expect(providerCode, isNot(contains('class UpdatePet extends _\$UpdatePet')));
      expect(providerCode, isNot(contains('class DeletePet extends _\$DeletePet')));

      // Multipart endpoint → Mutation constant
      expect(providerCode,
          contains('final uploadPetPhotoMutation = Mutation<_r.UploadPetPhotoResponse>();'));
      expect(providerCode, isNot(contains('class UploadPetPhoto extends _\$UploadPetPhoto')));
      expect(providerCode, contains("import 'package:dio/dio.dart';"));
      expect(providerCode, contains("import 'package:riverpod/experimental/mutation.dart';"));
    });

    test('barrel file includes provider exports when riverpod enabled', () {
      final config = _makeConfig(outputDir.path, riverpodEnabled: true);

      FlorvalRunner().run(config);

      final barrelCode =
          File(p.join(outputDir.path, 'api.dart')).readAsStringSync();

      expect(barrelCode, contains("export 'providers/pets_providers.dart';"));
    });

    test('generates paginated_data.dart and api_exception.dart when pagination configured', () {
      final config = _makeConfig(
        outputDir.path,
        riverpodEnabled: true,
        pagination: [
          PaginationConfig(
            operationId: 'listPetsPaginated',
            cursorParam: 'after',
            nextCursorField: 'nextCursor',
            itemsField: 'items',
          ),
        ],
      );

      FlorvalRunner().run(config);

      expect(
          File(p.join(outputDir.path, 'models', 'paginated_data.dart'))
              .existsSync(),
          isTrue);
      expect(
          File(p.join(outputDir.path, 'models', 'api_exception.dart'))
              .existsSync(),
          isTrue);

      final paginatedDataCode =
          File(p.join(outputDir.path, 'models', 'paginated_data.dart'))
              .readAsStringSync();
      expect(paginatedDataCode, contains('class PaginatedData<T, P>'));

      final apiExceptionCode =
          File(p.join(outputDir.path, 'models', 'api_exception.dart'))
              .readAsStringSync();
      expect(apiExceptionCode, contains('class ApiException'));

      // Wrapper model generated for inline response schema
      expect(
          File(p.join(
                  outputDir.path, 'models', 'list_pets_paginated_page.dart'))
              .existsSync(),
          isTrue);
      final wrapperCode = File(p.join(
              outputDir.path, 'models', 'list_pets_paginated_page.dart'))
          .readAsStringSync();
      expect(wrapperCode, contains('class ListPetsPaginatedPage'));
    });

    test('paginated provider contains fetchMore method', () {
      final config = _makeConfig(
        outputDir.path,
        riverpodEnabled: true,
        pagination: [
          PaginationConfig(
            operationId: 'listPetsPaginated',
            cursorParam: 'after',
            nextCursorField: 'nextCursor',
            itemsField: 'items',
          ),
        ],
      );

      FlorvalRunner().run(config);

      final providerCode =
          File(p.join(outputDir.path, 'providers', 'pets_providers.dart'))
              .readAsStringSync();

      expect(providerCode, contains('class ListPetsPaginated extends _\$ListPetsPaginated'));
      expect(providerCode, contains('Future<void> fetchMore()'));
      expect(providerCode, contains('PaginatedData<Pet, ListPetsPaginatedPage>'));
    });

    test('barrel file exports pagination utilities when configured', () {
      final config = _makeConfig(
        outputDir.path,
        riverpodEnabled: true,
        pagination: [
          PaginationConfig(
            operationId: 'listPetsPaginated',
            cursorParam: 'after',
            nextCursorField: 'nextCursor',
            itemsField: 'items',
          ),
        ],
      );

      FlorvalRunner().run(config);

      final barrelCode =
          File(p.join(outputDir.path, 'api.dart')).readAsStringSync();

      expect(barrelCode, contains("export 'models/paginated_data.dart';"));
      expect(barrelCode, contains("export 'models/api_exception.dart';"));
    });

    test('does not generate pagination utilities when no pagination configured', () {
      final config = _makeConfig(outputDir.path, riverpodEnabled: true);

      FlorvalRunner().run(config);

      expect(
          File(p.join(outputDir.path, 'models', 'paginated_data.dart'))
              .existsSync(),
          isFalse);
      expect(
          File(p.join(outputDir.path, 'models', 'api_exception.dart'))
              .existsSync(),
          isFalse);
    });

    test('generates retry.dart utility and imports it when retry is configured', () {
      final config = _makeConfig(
        outputDir.path,
        riverpodEnabled: true,
        retry: const RiverpodRetryConfig(maxAttempts: 3, delay: 1000),
      );

      FlorvalRunner().run(config);

      // Verify retry.dart utility file
      final retryFile =
          File(p.join(outputDir.path, 'providers', 'retry.dart'));
      expect(retryFile.existsSync(), isTrue);

      final retryCode = retryFile.readAsStringSync();
      expect(retryCode, contains('Duration? retry(int retryCount, Object error)'));
      expect(retryCode, contains('if (retryCount >= 3) return null;'));
      expect(retryCode, contains('Duration(milliseconds: 1000 * (retryCount + 1))'));

      // Verify provider imports retry.dart and uses @Riverpod(retry: retry)
      final providerCode =
          File(p.join(outputDir.path, 'providers', 'pets_providers.dart'))
              .readAsStringSync();

      expect(providerCode, contains("import 'retry.dart';"));
      expect(providerCode, contains('@Riverpod(retry: retry)'));
      expect(providerCode, contains('final createPetMutation = Mutation<_r.CreatePetResponse>();'));

      // Verify barrel file exports retry.dart
      final barrelCode =
          File(p.join(outputDir.path, 'api.dart')).readAsStringSync();
      expect(barrelCode, contains("export 'providers/retry.dart';"));
    });

    test('does not generate retry.dart when retry is not configured', () {
      final config = _makeConfig(outputDir.path, riverpodEnabled: true);

      FlorvalRunner().run(config);

      expect(
          File(p.join(outputDir.path, 'providers', 'retry.dart'))
              .existsSync(),
          isFalse);

      final providerCode =
          File(p.join(outputDir.path, 'providers', 'pets_providers.dart'))
              .readAsStringSync();

      expect(providerCode, isNot(contains("import 'retry.dart';")));
      expect(providerCode, isNot(contains('@Riverpod(retry:')));
    });
  });
}
