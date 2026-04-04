import 'package:test/test.dart';
import 'package:florval/src/generator/client_generator.dart';
import 'package:florval/src/model/api_endpoint.dart';
import 'package:florval/src/model/api_response.dart';
import 'package:florval/src/model/api_schema.dart';
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

      expect(code, contains('Future<r.GetUserResponse> getUser('));
    });

    test('generates path parameter interpolation', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, contains(r"'/users/$id'"));
    });

    test('generates status code switch', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, contains('switch (response.statusCode)'));
      expect(code, contains('case 200:'));
      expect(code, contains('r.GetUserResponse.success(User.fromJson('));
      expect(code, contains('case 404:'));
      expect(code, contains('r.GetUserResponse.notFound()'));
      expect(code, contains('case 500:'));
      expect(code, contains('r.GetUserResponse.serverError(Error.fromJson('));
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

    test('generates list body serialization with map instead of toJson', () {
      final endpoint = FlorvalEndpoint(
        path: '/v1/user-images/orders',
        method: 'PUT',
        operationId: 'updateImageOrders',
        parameters: [],
        requestBody: FlorvalRequestBody(
          type: FlorvalType(
            name: 'List<UserImageOrderDto>',
            dartType: 'List<UserImageOrderDto>',
            isList: true,
            itemType: FlorvalType(
              name: 'UserImageOrderDto',
              dartType: 'UserImageOrderDto',
              ref: '#/components/schemas/UserImageOrderDto',
            ),
          ),
          isRequired: true,
        ),
        responses: {
          200: FlorvalResponse(statusCode: 200),
        },
        tags: ['user-images'],
      );

      final code = generator.generate('user-images', [endpoint]);

      expect(code, contains('body.map((e) => e.toJson()).toList()'));
      expect(code, isNot(contains('body.toJson()')));
    });

    test('generates imports for models and responses', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, contains("import 'package:dio/dio.dart';"));
      expect(code, contains("import '../models/user.dart';"));
      expect(code, contains("import '../api_responses.dart' as r;"));
    });

    test('generates ResponseType.plain for endpoints with no response body',
        () {
      final endpoint = FlorvalEndpoint(
        path: '/pets/{petId}',
        method: 'DELETE',
        operationId: 'deletePet',
        parameters: [
          FlorvalParam(
            name: 'petId',
            dartName: 'petId',
            location: ParamLocation.path,
            type: FlorvalType(name: 'int', dartType: 'int'),
            isRequired: true,
          ),
        ],
        responses: {
          200: FlorvalResponse(statusCode: 200),
          400: FlorvalResponse(statusCode: 400),
          404: FlorvalResponse(statusCode: 404),
        },
        tags: ['pets'],
      );

      final code = generator.generate('pets', [endpoint]);

      expect(code, contains('ResponseType.plain'));
    });

    test('does not generate ResponseType.plain when response has body', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, isNot(contains('ResponseType.plain')));
    });

    test('generates multipart method with form fields as params', () {
      final endpoint = FlorvalEndpoint(
        path: '/pets/{petId}/photo',
        method: 'POST',
        operationId: 'uploadPetPhoto',
        parameters: [
          FlorvalParam(
            name: 'petId',
            dartName: 'petId',
            location: ParamLocation.path,
            type: FlorvalType(name: 'int', dartType: 'int'),
            isRequired: true,
          ),
        ],
        requestBody: FlorvalRequestBody(
          type: FlorvalType(name: 'FormData', dartType: 'FormData'),
          isRequired: true,
          contentType: ContentType.multipart,
          formFields: [
            FlorvalField(
              name: 'file',
              jsonKey: 'file',
              type: FlorvalType(name: 'MultipartFile', dartType: 'MultipartFile'),
              isRequired: true,
            ),
            FlorvalField(
              name: 'description',
              jsonKey: 'description',
              type: FlorvalType(name: 'String', dartType: 'String'),
              isRequired: false,
            ),
          ],
        ),
        responses: {
          200: FlorvalResponse(
            statusCode: 200,
            type: FlorvalType(
                name: 'Pet',
                dartType: 'Pet',
                ref: '#/components/schemas/Pet'),
          ),
        },
        tags: ['pets'],
      );

      final code = generator.generate('pets', [endpoint]);

      expect(code, contains('required MultipartFile file,'));
      expect(code, contains('String? description,'));
      expect(code, contains('FormData.fromMap({'));
      expect(code, contains("'file': file,"));
      expect(code, contains("if (description != null) 'description': description,"));
      expect(code, isNot(contains('body.toJson()')));
    });

    test('generates doc comment from endpoint summary', () {
      final endpoint = FlorvalEndpoint(
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
        },
        tags: ['users'],
        summary: 'Find user by ID',
      );

      final code = generator.generate('users', [endpoint]);

      expect(code, contains('  /// Find user by ID'));
      // Doc comment should appear before the method signature
      final docIndex = code.indexOf('  /// Find user by ID');
      final methodIndex = code.indexOf('Future<r.GetUserResponse> getUser(');
      expect(docIndex, lessThan(methodIndex));
    });

    test('generates doc comment with summary and description', () {
      final endpoint = FlorvalEndpoint(
        path: '/pets/{petId}',
        method: 'GET',
        operationId: 'getPetById',
        parameters: [
          FlorvalParam(
            name: 'petId',
            dartName: 'petId',
            location: ParamLocation.path,
            type: FlorvalType(name: 'int', dartType: 'int'),
            isRequired: true,
          ),
        ],
        responses: {
          200: FlorvalResponse(
            statusCode: 200,
            type: FlorvalType(
                name: 'Pet',
                dartType: 'Pet',
                ref: '#/components/schemas/Pet'),
          ),
        },
        tags: ['pets'],
        summary: 'Find pet by ID',
        description: 'Returns a single pet',
      );

      final code = generator.generate('pets', [endpoint]);

      expect(code, contains('  /// Find pet by ID'));
      expect(code, contains('  /// Returns a single pet'));
      // Blank line separator between summary and description
      final summaryIndex = code.indexOf('  /// Find pet by ID');
      final blankDocIndex = code.indexOf('  ///', summaryIndex + 1);
      final descIndex = code.indexOf('  /// Returns a single pet');
      expect(blankDocIndex, lessThan(descIndex));
    });

    test('does not generate doc comment when no summary or description', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      // The method should not have doc comments
      final methodIndex = code.indexOf('Future<r.GetUserResponse> getUser(');
      final preceding = code.substring(0, methodIndex);
      expect(preceding, isNot(contains('  ///')));
    });

    test('generates doc comment with only description', () {
      final endpoint = FlorvalEndpoint(
        path: '/users',
        method: 'GET',
        operationId: 'listUsers',
        parameters: [],
        responses: {
          200: FlorvalResponse(statusCode: 200),
        },
        tags: ['users'],
        description: 'Returns all users in the system',
      );

      final code = generator.generate('users', [endpoint]);

      expect(code, contains('  /// Returns all users in the system'));
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

    test('generates @Deprecated annotation for deprecated endpoint', () {
      final endpoint = FlorvalEndpoint(
        path: '/old',
        method: 'GET',
        operationId: 'getOld',
        parameters: [],
        responses: {
          200: FlorvalResponse(statusCode: 200),
        },
        tags: ['test'],
        deprecated: true,
      );

      final code = generator.generate('test', [endpoint]);

      expect(code, contains("  @Deprecated('')"));
      // @Deprecated should appear before the method signature
      final depIndex = code.indexOf("@Deprecated('')");
      final methodIndex = code.indexOf('Future<');
      expect(depIndex, lessThan(methodIndex));
    });

    test('does not generate @Deprecated when deprecated is false', () {
      final code = generator.generate('users', [makeGetEndpoint()]);
      expect(code, isNot(contains('@Deprecated')));
    });

    test('generates explicit type argument for dio calls', () {
      final code = generator.generate('users', [makeGetEndpoint()]);
      expect(code, contains('_dio.get<Map<String, dynamic>>('));
    });

    test('generates List type argument for list responses', () {
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
      expect(code, contains('_dio.get<List<dynamic>>('));
    });

    test('generates dynamic type argument for no-body responses', () {
      final endpoint = FlorvalEndpoint(
        path: '/pets/{id}',
        method: 'DELETE',
        operationId: 'deletePet',
        parameters: [
          FlorvalParam(
            name: 'id',
            dartName: 'id',
            location: ParamLocation.path,
            type: FlorvalType(name: 'String', dartType: 'String'),
            isRequired: true,
          ),
        ],
        responses: {
          204: FlorvalResponse(statusCode: 204),
        },
        tags: ['pets'],
      );
      final code = generator.generate('pets', [endpoint]);
      expect(code, contains('_dio.delete<dynamic>('));
    });
  });
}
