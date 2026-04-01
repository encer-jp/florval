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

  /// Lint configuration (post-generation commands).
  final LintConfig lint;

  const FlorvalConfig({
    required this.schemaPath,
    required this.outputDirectory,
    this.client = const ClientConfig(),
    this.riverpod = const RiverpodConfig(),
    this.templates = const TemplateConfig(),
    this.lint = const LintConfig(),
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
      lint: florval['lint'] != null
          ? LintConfig.fromYaml(florval['lint'] as YamlMap)
          : const LintConfig(),
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

  const ClientConfig({
    this.baseUrlEnv = 'API_BASE_URL',
    this.timeout = 30000,
  });

  factory ClientConfig.fromYaml(YamlMap yaml) {
    return ClientConfig(
      baseUrlEnv: (yaml['base_url_env'] as String?) ?? 'API_BASE_URL',
      timeout: (yaml['timeout'] as int?) ?? 30000,
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

  /// Retry configuration for GET providers.
  final RiverpodRetryConfig? retry;

  const RiverpodConfig({
    this.enabled = false,
    this.autoInvalidate = false,
    this.pagination = const [],
    this.retry,
  });

  factory RiverpodConfig.fromYaml(YamlMap yaml) {
    final paginationYaml = yaml['pagination'];
    final pagination = <PaginationConfig>[];

    if (paginationYaml is YamlMap) {
      // New format: { defaults: {...}, endpoints: [...] }
      final defaultsYaml = paginationYaml['defaults'] as YamlMap?;
      final defaultCursorParam = defaultsYaml?['cursor_param'] as String?;
      final defaultNextCursorField =
          defaultsYaml?['next_cursor_field'] as String?;
      final defaultItemsField = defaultsYaml?['items_field'] as String?;

      final endpointsList = paginationYaml['endpoints'] as YamlList?;
      if (endpointsList != null) {
        for (final entry in endpointsList) {
          if (entry is String) {
            // Shorthand: just operation_id string
            if (defaultCursorParam == null ||
                defaultNextCursorField == null ||
                defaultItemsField == null) {
              throw FlorvalConfigException(
                'Pagination endpoint "$entry" uses shorthand but '
                'defaults are incomplete. Provide cursor_param, '
                'next_cursor_field, and items_field in defaults.',
              );
            }
            pagination.add(PaginationConfig(
              operationId: entry,
              cursorParam: defaultCursorParam,
              nextCursorField: defaultNextCursorField,
              itemsField: defaultItemsField,
            ));
          } else if (entry is YamlMap) {
            // Map with operation_id + optional overrides
            pagination.add(PaginationConfig(
              operationId: entry['operation_id'] as String,
              cursorParam: (entry['cursor_param'] as String?) ??
                  defaultCursorParam ??
                  'after',
              nextCursorField: (entry['next_cursor_field'] as String?) ??
                  defaultNextCursorField ??
                  'nextCursor',
              itemsField: (entry['items_field'] as String?) ??
                  defaultItemsField ??
                  'items',
            ));
          }
        }
      }
    } else if (paginationYaml is YamlList) {
      // Legacy flat list format (backwards compatible)
      for (final entry in paginationYaml) {
        if (entry is YamlMap) {
          pagination.add(PaginationConfig.fromYaml(entry));
        }
      }
    }

    final retryYaml = yaml['retry'];
    final retry = retryYaml is YamlMap
        ? RiverpodRetryConfig.fromYaml(retryYaml)
        : null;

    return RiverpodConfig(
      enabled: (yaml['enabled'] as bool?) ?? false,
      autoInvalidate: (yaml['auto_invalidate'] as bool?) ?? false,
      pagination: pagination,
      retry: retry,
    );
  }
}

/// Retry configuration for Riverpod GET providers.
class RiverpodRetryConfig {
  /// Maximum retry attempts.
  final int maxAttempts;

  /// Initial delay between retries in milliseconds (linear backoff).
  final int delay;

  const RiverpodRetryConfig({
    this.maxAttempts = 3,
    this.delay = 1000,
  });

  factory RiverpodRetryConfig.fromYaml(YamlMap yaml) {
    return RiverpodRetryConfig(
      maxAttempts: (yaml['max_attempts'] as int?) ?? 3,
      delay: (yaml['delay'] as int?) ?? 1000,
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

/// Lint configuration for running commands after code generation.
class LintConfig {
  /// Shell commands to run after code generation.
  /// Each command is executed sequentially in the output directory.
  final List<String> commands;

  const LintConfig({
    this.commands = const [],
  });

  /// Whether any lint commands are configured.
  bool get enabled => commands.isNotEmpty;

  factory LintConfig.fromYaml(YamlMap yaml) {
    final commandsYaml = yaml['commands'];
    final commands = <String>[];
    if (commandsYaml is YamlList) {
      for (final cmd in commandsYaml) {
        if (cmd is String) {
          commands.add(cmd);
        }
      }
    }
    return LintConfig(commands: commands);
  }
}

/// Exception thrown for config errors.
class FlorvalConfigException implements Exception {
  final String message;
  const FlorvalConfigException(this.message);

  @override
  String toString() => 'FlorvalConfigException: $message';
}
