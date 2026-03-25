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
