import 'package:test/test.dart';
import 'package:florval/src/generator/provider_generator.dart';
import 'package:florval/src/model/api_endpoint.dart';
import 'package:florval/src/model/api_response.dart';
import 'package:florval/src/model/api_schema.dart';
import 'package:florval/src/model/api_type.dart';

void main() {
  group('ProviderGenerator', () {
    final generator = ProviderGenerator();

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
          },
          tags: ['users'],
        );

    FlorvalEndpoint makePostEndpoint() => FlorvalEndpoint(
          path: '/users',
          method: 'POST',
          operationId: 'createUser',
          parameters: [],
          requestBody: FlorvalRequestBody(
            type: FlorvalType(
                name: 'CreateUserRequest',
                dartType: 'CreateUserRequest',
                ref: '#/components/schemas/CreateUserRequest'),
            isRequired: true,
          ),
          responses: {
            201: FlorvalResponse(
              statusCode: 201,
              type: FlorvalType(
                  name: 'User',
                  dartType: 'User',
                  ref: '#/components/schemas/User'),
            ),
          },
          tags: ['users'],
        );

    FlorvalEndpoint makeListEndpoint() => FlorvalEndpoint(
          path: '/users',
          method: 'GET',
          operationId: 'listUsers',
          parameters: [],
          responses: {
            200: FlorvalResponse(
              statusCode: 200,
              type: FlorvalType(
                name: 'List<User>',
                dartType: 'List<User>',
                isList: true,
                itemType: FlorvalType(
                    name: 'User',
                    dartType: 'User',
                    ref: '#/components/schemas/User'),
              ),
            ),
          },
          tags: ['users'],
        );

    test('generates part directive when GET endpoints exist', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, contains("part 'users_providers.g.dart';"));
    });

    test('does not generate part directive when only mutation endpoints exist', () {
      final code = generator.generate('users', [makePostEndpoint()]);

      expect(code, isNot(contains("part '")));
    });

    test('generates riverpod_annotation import for GET endpoints', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code,
          contains("import 'package:riverpod_annotation/riverpod_annotation.dart';"));
    });

    test('generates mutation import for mutation endpoints', () {
      final code = generator.generate('users', [makePostEndpoint()]);

      expect(code,
          contains("import 'package:riverpod/experimental/mutation.dart';"));
    });

    test('generates dart:async import only for GET endpoints', () {
      final getCode = generator.generate('users', [makeGetEndpoint()]);
      expect(getCode, contains("import 'dart:async';"));

      final postCode = generator.generate('users', [makePostEndpoint()]);
      expect(postCode, isNot(contains("import 'dart:async';")));
    });

    test('generates client import', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code,
          contains("import '../clients/users_api_client.dart';"));
    });

    test('generates response imports', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code,
          contains("import '../responses/get_user_response.dart';"));
    });

    test('generates client provider', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, contains('@riverpod'));
      expect(code, contains('UsersApiClient usersApiClient(Ref ref)'));
    });

    test('generates GET endpoint as @riverpod Notifier', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, contains('class GetUser extends _\$GetUser'));
      expect(code, contains('FutureOr<GetUserResponse> build('));
      expect(code, contains('required int id,'));
      expect(code, contains('ref.watch(usersApiClientProvider)'));
      expect(code, contains('client.getUser(id: id)'));
    });

    test('generates GET endpoint without params', () {
      final code = generator.generate('users', [makeListEndpoint()]);

      expect(code, contains('class ListUsers extends _\$ListUsers'));
      expect(code, contains('FutureOr<ListUsersResponse> build() async'));
      expect(code, contains('client.listUsers()'));
    });

    test('generates GET endpoint with query params', () {
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
          FlorvalParam(
            name: 'status',
            dartName: 'status',
            location: ParamLocation.query,
            type: FlorvalType(name: 'String', dartType: 'String'),
            isRequired: true,
          ),
        ],
        responses: {
          200: FlorvalResponse(statusCode: 200),
        },
        tags: ['pets'],
      );

      final code = generator.generate('pets', [endpoint]);

      expect(code, contains('int? limit,'));
      expect(code, contains('required String status,'));
      expect(code, contains('client.listPets(limit: limit, status: status)'));
    });

    test('generates POST endpoint as Mutation constant', () {
      final code = generator.generate('users', [makePostEndpoint()]);

      expect(code, contains('final createUser = Mutation<CreateUserResponse>();'));
      expect(code, isNot(contains('class CreateUser extends _\$CreateUser')));
      expect(code, isNot(contains('build() => null')));
      expect(code, isNot(contains('@mutation')));
    });

    test('generates PUT endpoint as Mutation constant with path params', () {
      final endpoint = FlorvalEndpoint(
        path: '/users/{id}',
        method: 'PUT',
        operationId: 'updateUser',
        parameters: [
          FlorvalParam(
            name: 'id',
            dartName: 'id',
            location: ParamLocation.path,
            type: FlorvalType(name: 'int', dartType: 'int'),
            isRequired: true,
          ),
        ],
        requestBody: FlorvalRequestBody(
          type: FlorvalType(
              name: 'UpdateUserRequest',
              dartType: 'UpdateUserRequest',
              ref: '#/components/schemas/UpdateUserRequest'),
          isRequired: true,
        ),
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
      );

      final code = generator.generate('users', [endpoint]);

      expect(code, contains('final updateUser = Mutation<UpdateUserResponse>();'));
      expect(code, isNot(contains('class UpdateUser extends _\$UpdateUser')));
      expect(code, isNot(contains('build() => null')));
    });

    test('generates DELETE endpoint as Mutation constant', () {
      final endpoint = FlorvalEndpoint(
        path: '/users/{id}',
        method: 'DELETE',
        operationId: 'deleteUser',
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
          204: FlorvalResponse(statusCode: 204),
        },
        tags: ['users'],
      );

      final code = generator.generate('users', [endpoint]);

      expect(code, contains('final deleteUser = Mutation<DeleteUserResponse>();'));
      expect(code, isNot(contains('class DeleteUser extends _\$DeleteUser')));
      expect(code, isNot(contains('build() => null')));
    });

    test('generates model imports for request body types', () {
      final code = generator.generate('users', [makePostEndpoint()]);

      expect(code,
          contains("import '../models/create_user_request.dart';"));
    });

    test('generates multiple endpoints in one file', () {
      final code = generator.generate(
          'users', [makeGetEndpoint(), makePostEndpoint()]);

      expect(code, contains('class GetUser extends _\$GetUser'));
      expect(code, contains('final createUser = Mutation<CreateUserResponse>();'));
    });

    test('mutation does not generate helper by default', () {
      final code = generator.generate(
          'users', [makeGetEndpoint(), makePostEndpoint()]);

      expect(code, isNot(contains('runCreateUser')));
      expect(code, isNot(contains('ref.invalidate(')));
    });

    test('mutation generates helper with invalidation when autoInvalidate is true', () {
      final autoInvalidateGenerator = ProviderGenerator(autoInvalidate: true);
      final code = autoInvalidateGenerator.generate(
          'users', [makeGetEndpoint(), makePostEndpoint()]);

      // Helper function should exist
      expect(code, contains('Future<CreateUserResponse> runCreateUser('));
      expect(code, contains('MutationTarget ref'));
      expect(code, contains('createUser.run(ref, (tsx) async {'));
      expect(code, contains('tsx.get(usersApiClientProvider)'));
      expect(code, contains('ref.invalidate(getUserProvider)'));
    });

    test('mutation helper with multiple GET endpoints invalidates all when autoInvalidate is true', () {
      final autoInvalidateGenerator = ProviderGenerator(autoInvalidate: true);

      final code = autoInvalidateGenerator.generate(
          'users', [makeGetEndpoint(), makeListEndpoint(), makePostEndpoint()]);

      expect(code, contains('ref.invalidate(getUserProvider)'));
      expect(code, contains('ref.invalidate(listUsersProvider)'));
    });

    test('mutation helper not generated when autoInvalidate is false', () {
      final code = generator.generate(
          'users', [makeGetEndpoint(), makePostEndpoint()]);

      expect(code, isNot(contains('runCreateUser')));
      expect(code, isNot(contains('MutationTarget')));
    });

    test('mutation helper includes request body params', () {
      final autoInvalidateGenerator = ProviderGenerator(autoInvalidate: true);
      final code = autoInvalidateGenerator.generate(
          'users', [makeGetEndpoint(), makePostEndpoint()]);

      expect(code, contains('required CreateUserRequest body,'));
      expect(code, contains('client.createUser(body: body)'));
    });

    test('generates multipart mutation as Mutation constant', () {
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

      expect(code, contains('final uploadPetPhoto = Mutation<UploadPetPhotoResponse>();'));
      expect(code, isNot(contains('class UploadPetPhoto extends')));
    });

    test('generates dio import when multipart endpoint exists', () {
      final endpoint = FlorvalEndpoint(
        path: '/photos',
        method: 'POST',
        operationId: 'uploadPhoto',
        parameters: [],
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
          ],
        ),
        responses: {
          200: FlorvalResponse(statusCode: 200),
        },
        tags: ['photos'],
      );

      final code = generator.generate('photos', [endpoint]);

      expect(code, contains("import 'package:dio/dio.dart';"));
    });

    test('GET providers do not have invalidation calls', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, isNot(contains('ref.invalidate(')));
    });

    test('mutation comment includes method and path', () {
      final code = generator.generate('users', [makePostEndpoint()]);

      expect(code, contains('/// Mutation for createUser (POST /users)'));
    });

    test('generates both mutation import and riverpod_annotation import for mixed endpoints', () {
      final code = generator.generate(
          'users', [makeGetEndpoint(), makePostEndpoint()]);

      expect(code,
          contains("import 'package:riverpod/experimental/mutation.dart';"));
      expect(code,
          contains("import 'package:riverpod_annotation/riverpod_annotation.dart';"));
    });
  });
}
