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
      // jsonValue getter
      expect(code, contains('String get jsonValue => switch (this)'));
      expect(code, contains("GenderEnum.male => 'male'"));
      expect(code, contains("GenderEnum.female => 'female'"));
      // fromJsonValue static method
      expect(code, contains('static GenderEnum fromJsonValue(String value)'));
      expect(code, contains('values.firstWhere((e) => e.jsonValue == value)'));
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
      'variantSchemaNames collects variant names and subclass names from discriminator unions',
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
            // No discriminator → not processed by variantSchemaNames
          ),
        ];

        final names = ModelGenerator.variantSchemaNames(schemas);

        // Original variant names from discriminator unions
        expect(names, contains('TypeA'));
        expect(names, contains('TypeB'));
        // Generated subclass names from discriminator unions
        expect(names, contains('PayloadA'));
        expect(names, contains('PayloadB'));
        // Non-discriminator union variants should NOT be included
        expect(names, isNot(contains('Circle')));
        expect(names, isNot(contains('ShapeCircle')));
        // Regular schemas should NOT be included
        expect(names, isNot(contains('User')));
      },
    );

    test(
      'variantSchemaNames with ref-style mapping values',
      () {
        final schemas = [
          FlorvalSchema(
            name: 'RequestData',
            fields: [],
            oneOf: [
              FlorvalSchema(name: 'RoomInvitation', fields: []),
              FlorvalSchema(name: 'DirectMessage', fields: []),
            ],
            discriminator: FlorvalDiscriminator(
              propertyName: 'type',
              mapping: {
                'room_invitation': '#/components/schemas/RoomInvitation',
                'direct_message': '#/components/schemas/DirectMessage',
              },
            ),
          ),
        ];

        final names = ModelGenerator.variantSchemaNames(schemas);

        expect(names, contains('RoomInvitation'));
        expect(names, contains('DirectMessage'));
        expect(names, contains('RequestDataRoomInvitation'));
        expect(names, contains('RequestDataDirectMessage'));
      },
    );

    test(
      'variantSchemaNames without explicit mapping uses snake_case default',
      () {
        final schemas = [
          FlorvalSchema(
            name: 'PostContent',
            fields: [],
            oneOf: [
              FlorvalSchema(name: 'TextBlock', fields: []),
              FlorvalSchema(name: 'ImageBlock', fields: []),
            ],
            discriminator: FlorvalDiscriminator(
              propertyName: 'kind',
            ),
          ),
        ];

        final names = ModelGenerator.variantSchemaNames(schemas);

        expect(names, contains('TextBlock'));
        expect(names, contains('ImageBlock'));
        // Default: ReCase(variant.name).snakeCase → 'text_block'
        // Subclass: PostContent + ReCase('text_block').pascalCase = PostContentTextBlock
        expect(names, contains('PostContentTextBlock'));
        expect(names, contains('PostContentImageBlock'));
      },
    );

    test(
      'unionSubclassNames collects subclass names from discriminator unions',
      () {
        final schemas = [
          FlorvalSchema(
            name: 'RequestData',
            fields: [],
            oneOf: [
              FlorvalSchema(name: 'RoomInvitation', fields: []),
              FlorvalSchema(name: 'DirectMessage', fields: []),
            ],
            discriminator: FlorvalDiscriminator(
              propertyName: 'type',
              mapping: {
                'room_invitation': 'RoomInvitation',
                'direct_message': 'DirectMessage',
              },
            ),
          ),
        ];

        final names = ModelGenerator.unionSubclassNames(schemas);

        // Only subclass names, NOT original variant names
        expect(names, contains('RequestDataRoomInvitation'));
        expect(names, contains('RequestDataDirectMessage'));
        expect(names, isNot(contains('RoomInvitation')));
        expect(names, isNot(contains('DirectMessage')));
      },
    );

    test(
      'unionSubclassNames collects subclass names from non-discriminator unions',
      () {
        final schemas = [
          FlorvalSchema(
            name: 'TaskOwner',
            fields: [],
            anyOf: [
              FlorvalSchema(name: 'User', fields: []),
              FlorvalSchema(name: 'Group', fields: []),
            ],
          ),
        ];

        final names = ModelGenerator.unionSubclassNames(schemas);

        // Subclass names from non-discriminator union
        expect(names, contains('TaskOwnerUser'));
        expect(names, contains('TaskOwnerGroup'));
        // Variant type names must NOT be included
        expect(names, isNot(contains('User')));
        expect(names, isNot(contains('Group')));
      },
    );

    test(
      'unionSubclassNames skips non-union schemas',
      () {
        final schemas = [
          FlorvalSchema(name: 'User', fields: []),
          FlorvalSchema(name: 'Task', fields: []),
        ];

        final names = ModelGenerator.unionSubclassNames(schemas);

        expect(names, isEmpty);
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

    group('default values', () {
      test('generates @Default annotation for field with defaultValue', () {
        final schema = FlorvalSchema(
          name: 'Config',
          fields: [
            FlorvalField(
              name: 'retries',
              jsonKey: 'retries',
              type: FlorvalType(name: 'int', dartType: 'int'),
              isRequired: true,
              defaultValue: '3',
            ),
          ],
        );

        final code = generator.generate(schema);

        expect(code, contains('@Default(3) int retries,'));
        // Should NOT have required prefix when defaultValue is set
        expect(code, isNot(contains('required int retries,')));
      });

      test('generates @Default for string defaultValue', () {
        final schema = FlorvalSchema(
          name: 'Task',
          fields: [
            FlorvalField(
              name: 'status',
              jsonKey: 'status',
              type: FlorvalType(name: 'String', dartType: 'String'),
              isRequired: true,
              defaultValue: "'active'",
            ),
          ],
        );

        final code = generator.generate(schema);

        expect(code, contains("@Default('active') String status,"));
        expect(code, isNot(contains('required String status,')));
      });

      test('generates @Default for boolean defaultValue', () {
        final schema = FlorvalSchema(
          name: 'Config',
          fields: [
            FlorvalField(
              name: 'enabled',
              jsonKey: 'enabled',
              type: FlorvalType(name: 'bool', dartType: 'bool'),
              isRequired: false,
              defaultValue: 'true',
            ),
          ],
        );

        final code = generator.generate(schema);

        expect(code, contains('@Default(true) bool enabled,'));
      });

      test('generates @Default for empty array defaultValue', () {
        final schema = FlorvalSchema(
          name: 'Task',
          fields: [
            FlorvalField(
              name: 'tags',
              jsonKey: 'tags',
              type: FlorvalType(
                name: 'List<String>',
                dartType: 'List<String>',
                isList: true,
              ),
              isRequired: false,
              defaultValue: 'const []',
            ),
          ],
        );

        final code = generator.generate(schema);

        expect(code, contains('@Default(const []) List<String> tags,'));
      });

      test('absentable takes priority over defaultValue', () {
        final schema = FlorvalSchema(
          name: 'UpdateUserRequest',
          fields: [
            FlorvalField(
              name: 'name',
              jsonKey: 'name',
              type: FlorvalType(
                name: 'String',
                dartType: 'String?',
                isNullable: true,
              ),
              isRequired: false,
              absentable: true,
              defaultValue: "'default'",
            ),
          ],
        );

        final code = generator.generate(schema);

        // absentable wins — JsonOptional wrapping, not @Default
        expect(code, contains('JsonOptional<String>'));
        expect(code, isNot(contains("@Default('default')")));
      });
    });

    group('deprecated', () {
      test('generates @Deprecated on deprecated field', () {
        final schema = FlorvalSchema(
          name: 'User',
          fields: [
            FlorvalField(
              name: 'name',
              jsonKey: 'name',
              type: FlorvalType(name: 'String', dartType: 'String'),
              isRequired: true,
            ),
            FlorvalField(
              name: 'legacyId',
              jsonKey: 'legacy_id',
              type: FlorvalType(
                name: 'String',
                dartType: 'String?',
                isNullable: true,
              ),
              isRequired: false,
              deprecated: true,
            ),
          ],
        );

        final code = generator.generate(schema);

        expect(code, contains("@Deprecated('')"));
        expect(code, contains("@JsonKey(name: 'legacy_id')"));
        // @Deprecated should appear before @JsonKey
        final deprecatedIndex = code.indexOf("@Deprecated('')");
        final jsonKeyIndex = code.indexOf("@JsonKey(name: 'legacy_id')");
        expect(deprecatedIndex, lessThan(jsonKeyIndex));
      });

      test('generates @Deprecated on deprecated data class', () {
        final schema = FlorvalSchema(
          name: 'OldUser',
          fields: [
            FlorvalField(
              name: 'name',
              jsonKey: 'name',
              type: FlorvalType(name: 'String', dartType: 'String'),
              isRequired: true,
            ),
          ],
          deprecated: true,
        );

        final code = generator.generate(schema);

        expect(code, contains("@Deprecated('')"));
        // @Deprecated should appear before @freezed
        final deprecatedIndex = code.indexOf("@Deprecated('')");
        final freezedIndex = code.indexOf('@freezed');
        expect(deprecatedIndex, lessThan(freezedIndex));
      });

      test('generates @Deprecated on deprecated enum', () {
        final schema = FlorvalSchema(
          name: 'OldStatus',
          fields: [],
          enumValues: ['active', 'inactive'],
          deprecated: true,
        );

        final code = generator.generate(schema);

        expect(code, contains("@Deprecated('')"));
        // @Deprecated should appear before enum definition
        final deprecatedIndex = code.indexOf("@Deprecated('')");
        final enumIndex = code.indexOf('enum OldStatus {');
        expect(deprecatedIndex, lessThan(enumIndex));
      });

      test('non-deprecated field does not have @Deprecated', () {
        final schema = FlorvalSchema(
          name: 'User',
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

        expect(code, isNot(contains("@Deprecated")));
      });
    });

    group('absentable fields (JsonOptional)', () {
      test('wraps absentable fields in JsonOptional with @Default', () {
        final schema = FlorvalSchema(
          name: 'UpdateUserRequest',
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
              type: FlorvalType(
                name: 'String',
                dartType: 'String?',
                isNullable: true,
              ),
              isRequired: false,
              absentable: true,
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
              absentable: true,
            ),
          ],
        );

        final code = generator.generate(schema);

        // Required field stays as-is
        expect(code, contains('required int id,'));

        // Absentable fields wrapped in JsonOptional
        expect(
          code,
          contains(
              '@Default(JsonOptional<String>.absent()) JsonOptional<String> name,'),
        );
        expect(
          code,
          contains(
              '@Default(JsonOptional<String>.absent()) JsonOptional<String> email,'),
        );

        // Should NOT have 'required' prefix on absentable fields
        expect(code, isNot(contains('required JsonOptional')));
      });

      test('generates @Freezed(fromJson: false, toJson: false) for absentable schema', () {
        final schema = FlorvalSchema(
          name: 'UpdateUserRequest',
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
              type: FlorvalType(
                name: 'String',
                dartType: 'String?',
                isNullable: true,
              ),
              isRequired: false,
              absentable: true,
            ),
          ],
        );

        final code = generator.generate(schema);

        expect(code, contains('@Freezed(fromJson: false, toJson: false)'));
        // Should NOT have plain @freezed or @JsonSerializable
        expect(code, isNot(contains('@JsonSerializable')));
        // Should NOT have .g.dart part directive
        expect(code, isNot(contains(".g.dart';")));
      });

      test('generates custom toJson that excludes absent fields', () {
        final schema = FlorvalSchema(
          name: 'UpdateUserRequest',
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
              type: FlorvalType(
                name: 'String',
                dartType: 'String?',
                isNullable: true,
              ),
              isRequired: false,
              absentable: true,
            ),
          ],
        );

        final code = generator.generate(schema);

        // Custom toJson method
        expect(code, contains('Map<String, dynamic> toJson()'));
        expect(code, contains("json['id'] = id;"));
        expect(code, contains('if (name is JsonOptionalValue<String>)'));
        expect(
          code,
          contains(
              "json['name'] = (name as JsonOptionalValue<String>).value;"),
        );
        expect(code, contains('return json;'));
      });

      test('imports json_optional for absentable schema', () {
        final schema = FlorvalSchema(
          name: 'UpdateUserRequest',
          fields: [
            FlorvalField(
              name: 'name',
              jsonKey: 'name',
              type: FlorvalType(
                name: 'String',
                dartType: 'String?',
                isNullable: true,
              ),
              isRequired: false,
              absentable: true,
            ),
          ],
        );

        final code = generator.generate(schema);

        expect(code, contains("import '../core/json_optional.dart';"));
        // json_annotation is NOT needed (no @JsonSerializable)
        expect(
          code,
          isNot(contains("import 'package:json_annotation/json_annotation.dart';")),
        );
      });

      test('does not apply JsonOptional to required fields', () {
        final schema = FlorvalSchema(
          name: 'UpdateUserRequest',
          fields: [
            FlorvalField(
              name: 'id',
              jsonKey: 'id',
              type: FlorvalType(name: 'int', dartType: 'int'),
              isRequired: true,
              // absentable stays false by default
            ),
            FlorvalField(
              name: 'name',
              jsonKey: 'name',
              type: FlorvalType(
                name: 'String',
                dartType: 'String?',
                isNullable: true,
              ),
              isRequired: false,
              absentable: true,
            ),
          ],
        );

        final code = generator.generate(schema);

        // Required field is NOT wrapped
        expect(code, contains('required int id,'));
        expect(code, isNot(contains('JsonOptional<int>')));
      });

      test('does not generate JsonOptional artifacts when no absentable fields', () {
        final schema = FlorvalSchema(
          name: 'CreateUserRequest',
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

        expect(code, isNot(contains('JsonOptional')));
        expect(code, isNot(contains('json_optional')));
        expect(code, isNot(contains('@Freezed(fromJson')));
        expect(code, isNot(contains('Map<String, dynamic> toJson()')));
        // Normal schema still has .g.dart
        expect(code, contains(".g.dart';"));
      });

      test('generates private constructor for absentable schema', () {
        final schema = FlorvalSchema(
          name: 'UpdateUserRequest',
          fields: [
            FlorvalField(
              name: 'name',
              jsonKey: 'name',
              type: FlorvalType(
                name: 'String',
                dartType: 'String?',
                isNullable: true,
              ),
              isRequired: false,
              absentable: true,
            ),
          ],
        );

        final code = generator.generate(schema);

        // Private constructor needed for custom methods on freezed classes
        expect(code, contains('const UpdateUserRequest._();'));
      });

      test('generates custom fromJson with containsKey for absentable fields', () {
        final schema = FlorvalSchema(
          name: 'UpdateUserRequest',
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
              type: FlorvalType(
                name: 'String',
                dartType: 'String?',
                isNullable: true,
              ),
              isRequired: false,
              absentable: true,
            ),
          ],
        );

        final code = generator.generate(schema);

        // Custom fromJson factory
        expect(
          code,
          contains(
              'factory UpdateUserRequest.fromJson(Map<String, dynamic> json)'),
        );
        // Should NOT delegate to _$...FromJson
        expect(code, isNot(contains('_\$UpdateUserRequestFromJson')));
        // Required field: direct cast
        expect(code, contains("id: (json['id'] as num).toInt(),"));
        // Absentable field: containsKey check
        expect(code, contains("json.containsKey('name')"));
        expect(code, contains('JsonOptional.value('));
        expect(code, contains('JsonOptional<String>.absent()'));
      });

      test('handles absentable field with JsonKey', () {
        final schema = FlorvalSchema(
          name: 'UpdateUserRequest',
          fields: [
            FlorvalField(
              name: 'assigneeId',
              jsonKey: 'assignee_id',
              type: FlorvalType(
                name: 'String',
                dartType: 'String?',
                isNullable: true,
              ),
              isRequired: false,
              absentable: true,
            ),
          ],
        );

        final code = generator.generate(schema);

        expect(code, contains("@JsonKey(name: 'assignee_id')"));
        expect(
          code,
          contains(
              '@Default(JsonOptional<String>.absent()) JsonOptional<String> assigneeId,'),
        );
        // toJson uses the jsonKey
        expect(
          code,
          contains("json['assignee_id']"),
        );
      });
    });

    group('doc comments', () {
      test('generates doc comment for schema with description', () {
        final schema = FlorvalSchema(
          name: 'Pet',
          fields: [
            FlorvalField(
              name: 'id',
              jsonKey: 'id',
              type: FlorvalType(name: 'int', dartType: 'int'),
              isRequired: true,
            ),
          ],
          description: 'Represents a pet in the store',
        );

        final code = generator.generate(schema);

        expect(code, contains('/// Represents a pet in the store'));
        // Doc comment should appear before @freezed
        final docIndex = code.indexOf('/// Represents a pet in the store');
        final freezedIndex = code.indexOf('@freezed');
        expect(docIndex, lessThan(freezedIndex));
      });

      test('does not generate doc comment when description is null', () {
        final schema = FlorvalSchema(
          name: 'Pet',
          fields: [
            FlorvalField(
              name: 'id',
              jsonKey: 'id',
              type: FlorvalType(name: 'int', dartType: 'int'),
              isRequired: true,
            ),
          ],
        );

        final code = generator.generate(schema);

        expect(code, isNot(contains('///')));
      });

      test('generates doc comment for field with description', () {
        final schema = FlorvalSchema(
          name: 'User',
          fields: [
            FlorvalField(
              name: 'id',
              jsonKey: 'id',
              type: FlorvalType(name: 'int', dartType: 'int'),
              isRequired: true,
              description: 'The unique identifier of the user',
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

        expect(code, contains('    /// The unique identifier of the user'));
        // Only the first field has a doc comment
        expect('///'.allMatches(code).length, 1);
      });

      test('generates doc comment with example for field', () {
        final schema = FlorvalSchema(
          name: 'User',
          fields: [
            FlorvalField(
              name: 'email',
              jsonKey: 'email',
              type: FlorvalType(name: 'String', dartType: 'String'),
              isRequired: true,
              description: "The user's email address",
              example: 'user@example.com',
            ),
          ],
        );

        final code = generator.generate(schema);

        expect(code, contains("    /// The user's email address"));
        expect(code, contains('    ///'));
        expect(code, contains('    /// Example: "user@example.com"'));
      });

      test('generates doc comment with example only (no description)', () {
        final schema = FlorvalSchema(
          name: 'User',
          fields: [
            FlorvalField(
              name: 'age',
              jsonKey: 'age',
              type: FlorvalType(name: 'int', dartType: 'int'),
              isRequired: true,
              example: 25,
            ),
          ],
        );

        final code = generator.generate(schema);

        expect(code, contains('    /// Example: 25'));
      });

      test('generates doc comment for enum schema', () {
        final schema = FlorvalSchema(
          name: 'Status',
          fields: [],
          enumValues: ['active', 'inactive'],
          description: 'The status of the resource',
        );

        final code = generator.generate(schema);

        expect(code, contains('/// The status of the resource'));
        final docIndex = code.indexOf('/// The status of the resource');
        final enumIndex = code.indexOf('enum Status {');
        expect(docIndex, lessThan(enumIndex));
      });

      test('generates doc comment for sealed class (union type)', () {
        final schema = FlorvalSchema(
          name: 'Animal',
          fields: [],
          oneOf: [
            FlorvalSchema(name: 'Dog', fields: []),
            FlorvalSchema(name: 'Cat', fields: []),
          ],
          description: 'A union of animal types',
        );

        final code = generator.generate(schema);

        expect(code, contains('/// A union of animal types'));
        final docIndex = code.indexOf('/// A union of animal types');
        final sealedIndex = code.indexOf('sealed class Animal');
        expect(docIndex, lessThan(sealedIndex));
      });

      test('generates doc comment for discriminator sealed class', () {
        final schema = FlorvalSchema(
          name: 'Payload',
          fields: [],
          oneOf: [
            FlorvalSchema(
              name: 'TypeA',
              fields: [
                FlorvalField(
                  name: 'kind',
                  jsonKey: 'kind',
                  type: FlorvalType(name: 'String', dartType: 'String'),
                  isRequired: true,
                ),
              ],
            ),
          ],
          discriminator: FlorvalDiscriminator(
            propertyName: 'kind',
            mapping: {'a': 'TypeA'},
          ),
          description: 'A polymorphic payload',
        );

        final code = generator.generate(schema);

        expect(code, contains('/// A polymorphic payload'));
        final docIndex = code.indexOf('/// A polymorphic payload');
        final freezedIndex = code.indexOf("@Freezed(unionKey:");
        expect(docIndex, lessThan(freezedIndex));
      });

      test('handles multi-line description on schema', () {
        final schema = FlorvalSchema(
          name: 'Pet',
          fields: [],
          description: 'A pet object.\nContains all pet details.',
        );

        final code = generator.generate(schema);

        expect(code, contains('/// A pet object.'));
        expect(code, contains('/// Contains all pet details.'));
      });

      test('generates example with map value as JSON', () {
        final schema = FlorvalSchema(
          name: 'Config',
          fields: [
            FlorvalField(
              name: 'metadata',
              jsonKey: 'metadata',
              type: FlorvalType(
                  name: 'Map<String, dynamic>',
                  dartType: 'Map<String, dynamic>'),
              isRequired: true,
              example: {'key': 'value'},
            ),
          ],
        );

        final code = generator.generate(schema);

        expect(code, contains('    /// Example: {"key":"value"}'));
      });
    });

    group('readOnly / writeOnly', () {
      test('readOnly field generates @JsonKey(includeToJson: false)', () {
        final schema = FlorvalSchema(
          name: 'Resource',
          fields: [
            FlorvalField(
              name: 'id',
              jsonKey: 'id',
              type: FlorvalType(name: 'int', dartType: 'int'),
              isRequired: true,
              readOnly: true,
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

        expect(code, contains('@JsonKey(includeToJson: false)'));
        expect(code, contains('required int id,'));
        // includeFromJson should NOT be present for readOnly
        expect(code, isNot(contains('includeFromJson')));
      });

      test('writeOnly field generates @JsonKey(includeFromJson: false)', () {
        final schema = FlorvalSchema(
          name: 'Account',
          fields: [
            FlorvalField(
              name: 'password',
              jsonKey: 'password',
              type: FlorvalType(name: 'String', dartType: 'String'),
              isRequired: true,
              writeOnly: true,
            ),
          ],
        );

        final code = generator.generate(schema);

        expect(code, contains('@JsonKey(includeFromJson: false)'));
        expect(code, isNot(contains('includeToJson')));
      });

      test('readOnly field with name mapping combines in single @JsonKey', () {
        final schema = FlorvalSchema(
          name: 'Resource',
          fields: [
            FlorvalField(
              name: 'createdAt',
              jsonKey: 'created_at',
              type: FlorvalType(name: 'DateTime', dartType: 'DateTime'),
              isRequired: true,
              readOnly: true,
            ),
          ],
        );

        final code = generator.generate(schema);

        expect(
          code,
          contains("@JsonKey(name: 'created_at', includeToJson: false)"),
        );
        // Should NOT have a separate @JsonKey line
        final jsonKeyCount =
            '@JsonKey('.allMatches(code).length;
        expect(jsonKeyCount, 1);
      });

      test('non-readOnly non-writeOnly field does not include includeToJson/includeFromJson', () {
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

        expect(code, isNot(contains('includeToJson')));
        expect(code, isNot(contains('includeFromJson')));
        expect(code, isNot(contains('@JsonKey')));
      });

      test('readOnly field in absentable schema is excluded from custom toJson', () {
        final schema = FlorvalSchema(
          name: 'UpdateResource',
          fields: [
            FlorvalField(
              name: 'id',
              jsonKey: 'id',
              type: FlorvalType(name: 'int', dartType: 'int'),
              isRequired: true,
              readOnly: true,
            ),
            FlorvalField(
              name: 'name',
              jsonKey: 'name',
              type: FlorvalType(
                name: 'String',
                dartType: 'String?',
                isNullable: true,
              ),
              isRequired: false,
              absentable: true,
            ),
          ],
        );

        final code = generator.generate(schema);

        // toJson should NOT contain the readOnly field 'id'
        expect(code, contains('Map<String, dynamic> toJson()'));
        final toJson = code.substring(code.indexOf('Map<String, dynamic> toJson()'));
        expect(toJson, isNot(contains("json['id']")));
        // fromJson should still contain 'id' (readOnly is excluded from toJson only)
        final fromJson = code.substring(
          code.indexOf('factory UpdateResource.fromJson'),
          code.indexOf('Map<String, dynamic> toJson()'),
        );
        expect(fromJson, contains("json['id']"));
        // toJson should contain the absentable field 'name'
        expect(toJson, contains("json['name']"));
      });

      test('writeOnly field in absentable schema is excluded from custom fromJson', () {
        final schema = FlorvalSchema(
          name: 'UpdateAccount',
          fields: [
            FlorvalField(
              name: 'username',
              jsonKey: 'username',
              type: FlorvalType(name: 'String', dartType: 'String'),
              isRequired: true,
            ),
            FlorvalField(
              name: 'secret',
              jsonKey: 'secret',
              type: FlorvalType(
                name: 'String',
                dartType: 'String?',
                isNullable: true,
              ),
              isRequired: false,
              absentable: true,
              writeOnly: true,
            ),
          ],
        );

        final code = generator.generate(schema);

        // fromJson should contain username but NOT secret
        final fromJson = code.substring(
          code.indexOf('factory UpdateAccount.fromJson'),
          code.indexOf('Map<String, dynamic> toJson()'),
        );
        expect(fromJson, contains("json['username']"));
        expect(fromJson, isNot(contains("json['secret']")));
        // toJson should still contain secret (it's writeOnly, not readOnly)
        final toJson = code.substring(code.indexOf('Map<String, dynamic> toJson()'));
        expect(toJson, contains("json['secret']"));
      });
    });

    group('title as doc comment fallback', () {
      test('uses title as doc comment when description is absent', () {
        final schema = FlorvalSchema(
          name: 'Pet',
          fields: [
            FlorvalField(
              name: 'name',
              jsonKey: 'name',
              type: FlorvalType(name: 'String', dartType: 'String'),
              isRequired: true,
            ),
          ],
          title: 'A pet in the store',
        );

        final code = generator.generate(schema);

        expect(code, contains('/// A pet in the store'));
        final docIndex = code.indexOf('/// A pet in the store');
        final freezedIndex = code.indexOf('@freezed');
        expect(docIndex, lessThan(freezedIndex));
      });

      test('description takes precedence over title', () {
        final schema = FlorvalSchema(
          name: 'Pet',
          fields: [
            FlorvalField(
              name: 'name',
              jsonKey: 'name',
              type: FlorvalType(name: 'String', dartType: 'String'),
              isRequired: true,
            ),
          ],
          title: 'Short title',
          description: 'Detailed description of a pet',
        );

        final code = generator.generate(schema);

        expect(code, contains('/// Detailed description of a pet'));
        expect(code, isNot(contains('/// Short title')));
      });

      test('no doc comment when both title and description are absent', () {
        final schema = FlorvalSchema(
          name: 'Pet',
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

        // Should not have any doc comment before @freezed
        final lines = code.split('\n');
        final freezedLineIndex = lines.indexWhere((l) => l.contains('@freezed'));
        if (freezedLineIndex > 0) {
          expect(lines[freezedLineIndex - 1].trim(), isNot(startsWith('///')));
        }
      });

      test('uses title for enum doc comment', () {
        final schema = FlorvalSchema(
          name: 'Status',
          fields: [],
          enumValues: ['active', 'inactive'],
          title: 'Pet status enum',
        );

        final code = generator.generate(schema);

        expect(code, contains('/// Pet status enum'));
      });
    });
  });
}
