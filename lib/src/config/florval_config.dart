import 'dart:io';

import 'package:yaml/yaml.dart';

import 'config_validator.dart';
import 'template_config.dart';

/// Configuration loaded from florval.yaml.
class FlorvalConfig {
  /// Path to the OpenAPI spec file.
  final String schemaPath;

  /// Output directory for generated code.
  final String outputDirectory;

  /// Client configuration.
  final ClientConfig client;

  /// Riverpod configuration.
  final RiverpodConfig riverpod;

  /// Template customization configuration.
  final TemplateConfig templates;

  const FlorvalConfig({
    required this.schemaPath,
    required this.outputDirectory,
    this.client = const ClientConfig(),
    this.riverpod = const RiverpodConfig(),
    this.templates = const TemplateConfig(),
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
    // Validate config
    final validator = ConfigValidator();
    final validationErrors = validator.validate(yaml);

    final errors = validationErrors
        .where((e) => e.severity == ValidationSeverity.error)
        .toList();
    final warnings = validationErrors
        .where((e) => e.severity == ValidationSeverity.warning)
        .toList();

    // Print warnings to stderr
    for (final warning in warnings) {
      stderr.writeln('florval [WARN]: $warning');
    }

    // Throw on errors
    if (errors.isNotEmpty) {
      throw FlorvalConfigException(
        errors.map((e) => e.toString()).join('\n'),
      );
    }

    final florval = yaml['florval'] as YamlMap;
    final schemaPath = florval['schema_path'] as String;

    return FlorvalConfig(
      schemaPath: schemaPath,
      outputDirectory:
          (florval['output_directory'] as String?) ?? 'lib/api/generated',
      client: florval['client'] != null
          ? ClientConfig.fromYaml(florval['client'] as YamlMap)
          : const ClientConfig(),
      riverpod: florval['riverpod'] != null
          ? RiverpodConfig.fromYaml(florval['riverpod'] as YamlMap)
          : const RiverpodConfig(),
      templates: florval['templates'] != null
          ? TemplateConfig.fromYaml(florval['templates'] as YamlMap)
          : const TemplateConfig(),
    );
  }

  /// Creates config from CLI arguments (overrides).
  factory FlorvalConfig.fromArgs({
    required String schemaPath,
    required String outputDirectory,
    RiverpodConfig riverpod = const RiverpodConfig(),
  }) {
    return FlorvalConfig(
      schemaPath: schemaPath,
      outputDirectory: outputDirectory,
      riverpod: riverpod,
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

/// Riverpod generation configuration.
class RiverpodConfig {
  /// Whether to generate Riverpod providers.
  final bool enabled;

  /// Whether to auto-invalidate same-tag GET providers after mutations.
  final bool autoInvalidate;

  /// Pagination configurations for cursor-based paginated endpoints.
  final List<PaginationConfig> pagination;

  const RiverpodConfig({
    this.enabled = false,
    this.autoInvalidate = false,
    this.pagination = const [],
  });

  factory RiverpodConfig.fromYaml(YamlMap yaml) {
    final paginationList = yaml['pagination'];
    final pagination = <PaginationConfig>[];
    if (paginationList is YamlList) {
      for (final entry in paginationList) {
        if (entry is YamlMap) {
          pagination.add(PaginationConfig.fromYaml(entry));
        }
      }
    }

    return RiverpodConfig(
      enabled: (yaml['enabled'] as bool?) ?? false,
      autoInvalidate: (yaml['auto_invalidate'] as bool?) ?? false,
      pagination: pagination,
    );
  }
}

/// Configuration for a single cursor-based paginated endpoint.
class PaginationConfig {
  /// The operationId of the endpoint to apply pagination to.
  final String operationId;

  /// The query parameter name used as the cursor (e.g. 'after').
  final String cursorParam;

  /// The response field name containing the next cursor value.
  final String nextCursorField;

  /// The response field name containing the data items array.
  final String itemsField;

  const PaginationConfig({
    required this.operationId,
    required this.cursorParam,
    required this.nextCursorField,
    required this.itemsField,
  });

  factory PaginationConfig.fromYaml(YamlMap yaml) {
    return PaginationConfig(
      operationId: yaml['operation_id'] as String,
      cursorParam: yaml['cursor_param'] as String,
      nextCursorField: yaml['next_cursor_field'] as String,
      itemsField: yaml['items_field'] as String,
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
