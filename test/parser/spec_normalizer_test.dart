import 'package:test/test.dart';
import 'package:florval/src/parser/spec_normalizer.dart';

void main() {
  late SpecNormalizer normalizer;

  setUp(() {
    normalizer = SpecNormalizer();
  });

  group('detectVersion', () {
    test('detects OpenAPI 3.0', () {
      expect(normalizer.detectVersion({'openapi': '3.0.3'}), '3.0');
    });

    test('detects OpenAPI 3.1', () {
      expect(normalizer.detectVersion({'openapi': '3.1.0'}), '3.1');
    });

    test('detects Swagger 2.0', () {
      expect(normalizer.detectVersion({'swagger': '2.0'}), '2.0');
    });
  });

  group('normalizeV30', () {
    group('nullable conversion', () {
      test('converts nullable: true to type array', () {
        final spec = _makeSpec(schemas: {
          'Foo': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string', 'nullable': true},
            },
          },
        });

        final result = normalizer.normalizeV30(spec);
        final nameSchema = _getSchema(result, 'Foo', 'name');

        expect(nameSchema['type'], ['string', 'null']);
        expect(nameSchema.containsKey('nullable'), isFalse);
      });

      test('removes nullable: false without changing type', () {
        final spec = _makeSpec(schemas: {
          'Foo': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string', 'nullable': false},
            },
          },
        });

        final result = normalizer.normalizeV30(spec);
        final nameSchema = _getSchema(result, 'Foo', 'name');

        expect(nameSchema['type'], 'string');
        expect(nameSchema.containsKey('nullable'), isFalse);
      });

      test('does not modify type when nullable is absent', () {
        final spec = _makeSpec(schemas: {
          'Foo': {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
            },
          },
        });

        final result = normalizer.normalizeV30(spec);
        final nameSchema = _getSchema(result, 'Foo', 'name');

        expect(nameSchema['type'], 'string');
      });
    });

    group('exclusiveMinimum conversion', () {
      test('converts exclusiveMinimum: true with minimum to number', () {
        final spec = _makeSpec(schemas: {
          'Foo': {
            'type': 'object',
            'properties': {
              'age': {
                'type': 'integer',
                'minimum': 5,
                'exclusiveMinimum': true,
              },
            },
          },
        });

        final result = normalizer.normalizeV30(spec);
        final ageSchema = _getSchema(result, 'Foo', 'age');

        expect(ageSchema['exclusiveMinimum'], 5);
        expect(ageSchema.containsKey('minimum'), isFalse);
      });

      test('removes exclusiveMinimum: false and keeps minimum', () {
        final spec = _makeSpec(schemas: {
          'Foo': {
            'type': 'object',
            'properties': {
              'age': {
                'type': 'integer',
                'minimum': 5,
                'exclusiveMinimum': false,
              },
            },
          },
        });

        final result = normalizer.normalizeV30(spec);
        final ageSchema = _getSchema(result, 'Foo', 'age');

        expect(ageSchema['minimum'], 5);
        expect(ageSchema.containsKey('exclusiveMinimum'), isFalse);
      });
    });

    group('exclusiveMaximum conversion', () {
      test('converts exclusiveMaximum: true with maximum to number', () {
        final spec = _makeSpec(schemas: {
          'Foo': {
            'type': 'object',
            'properties': {
              'weight': {
                'type': 'number',
                'maximum': 10,
                'exclusiveMaximum': true,
              },
            },
          },
        });

        final result = normalizer.normalizeV30(spec);
        final weightSchema = _getSchema(result, 'Foo', 'weight');

        expect(weightSchema['exclusiveMaximum'], 10);
        expect(weightSchema.containsKey('maximum'), isFalse);
      });

      test('removes exclusiveMaximum: false and keeps maximum', () {
        final spec = _makeSpec(schemas: {
          'Foo': {
            'type': 'object',
            'properties': {
              'weight': {
                'type': 'number',
                'maximum': 10,
                'exclusiveMaximum': false,
              },
            },
          },
        });

        final result = normalizer.normalizeV30(spec);
        final weightSchema = _getSchema(result, 'Foo', 'weight');

        expect(weightSchema['maximum'], 10);
        expect(weightSchema.containsKey('exclusiveMaximum'), isFalse);
      });
    });

    group('nested schema traversal', () {
      test('normalizes schemas inside properties', () {
        final spec = _makeSpec(schemas: {
          'Outer': {
            'type': 'object',
            'properties': {
              'inner': {
                'type': 'object',
                'properties': {
                  'value': {'type': 'string', 'nullable': true},
                },
              },
            },
          },
        });

        final result = normalizer.normalizeV30(spec);
        final innerProps = (result['components'] as Map)['schemas']['Outer']
            ['properties']['inner']['properties'];
        final valueSchema = innerProps['value'] as Map<String, dynamic>;

        expect(valueSchema['type'], ['string', 'null']);
        expect(valueSchema.containsKey('nullable'), isFalse);
      });

      test('normalizes schemas inside items (array)', () {
        final spec = _makeSpec(schemas: {
          'Foo': {
            'type': 'object',
            'properties': {
              'tags': {
                'type': 'array',
                'items': {'type': 'string', 'nullable': true},
              },
            },
          },
        });

        final result = normalizer.normalizeV30(spec);
        final items = _getSchema(result, 'Foo', 'tags')['items']
            as Map<String, dynamic>;

        expect(items['type'], ['string', 'null']);
      });

      test('normalizes schemas inside allOf', () {
        final spec = _makeSpec(schemas: {
          'Foo': {
            'allOf': [
              {
                'type': 'object',
                'properties': {
                  'name': {'type': 'string', 'nullable': true},
                },
              },
            ],
          },
        });

        final result = normalizer.normalizeV30(spec);
        final allOf = (result['components'] as Map)['schemas']['Foo']['allOf']
            as List;
        final nameSchema =
            (allOf[0] as Map)['properties']['name'] as Map<String, dynamic>;

        expect(nameSchema['type'], ['string', 'null']);
      });

      test('converts nullable to type array on allOf wrapper without type', () {
        final spec = _makeSpec(schemas: {
          'Bar': {
            'type': 'object',
            'properties': {
              'tenant': {
                'nullable': true,
                'allOf': [
                  {r'$ref': '#/components/schemas/Tenant'},
                ],
              },
            },
          },
          'Tenant': {
            'type': 'object',
            'properties': {
              'id': {'type': 'string'},
            },
          },
        });

        final result = normalizer.normalizeV30(spec);
        final tenantSchema = _getSchema(result, 'Bar', 'tenant');

        expect(tenantSchema['type'], ['null']);
        expect(tenantSchema['nullable'], isNull);
        expect(tenantSchema['allOf'], isNotNull);
      });

      test('normalizes schemas inside oneOf', () {
        final spec = _makeSpec(schemas: {
          'Foo': {
            'oneOf': [
              {'type': 'string', 'nullable': true},
            ],
          },
        });

        final result = normalizer.normalizeV30(spec);
        final oneOf = (result['components'] as Map)['schemas']['Foo']['oneOf']
            as List;

        expect((oneOf[0] as Map)['type'], ['string', 'null']);
      });
    });

    group('paths and parameters traversal', () {
      test('normalizes schemas in path parameter schemas', () {
        final spec = <String, dynamic>{
          'openapi': '3.0.3',
          'info': {'title': 'Test', 'version': '1.0.0'},
          'paths': {
            '/items': {
              'get': {
                'operationId': 'listItems',
                'parameters': [
                  {
                    'name': 'filter',
                    'in': 'query',
                    'schema': {'type': 'string', 'nullable': true},
                  },
                ],
                'responses': {
                  '200': {'description': 'OK'},
                },
              },
            },
          },
        };

        final result = normalizer.normalizeV30(spec);
        final paramSchema = (result['paths'] as Map)['/items']['get']
            ['parameters'][0]['schema'] as Map<String, dynamic>;

        expect(paramSchema['type'], ['string', 'null']);
        expect(paramSchema.containsKey('nullable'), isFalse);
      });

      test('normalizes schemas in response content', () {
        final spec = <String, dynamic>{
          'openapi': '3.0.3',
          'info': {'title': 'Test', 'version': '1.0.0'},
          'paths': {
            '/items': {
              'get': {
                'operationId': 'listItems',
                'responses': {
                  '200': {
                    'description': 'OK',
                    'content': {
                      'application/json': {
                        'schema': {
                          'type': 'object',
                          'properties': {
                            'name': {'type': 'string', 'nullable': true},
                          },
                        },
                      },
                    },
                  },
                },
              },
            },
          },
        };

        final result = normalizer.normalizeV30(spec);
        final schema = (result['paths'] as Map)['/items']['get']['responses']
            ['200']['content']['application/json']['schema'] as Map;
        final nameSchema = schema['properties']['name'] as Map<String, dynamic>;

        expect(nameSchema['type'], ['string', 'null']);
      });

      test('normalizes schemas in requestBody content', () {
        final spec = <String, dynamic>{
          'openapi': '3.0.3',
          'info': {'title': 'Test', 'version': '1.0.0'},
          'paths': {
            '/items': {
              'post': {
                'operationId': 'createItem',
                'requestBody': {
                  'content': {
                    'application/json': {
                      'schema': {
                        'type': 'object',
                        'properties': {
                          'value': {
                            'type': 'integer',
                            'minimum': 0,
                            'exclusiveMinimum': true,
                          },
                        },
                      },
                    },
                  },
                },
                'responses': {
                  '201': {'description': 'Created'},
                },
              },
            },
          },
        };

        final result = normalizer.normalizeV30(spec);
        final schema = (result['paths'] as Map)['/items']['post']['requestBody']
            ['content']['application/json']['schema'] as Map;
        final valueSchema =
            schema['properties']['value'] as Map<String, dynamic>;

        expect(valueSchema['exclusiveMinimum'], 0);
        expect(valueSchema.containsKey('minimum'), isFalse);
      });

      test('normalizes schemas in components.parameters', () {
        final spec = <String, dynamic>{
          'openapi': '3.0.3',
          'info': {'title': 'Test', 'version': '1.0.0'},
          'paths': {},
          'components': {
            'parameters': {
              'OptionalFilter': {
                'name': 'filter',
                'in': 'query',
                'schema': {'type': 'string', 'nullable': true},
              },
            },
          },
        };

        final result = normalizer.normalizeV30(spec);
        final paramSchema = (result['components'] as Map)['parameters']
            ['OptionalFilter']['schema'] as Map<String, dynamic>;

        expect(paramSchema['type'], ['string', 'null']);
        expect(paramSchema.containsKey('nullable'), isFalse);
      });
    });

    test('sets openapi version to 3.1.0', () {
      final spec = <String, dynamic>{
        'openapi': '3.0.3',
        'info': {'title': 'Test', 'version': '1.0.0'},
        'paths': {},
      };

      final result = normalizer.normalizeV30(spec);
      expect(result['openapi'], '3.1.0');
    });
  });
}

/// Helper to create a minimal spec with component schemas.
Map<String, dynamic> _makeSpec({
  required Map<String, dynamic> schemas,
}) {
  return {
    'openapi': '3.0.3',
    'info': {'title': 'Test', 'version': '1.0.0'},
    'paths': {},
    'components': {
      'schemas': schemas,
    },
  };
}

/// Helper to get a property schema from a component schema.
Map<String, dynamic> _getSchema(
    Map<String, dynamic> spec, String schemaName, String propertyName) {
  return ((spec['components'] as Map)['schemas'] as Map)[schemaName]
      ['properties'][propertyName] as Map<String, dynamic>;
}
