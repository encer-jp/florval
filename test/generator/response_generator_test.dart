import 'package:test/test.dart';
import 'package:florval/src/generator/response_generator.dart';
import 'package:florval/src/model/api_endpoint.dart';
import 'package:florval/src/model/api_response.dart';
import 'package:florval/src/model/api_type.dart';

void main() {
  group('ResponseGenerator', () {
    final generator = ResponseGenerator();

    test('generates freezed sealed class with status code variants', () {
      final endpoint = FlorvalEndpoint(
        path: '/users/{id}',
        method: 'GET',
        operationId: 'getUser',
        parameters: [],
        responses: {
          200: FlorvalResponse(
            statusCode: 200,
            type: FlorvalType(name: 'User', dartType: 'User',
                ref: '#/components/schemas/User'),
          ),
          404: FlorvalResponse(statusCode: 404),
          500: FlorvalResponse(
            statusCode: 500,
            type: FlorvalType(name: 'Error', dartType: 'Error',
                ref: '#/components/schemas/Error'),
          ),
        },
        tags: ['users'],
      );

      final code = generator.generate(endpoint);

      expect(code, contains('@freezed'));
      expect(code, contains('sealed class GetUserResponse with _\$GetUserResponse'));
      expect(code, contains("import 'package:freezed_annotation/freezed_annotation.dart';"));
      expect(code, contains("part 'get_user_response.freezed.dart';"));
      // No .g.dart (no JSON serialization needed for response types)
      expect(code, isNot(contains('.g.dart')));
      // Factory constructors
      expect(code, contains(
          'const factory GetUserResponse.success(_m.User data) = GetUserResponseSuccess;'));
      expect(code, contains(
          'const factory GetUserResponse.notFound() = GetUserResponseNotFound;'));
      expect(code, contains(
          'const factory GetUserResponse.serverError(_m.Error data) = GetUserResponseServerError;'));
      expect(code, contains(
          'const factory GetUserResponse.unknown(int statusCode, dynamic body) = GetUserResponseUnknown;'));
    });

    test('generates factory with data parameter for body responses', () {
      final endpoint = FlorvalEndpoint(
        path: '/users/{id}',
        method: 'GET',
        operationId: 'getUser',
        parameters: [],
        responses: {
          200: FlorvalResponse(
            statusCode: 200,
            type: FlorvalType(name: 'User', dartType: 'User',
                ref: '#/components/schemas/User'),
          ),
        },
        tags: ['users'],
      );

      final code = generator.generate(endpoint);
      expect(code, contains(
          'const factory GetUserResponse.success(_m.User data) = GetUserResponseSuccess;'));
    });

    test('imports model types with _m prefix', () {
      final endpoint = FlorvalEndpoint(
        path: '/pets',
        method: 'POST',
        operationId: 'createPet',
        parameters: [],
        responses: {
          201: FlorvalResponse(
            statusCode: 201,
            type: FlorvalType(name: 'Pet', dartType: 'Pet',
                ref: '#/components/schemas/Pet'),
          ),
          400: FlorvalResponse(
            statusCode: 400,
            type: FlorvalType(name: 'ValidationError', dartType: 'ValidationError',
                ref: '#/components/schemas/ValidationError'),
          ),
        },
        tags: ['pets'],
      );

      final code = generator.generate(endpoint);
      expect(code, contains("import '../models/pet.dart' as _m;"));
      expect(code, contains("import '../models/validation_error.dart' as _m;"));
    });

    test('generates 201 as created factory with _m prefix', () {
      final endpoint = FlorvalEndpoint(
        path: '/pets',
        method: 'POST',
        operationId: 'createPet',
        parameters: [],
        responses: {
          201: FlorvalResponse(
            statusCode: 201,
            type: FlorvalType(name: 'Pet', dartType: 'Pet',
                ref: '#/components/schemas/Pet'),
          ),
        },
        tags: ['pets'],
      );

      final code = generator.generate(endpoint);
      expect(code, contains('const factory CreatePetResponse.created(_m.Pet data)'));
    });

    test('generates 204 as noContent factory', () {
      final endpoint = FlorvalEndpoint(
        path: '/pets/{petId}',
        method: 'DELETE',
        operationId: 'deletePet',
        parameters: [],
        responses: {
          204: FlorvalResponse(statusCode: 204),
        },
        tags: ['pets'],
      );

      final code = generator.generate(endpoint);
      expect(code, contains(
          'const factory DeletePetResponse.noContent() = DeletePetResponseNoContent;'));
    });

    test('generates list type with _m prefix on items', () {
      final endpoint = FlorvalEndpoint(
        path: '/pets',
        method: 'GET',
        operationId: 'listPets',
        parameters: [],
        responses: {
          200: FlorvalResponse(
            statusCode: 200,
            type: FlorvalType(
              name: 'List<Pet>',
              dartType: 'List<Pet>',
              isList: true,
              itemType: FlorvalType(name: 'Pet', dartType: 'Pet',
                  ref: '#/components/schemas/Pet'),
            ),
          ),
        },
        tags: ['pets'],
      );

      final code = generator.generate(endpoint);
      expect(code, contains('List<_m.Pet> data'));
    });

    test('does not prefix primitive types', () {
      final endpoint = FlorvalEndpoint(
        path: '/count',
        method: 'GET',
        operationId: 'getCount',
        parameters: [],
        responses: {
          200: FlorvalResponse(
            statusCode: 200,
            type: FlorvalType(name: 'int', dartType: 'int'),
          ),
        },
        tags: ['misc'],
      );

      final code = generator.generate(endpoint);
      expect(code, contains('int data'));
      expect(code, isNot(contains('_m.int')));
    });
  });
}
