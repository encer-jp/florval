import 'package:openapi_spec_plus/v31.dart' as v31;
import 'package:recase/recase.dart';

import '../model/analysis_result.dart';
import '../model/api_response.dart';
import '../model/api_schema.dart';
import '../model/api_type.dart';
import '../parser/ref_resolver.dart';
import '../utils/logger.dart';
import 'schema_analyzer.dart';

/// Extracts status-code-specific response information from OpenAPI operations.
class ResponseAnalyzer {
  final RefResolver resolver;
  final SchemaAnalyzer schemaAnalyzer;
  final FlorvalLogger? logger;

  ResponseAnalyzer(this.resolver, this.schemaAnalyzer, {this.logger});

  /// Analyzes all responses for an operation.
  /// [operationId] is used to generate names for inline oneOf/anyOf union types.
  ({Map<int, FlorvalResponse> responses, List<FlorvalSchema> inlineUnionSchemas, List<FlorvalSchema> inlineObjectSchemas}) analyzeResponses(
    Map<String, v31.Response> responses, {
    String? operationId,
  }) {
    final result = <int, FlorvalResponse>{};
    final allInlineUnions = <FlorvalSchema>[];
    final allInlineObjects = <FlorvalSchema>[];

    for (final entry in responses.entries) {
      final code = _parseStatusCode(entry.key);
      if (code == null) continue;

      final response = resolver.resolveResponse(entry.value);
      final typeResult = _extractResponseType(response, operationId: operationId, statusCode: code);

      if (typeResult != null) {
        allInlineUnions.addAll(typeResult.inlineUnionSchemas);
        allInlineObjects.addAll(typeResult.inlineObjectSchemas);
      }

      result[code] = FlorvalResponse(
        statusCode: code,
        description: response.description,
        type: typeResult?.type,
      );
    }

    return (responses: result, inlineUnionSchemas: allInlineUnions, inlineObjectSchemas: allInlineObjects);
  }

  /// Extracts the response body type from a Response.
  ///
  /// Delegates all type resolution to [SchemaAnalyzer.schemaToType], which
  /// correctly distinguishes nullable $ref patterns (e.g. `anyOf: [$ref, null]`)
  /// from true inline unions.
  TypeResult? _extractResponseType(
    v31.Response response, {
    String? operationId,
    int? statusCode,
  }) {
    if (response.content == null) return null;

    final jsonContent = response.content!['application/json'];
    if (jsonContent == null) {
      final unsupported = response.content!.keys.toList();
      if (unsupported.isNotEmpty) {
        logger?.warn(
          'Response for ${operationId ?? "unknown"} (${statusCode ?? "?"}) '
          'has unsupported content type(s): ${unsupported.join(", ")}. '
          'Only application/json is supported — skipping response body.');
      }
      return null;
    }

    final schema = jsonContent.schema;
    if (schema == null) return null;

    // Build contextName for inline unions/objects in response bodies
    final baseName = operationId != null
        ? ReCase(operationId).pascalCase
        : 'InlineType';
    final statusSuffix = statusCode != null
        ? _statusCodeToName(statusCode)
        : 'Body';
    final contextName = '$baseName$statusSuffix';

    return schemaAnalyzer.schemaToType(schema, contextName: contextName);
  }

  /// Maps status codes to human-readable suffixes for type names.
  String _statusCodeToName(int code) {
    return switch (code) {
      200 => 'SuccessBody',
      201 => 'CreatedBody',
      204 => 'NoContentBody',
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
