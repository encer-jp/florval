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
      final result = analyzer.analyze('Pet', spec.components!.schemas!['Pet']!);
      final pet = result.schema;

      expect(pet.name, 'Pet');
      expect(pet.fields.length, 6); // id, name, tag, category, createdAt, legacyCode

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
      final result = analyzer.analyze('Pet', spec.components!.schemas!['Pet']!);
      final pet = result.schema;
      final categoryField =
          pet.fields.firstWhere((f) => f.name == 'category');

      expect(categoryField.type.dartType, 'Category?');
      expect(categoryField.type.ref != null, isTrue);
      expect(categoryField.isRequired, isFalse);
    });

    test('handles DateTime format', () {
      final result = analyzer.analyze('Pet', spec.components!.schemas!['Pet']!);
      final pet = result.schema;
      final createdAt = pet.fields.firstWhere((f) => f.name == 'createdAt');

      expect(createdAt.type.dartType, 'DateTime?');
      expect(createdAt.isRequired, isFalse);
    });

    test('handles array of \$ref', () {
      final result =
          analyzer.analyze('ValidationError', spec.components!.schemas!['ValidationError']!);
      final schema = result.schema;
      final errorsField = schema.fields.firstWhere((f) => f.name == 'errors');

      expect(errorsField.type.isList, isTrue);
      expect(errorsField.type.itemType?.dartType, 'FieldError');
      expect(errorsField.isRequired, isTrue);
    });

    test('maps OpenAPI types to Dart types', () {
      expect(
        analyzer.schemaToType(v31.Schema.string()).type.dartType,
        'String',
      );
      expect(
        analyzer.schemaToType(v31.Schema.integer()).type.dartType,
        'int',
      );
      expect(
        analyzer.schemaToType(v31.Schema.number()).type.dartType,
        'double',
      );
      expect(
        analyzer.schemaToType(v31.Schema.boolean()).type.dartType,
        'bool',
      );
    });

    test('handles nullable types', () {
      final nullable = v31.Schema.nullableString();
      final result = analyzer.schemaToType(nullable);
      expect(result.type.isNullable, isTrue);
      expect(result.type.dartType, 'String?');
    });

    test('handles array type', () {
      final arraySchema = v31.Schema.array(items: v31.Schema.string());
      final result = analyzer.schemaToType(arraySchema);
      expect(result.type.isList, isTrue);
      expect(result.type.dartType, 'List<String>');
      expect(result.type.itemType?.dartType, 'String');
    });

    test('handles object without properties as Map', () {
      final objSchema = v31.Schema.object();
      final result = analyzer.schemaToType(objSchema);
      expect(result.type.dartType, 'Map<String, dynamic>');
    });

    test('analyzes all schemas', () {
      final result = analyzer.analyzeAll(spec.components!.schemas!);
      expect(result.schemas.length, 6); // Pet, Category, CreatePetRequest, Error, ValidationError, FieldError
      expect(result.schemas.map((s) => s.name).toSet(),
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
      final result = enumAnalyzer.analyze(
        'GenderEnum',
        enumSpec.components!.schemas!['GenderEnum']!,
      );

      expect(result.schema.isEnum, isTrue);
      expect(result.schema.enumValues, ['male', 'female']);
      expect(result.schema.fields, isEmpty);
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
      final result = allOfAnalyzer.analyze(
        'User',
        allOfSpec.components!.schemas!['User']!,
      );
      final user = result.schema;

      final genderField = user.fields.firstWhere((f) => f.name == 'gender');
      expect(genderField.type.dartType, 'GenderEnum');
      expect(genderField.type.ref, contains('GenderEnum'));
      expect(genderField.type.isEnum, isTrue);
    });

    test('preserves jsonKey for field name mapping', () {
      final result = analyzer.analyze('Pet', spec.components!.schemas!['Pet']!);
      final pet = result.schema;
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
      final result = japaneseAnalyzer.analyze(
        'Record',
        japaneseSpec.components!.schemas!['Record']!,
      );
      final schema = result.schema;

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
      final result = mixedAnalyzer.analyze(
        'MixedRecord',
        mixedSpec.components!.schemas!['MixedRecord']!,
      );
      final schema = result.schema;

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
      final result = anyOfAnalyzer.analyze(
        'Task',
        anyOfSpec.components!.schemas!['Task']!,
      );
      final task = result.schema;

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
      final result = oneOfAnalyzer.analyze(
        'Task',
        oneOfSpec.components!.schemas!['Task']!,
      );
      final task = result.schema;

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
      final result = anyOfAnalyzer.analyze(
        'Task',
        anyOfSpec.components!.schemas!['Task']!,
      );
      final task = result.schema;

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
      final result = enumAnalyzer.analyze(
        'Task',
        enumSpec.components!.schemas!['Task']!,
      );
      final task = result.schema;

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
      final result = unionAnalyzer.analyze(
        'Task',
        unionSpec.components!.schemas!['Task']!,
      );
      final task = result.schema;

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
      final result = unionAnalyzer.analyze(
        'Task',
        unionSpec.components!.schemas!['Task']!,
      );
      final task = result.schema;

      final owner = task.fields.firstWhere((f) => f.name == 'owner');
      expect(owner.type.dartType, 'TaskOwner?');
      expect(owner.type.isNullable, isTrue);
      expect(owner.type.ref, isNotNull);

      // Should have registered one inline union schema
      expect(result.inlineUnionSchemas, hasLength(1));
      final unionSchema = result.inlineUnionSchemas.first;
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
      final result = unionAnalyzer.analyze(
        'Task',
        unionSpec.components!.schemas!['Task']!,
      );
      final task = result.schema;

      final target = task.fields.firstWhere((f) => f.name == 'target');
      expect(target.type.dartType, 'TaskTarget?');
      // Not required, so nullable due to _extractFields logic
      expect(target.type.isNullable, isTrue);
      expect(target.type.ref, isNotNull);

      expect(result.inlineUnionSchemas, hasLength(1));
      final unionSchema = result.inlineUnionSchemas.first;
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
      final result = analyzer.analyze(
        'Task',
        spec.components!.schemas!['Task']!,
      );

      final label = result.schema.fields.firstWhere((f) => f.name == 'label');
      // anyOf with 1 non-null element that is NOT a $ref falls through
      // to _extractType — no inline union should be registered
      expect(result.inlineUnionSchemas, isEmpty);
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
      final result = analyzer.analyze('Pet', spec.components!.schemas!['Pet']!);

      expect(result.inlineUnionSchemas, hasLength(1));
      expect(result.inlineUnionSchemas.first.name, 'PetAnimal');
    });

    test('inline object with properties generates typed class', () {
      final inlineSpec = SpecReader().parse('''
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
        - title
      properties:
        title:
          type: string
        metadata:
          type: object
          properties:
            key:
              type: string
            value:
              type: string
''');
      final inlineAnalyzer = SchemaAnalyzer(RefResolver(inlineSpec));
      final result = inlineAnalyzer.analyze(
        'Task',
        inlineSpec.components!.schemas!['Task']!,
      );
      final task = result.schema;

      final metadata = task.fields.firstWhere((f) => f.name == 'metadata');
      expect(metadata.type.dartType, 'TaskMetadata?');
      expect(metadata.type.ref, isNotNull);

      // Should have registered one inline object schema
      expect(result.inlineObjectSchemas, hasLength(1));
      final inlineSchema = result.inlineObjectSchemas.first;
      expect(inlineSchema.name, 'TaskMetadata');
      expect(inlineSchema.fields, hasLength(2));
      expect(inlineSchema.fields.map((f) => f.name).toSet(), {'key', 'value'});
    });

    test('object without properties stays as Map<String, dynamic>', () {
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
      properties:
        extra:
          type: object
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      final result = analyzer.analyze(
        'Task',
        spec.components!.schemas!['Task']!,
      );

      final extra = result.schema.fields.firstWhere((f) => f.name == 'extra');
      expect(extra.type.dartType, 'Map<String, dynamic>?');
      expect(result.inlineObjectSchemas, isEmpty);
    });

    test('nested inline objects are recursively named', () {
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
      properties:
        config:
          type: object
          properties:
            display:
              type: object
              properties:
                color:
                  type: string
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      final result = analyzer.analyze(
        'Task',
        spec.components!.schemas!['Task']!,
      );

      final config = result.schema.fields.firstWhere((f) => f.name == 'config');
      expect(config.type.dartType, 'TaskConfig?');

      // Should have 2 inline object schemas: TaskConfig and TaskConfigDisplay
      expect(result.inlineObjectSchemas, hasLength(2));
      final names = result.inlineObjectSchemas.map((s) => s.name).toSet();
      expect(names, {'TaskConfig', 'TaskConfigDisplay'});
    });

    test('additionalProperties with type string generates Map<String, String>', () {
      final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    Config:
      type: object
      properties:
        headers:
          type: object
          additionalProperties:
            type: string
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      final result = analyzer.analyze(
        'Config',
        spec.components!.schemas!['Config']!,
      );

      final headers = result.schema.fields.firstWhere((f) => f.name == 'headers');
      expect(headers.type.dartType, 'Map<String, String>?');
    });

    test('additionalProperties with type integer generates Map<String, int>', () {
      final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    Scores:
      type: object
      additionalProperties:
        type: integer
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      final result = analyzer.schemaToType(
        spec.components!.schemas!['Scores']!,
      );

      expect(result.type.dartType, 'Map<String, int>');
    });

    test('additionalProperties with \$ref generates Map<String, RefType>', () {
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
    UserMap:
      type: object
      additionalProperties:
        \$ref: '#/components/schemas/User'
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      final result = analyzer.schemaToType(
        spec.components!.schemas!['UserMap']!,
      );

      expect(result.type.dartType, 'Map<String, User>');
    });

    test('additionalProperties true generates Map<String, dynamic>', () {
      final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    Metadata:
      type: object
      additionalProperties: true
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      final result = analyzer.schemaToType(
        spec.components!.schemas!['Metadata']!,
      );

      expect(result.type.dartType, 'Map<String, dynamic>');
    });

    test('additionalProperties with properties present prioritizes properties', () {
      final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    Mixed:
      type: object
      properties:
        name:
          type: string
      additionalProperties:
        type: string
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      final result = analyzer.analyze(
        'Mixed',
        spec.components!.schemas!['Mixed']!,
      );

      // Properties take precedence; additionalProperties is ignored
      expect(result.schema.fields, hasLength(1));
      expect(result.schema.fields.first.name, 'name');
    });

    test('type unspecified with no composition returns dynamic', () {
      final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    Anything:
      description: "No type specified"
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      final result = analyzer.schemaToType(
        spec.components!.schemas!['Anything']!,
      );

      expect(result.type.dartType, 'dynamic');
    });

    test('type object without properties still generates Map<String, dynamic>', () {
      final objSchema = v31.Schema.object();
      final result = analyzer.schemaToType(objSchema);
      expect(result.type.dartType, 'Map<String, dynamic>');
    });

    test('generates inline enum for string property with enum values', () {
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
        - status
      properties:
        status:
          type: string
          enum:
            - todo
            - in_progress
            - done
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      final result = analyzer.analyze(
        'Task',
        spec.components!.schemas!['Task']!,
      );
      final task = result.schema;

      final status = task.fields.firstWhere((f) => f.name == 'status');
      expect(status.type.dartType, 'TaskStatus');
      expect(status.type.isEnum, isTrue);
      expect(status.type.ref, contains('TaskStatus'));

      expect(result.inlineEnumSchemas, hasLength(1));
      final enumSchema = result.inlineEnumSchemas.first;
      expect(enumSchema.name, 'TaskStatus');
      expect(enumSchema.isEnum, isTrue);
      expect(enumSchema.enumValues, ['todo', 'in_progress', 'done']);
    });

    test('generates inline enum for nullable string enum', () {
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
      properties:
        priority:
          type:
            - string
            - "null"
          enum:
            - low
            - medium
            - high
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      final result = analyzer.analyze(
        'Task',
        spec.components!.schemas!['Task']!,
      );
      final task = result.schema;

      final priority = task.fields.firstWhere((f) => f.name == 'priority');
      expect(priority.type.dartType, 'TaskPriority?');
      expect(priority.type.isNullable, isTrue);
      expect(priority.type.isEnum, isTrue);

      expect(result.inlineEnumSchemas, hasLength(1));
      expect(result.inlineEnumSchemas.first.name, 'TaskPriority');
    });

    test('generates inline enum for integer enum', () {
      final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    Config:
      type: object
      required:
        - level
      properties:
        level:
          type: integer
          enum:
            - 1
            - 2
            - 3
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      final result = analyzer.analyze(
        'Config',
        spec.components!.schemas!['Config']!,
      );
      final config = result.schema;

      final level = config.fields.firstWhere((f) => f.name == 'level');
      expect(level.type.dartType, 'ConfigLevel');
      expect(level.type.isEnum, isTrue);

      expect(result.inlineEnumSchemas, hasLength(1));
      final enumSchema = result.inlineEnumSchemas.first;
      expect(enumSchema.name, 'ConfigLevel');
      expect(enumSchema.enumValues, ['1', '2', '3']);
    });

    test('contextName null falls back to String for inline enum', () {
      final schema = v31.Schema(
        type: 'string',
        enumValues: ['a', 'b', 'c'],
      );
      final result = analyzer.schemaToType(schema);
      // No contextName → should fall back to String
      expect(result.type.dartType, 'String');
      expect(result.inlineEnumSchemas, isEmpty);
    });

    test('multiple inline enum fields in same schema', () {
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
        - status
        - priority
      properties:
        status:
          type: string
          enum:
            - todo
            - done
        priority:
          type: string
          enum:
            - low
            - high
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      final result = analyzer.analyze(
        'Task',
        spec.components!.schemas!['Task']!,
      );

      expect(result.inlineEnumSchemas, hasLength(2));
      final names = result.inlineEnumSchemas.map((s) => s.name).toSet();
      expect(names, {'TaskStatus', 'TaskPriority'});
    });

    test('inline enum in allOf schema is propagated', () {
      final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    Base:
      type: object
      properties:
        name:
          type: string
    Extended:
      allOf:
        - \$ref: '#/components/schemas/Base'
        - type: object
          required:
            - status
          properties:
            status:
              type: string
              enum:
                - active
                - inactive
''');
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      final result = analyzer.analyze(
        'Extended',
        spec.components!.schemas!['Extended']!,
      );

      final status = result.schema.fields.firstWhere((f) => f.name == 'status');
      expect(status.type.dartType, 'ExtendedStatus');
      expect(status.type.isEnum, isTrue);

      expect(result.inlineEnumSchemas, hasLength(1));
      expect(result.inlineEnumSchemas.first.name, 'ExtendedStatus');
    });

    group('default values', () {
      test('extracts string default value', () {
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
        - status
      properties:
        status:
          type: string
          default: active
''');
        final analyzer = SchemaAnalyzer(RefResolver(spec));
        final result = analyzer.analyze(
          'Task',
          spec.components!.schemas!['Task']!,
        );
        final status = result.schema.fields.firstWhere((f) => f.name == 'status');
        expect(status.defaultValue, "'active'");
      });

      test('extracts integer default value', () {
        final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    Config:
      type: object
      properties:
        retries:
          type: integer
          default: 10
''');
        final analyzer = SchemaAnalyzer(RefResolver(spec));
        final result = analyzer.analyze(
          'Config',
          spec.components!.schemas!['Config']!,
        );
        final retries = result.schema.fields.firstWhere((f) => f.name == 'retries');
        expect(retries.defaultValue, '10');
      });

      test('extracts boolean default value', () {
        final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    Config:
      type: object
      properties:
        enabled:
          type: boolean
          default: true
''');
        final analyzer = SchemaAnalyzer(RefResolver(spec));
        final result = analyzer.analyze(
          'Config',
          spec.components!.schemas!['Config']!,
        );
        final enabled = result.schema.fields.firstWhere((f) => f.name == 'enabled');
        expect(enabled.defaultValue, 'true');
      });

      test('extracts empty array default value', () {
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
      properties:
        tags:
          type: array
          items:
            type: string
          default: []
''');
        final analyzer = SchemaAnalyzer(RefResolver(spec));
        final result = analyzer.analyze(
          'Task',
          spec.components!.schemas!['Task']!,
        );
        final tags = result.schema.fields.firstWhere((f) => f.name == 'tags');
        expect(tags.defaultValue, 'const []');
      });

      test('extracts enum default value as EnumName.dartMemberName', () {
        final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    TaskStatus:
      type: string
      enum:
        - todo
        - in_progress
        - done
    Task:
      type: object
      properties:
        status:
          \$ref: '#/components/schemas/TaskStatus'
          default: todo
''');
        final analyzer = SchemaAnalyzer(RefResolver(spec));
        final result = analyzer.analyze(
          'Task',
          spec.components!.schemas!['Task']!,
        );
        final status = result.schema.fields.firstWhere((f) => f.name == 'status');
        expect(status.defaultValue, 'TaskStatus.todo');
      });

      test('returns null for date-time default', () {
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
      properties:
        createdAt:
          type: string
          format: date-time
          default: "2024-01-01T00:00:00Z"
''');
        final analyzer = SchemaAnalyzer(RefResolver(spec));
        final result = analyzer.analyze(
          'Task',
          spec.components!.schemas!['Task']!,
        );
        final createdAt = result.schema.fields.firstWhere((f) => f.name == 'createdAt');
        expect(createdAt.defaultValue, isNull);
      });

      test('extracts number default value', () {
        final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    Config:
      type: object
      properties:
        ratio:
          type: number
          default: 0.5
''');
        final analyzer = SchemaAnalyzer(RefResolver(spec));
        final result = analyzer.analyze(
          'Config',
          spec.components!.schemas!['Config']!,
        );
        final ratio = result.schema.fields.firstWhere((f) => f.name == 'ratio');
        expect(ratio.defaultValue, '0.5');
      });
    });

    group('deprecated', () {
      test('reads deprecated flag on field', () {
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
        legacyId:
          type: string
          deprecated: true
''');
        final analyzer = SchemaAnalyzer(RefResolver(spec));
        final result = analyzer.analyze(
          'User',
          spec.components!.schemas!['User']!,
        );
        final name = result.schema.fields.firstWhere((f) => f.name == 'name');
        expect(name.deprecated, isFalse);
        final legacyId = result.schema.fields.firstWhere((f) => f.name == 'legacyId');
        expect(legacyId.deprecated, isTrue);
      });

      test('reads deprecated flag on schema', () {
        final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    OldUser:
      type: object
      deprecated: true
      properties:
        name:
          type: string
''');
        final analyzer = SchemaAnalyzer(RefResolver(spec));
        final result = analyzer.analyze(
          'OldUser',
          spec.components!.schemas!['OldUser']!,
        );
        expect(result.schema.deprecated, isTrue);
      });

      test('reads deprecated flag on enum schema', () {
        final spec = SpecReader().parse('''
openapi: "3.1.0"
info:
  title: Test
  version: "1.0"
paths: {}
components:
  schemas:
    OldStatus:
      type: string
      deprecated: true
      enum:
        - active
        - inactive
''');
        final analyzer = SchemaAnalyzer(RefResolver(spec));
        final result = analyzer.analyze(
          'OldStatus',
          spec.components!.schemas!['OldStatus']!,
        );
        expect(result.schema.deprecated, isTrue);
        expect(result.schema.isEnum, isTrue);
      });
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
      final result = analyzer.analyze('Task', spec.components!.schemas!['Task']!);

      expect(result.inlineUnionSchemas, hasLength(2));
      final names = result.inlineUnionSchemas.map((s) => s.name).toSet();
      expect(names, {'TaskOwner', 'TaskReviewer'});
    });
  });
}
