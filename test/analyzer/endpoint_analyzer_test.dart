import 'package:openapi_spec_plus/v31.dart' as v31;
import 'package:test/test.dart';
import 'package:florval/src/analyzer/endpoint_analyzer.dart';
import 'package:florval/src/analyzer/response_analyzer.dart';
import 'package:florval/src/analyzer/schema_analyzer.dart';
import 'package:florval/src/config/florval_config.dart';
import 'package:florval/src/model/api_endpoint.dart';
import 'package:florval/src/parser/ref_resolver.dart';
import 'package:florval/src/parser/spec_reader.dart';

void main() {
  group('EndpointAnalyzer', () {
    late v31.OpenAPI spec;
    late EndpointAnalyzer analyzer;

    setUp(() {
      spec = SpecReader().readFile('test/fixtures/petstore.yaml');
      final resolver = RefResolver(spec);
      final schemaAnalyzer = SchemaAnalyzer(resolver);
      final responseAnalyzer = ResponseAnalyzer(resolver, schemaAnalyzer);
      analyzer = EndpointAnalyzer(resolver, schemaAnalyzer, responseAnalyzer);
    });

    test('extracts all endpoints', () {
      final result = analyzer.analyzeAll(spec.paths);
      // GET /pets, POST /pets, GET /pets/paginated, POST /pets/{petId}/photo, GET /pets/{petId}, PUT /pets/{petId}, DELETE /pets/{petId}
      expect(result.endpoints.length, 7);
    });

    test('parses GET /pets correctly', () {
      final result = analyzer.analyzeAll(spec.paths);
      final listPets =
          result.endpoints.firstWhere((e) => e.operationId == 'listPets');

      expect(listPets.path, '/pets');
      expect(listPets.method, 'GET');
      expect(listPets.tags, ['pets']);
      expect(listPets.queryParameters.length, 2);
      expect(listPets.pathParameters, isEmpty);
    });

    test('parses path parameters', () {
      final result = analyzer.analyzeAll(spec.paths);
      final getPet = result.endpoints.firstWhere((e) => e.operationId == 'getPet');

      expect(getPet.pathParameters.length, 1);
      expect(getPet.pathParameters.first.name, 'petId');
      expect(getPet.pathParameters.first.location, ParamLocation.path);
      expect(getPet.pathParameters.first.type.dartType, 'int');
      expect(getPet.pathParameters.first.isRequired, isTrue);
    });

    test('parses query parameters', () {
      final result = analyzer.analyzeAll(spec.paths);
      final listPets =
          result.endpoints.firstWhere((e) => e.operationId == 'listPets');

      final limitParam =
          listPets.queryParameters.firstWhere((p) => p.name == 'limit');
      expect(limitParam.type.dartType, 'int');
      expect(limitParam.isRequired, isFalse);
    });

    test('parses request body', () {
      final result = analyzer.analyzeAll(spec.paths);
      final createPet =
          result.endpoints.firstWhere((e) => e.operationId == 'createPet');

      expect(createPet.requestBody, isNotNull);
      expect(createPet.requestBody!.type.dartType, 'CreatePetRequest');
      expect(createPet.requestBody!.isRequired, isTrue);
    });

    test('parses responses with status codes', () {
      final result = analyzer.analyzeAll(spec.paths);
      final listPets =
          result.endpoints.firstWhere((e) => e.operationId == 'listPets');

      expect(listPets.responses.containsKey(200), isTrue);
      expect(listPets.responses.containsKey(400), isTrue);
      expect(listPets.responses.containsKey(500), isTrue);

      expect(listPets.responses[200]!.type?.isList, isTrue);
      expect(listPets.responses[200]!.type?.itemType?.dartType, 'Pet');
    });

    test('handles responses without body', () {
      final result = analyzer.analyzeAll(spec.paths);
      final getPet = result.endpoints.firstWhere((e) => e.operationId == 'getPet');

      expect(getPet.responses[404]!.type, isNull);
      expect(getPet.responses[404]!.hasBody, isFalse);
    });

    test('handles DELETE with no-body responses', () {
      final result = analyzer.analyzeAll(spec.paths);
      final deletePet =
          result.endpoints.firstWhere((e) => e.operationId == 'deletePet');

      expect(deletePet.responses[204]!.hasBody, isFalse);
      expect(deletePet.responses[404]!.hasBody, isFalse);
    });

    test('parses multipart/form-data request body', () {
      final result = analyzer.analyzeAll(spec.paths);
      final uploadPhoto =
          result.endpoints.firstWhere((e) => e.operationId == 'uploadPetPhoto');

      expect(uploadPhoto.requestBody, isNotNull);
      expect(uploadPhoto.requestBody!.contentType, ContentType.multipart);
      expect(uploadPhoto.requestBody!.isMultipart, isTrue);
      expect(uploadPhoto.requestBody!.isRequired, isTrue);
    });

    test('multipart form fields contain file and description', () {
      final result = analyzer.analyzeAll(spec.paths);
      final uploadPhoto =
          result.endpoints.firstWhere((e) => e.operationId == 'uploadPetPhoto');

      final fields = uploadPhoto.requestBody!.formFields!;
      expect(fields.length, 2);

      final fileField = fields.firstWhere((f) => f.jsonKey == 'file');
      expect(fileField.type.dartType, 'MultipartFile');
      expect(fileField.isRequired, isTrue);

      final descField = fields.firstWhere((f) => f.jsonKey == 'description');
      expect(descField.type.dartType, 'String');
      expect(descField.isRequired, isFalse);
    });

    test('pagination is null when no pagination config provided', () {
      final result = analyzer.analyzeAll(spec.paths);
      final listPets =
          result.endpoints.firstWhere((e) => e.operationId == 'listPets');

      expect(listPets.pagination, isNull);
    });

    test('pagination is set when config matches endpoint', () {
      final paginationConfigs = [
        PaginationConfig(
          operationId: 'listPetsPaginated',
          cursorParam: 'after',
          nextCursorField: 'nextCursor',
          itemsField: 'items',
        ),
      ];
      final resolver = RefResolver(spec);
      final schemaAnalyzer = SchemaAnalyzer(resolver);
      final responseAnalyzer = ResponseAnalyzer(resolver, schemaAnalyzer);
      final paginatedAnalyzer = EndpointAnalyzer(
        resolver,
        schemaAnalyzer,
        responseAnalyzer,
        paginationConfigs: paginationConfigs,
      );

      final result = paginatedAnalyzer.analyzeAll(spec.paths);
      final paginated =
          result.endpoints.firstWhere((e) => e.operationId == 'listPetsPaginated');

      expect(paginated.pagination, isNotNull);
      expect(paginated.pagination!.cursorParam, 'after');
      expect(paginated.pagination!.nextCursorField, 'nextCursor');
      expect(paginated.pagination!.itemsField, 'items');
      expect(paginated.pagination!.itemType.dartType, 'Pet');

      // Inline response → wrapper schema auto-generated
      expect(paginated.pagination!.wrapperSchema, isNotNull);
      expect(paginated.pagination!.wrapperSchema!.name, 'ListPetsPaginatedPage');
      expect(
          paginated.pagination!.wrapperSchema!.fields
              .any((f) => f.name == 'items'),
          isTrue);
      expect(
          paginated.pagination!.wrapperSchema!.fields
              .any((f) => f.name == 'nextCursor'),
          isTrue);

      // 200 response type should be the wrapper, not Map<String, dynamic>
      expect(paginated.responses[200]!.type!.dartType, 'ListPetsPaginatedPage');
    });

    test('pagination is null when cursor param does not exist', () {
      final paginationConfigs = [
        PaginationConfig(
          operationId: 'listPetsPaginated',
          cursorParam: 'nonexistent',
          nextCursorField: 'nextCursor',
          itemsField: 'items',
        ),
      ];
      final resolver = RefResolver(spec);
      final schemaAnalyzer = SchemaAnalyzer(resolver);
      final responseAnalyzer = ResponseAnalyzer(resolver, schemaAnalyzer);
      final paginatedAnalyzer = EndpointAnalyzer(
        resolver,
        schemaAnalyzer,
        responseAnalyzer,
        paginationConfigs: paginationConfigs,
      );

      final result = paginatedAnalyzer.analyzeAll(spec.paths);
      final paginated =
          result.endpoints.firstWhere((e) => e.operationId == 'listPetsPaginated');

      expect(paginated.pagination, isNull);
    });

    group('deprecated', () {
      test('reads deprecated flag on operation', () {
        final deprecatedSpec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths:
  /old:
    get:
      operationId: getOld
      deprecated: true
      tags:
        - test
      responses:
        "200":
          description: OK
components:
  schemas: {}
''');
        final resolver = RefResolver(deprecatedSpec);
        final schemaAnalyzer = SchemaAnalyzer(resolver);
        final responseAnalyzer = ResponseAnalyzer(resolver, schemaAnalyzer);
        final depAnalyzer = EndpointAnalyzer(resolver, schemaAnalyzer, responseAnalyzer);

        final result = depAnalyzer.analyzeAll(deprecatedSpec.paths);
        final endpoint = result.endpoints.firstWhere((e) => e.operationId == 'getOld');
        expect(endpoint.deprecated, isTrue);
      });

      test('reads deprecated flag on parameter', () {
        final deprecatedSpec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths:
  /items:
    get:
      operationId: listItems
      tags:
        - test
      parameters:
        - name: oldFilter
          in: query
          deprecated: true
          schema:
            type: string
      responses:
        "200":
          description: OK
components:
  schemas: {}
''');
        final resolver = RefResolver(deprecatedSpec);
        final schemaAnalyzer = SchemaAnalyzer(resolver);
        final responseAnalyzer = ResponseAnalyzer(resolver, schemaAnalyzer);
        final depAnalyzer = EndpointAnalyzer(resolver, schemaAnalyzer, responseAnalyzer);

        final result = depAnalyzer.analyzeAll(deprecatedSpec.paths);
        final endpoint = result.endpoints.first;
        final param = endpoint.parameters.firstWhere((p) => p.name == 'oldFilter');
        expect(param.deprecated, isTrue);
      });

      test('deprecated defaults to false', () {
        final result = analyzer.analyzeAll(spec.paths);
        final listPets = result.endpoints.firstWhere((e) => e.operationId == 'listPets');
        expect(listPets.deprecated, isFalse);
        for (final p in listPets.parameters) {
          expect(p.deprecated, isFalse);
        }
      });
    });

    test('non-matching endpoints remain without pagination', () {
      final paginationConfigs = [
        PaginationConfig(
          operationId: 'listPetsPaginated',
          cursorParam: 'after',
          nextCursorField: 'nextCursor',
          itemsField: 'items',
        ),
      ];
      final resolver = RefResolver(spec);
      final schemaAnalyzer = SchemaAnalyzer(resolver);
      final responseAnalyzer = ResponseAnalyzer(resolver, schemaAnalyzer);
      final paginatedAnalyzer = EndpointAnalyzer(
        resolver,
        schemaAnalyzer,
        responseAnalyzer,
        paginationConfigs: paginationConfigs,
      );

      final result = paginatedAnalyzer.analyzeAll(spec.paths);
      final listPets =
          result.endpoints.firstWhere((e) => e.operationId == 'listPets');
      final getPet =
          result.endpoints.firstWhere((e) => e.operationId == 'getPet');

      expect(listPets.pagination, isNull);
      expect(getPet.pagination, isNull);
    });
  });

  group('parameter name sanitization', () {
    late EndpointAnalyzer analyzer;

    setUp(() {
      final spec = SpecReader().readFile('test/fixtures/petstore.yaml');
      final resolver = RefResolver(spec);
      final schemaAnalyzer = SchemaAnalyzer(resolver);
      final responseAnalyzer = ResponseAnalyzer(resolver, schemaAnalyzer);
      analyzer = EndpointAnalyzer(resolver, schemaAnalyzer, responseAnalyzer);
    });

    test('sanitizes Dart reserved word parameter names', () {
      // Simulate a path with a parameter named 'in' (a Dart keyword)
      final paths = <String, v31.PathItem>{
        '/items': v31.PathItem(
          get: v31.Operation(
            operationId: 'listItems',
            responses: {
              '200': v31.Response(description: 'OK'),
            },
            parameters: [
              v31.Parameter(
                name: 'in',
                location: v31.ParameterLocation.query,
                schema: v31.Schema(type: 'string'),
              ),
              v31.Parameter(
                name: 'default',
                location: v31.ParameterLocation.query,
                schema: v31.Schema(type: 'string'),
              ),
            ],
          ),
        ),
      };

      final result = analyzer.analyzeAll(paths);
      final endpoint = result.endpoints.first;

      // 'in' → 'in_' (Dart keyword appended with underscore)
      final inParam = endpoint.parameters.firstWhere((p) => p.name == 'in');
      expect(inParam.dartName, 'in_');

      // 'default' → 'default_' (Dart keyword appended with underscore)
      final defaultParam =
          endpoint.parameters.firstWhere((p) => p.name == 'default');
      expect(defaultParam.dartName, 'default_');
    });
  });
}
