import 'package:recase/recase.dart';

import '../config/template_config.dart';
import '../model/api_endpoint.dart';

/// Generates dio API client classes grouped by tag.
class ClientGenerator {
  final TemplateConfig? templateConfig;

  ClientGenerator({this.templateConfig});

  /// Generates a client class for a group of endpoints sharing a tag.
  String generate(String tag, List<FlorvalEndpoint> endpoints) {
    final className = '${ReCase(tag).pascalCase}ApiClient';
    final buffer = StringBuffer();

    // Custom header
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
      buffer.writeln();
    }

    // Imports
    buffer.writeln("import 'package:dio/dio.dart';");

    // Custom client imports
    if (templateConfig != null) {
      for (final import_ in templateConfig!.clientImports) {
        buffer.writeln(import_);
      }
    }
    buffer.writeln();

    // Import response types
    final responseImports = <String>{};
    final modelImports = <String>{};

    for (final endpoint in endpoints) {
      final responseName = ReCase(endpoint.operationId).snakeCase;
      responseImports.add(responseName);
      _collectModelImports(endpoint, modelImports);
    }

    for (final import_ in modelImports) {
      buffer.writeln("import '../models/$import_.dart';");
    }
    for (final import_ in responseImports) {
      buffer.writeln("import '../responses/${import_}_api_response.dart';");
    }
    buffer.writeln();

    // Class
    buffer.writeln('class $className {');
    buffer.writeln('  final Dio _dio;');
    buffer.writeln();
    buffer.writeln('  $className(this._dio);');

    for (final endpoint in endpoints) {
      buffer.writeln();
      _writeMethod(buffer, endpoint);
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  void _writeMethod(StringBuffer buffer, FlorvalEndpoint endpoint) {
    final responseType =
        '${ReCase(endpoint.operationId).pascalCase}ApiResponse';
    final methodName = ReCase(endpoint.operationId).camelCase;

    // Method signature
    buffer.write('  Future<$responseType> $methodName(');
    final params = _buildMethodParams(endpoint);
    if (params.isNotEmpty) {
      buffer.writeln('{');
      for (final param in params) {
        buffer.writeln('    $param');
      }
      buffer.write('  }');
    }
    buffer.writeln(') async {');

    // Method body
    buffer.writeln('    try {');
    _writeDioCall(buffer, endpoint);
    _writeResponseSwitch(buffer, endpoint, responseType);
    buffer.writeln('    } on DioException catch (e) {');
    buffer.writeln('      if (e.response != null) {');
    _writeErrorSwitch(buffer, endpoint, responseType);
    buffer.writeln('      }');
    buffer.writeln('      rethrow;');
    buffer.writeln('    }');
    buffer.writeln('  }');
  }

  List<String> _buildMethodParams(FlorvalEndpoint endpoint) {
    final params = <String>[];

    for (final p in endpoint.pathParameters) {
      params.add('required ${p.type.dartType} ${p.dartName},');
    }
    for (final p in endpoint.queryParameters) {
      if (p.isRequired) {
        params.add('required ${p.type.dartType} ${p.dartName},');
      } else {
        params.add('${p.type.asNullable().dartType} ${p.dartName},');
      }
    }
    if (endpoint.requestBody != null) {
      final body = endpoint.requestBody!;
      if (body.isMultipart && body.formFields != null) {
        // Expand multipart form fields as individual parameters
        for (final field in body.formFields!) {
          if (field.isRequired) {
            params.add('required ${field.type.dartType} ${field.name},');
          } else {
            params.add('${field.type.asNullable().dartType} ${field.name},');
          }
        }
      } else {
        if (body.isRequired) {
          params.add('required ${body.type.dartType} body,');
        } else {
          params.add('${body.type.asNullable().dartType} body,');
        }
      }
    }

    return params;
  }

  void _writeDioCall(StringBuffer buffer, FlorvalEndpoint endpoint) {
    final dioMethod = endpoint.method.toLowerCase();
    final pathExpr = _buildPathExpression(endpoint);

    // Check if any response has a body (needs JSON parsing)
    final hasAnyResponseBody =
        endpoint.responses.values.any((r) => r.hasBody);

    buffer.write("      final response = await _dio.$dioMethod(");
    buffer.write("'$pathExpr'");

    // Query parameters
    if (endpoint.queryParameters.isNotEmpty) {
      buffer.writeln(',');
      buffer.writeln('        queryParameters: {');
      for (final p in endpoint.queryParameters) {
        if (p.isRequired) {
          // Enum types need .name to serialize as the string value
          final valueExpr = p.type.isEnum ? '${p.dartName}.name' : p.dartName;
          buffer.writeln("          '${p.name}': $valueExpr,");
        } else {
          // Inside null-check guard, so use . not ?. for enum .name
          final valueExpr =
              p.type.isEnum ? '${p.dartName}.name' : p.dartName;
          buffer.writeln(
              "          if (${p.dartName} != null) '${p.name}': $valueExpr,");
        }
      }
      buffer.write('        }');
    }

    // Request body
    if (endpoint.requestBody != null) {
      final body = endpoint.requestBody!;
      if (body.isMultipart && body.formFields != null) {
        buffer.writeln(',');
        buffer.writeln('        data: FormData.fromMap({');
        for (final field in body.formFields!) {
          if (field.isRequired) {
            buffer.writeln("          '${field.jsonKey}': ${field.name},");
          } else {
            buffer.writeln(
                "          if (${field.name} != null) '${field.jsonKey}': ${field.name},");
          }
        }
        buffer.write('        })');
      } else {
        buffer.writeln(',');
        buffer.write('        data: body');
        if (body.type.isList &&
            body.type.itemType != null &&
            !body.type.itemType!.isPrimitive) {
          buffer.write('.map((e) => e.toJson()).toList()');
        } else if (!body.type.isPrimitive) {
          buffer.write('.toJson()');
        }
      }
    }

    // Use plain responseType when no response has a body to avoid JSON parse errors
    if (!hasAnyResponseBody) {
      buffer.writeln(',');
      buffer.write(
          '        options: Options(responseType: ResponseType.plain)');
    }

    buffer.writeln(',');
    buffer.writeln('      );');
  }

  void _writeResponseSwitch(
      StringBuffer buffer, FlorvalEndpoint endpoint, String responseType) {
    buffer.writeln('      switch (response.statusCode) {');
    final sortedResponses = endpoint.responses.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedResponses) {
      _writeSwitchCase(buffer, responseType, entry.key, entry.value);
    }

    buffer.writeln(
        '        default:');
    buffer.writeln(
        '          return $responseType.unknown(response.statusCode ?? 0, response.data);');

    buffer.writeln('      }');
  }

  void _writeErrorSwitch(
      StringBuffer buffer, FlorvalEndpoint endpoint, String responseType) {
    buffer.writeln('        switch (e.response!.statusCode) {');
    final errorResponses = endpoint.responses.entries
        .where((e) => e.key >= 400)
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in errorResponses) {
      _writeSwitchCase(
          buffer, responseType, entry.key, entry.value,
          dataExpr: 'e.response!.data');
    }

    buffer.writeln('          default:');
    buffer.writeln(
        '            return $responseType.unknown(e.response!.statusCode ?? 0, e.response!.data);');
    buffer.writeln('        }');
  }

  void _writeSwitchCase(
    StringBuffer buffer,
    String responseType,
    int statusCode,
    dynamic response, {
    String dataExpr = 'response.data',
  }) {
    final factoryName = _statusCodeToFactoryName(statusCode);

    if (response.hasBody) {
      final type = response.type;
      buffer.writeln('        case $statusCode:');

      if (type.isList && type.itemType != null && !type.itemType.isPrimitive) {
        // List of objects
        buffer.writeln(
            '          return $responseType.$factoryName(($dataExpr as List).map((e) => ${type.itemType.dartType}.fromJson(e as Map<String, dynamic>)).toList());');
      } else if (!type.isPrimitive && !type.isMap && !type.isList) {
        // Single object
        buffer.writeln(
            '          return $responseType.$factoryName(${type.dartType}.fromJson($dataExpr as Map<String, dynamic>));');
      } else {
        // Primitive or Map
        buffer.writeln(
            '          return $responseType.$factoryName($dataExpr as ${type.dartType});');
      }
    } else {
      buffer.writeln('        case $statusCode:');
      buffer.writeln(
          '          return $responseType.$factoryName();');
    }
  }

  String _buildPathExpression(FlorvalEndpoint endpoint) {
    var path = endpoint.path;
    for (final p in endpoint.pathParameters) {
      path = path.replaceAll('{${p.name}}', '\$${p.dartName}');
    }
    return path;
  }

  String _statusCodeToFactoryName(int code) {
    return switch (code) {
      200 => 'success',
      201 => 'created',
      204 => 'noContent',
      400 => 'badRequest',
      401 => 'unauthorized',
      403 => 'forbidden',
      404 => 'notFound',
      409 => 'conflict',
      422 => 'unprocessableEntity',
      429 => 'tooManyRequests',
      500 => 'serverError',
      502 => 'badGateway',
      503 => 'serviceUnavailable',
      0 => 'defaultResponse',
      _ => 'status$code',
    };
  }

  void _collectModelImports(
      FlorvalEndpoint endpoint, Set<String> imports) {
    // From responses
    for (final response in endpoint.responses.values) {
      if (response.type != null) {
        _addTypeImport(imports, response.type!);
      }
    }
    // From request body (skip multipart — no model to import)
    if (endpoint.requestBody != null && !endpoint.requestBody!.isMultipart) {
      _addTypeImport(imports, endpoint.requestBody!.type);
    }
    // From path and query parameters (e.g. enum types)
    for (final p in endpoint.parameters) {
      _addTypeImport(imports, p.type);
    }
  }

  void _addTypeImport(Set<String> imports, dynamic type) {
    if (type.ref != null) {
      final refName = (type.ref as String).split('/').last;
      imports.add(ReCase(refName).snakeCase);
    }
    if (type.isList == true && type.itemType != null) {
      _addTypeImport(imports, type.itemType);
    }
  }
}
