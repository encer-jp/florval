import 'package:recase/recase.dart';

import '../config/template_config.dart';
import '../model/api_endpoint.dart';
import '../model/api_response.dart';
import '../model/api_type.dart';

/// Generates plain Dart sealed classes for status-code-based response Union types.
///
/// No freezed dependency — response types only need pattern matching,
/// not copyWith/equality/serialization.
class ResponseGenerator {
  final TemplateConfig? templateConfig;

  ResponseGenerator({this.templateConfig});

  /// Generates a response Union type for an endpoint.
  String generate(FlorvalEndpoint endpoint) {
    final className =
        '${ReCase(endpoint.operationId).pascalCase}Response';
    final buffer = StringBuffer();

    // Custom header
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
      buffer.writeln();
    }

    // Import model types with m prefix to avoid collision with response class name
    final imports = _collectImports(endpoint);
    for (final import_ in imports) {
      buffer.writeln("import '../models/$import_.dart' as m;");
    }
    if (imports.isNotEmpty) buffer.writeln();

    // Sealed class with redirecting factory constructors
    buffer.writeln('sealed class $className {');
    buffer.writeln('  const $className();');
    buffer.writeln();

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
    buffer.writeln();

    // Subclasses
    for (final entry in sortedResponses) {
      _writeSubclass(buffer, className, entry.key, entry.value);
    }

    // Unknown subclass
    buffer.writeln('class ${className}Unknown extends $className {');
    buffer.writeln('  final int statusCode;');
    buffer.writeln('  final dynamic body;');
    buffer.writeln('  const ${className}Unknown(this.statusCode, this.body);');
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
      final dartType = _prefixModelType(response.type!);
      buffer.writeln(
          '  const factory $className.$factoryName($dartType data) = $subclassName;');
    } else {
      buffer.writeln(
          '  const factory $className.$factoryName() = $subclassName;');
    }
  }

  void _writeSubclass(
    StringBuffer buffer,
    String className,
    int statusCode,
    FlorvalResponse response,
  ) {
    final factoryName = _statusCodeToFactoryName(statusCode);
    final subclassName = '$className${ReCase(factoryName).pascalCase}';

    buffer.writeln('class $subclassName extends $className {');
    if (response.hasBody) {
      final dartType = _prefixModelType(response.type!);
      buffer.writeln('  final $dartType data;');
      buffer.writeln('  const $subclassName(this.data);');
    } else {
      buffer.writeln('  const $subclassName();');
    }
    buffer.writeln('}');
    buffer.writeln();
  }

  /// Prefixes model types with `m.` for imports that use the `as m` alias.
  /// Primitives and Map types are not prefixed.
  String _prefixModelType(FlorvalType type) {
    if (type.isList && type.itemType != null) {
      final inner = _prefixModelType(type.itemType!);
      return 'List<$inner>';
    }
    if (type.ref != null) {
      return 'm.${type.dartType}';
    }
    return type.dartType;
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
