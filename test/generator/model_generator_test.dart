import 'package:test/test.dart';
import 'package:florval/src/generator/model_generator.dart';
import 'package:florval/src/model/api_schema.dart';
import 'package:florval/src/model/api_type.dart';

void main() {
  group('ModelGenerator', () {
    final generator = ModelGenerator();

    test('generates simple model', () {
      final schema = FlorvalSchema(
        name: 'User',
        fields: [
          FlorvalField(
            name: 'id',
            jsonKey: 'id',
            type: FlorvalType(name: 'int', dartType: 'int'),
            isRequired: true,
          ),
          FlorvalField(
            name: 'name',
            jsonKey: 'name',
            type: FlorvalType(name: 'String', dartType: 'String'),
            isRequired: true,
          ),
          FlorvalField(
            name: 'email',
            jsonKey: 'email',
            type: FlorvalType(
              name: 'String',
              dartType: 'String?',
              isNullable: true,
            ),
            isRequired: false,
          ),
        ],
      );

      final code = generator.generate(schema);

      expect(code, contains('@freezed'));
      expect(code, contains('abstract class User with _\$User'));
      expect(code, contains('required int id,'));
      expect(code, contains('required String name,'));
      expect(code, contains('String? email,'));
      expect(code, contains("part 'user.freezed.dart';"));
      expect(code, contains("part 'user.g.dart';"));
      expect(code, contains(') = _User;'));
      expect(
        code,
        contains('factory User.fromJson(Map<String, dynamic> json)'),
      );
    });

    test('generates JsonKey for mismatched field names', () {
      final schema = FlorvalSchema(
        name: 'Pet',
        fields: [
          FlorvalField(
            name: 'createdAt',
            jsonKey: 'created_at',
            type: FlorvalType(name: 'DateTime', dartType: 'DateTime'),
            isRequired: true,
          ),
        ],
      );

      final code = generator.generate(schema);

      expect(code, contains("@JsonKey(name: 'created_at')"));
      expect(code, contains('required DateTime createdAt,'));
    });

    test('does not generate JsonKey when names match', () {
      final schema = FlorvalSchema(
        name: 'Simple',
        fields: [
          FlorvalField(
            name: 'name',
            jsonKey: 'name',
            type: FlorvalType(name: 'String', dartType: 'String'),
            isRequired: true,
          ),
        ],
      );

      final code = generator.generate(schema);
      expect(code, isNot(contains('@JsonKey')));
    });

    test(
      'generates empty factory without named parameters for schema with no fields',
      () {
        final schema = FlorvalSchema(name: 'FbRoomEntity', fields: []);

        final code = generator.generate(schema);
        expect(code, contains('const factory FbRoomEntity() = _FbRoomEntity;'));
        expect(code, isNot(contains('const factory FbRoomEntity({')));
      },
    );

    test('imports referenced types', () {
      final schema = FlorvalSchema(
        name: 'Pet',
        fields: [
          FlorvalField(
            name: 'category',
            jsonKey: 'category',
            type: FlorvalType(
              name: 'Category',
              dartType: 'Category?',
              isNullable: true,
              ref: '#/components/schemas/Category',
            ),
            isRequired: false,
          ),
        ],
      );

      final code = generator.generate(schema);
      expect(code, contains("import 'category.dart';"));
    });

    test('imports item type for list of references', () {
      final schema = FlorvalSchema(
        name: 'ValidationError',
        fields: [
          FlorvalField(
            name: 'errors',
            jsonKey: 'errors',
            type: FlorvalType(
              name: 'List<FieldError>',
              dartType: 'List<FieldError>',
              isList: true,
              itemType: FlorvalType(
                name: 'FieldError',
                dartType: 'FieldError',
                ref: '#/components/schemas/FieldError',
              ),
            ),
            isRequired: true,
          ),
        ],
      );

      final code = generator.generate(schema);
      expect(code, contains("import 'field_error.dart';"));
    });

    test('generates sealed class for oneOf union type', () {
      final schema = FlorvalSchema(
        name: 'Animal',
        fields: [],
        oneOf: [
          FlorvalSchema(name: 'Dog', fields: []),
          FlorvalSchema(name: 'Cat', fields: []),
        ],
      );

      final code = generator.generate(schema);

      expect(code, contains('sealed class Animal'));
      expect(code, isNot(contains('with _\$Animal')));
      expect(code, isNot(contains('@freezed')));
      expect(code, contains('const factory Animal.dog(Dog data) = AnimalDog;'));
      expect(code, contains('const factory Animal.cat(Cat data) = AnimalCat;'));
      expect(code, contains("import 'dog.dart';"));
      expect(code, contains("import 'cat.dart';"));
      // Subclasses
      expect(code, contains('class AnimalDog extends Animal'));
      expect(code, contains('class AnimalCat extends Animal'));
    });

    test('generates sealed class for anyOf union type', () {
      final schema = FlorvalSchema(
        name: 'Shape',
        fields: [],
        anyOf: [
          FlorvalSchema(name: 'Circle', fields: []),
          FlorvalSchema(name: 'Square', fields: []),
        ],
      );

      final code = generator.generate(schema);

      expect(code, contains('sealed class Shape'));
      expect(code, isNot(contains('with _\$Shape')));
      expect(
        code,
        contains('const factory Shape.circle(Circle data) = ShapeCircle;'),
      );
      expect(
        code,
        contains('const factory Shape.square(Square data) = ShapeSquare;'),
      );
    });

    test('generates freezed sealed class for discriminator union', () {
      final schema = FlorvalSchema(
        name: 'Animal',
        fields: [],
        oneOf: [
          FlorvalSchema(
            name: 'Dog',
            fields: [
              FlorvalField(
                name: 'type',
                jsonKey: 'type',
                type: FlorvalType(name: 'String', dartType: 'String'),
                isRequired: true,
              ),
              FlorvalField(
                name: 'breed',
                jsonKey: 'breed',
                type: FlorvalType(name: 'String', dartType: 'String'),
                isRequired: true,
              ),
            ],
          ),
          FlorvalSchema(
            name: 'Cat',
            fields: [
              FlorvalField(
                name: 'type',
                jsonKey: 'type',
                type: FlorvalType(name: 'String', dartType: 'String'),
                isRequired: true,
              ),
              FlorvalField(
                name: 'indoor',
                jsonKey: 'indoor',
                type: FlorvalType(name: 'bool', dartType: 'bool'),
                isRequired: true,
              ),
            ],
          ),
        ],
        discriminator: FlorvalDiscriminator(
          propertyName: 'type',
          mapping: {'dog': 'Dog', 'cat': 'Cat'},
        ),
      );

      final code = generator.generate(schema);

      // freezed annotations
      expect(code, contains("@Freezed(unionKey: 'type')"));
      expect(code, contains('sealed class Animal with _\$Animal'));
      expect(code, contains("part 'animal.freezed.dart';"));
      expect(code, contains("part 'animal.g.dart';"));

      // Variant factories with @FreezedUnionValue
      expect(code, contains("@FreezedUnionValue('dog')"));
      expect(code, contains("@FreezedUnionValue('cat')"));
      expect(code, contains('const factory Animal.dog('));
      expect(code, contains('const factory Animal.cat('));
      expect(code, contains(') = AnimalDog;'));
      expect(code, contains(') = AnimalCat;'));

      // Variant fields are inlined (discriminator field excluded)
      expect(code, contains('required String breed,'));
      expect(code, contains('required bool indoor,'));
      // Discriminator property itself should NOT appear as a field
      expect(code, isNot(contains('required String type,')));

      // Generated fromJson (delegated to freezed)
      expect(code, contains('_\$AnimalFromJson(json)'));

      // No manual toJson/subclasses (freezed generates them)
      expect(code, isNot(contains('class AnimalDog extends Animal')));
      expect(code, isNot(contains('Map<String, dynamic> toJson()')));
    });

    test('generates PaginatedData class', () {
      final code = generator.generatePaginatedData();

      expect(code, contains('class PaginatedData<T, P>'));
      expect(code, contains('final List<T> items;'));
      expect(code, contains('final String? nextCursor;'));
      expect(code, contains('final bool hasMore;'));
      expect(code, contains('final P lastPage;'));
      expect(code, contains('const PaginatedData('));
      expect(code, contains('required this.items,'));
      expect(code, contains('this.nextCursor,'));
      expect(code, contains('this.hasMore = true,'));
      expect(code, contains('required this.lastPage,'));
    });

    test('generates ApiException class', () {
      final code = generator.generateApiException();

      expect(code, contains('class ApiException implements Exception'));
      expect(code, contains('final dynamic response;'));
      expect(code, contains('const ApiException(this.response);'));
      expect(
        code,
        contains("String toString() => 'ApiException: \$response';"),
      );
    });

    test('generates Dart enum for enum schema', () {
      final schema = FlorvalSchema(
        name: 'GenderEnum',
        fields: [],
        enumValues: ['male', 'female'],
      );

      final code = generator.generate(schema);

      expect(
        code,
        contains("import 'package:json_annotation/json_annotation.dart';"),
      );
      expect(code, contains('enum GenderEnum {'));
      expect(code, contains("@JsonValue('male')"));
      expect(code, contains('male,'));
      expect(code, contains("@JsonValue('female')"));
      expect(code, contains('female;'));
      // Should NOT contain freezed artifacts
      expect(code, isNot(contains('@freezed')));
      expect(code, isNot(contains('part ')));
      expect(code, isNot(contains('abstract class')));
    });

    test('generates enum with snake_case values as camelCase Dart names', () {
      final schema = FlorvalSchema(
        name: 'ErrorCode',
        fields: [],
        enumValues: ['reg_ticket_sold_out', 'usr_not_found'],
      );

      final code = generator.generate(schema);

      expect(code, contains("@JsonValue('reg_ticket_sold_out')"));
      expect(code, contains('regTicketSoldOut,'));
      expect(code, contains("@JsonValue('usr_not_found')"));
      expect(code, contains('usrNotFound;'));
    });

    test('generates enum with many values (Prefecture)', () {
      final schema = FlorvalSchema(
        name: 'Prefecture',
        fields: [],
        enumValues: ['hokkaido', 'tokyo', 'osaka'],
      );

      final code = generator.generate(schema);

      expect(code, contains('enum Prefecture {'));
      expect(code, contains("@JsonValue('hokkaido')"));
      expect(code, contains('hokkaido,'));
      expect(code, contains("@JsonValue('tokyo')"));
      expect(code, contains('tokyo,'));
      expect(code, contains("@JsonValue('osaka')"));
      expect(code, contains('osaka;'));
    });

    test('generates enum with non-ASCII (Japanese) values', () {
      final schema = FlorvalSchema(
        name: 'SeverityType',
        fields: [],
        enumValues: ['正常', '軽度', '中等度', '重度', '極めて重度'],
      );

      final code = generator.generate(schema);

      // Each non-ASCII value should get a unique index-based name
      expect(code, contains("@JsonValue('正常')"));
      expect(code, contains('value0,'));
      expect(code, contains("@JsonValue('軽度')"));
      expect(code, contains('value1,'));
      expect(code, contains("@JsonValue('中等度')"));
      expect(code, contains('value2,'));
      expect(code, contains("@JsonValue('重度')"));
      expect(code, contains('value3,'));
      expect(code, contains("@JsonValue('極めて重度')"));
      expect(code, contains('value4;'));
    });

    test('generates enum with mixed ASCII and non-ASCII values', () {
      final schema = FlorvalSchema(
        name: 'MixedEnum',
        fields: [],
        enumValues: ['normal', '異常', 'critical'],
      );

      final code = generator.generate(schema);

      expect(code, contains('normal,'));
      expect(code, contains('value1,'));
      expect(code, contains('critical;'));
    });

    test('generates enum handling collision from non-ASCII stripping', () {
      final schema = FlorvalSchema(
        name: 'CollisionEnum',
        fields: [],
        enumValues: ['bmi', 'BMI値'],
      );

      final code = generator.generate(schema);

      // 'bmi' is used first, 'BMI值' strips to 'bmi' which collides → 'bmi1'
      expect(code, contains("@JsonValue('bmi')"));
      expect(code, contains('bmi,'));
      expect(code, contains("@JsonValue('BMI値')"));
      expect(code, contains('bmi1;'));
    });

    test('generates valid freezed 3.x syntax', () {
      final schema = FlorvalSchema(
        name: 'Category',
        fields: [
          FlorvalField(
            name: 'id',
            jsonKey: 'id',
            type: FlorvalType(name: 'int', dartType: 'int'),
            isRequired: true,
          ),
          FlorvalField(
            name: 'name',
            jsonKey: 'name',
            type: FlorvalType(name: 'String', dartType: 'String'),
            isRequired: true,
          ),
        ],
      );

      final code = generator.generate(schema);

      // Verify structure order
      expect(
        code.indexOf('@freezed'),
        lessThan(code.indexOf('abstract class')),
      );
      expect(
        code.indexOf('abstract class'),
        lessThan(code.indexOf('const factory')),
      );
      expect(code.indexOf('const factory'), lessThan(code.indexOf('fromJson')));
    });

    test(
      'variantSchemaNames collects variant names from discriminator unions',
      () {
        final schemas = [
          FlorvalSchema(
            name: 'Payload',
            fields: [],
            oneOf: [
              FlorvalSchema(name: 'TypeA', fields: []),
              FlorvalSchema(name: 'TypeB', fields: []),
            ],
            discriminator: FlorvalDiscriminator(
              propertyName: 'kind',
              mapping: {'a': 'TypeA', 'b': 'TypeB'},
            ),
          ),
          FlorvalSchema(name: 'User', fields: []),
          FlorvalSchema(
            name: 'Shape',
            fields: [],
            oneOf: [FlorvalSchema(name: 'Circle', fields: [])],
            // No discriminator → not a freezed union
          ),
        ];

        final names = ModelGenerator.variantSchemaNames(schemas);

        expect(names, contains('TypeA'));
        expect(names, contains('TypeB'));
        // Non-discriminator union variants should NOT be included
        expect(names, isNot(contains('Circle')));
        // Regular schemas should NOT be included
        expect(names, isNot(contains('User')));
      },
    );

    test('generates fromJson for non-discriminator union type', () {
      final schema = FlorvalSchema(
        name: 'TaskOwner',
        fields: [],
        anyOf: [
          FlorvalSchema(name: 'User', fields: []),
          FlorvalSchema(name: 'Group', fields: []),
        ],
      );

      final code = generator.generate(schema);

      // Should NOT contain todo comments
      expect(code, isNot(contains('// TODO')));
      // Should contain fromJson factory
      expect(
        code,
        contains('factory TaskOwner.fromJson(Map<String, dynamic> json)'),
      );
      // Should try each variant
      expect(code, contains('return TaskOwner.user(User.fromJson(json));'));
      expect(code, contains('return TaskOwner.group(Group.fromJson(json));'));
      // Should throw FormatException on no match
      expect(code, contains('throw FormatException('));
      expect(code, contains('none of the variants matched'));
    });

    test('generates toJson for non-discriminator union subclasses', () {
      final schema = FlorvalSchema(
        name: 'TaskOwner',
        fields: [],
        anyOf: [
          FlorvalSchema(name: 'User', fields: []),
          FlorvalSchema(name: 'Group', fields: []),
        ],
      );

      final code = generator.generate(schema);

      expect(code, contains('Map<String, dynamic> toJson() => data.toJson();'));
      // Both subclasses should have toJson
      expect(code, contains('class TaskOwnerUser extends TaskOwner'));
      expect(code, contains('class TaskOwnerGroup extends TaskOwner'));
    });
  });
}
