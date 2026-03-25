import 'package:recase/recase.dart';

import '../model/api_schema.dart';

/// Generates freezed 3.x model classes from FlorvalSchemas.
class ModelGenerator {
  /// Generates a freezed model file for a single schema.
  String generate(FlorvalSchema schema) {
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

    // Imports
    buffer.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");
    buffer.writeln("import 'package:json_annotation/json_annotation.dart';");
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
    buffer.writeln('  const factory ${schema.name}({');

    // Fields
    for (final field in schema.fields) {
      _writeField(buffer, field);
    }

    buffer.writeln('  }) = _${schema.name};');
    buffer.writeln();
    buffer.writeln(
        '  factory ${schema.name}.fromJson(Map<String, dynamic> json) => _\$${schema.name}FromJson(json);');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates a freezed sealed class for union types (oneOf/anyOf).
  String _generateSealedClass(FlorvalSchema schema) {
    final fileName = ReCase(schema.name).snakeCase;
    final variants = schema.oneOf ?? schema.anyOf ?? [];
    final buffer = StringBuffer();

    // Imports
    buffer.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");
    buffer.writeln("import 'package:json_annotation/json_annotation.dart';");
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
    buffer.writeln(
        'sealed class ${schema.name} with _\$${schema.name} {');

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
  void _writeDiscriminatorFromJson(
      StringBuffer buffer, FlorvalSchema schema) {
    final disc = schema.discriminator!;
    final variants = schema.oneOf ?? schema.anyOf ?? [];

    buffer.writeln(
        "  factory ${schema.name}.fromJson(Map<String, dynamic> json) {");
    buffer.writeln("    switch (json['${disc.propertyName}']) {");

    for (final variant in variants) {
      final factoryName = ReCase(variant.name).camelCase;
      // Use explicit mapping if available, otherwise infer from variant name
      final discriminatorValue = disc.mapping != null
          ? disc.mapping!.entries
              .where((e) =>
                  e.value == variant.name ||
                  e.value.endsWith('/${variant.name}'))
              .map((e) => e.key)
              .firstOrNull
          : null;
      final value = discriminatorValue ?? ReCase(variant.name).snakeCase;

      buffer.writeln(
          "      case '$value':");
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
