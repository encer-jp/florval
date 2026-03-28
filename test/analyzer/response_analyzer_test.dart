import 'package:test/test.dart';
import 'package:florval/src/analyzer/response_analyzer.dart';
import 'package:florval/src/analyzer/schema_analyzer.dart';
import 'package:florval/src/parser/ref_resolver.dart';
import 'package:florval/src/parser/spec_reader.dart';

void main() {
  group('ResponseAnalyzer', () {
    test('nullable anyOf response body returns nullable \$ref, not union', () {
      final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths:
  /tasks/{id}:
    get:
      operationId: getTask
      responses:
        "200":
          description: Success
          content:
            application/json:
              schema:
                anyOf:
                  - \$ref: '#/components/schemas/User'
                  - type: "null"
components:
  schemas:
    User:
      type: object
      properties:
        name:
          type: string
''');
      final resolver = RefResolver(spec);
      final schemaAnalyzer = SchemaAnalyzer(resolver);
      final responseAnalyzer = ResponseAnalyzer(resolver, schemaAnalyzer);

      final responses = spec.paths['/tasks/{id}']!.get!.responses;
      final result = responseAnalyzer.analyzeResponses(
        responses,
        operationId: 'getTask',
      );

      final type200 = result.responses[200]!.type!;
      expect(type200.dartType, 'User?');
      expect(type200.isNullable, isTrue);
      expect(type200.ref, contains('User'));
      // Should NOT have generated any inline union schemas
      expect(result.inlineUnionSchemas, isEmpty);
    });

    test(
      'oneOf with multiple \$refs in response body generates inline union',
      () {
        final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths:
  /items/{id}:
    get:
      operationId: getItem
      responses:
        "200":
          description: Success
          content:
            application/json:
              schema:
                oneOf:
                  - \$ref: '#/components/schemas/Book'
                  - \$ref: '#/components/schemas/Movie'
components:
  schemas:
    Book:
      type: object
      properties:
        title:
          type: string
    Movie:
      type: object
      properties:
        director:
          type: string
''');
        final resolver = RefResolver(spec);
        final schemaAnalyzer = SchemaAnalyzer(resolver);
        final responseAnalyzer = ResponseAnalyzer(resolver, schemaAnalyzer);

        final responses = spec.paths['/items/{id}']!.get!.responses;
        final result = responseAnalyzer.analyzeResponses(
          responses,
          operationId: 'getItem',
        );

        final type200 = result.responses[200]!.type!;
        // Should be an inline union type (via inlineUnionSchemas in result)
        expect(type200.ref, isNotNull);
        expect(result.inlineUnionSchemas, hasLength(1));
      },
    );

    test('simple \$ref response body returns the referenced type', () {
      final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths:
  /users/{id}:
    get:
      operationId: getUser
      responses:
        "200":
          description: Success
          content:
            application/json:
              schema:
                \$ref: '#/components/schemas/User'
components:
  schemas:
    User:
      type: object
      properties:
        name:
          type: string
''');
      final resolver = RefResolver(spec);
      final schemaAnalyzer = SchemaAnalyzer(resolver);
      final responseAnalyzer = ResponseAnalyzer(resolver, schemaAnalyzer);

      final responses = spec.paths['/users/{id}']!.get!.responses;
      final result = responseAnalyzer.analyzeResponses(
        responses,
        operationId: 'getUser',
      );

      final type200 = result.responses[200]!.type!;
      expect(type200.dartType, 'User');
      expect(type200.ref, contains('User'));
    });
  });
}
