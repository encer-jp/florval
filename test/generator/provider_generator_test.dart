import 'package:test/test.dart';
import 'package:florval/src/generator/provider_generator.dart';
import 'package:florval/src/model/api_endpoint.dart';
import 'package:florval/src/model/api_response.dart';
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

    test('generates part directive', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, contains("part 'users_providers.g.dart';"));
    });

    test('generates riverpod_annotation import', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code,
          contains("import 'package:riverpod_annotation/riverpod_annotation.dart';"));
    });

    test('generates dart:async import', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, contains("import 'dart:async';"));
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
      final endpoint = FlorvalEndpoint(
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

      final code = generator.generate('users', [endpoint]);

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

    test('generates POST endpoint as mutation', () {
      final code = generator.generate('users', [makePostEndpoint()]);

      expect(code, contains('class CreateUser extends _\$CreateUser'));
      expect(code, contains('FutureOr<CreateUserResponse?> build() => null;'));
      expect(code, contains('@mutation'));
      expect(code, contains('Future<CreateUserResponse> call('));
      expect(code, contains('required CreateUserRequest body,'));
      expect(code, contains('client.createUser(body: body)'));
    });

    test('generates PUT endpoint as mutation with path params', () {
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

      expect(code, contains('class UpdateUser extends _\$UpdateUser'));
      expect(code, contains('@mutation'));
      expect(code, contains('required int id,'));
      expect(code, contains('required UpdateUserRequest body,'));
      expect(code, contains('client.updateUser(id: id, body: body)'));
    });

    test('generates DELETE endpoint as mutation', () {
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

      expect(code, contains('class DeleteUser extends _\$DeleteUser'));
      expect(code, contains('@mutation'));
      expect(code, contains('Future<DeleteUserResponse> call('));
      expect(code, contains('required int id,'));
      expect(code, contains('client.deleteUser(id: id)'));
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
      expect(code, contains('class CreateUser extends _\$CreateUser'));
    });

    test('mutation invalidates related GET providers', () {
      final code = generator.generate(
          'users', [makeGetEndpoint(), makePostEndpoint()]);

      // The POST mutation should invalidate the GET provider
      expect(code, contains('ref.invalidate(getUserProvider)'));
    });

    test('mutation with multiple GET endpoints invalidates all', () {
      final listEndpoint = FlorvalEndpoint(
        path: '/users',
        method: 'GET',
        operationId: 'listUsers',
        parameters: [],
        responses: {200: FlorvalResponse(statusCode: 200)},
        tags: ['users'],
      );

      final code = generator.generate(
          'users', [makeGetEndpoint(), listEndpoint, makePostEndpoint()]);

      expect(code, contains('ref.invalidate(getUserProvider)'));
      expect(code, contains('ref.invalidate(listUsersProvider)'));
    });

    test('GET providers do not have invalidation calls', () {
      final code = generator.generate('users', [makeGetEndpoint()]);

      expect(code, isNot(contains('ref.invalidate(')));
    });
  });
}
