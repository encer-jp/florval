import 'dart:io';

import 'package:yaml/yaml.dart';

/// Configuration loaded from florval.yaml.
class FlorvalConfig {
  /// Path to the OpenAPI spec file.
  final String schemaPath;

  /// Output directory for generated code.
  final String outputDirectory;

  /// Client configuration.
  final ClientConfig client;

  const FlorvalConfig({
    required this.schemaPath,
    required this.outputDirectory,
    this.client = const ClientConfig(),
  });

  /// Loads config from a YAML file.
  factory FlorvalConfig.fromFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw FlorvalConfigException('Config file not found: $path');
    }
    final content = file.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap?;
    if (yaml == null) {
      throw FlorvalConfigException('Invalid YAML in config file: $path');
    }
    return FlorvalConfig.fromYaml(yaml);
  }

  /// Creates config from parsed YAML.
  factory FlorvalConfig.fromYaml(YamlMap yaml) {
    final florval = yaml['florval'] as YamlMap?;
    if (florval == null) {
      throw FlorvalConfigException(
        'Missing "florval" key in config file.',
      );
    }

    final schemaPath = florval['schema_path'] as String?;
    if (schemaPath == null) {
      throw FlorvalConfigException(
        'Missing "schema_path" in florval config.',
      );
    }

    return FlorvalConfig(
      schemaPath: schemaPath,
      outputDirectory:
          (florval['output_directory'] as String?) ?? 'lib/api/generated',
      client: florval['client'] != null
          ? ClientConfig.fromYaml(florval['client'] as YamlMap)
          : const ClientConfig(),
    );
  }

  /// Creates config from CLI arguments (overrides).
  factory FlorvalConfig.fromArgs({
    required String schemaPath,
    required String outputDirectory,
  }) {
    return FlorvalConfig(
      schemaPath: schemaPath,
      outputDirectory: outputDirectory,
    );
  }
}

/// Client generation configuration.
class ClientConfig {
  /// Environment variable name for base URL.
  final String baseUrlEnv;

  /// Default request timeout in milliseconds.
  final int timeout;

  /// Retry configuration.
  final RetryConfig retry;

  const ClientConfig({
    this.baseUrlEnv = 'API_BASE_URL',
    this.timeout = 30000,
    this.retry = const RetryConfig(),
  });

  factory ClientConfig.fromYaml(YamlMap yaml) {
    return ClientConfig(
      baseUrlEnv: (yaml['base_url_env'] as String?) ?? 'API_BASE_URL',
      timeout: (yaml['timeout'] as int?) ?? 30000,
      retry: yaml['retry'] != null
          ? RetryConfig.fromYaml(yaml['retry'] as YamlMap)
          : const RetryConfig(),
    );
  }
}

/// Retry configuration.
class RetryConfig {
  /// Maximum retry attempts.
  final int maxAttempts;

  /// Initial delay between retries in milliseconds.
  final int delay;

  const RetryConfig({
    this.maxAttempts = 3,
    this.delay = 1000,
  });

  factory RetryConfig.fromYaml(YamlMap yaml) {
    return RetryConfig(
      maxAttempts: (yaml['max_attempts'] as int?) ?? 3,
      delay: (yaml['delay'] as int?) ?? 1000,
    );
  }
}

/// Exception thrown for config errors.
class FlorvalConfigException implements Exception {
  final String message;
  const FlorvalConfigException(this.message);

  @override
  String toString() => 'FlorvalConfigException: $message';
}
