// ignore: implementation_imports
import 'package:openapi_spec_plus/src/util/enums.dart' as oapi_enums;
import 'package:openapi_spec_plus/v31.dart' as v31;
import 'package:recase/recase.dart';

import '../model/api_endpoint.dart';
import '../model/api_type.dart';
import '../parser/ref_resolver.dart';
import 'response_analyzer.dart';
import 'schema_analyzer.dart';

/// Extracts endpoint information from OpenAPI paths.
class EndpointAnalyzer {
  final RefResolver resolver;
  final SchemaAnalyzer schemaAnalyzer;
  final ResponseAnalyzer responseAnalyzer;

  EndpointAnalyzer(this.resolver, this.schemaAnalyzer, this.responseAnalyzer);

  /// Analyzes all endpoints from the spec's paths.
  List<FlorvalEndpoint> analyzeAll(Map<String, v31.PathItem> paths) {
    final endpoints = <FlorvalEndpoint>[];

    for (final entry in paths.entries) {
      final path = entry.key;
      final pathItem = entry.value;
      final pathParams = pathItem.parameters ?? [];

      if (pathItem.get != null) {
        endpoints.add(_analyzeOperation(path, 'GET', pathItem.get!, pathParams));
      }
      if (pathItem.post != null) {
        endpoints
            .add(_analyzeOperation(path, 'POST', pathItem.post!, pathParams));
      }
      if (pathItem.put != null) {
        endpoints
            .add(_analyzeOperation(path, 'PUT', pathItem.put!, pathParams));
      }
      if (pathItem.delete != null) {
        endpoints.add(
            _analyzeOperation(path, 'DELETE', pathItem.delete!, pathParams));
      }
      if (pathItem.patch != null) {
        endpoints.add(
            _analyzeOperation(path, 'PATCH', pathItem.patch!, pathParams));
      }
    }

    return endpoints;
  }

  FlorvalEndpoint _analyzeOperation(
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
    final responses = responseAnalyzer.analyzeResponses(operation.responses);

    return FlorvalEndpoint(
      path: path,
      method: method,
      operationId: operationId,
      parameters: parameters,
      requestBody: requestBody,
      responses: responses,
      tags: operation.tags,
      summary: operation.summary,
    );
  }

  List<FlorvalParam> _analyzeParameters(List<v31.Parameter> parameters) {
    return parameters.map((p) {
      final resolved = resolver.resolveParameter(p);
      final type = resolved.schema != null
          ? schemaAnalyzer.schemaToType(resolved.schema!)
          : const FlorvalType(name: 'String', dartType: 'String');

      return FlorvalParam(
        name: resolved.name ?? '',
        dartName: ReCase(resolved.name ?? '').camelCase,
        location: _toParamLocation(resolved.location),
        type: type,
        isRequired: resolved.required ?? false,
        description: resolved.description,
      );
    }).toList();
  }

  FlorvalRequestBody? _analyzeRequestBody(v31.RequestBody? requestBody) {
    if (requestBody == null) return null;

    final jsonContent = requestBody.content['application/json'];
    if (jsonContent == null) return null;

    final schema = jsonContent.schema;
    if (schema == null) return null;

    final type = schemaAnalyzer.schemaToType(schema);

    return FlorvalRequestBody(
      type: type,
      isRequired: requestBody.$required ?? false,
      description: requestBody.description,
    );
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
