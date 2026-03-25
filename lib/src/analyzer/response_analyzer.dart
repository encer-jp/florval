import 'package:openapi_spec_plus/v31.dart' as v31;

import '../model/api_response.dart';
import '../model/api_type.dart';
import '../parser/ref_resolver.dart';
import 'schema_analyzer.dart';

/// Extracts status-code-specific response information from OpenAPI operations.
class ResponseAnalyzer {
  final RefResolver resolver;
  final SchemaAnalyzer schemaAnalyzer;

  ResponseAnalyzer(this.resolver, this.schemaAnalyzer);

  /// Analyzes all responses for an operation.
  Map<int, FlorvalResponse> analyzeResponses(
    Map<String, v31.Response> responses,
  ) {
    final result = <int, FlorvalResponse>{};

    for (final entry in responses.entries) {
      final code = _parseStatusCode(entry.key);
      if (code == null) continue;

      final response = resolver.resolveResponse(entry.value);
      final type = _extractResponseType(response);

      result[code] = FlorvalResponse(
        statusCode: code,
        description: response.description,
        type: type,
      );
    }

    return result;
  }

  /// Extracts the response body type from a Response.
  FlorvalType? _extractResponseType(v31.Response response) {
    if (response.content == null) return null;

    final jsonContent = response.content!['application/json'];
    if (jsonContent == null) return null;

    final schema = jsonContent.schema;
    if (schema == null) return null;

    return schemaAnalyzer.schemaToType(schema);
  }

  /// Parses a status code string to int.
  /// Handles "200", "2XX", "default", etc.
  int? _parseStatusCode(String code) {
    final parsed = int.tryParse(code);
    if (parsed != null) return parsed;

    // Wildcard status codes
    switch (code.toUpperCase()) {
      case '2XX':
        return 200;
      case '3XX':
        return 300;
      case '4XX':
        return 400;
      case '5XX':
        return 500;
      case 'DEFAULT':
        return 0; // Represented as 0 for "default"
      default:
        return null;
    }
  }
}
