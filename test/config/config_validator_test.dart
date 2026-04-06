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

  group('ConfigValidator - riverpod.retry', () {
    final validator = ConfigValidator();

    test('accepts valid retry config', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
    retry:
      max_attempts: 3
      delay: 1000
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors, isEmpty);
    });

    test('errors when max_attempts is not an integer', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  riverpod:
    retry:
      max_attempts: "three"
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors.any((e) => e.field.contains('max_attempts')), isTrue);
      expect(
          errors.any((e) => e.message.contains('must be an integer')), isTrue);
    });

    test('errors when max_attempts is zero or negative', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  riverpod:
    retry:
      max_attempts: 0
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors.any((e) => e.field.contains('max_attempts')), isTrue);
      expect(errors.any((e) => e.message.contains('positive')), isTrue);
    });

    test('errors when delay is not an integer', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  riverpod:
    retry:
      delay: "fast"
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors.any((e) => e.field.contains('delay')), isTrue);
      expect(
          errors.any((e) => e.message.contains('must be an integer')), isTrue);
    });

    test('errors when delay is negative', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  riverpod:
    retry:
      delay: -100
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors.any((e) => e.field.contains('delay')), isTrue);
      expect(errors.any((e) => e.message.contains('non-negative')), isTrue);
    });

    test('warns on unknown keys in retry', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  riverpod:
    retry:
      max_attempts: 3
      unknown_key: value
''') as YamlMap;

      final warnings = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.warning)
          .toList();

      expect(
          warnings.any((e) => e.message.contains('unknown_key')), isTrue);
    });
  });

  group('ConfigValidator - lint', () {
    final validator = ConfigValidator();

    test('accepts valid lint config', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  lint:
    commands:
      - dart format .
      - dart fix --apply
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors, isEmpty);
    });

    test('errors when lint is not a map', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  lint: true
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors.any((e) => e.message.contains('"lint" must be a map')),
          isTrue);
    });

    test('errors when commands is not a list', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  lint:
    commands: "dart format ."
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(
          errors.any((e) => e.message.contains('must be a list of strings')),
          isTrue);
    });

    test('errors when command entry is not a string', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  lint:
    commands:
      - dart format .
      - 123
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors.any((e) => e.message.contains('must be a string')),
          isTrue);
    });

    test('errors when command is empty string', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  lint:
    commands:
      - ""
''') as YamlMap;

      final errors = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.error)
          .toList();

      expect(errors.any((e) => e.message.contains('must not be empty')),
          isTrue);
    });

    test('warns on unknown keys in lint', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  lint:
    commands:
      - dart format .
    unknown_key: value
''') as YamlMap;

      final warnings = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.warning)
          .toList();

      expect(
          warnings.any((e) => e.message.contains('unknown_key')), isTrue);
    });
  });

  group('ConfigValidator - client.retry deprecation', () {
    final validator = ConfigValidator();

    test('warns when client.retry is present', () {
      final yaml = loadYaml('''
florval:
  schema_path: api.yaml
  client:
    retry:
      max_attempts: 3
''') as YamlMap;

      final warnings = validator
          .validate(yaml)
          .where((e) => e.severity == ValidationSeverity.warning)
          .toList();

      expect(
          warnings.any((e) =>
              e.field == 'florval.client.retry' &&
              e.message.contains('moved to "riverpod.retry"')),
          isTrue);
    });
  });
}
