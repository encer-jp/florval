import 'package:recase/recase.dart';

import '../config/template_config.dart';
import '../model/api_endpoint.dart';
import '../model/api_response.dart';

/// Generates freezed 3.x sealed classes for status-code-based response Union types.
class ResponseGenerator {
  final TemplateConfig? templateConfig;

  ResponseGenerator({this.templateConfig});

  /// Generates a response Union type for an endpoint.
  String generate(FlorvalEndpoint endpoint) {
    final className =
        '${ReCase(endpoint.operationId).pascalCase}Response';
    final fileName = ReCase(endpoint.operationId).snakeCase;
    final buffer = StringBuffer();

    // Custom header
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
      buffer.writeln();
    }

    // Imports
    buffer.writeln(
        "import 'package:freezed_annotation/freezed_annotation.dart';");
    buffer.writeln();

    // Import model types used in responses
    final imports = _collectImports(endpoint);
    for (final import_ in imports) {
      buffer.writeln("import '../models/$import_.dart';");
    }
    if (imports.isNotEmpty) buffer.writeln();

    // Part directive
    buffer.writeln("part '${fileName}_response.freezed.dart';");
    buffer.writeln();

    // Sealed class
    buffer.writeln('@freezed');
    buffer.writeln('sealed class $className with _\$$className {');

    // Factory for each status code
    final sortedResponses = endpoint.responses.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    for (final entry in sortedResponses) {
      _writeFactory(buffer, className, entry.key, entry.value);
    }

    // Unknown fallback
    buffer.writeln(
        '  const factory $className.unknown(int statusCode, dynamic body) = ${className}Unknown;');

    buffer.writeln('}');

    return buffer.toString();
  }

  void _writeFactory(
    StringBuffer buffer,
    String className,
    int statusCode,
    FlorvalResponse response,
  ) {
    final factoryName = _statusCodeToFactoryName(statusCode);
    final subclassName = '$className${ReCase(factoryName).pascalCase}';

    if (response.hasBody) {
      buffer.writeln(
          '  const factory $className.$factoryName(${response.type!.dartType} data) = $subclassName;');
    } else {
      buffer.writeln(
          '  const factory $className.$factoryName() = $subclassName;');
    }
  }

  /// Maps HTTP status codes to factory names.
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

  /// Collects model imports needed for response types.
  Set<String> _collectImports(FlorvalEndpoint endpoint) {
    final imports = <String>{};
    for (final response in endpoint.responses.values) {
      if (response.type != null) {
        _addTypeImport(imports, response.type!);
      }
    }
    return imports;
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
