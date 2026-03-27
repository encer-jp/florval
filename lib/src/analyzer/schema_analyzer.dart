import 'package:openapi_spec_plus/v31.dart' as v31;
import 'package:recase/recase.dart';

import '../model/api_schema.dart';
import '../model/api_type.dart';
import '../parser/ref_resolver.dart';
import '../utils/dart_identifier.dart';
import '../utils/logger.dart';

/// Converts OpenAPI schemas to florval intermediate representations.
class SchemaAnalyzer {
  final RefResolver resolver;
  final FlorvalLogger? logger;

  /// Inline union schemas discovered during schema analysis.
  /// These need to be generated as separate model files.
  final List<FlorvalSchema> inlineUnionSchemas = [];

  /// Inline object schemas discovered during schema analysis.
  /// These need to be generated as separate model files.
  final List<FlorvalSchema> inlineObjectSchemas = [];

  SchemaAnalyzer(this.resolver, {this.logger});

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
    final fields = _extractFields(resolved, schemaName: name);

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
  ///
  /// [schemaName] is used to generate context names for inline union types.
  List<FlorvalField> _extractFields(v31.Schema schema, {String? schemaName}) {
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
        final contextName = schemaName != null
            ? '$schemaName${ReCase(entry.key).pascalCase}'
            : null;
        final type = schemaToType(fieldSchema, contextName: contextName);

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
        fields: _extractFields(resolved, schemaName: name),
      );
      for (final field in analyzed.fields) {
        mergedFields[field.jsonKey] = field;
      }
    }

    // Also merge fields from the schema itself (if any)
    for (final field in _extractFields(schema, schemaName: name)) {
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
    return _analyzeComposite(name, schema, schema.oneOf!, isOneOf: true);
  }

  /// Handles anyOf — treat the same as oneOf for Dart code generation.
  FlorvalSchema _analyzeAnyOf(String name, v31.Schema schema) {
    return _analyzeComposite(name, schema, schema.anyOf!, isOneOf: false);
  }

  /// Common implementation for oneOf/anyOf analysis.
  FlorvalSchema _analyzeComposite(
    String name,
    v31.Schema schema,
    List<v31.Schema> subSchemas, {
    required bool isOneOf,
  }) {
    final variants = <FlorvalSchema>[];

    for (final subSchema in subSchemas) {
      final resolved = resolver.resolveSchema(subSchema);
      final subName = resolver.schemaName(subSchema);
      if (subName != null) {
        variants.add(FlorvalSchema(
          name: subName,
          fields: _extractFields(resolved, schemaName: subName),
          description: resolved.description,
        ));
      } else {
        // Inline schema — give it a generated name
        final variantName = '${name}Variant${variants.length}';
        variants.add(FlorvalSchema(
          name: variantName,
          fields: _extractFields(resolved, schemaName: variantName),
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
      oneOf: isOneOf ? variants : null,
      anyOf: isOneOf ? null : variants,
      discriminator: discriminator,
      description: schema.description,
    );
  }

  /// Converts a schema to a FlorvalType.
  ///
  /// [contextName] is used to generate names for inline union types
  /// (e.g. 'TaskOwner' for field 'owner' in schema 'Task').
  FlorvalType schemaToType(v31.Schema schema, {String? contextName}) {
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

    // Handle allOf with a single $ref (common pattern for nullable $ref)
    // e.g. allOf: [$ref User, {nullable: true}]
    if (schema.allOf != null && schema.allOf!.isNotEmpty) {
      final refSchema = schema.allOf!.firstWhere(
        (s) => s.ref != null,
        orElse: () => schema.allOf!.first,
      );
      if (refSchema.ref != null) {
        final name = resolver.schemaName(refSchema)!;
        // Check nullable on wrapper AND on allOf sub-items
        final isNullable = _isNullable(schema) ||
            schema.allOf!.any((s) => _isNullable(s));
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

    // Handle anyOf/oneOf — nullable $ref idiom or inline union types
    for (final compositeList in [schema.anyOf, schema.oneOf]) {
      if (compositeList != null && compositeList.isNotEmpty) {
        // Separate null and non-null elements
        final nonNullSchemas =
            compositeList.where((s) => !_isNullTypeSchema(s)).toList();
        final hasNullElement =
            compositeList.any((s) => _isNullTypeSchema(s));

        if (nonNullSchemas.length == 1 && nonNullSchemas.first.ref != null) {
          // Single $ref + optional null → nullable $ref
          final refSchema = nonNullSchemas.first;
          final name = resolver.schemaName(refSchema)!;
          final resolved = resolver.resolveSchema(refSchema);
          final isEnumType = _isEnumSchema(resolved);
          final isNullable = hasNullElement;
          return FlorvalType(
            name: name,
            dartType: isNullable ? '$name?' : name,
            isNullable: isNullable,
            ref: refSchema.ref,
            isEnum: isEnumType,
          );
        } else if (nonNullSchemas.length >= 2) {
          // True union type — generate inline union schema
          final unionName = contextName ??
              'InlineUnion${inlineUnionSchemas.length}';

          // Build a synthetic schema with only non-null elements for analysis
          final syntheticSchema = compositeList == schema.anyOf
              ? v31.Schema(anyOf: nonNullSchemas,
                  discriminator: schema.discriminator)
              : v31.Schema(oneOf: nonNullSchemas,
                  discriminator: schema.discriminator);

          final unionSchema = analyze(unionName, syntheticSchema);

          if (unionSchema.oneOf != null || unionSchema.anyOf != null) {
            inlineUnionSchemas.add(unionSchema);
            return FlorvalType(
              name: unionName,
              dartType: hasNullElement ? '$unionName?' : unionName,
              isNullable: hasNullElement,
              ref: '#/components/schemas/$unionName',
            );
          }
        }
        // nonNullSchemas.length == 1 but not a $ref, or == 0 → fall through
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
        return _objectType(schema, isNullable, contextName: contextName);
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
    final FlorvalType itemType;
    if (schema.items != null) {
      itemType = schemaToType(schema.items!);
    } else {
      logger?.warn('Array schema missing "items" — using List<dynamic>. '
          'This is likely an error in the OpenAPI spec.');
      itemType = const FlorvalType(name: 'dynamic', dartType: 'dynamic');
    }

    final dartType = 'List<${itemType.dartType}>';
    return FlorvalType(
      name: dartType,
      dartType: isNullable ? '$dartType?' : dartType,
      isNullable: isNullable,
      isList: true,
      itemType: itemType,
    );
  }

  FlorvalType _objectType(v31.Schema schema, bool isNullable,
      {String? contextName}) {
    // Object with no properties → check additionalProperties for typed Map
    if (schema.properties == null || schema.properties!.isEmpty) {
      final addProps = schema.additionalProperties;
      if (addProps != null && addProps is v31.Schema) {
        // additionalProperties is a Schema → Map<String, T>
        final valueType = schemaToType(addProps);
        final dartType = 'Map<String, ${valueType.dartType}>';
        return FlorvalType(
          name: dartType,
          dartType: isNullable ? '$dartType?' : dartType,
          isNullable: isNullable,
        );
      }
      // additionalProperties is true, false, or absent → Map<String, dynamic>
      const dartType = 'Map<String, dynamic>';
      return FlorvalType(
        name: dartType,
        dartType: isNullable ? '$dartType?' : dartType,
        isNullable: isNullable,
      );
    }

    // Object with properties + contextName → generate inline object class
    if (contextName != null) {
      final inlineSchema = analyze(contextName, schema);
      inlineObjectSchemas.add(inlineSchema);
      return FlorvalType(
        name: contextName,
        dartType: isNullable ? '$contextName?' : contextName,
        isNullable: isNullable,
        ref: '#/components/schemas/$contextName',
      );
    }

    // No contextName → safe fallback to Map
    const dartType = 'Map<String, dynamic>';
    return FlorvalType(
      name: dartType,
      dartType: isNullable ? '$dartType?' : dartType,
      isNullable: isNullable,
    );
  }

  /// Extracts the primary type string from a schema.
  ///
  /// Returns `'dynamic'` when type is unspecified (OpenAPI 3.1: "any type").
  String _extractType(v31.Schema schema) {
    final type = schema.type;
    if (type == null) return 'dynamic';
    if (type is String) return type;
    if (type is List) {
      // e.g. ["string", "null"] → "string"
      final types = type.cast<String>();
      return types.firstWhere((t) => t != 'null', orElse: () => 'dynamic');
    }
    return 'dynamic';
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

  /// Checks if a schema represents the null type ({type: "null"}).
  bool _isNullTypeSchema(v31.Schema schema) {
    final type = schema.type;
    if (type is String && type == 'null') return true;
    if (type is List && type.length == 1 && type.first == 'null') return true;
    return _isNullable(schema);
  }

  /// Gets the list of required field names from a schema.
  List<String> _requiredFields(v31.Schema schema) {
    return schema.$required ?? [];
  }
}
