import 'package:test/test.dart';
import 'package:florval/src/model/analysis_result.dart';
import 'package:florval/src/model/api_endpoint.dart';
import 'package:florval/src/model/api_response.dart';
import 'package:florval/src/model/api_schema.dart';
import 'package:florval/src/model/api_type.dart';

void main() {
  group('absentable field marking logic', () {
    /// Mirrors FlorvalRunner._markAbsentableFields for unit testing.
    /// The private method is tested through this replica to validate
    /// the algorithm without requiring file I/O dependencies.

    bool isComplexObjectField(FlorvalType type) {
      if (type.isPrimitive) return false;
      if (type.dartType == 'MultipartFile' ||
          type.dartType == 'List<MultipartFile>') return false;
      if (type.isEnum) return false;
      if (type.isMap) return false;
      if (type.isList) return false;
      return true;
    }

    AnalysisResult markAbsentableFields(AnalysisResult analysis) {
      // Mirror the logic from FlorvalRunner._markAbsentableFields
      final absentableSchemaNames = <String>{};
      for (final endpoint in analysis.endpoints) {
        if ((endpoint.method == 'PATCH' || endpoint.method == 'PUT') &&
            endpoint.requestBody != null) {
          if (!endpoint.requestBody!.isMultipart) {
            absentableSchemaNames.add(endpoint.requestBody!.type.name);
          } else if (endpoint.requestBody!.formFields != null) {
            for (final field in endpoint.requestBody!.formFields!) {
              if (isComplexObjectField(field.type)) {
                absentableSchemaNames.add(field.type.name);
              }
            }
          }
        }
      }
      if (absentableSchemaNames.isEmpty) return analysis;

      List<FlorvalSchema> applyAbsentable(List<FlorvalSchema> schemas) {
        return schemas.map((schema) {
          if (!absentableSchemaNames.contains(schema.name)) return schema;
          return FlorvalSchema(
            name: schema.name,
            fields: schema.fields
                .map((f) => FlorvalField(
                      name: f.name,
                      jsonKey: f.jsonKey,
                      type: f.type,
                      isRequired: f.isRequired,
                      absentable: !f.isRequired,
                      defaultValue: f.defaultValue,
                      deprecated: f.deprecated,
                      description: f.description,
                      example: f.example,
                      readOnly: f.readOnly,
                      writeOnly: f.writeOnly,
                    ))
                .toList(),
            discriminator: schema.discriminator,
            oneOf: schema.oneOf,
            anyOf: schema.anyOf,
            allOf: schema.allOf,
            description: schema.description,
            title: schema.title,
            enumValues: schema.enumValues,
            deprecated: schema.deprecated,
          );
        }).toList();
      }

      return AnalysisResult(
        schemas: applyAbsentable(analysis.schemas),
        endpoints: analysis.endpoints,
        inlineUnionSchemas:
            applyAbsentable(analysis.inlineUnionSchemas),
        inlineObjectSchemas:
            applyAbsentable(analysis.inlineObjectSchemas),
      );
    }

    FlorvalSchema makeSchema(String name,
        {List<FlorvalField>? fields}) {
      return FlorvalSchema(
        name: name,
        fields: fields ??
            [
              FlorvalField(
                name: 'id',
                jsonKey: 'id',
                type: const FlorvalType(name: 'int', dartType: 'int'),
                isRequired: true,
              ),
              FlorvalField(
                name: 'name',
                jsonKey: 'name',
                type: const FlorvalType(
                  name: 'String',
                  dartType: 'String?',
                  isNullable: true,
                ),
                isRequired: false,
              ),
              FlorvalField(
                name: 'email',
                jsonKey: 'email',
                type: const FlorvalType(
                  name: 'String',
                  dartType: 'String?',
                  isNullable: true,
                ),
                isRequired: false,
              ),
            ],
      );
    }

    FlorvalEndpoint makeEndpoint(
      String method,
      String operationId, {
      String? requestBodyType,
      bool multipart = false,
      List<FlorvalField>? formFields,
    }) {
      return FlorvalEndpoint(
        path: '/test',
        method: method,
        operationId: operationId,
        parameters: [],
        requestBody: requestBodyType != null || (multipart && formFields != null)
            ? FlorvalRequestBody(
                type: FlorvalType(
                  name: multipart ? 'FormData' : requestBodyType!,
                  dartType: multipart ? 'FormData' : requestBodyType!,
                ),
                isRequired: true,
                contentType:
                    multipart ? ContentType.multipart : ContentType.json,
                formFields: formFields,
              )
            : null,
        responses: {
          200: const FlorvalResponse(
            statusCode: 200,
            description: 'OK',
          ),
        },
        tags: ['test'],
      );
    }

    test('marks non-required fields as absentable for PUT endpoint', () {
      final analysis = AnalysisResult(
        schemas: [makeSchema('UpdateUserRequest')],
        endpoints: [makeEndpoint('PUT', 'updateUser',
            requestBodyType: 'UpdateUserRequest')],
        inlineUnionSchemas: [],
        inlineObjectSchemas: [],
      );

      final result = markAbsentableFields(analysis);
      final schema = result.schemas.first;

      // Required field: NOT absentable
      expect(schema.fields[0].name, equals('id'));
      expect(schema.fields[0].isRequired, isTrue);
      expect(schema.fields[0].absentable, isFalse);

      // Non-required fields: absentable
      expect(schema.fields[1].name, equals('name'));
      expect(schema.fields[1].absentable, isTrue);
      expect(schema.fields[2].name, equals('email'));
      expect(schema.fields[2].absentable, isTrue);
    });

    test('marks non-required fields as absentable for PATCH endpoint', () {
      final analysis = AnalysisResult(
        schemas: [makeSchema('PatchUserRequest')],
        endpoints: [makeEndpoint('PATCH', 'patchUser',
            requestBodyType: 'PatchUserRequest')],
        inlineUnionSchemas: [],
        inlineObjectSchemas: [],
      );

      final result = markAbsentableFields(analysis);
      final schema = result.schemas.first;

      expect(schema.fields[1].absentable, isTrue);
      expect(schema.fields[2].absentable, isTrue);
    });

    test('does NOT mark fields for POST endpoint', () {
      final analysis = AnalysisResult(
        schemas: [makeSchema('CreateUserRequest')],
        endpoints: [makeEndpoint('POST', 'createUser',
            requestBodyType: 'CreateUserRequest')],
        inlineUnionSchemas: [],
        inlineObjectSchemas: [],
      );

      final result = markAbsentableFields(analysis);
      final schema = result.schemas.first;

      for (final field in schema.fields) {
        expect(field.absentable, isFalse,
            reason: 'POST fields should not be absentable');
      }
    });

    test('does NOT mark fields for GET endpoint', () {
      final analysis = AnalysisResult(
        schemas: [makeSchema('SomeRequest')],
        endpoints: [makeEndpoint('GET', 'getUser')],
        inlineUnionSchemas: [],
        inlineObjectSchemas: [],
      );

      final result = markAbsentableFields(analysis);

      for (final field in result.schemas.first.fields) {
        expect(field.absentable, isFalse);
      }
    });

    test('does NOT mark fields for multipart PUT without complex object form fields',
        () {
      final analysis = AnalysisResult(
        schemas: [makeSchema('UploadRequest')],
        endpoints: [
          makeEndpoint('PUT', 'upload', multipart: true, formFields: [
            FlorvalField(
              name: 'file',
              jsonKey: 'file',
              type: const FlorvalType(
                  name: 'MultipartFile', dartType: 'MultipartFile'),
              isRequired: true,
            ),
            FlorvalField(
              name: 'description',
              jsonKey: 'description',
              type: const FlorvalType(name: 'String', dartType: 'String'),
              isRequired: false,
            ),
          ]),
        ],
        inlineUnionSchemas: [],
        inlineObjectSchemas: [],
      );

      final result = markAbsentableFields(analysis);

      // UploadRequest schema is unrelated to the form fields,
      // so it should NOT be marked absentable
      for (final field in result.schemas.first.fields) {
        expect(field.absentable, isFalse,
            reason:
                'Schema unrelated to multipart form fields should not be absentable');
      }
    });

    test(
        'marks referenced DTO schema as absentable for multipart PATCH endpoint',
        () {
      final analysis = AnalysisResult(
        schemas: [makeSchema('UpdateUserDto')],
        endpoints: [
          makeEndpoint('PATCH', 'updateMe', multipart: true, formFields: [
            FlorvalField(
              name: 'updateUserDto',
              jsonKey: 'updateUserDto',
              type: const FlorvalType(
                name: 'UpdateUserDto',
                dartType: 'UpdateUserDto',
                ref: '#/components/schemas/UpdateUserDto',
              ),
              isRequired: false,
            ),
            FlorvalField(
              name: 'iconFile',
              jsonKey: 'iconFile',
              type: const FlorvalType(
                  name: 'MultipartFile', dartType: 'MultipartFile'),
              isRequired: false,
            ),
          ]),
        ],
        inlineUnionSchemas: [],
        inlineObjectSchemas: [],
      );

      final result = markAbsentableFields(analysis);
      final schema = result.schemas.first;

      // Required field: NOT absentable
      expect(schema.fields[0].name, equals('id'));
      expect(schema.fields[0].absentable, isFalse);

      // Non-required fields: absentable
      expect(schema.fields[1].name, equals('name'));
      expect(schema.fields[1].absentable, isTrue);
      expect(schema.fields[2].name, equals('email'));
      expect(schema.fields[2].absentable, isTrue);
    });

    test(
        'marks inline object schema as absentable for multipart PUT endpoint',
        () {
      // Inline objects have ref == null but are still complex DTOs
      final analysis = AnalysisResult(
        schemas: [],
        endpoints: [
          makeEndpoint('PUT', 'updateProfile', multipart: true, formFields: [
            FlorvalField(
              name: 'profileData',
              jsonKey: 'profileData',
              type: const FlorvalType(
                name: 'UpdateProfileProfileData',
                dartType: 'UpdateProfileProfileData',
                // No $ref — inline object
              ),
              isRequired: false,
            ),
            FlorvalField(
              name: 'avatar',
              jsonKey: 'avatar',
              type: const FlorvalType(
                  name: 'MultipartFile', dartType: 'MultipartFile'),
              isRequired: false,
            ),
          ]),
        ],
        inlineUnionSchemas: [],
        inlineObjectSchemas: [makeSchema('UpdateProfileProfileData')],
      );

      final result = markAbsentableFields(analysis);
      final schema = result.inlineObjectSchemas.first;

      // Non-required fields: absentable
      expect(schema.fields[1].absentable, isTrue);
      expect(schema.fields[2].absentable, isTrue);
    });

    test('does NOT mark primitive or file form fields as absentable schemas',
        () {
      final analysis = AnalysisResult(
        schemas: [
          makeSchema('String'),
          makeSchema('MultipartFile'),
        ],
        endpoints: [
          makeEndpoint('PATCH', 'updateItem', multipart: true, formFields: [
            FlorvalField(
              name: 'description',
              jsonKey: 'description',
              type: const FlorvalType(name: 'String', dartType: 'String'),
              isRequired: false,
            ),
            FlorvalField(
              name: 'file',
              jsonKey: 'file',
              type: const FlorvalType(
                  name: 'MultipartFile', dartType: 'MultipartFile'),
              isRequired: false,
            ),
          ]),
        ],
        inlineUnionSchemas: [],
        inlineObjectSchemas: [],
      );

      final result = markAbsentableFields(analysis);

      for (final schema in result.schemas) {
        for (final field in schema.fields) {
          expect(field.absentable, isFalse,
              reason:
                  'Primitive/file form fields should not cause absentable marking');
        }
      }
    });

    test('leaves unrelated schemas untouched', () {
      final analysis = AnalysisResult(
        schemas: [
          makeSchema('UpdateUserRequest'),
          makeSchema('User'),
        ],
        endpoints: [makeEndpoint('PUT', 'updateUser',
            requestBodyType: 'UpdateUserRequest')],
        inlineUnionSchemas: [],
        inlineObjectSchemas: [],
      );

      final result = markAbsentableFields(analysis);

      // UpdateUserRequest is marked
      expect(result.schemas[0].fields[1].absentable, isTrue);

      // User is NOT marked
      for (final field in result.schemas[1].fields) {
        expect(field.absentable, isFalse,
            reason: 'User schema should not be affected');
      }
    });

    test('preserves example, readOnly, writeOnly through absentable marking',
        () {
      final analysis = AnalysisResult(
        schemas: [
          FlorvalSchema(
            name: 'UpdateResource',
            fields: [
              FlorvalField(
                name: 'id',
                jsonKey: 'id',
                type: const FlorvalType(name: 'int', dartType: 'int'),
                isRequired: true,
                readOnly: true,
                example: 42,
              ),
              FlorvalField(
                name: 'name',
                jsonKey: 'name',
                type: const FlorvalType(
                  name: 'String',
                  dartType: 'String?',
                  isNullable: true,
                ),
                isRequired: false,
                description: 'Display name',
                example: 'Alice',
              ),
              FlorvalField(
                name: 'secret',
                jsonKey: 'secret',
                type: const FlorvalType(
                  name: 'String',
                  dartType: 'String?',
                  isNullable: true,
                ),
                isRequired: false,
                writeOnly: true,
              ),
            ],
          ),
        ],
        endpoints: [
          makeEndpoint('PATCH', 'updateResource',
              requestBodyType: 'UpdateResource'),
        ],
        inlineUnionSchemas: [],
        inlineObjectSchemas: [],
      );

      final result = markAbsentableFields(analysis);
      final fields = result.schemas.first.fields;

      // readOnly preserved
      expect(fields[0].readOnly, isTrue);
      expect(fields[0].example, 42);

      // example preserved on absentable field
      expect(fields[1].absentable, isTrue);
      expect(fields[1].example, 'Alice');
      expect(fields[1].description, 'Display name');

      // writeOnly preserved on absentable field
      expect(fields[2].absentable, isTrue);
      expect(fields[2].writeOnly, isTrue);
    });

    test('marks inline object schemas used by PATCH/PUT', () {
      final analysis = AnalysisResult(
        schemas: [],
        endpoints: [makeEndpoint('PATCH', 'patchItem',
            requestBodyType: 'PatchItemRequest')],
        inlineUnionSchemas: [],
        inlineObjectSchemas: [makeSchema('PatchItemRequest')],
      );

      final result = markAbsentableFields(analysis);

      expect(result.inlineObjectSchemas.first.fields[1].absentable, isTrue);
    });
  });
}
