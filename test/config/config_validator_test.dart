import 'package:test/test.dart';
import 'package:yaml/yaml.dart';
import 'package:florval/src/config/config_validator.dart';

void main() {
  group('ConfigValidator - pagination', () {
    final validator = ConfigValidator();

    test('accepts valid pagination config', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
    pagination:
      - operation_id: listPets
        cursor_param: after
        next_cursor_field: nextCursor
        items_field: items
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors, isEmpty);
    });

    test('errors on missing required pagination fields', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
    pagination:
      - operation_id: listPets
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors.length, 3); // cursor_param, next_cursor_field, items_field
      expect(errors.any((e) => e.field.contains('cursor_param')), isTrue);
      expect(errors.any((e) => e.field.contains('next_cursor_field')), isTrue);
      expect(errors.any((e) => e.field.contains('items_field')), isTrue);
    });

    test('errors when pagination entry is not a map', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
    pagination:
      - not_a_map
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors.any((e) => e.message.contains('must be a map')), isTrue);
    });

    test('accepts new map format with defaults and endpoints', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
    pagination:
      defaults:
        cursor_param: after
        next_cursor_field: nextCursor
        items_field: items
      endpoints:
        - searchPets
        - operation_id: listOrders
          cursor_param: cursor
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors, isEmpty);
    });

    test('errors when pagination is not a list or map', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
    pagination: invalid
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors.any((e) => e.message.contains('must be a map')), isTrue);
    });

    test('warns on unknown keys in pagination entry', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
    pagination:
      - operation_id: listPets
        cursor_param: after
        next_cursor_field: nextCursor
        items_field: items
        unknown_key: value
''') as YamlMap;

      final warnings = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.warning)
          .toList();

      expect(warnings.any((e) => e.message.contains('unknown_key')), isTrue);
    });

    test('errors when pagination field is not a string', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
    pagination:
      - operation_id: 123
        cursor_param: after
        next_cursor_field: nextCursor
        items_field: items
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors.any((e) => e.field.contains('operation_id')), isTrue);
      expect(errors.any((e) => e.message.contains('must be a string')), isTrue);
    });
  });
}
