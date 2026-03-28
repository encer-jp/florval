// ignore: implementation_imports
import 'package:openapi_spec_plus/src/util/enums.dart' as oapi_enums;
import 'package:openapi_spec_plus/v31.dart' as v31;
import 'package:recase/recase.dart';

import '../config/florval_config.dart';
import '../model/analysis_result.dart';
import '../model/api_endpoint.dart';
import '../model/api_response.dart';
import '../model/api_schema.dart';
import '../model/api_type.dart';
import '../parser/ref_resolver.dart';
import '../utils/logger.dart';
import 'response_analyzer.dart';
import 'schema_analyzer.dart';

/// Extracts endpoint information from OpenAPI paths.
class EndpointAnalyzer {
  final RefResolver resolver;
  final SchemaAnalyzer schemaAnalyzer;
  final ResponseAnalyzer responseAnalyzer;
  final FlorvalLogger? logger;
  final List<PaginationConfig> _paginationConfigs;

  EndpointAnalyzer(
    this.resolver,
    this.schemaAnalyzer,
    this.responseAnalyzer, {
    this.logger,
    List<PaginationConfig> paginationConfigs = const [],
  }) : _paginationConfigs = paginationConfigs;

  /// Analyzes all endpoints from the spec's paths.
  ({List<FlorvalEndpoint> endpoints, List<FlorvalSchema> inlineUnionSchemas, List<FlorvalSchema> inlineObjectSchemas, List<FlorvalSchema> inlineEnumSchemas}) analyzeAll(Map<String, v31.PathItem> paths) {
    final endpoints = <FlorvalEndpoint>[];
    final allInlineUnions = <FlorvalSchema>[];
    final allInlineObjects = <FlorvalSchema>[];
    final allInlineEnums = <FlorvalSchema>[];

    for (final entry in paths.entries) {
      final path = entry.key;
      final pathItem = entry.value;
      final pathParams = pathItem.parameters ?? [];

      for (final (method, operation) in [
        ('GET', pathItem.get),
        ('POST', pathItem.post),
        ('PUT', pathItem.put),
        ('DELETE', pathItem.delete),
        ('PATCH', pathItem.patch),
      ]) {
        if (operation != null) {
          final result = _analyzeOperation(path, method, operation, pathParams);
          endpoints.add(result.endpoint);
          allInlineUnions.addAll(result.inlineUnionSchemas);
          allInlineObjects.addAll(result.inlineObjectSchemas);
          allInlineEnums.addAll(result.inlineEnumSchemas);
        }
      }
    }

    return (endpoints: endpoints, inlineUnionSchemas: allInlineUnions, inlineObjectSchemas: allInlineObjects, inlineEnumSchemas: allInlineEnums);
  }

  ({FlorvalEndpoint endpoint, List<FlorvalSchema> inlineUnionSchemas, List<FlorvalSchema> inlineObjectSchemas, List<FlorvalSchema> inlineEnumSchemas}) _analyzeOperation(
    String path,
    String method,
    v31.Operation operation,
    List<v31.Parameter> pathLevelParams,
  ) {
    final operationId =
        operation.operationId ?? _generateOperationId(path, method);

    // Merge path-level and operation-level parameters
    final allParams = <v31.Parameter>[
      ...pathLevelParams,
      ...operation.parameters,
    ];

    final parameters = _analyzeParameters(allParams);
    final requestBody = _analyzeRequestBody(operation.requestBody);
    final responseResult = responseAnalyzer.analyzeResponses(
      operation.responses,
      operationId: operationId,
    );
    final responses = responseResult.responses;
    final inlineUnions = [...responseResult.inlineUnionSchemas];
    final inlineObjects = [...responseResult.inlineObjectSchemas];
    final inlineEnums = [...responseResult.inlineEnumSchemas];

    // Check if this endpoint has a pagination config
    PaginationInfo? pagination;
    if (method == 'GET') {
      final paginationConfig = _paginationConfigs
          .where((c) => c.operationId == operationId)
          .firstOrNull;
      if (paginationConfig != null) {
        pagination = _buildPaginationInfo(
          paginationConfig,
          operation.responses,
          parameters,
          operationId,
        );
        // Replace 200 response type with the wrapper model type
        if (pagination != null && pagination.wrapperSchema != null) {
          final wrapperName = pagination.wrapperSchema!.name;
          final wrapperType = FlorvalType(
            name: wrapperName,
            dartType: wrapperName,
            // Synthetic ref so import collection picks up the wrapper model
            ref: '#/components/schemas/$wrapperName',
          );
          final existing200 = responses[200]!;
          responses[200] = FlorvalResponse(
            statusCode: 200,
            description: existing200.description,
            type: wrapperType,
          );
        }
      }
    }

    return (
      endpoint: FlorvalEndpoint(
        path: path,
        method: method,
        operationId: operationId,
        parameters: parameters,
        requestBody: requestBody,
        responses: responses,
        tags: operation.tags,
        summary: operation.summary,
        description: operation.description,
        pagination: pagination,
        deprecated: operation.$deprecated == true,
      ),
      inlineUnionSchemas: inlineUnions,
      inlineObjectSchemas: inlineObjects,
      inlineEnumSchemas: inlineEnums,
    );
  }

  List<FlorvalParam> _analyzeParameters(List<v31.Parameter> parameters) {
    return parameters.map((p) {
      final resolved = resolver.resolveParameter(p);
      final typeResult = resolved.schema != null
          ? schemaAnalyzer.schemaToType(resolved.schema!)
          : const TypeResult(
              type: FlorvalType(name: 'String', dartType: 'String'));

      return FlorvalParam(
        name: resolved.name ?? '',
        dartName: ReCase(resolved.name ?? '').camelCase,
        location: _toParamLocation(resolved.location),
        type: typeResult.type,
        isRequired: resolved.required ?? false,
        description: resolved.description,
        example: resolved.example,
        deprecated: resolved.$deprecated == true,
      );
    }).toList();
  }

  FlorvalRequestBody? _analyzeRequestBody(v31.RequestBody? requestBody) {
    if (requestBody == null) return null;

    // Prefer application/json
    final jsonContent = requestBody.content['application/json'];
    if (jsonContent != null) {
      final schema = jsonContent.schema;
      if (schema == null) return null;

      final typeResult = schemaAnalyzer.schemaToType(schema);

      return FlorvalRequestBody(
        type: typeResult.type,
        isRequired: requestBody.$required ?? false,
        description: requestBody.description,
        contentType: ContentType.json,
      );
    }

    // Fall back to multipart/form-data
    final multipartContent = requestBody.content['multipart/form-data'];
    if (multipartContent != null) {
      return _analyzeMultipartRequestBody(
        multipartContent,
        requestBody.$required ?? false,
        requestBody.description,
      );
    }

    final types = requestBody.content.keys.toList();
    if (types.isNotEmpty) {
      logger?.warn(
        'Request body has unsupported content type(s): ${types.join(", ")}. '
        'Only application/json and multipart/form-data are supported — skipping request body.');
    }

    return null;
  }

  FlorvalRequestBody? _analyzeMultipartRequestBody(
    v31.MediaType mediaType,
    bool isRequired,
    String? description,
  ) {
    final schema = mediaType.schema;
    if (schema == null) return null;

    final resolved = resolver.resolveSchema(schema);
    final properties = resolved.properties ?? {};
    final requiredFields = resolved.$required ?? [];

    final formFields = <FlorvalField>[];
    for (final entry in properties.entries) {
      final fieldName = entry.key;
      final fieldSchema = resolver.resolveSchema(entry.value);
      final fieldRequired = requiredFields.contains(fieldName);

      final type = _multipartFieldType(fieldSchema);

      formFields.add(FlorvalField(
        name: ReCase(fieldName).camelCase,
        jsonKey: fieldName,
        type: type,
        isRequired: fieldRequired,
      ));
    }

    // Use a placeholder type for the multipart body as a whole
    const multipartType = FlorvalType(name: 'FormData', dartType: 'FormData');

    return FlorvalRequestBody(
      type: multipartType,
      isRequired: isRequired,
      description: description,
      contentType: ContentType.multipart,
      formFields: formFields,
    );
  }

  /// Maps a schema field within a multipart body to the appropriate Dart type.
  /// `string` + `format: binary` → `MultipartFile`
  /// `array` of `string/binary` → `List<MultipartFile>`
  FlorvalType _multipartFieldType(v31.Schema schema) {
    if (_isBinaryString(schema)) {
      return const FlorvalType(name: 'MultipartFile', dartType: 'MultipartFile');
    }
    final extractedType = _extractType(schema);
    if (extractedType == 'array' && schema.items != null) {
      final itemSchema = resolver.resolveSchema(schema.items!);
      if (_isBinaryString(itemSchema)) {
        return const FlorvalType(
          name: 'List<MultipartFile>',
          dartType: 'List<MultipartFile>',
          isList: true,
          itemType: FlorvalType(name: 'MultipartFile', dartType: 'MultipartFile'),
        );
      }
    }
    // For non-binary fields, use the standard schema-to-type mapping
    return schemaAnalyzer.schemaToType(schema).type;
  }

  /// Returns true if the schema represents a binary string (format: binary).
  bool _isBinaryString(v31.Schema schema) {
    return _extractType(schema) == 'string' && schema.format == 'binary';
  }

  /// Extracts the primary type string from a schema, handling OpenAPI 3.1
  /// array-style types like `["string", "null"]`.
  ///
  /// Returns `'dynamic'` when type is unspecified (OpenAPI 3.1: "any type").
  String _extractType(v31.Schema schema) {
    final type = schema.type;
    if (type == null) return 'dynamic';
    if (type is String) return type;
    if (type is List) {
      final types = type.cast<String>();
      return types.firstWhere((t) => t != 'null', orElse: () => 'dynamic');
    }
    return 'dynamic';
  }

  ParamLocation _toParamLocation(oapi_enums.ParameterLocation? location) {
    switch (location) {
      case oapi_enums.ParameterLocation.path:
        return ParamLocation.path;
      case oapi_enums.ParameterLocation.query:
        return ParamLocation.query;
      case oapi_enums.ParameterLocation.header:
        return ParamLocation.header;
      case oapi_enums.ParameterLocation.cookie:
        return ParamLocation.cookie;
      default:
        return ParamLocation.query;
    }
  }

  /// Builds PaginationInfo by inspecting the 200 response schema.
  PaginationInfo? _buildPaginationInfo(
    PaginationConfig config,
    Map<String, v31.Response> responses,
    List<FlorvalParam> parameters,
    String operationId,
  ) {
    // Validate cursor param exists in query parameters
    final hasCursorParam = parameters.any(
      (p) => p.name == config.cursorParam && p.location == ParamLocation.query,
    );
    if (!hasCursorParam) return null;

    // Find 200 response schema
    final response200 = responses['200'];
    if (response200 == null) return null;

    final resolved200 = resolver.resolveResponse(response200);
    final jsonContent = resolved200.content?['application/json'];
    if (jsonContent == null) return null;

    final schema = jsonContent.schema;
    if (schema == null) return null;

    final resolvedSchema = resolver.resolveSchema(schema);
    final properties = resolvedSchema.properties;
    if (properties == null) return null;

    // Validate items_field exists and is an array
    final itemsSchema = properties[config.itemsField];
    if (itemsSchema == null) return null;

    final resolvedItems = resolver.resolveSchema(itemsSchema);
    final itemsType = _extractType(resolvedItems);
    if (itemsType != 'array') return null;

    // Extract item element type
    final FlorvalType itemType;
    if (resolvedItems.items != null) {
      itemType = schemaAnalyzer.schemaToType(resolvedItems.items!).type;
    } else {
      logger?.warn(
        'Pagination items field "${config.itemsField}" in $operationId '
        'is missing "items" — using List<dynamic>.');
      itemType = const FlorvalType(name: 'dynamic', dartType: 'dynamic');
    }

    // Validate next_cursor_field exists
    final cursorSchema = properties[config.nextCursorField];
    if (cursorSchema == null) return null;

    // If the 200 response is an inline object (no $ref), auto-generate a
    // wrapper model so the Union type uses a proper class instead of
    // Map<String, dynamic>.
    FlorvalSchema? wrapperSchema;
    if (schema.ref == null) {
      final wrapperName =
          '${ReCase(operationId).pascalCase}Page';
      final wrapperFields = <FlorvalField>[];
      final requiredFields = resolvedSchema.$required ?? [];

      for (final entry in properties.entries) {
        final fieldName = ReCase(entry.key).camelCase;
        final fieldSchema = entry.value;
        final isRequired = requiredFields.contains(entry.key);
        final type = schemaAnalyzer.schemaToType(fieldSchema).type;

        wrapperFields.add(FlorvalField(
          name: fieldName,
          jsonKey: entry.key,
          type: isRequired ? type : type.asNullable(),
          isRequired: isRequired,
        ));
      }

      wrapperSchema = FlorvalSchema(
        name: wrapperName,
        fields: wrapperFields,
      );
    }

    return PaginationInfo(
      cursorParam: config.cursorParam,
      nextCursorField: config.nextCursorField,
      itemsField: config.itemsField,
      itemType: itemType,
      wrapperSchema: wrapperSchema,
    );
  }

  /// Generates an operationId from path and method.
  /// e.g. GET /users/{id} → getUsersId
  String _generateOperationId(String path, String method) {
    final segments = path
        .split('/')
        .where((s) => s.isNotEmpty)
        .map((s) => s.replaceAll(RegExp(r'[{}]'), ''))
        .map((s) => ReCase(s).pascalCase)
        .join();
    return '${method.toLowerCase()}$segments';
  }
}
