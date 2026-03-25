import 'dart:io';

import 'package:test/test.dart';
import 'package:florval/src/config/florval_config.dart';

void main() {
  group('FlorvalConfig', () {
    test('loads from valid YAML file', () {
      final tmpFile = File('${Directory.systemTemp.path}/florval_test.yaml');
      tmpFile.writeAsStringSync('''
florval:
  schema_path: openapi.yaml
  output_directory: lib/api/generated
  client:
    base_url_env: MY_API_URL
    timeout: 60000
''');

      final config = FlorvalConfig.fromFile(tmpFile.path);

      expect(config.schemaPath, 'openapi.yaml');
      expect(config.outputDirectory, 'lib/api/generated');
      expect(config.client.baseUrlEnv, 'MY_API_URL');
      expect(config.client.timeout, 60000);

      tmpFile.deleteSync();
    });

    test('applies defaults for optional fields', () {
      final tmpFile = File('${Directory.systemTemp.path}/florval_test2.yaml');
      tmpFile.writeAsStringSync('''
florval:
  schema_path: api.yaml
''');

      final config = FlorvalConfig.fromFile(tmpFile.path);

      expect(config.schemaPath, 'api.yaml');
      expect(config.outputDirectory, 'lib/api/generated');
      expect(config.client.baseUrlEnv, 'API_BASE_URL');
      expect(config.client.timeout, 30000);

      tmpFile.deleteSync();
    });

    test('throws on missing file', () {
      expect(
        () => FlorvalConfig.fromFile('nonexistent.yaml'),
        throwsA(isA<FlorvalConfigException>()),
      );
    });

    test('throws on missing florval key', () {
      final tmpFile = File('${Directory.systemTemp.path}/florval_test3.yaml');
      tmpFile.writeAsStringSync('something_else: true\n');

      expect(
        () => FlorvalConfig.fromFile(tmpFile.path),
        throwsA(isA<FlorvalConfigException>()),
      );

      tmpFile.deleteSync();
    });

    test('throws on missing schema_path', () {
      final tmpFile = File('${Directory.systemTemp.path}/florval_test4.yaml');
      tmpFile.writeAsStringSync('''
florval:
  output_directory: lib/api/
''');

      expect(
        () => FlorvalConfig.fromFile(tmpFile.path),
        throwsA(isA<FlorvalConfigException>()),
      );

      tmpFile.deleteSync();
    });

    test('creates from args', () {
      final config = FlorvalConfig.fromArgs(
        schemaPath: 'spec.yaml',
        outputDirectory: 'output/',
      );

      expect(config.schemaPath, 'spec.yaml');
      expect(config.outputDirectory, 'output/');
    });

    test('loads riverpod config from YAML', () {
      final tmpFile = File('${Directory.systemTemp.path}/florval_test_rp.yaml');
      tmpFile.writeAsStringSync('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
''');

      final config = FlorvalConfig.fromFile(tmpFile.path);

      expect(config.riverpod.enabled, isTrue);
      expect(config.riverpod.autoInvalidate, isFalse);

      tmpFile.deleteSync();
    });

    test('loads riverpod auto_invalidate from YAML', () {
      final tmpFile = File('${Directory.systemTemp.path}/florval_test_rp_ai.yaml');
      tmpFile.writeAsStringSync('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
    auto_invalidate: true
''');

      final config = FlorvalConfig.fromFile(tmpFile.path);

      expect(config.riverpod.autoInvalidate, isTrue);

      tmpFile.deleteSync();
    });

    test('riverpod defaults to disabled', () {
      final tmpFile =
          File('${Directory.systemTemp.path}/florval_test_rp2.yaml');
      tmpFile.writeAsStringSync('''
florval:
  schema_path: api.yaml
''');

      final config = FlorvalConfig.fromFile(tmpFile.path);

      expect(config.riverpod.enabled, isFalse);
      expect(config.riverpod.autoInvalidate, isFalse);

      tmpFile.deleteSync();
    });

    test('loads pagination config with defaults and shorthand', () {
      final tmpFile =
          File('${Directory.systemTemp.path}/florval_test_pg.yaml');
      tmpFile.writeAsStringSync('''
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
        - listPets
        - listUsers
''');

      final config = FlorvalConfig.fromFile(tmpFile.path);

      expect(config.riverpod.pagination.length, 2);
      expect(config.riverpod.pagination[0].operationId, 'listPets');
      expect(config.riverpod.pagination[0].cursorParam, 'after');
      expect(config.riverpod.pagination[0].nextCursorField, 'nextCursor');
      expect(config.riverpod.pagination[0].itemsField, 'items');
      expect(config.riverpod.pagination[1].operationId, 'listUsers');
      expect(config.riverpod.pagination[1].cursorParam, 'after');

      tmpFile.deleteSync();
    });

    test('pagination endpoint overrides defaults', () {
      final tmpFile =
          File('${Directory.systemTemp.path}/florval_test_pg_ov.yaml');
      tmpFile.writeAsStringSync('''
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
        - listPets
        - operation_id: listOrders
          cursor_param: cursor
          items_field: edges
''');

      final config = FlorvalConfig.fromFile(tmpFile.path);

      expect(config.riverpod.pagination.length, 2);
      expect(config.riverpod.pagination[0].operationId, 'listPets');
      expect(config.riverpod.pagination[0].cursorParam, 'after');
      expect(config.riverpod.pagination[1].operationId, 'listOrders');
      expect(config.riverpod.pagination[1].cursorParam, 'cursor');
      expect(config.riverpod.pagination[1].nextCursorField, 'nextCursor');
      expect(config.riverpod.pagination[1].itemsField, 'edges');

      tmpFile.deleteSync();
    });

    test('pagination legacy flat list still works', () {
      final tmpFile =
          File('${Directory.systemTemp.path}/florval_test_pg_legacy.yaml');
      tmpFile.writeAsStringSync('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
    pagination:
      - operation_id: listPets
        cursor_param: after
        next_cursor_field: nextCursor
        items_field: items
''');

      final config = FlorvalConfig.fromFile(tmpFile.path);

      expect(config.riverpod.pagination.length, 1);
      expect(config.riverpod.pagination[0].operationId, 'listPets');
      expect(config.riverpod.pagination[0].cursorParam, 'after');

      tmpFile.deleteSync();
    });

    test('pagination defaults to empty list', () {
      final tmpFile =
          File('${Directory.systemTemp.path}/florval_test_pg2.yaml');
      tmpFile.writeAsStringSync('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
''');

      final config = FlorvalConfig.fromFile(tmpFile.path);

      expect(config.riverpod.pagination, isEmpty);

      tmpFile.deleteSync();
    });

    test('loads riverpod retry config from YAML', () {
      final tmpFile =
          File('${Directory.systemTemp.path}/florval_test_retry.yaml');
      tmpFile.writeAsStringSync('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
    retry:
      max_attempts: 5
      delay: 2000
''');

      final config = FlorvalConfig.fromFile(tmpFile.path);

      expect(config.riverpod.retry, isNotNull);
      expect(config.riverpod.retry!.maxAttempts, 5);
      expect(config.riverpod.retry!.delay, 2000);

      tmpFile.deleteSync();
    });

    test('riverpod retry defaults when partially specified', () {
      final tmpFile =
          File('${Directory.systemTemp.path}/florval_test_retry2.yaml');
      tmpFile.writeAsStringSync('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
    retry:
      max_attempts: 5
''');

      final config = FlorvalConfig.fromFile(tmpFile.path);

      expect(config.riverpod.retry, isNotNull);
      expect(config.riverpod.retry!.maxAttempts, 5);
      expect(config.riverpod.retry!.delay, 1000);

      tmpFile.deleteSync();
    });

    test('riverpod retry is null when not specified', () {
      final tmpFile =
          File('${Directory.systemTemp.path}/florval_test_retry3.yaml');
      tmpFile.writeAsStringSync('''
florval:
  schema_path: api.yaml
  riverpod:
    enabled: true
''');

      final config = FlorvalConfig.fromFile(tmpFile.path);

      expect(config.riverpod.retry, isNull);

      tmpFile.deleteSync();
    });
  });
}
