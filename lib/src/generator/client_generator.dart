import 'package:recase/recase.dart';

import '../config/template_config.dart';
import '../model/api_endpoint.dart';
import '../model/api_response.dart';
import '../model/api_schema.dart';
import '../model/api_type.dart';
import '../utils/doc_comment.dart';
import '../utils/import_collector.dart';
import '../utils/status_code.dart';

/// Generates dio API client classes grouped by tag.
class ClientGenerator {
  final TemplateConfig? templateConfig;

  /// Coercion helper function names referenced by the methods generated in
  /// the current [generate] call. Only these helpers are appended to the
  /// client file, keeping the output free of unused declarations.
  final Set<String> _usedCoercionHelpers = {};

  ClientGenerator({this.templateConfig});

  /// Coercion helper function name per primitive Dart type.
  static const Map<String, String> _coercionHelperNames = {
    'int': '_coerceInt',
    'double': '_coerceDouble',
    'bool': '_coerceBool',
    'String': '_coerceString',
    'DateTime': '_coerceDateTime',
  };

  /// Source code of the defensive coercion helpers emitted into client
  /// files, keyed by helper function name.
  ///
  /// Some server frameworks serialize top-level primitive response bodies
  /// as plain text (e.g. `text/html` or `text/plain`) instead of
  /// `application/json`. In that case dio does not JSON-decode the body and
  /// hands back a `String`, so a plain `as int` cast would throw even
  /// though the spec declares `type: integer`. These helpers accept
  /// whatever representation arrives and coerce it to the declared type.
  ///
  /// Public so tests can execute the exact source that gets generated.
  static const Map<String, String> coercionHelperSources = {
    '_coerceInt': '''
int _coerceInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return num.parse(value.trim()).toInt();
  throw FormatException('Expected an int response body but got: \$value');
}
''',
    '_coerceDouble': '''
double _coerceDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) return double.parse(value.trim());
  throw FormatException('Expected a double response body but got: \$value');
}
''',
    '_coerceBool': '''
bool _coerceBool(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true') return true;
    if (normalized == 'false') return false;
  }
  throw FormatException('Expected a bool response body but got: \$value');
}
''',
    '_coerceString': '''
String _coerceString(dynamic value) {
  if (value is String) return value;
  if (value != null) return value.toString();
  throw const FormatException(
      'Expected a String response body but got null');
}
''',
    '_coerceDateTime': '''
DateTime _coerceDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) return DateTime.parse(value.trim());
  throw FormatException(
      'Expected a date-time response body but got: \$value');
}
''',
  };

  /// Generates a client class for a group of endpoints sharing a tag.
  String generate(String tag, List<FlorvalEndpoint> endpoints) {
    _usedCoercionHelpers.clear();
    final className = '${ReCase(tag).pascalCase}ApiClient';
    final buffer = StringBuffer();

    // Custom header
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
      buffer.writeln();
    }

    // Check if any endpoint has complex multipart fields needing JSON serialization
    final hasComplexMultipart = endpoints.any((e) =>
        e.requestBody != null &&
        e.requestBody!.isMultipart &&
        e.requestBody!.formFields != null &&
        e.requestBody!.formFields!.any((f) => _isComplexMultipartField(f.type)));

    // Imports
    if (hasComplexMultipart) {
      buffer.writeln("import 'dart:convert';");
      buffer.writeln();
    }
    buffer.writeln("import 'package:dio/dio.dart';");
    if (hasComplexMultipart) {
      buffer.writeln("import 'package:http_parser/http_parser.dart';");
    }

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

    _writeCoercionHelpers(buffer);

    return buffer.toString();
  }

  /// Appends the coercion helpers referenced by the generated methods.
  void _writeCoercionHelpers(StringBuffer buffer) {
    if (_usedCoercionHelpers.isEmpty) return;

    buffer.writeln();
    buffer.writeln(
        '// Servers may serialize top-level primitive bodies as plain text');
    buffer.writeln(
        '// instead of JSON, in which case dio hands back a String. These');
    buffer.writeln(
        '// helpers coerce the body to the type declared in the spec');
    buffer.writeln('// regardless of the response Content-Type.');
    for (final name in _coercionHelperNames.values) {
      if (!_usedCoercionHelpers.contains(name)) continue;
      buffer.write(coercionHelperSources[name]);
    }
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
      final successResponses = endpoint.responses.entries
          .where((e) => e.key >= 200 && e.key < 300)
          .toList();
      // Top-level primitive bodies must be requested as <dynamic>: servers
      // may send them as plain text (String) rather than JSON, and a
      // Map/List type argument would make dio fail before the status-code
      // switch runs.
      final hasPrimitiveResponse =
          successResponses.any((e) => e.value.type?.isPrimitive == true);
      final hasListResponse =
          successResponses.any((e) => e.value.type?.isList == true);
      if (hasPrimitiveResponse) {
        dioTypeArg = '<dynamic>';
      } else if (hasListResponse) {
        dioTypeArg = '<List<dynamic>>';
      } else {
        dioTypeArg = '<Map<String, dynamic>>';
      }
    }

    // Detect List<MultipartFile> fields in multipart bodies — Dio's
    // FormData.fromMap defaults to ListFormat.multiCompatible which appends
    // `[]` to array field names, breaking servers that expect strict name
    // matching (e.g. NestJS multer FilesInterceptor). For these fields we
    // emit a preamble that builds `_formData` and pushes each file under
    // the exact same field name via `files.add(MapEntry(name, file))`.
    final useFormDataPreamble = endpoint.requestBody != null &&
        endpoint.requestBody!.isMultipart &&
        endpoint.requestBody!.formFields != null &&
        endpoint.requestBody!.formFields!
            .any((f) => _isMultipartFileListType(f.type));

    if (useFormDataPreamble) {
      _writeMultipartPreamble(buffer, endpoint.requestBody!);
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
        if (useFormDataPreamble) {
          buffer.write('        data: _formData');
        } else {
          buffer.writeln('        data: FormData.fromMap({');
          for (final field in body.formFields!) {
            final valueExpr = _multipartFieldValueExpr(field);
            if (field.isRequired) {
              buffer.writeln("          '${field.jsonKey}': $valueExpr,");
            } else {
              buffer.writeln(
                  "          if (${field.name} != null) '${field.jsonKey}': $valueExpr,");
            }
          }
          buffer.write('        })');
        }
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
      } else if (type.isList &&
          type.itemType != null &&
          _coercionExpr(type.itemType!, 'e') != null) {
        // JSON decoding yields List<dynamic>; casting it to List<int> etc.
        // fails at runtime, so coerce each element instead.
        final itemExpr = _coercionExpr(type.itemType!, 'e')!;
        buffer.writeln(
            '          return $responseType.$factoryName(($dataExpr as List).map((e) => $itemExpr).toList());');
      } else if (_coercionExpr(type, dataExpr) != null) {
        buffer.writeln(
            '          return $responseType.$factoryName(${_coercionExpr(type, dataExpr)!});');
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

  /// Returns an expression that defensively coerces [expr] to [type]'s
  /// primitive Dart type, or null when [type] is not a coercible primitive.
  ///
  /// Records the referenced helper function so it gets appended to the
  /// generated client file.
  String? _coercionExpr(FlorvalType type, String expr) {
    final base = type.dartType.replaceAll('?', '');
    final helper = _coercionHelperNames[base];
    if (helper == null) return null;
    _usedCoercionHelpers.add(helper);
    if (type.dartType.endsWith('?')) {
      return '$expr == null ? null : $helper($expr)';
    }
    return '$helper($expr)';
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

  /// Whether a type represents MultipartFile (single or list).
  bool _isMultipartFileType(FlorvalType type) {
    final base = type.dartType.replaceAll('?', '');
    return base == 'MultipartFile' || base == 'List<MultipartFile>';
  }

  /// Whether a type is specifically `List<MultipartFile>` (not a single
  /// `MultipartFile`). Used to detect form fields that need explicit
  /// per-file MapEntry handling to avoid Dio's `[]` suffix on field names.
  bool _isMultipartFileListType(FlorvalType type) {
    if (!type.isList) return false;
    if (type.itemType == null) return false;
    final itemBase = type.itemType!.dartType.replaceAll('?', '');
    return itemBase == 'MultipartFile';
  }

  /// Emits the preamble that builds a `_formData` local variable when a
  /// multipart body contains one or more `List<MultipartFile>` fields.
  ///
  /// Non-file-list fields go into `FormData.fromMap({...})`; each file in
  /// each file-list field is then appended via
  /// `_formData.files.add(MapEntry(jsonKey, file))` so the field name is
  /// preserved verbatim (no `[]` suffix).
  void _writeMultipartPreamble(
      StringBuffer buffer, FlorvalRequestBody body) {
    final fields = body.formFields!;
    final fileListFields =
        fields.where((f) => _isMultipartFileListType(f.type)).toList();
    final otherFields =
        fields.where((f) => !_isMultipartFileListType(f.type)).toList();

    buffer.writeln('      final _formData = FormData.fromMap({');
    for (final field in otherFields) {
      final valueExpr = _multipartFieldValueExpr(field);
      if (field.isRequired) {
        buffer.writeln("        '${field.jsonKey}': $valueExpr,");
      } else {
        buffer.writeln(
            "        if (${field.name} != null) '${field.jsonKey}': $valueExpr,");
      }
    }
    buffer.writeln('      });');

    for (final field in fileListFields) {
      if (field.isRequired) {
        buffer.writeln('      for (final e in ${field.name}) {');
        buffer.writeln(
            "        _formData.files.add(MapEntry('${field.jsonKey}', e));");
        buffer.writeln('      }');
      } else {
        buffer.writeln('      if (${field.name} != null) {');
        buffer.writeln('        for (final e in ${field.name}!) {');
        buffer.writeln(
            "          _formData.files.add(MapEntry('${field.jsonKey}', e));");
        buffer.writeln('        }');
        buffer.writeln('      }');
      }
    }
  }

  /// Whether a multipart form field is a complex object type that needs
  /// JSON serialization via `MultipartFile.fromString(jsonEncode(...))`.
  bool _isComplexMultipartField(FlorvalType type) {
    if (_isMultipartFileType(type)) return false;
    if (type.isPrimitive) return false;
    if (type.isEnum) return false;
    if (type.isMap) return false;
    // List of non-primitive, non-MultipartFile items
    if (type.isList && type.itemType != null) {
      return !type.itemType!.isPrimitive && !_isMultipartFileType(type.itemType!);
    }
    // Non-primitive single object ($ref or inline object)
    return true;
  }

  /// Builds the value expression for a multipart form field.
  String _multipartFieldValueExpr(FlorvalField field) {
    final type = field.type;
    final name = field.name;
    if (_isMultipartFileType(type)) return name;
    if (type.isPrimitive) return name;
    if (type.isEnum) return '$name.jsonValue';
    if (type.isMap) return name;
    // List types
    if (type.isList && type.itemType != null) {
      if (type.itemType!.isPrimitive || _isMultipartFileType(type.itemType!)) {
        return name;
      }
      if (type.itemType!.isEnum) return '$name.map((e) => e.jsonValue).toList()';
      return "MultipartFile.fromString(jsonEncode($name.map((e) => e.toJson()).toList()), contentType: MediaType('application', 'json'))";
    }
    // Complex object ($ref or non-primitive)
    if (_isComplexMultipartField(type)) {
      return "MultipartFile.fromString(jsonEncode($name.toJson()), contentType: MediaType('application', 'json'))";
    }
    return name;
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
