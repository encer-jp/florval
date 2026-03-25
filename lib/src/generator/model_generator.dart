import 'package:recase/recase.dart';

import '../model/api_schema.dart';

/// Generates freezed 3.x model classes from FlorvalSchemas.
class ModelGenerator {
  /// Generates a freezed model file for a single schema.
  String generate(FlorvalSchema schema) {
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
