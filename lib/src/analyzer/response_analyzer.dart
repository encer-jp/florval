import 'package:openapi_spec_plus/v31.dart' as v31;
import 'package:recase/recase.dart';

import '../model/api_response.dart';
import '../model/api_schema.dart';
import '../model/api_type.dart';
import '../parser/ref_resolver.dart';
import 'schema_analyzer.dart';

/// Extracts status-code-specific response information from OpenAPI operations.
class ResponseAnalyzer {
  final RefResolver resolver;
  final SchemaAnalyzer schemaAnalyzer;

  /// Inline union schemas discovered during response analysis.
  /// These need to be generated as separate model files.
  final List<FlorvalSchema> inlineUnionSchemas = [];

  ResponseAnalyzer(this.resolver, this.schemaAnalyzer);

  /// Analyzes all responses for an operation.
  /// [operationId] is used to generate names for inline oneOf/anyOf union types.
  Map<int, FlorvalResponse> analyzeResponses(
    Map<String, v31.Response> responses, {
    String? operationId,
  }) {
    final result = <int, FlorvalResponse>{};

    for (final entry in responses.entries) {
      final code = _parseStatusCode(entry.key);
      if (code == null) continue;

      final response = resolver.resolveResponse(entry.value);
      final type = _extractResponseType(response, operationId: operationId, statusCode: code);

      result[code] = FlorvalResponse(
        statusCode: code,
        description: response.description,
        type: type,
      );
    }

    return result;
  }

  /// Extracts the response body type from a Response.
  FlorvalType? _extractResponseType(
    v31.Response response, {
    String? operationId,
    int? statusCode,
  }) {
    if (response.content == null) return null;

    final jsonContent = response.content!['application/json'];
    if (jsonContent == null) return null;

    final schema = jsonContent.schema;
    if (schema == null) return null;

    // Handle inline oneOf/anyOf with discriminator
    if (_hasInlineOneOf(schema)) {
      return _extractInlineUnionType(schema, operationId, statusCode);
    }

    return schemaAnalyzer.schemaToType(schema);
  }

  /// Checks if a schema has inline oneOf or anyOf (not a $ref).
  bool _hasInlineOneOf(v31.Schema schema) {
    if (schema.ref != null) return false;
    return (schema.oneOf != null && schema.oneOf!.isNotEmpty) ||
        (schema.anyOf != null && schema.anyOf!.isNotEmpty);
  }

  /// Extracts an inline oneOf/anyOf schema as a named union type.
  FlorvalType? _extractInlineUnionType(
    v31.Schema schema,
    String? operationId,
    int? statusCode,
  ) {
    // Generate a name for the inline union type
    final baseName = operationId != null
        ? ReCase(operationId).pascalCase
        : 'InlineUnion';
    final statusSuffix = statusCode != null
        ? _statusCodeToName(statusCode)
        : 'Body';
    final unionName = '$baseName$statusSuffix';

    // Analyze the inline schema as a named union type
    final unionSchema = schemaAnalyzer.analyze(unionName, schema);

    // Only register if it's actually a union type
    if (unionSchema.oneOf != null || unionSchema.anyOf != null) {
      inlineUnionSchemas.add(unionSchema);

      return FlorvalType(
        name: unionName,
        dartType: unionName,
        // Synthetic ref so import collection picks up the model
        ref: '#/components/schemas/$unionName',
      );
    }

    // Fallback to standard type extraction
    return schemaAnalyzer.schemaToType(schema);
  }

  /// Maps status codes to human-readable suffixes for type names.
  String _statusCodeToName(int code) {
    return switch (code) {
      400 => 'BadRequestBody',
      401 => 'UnauthorizedBody',
      403 => 'ForbiddenBody',
      404 => 'NotFoundBody',
      409 => 'ConflictBody',
      422 => 'UnprocessableEntityBody',
      500 => 'ServerErrorBody',
      _ => 'Status${code}Body',
    };
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
