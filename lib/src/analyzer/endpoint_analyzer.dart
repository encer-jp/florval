// ignore: implementation_imports
import 'package:openapi_spec_plus/src/util/enums.dart' as oapi_enums;
import 'package:openapi_spec_plus/v31.dart' as v31;
import 'package:recase/recase.dart';

import '../config/florval_config.dart';
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

    final paramsResult = _analyzeParameters(operationId, allParams);
    final parameters = paramsResult.params;
    final bodyResult = _analyzeRequestBody(operationId, operation.requestBody);
    final requestBody = bodyResult?.requestBody;
    final responseResult = responseAnalyzer.analyzeResponses(
      operation.responses,
      operationId: operationId,
    );
    final responses = responseResult.responses;
    final inlineUnions = [
      ...responseResult.inlineUnionSchemas,
      ...paramsResult.inlineUnions,
      if (bodyResult != null) ...bodyResult.inlineUnions,
    ];
    final inlineObjects = [
      ...responseResult.inlineObjectSchemas,
      ...paramsResult.inlineObjects,
      if (bodyResult != null) ...bodyResult.inlineObjects,
    ];
    final inlineEnums = [
      ...responseResult.inlineEnumSchemas,
      ...paramsResult.inlineEnums,
      if (bodyResult != null) ...bodyResult.inlineEnums,
    ];

    // Check if this endpoint has a pagination config
    PaginationInfo? pagination;
    if (method == 'GET') {
      final paginationConfig = _paginationConfigs
          .where((c) => c.operationId == operationId)
          .firstOrNull;
      if (paginationConfig != null) {
        final paginationResult = _buildPaginationInfo(
          paginationConfig,
          operation.responses,
          parameters,
          operationId,
        );
        pagination = paginationResult?.info;
        if (paginationResult != null) {
          inlineUnions.addAll(paginationResult.inlineUnions);
          inlineObjects.addAll(paginationResult.inlineObjects);
          inlineEnums.addAll(paginationResult.inlineEnums);
        }
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
        deprecated: operation.deprecated == true,
      ),
      inlineUnionSchemas: inlineUnions,
      inlineObjectSchemas: inlineObjects,
      inlineEnumSchemas: inlineEnums,
    );
  }

  ({
    List<FlorvalParam> params,
    List<FlorvalSchema> inlineEnums,
    List<FlorvalSchema> inlineUnions,
    List<FlorvalSchema> inlineObjects,
  }) _analyzeParameters(String operationId, List<v31.Parameter> parameters) {
    final params = <FlorvalParam>[];
    final inlineEnums = <FlorvalSchema>[];
    final inlineUnions = <FlorvalSchema>[];
    final inlineObjects = <FlorvalSchema>[];
    final opBase = ReCase(operationId).pascalCase;

    for (final p in parameters) {
      final resolved = resolver.resolveParameter(p);
      final paramName = resolved.name ?? '';
      final FlorvalType type;
      if (resolved.schema != null) {
        final contextName = '$opBase${ReCase(paramName).pascalCase}';
        final typeResult = schemaAnalyzer.schemaToType(
          resolved.schema!,
          contextName: contextName,
        );
        type = typeResult.type;
        inlineEnums.addAll(typeResult.inlineEnumSchemas);
        inlineUnions.addAll(typeResult.inlineUnionSchemas);
        inlineObjects.addAll(typeResult.inlineObjectSchemas);
      } else {
        type = const FlorvalType(name: 'String', dartType: 'String');
      }

      params.add(FlorvalParam(
        name: paramName,
        dartName: ReCase(paramName).camelCase,
        location: _toParamLocation(resolved.location),
        type: type,
        isRequired: resolved.required ?? false,
        description: resolved.description,
        example: resolved.example,
        deprecated: resolved.deprecated == true,
      ));
    }

    return (
      params: params,
      inlineEnums: inlineEnums,
      inlineUnions: inlineUnions,
      inlineObjects: inlineObjects,
    );
  }

  ({
    FlorvalRequestBody requestBody,
    List<FlorvalSchema> inlineEnums,
    List<FlorvalSchema> inlineUnions,
    List<FlorvalSchema> inlineObjects,
  })? _analyzeRequestBody(String operationId, v31.RequestBody? requestBody) {
    if (requestBody == null) return null;
    final opBase = ReCase(operationId).pascalCase;

    // Prefer application/json
    final jsonContent = requestBody.content['application/json'];
    if (jsonContent != null) {
      final schema = jsonContent.schema;
      if (schema == null) return null;

      final typeResult = schemaAnalyzer.schemaToType(
        schema,
        contextName: '${opBase}Body',
      );

      return (
        requestBody: FlorvalRequestBody(
          type: typeResult.type,
          isRequired: requestBody.$required ?? false,
          description: requestBody.description,
          contentType: ContentType.json,
        ),
        inlineEnums: typeResult.inlineEnumSchemas,
        inlineUnions: typeResult.inlineUnionSchemas,
        inlineObjects: typeResult.inlineObjectSchemas,
      );
    }

    // Fall back to multipart/form-data
    final multipartContent = requestBody.content['multipart/form-data'];
    if (multipartContent != null) {
      return _analyzeMultipartRequestBody(
        operationId,
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

  ({
    FlorvalRequestBody requestBody,
    List<FlorvalSchema> inlineEnums,
    List<FlorvalSchema> inlineUnions,
    List<FlorvalSchema> inlineObjects,
  })? _analyzeMultipartRequestBody(
    String operationId,
    v31.MediaType mediaType,
    bool isRequired,
    String? description,
  ) {
    final schema = mediaType.schema;
    if (schema == null) return null;

    final resolved = resolver.resolveSchema(schema);
    final properties = resolved.properties ?? {};
    final requiredFields = resolved.$required ?? [];
    final opBase = ReCase(operationId).pascalCase;

    final formFields = <FlorvalField>[];
    final inlineEnums = <FlorvalSchema>[];
    final inlineUnions = <FlorvalSchema>[];
    final inlineObjects = <FlorvalSchema>[];

    for (final entry in properties.entries) {
      final fieldName = entry.key;
      final fieldRequired = requiredFields.contains(fieldName);
      final contextName = '$opBase${ReCase(fieldName).pascalCase}';

      // Pass original schema (with $ref intact) so schemaToType can detect refs
      final fieldResult = _multipartFieldType(entry.value, contextName);
      inlineEnums.addAll(fieldResult.inlineEnums);
      inlineUnions.addAll(fieldResult.inlineUnions);
      inlineObjects.addAll(fieldResult.inlineObjects);

      formFields.add(FlorvalField(
        name: ReCase(fieldName).camelCase,
        jsonKey: fieldName,
        type: fieldResult.type,
        isRequired: fieldRequired,
      ));
    }

    // Use a placeholder type for the multipart body as a whole
    const multipartType = FlorvalType(name: 'FormData', dartType: 'FormData');

    return (
      requestBody: FlorvalRequestBody(
        type: multipartType,
        isRequired: isRequired,
        description: description,
        contentType: ContentType.multipart,
        formFields: formFields,
      ),
      inlineEnums: inlineEnums,
      inlineUnions: inlineUnions,
      inlineObjects: inlineObjects,
    );
  }

  /// Maps a schema field within a multipart body to the appropriate Dart type.
  /// `string` + `format: binary` → `MultipartFile`
  /// `array` of `string/binary` → `List<MultipartFile>`
  ({
    FlorvalType type,
    List<FlorvalSchema> inlineEnums,
    List<FlorvalSchema> inlineUnions,
    List<FlorvalSchema> inlineObjects,
  }) _multipartFieldType(v31.Schema schema, String contextName) {
    // Resolve for binary detection, but keep original schema for schemaToType
    final resolved = resolver.resolveSchema(schema);
    if (_isBinaryString(resolved)) {
      return (
        type: const FlorvalType(name: 'MultipartFile', dartType: 'MultipartFile'),
        inlineEnums: const [],
        inlineUnions: const [],
        inlineObjects: const [],
      );
    }
    final extractedType = _extractType(resolved);
    if (extractedType == 'array' && resolved.items != null) {
      final itemSchema = resolver.resolveSchema(resolved.items!);
        return (
          type: const FlorvalType(
            name: 'List<MultipartFile>',
            dartType: 'List<MultipartFile>',
            isList: true,
            itemType: FlorvalType(name: 'MultipartFile', dartType: 'MultipartFile'),
          ),
          inlineEnums: const [],
          inlineUnions: const [],
          inlineObjects: const [],
        );
      }
    }
    // For non-binary fields, use the standard schema-to-type mapping
    final typeResult =
        schemaAnalyzer.schemaToType(schema, contextName: contextName);
    return (
      type: typeResult.type,
      inlineEnums: typeResult.inlineEnumSchemas,
      inlineUnions: typeResult.inlineUnionSchemas,
      inlineObjects: typeResult.inlineObjectSchemas,
    );
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
  ({
    PaginationInfo info,
    List<FlorvalSchema> inlineEnums,
    List<FlorvalSchema> inlineUnions,
    List<FlorvalSchema> inlineObjects,
  })? _buildPaginationInfo(
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

    final wrapperName = '${ReCase(operationId).pascalCase}Page';
    final inlineEnums = <FlorvalSchema>[];
    final inlineUnions = <FlorvalSchema>[];
    final inlineObjects = <FlorvalSchema>[];

    // Extract item element type
    final FlorvalType itemType;
    if (resolvedItems.items != null) {
      final itemTypeResult = schemaAnalyzer.schemaToType(
        resolvedItems.items!,
        contextName: '${wrapperName}Item',
      );
      itemType = itemTypeResult.type;
      inlineEnums.addAll(itemTypeResult.inlineEnumSchemas);
      inlineUnions.addAll(itemTypeResult.inlineUnionSchemas);
      inlineObjects.addAll(itemTypeResult.inlineObjectSchemas);
    } else {
      logger?.warn(
        'Pagination items field "${config.itemsField}" in $operationId '
        'is missing "items" — using List<dynamic>.');
      itemType = const FlorvalType(name: 'dynamic', dartType: 'dynamic');
    }

    // Validate next_cursor_field exists (supports dot notation for nested fields)
    if (!_resolveNestedField(properties, config.nextCursorField)) return null;

    // If the 200 response is an inline object (no $ref), auto-generate a
    // wrapper model so the Union type uses a proper class instead of
    // Map<String, dynamic>.
    FlorvalSchema? wrapperSchema;
    if (schema.ref == null) {
      final wrapperFields = <FlorvalField>[];
      final requiredFields = resolvedSchema.$required ?? [];

      for (final entry in properties.entries) {
        final fieldName = ReCase(entry.key).camelCase;
        final fieldSchema = entry.value;
        final isRequired = requiredFields.contains(entry.key);
        final contextName =
            '$wrapperName${ReCase(entry.key).pascalCase}';
        final typeResult = schemaAnalyzer.schemaToType(
          fieldSchema,
          contextName: contextName,
        );
        final type = typeResult.type;
        inlineEnums.addAll(typeResult.inlineEnumSchemas);
        inlineUnions.addAll(typeResult.inlineUnionSchemas);
        inlineObjects.addAll(typeResult.inlineObjectSchemas);

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

    return (
      info: PaginationInfo(
        cursorParam: config.cursorParam,
        nextCursorField: config.nextCursorField,
        itemsField: config.itemsField,
        itemType: itemType,
        wrapperSchema: wrapperSchema,
      ),
      inlineEnums: inlineEnums,
      inlineUnions: inlineUnions,
      inlineObjects: inlineObjects,
    );
  }

  /// Resolves a possibly dot-notated field path through nested properties.
  /// e.g. "pagination.nextCursor" checks properties["pagination"] →
  /// resolve → properties["nextCursor"].
  /// Handles allOf by merging properties from all entries.
  bool _resolveNestedField(
    Map<String, v31.Schema> properties,
    String fieldPath,
  ) {
    final segments = fieldPath.split('.');
    var currentProps = properties;
    for (var i = 0; i < segments.length; i++) {
      final schema = currentProps[segments[i]];
      if (schema == null) return false;
      if (i < segments.length - 1) {
        // Need to traverse deeper — resolve and get nested properties
        final nestedProps = _collectProperties(schema);
        if (nestedProps == null) return false;
        currentProps = nestedProps;
      }
    }
    return true;
  }

  /// Collects properties from a schema, handling $ref and allOf.
  Map<String, v31.Schema>? _collectProperties(v31.Schema schema) {
    final resolved = resolver.resolveSchema(schema);
    if (resolved.properties != null) return resolved.properties;
    // Handle allOf: merge properties from all entries
    if (resolved.allOf != null && resolved.allOf!.isNotEmpty) {
      final merged = <String, v31.Schema>{};
      for (final entry in resolved.allOf!) {
        final entryResolved = resolver.resolveSchema(entry);
        if (entryResolved.properties != null) {
          merged.addAll(entryResolved.properties!);
        }
      }
      return merged.isNotEmpty ? merged : null;
    }
    return null;
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
