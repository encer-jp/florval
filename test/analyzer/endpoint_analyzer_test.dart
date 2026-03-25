import 'package:openapi_spec_plus/v31.dart' as v31;
import 'package:test/test.dart';
import 'package:florval/src/analyzer/endpoint_analyzer.dart';
import 'package:florval/src/analyzer/response_analyzer.dart';
import 'package:florval/src/analyzer/schema_analyzer.dart';
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
      final endpoints = analyzer.analyzeAll(spec.paths);
      // GET /pets, POST /pets, GET /pets/{petId}, PUT /pets/{petId}, DELETE /pets/{petId}
      expect(endpoints.length, 5);
    });

    test('parses GET /pets correctly', () {
      final endpoints = analyzer.analyzeAll(spec.paths);
      final listPets =
          endpoints.firstWhere((e) => e.operationId == 'listPets');

      expect(listPets.path, '/pets');
      expect(listPets.method, 'GET');
      expect(listPets.tags, ['pets']);
      expect(listPets.queryParameters.length, 2);
      expect(listPets.pathParameters, isEmpty);
    });

    test('parses path parameters', () {
      final endpoints = analyzer.analyzeAll(spec.paths);
      final getPet = endpoints.firstWhere((e) => e.operationId == 'getPet');

      expect(getPet.pathParameters.length, 1);
      expect(getPet.pathParameters.first.name, 'petId');
      expect(getPet.pathParameters.first.location, ParamLocation.path);
      expect(getPet.pathParameters.first.type.dartType, 'int');
      expect(getPet.pathParameters.first.isRequired, isTrue);
    });

    test('parses query parameters', () {
      final endpoints = analyzer.analyzeAll(spec.paths);
      final listPets =
          endpoints.firstWhere((e) => e.operationId == 'listPets');

      final limitParam =
          listPets.queryParameters.firstWhere((p) => p.name == 'limit');
      expect(limitParam.type.dartType, 'int');
      expect(limitParam.isRequired, isFalse);
    });

    test('parses request body', () {
      final endpoints = analyzer.analyzeAll(spec.paths);
      final createPet =
          endpoints.firstWhere((e) => e.operationId == 'createPet');

      expect(createPet.requestBody, isNotNull);
      expect(createPet.requestBody!.type.dartType, 'CreatePetRequest');
      expect(createPet.requestBody!.isRequired, isTrue);
    });

    test('parses responses with status codes', () {
      final endpoints = analyzer.analyzeAll(spec.paths);
      final listPets =
          endpoints.firstWhere((e) => e.operationId == 'listPets');

      expect(listPets.responses.containsKey(200), isTrue);
      expect(listPets.responses.containsKey(400), isTrue);
      expect(listPets.responses.containsKey(500), isTrue);

      expect(listPets.responses[200]!.type?.isList, isTrue);
      expect(listPets.responses[200]!.type?.itemType?.dartType, 'Pet');
    });

    test('handles responses without body', () {
      final endpoints = analyzer.analyzeAll(spec.paths);
      final getPet = endpoints.firstWhere((e) => e.operationId == 'getPet');

      expect(getPet.responses[404]!.type, isNull);
      expect(getPet.responses[404]!.hasBody, isFalse);
    });

    test('handles DELETE with no-body responses', () {
      final endpoints = analyzer.analyzeAll(spec.paths);
      final deletePet =
          endpoints.firstWhere((e) => e.operationId == 'deletePet');

      expect(deletePet.responses[204]!.hasBody, isFalse);
      expect(deletePet.responses[404]!.hasBody, isFalse);
    });
  });
}
