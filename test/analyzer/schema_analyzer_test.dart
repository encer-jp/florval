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

    test('detects enum schemas', () {
      final enumSpec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    GenderEnum:
      type: string
      enum:
        - male
        - female
      description: Gender
''');
      final enumAnalyzer = SchemaAnalyzer(RefResolver(enumSpec));
      final schema = enumAnalyzer.analyze(
        'GenderEnum',
        enumSpec.components!.schemas!['GenderEnum']!,
      );

      expect(schema.isEnum, isTrue);
      expect(schema.enumValues, ['male', 'female']);
      expect(schema.fields, isEmpty);
    });

    test('resolves allOf with single \$ref to the referenced type', () {
      final allOfSpec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    GenderEnum:
      type: string
      enum:
        - male
        - female
    User:
      type: object
      required:
        - gender
      properties:
        gender:
          allOf:
            - \$ref: '#/components/schemas/GenderEnum'
''');
      final allOfAnalyzer = SchemaAnalyzer(RefResolver(allOfSpec));
      final user = allOfAnalyzer.analyze(
        'User',
        allOfSpec.components!.schemas!['User']!,
      );

      final genderField = user.fields.firstWhere((f) => f.name == 'gender');
      expect(genderField.type.dartType, 'GenderEnum');
      expect(genderField.type.ref, contains('GenderEnum'));
      expect(genderField.type.isEnum, isTrue);
    });

    test('preserves jsonKey for field name mapping', () {
      final pet = analyzer.analyze('Pet', spec.components!.schemas!['Pet']!);
      final createdAt = pet.fields.firstWhere((f) => f.name == 'createdAt');
      expect(createdAt.jsonKey, 'createdAt');
    });

    test('handles non-ASCII (Japanese) field names', () {
      final japaneseSpec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    Record:
      type: object
      properties:
        レコード番号:
          type: string
        名前:
          type: string
''');
      final japaneseAnalyzer = SchemaAnalyzer(RefResolver(japaneseSpec));
      final schema = japaneseAnalyzer.analyze(
        'Record',
        japaneseSpec.components!.schemas!['Record']!,
      );

      expect(schema.fields.length, 2);
      // Fields should have fallback names
      expect(schema.fields[0].name, 'field0');
      expect(schema.fields[0].jsonKey, 'レコード番号');
      expect(schema.fields[1].name, 'field1');
      expect(schema.fields[1].jsonKey, '名前');
    });

    test('handles mixed ASCII and non-ASCII field names with collision', () {
      final mixedSpec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    MixedRecord:
      type: object
      properties:
        bmi:
          type: number
        BMI値:
          type: number
        name:
          type: string
''');
      final mixedAnalyzer = SchemaAnalyzer(RefResolver(mixedSpec));
      final schema = mixedAnalyzer.analyze(
        'MixedRecord',
        mixedSpec.components!.schemas!['MixedRecord']!,
      );

      expect(schema.fields.length, 3);
      expect(schema.fields[0].name, 'bmi');
      expect(schema.fields[0].jsonKey, 'bmi');
      // 'BMI値' strips to 'bmi' which collides → 'bmi1'
      expect(schema.fields[1].name, 'bmi1');
      expect(schema.fields[1].jsonKey, 'BMI値');
      expect(schema.fields[2].name, 'name');
    });

    test('resolves anyOf nullable \$ref to nullable type', () {
      final anyOfSpec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    User:
      type: object
      properties:
        name:
          type: string
    Task:
      type: object
      required:
        - title
      properties:
        title:
          type: string
        assignee:
          anyOf:
            - \$ref: '#/components/schemas/User'
            - type: "null"
''');
      final anyOfAnalyzer = SchemaAnalyzer(RefResolver(anyOfSpec));
      final task = anyOfAnalyzer.analyze(
        'Task',
        anyOfSpec.components!.schemas!['Task']!,
      );

      final assignee = task.fields.firstWhere((f) => f.name == 'assignee');
      expect(assignee.type.dartType, 'User?');
      expect(assignee.type.isNullable, isTrue);
      expect(assignee.type.ref, isNotNull);
      expect(assignee.type.ref, contains('User'));
    });

    test('resolves oneOf nullable \$ref to nullable type', () {
      final oneOfSpec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    User:
      type: object
      properties:
        name:
          type: string
    Task:
      type: object
      required:
        - title
      properties:
        title:
          type: string
        assignee:
          oneOf:
            - \$ref: '#/components/schemas/User'
            - type: "null"
''');
      final oneOfAnalyzer = SchemaAnalyzer(RefResolver(oneOfSpec));
      final task = oneOfAnalyzer.analyze(
        'Task',
        oneOfSpec.components!.schemas!['Task']!,
      );

      final assignee = task.fields.firstWhere((f) => f.name == 'assignee');
      expect(assignee.type.dartType, 'User?');
      expect(assignee.type.isNullable, isTrue);
      expect(assignee.type.ref, isNotNull);
    });

    test('anyOf nullable \$ref is not primitive', () {
      final anyOfSpec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    User:
      type: object
      properties:
        name:
          type: string
    Task:
      type: object
      properties:
        assignee:
          anyOf:
            - \$ref: '#/components/schemas/User'
            - type: "null"
''');
      final anyOfAnalyzer = SchemaAnalyzer(RefResolver(anyOfSpec));
      final task = anyOfAnalyzer.analyze(
        'Task',
        anyOfSpec.components!.schemas!['Task']!,
      );

      final assignee = task.fields.firstWhere((f) => f.name == 'assignee');
      expect(assignee.type.isPrimitive, isFalse);
    });

    test('anyOf nullable \$ref preserves isEnum for enum references', () {
      final enumSpec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    Status:
      type: string
      enum:
        - active
        - inactive
    Task:
      type: object
      properties:
        status:
          anyOf:
            - \$ref: '#/components/schemas/Status'
            - type: "null"
''');
      final enumAnalyzer = SchemaAnalyzer(RefResolver(enumSpec));
      final task = enumAnalyzer.analyze(
        'Task',
        enumSpec.components!.schemas!['Task']!,
      );

      final status = task.fields.firstWhere((f) => f.name == 'status');
      expect(status.type.dartType, 'Status?');
      expect(status.type.isNullable, isTrue);
      expect(status.type.isEnum, isTrue);
    });

    test('anyOf with 3+ elements does not use nullable \$ref shortcut', () {
      final unionSpec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    User:
      type: object
      properties:
        name:
          type: string
    Group:
      type: object
      properties:
        groupName:
          type: string
    Task:
      type: object
      properties:
        assignee:
          anyOf:
            - \$ref: '#/components/schemas/User'
            - \$ref: '#/components/schemas/Group'
            - type: "null"
''');
      final unionAnalyzer = SchemaAnalyzer(RefResolver(unionSpec));
      final task = unionAnalyzer.analyze(
        'Task',
        unionSpec.components!.schemas!['Task']!,
      );

      final assignee = task.fields.firstWhere((f) => f.name == 'assignee');
      // Should NOT be 'User?' — this is a true union, not a nullable $ref
      expect(assignee.type.dartType, isNot('User?'));
      expect(assignee.type.dartType, isNot('Group?'));
    });

    test('3-element anyOf (2 \$ref + null) generates inline union type', () {
      final unionSpec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    User:
      type: object
      properties:
        name:
          type: string
    Group:
      type: object
      properties:
        groupName:
          type: string
    Task:
      type: object
      properties:
        owner:
          anyOf:
            - \$ref: '#/components/schemas/User'
            - \$ref: '#/components/schemas/Group'
            - type: "null"
''');
      final unionAnalyzer = SchemaAnalyzer(RefResolver(unionSpec));
      final task = unionAnalyzer.analyze(
        'Task',
        unionSpec.components!.schemas!['Task']!,
      );

      final owner = task.fields.firstWhere((f) => f.name == 'owner');
      expect(owner.type.dartType, 'TaskOwner?');
      expect(owner.type.isNullable, isTrue);
      expect(owner.type.ref, isNotNull);

      // Should have registered one inline union schema
      expect(unionAnalyzer.inlineUnionSchemas, hasLength(1));
      final unionSchema = unionAnalyzer.inlineUnionSchemas.first;
      expect(unionSchema.name, 'TaskOwner');
      // Should have 2 variants (User and Group), null element excluded
      expect(unionSchema.anyOf, isNotNull);
      expect(unionSchema.anyOf, hasLength(2));
      expect(unionSchema.anyOf!.map((v) => v.name).toSet(),
          {'User', 'Group'});
    });

    test('2-element oneOf (2 \$ref, no null) generates inline union type', () {
      final unionSpec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    User:
      type: object
      properties:
        name:
          type: string
    Group:
      type: object
      properties:
        groupName:
          type: string
    Task:
      type: object
      properties:
        target:
          oneOf:
            - \$ref: '#/components/schemas/User'
            - \$ref: '#/components/schemas/Group'
''');
      final unionAnalyzer = SchemaAnalyzer(RefResolver(unionSpec));
      final task = unionAnalyzer.analyze(
        'Task',
        unionSpec.components!.schemas!['Task']!,
      );

      final target = task.fields.firstWhere((f) => f.name == 'target');
      expect(target.type.dartType, 'TaskTarget?');
      // Not required, so nullable due to _extractFields logic
      expect(target.type.isNullable, isTrue);
      expect(target.type.ref, isNotNull);

      expect(unionAnalyzer.inlineUnionSchemas, hasLength(1));
      final unionSchema = unionAnalyzer.inlineUnionSchemas.first;
      expect(unionSchema.name, 'TaskTarget');
      expect(unionSchema.oneOf, isNotNull);
      expect(unionSchema.oneOf, hasLength(2));
    });

    test('anyOf with primitive + null does not create inline union', () {
      final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    Task:
      type: object
      required:
        - label
      properties:
        label:
          anyOf:
            - type: string
            - type: "null"
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      final task = analyzer.analyze(
        'Task',
        spec.components!.schemas!['Task']!,
      );

      final label = task.fields.firstWhere((f) => f.name == 'label');
      // anyOf with 1 non-null element that is NOT a $ref falls through
      // to _extractType — no inline union should be registered
      expect(analyzer.inlineUnionSchemas, isEmpty);
      // Should not be a union type name
      expect(label.type.dartType, isNot('TaskLabel'));
    });

    test('inline union naming uses contextName from parent schema + field', () {
      final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    Dog:
      type: object
      properties:
        breed:
          type: string
    Cat:
      type: object
      properties:
        color:
          type: string
    Pet:
      type: object
      properties:
        animal:
          oneOf:
            - \$ref: '#/components/schemas/Dog'
            - \$ref: '#/components/schemas/Cat'
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      analyzer.analyze('Pet', spec.components!.schemas!['Pet']!);

      expect(analyzer.inlineUnionSchemas, hasLength(1));
      expect(analyzer.inlineUnionSchemas.first.name, 'PetAnimal');
    });

    test('multiple inline union fields in same schema have unique names', () {
      final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    User:
      type: object
      properties:
        name:
          type: string
    Group:
      type: object
      properties:
        groupName:
          type: string
    Bot:
      type: object
      properties:
        botId:
          type: string
    Task:
      type: object
      properties:
        owner:
          anyOf:
            - \$ref: '#/components/schemas/User'
            - \$ref: '#/components/schemas/Group'
        reviewer:
          oneOf:
            - \$ref: '#/components/schemas/User'
            - \$ref: '#/components/schemas/Bot'
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      analyzer.analyze('Task', spec.components!.schemas!['Task']!);

      expect(analyzer.inlineUnionSchemas, hasLength(2));
      final names = analyzer.inlineUnionSchemas.map((s) => s.name).toSet();
      expect(names, {'TaskOwner', 'TaskReviewer'});
    });
  });
}
