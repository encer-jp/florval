import 'dart:io';

import 'package:yaml/yaml.dart';

/// Severity level for validation results.
enum ValidationSeverity { error, warning }

/// A single validation error or warning.
class ConfigValidationError {
  final String field;
  final String message;
  final ValidationSeverity severity;

  const ConfigValidationError({
    required this.field,
    required this.message,
    this.severity = ValidationSeverity.error,
  });

  @override
  String toString() =>
      '${severity == ValidationSeverity.warning ? "Warning" : "Error"} [$field]: $message';
}

/// Validates florval.yaml configuration.
class ConfigValidator {
  static const _validFlorvalKeys = {
    'schema_path',
    'output_directory',
    'client',
    'riverpod',
    'templates',
  };

  static const _validClientKeys = {
    'base_url_env',
    'timeout',
    'retry',
  };

  static const _validRetryKeys = {
    'max_attempts',
    'delay',
  };

  static const _validRiverpodKeys = {
    'enabled',
    'state_type',
  };

  static const _validTemplateKeys = {
    'header',
    'model_imports',
    'client_imports',
    'provider_imports',
  };

  static const _validStateTypes = {
    'async_notifier',
    'future_provider',
  };

  /// Validates a parsed YAML config and returns all errors/warnings.
  List<ConfigValidationError> validate(YamlMap yaml) {
    final errors = <ConfigValidationError>[];

    // Top-level: require 'florval' key
    final florval = yaml['florval'];
    if (florval == null) {
      errors.add(const ConfigValidationError(
        field: 'florval',
        message: 'Missing required "florval" key.',
      ));
      return errors;
    }

    if (florval is! YamlMap) {
      errors.add(const ConfigValidationError(
        field: 'florval',
        message: '"florval" must be a map.',
      ));
      return errors;
    }

    // Check for unknown keys
    _checkUnknownKeys(
        florval, _validFlorvalKeys, 'florval', errors);

    // schema_path: required string
    final schemaPath = florval['schema_path'];
    if (schemaPath == null) {
      errors.add(const ConfigValidationError(
        field: 'florval.schema_path',
        message: 'Missing required "schema_path".',
      ));
    } else if (schemaPath is! String) {
      errors.add(const ConfigValidationError(
        field: 'florval.schema_path',
        message: '"schema_path" must be a string.',
      ));
    } else if (!File(schemaPath).existsSync()) {
      errors.add(ConfigValidationError(
        field: 'florval.schema_path',
        message: 'Schema file not found: $schemaPath',
        severity: ValidationSeverity.warning,
      ));
    }

    // output_directory: optional string
    final outputDir = florval['output_directory'];
    if (outputDir != null && outputDir is! String) {
      errors.add(const ConfigValidationError(
        field: 'florval.output_directory',
        message: '"output_directory" must be a string.',
      ));
    }

    // client section
    final client = florval['client'];
    if (client != null) {
      if (client is! YamlMap) {
        errors.add(const ConfigValidationError(
          field: 'florval.client',
          message: '"client" must be a map.',
        ));
      } else {
        _validateClient(client, errors);
      }
    }

    // riverpod section
    final riverpod = florval['riverpod'];
    if (riverpod != null) {
      if (riverpod is! YamlMap) {
        errors.add(const ConfigValidationError(
          field: 'florval.riverpod',
          message: '"riverpod" must be a map.',
        ));
      } else {
        _validateRiverpod(riverpod, errors);
      }
    }

    // templates section
    final templates = florval['templates'];
    if (templates != null) {
      if (templates is! YamlMap) {
        errors.add(const ConfigValidationError(
          field: 'florval.templates',
          message: '"templates" must be a map.',
        ));
      } else {
        _checkUnknownKeys(
            templates, _validTemplateKeys, 'florval.templates', errors);
      }
    }

    return errors;
  }

  void _validateClient(
      YamlMap client, List<ConfigValidationError> errors) {
    _checkUnknownKeys(client, _validClientKeys, 'florval.client', errors);

    final baseUrlEnv = client['base_url_env'];
    if (baseUrlEnv != null && baseUrlEnv is! String) {
      errors.add(const ConfigValidationError(
        field: 'florval.client.base_url_env',
        message: '"base_url_env" must be a string.',
      ));
    }

    final timeout = client['timeout'];
    if (timeout != null) {
      if (timeout is! int) {
        errors.add(const ConfigValidationError(
          field: 'florval.client.timeout',
          message: '"timeout" must be an integer (milliseconds).',
        ));
      } else if (timeout <= 0) {
        errors.add(const ConfigValidationError(
          field: 'florval.client.timeout',
          message: '"timeout" must be a positive integer.',
        ));
      }
    }

    final retry = client['retry'];
    if (retry != null) {
      if (retry is! YamlMap) {
        errors.add(const ConfigValidationError(
          field: 'florval.client.retry',
          message: '"retry" must be a map.',
        ));
      } else {
        _validateRetry(retry, errors);
      }
    }
  }

  void _validateRetry(
      YamlMap retry, List<ConfigValidationError> errors) {
    _checkUnknownKeys(
        retry, _validRetryKeys, 'florval.client.retry', errors);

    final maxAttempts = retry['max_attempts'];
    if (maxAttempts != null) {
      if (maxAttempts is! int) {
        errors.add(const ConfigValidationError(
          field: 'florval.client.retry.max_attempts',
          message: '"max_attempts" must be an integer.',
        ));
      } else if (maxAttempts <= 0) {
        errors.add(const ConfigValidationError(
          field: 'florval.client.retry.max_attempts',
          message: '"max_attempts" must be a positive integer.',
        ));
      }
    }

    final delay = retry['delay'];
    if (delay != null) {
      if (delay is! int) {
        errors.add(const ConfigValidationError(
          field: 'florval.client.retry.delay',
          message: '"delay" must be an integer (milliseconds).',
        ));
      } else if (delay < 0) {
        errors.add(const ConfigValidationError(
          field: 'florval.client.retry.delay',
          message: '"delay" must be a non-negative integer.',
        ));
      }
    }
  }

  void _validateRiverpod(
      YamlMap riverpod, List<ConfigValidationError> errors) {
    _checkUnknownKeys(
        riverpod, _validRiverpodKeys, 'florval.riverpod', errors);

    final enabled = riverpod['enabled'];
    if (enabled != null && enabled is! bool) {
      errors.add(const ConfigValidationError(
        field: 'florval.riverpod.enabled',
        message: '"enabled" must be a boolean.',
      ));
    }

    final stateType = riverpod['state_type'];
    if (stateType != null) {
      if (stateType is! String) {
        errors.add(const ConfigValidationError(
          field: 'florval.riverpod.state_type',
          message: '"state_type" must be a string.',
        ));
      } else if (!_validStateTypes.contains(stateType)) {
        errors.add(ConfigValidationError(
          field: 'florval.riverpod.state_type',
          message:
              'Invalid state_type "$stateType". Must be one of: ${_validStateTypes.join(", ")}.',
        ));
      }
    }
  }

  void _checkUnknownKeys(YamlMap yaml, Set<String> validKeys,
      String prefix, List<ConfigValidationError> errors) {
    for (final key in yaml.keys) {
      if (!validKeys.contains(key)) {
        final suggestion = _suggestKey(key.toString(), validKeys);
        errors.add(ConfigValidationError(
          field: '$prefix.$key',
          message:
              'Unknown key "$key".'
              '${suggestion != null ? " Did you mean \"$suggestion\"?" : ""}',
          severity: ValidationSeverity.warning,
        ));
      }
    }
  }

  String? _suggestKey(String input, Set<String> validKeys) {
    final lower = input.toLowerCase();
    for (final key in validKeys) {
      final keyLower = key.toLowerCase();
      if (keyLower.contains(lower) || lower.contains(keyLower)) {
        return key;
      }
    }
    return null;
  }
}
