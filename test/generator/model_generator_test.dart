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
                name: 'String', dartType: 'String?', isNullable: true),
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
          code, contains('factory User.fromJson(Map<String, dynamic> json)'));
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

      expect(code, contains('sealed class Animal with _\$Animal'));
      expect(code, contains('const factory Animal.dog(Dog data) = AnimalDog;'));
      expect(code, contains('const factory Animal.cat(Cat data) = AnimalCat;'));
      expect(code, contains("import 'dog.dart';"));
      expect(code, contains("import 'cat.dart';"));
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

      expect(code, contains('sealed class Shape with _\$Shape'));
      expect(code, contains('const factory Shape.circle(Circle data) = ShapeCircle;'));
      expect(code, contains('const factory Shape.square(Square data) = ShapeSquare;'));
    });

    test('generates discriminator-based fromJson', () {
      final schema = FlorvalSchema(
        name: 'Animal',
        fields: [],
        oneOf: [
          FlorvalSchema(name: 'Dog', fields: []),
          FlorvalSchema(name: 'Cat', fields: []),
        ],
        discriminator: FlorvalDiscriminator(
          propertyName: 'type',
          mapping: {'dog': 'Dog', 'cat': 'Cat'},
        ),
      );

      final code = generator.generate(schema);

      expect(code, contains("switch (json['type'])"));
      expect(code, contains("case 'dog':"));
      expect(code, contains('Animal.dog(Dog.fromJson(json))'));
      expect(code, contains("case 'cat':"));
      expect(code, contains('Animal.cat(Cat.fromJson(json))'));
      expect(code, contains("throw UnimplementedError('Unknown type:"));
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
      expect(code, contains("String toString() => 'ApiException: \$response';"));
    });

    test('generates Dart enum for enum schema', () {
      final schema = FlorvalSchema(
        name: 'GenderEnum',
        fields: [],
        enumValues: ['male', 'female'],
      );

      final code = generator.generate(schema);

      expect(code, contains("import 'package:json_annotation/json_annotation.dart';"));
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
      expect(code.indexOf('@freezed'), lessThan(code.indexOf('abstract class')));
      expect(code.indexOf('abstract class'),
          lessThan(code.indexOf('const factory')));
      expect(
          code.indexOf('const factory'), lessThan(code.indexOf('fromJson')));
    });
  });
}
