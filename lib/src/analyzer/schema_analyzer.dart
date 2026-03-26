import 'package:openapi_spec_plus/v31.dart' as v31;

import '../model/api_schema.dart';
import '../model/api_type.dart';
import '../parser/ref_resolver.dart';
import '../utils/dart_identifier.dart';

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

    // Handle enum schemas (type: string/integer with enum values)
    if (_isEnumSchema(resolved)) {
      return _analyzeEnum(name, resolved);
    }

    // Handle allOf — merge fields from all sub-schemas
    if (resolved.allOf != null && resolved.allOf!.isNotEmpty) {
      return _analyzeAllOf(name, resolved);
    }

    // Handle oneOf — generate sealed class variants
    if (resolved.oneOf != null && resolved.oneOf!.isNotEmpty) {
      return _analyzeOneOf(name, resolved);
    }

    // Handle anyOf — treat same as oneOf for Dart
    if (resolved.anyOf != null && resolved.anyOf!.isNotEmpty) {
      return _analyzeAnyOf(name, resolved);
    }

    // Regular object with properties
    final fields = _extractFields(resolved);

    return FlorvalSchema(
      name: name,
      fields: fields,
      description: resolved.description,
    );
  }

  /// Checks if a schema is an enum (has enum values and no properties).
  bool _isEnumSchema(v31.Schema schema) {
    final enumValues = schema.enumValues;
    return enumValues != null && enumValues.isNotEmpty;
  }

  /// Analyzes an enum schema into a FlorvalSchema with enumValues.
  FlorvalSchema _analyzeEnum(String name, v31.Schema schema) {
    final values = schema.enumValues!
        .where((v) => v != null)
        .map((v) => v.toString())
        .toList();

    return FlorvalSchema(
      name: name,
      fields: [],
      enumValues: values,
      description: schema.description,
    );
  }

  /// Extracts fields from a schema's properties.
  List<FlorvalField> _extractFields(v31.Schema schema) {
    final requiredFields = _requiredFields(schema);
    final fields = <FlorvalField>[];
    final usedNames = <String>{};

    if (schema.properties != null) {
      var index = 0;
      for (final entry in schema.properties!.entries) {
        // Sanitize non-ASCII field names to valid Dart identifiers
        var fieldName = sanitizeToCamelCase(entry.key) ?? 'field$index';

        // Handle collisions
        if (usedNames.contains(fieldName)) {
          fieldName = '$fieldName$index';
        }
        usedNames.add(fieldName);

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
        index++;
      }
    }

    return fields;
  }

  /// Handles allOf — merges all sub-schema fields into one flat schema.
  FlorvalSchema _analyzeAllOf(String name, v31.Schema schema) {
    final mergedFields = <String, FlorvalField>{};

    for (final subSchema in schema.allOf!) {
      final resolved = resolver.resolveSchema(subSchema);
      final subName = resolver.schemaName(subSchema) ?? name;
      final analyzed = FlorvalSchema(
        name: subName,
        fields: _extractFields(resolved),
      );
      for (final field in analyzed.fields) {
        mergedFields[field.jsonKey] = field;
      }
    }

    // Also merge fields from the schema itself (if any)
    for (final field in _extractFields(schema)) {
      mergedFields[field.jsonKey] = field;
    }

    return FlorvalSchema(
      name: name,
      fields: mergedFields.values.toList(),
      description: schema.description,
    );
  }

  /// Handles oneOf — creates variant schemas for sealed class generation.
  FlorvalSchema _analyzeOneOf(String name, v31.Schema schema) {
    final variants = <FlorvalSchema>[];

    for (final subSchema in schema.oneOf!) {
      final resolved = resolver.resolveSchema(subSchema);
      final subName = resolver.schemaName(subSchema);
      if (subName != null) {
        variants.add(FlorvalSchema(
          name: subName,
          fields: _extractFields(resolved),
          description: resolved.description,
        ));
      } else {
        // Inline schema — give it a generated name
        final variantName = '${name}Variant${variants.length}';
        variants.add(FlorvalSchema(
          name: variantName,
          fields: _extractFields(resolved),
          description: resolved.description,
        ));
      }
    }

    // Parse discriminator if present
    FlorvalDiscriminator? discriminator;
    if (schema.discriminator != null) {
      discriminator = FlorvalDiscriminator(
        propertyName: schema.discriminator!.propertyName,
        mapping: schema.discriminator!.mapping?.cast<String, String>(),
      );
    }

    return FlorvalSchema(
      name: name,
      fields: [],
      oneOf: variants,
      discriminator: discriminator,
      description: schema.description,
    );
  }

  /// Handles anyOf — treat the same as oneOf for Dart code generation.
  FlorvalSchema _analyzeAnyOf(String name, v31.Schema schema) {
    final variants = <FlorvalSchema>[];

    for (final subSchema in schema.anyOf!) {
      final resolved = resolver.resolveSchema(subSchema);
      final subName = resolver.schemaName(subSchema);
      if (subName != null) {
        variants.add(FlorvalSchema(
          name: subName,
          fields: _extractFields(resolved),
          description: resolved.description,
        ));
      } else {
        final variantName = '${name}Variant${variants.length}';
        variants.add(FlorvalSchema(
          name: variantName,
          fields: _extractFields(resolved),
          description: resolved.description,
        ));
      }
    }

    FlorvalDiscriminator? discriminator;
    if (schema.discriminator != null) {
      discriminator = FlorvalDiscriminator(
        propertyName: schema.discriminator!.propertyName,
        mapping: schema.discriminator!.mapping?.cast<String, String>(),
      );
    }

    return FlorvalSchema(
      name: name,
      fields: [],
      anyOf: variants,
      discriminator: discriminator,
      description: schema.description,
    );
  }

  /// Converts a schema to a FlorvalType.
  FlorvalType schemaToType(v31.Schema schema) {
    // Handle $ref
    if (schema.ref != null) {
      final name = resolver.schemaName(schema)!;
      final resolved = resolver.resolveSchema(schema);
      final isEnumType = _isEnumSchema(resolved);
      return FlorvalType(
        name: name,
        dartType: name,
        ref: schema.ref,
        isEnum: isEnumType,
      );
    }

    // Handle allOf with a single $ref (common pattern for enum references)
    if (schema.allOf != null && schema.allOf!.isNotEmpty) {
      final refSchema = schema.allOf!.firstWhere(
        (s) => s.ref != null,
        orElse: () => schema.allOf!.first,
      );
      if (refSchema.ref != null) {
        final name = resolver.schemaName(refSchema)!;
        final isNullable = _isNullable(schema);
        final resolved = resolver.resolveSchema(refSchema);
        final isEnumType = _isEnumSchema(resolved);
        return FlorvalType(
          name: name,
          dartType: isNullable ? '$name?' : name,
          isNullable: isNullable,
          ref: refSchema.ref,
          isEnum: isEnumType,
        );
      }
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
    // v3.0 compatibility fallback: nullable: true may still appear
    // if the spec was not normalised through SpecNormalizer.
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
