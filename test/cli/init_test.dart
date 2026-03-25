import 'dart:io';

import 'package:florval/src/config/florval_config.dart';
import 'package:florval/src/init/init_command.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  late Directory tempDir;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('florval_init_test_');
  });

  tearDown(() {
    tempDir.deleteSync(recursive: true);
  });

  group('InitCommand', () {
    test('creates template file at specified path', () {
      final configPath = '${tempDir.path}/florval.yaml';

      final result =
          InitCommand.run(configPath: configPath, force: false);

      expect(result, equals(InitResult.created));
      expect(File(configPath).existsSync(), isTrue);
    });

    test('generated file is valid YAML', () {
      final configPath = '${tempDir.path}/florval.yaml';
      InitCommand.run(configPath: configPath, force: false);

      final content = File(configPath).readAsStringSync();
      final yaml = loadYaml(content);

      expect(yaml, isA<YamlMap>());
      expect((yaml as YamlMap).containsKey('florval'), isTrue);
    });

    test('generated file contains schema_path', () {
      final configPath = '${tempDir.path}/florval.yaml';
      InitCommand.run(configPath: configPath, force: false);

      final content = File(configPath).readAsStringSync();
      expect(content, contains('schema_path'));
    });

    test('generated file can be parsed by FlorvalConfig.fromFile', () {
      final configPath = '${tempDir.path}/florval.yaml';
      InitCommand.run(configPath: configPath, force: false);

      final config = FlorvalConfig.fromFile(configPath);

      expect(config.schemaPath, equals('openapi.yaml'));
      expect(config.outputDirectory, equals('lib/api/generated'));
      expect(config.client.baseUrlEnv, equals('API_BASE_URL'));
      expect(config.client.timeout, equals(30000));
      expect(config.riverpod.enabled, isTrue);
      expect(config.riverpod.autoInvalidate, isTrue);
      expect(config.riverpod.retry, isNotNull);
      expect(config.riverpod.retry!.maxAttempts, equals(3));
      expect(config.riverpod.retry!.delay, equals(1000));
    });

    test('returns alreadyExists when file exists and force is false', () {
      final configPath = '${tempDir.path}/florval.yaml';
      File(configPath).writeAsStringSync('existing content');

      final result =
          InitCommand.run(configPath: configPath, force: false);

      expect(result, equals(InitResult.alreadyExists));
      // Original content should be preserved
      expect(File(configPath).readAsStringSync(), equals('existing content'));
    });

    test('overwrites existing file when force is true', () {
      final configPath = '${tempDir.path}/florval.yaml';
      File(configPath).writeAsStringSync('existing content');

      final result =
          InitCommand.run(configPath: configPath, force: true);

      expect(result, equals(InitResult.created));
      expect(File(configPath).readAsStringSync(),
          equals(InitCommand.configTemplate));
    });

    test('creates file at custom path with --config', () {
      final configPath = '${tempDir.path}/custom.yaml';

      final result =
          InitCommand.run(configPath: configPath, force: false);

      expect(result, equals(InitResult.created));
      expect(File(configPath).existsSync(), isTrue);
    });
  });

  group('CLI integration', () {
    test('dart run florval init creates florval.yaml', () async {
      final result = await Process.run(
        'dart',
        ['run', 'florval', 'init', '--config', '${tempDir.path}/florval.yaml'],
        workingDirectory: '/home/user/florval',
      );

      expect(result.exitCode, equals(0));
      expect(
          result.stdout.toString(), contains('Created ${tempDir.path}/florval.yaml'));
      expect(File('${tempDir.path}/florval.yaml').existsSync(), isTrue);
    });

    test('exits with error when file already exists', () async {
      final configPath = '${tempDir.path}/florval.yaml';
      File(configPath).writeAsStringSync('existing');

      final result = await Process.run(
        'dart',
        ['run', 'florval', 'init', '--config', configPath],
        workingDirectory: '/home/user/florval',
      );

      expect(result.exitCode, equals(1));
      expect(result.stderr.toString(), contains('already exists'));
      expect(result.stderr.toString(), contains('--force'));
    });

    test('overwrites with --force flag', () async {
      final configPath = '${tempDir.path}/florval.yaml';
      File(configPath).writeAsStringSync('existing');

      final result = await Process.run(
        'dart',
        ['run', 'florval', 'init', '--config', configPath, '--force'],
        workingDirectory: '/home/user/florval',
      );

      expect(result.exitCode, equals(0));
      expect(File(configPath).readAsStringSync(),
          equals(InitCommand.configTemplate));
    });
  });
}
