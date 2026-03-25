import 'package:openapi_spec_plus/v31.dart' as v31;
import 'package:test/test.dart';
import 'package:florval/src/analyzer/schema_analyzer.dart';
import 'package:florval/src/parser/ref_resolver.dart';
import 'package:florval/src/parser/spec_reader.dart';

void main() {
  group('SchemaAnalyzer', () {
    late v31.OpenAPI spec;
    late SchemaAnalyzer analyzer;

    setUp(() {
      spec = SpecReader().readFile('test/fixtures/petstore.yaml');
      analyzer = SchemaAnalyzer(RefResolver(spec));
    });

    test('analyzes Pet schema', () {
      final pet = analyzer.analyze('Pet', spec.components!.schemas!['Pet']!);

      expect(pet.name, 'Pet');
      expect(pet.fields.length, 5); // id, name, tag, category, createdAt

      final idField = pet.fields.firstWhere((f) => f.name == 'id');
      expect(idField.type.dartType, 'int');
      expect(idField.isRequired, isTrue);

      final nameField = pet.fields.firstWhere((f) => f.name == 'name');
      expect(nameField.type.dartType, 'String');
      expect(nameField.isRequired, isTrue);

      final tagField = pet.fields.firstWhere((f) => f.name == 'tag');
      expect(tagField.type.dartType, 'String?');
      expect(tagField.isRequired, isFalse);
    });

    test('handles \$ref fields', () {
      final pet = analyzer.analyze('Pet', spec.components!.schemas!['Pet']!);
      final categoryField =
          pet.fields.firstWhere((f) => f.name == 'category');

      expect(categoryField.type.dartType, 'Category?');
      expect(categoryField.type.ref != null, isTrue);
      expect(categoryField.isRequired, isFalse);
    });

    test('handles DateTime format', () {
      final pet = analyzer.analyze('Pet', spec.components!.schemas!['Pet']!);
      final createdAt = pet.fields.firstWhere((f) => f.name == 'createdAt');

      expect(createdAt.type.dartType, 'DateTime?');
      expect(createdAt.isRequired, isFalse);
    });

    test('handles array of \$ref', () {
      final schema =
          analyzer.analyze('ValidationError', spec.components!.schemas!['ValidationError']!);
      final errorsField = schema.fields.firstWhere((f) => f.name == 'errors');

      expect(errorsField.type.isList, isTrue);
      expect(errorsField.type.itemType?.dartType, 'FieldError');
      expect(errorsField.isRequired, isTrue);
    });

    test('maps OpenAPI types to Dart types', () {
      expect(
        analyzer.schemaToType(v31.Schema.string()).dartType,
        'String',
      );
      expect(
        analyzer.schemaToType(v31.Schema.integer()).dartType,
        'int',
      );
      expect(
        analyzer.schemaToType(v31.Schema.number()).dartType,
        'double',
      );
      expect(
        analyzer.schemaToType(v31.Schema.boolean()).dartType,
        'bool',
      );
    });

    test('handles nullable types', () {
      final nullable = v31.Schema.nullableString();
      final type = analyzer.schemaToType(nullable);
      expect(type.isNullable, isTrue);
      expect(type.dartType, 'String?');
    });

    test('handles array type', () {
      final arraySchema = v31.Schema.array(items: v31.Schema.string());
      final type = analyzer.schemaToType(arraySchema);
      expect(type.isList, isTrue);
      expect(type.dartType, 'List<String>');
      expect(type.itemType?.dartType, 'String');
    });

    test('handles object without properties as Map', () {
      final objSchema = v31.Schema.object();
      final type = analyzer.schemaToType(objSchema);
      expect(type.dartType, 'Map<String, dynamic>');
    });

    test('analyzes all schemas', () {
      final schemas = analyzer.analyzeAll(spec.components!.schemas!);
      expect(schemas.length, 6); // Pet, Category, CreatePetRequest, Error, ValidationError, FieldError
      expect(schemas.map((s) => s.name).toSet(),
          {'Pet', 'Category', 'CreatePetRequest', 'Error', 'ValidationError', 'FieldError'});
    });

    test('preserves jsonKey for field name mapping', () {
      final pet = analyzer.analyze('Pet', spec.components!.schemas!['Pet']!);
      final createdAt = pet.fields.firstWhere((f) => f.name == 'createdAt');
      expect(createdAt.jsonKey, 'createdAt');
    });
  });
}
