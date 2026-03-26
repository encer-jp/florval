import 'package:test/test.dart';
import 'package:florval/src/config/florval_config.dart';
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

    test('generates part directive even when only mutation endpoints exist', () {
      final code = generator.generate('users', [makePostEndpoint()]);

      // Part directive is always needed for client provider (@riverpod)
      expect(code, contains("part 'users_providers.g.dart';"));
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

    test('does not generate dart:async import (not needed in Riverpod 3.x)', () {
      final getCode = generator.generate('users', [makeGetEndpoint()]);
      expect(getCode, isNot(contains("import 'dart:async';")));

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

      expect(code, contains('final createUserMutation = Mutation<CreateUserResponse>();'));
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

      expect(code, contains('final updateUserMutation = Mutation<UpdateUserResponse>();'));
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

      expect(code, contains('final deleteUserMutation = Mutation<DeleteUserResponse>();'));
      expect(code, isNot(contains('class DeleteUser extends _\$DeleteUser')));
      expect(code, isNot(contains('build() => null')));
    });

    test('does not import request body types for mutation-only providers without autoInvalidate', () {
      final code = generator.generate('users', [makePostEndpoint()]);

      // Mutation-only providers generate only Mutation<T>() constants,
      // which don't reference request body types.
      expect(code,
          isNot(contains("import '../models/create_user_request.dart';")));
    });

    test('imports request body types when autoInvalidate generates mutation helpers', () {
      final autoInvalidateGenerator = ProviderGenerator(autoInvalidate: true);
      final code = autoInvalidateGenerator.generate(
          'users', [makeGetEndpoint(), makePostEndpoint()]);

      expect(code,
          contains("import '../models/create_user_request.dart';"));
    });

    test('mutation generates helper without invalidation when autoInvalidate is true but no GET endpoints', () {
      final autoInvalidateGenerator = ProviderGenerator(autoInvalidate: true);
      final code = autoInvalidateGenerator.generate(
          'tickets', [makePostEndpoint()]);

      // Helper function should exist even without GET endpoints
      expect(code, contains('Future<CreateUserResponse> createUser('));
      expect(code, contains('MutationTarget ref'));
      expect(code, contains('createUserMutation.run(ref, (tsx) async {'));
      expect(code, contains('tsx.get(ticketsApiClientProvider)'));
      // No invalidation calls since there are no GET endpoints
      expect(code, isNot(contains('ref.container.invalidate(')));
      // Doc comment should not mention invalidation
      expect(code, contains('/// Executes createUser mutation.'));
    });

    test('imports request body types when autoInvalidate is true even without GET endpoints', () {
      final autoInvalidateGenerator = ProviderGenerator(autoInvalidate: true);
      final code = autoInvalidateGenerator.generate(
          'tickets', [makePostEndpoint()]);

      expect(code,
          contains("import '../models/create_user_request.dart';"));
    });

    test('generates multiple endpoints in one file', () {
      final code = generator.generate(
          'users', [makeGetEndpoint(), makePostEndpoint()]);

      expect(code, contains('class GetUser extends _\$GetUser'));
      expect(code, contains('final createUserMutation = Mutation<CreateUserResponse>();'));
    });

    test('mutation does not generate helper by default', () {
      final code = generator.generate(
          'users', [makeGetEndpoint(), makePostEndpoint()]);

      expect(code, isNot(contains('Future<CreateUserResponse> createUser(')));
      expect(code, isNot(contains('MutationTarget')));
      expect(code, isNot(contains('ref.container.invalidate(')));
    });

    test('mutation generates helper with invalidation when autoInvalidate is true', () {
      final autoInvalidateGenerator = ProviderGenerator(autoInvalidate: true);
      final code = autoInvalidateGenerator.generate(
          'users', [makeGetEndpoint(), makePostEndpoint()]);

      // Helper function should exist
      expect(code, contains('Future<CreateUserResponse> createUser('));
      expect(code, contains('MutationTarget ref'));
      expect(code, contains('createUserMutation.run(ref, (tsx) async {'));
      expect(code, contains('tsx.get(usersApiClientProvider)'));
      expect(code, contains('ref.container.invalidate(getUserProvider)'));
    });

    test('mutation helper with multiple GET endpoints invalidates all when autoInvalidate is true', () {
      final autoInvalidateGenerator = ProviderGenerator(autoInvalidate: true);

      final code = autoInvalidateGenerator.generate(
          'users', [makeGetEndpoint(), makeListEndpoint(), makePostEndpoint()]);

      expect(code, contains('ref.container.invalidate(getUserProvider)'));
      expect(code, contains('ref.container.invalidate(listUsersProvider)'));
    });

    test('mutation helper not generated when autoInvalidate is false', () {
      final code = generator.generate(
          'users', [makeGetEndpoint(), makePostEndpoint()]);

      expect(code, isNot(contains('Future<CreateUserResponse> createUser(')));
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

      expect(code, contains('final uploadPetPhotoMutation = Mutation<UploadPetPhotoResponse>();'));
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

      expect(code, isNot(contains('ref.container.invalidate(')));
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

    // Pagination tests
    group('pagination', () {
      FlorvalEndpoint makePaginatedEndpoint() => FlorvalEndpoint(
            path: '/pets/paginated',
            method: 'GET',
            operationId: 'listPetsPaginated',
            parameters: [
              FlorvalParam(
                name: 'limit',
                dartName: 'limit',
                location: ParamLocation.query,
                type: FlorvalType(name: 'int', dartType: 'int'),
                isRequired: false,
              ),
              FlorvalParam(
                name: 'after',
                dartName: 'after',
                location: ParamLocation.query,
                type: FlorvalType(name: 'String', dartType: 'String'),
                isRequired: false,
              ),
            ],
            responses: {
              200: FlorvalResponse(
                statusCode: 200,
                type: FlorvalType(
                    name: 'ListPetsPaginatedPage',
                    dartType: 'ListPetsPaginatedPage',
                    ref: '#/components/schemas/ListPetsPaginatedPage'),
              ),
              400: FlorvalResponse(
                statusCode: 400,
                type: FlorvalType(
                    name: 'Error',
                    dartType: 'Error',
                    ref: '#/components/schemas/Error'),
              ),
            },
            tags: ['pets'],
            pagination: PaginationInfo(
              cursorParam: 'after',
              nextCursorField: 'nextCursor',
              itemsField: 'items',
              itemType: FlorvalType(
                  name: 'Pet',
                  dartType: 'Pet',
                  ref: '#/components/schemas/Pet'),
            ),
          );

      test('generates paginated provider with fetchMore', () {
        final code = generator.generate('pets', [makePaginatedEndpoint()]);

        expect(code, contains('class ListPetsPaginated extends _\$ListPetsPaginated'));
        expect(code, contains('FutureOr<PaginatedData<Pet, ListPetsPaginatedPage>> build('));
        expect(code, contains('Future<void> fetchMore()'));
      });

      test('paginated provider contains _allItems and _nextCursor fields', () {
        final code = generator.generate('pets', [makePaginatedEndpoint()]);

        expect(code, contains('final List<Pet> _allItems = [];'));
        expect(code, contains('String? _nextCursor;'));
        expect(code, contains('bool _hasMore = true;'));
      });

      test('paginated provider build() resets state', () {
        final code = generator.generate('pets', [makePaginatedEndpoint()]);

        expect(code, contains('_allItems.clear();'));
        expect(code, contains('_nextCursor = null;'));
        expect(code, contains('_hasMore = true;'));
      });

      test('paginated provider build() switches on Union type', () {
        final code = generator.generate('pets', [makePaginatedEndpoint()]);

        expect(code, contains('switch (response)'));
        expect(code, contains('case ListPetsPaginatedResponseSuccess(:final data):'));
        expect(code, contains('_allItems.addAll(data.items)'));
        expect(code, contains('_nextCursor = data.nextCursor'));
        expect(code, contains('lastPage: data,'));
        expect(code, contains('throw ApiException(response)'));
      });

      test('paginated provider fetchMore() uses cursor param', () {
        final code = generator.generate('pets', [makePaginatedEndpoint()]);

        expect(code, contains('if (!_hasMore || _nextCursor == null) return;'));
        expect(code, contains('after: _nextCursor'));
      });

      test('paginated provider fetchMore() appends items', () {
        final code = generator.generate('pets', [makePaginatedEndpoint()]);

        // fetchMore should update state with AsyncData
        expect(code, contains('state = AsyncData(PaginatedData('));
      });

      test('paginated provider fetchMore() handles errors with AsyncError', () {
        final code = generator.generate('pets', [makePaginatedEndpoint()]);

        expect(code, contains('state = AsyncError(ApiException(response), StackTrace.current)'));
      });

      test('paginated provider excludes cursor param from build()', () {
        final code = generator.generate('pets', [makePaginatedEndpoint()]);

        // build() should have limit but NOT after
        expect(code, contains('int? limit,'));
        // The build signature should not contain 'after' as a parameter
        final buildMatch = RegExp(r'build\(\{(.*?)\}\)', dotAll: true)
            .firstMatch(code);
        expect(buildMatch, isNotNull);
        expect(buildMatch!.group(1), isNot(contains('after')));
      });

      test('paginated provider imports pagination utilities', () {
        final code = generator.generate('pets', [makePaginatedEndpoint()]);

        expect(code, contains("import '../models/paginated_data.dart';"));
        expect(code, contains("import '../models/api_exception.dart';"));
      });

      test('non-paginated endpoints do not import pagination utilities', () {
        final code = generator.generate('users', [makeGetEndpoint()]);

        expect(code, isNot(contains("paginated_data.dart")));
        expect(code, isNot(contains("api_exception.dart")));
      });

      test('normal GET endpoint is unchanged when paginated endpoint exists in different tag', () {
        final code = generator.generate('users', [makeGetEndpoint()]);

        expect(code, contains('class GetUser extends _\$GetUser'));
        expect(code, contains('FutureOr<GetUserResponse> build('));
        expect(code, isNot(contains('fetchMore')));
        expect(code, isNot(contains('PaginatedData')));
      });
    });

    // Retry tests
    group('retry', () {
      final retryGenerator = ProviderGenerator(
        retry: const RiverpodRetryConfig(maxAttempts: 3, delay: 1000),
      );

      test('generates retry utility file', () {
        final code = retryGenerator.generateRetryUtility(
            const RiverpodRetryConfig(maxAttempts: 3, delay: 1000));

        expect(code, contains('Duration? retry(int retryCount, Object error)'));
        expect(code, contains('if (retryCount >= 3) return null;'));
        expect(code, contains('Duration(milliseconds: 1000 * (retryCount + 1))'));
      });

      test('imports retry.dart when retry is configured', () {
        final code = retryGenerator.generate('users', [makeGetEndpoint()]);

        expect(code, contains("import 'retry.dart';"));
      });

      test('GET Notifier uses @Riverpod(retry: retry) when retry is configured', () {
        final code = retryGenerator.generate('users', [makeGetEndpoint()]);

        expect(code, contains('@Riverpod(retry: retry)'));
        expect(code, contains('class GetUser extends _\$GetUser'));
      });

      test('paginated Notifier uses @Riverpod(retry: retry) when retry is configured', () {
        final paginatedEndpoint = FlorvalEndpoint(
          path: '/pets/paginated',
          method: 'GET',
          operationId: 'listPetsPaginated',
          parameters: [
            FlorvalParam(
              name: 'after',
              dartName: 'after',
              location: ParamLocation.query,
              type: FlorvalType(name: 'String', dartType: 'String'),
              isRequired: false,
            ),
          ],
          responses: {
            200: FlorvalResponse(
              statusCode: 200,
              type: FlorvalType(
                  name: 'ListPetsPaginatedPage',
                  dartType: 'ListPetsPaginatedPage',
                  ref: '#/components/schemas/ListPetsPaginatedPage'),
            ),
          },
          tags: ['pets'],
          pagination: PaginationInfo(
            cursorParam: 'after',
            nextCursorField: 'nextCursor',
            itemsField: 'items',
            itemType: FlorvalType(
                name: 'Pet',
                dartType: 'Pet',
                ref: '#/components/schemas/Pet'),
          ),
        );

        final code = retryGenerator.generate('pets', [paginatedEndpoint]);

        expect(code, contains('@Riverpod(retry: retry)'));
        expect(code, contains('class ListPetsPaginated extends _\$ListPetsPaginated'));
      });

      test('Mutation constants are not affected by retry', () {
        final code = retryGenerator.generate(
            'users', [makeGetEndpoint(), makePostEndpoint()]);

        expect(code, contains('final createUserMutation = Mutation<CreateUserResponse>();'));
        // Mutation line should not have retry annotation
        final mutationLine = code.split('\n')
            .where((l) => l.contains('Mutation<CreateUserResponse>'))
            .first;
        expect(mutationLine, isNot(contains('retry')));
      });

      test('does not import retry.dart when retry is not configured', () {
        final code = generator.generate('users', [makeGetEndpoint()]);

        expect(code, isNot(contains("import 'retry.dart';")));
      });

      test('GET Notifier uses @riverpod (lowercase) when retry is not configured', () {
        final code = generator.generate('users', [makeGetEndpoint()]);

        expect(code, contains('@riverpod'));
        expect(code, isNot(contains('@Riverpod(retry:')));
      });

      test('retry utility uses custom max_attempts and delay', () {
        final code = retryGenerator.generateRetryUtility(
            const RiverpodRetryConfig(maxAttempts: 5, delay: 2000));

        expect(code, contains('if (retryCount >= 5) return null;'));
        expect(code, contains('Duration(milliseconds: 2000 * (retryCount + 1))'));
      });

      test('does not import retry.dart when only mutation endpoints exist', () {
        final code = retryGenerator.generate('users', [makePostEndpoint()]);

        expect(code, isNot(contains("import 'retry.dart';")));
      });
    });

    test('does not produce double ?? for nullable optional query params', () {
      final endpoint = FlorvalEndpoint(
        path: '/items',
        method: 'GET',
        operationId: 'listItems',
        parameters: [
          FlorvalParam(
            name: 'filter',
            dartName: 'filter',
            location: ParamLocation.query,
            type: FlorvalType(
                name: 'String', dartType: 'String?', isNullable: true),
            isRequired: false,
          ),
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
            type: FlorvalType(name: 'String', dartType: 'String'),
          ),
        },
        tags: ['items'],
      );

      final code = generator.generate('items', [endpoint]);

      // 'String?' (already nullable) should NOT become 'String??'
      expect(code, isNot(contains('??')));
      // Should contain 'String? filter' (single ?)
      expect(code, contains('String? filter'));
      // Non-nullable optional should get single '?'
      expect(code, contains('int? limit'));
    });

    test('renames Riverpod reserved param names with Param suffix', () {
      final endpoint = FlorvalEndpoint(
        path: '/auth/callback',
        method: 'GET',
        operationId: 'authCallback',
        parameters: [
          FlorvalParam(
            name: 'code',
            dartName: 'code',
            location: ParamLocation.query,
            type: FlorvalType(name: 'String', dartType: 'String'),
            isRequired: true,
          ),
          FlorvalParam(
            name: 'state',
            dartName: 'state',
            location: ParamLocation.query,
            type: FlorvalType(name: 'String', dartType: 'String'),
            isRequired: true,
          ),
        ],
        responses: {
          200: FlorvalResponse(
            statusCode: 200,
            type: FlorvalType(name: 'String', dartType: 'String'),
          ),
        },
        tags: ['auth'],
      );

      final code = generator.generate('auth', [endpoint]);

      // 'state' should be renamed to 'stateParam' in build()
      expect(code, contains('required String stateParam'));
      // 'code' should NOT be renamed (not a reserved name)
      expect(code, contains('required String code'));
      // Client call should map back: state: stateParam
      expect(code, contains('state: stateParam'));
    });
  });
}
