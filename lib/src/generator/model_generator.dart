import 'package:recase/recase.dart';

import '../config/template_config.dart';
import '../model/api_schema.dart';
import '../utils/dart_identifier.dart';

/// Generates freezed 3.x model classes from FlorvalSchemas.
class ModelGenerator {
  final TemplateConfig? templateConfig;

  ModelGenerator({this.templateConfig});

  /// Generates a freezed model file for a single schema.
  String generate(FlorvalSchema schema) {
    // Enum schemas → Dart enum with @JsonValue annotations
    if (schema.isEnum) {
      return _generateEnum(schema);
    }
    // Union types (oneOf/anyOf) → sealed class
    if (_isUnionType(schema)) {
      return _generateSealedClass(schema);
    }
    // Regular data class → abstract class
    return _generateDataClass(schema);
  }

  /// Generates a regular freezed abstract data class.
  String _generateDataClass(FlorvalSchema schema) {
    final fileName = ReCase(schema.name).snakeCase;
    final buffer = StringBuffer();

    // Custom header
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
      buffer.writeln();
    }

    // Imports
    buffer.writeln(
        "import 'package:freezed_annotation/freezed_annotation.dart';");

    // Custom model imports
    if (templateConfig != null) {
      for (final import_ in templateConfig!.modelImports) {
        buffer.writeln(import_);
      }
    }
    buffer.writeln();

    // Import referenced types
    final imports = _collectImports(schema);
    for (final import_ in imports) {
      buffer.writeln("import '$import_.dart';");
    }
    if (imports.isNotEmpty) buffer.writeln();

    // Part directives
    buffer.writeln("part '$fileName.freezed.dart';");
    buffer.writeln("part '$fileName.g.dart';");
    buffer.writeln();

    // Class definition
    buffer.writeln('@freezed');
    buffer.writeln('abstract class ${schema.name} with _\$${schema.name} {');
    // Empty fields → no named parameters (avoids freezed parse error)
    if (schema.fields.isEmpty) {
      buffer.writeln('  const factory ${schema.name}() = _${schema.name};');
    } else {
      buffer.writeln('  const factory ${schema.name}({');
      for (final field in schema.fields) {
        _writeField(buffer, field);
      }
      buffer.writeln('  }) = _${schema.name};');
    }
    buffer.writeln();
    buffer.writeln(
        '  factory ${schema.name}.fromJson(Map<String, dynamic> json) => _\$${schema.name}FromJson(json);');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates a Dart enum with @JsonValue annotations for JSON serialization.
  String _generateEnum(FlorvalSchema schema) {
    final buffer = StringBuffer();

    // Custom header
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
      buffer.writeln();
    }

    // Imports
    buffer.writeln("import 'package:json_annotation/json_annotation.dart';");

    // Custom model imports
    if (templateConfig != null) {
      for (final import_ in templateConfig!.modelImports) {
        buffer.writeln(import_);
      }
    }
    buffer.writeln();

    // Enum definition
    buffer.writeln('enum ${schema.name} {');

    final usedNames = <String>{};
    for (var i = 0; i < schema.enumValues!.length; i++) {
      final value = schema.enumValues![i];
      final dartName = _enumValueToDartName(value, i, usedNames);
      final isLast = i == schema.enumValues!.length - 1;

      buffer.writeln("  @JsonValue('$value')");
      buffer.writeln('  $dartName${isLast ? ';' : ','}');
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Converts an OpenAPI enum value to a valid Dart enum member name.
  String _enumValueToDartName(String value, int index, Set<String> usedNames) {
    // Handle empty strings
    if (value.isEmpty) return _uniqueName('empty', index, usedNames);

    // Sanitize non-ASCII characters
    final sanitized = sanitizeToCamelCase(value);

    String name;
    if (sanitized == null) {
      // Entirely non-ASCII: use index-based fallback
      name = 'value$index';
    } else if (RegExp(r'^[0-9]').hasMatch(sanitized)) {
      // Ensure it doesn't start with a digit
      name = 'value$sanitized';
    } else if (_dartReservedWords.contains(sanitized)) {
      // Handle Dart reserved words
      name = '${sanitized}_';
    } else {
      name = sanitized;
    }

    return _uniqueName(name, index, usedNames);
  }

  /// Returns a unique name by appending the index if [base] is already used.
  String _uniqueName(String base, int index, Set<String> usedNames) {
    var name = base;
    if (usedNames.contains(name)) {
      name = '$base$index';
    }
    usedNames.add(name);
    return name;
  }

  static const _dartReservedWords = {
    'assert', 'break', 'case', 'catch', 'class', 'const', 'continue',
    'default', 'do', 'else', 'enum', 'extends', 'false', 'final',
    'finally', 'for', 'if', 'in', 'is', 'new', 'null', 'rethrow',
    'return', 'super', 'switch', 'this', 'throw', 'true', 'try',
    'var', 'void', 'while', 'with', 'yield',
  };

  /// Generates a freezed sealed class for union types (oneOf/anyOf).
  String _generateSealedClass(FlorvalSchema schema) {
    final fileName = ReCase(schema.name).snakeCase;
    final variants = schema.oneOf ?? schema.anyOf ?? [];
    final buffer = StringBuffer();

    // Custom header
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
      buffer.writeln();
    }

    // Imports
    buffer.writeln(
        "import 'package:freezed_annotation/freezed_annotation.dart';");

    // Custom model imports
    if (templateConfig != null) {
      for (final import_ in templateConfig!.modelImports) {
        buffer.writeln(import_);
      }
    }
    buffer.writeln();

    // Import variant types
    final imports = <String>{};
    for (final variant in variants) {
      imports.add(ReCase(variant.name).snakeCase);
    }
    for (final import_ in imports) {
      buffer.writeln("import '$import_.dart';");
    }
    if (imports.isNotEmpty) buffer.writeln();

    // Part directives
    buffer.writeln("part '$fileName.freezed.dart';");
    buffer.writeln("part '$fileName.g.dart';");
    buffer.writeln();

    // Sealed class definition
    buffer.writeln('@freezed');
    buffer.writeln('sealed class ${schema.name} with _\$${schema.name} {');

    // Factory constructors for each variant
    for (final variant in variants) {
      final factoryName = ReCase(variant.name).camelCase;
      final subclassName = '${schema.name}${variant.name}';
      buffer.writeln(
          '  const factory ${schema.name}.$factoryName(${variant.name} data) = $subclassName;');
    }

    buffer.writeln();

    // fromJson with discriminator support
    if (schema.discriminator != null) {
      _writeDiscriminatorFromJson(buffer, schema);
    } else {
      buffer.writeln(
          '  factory ${schema.name}.fromJson(Map<String, dynamic> json) => _\$${schema.name}FromJson(json);');
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Writes a fromJson factory that switches on a discriminator property.
  void _writeDiscriminatorFromJson(StringBuffer buffer, FlorvalSchema schema) {
    final disc = schema.discriminator!;
    final variants = schema.oneOf ?? schema.anyOf ?? [];

    buffer.writeln(
        "  factory ${schema.name}.fromJson(Map<String, dynamic> json) {");
    buffer.writeln("    switch (json['${disc.propertyName}']) {");

    for (final variant in variants) {
      final factoryName = ReCase(variant.name).camelCase;
      // Use explicit mapping if available, otherwise infer from variant name
      final discriminatorValue = disc.mapping?.entries
          .where((e) =>
              e.value == variant.name || e.value.endsWith('/${variant.name}'))
          .map((e) => e.key)
          .firstOrNull;
      final value = discriminatorValue ?? ReCase(variant.name).snakeCase;

      buffer.writeln("      case '$value':");
      buffer.writeln(
          '        return ${schema.name}.$factoryName(${variant.name}.fromJson(json));');
    }

    buffer.writeln('      default:');
    buffer.writeln(
        "        throw UnimplementedError('Unknown ${disc.propertyName}: \${json[\"${disc.propertyName}\"]}');");
    buffer.writeln('    }');
    buffer.writeln('  }');
  }

  bool _isUnionType(FlorvalSchema schema) {
    return (schema.oneOf != null && schema.oneOf!.isNotEmpty) ||
        (schema.anyOf != null && schema.anyOf!.isNotEmpty);
  }

  void _writeField(StringBuffer buffer, FlorvalField field) {
    // Add JsonKey if the Dart name differs from the JSON key
    final needsJsonKey = field.name != field.jsonKey;
    if (needsJsonKey) {
      buffer.writeln("    @JsonKey(name: '${field.jsonKey}')");
    }

    final prefix = field.isRequired ? 'required ' : '';
    buffer.writeln('    $prefix${field.type.dartType} ${field.name},');
  }

  /// Generates the `PaginatedData<T, P>` utility class.
  String generatePaginatedData() {
    final buffer = StringBuffer();

    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
      buffer.writeln();
    }

    buffer.writeln('/// Paginated data container for cursor-based pagination.');
    buffer.writeln('///');
    buffer.writeln('/// [T] is the item type (e.g. Pet, Comment).');
    buffer.writeln('/// [P] is the raw page type returned by the API (e.g. SearchPetsPage, CommentPage).');
    buffer.writeln('class PaginatedData<T, P> {');
    buffer.writeln('  /// The accumulated items across all loaded pages.');
    buffer.writeln('  final List<T> items;');
    buffer.writeln();
    buffer.writeln('  /// The cursor for the next page. Null if no more pages.');
    buffer.writeln('  final String? nextCursor;');
    buffer.writeln();
    buffer.writeln('  /// Whether more pages are available.');
    buffer.writeln('  final bool hasMore;');
    buffer.writeln();
    buffer.writeln('  /// The raw page data from the last API response.');
    buffer.writeln('  /// Use this to access API-specific fields (e.g. totalCount).');
    buffer.writeln('  final P lastPage;');
    buffer.writeln();
    buffer.writeln('  const PaginatedData({');
    buffer.writeln('    required this.items,');
    buffer.writeln('    this.nextCursor,');
    buffer.writeln('    this.hasMore = true,');
    buffer.writeln('    required this.lastPage,');
    buffer.writeln('  });');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates the ApiException utility class.
  String generateApiException() {
    final buffer = StringBuffer();

    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
      buffer.writeln();
    }

    buffer.writeln('/// Exception wrapping a non-success API response.');
    buffer.writeln('class ApiException implements Exception {');
    buffer.writeln('  final dynamic response;');
    buffer.writeln('  const ApiException(this.response);');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln("  String toString() => 'ApiException: \$response';");
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Collects import paths for referenced types.
  Set<String> _collectImports(FlorvalSchema schema) {
    final imports = <String>{};
    for (final field in schema.fields) {
      final type = field.type;
      // Check if this is a reference type (not primitive)
      if (type.ref != null) {
        final refName = type.ref!.split('/').last;
        imports.add(ReCase(refName).snakeCase);
      }
      // Check item type for lists
      if (type.itemType != null && type.itemType!.ref != null) {
        final refName = type.itemType!.ref!.split('/').last;
        imports.add(ReCase(refName).snakeCase);
      }
    }
    return imports;
  }
}
