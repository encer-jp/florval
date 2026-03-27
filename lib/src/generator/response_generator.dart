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

    // Detect model imports that collide with the response Union class name
    final imports = _collectImports(endpoint);
    final collidingModels = _detectCollisions(className, imports, endpoint);

    for (final import_ in imports) {
      if (collidingModels.containsKey(import_)) {
        buffer.writeln(
            "import '../models/$import_.dart' as ${collidingModels[import_]};");
      } else {
        buffer.writeln("import '../models/$import_.dart';");
      }
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
      _writeFactory(buffer, className, entry.key, entry.value,
          collidingModels: collidingModels);
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
    FlorvalResponse response, {
    Map<String, String> collidingModels = const {},
  }) {
    final factoryName = _statusCodeToFactoryName(statusCode);
    final subclassName = '$className${ReCase(factoryName).pascalCase}';

    if (response.hasBody) {
      final dartType =
          _resolveType(response.type!, collidingModels);
      buffer.writeln(
          '  const factory $className.$factoryName($dartType data) = $subclassName;');
    } else {
      buffer.writeln(
          '  const factory $className.$factoryName() = $subclassName;');
    }
  }

  /// Resolves a type's dart representation, applying import alias prefixes
  /// for types that collide with the response class name.
  String _resolveType(
      dynamic type, Map<String, String> collidingModels) {
    if (type.ref != null) {
      final refName = (type.ref as String).split('/').last;
      final snakeName = ReCase(refName).snakeCase;
      if (collidingModels.containsKey(snakeName)) {
        final prefix = collidingModels[snakeName]!;
        if (type.isList == true) {
          return 'List<$prefix.${type.itemType?.dartType ?? refName}>';
        }
        return '$prefix.${type.dartType as String}';
      }
    }
    if (type.isList == true && type.itemType != null) {
      final resolvedItem = _resolveType(type.itemType, collidingModels);
      if (resolvedItem != (type.itemType.dartType as String)) {
        return 'List<$resolvedItem>';
      }
    }
    return type.dartType as String;
  }

  /// Detects model imports whose class name collides with the response
  /// Union class name. Returns a map of snake_case import → alias prefix.
  Map<String, String> _detectCollisions(
    String responseClassName,
    Set<String> modelImports,
    FlorvalEndpoint endpoint,
  ) {
    final collisions = <String, String>{};
    // Collect all model class names referenced in responses
    for (final response in endpoint.responses.values) {
      if (response.type != null) {
        _checkTypeCollision(
            response.type!, responseClassName, collisions);
      }
    }
    return collisions;
  }

  void _checkTypeCollision(
    dynamic type,
    String responseClassName,
    Map<String, String> collisions,
  ) {
    if (type.ref != null) {
      final refName = (type.ref as String).split('/').last;
      if (refName == responseClassName) {
        final snakeName = ReCase(refName).snakeCase;
        collisions[snakeName] = '_m';
      }
    }
    if (type.isList == true && type.itemType != null) {
      _checkTypeCollision(type.itemType, responseClassName, collisions);
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
