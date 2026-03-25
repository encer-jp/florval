import 'dart:convert';
import 'dart:io';

import 'package:openapi_spec_plus/v31.dart' as v31;
import 'package:yaml/yaml.dart';

import 'spec_normalizer.dart';

/// Reads and parses OpenAPI specification files.
/// Supports OpenAPI 3.1, 3.0, and Swagger 2.0 via auto-detection
/// and normalization to v3.1 format.
class SpecReader {
  final SpecNormalizer _normalizer = SpecNormalizer();

  /// Parses an OpenAPI spec file (YAML or JSON).
  v31.OpenAPI readFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw SpecReaderException(
        'OpenAPI spec file not found: $path\n'
        '  Ensure the path in florval.yaml (schema_path) is correct.',
      );
    }

    final content = file.readAsStringSync();
    if (content.trim().isEmpty) {
      throw SpecReaderException(
        'OpenAPI spec file is empty: $path',
      );
    }

    return parse(content, path: path);
  }

  /// Parses OpenAPI spec from string content.
  /// Auto-detects version and normalizes to v3.1 if needed.
  v31.OpenAPI parse(String content, {String? path}) {
    try {
      // Parse raw YAML/JSON to a Map for version detection
      final isJson = path != null && path.endsWith('.json');
      final dynamic raw = isJson ? jsonDecode(content) : loadYaml(content);

      if (raw is! Map) {
        throw SpecReaderException(
          'OpenAPI spec must be a YAML/JSON object, got ${raw.runtimeType}.',
        );
      }

      final rawMap = _toStringDynMap(raw);
      final version = _normalizer.detectVersion(rawMap);

      Map<String, dynamic> normalizedMap;
      switch (version) {
        case '2.0':
          normalizedMap = _normalizer.normalizeV20(rawMap);
        case '3.0':
          normalizedMap = _normalizer.normalizeV30(rawMap);
        case '3.1':
          // Already v3.1, parse directly
          if (isJson) {
            return v31.OpenAPIParser.parseJson(content);
          }
          return v31.OpenAPIParser.parseYaml(content);
        default:
          throw SpecReaderException(
            'Cannot detect OpenAPI version from spec${path != null ? " '$path'" : ""}.\n'
            '  Expected "openapi: 3.x.x" or "swagger: 2.0" at the top of the file.',
          );
      }

      // Parse the normalized map as v3.1
      final normalizedJson = jsonEncode(normalizedMap);
      return v31.OpenAPIParser.parseJson(normalizedJson);
    } on SpecReaderException {
      rethrow;
    } catch (e) {
      final fileContext = path != null ? " '$path'" : '';
      throw SpecReaderException(
        'Failed to parse OpenAPI spec$fileContext: $e\n'
        '  Ensure the file is valid YAML/JSON and follows the OpenAPI specification.',
      );
    }
  }

  Map<String, dynamic> _toStringDynMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _convertValue(v)));
    }
    return {};
  }

  dynamic _convertValue(dynamic value) {
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _convertValue(v)));
    }
    if (value is List) {
      return value.map((e) => _convertValue(e)).toList();
    }
    return value;
  }
}

/// Exception thrown for spec reading errors.
class SpecReaderException implements Exception {
  final String message;
  const SpecReaderException(this.message);

  @override
  String toString() => 'SpecReaderException: $message';
}
