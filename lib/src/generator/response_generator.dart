import 'package:recase/recase.dart';

import '../config/template_config.dart';
import '../model/api_endpoint.dart';
import '../model/api_response.dart';
import '../model/api_type.dart';
import '../utils/import_collector.dart';
import '../utils/status_code.dart';

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
    final factoryName = statusCodeToFactoryName(statusCode);
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
    final factoryName = statusCodeToFactoryName(statusCode);
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

  /// Collects model imports needed for response types.
  Set<String> _collectImports(FlorvalEndpoint endpoint) {
    final imports = <String>{};
    for (final response in endpoint.responses.values) {
      if (response.type != null) {
        addTypeImport(imports, response.type!);
      }
    }
    return imports;
  }
}
