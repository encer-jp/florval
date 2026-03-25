import 'dart:io';

import 'package:openapi_spec_plus/v31.dart' as v31;

/// Reads and parses OpenAPI 3.1 specification files.
class SpecReader {
  /// Parses an OpenAPI spec file (YAML or JSON).
  v31.OpenAPI readFile(String path) {
    final file = File(path);
    if (!file.existsSync()) {
      throw SpecReaderException('OpenAPI spec file not found: $path');
    }

    final content = file.readAsStringSync();
    return parse(content, path: path);
  }

  /// Parses OpenAPI spec from string content.
  v31.OpenAPI parse(String content, {String? path}) {
    try {
      // openapi_spec_plus auto-detects YAML vs JSON
      if (path != null && path.endsWith('.json')) {
        return v31.OpenAPIParser.parseJson(content);
      }
      return v31.OpenAPIParser.parseYaml(content);
    } catch (e) {
      throw SpecReaderException('Failed to parse OpenAPI spec: $e');
    }
  }
}

/// Exception thrown for spec reading errors.
class SpecReaderException implements Exception {
  final String message;
  const SpecReaderException(this.message);

  @override
  String toString() => 'SpecReaderException: $message';
}
