import 'package:test/test.dart';
import 'package:florval/src/generator/client_generator.dart';
import 'package:florval/src/model/api_endpoint.dart';
import 'package:florval/src/model/api_response.dart';
import 'package:florval/src/model/api_type.dart';

void main() {
  group('ClientGenerator', () {
    final generator = ClientGenerator();

    FlorvalEndpoint makeGetEndpoint() => FlorvalEndpoint(
          path: '/users/{id}',
          method: 'GET',
          operationId: 'getUser',
          parameters: [
            FlorvalParam(
              name: 'id',
              dartName: 'id',
              location: ParamLocation.path,
              type: FlorvalType(name: 'int', dartType: 'int'),
              isRequired: true,
            ),
          ],
          responses: {
            200: FlorvalResponse(
              statusCode: 200,
              type: FlorvalType(
                  name: 'User',
                  dartType: 'User',
                  ref: '#/components/schemas/User'),
            ),
            404: FlorvalResponse(statusCode: 404),
            500: FlorvalResponse(
              statusCode: 500,
              type: FlorvalType(
                  name: 'Error',
                  dartType: 'Error',
                  ref: '#/components/schemas/Error'),
            ),
          },
          tags: ['users'],
        );

    test('generates client class', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, contains('class UsersApiClient'));
      expect(code, contains('final Dio _dio;'));
      expect(code, contains('UsersApiClient(this._dio);'));
    });

    test('generates method with correct return type', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, contains('Future<GetUserResponse> getUser('));
    });

    test('generates path parameter interpolation', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, contains(r"'/users/$id'"));
    });

    test('generates status code switch', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, contains('switch (response.statusCode)'));
      expect(code, contains('case 200:'));
      expect(code, contains('GetUserResponse.success(User.fromJson('));
      expect(code, contains('case 404:'));
      expect(code, contains('GetUserResponse.notFound()'));
      expect(code, contains('case 500:'));
      expect(code, contains('GetUserResponse.serverError(Error.fromJson('));
    });

    test('generates DioException handling', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, contains('on DioException catch (e)'));
      expect(code, contains('e.response != null'));
      expect(code, contains('rethrow'));
    });

    test('generates query parameters', () {
      final endpoint = FlorvalEndpoint(
        path: '/pets',
        method: 'GET',
        operationId: 'listPets',
        parameters: [
          FlorvalParam(
            name: 'limit',
            dartName: 'limit',
            location: ParamLocation.query,
            type: FlorvalType(name: 'int', dartType: 'int'),
            isRequired: false,
          ),
        ],
        responses: {
          200: FlorvalResponse(
            statusCode: 200,
            type: FlorvalType(
              name: 'List<Pet>',
              dartType: 'List<Pet>',
              isList: true,
              itemType: FlorvalType(
                  name: 'Pet',
                  dartType: 'Pet',
                  ref: '#/components/schemas/Pet'),
            ),
          ),
        },
        tags: ['pets'],
      );

      final code = generator.generate('pets', [endpoint]);

      expect(code, contains('int? limit,'));
      expect(code, contains('queryParameters:'));
      expect(code, contains("if (limit != null) 'limit': limit,"));
    });

    test('generates request body', () {
      final endpoint = FlorvalEndpoint(
        path: '/pets',
        method: 'POST',
        operationId: 'createPet',
        parameters: [],
        requestBody: FlorvalRequestBody(
          type: FlorvalType(
              name: 'CreatePetRequest',
              dartType: 'CreatePetRequest',
              ref: '#/components/schemas/CreatePetRequest'),
          isRequired: true,
        ),
        responses: {
          201: FlorvalResponse(
            statusCode: 201,
            type: FlorvalType(name: 'Pet', dartType: 'Pet',
                ref: '#/components/schemas/Pet'),
          ),
        },
        tags: ['pets'],
      );

      final code = generator.generate('pets', [endpoint]);

      expect(code, contains('required CreatePetRequest body,'));
      expect(code, contains('data: body.toJson()'));
    });

    test('generates imports for models and responses', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, contains("import 'package:dio/dio.dart';"));
      expect(code, contains("import '../models/user.dart';"));
      expect(code, contains("import '../responses/get_user_response.dart';"));
    });

    test('generates list deserialization', () {
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
              itemType: FlorvalType(
                  name: 'Pet',
                  dartType: 'Pet',
                  ref: '#/components/schemas/Pet'),
            ),
          ),
        },
        tags: ['pets'],
      );

      final code = generator.generate('pets', [endpoint]);

      expect(code, contains('(response.data as List)'));
      expect(code, contains('Pet.fromJson(e as Map<String, dynamic>)'));
    });
  });
}
