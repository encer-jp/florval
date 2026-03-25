import 'package:openapi_spec_plus/v31.dart' as v31;
import 'package:test/test.dart';
import 'package:florval/src/parser/ref_resolver.dart';
import 'package:florval/src/parser/spec_reader.dart';

v31.Schema _refSchema(String refPath) => v31.Schema(ref: refPath);

void main() {
  group('RefResolver', () {
    late v31.OpenAPI spec;
    late RefResolver resolver;

    setUp(() {
      spec = SpecReader().readFile('test/fixtures/petstore.yaml');
      resolver = RefResolver(spec);
    });

    test('resolves a direct schema \$ref', () {
      final schema = _refSchema('#/components/schemas/Pet');
      final resolved = resolver.resolveSchema(schema);

      expect(resolved.ref, isNull);
      expect(resolved.properties, isNotNull);
      expect(resolved.properties!.containsKey('id'), isTrue);
      expect(resolved.properties!.containsKey('name'), isTrue);
    });

    test('returns non-ref schema unchanged', () {
      final schema = v31.Schema.string();
      final result = resolver.resolveSchema(schema);

      expect(identical(result, schema), isTrue);
    });

    test('extracts schema name from \$ref', () {
      final schema = _refSchema('#/components/schemas/User');
      expect(resolver.schemaName(schema), 'User');
    });

    test('returns null name for non-ref schema', () {
      final schema = v31.Schema.string();
      expect(resolver.schemaName(schema), isNull);
    });

    test('throws on unresolvable \$ref', () {
      final schema = _refSchema('#/components/schemas/NonExistent');
      expect(
        () => resolver.resolveSchema(schema),
        throwsA(isA<RefResolveException>()),
      );
    });

    test('detects circular references without throwing', () {
      final circularSpec = v31.OpenAPI(
        openapi: '3.1.0',
        info: v31.Info(title: 'test', version: '1.0'),
        paths: {},
        components: v31.Components(
          schemas: {
            'A': _refSchema('#/components/schemas/B'),
            'B': _refSchema('#/components/schemas/A'),
          },
        ),
      );
      final circularResolver = RefResolver(circularSpec);

      final refA = _refSchema('#/components/schemas/A');
      final result = circularResolver.resolveSchema(refA);
      expect(result.ref, isNotNull);
    });

    test('resolves nested \$ref in schema properties', () {
      final pet = spec.components!.schemas!['Pet']!;
      final categoryRef = pet.properties!['category']!;

      expect(categoryRef.ref, isNotNull);

      final resolved = resolver.resolveSchema(categoryRef);
      expect(resolved.properties, isNotNull);
      expect(resolved.properties!.containsKey('id'), isTrue);
      expect(resolved.properties!.containsKey('name'), isTrue);
    });
  });
}
