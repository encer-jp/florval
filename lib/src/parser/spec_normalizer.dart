/// Normalizes OpenAPI 2.0 (Swagger) and 3.0 specs to OpenAPI 3.1 format
/// at the raw Map level, before parsing with openapi_spec_plus v31.
///
/// This approach avoids needing to construct v31 objects from v30/v20 types
/// directly, which may have limited constructors.
class SpecNormalizer {
  /// Detects the OpenAPI version from a raw spec map.
  /// Returns '2.0', '3.0', '3.1', or 'unknown'.
  String detectVersion(Map<String, dynamic> spec) {
    final swagger = spec['swagger'];
    if (swagger is String && swagger.startsWith('2')) return '2.0';

    final openapi = spec['openapi'];
    if (openapi is String) {
      if (openapi.startsWith('3.1')) return '3.1';
      if (openapi.startsWith('3.0')) return '3.0';
    }

    return 'unknown';
  }

  /// Normalizes an OpenAPI 3.0 spec map to 3.1 format.
  /// The main difference is the `openapi` version string.
  /// Structural differences (like `nullable`) are already handled
  /// by SchemaAnalyzer._isNullable which checks both styles.
  Map<String, dynamic> normalizeV30(Map<String, dynamic> spec) {
    final result = Map<String, dynamic>.from(spec);
    result['openapi'] = '3.1.0';
    return result;
  }

  /// Normalizes a Swagger 2.0 spec map to OpenAPI 3.1 format.
  Map<String, dynamic> normalizeV20(Map<String, dynamic> spec) {
    final result = <String, dynamic>{
      'openapi': '3.1.0',
      'info': spec['info'] ?? {'title': 'API', 'version': '1.0.0'},
    };

    // Convert host + basePath + schemes → servers
    result['servers'] = _convertServers(spec);

    // Convert paths
    if (spec['paths'] != null) {
      result['paths'] = _convertPaths(
        _toStringDynMap(spec['paths']),
        spec['consumes'] as List? ?? ['application/json'],
        spec['produces'] as List? ?? ['application/json'],
      );
    }

    // Convert definitions → components.schemas
    final components = <String, dynamic>{};
    if (spec['definitions'] != null) {
      components['schemas'] = _convertDefinitions(
        _toStringDynMap(spec['definitions']),
      );
    }
    if (spec['parameters'] != null) {
      components['parameters'] = _convertV20Parameters(
        _toStringDynMap(spec['parameters']),
      );
    }
    if (spec['responses'] != null) {
      components['responses'] = _convertV20Responses(
        _toStringDynMap(spec['responses']),
        spec['produces'] as List? ?? ['application/json'],
      );
    }
    if (components.isNotEmpty) {
      result['components'] = components;
    }

    return result;
  }

  List<Map<String, dynamic>> _convertServers(Map<String, dynamic> spec) {
    final host = spec['host'] as String? ?? 'localhost';
    final basePath = spec['basePath'] as String? ?? '/';
    final schemes = spec['schemes'] as List? ?? ['https'];
    final scheme = schemes.isNotEmpty ? schemes.first : 'https';
    return [
      {'url': '$scheme://$host$basePath'},
    ];
  }

  Map<String, dynamic> _convertPaths(
    Map<String, dynamic> paths,
    List globalConsumes,
    List globalProduces,
  ) {
    final result = <String, dynamic>{};
    for (final entry in paths.entries) {
      result[entry.key] = _convertPathItem(
        _toStringDynMap(entry.value),
        globalConsumes,
        globalProduces,
      );
    }
    return result;
  }

  Map<String, dynamic> _convertPathItem(
    Map<String, dynamic> pathItem,
    List globalConsumes,
    List globalProduces,
  ) {
    final result = <String, dynamic>{};
    final methods = ['get', 'post', 'put', 'delete', 'patch', 'options', 'head'];

    // Copy path-level parameters
    if (pathItem['parameters'] != null) {
      result['parameters'] = _convertParameterList(
        pathItem['parameters'] as List,
      );
    }

    for (final method in methods) {
      if (pathItem[method] != null) {
        result[method] = _convertOperation(
          _toStringDynMap(pathItem[method]),
          globalConsumes,
          globalProduces,
        );
      }
    }

    return result;
  }

  Map<String, dynamic> _convertOperation(
    Map<String, dynamic> operation,
    List globalConsumes,
    List globalProduces,
  ) {
    final result = <String, dynamic>{};

    // Copy simple fields
    for (final key in ['operationId', 'summary', 'description', 'tags']) {
      if (operation[key] != null) result[key] = operation[key];
    }

    final consumes = operation['consumes'] as List? ?? globalConsumes;
    final produces = operation['produces'] as List? ?? globalProduces;

    // Convert parameters: separate body params from others
    final parameters = operation['parameters'] as List? ?? [];
    final nonBodyParams = <dynamic>[];
    Map<String, dynamic>? requestBody;

    for (final param in parameters) {
      final p = _toStringDynMap(param);
      if (p['in'] == 'body') {
        requestBody = _convertBodyParam(p, consumes);
      } else if (p['in'] == 'formData') {
        // Skip formData for now (could be extended)
      } else {
        nonBodyParams.add(_convertParameter(p));
      }
    }

    if (nonBodyParams.isNotEmpty) {
      result['parameters'] = nonBodyParams;
    }

    if (requestBody != null) {
      result['requestBody'] = requestBody;
    }

    // Convert responses
    if (operation['responses'] != null) {
      result['responses'] = _convertOperationResponses(
        _toStringDynMap(operation['responses']),
        produces,
      );
    }

    return result;
  }

  Map<String, dynamic> _convertBodyParam(
      Map<String, dynamic> param, List consumes) {
    final schema = param['schema'];
    final contentType =
        consumes.isNotEmpty ? consumes.first.toString() : 'application/json';

    return {
      'required': param['required'] ?? false,
      if (param['description'] != null) 'description': param['description'],
      'content': {
        contentType: {
          'schema': _rewriteRefs(schema),
        },
      },
    };
  }

  Map<String, dynamic> _convertParameter(Map<String, dynamic> param) {
    if (param[r'$ref'] != null) {
      return {r'$ref': _rewriteRefPath(param[r'$ref'] as String)};
    }

    final result = <String, dynamic>{
      'name': param['name'],
      'in': param['in'],
    };

    if (param['required'] != null) result['required'] = param['required'];
    if (param['description'] != null) {
      result['description'] = param['description'];
    }

    // v2.0 has type directly on parameter, v3.1 uses schema
    if (param['type'] != null) {
      result['schema'] = _convertV20Type(param);
    } else if (param['schema'] != null) {
      result['schema'] = _rewriteRefs(param['schema']);
    }

    return result;
  }

  List<dynamic> _convertParameterList(List params) {
    return params.map((p) => _convertParameter(_toStringDynMap(p))).toList();
  }

  Map<String, dynamic> _convertOperationResponses(
    Map<String, dynamic> responses,
    List produces,
  ) {
    final result = <String, dynamic>{};
    for (final entry in responses.entries) {
      result[entry.key] = _convertResponse(
        _toStringDynMap(entry.value),
        produces,
      );
    }
    return result;
  }

  Map<String, dynamic> _convertResponse(
      Map<String, dynamic> response, List produces) {
    if (response[r'$ref'] != null) {
      return {r'$ref': _rewriteRefPath(response[r'$ref'] as String)};
    }

    final result = <String, dynamic>{};
    if (response['description'] != null) {
      result['description'] = response['description'];
    }

    // v2.0 response has 'schema' directly; v3.1 uses content
    if (response['schema'] != null) {
      final contentType =
          produces.isNotEmpty ? produces.first.toString() : 'application/json';
      result['content'] = {
        contentType: {
          'schema': _rewriteRefs(response['schema']),
        },
      };
    }

    return result;
  }

  Map<String, dynamic> _convertDefinitions(Map<String, dynamic> definitions) {
    final result = <String, dynamic>{};
    for (final entry in definitions.entries) {
      result[entry.key] = _rewriteRefs(entry.value);
    }
    return result;
  }

  Map<String, dynamic> _convertV20Parameters(Map<String, dynamic> params) {
    final result = <String, dynamic>{};
    for (final entry in params.entries) {
      result[entry.key] = _convertParameter(_toStringDynMap(entry.value));
    }
    return result;
  }

  Map<String, dynamic> _convertV20Responses(
      Map<String, dynamic> responses, List produces) {
    final result = <String, dynamic>{};
    for (final entry in responses.entries) {
      result[entry.key] = _convertResponse(
        _toStringDynMap(entry.value),
        produces,
      );
    }
    return result;
  }

  /// Converts a Swagger 2.0 inline type to a schema object.
  Map<String, dynamic> _convertV20Type(Map<String, dynamic> param) {
    final schema = <String, dynamic>{};

    if (param['type'] == 'file') {
      schema['type'] = 'string';
      schema['format'] = 'binary';
    } else if (param['type'] == 'array') {
      schema['type'] = 'array';
      if (param['items'] != null) {
        schema['items'] = _rewriteRefs(param['items']);
      }
    } else {
      schema['type'] = param['type'];
      if (param['format'] != null) schema['format'] = param['format'];
    }

    if (param['enum'] != null) schema['enum'] = param['enum'];
    if (param['default'] != null) schema['default'] = param['default'];

    return schema;
  }

  /// Recursively rewrites $ref paths from v2.0 format to v3.1 format.
  /// '#/definitions/User' → '#/components/schemas/User'
  /// '#/parameters/X' → '#/components/parameters/X'
  /// '#/responses/X' → '#/components/responses/X'
  dynamic _rewriteRefs(dynamic value) {
    if (value == null) return null;

    if (value is Map) {
      final map = _toStringDynMap(value);
      final result = <String, dynamic>{};

      for (final entry in map.entries) {
        if (entry.key == r'$ref' && entry.value is String) {
          result[r'$ref'] = _rewriteRefPath(entry.value as String);
        } else {
          result[entry.key] = _rewriteRefs(entry.value);
        }
      }
      return result;
    }

    if (value is List) {
      return value.map((e) => _rewriteRefs(e)).toList();
    }

    return value;
  }

  String _rewriteRefPath(String ref) {
    if (ref.startsWith('#/definitions/')) {
      return ref.replaceFirst('#/definitions/', '#/components/schemas/');
    }
    if (ref.startsWith('#/parameters/')) {
      return ref.replaceFirst('#/parameters/', '#/components/parameters/');
    }
    if (ref.startsWith('#/responses/')) {
      return ref.replaceFirst('#/responses/', '#/components/responses/');
    }
    return ref;
  }

  Map<String, dynamic> _toStringDynMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return {};
  }
}
