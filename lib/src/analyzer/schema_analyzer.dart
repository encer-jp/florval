import 'package:openapi_spec_plus/v31.dart' as v31;
import 'package:recase/recase.dart';

import '../model/api_schema.dart';
import '../model/api_type.dart';
import '../parser/ref_resolver.dart';

/// Converts OpenAPI schemas to florval intermediate representations.
class SchemaAnalyzer {
  final RefResolver resolver;

  SchemaAnalyzer(this.resolver);

  /// Converts all component schemas to FlorvalSchemas.
  List<FlorvalSchema> analyzeAll(Map<String, v31.Schema> schemas) {
    return schemas.entries.map((e) => analyze(e.key, e.value)).toList();
  }

  /// Converts a single named schema to a FlorvalSchema.
  FlorvalSchema analyze(String name, v31.Schema schema) {
    final resolved = resolver.resolveSchema(schema);
    final requiredFields = _requiredFields(resolved);
    final fields = <FlorvalField>[];

    if (resolved.properties != null) {
      for (final entry in resolved.properties!.entries) {
        final fieldName = ReCase(entry.key).camelCase;
        final fieldSchema = entry.value;
        final isRequired = requiredFields.contains(entry.key);
        final type = schemaToType(fieldSchema);

        fields.add(FlorvalField(
          name: fieldName,
          jsonKey: entry.key,
          type: isRequired ? type : type.asNullable(),
          isRequired: isRequired,
          description: fieldSchema.description,
        ));
      }
    }

    return FlorvalSchema(
      name: name,
      fields: fields,
      description: resolved.description,
    );
  }

  /// Converts a schema to a FlorvalType.
  FlorvalType schemaToType(v31.Schema schema) {
    // Handle $ref
    if (schema.ref != null) {
      final name = resolver.schemaName(schema)!;
      return FlorvalType(
        name: name,
        dartType: name,
        ref: schema.ref,
      );
    }

    final type = _extractType(schema);
    final isNullable = _isNullable(schema);

    switch (type) {
      case 'string':
        return _stringType(schema, isNullable);
      case 'integer':
        return _intType(schema, isNullable);
      case 'number':
        return _numberType(schema, isNullable);
      case 'boolean':
        return FlorvalType(
          name: 'bool',
          dartType: isNullable ? 'bool?' : 'bool',
          isNullable: isNullable,
        );
      case 'array':
        return _arrayType(schema, isNullable);
      case 'object':
        return _objectType(schema, isNullable);
      default:
        return FlorvalType(
          name: 'dynamic',
          dartType: 'dynamic',
        );
    }
  }

  FlorvalType _stringType(v31.Schema schema, bool isNullable) {
    final format = schema.format;
    if (format == 'date-time' || format == 'date') {
      return FlorvalType(
        name: 'DateTime',
        dartType: isNullable ? 'DateTime?' : 'DateTime',
        isNullable: isNullable,
      );
    }
    if (format == 'binary') {
      return FlorvalType(
        name: 'List<int>',
        dartType: isNullable ? 'List<int>?' : 'List<int>',
        isNullable: isNullable,
        isList: true,
      );
    }
    return FlorvalType(
      name: 'String',
      dartType: isNullable ? 'String?' : 'String',
      isNullable: isNullable,
    );
  }

  FlorvalType _intType(v31.Schema schema, bool isNullable) {
    return FlorvalType(
      name: 'int',
      dartType: isNullable ? 'int?' : 'int',
      isNullable: isNullable,
    );
  }

  FlorvalType _numberType(v31.Schema schema, bool isNullable) {
    return FlorvalType(
      name: 'double',
      dartType: isNullable ? 'double?' : 'double',
      isNullable: isNullable,
    );
  }

  FlorvalType _arrayType(v31.Schema schema, bool isNullable) {
    final itemType = schema.items != null
        ? schemaToType(schema.items!)
        : const FlorvalType(name: 'dynamic', dartType: 'dynamic');

    final dartType = 'List<${itemType.dartType}>';
    return FlorvalType(
      name: dartType,
      dartType: isNullable ? '$dartType?' : dartType,
      isNullable: isNullable,
      isList: true,
      itemType: itemType,
    );
  }

  FlorvalType _objectType(v31.Schema schema, bool isNullable) {
    // Object with no properties → Map<String, dynamic>
    if (schema.properties == null || schema.properties!.isEmpty) {
      const dartType = 'Map<String, dynamic>';
      return FlorvalType(
        name: dartType,
        dartType: isNullable ? '$dartType?' : dartType,
        isNullable: isNullable,
      );
    }
    // Object with properties should have been handled as a named schema
    // If we get here, it's an inline object — treat as Map
    const dartType = 'Map<String, dynamic>';
    return FlorvalType(
      name: dartType,
      dartType: isNullable ? '$dartType?' : dartType,
      isNullable: isNullable,
    );
  }

  /// Extracts the primary type string from a schema.
  String _extractType(v31.Schema schema) {
    final type = schema.type;
    if (type == null) return 'object';
    if (type is String) return type;
    if (type is List) {
      // e.g. ["string", "null"] → "string"
      final types = type.cast<String>();
      return types.firstWhere((t) => t != 'null', orElse: () => 'object');
    }
    return 'object';
  }

  /// Checks if a schema is nullable.
  bool _isNullable(v31.Schema schema) {
    // OpenAPI 3.0 style
    if (schema.nullable == true) return true;
    // OpenAPI 3.1 style: type is ["string", "null"]
    final type = schema.type;
    if (type is List) {
      return type.cast<String>().contains('null');
    }
    return false;
  }

  /// Gets the list of required field names from a schema.
  List<String> _requiredFields(v31.Schema schema) {
    return schema.$required ?? [];
  }
}
