import 'package:recase/recase.dart';

import '../config/template_config.dart';
import '../model/api_endpoint.dart';
import '../model/api_response.dart';
import '../utils/doc_comment.dart';
import '../utils/import_collector.dart';
import '../utils/status_code.dart';

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

    // Import model types (no prefix — no collision risk between models)
    final modelImports = <String>{};
    for (final endpoint in endpoints) {
      _collectModelImports(endpoint, modelImports);
    }
    for (final import_ in modelImports) {
      buffer.writeln("import '../models/$import_.dart';");
    }

    // Import responses via barrel with r prefix to avoid collision with models
    buffer.writeln("import '../api_responses.dart' as r;");
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
    // Doc comment from summary and/or description
    _writeMethodDocComment(buffer, endpoint);

    // Deprecated annotation
    if (endpoint.deprecated) {
      buffer.writeln("  @Deprecated('')");
    }

    final responseType =
        'r.${ReCase(endpoint.operationId).pascalCase}Response';
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

    final hasAnyResponseBody =
        endpoint.responses.values.any((r) => r.hasBody);

    final String dioTypeArg;
    if (!hasAnyResponseBody) {
      dioTypeArg = '<dynamic>';
    } else {
      final hasListResponse = endpoint.responses.entries
          .where((e) => e.key >= 200 && e.key < 300)
          .any((e) => e.value.type?.isList == true);
      dioTypeArg = hasListResponse ? '<List<dynamic>>' : '<Map<String, dynamic>>';
    }

    buffer.write("      final response = await _dio.$dioMethod$dioTypeArg(");
    buffer.write("'$pathExpr'");

    if (endpoint.queryParameters.isNotEmpty) {
      buffer.writeln(',');
      buffer.writeln('        queryParameters: {');
      for (final p in endpoint.queryParameters) {
        if (p.isRequired) {
          final valueExpr =
              p.type.isEnum ? '${p.dartName}.jsonValue' : p.dartName;
          buffer.writeln("          '${p.name}': $valueExpr,");
        } else {
          final valueExpr =
              p.type.isEnum ? '${p.dartName}.jsonValue' : p.dartName;
          buffer.writeln(
              "          if (${p.dartName} != null) '${p.name}': $valueExpr,");
        }
      }
      buffer.write('        }');
    }

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
    FlorvalResponse response, {
    String dataExpr = 'response.data',
  }) {
    final factoryName = statusCodeToFactoryName(statusCode);

    if (response.hasBody) {
      final type = response.type!;
      buffer.writeln('        case $statusCode:');

      if (type.isList && type.itemType != null && !type.itemType!.isPrimitive) {
        buffer.writeln(
            '          return $responseType.$factoryName(($dataExpr as List).map((e) => ${type.itemType!.dartType}.fromJson(e as Map<String, dynamic>)).toList());');
      } else if (!type.isPrimitive && !type.isMap && !type.isList) {
        buffer.writeln(
            '          return $responseType.$factoryName(${type.dartType}.fromJson($dataExpr as Map<String, dynamic>));');
      } else {
        buffer.writeln(
            '          return $responseType.$factoryName($dataExpr as ${type.dartType});');
      }
    } else {
      buffer.writeln('        case $statusCode:');
      buffer.writeln(
          '          return $responseType.$factoryName();');
    }
  }

  void _writeMethodDocComment(StringBuffer buffer, FlorvalEndpoint endpoint) {
    final hasSummary = endpoint.summary != null && endpoint.summary!.isNotEmpty;
    final hasDescription =
        endpoint.description != null && endpoint.description!.isNotEmpty;

    if (!hasSummary && !hasDescription) return;

    if (hasSummary) {
      writeDocComment(buffer, description: endpoint.summary, indent: '  ');
    }
    if (hasDescription) {
      if (hasSummary) {
        buffer.writeln('  ///');
      }
      writeDocComment(buffer, description: endpoint.description, indent: '  ');
    }
  }

  String _buildPathExpression(FlorvalEndpoint endpoint) {
    var path = endpoint.path;
    for (final p in endpoint.pathParameters) {
      final replacement = p.type.isEnum
          ? '\${${p.dartName}.jsonValue}'
          : '\$${p.dartName}';
      path = path.replaceAll('{${p.name}}', replacement);
    }
    return path;
  }

  void _collectModelImports(
      FlorvalEndpoint endpoint, Set<String> imports) {
    for (final response in endpoint.responses.values) {
      if (response.type != null) {
        addTypeImport(imports, response.type!);
      }
    }
    if (endpoint.requestBody != null && !endpoint.requestBody!.isMultipart) {
      addTypeImport(imports, endpoint.requestBody!.type);
    }
    // For multipart requests, collect imports from form field types
    if (endpoint.requestBody != null &&
        endpoint.requestBody!.isMultipart &&
        endpoint.requestBody!.formFields != null) {
      for (final field in endpoint.requestBody!.formFields!) {
        addTypeImport(imports, field.type);
      }
    }
    for (final p in endpoint.parameters) {
      addTypeImport(imports, p.type);
    }
  }
}
