import 'package:openapi_spec_plus/v31.dart' as v31;
import 'package:recase/recase.dart';

import '../model/analysis_result.dart';
import '../model/api_schema.dart';
import '../model/api_type.dart';
import '../parser/ref_resolver.dart';
import '../utils/dart_identifier.dart';
import '../utils/logger.dart';

/// Converts OpenAPI schemas to florval intermediate representations.
class SchemaAnalyzer {
  final RefResolver resolver;
  final FlorvalLogger? logger;

  SchemaAnalyzer(this.resolver, {this.logger});

  /// Converts all component schemas to FlorvalSchemas.
  SchemaAnalysisResult analyzeAll(Map<String, v31.Schema> schemas) {
    final allSchemas = <FlorvalSchema>[];
    final allInlineUnions = <FlorvalSchema>[];
    final allInlineObjects = <FlorvalSchema>[];
    final allInlineEnums = <FlorvalSchema>[];

    for (final entry in schemas.entries) {
      final result = analyze(entry.key, entry.value);
      allSchemas.add(result.schema);
      allInlineUnions.addAll(result.inlineUnionSchemas);
      allInlineObjects.addAll(result.inlineObjectSchemas);
      allInlineEnums.addAll(result.inlineEnumSchemas);
    }

    return SchemaAnalysisResult(
      schemas: allSchemas,
      inlineUnionSchemas: allInlineUnions,
      inlineObjectSchemas: allInlineObjects,
      inlineEnumSchemas: allInlineEnums,
    );
  }

  /// Converts a single named schema to a FlorvalSchema.
  SchemaResult analyze(String name, v31.Schema schema) {
    final resolved = resolver.resolveSchema(schema);

    // Handle enum schemas (type: string/integer with enum values)
    if (_isEnumSchema(resolved)) {
      return SchemaResult(schema: _analyzeEnum(name, resolved));
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
    final fieldsResult = _extractFields(resolved, schemaName: name);

    return SchemaResult(
      schema: FlorvalSchema(
        name: name,
        fields: fieldsResult.fields,
        description: resolved.description,
        title: resolved.title,
        deprecated: resolved.$deprecated == true,
      ),
      inlineUnionSchemas: fieldsResult.inlineUnions,
      inlineObjectSchemas: fieldsResult.inlineObjects,
      inlineEnumSchemas: fieldsResult.inlineEnums,
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
      title: schema.title,
      deprecated: schema.$deprecated == true,
    );
  }

  /// Extracts fields from a schema's properties.
  ///
  /// [schemaName] is used to generate context names for inline union types.
  ({List<FlorvalField> fields, List<FlorvalSchema> inlineUnions, List<FlorvalSchema> inlineObjects, List<FlorvalSchema> inlineEnums}) _extractFields(v31.Schema schema, {String? schemaName}) {
    final requiredFields = _requiredFields(schema);
    final fields = <FlorvalField>[];
    final inlineUnions = <FlorvalSchema>[];
    final inlineObjects = <FlorvalSchema>[];
    final inlineEnums = <FlorvalSchema>[];
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
        final typeResult = schemaToType(fieldSchema, contextName: contextName);
        inlineUnions.addAll(typeResult.inlineUnionSchemas);
        inlineObjects.addAll(typeResult.inlineObjectSchemas);
        inlineEnums.addAll(typeResult.inlineEnumSchemas);

        final defaultValue = _convertDefaultValue(
          fieldSchema,
          typeResult.type,
          contextName: contextName,
        );

        fields.add(FlorvalField(
          name: fieldName,
          jsonKey: entry.key,
          type: isRequired ? typeResult.type : typeResult.type.asNullable(),
          isRequired: isRequired,
          defaultValue: defaultValue,
          deprecated: fieldSchema.$deprecated == true,
          readOnly: fieldSchema.readOnly == true,
          writeOnly: fieldSchema.writeOnly == true,
          description: fieldSchema.description,
          example: _extractExample(fieldSchema),
        ));
        index++;
      }
    }

    return (fields: fields, inlineUnions: inlineUnions, inlineObjects: inlineObjects, inlineEnums: inlineEnums);
  }

  /// Handles allOf — merges all sub-schema fields into one flat schema.
  SchemaResult _analyzeAllOf(String name, v31.Schema schema) {
    final mergedFields = <String, FlorvalField>{};
    final allInlineUnions = <FlorvalSchema>[];
    final allInlineObjects = <FlorvalSchema>[];
    final allInlineEnums = <FlorvalSchema>[];

    for (final subSchema in schema.allOf!) {
      final resolved = resolver.resolveSchema(subSchema);
      final fieldsResult = _extractFields(resolved, schemaName: name);
      allInlineUnions.addAll(fieldsResult.inlineUnions);
      allInlineObjects.addAll(fieldsResult.inlineObjects);
      allInlineEnums.addAll(fieldsResult.inlineEnums);
      for (final field in fieldsResult.fields) {
        mergedFields[field.jsonKey] = field;
      }
    }

    // Also merge fields from the schema itself (if any)
    final ownFieldsResult = _extractFields(schema, schemaName: name);
    allInlineUnions.addAll(ownFieldsResult.inlineUnions);
    allInlineObjects.addAll(ownFieldsResult.inlineObjects);
    allInlineEnums.addAll(ownFieldsResult.inlineEnums);
    for (final field in ownFieldsResult.fields) {
      mergedFields[field.jsonKey] = field;
    }

    return SchemaResult(
      schema: FlorvalSchema(
        name: name,
        fields: mergedFields.values.toList(),
        description: schema.description,
        title: schema.title,
        deprecated: schema.$deprecated == true,
      ),
      inlineUnionSchemas: allInlineUnions,
      inlineObjectSchemas: allInlineObjects,
      inlineEnumSchemas: allInlineEnums,
    );
  }

  /// Handles oneOf — creates variant schemas for sealed class generation.
  SchemaResult _analyzeOneOf(String name, v31.Schema schema) {
    return _analyzeComposite(name, schema, schema.oneOf!, isOneOf: true);
  }

  /// Handles anyOf — treat the same as oneOf for Dart code generation.
  SchemaResult _analyzeAnyOf(String name, v31.Schema schema) {
    return _analyzeComposite(name, schema, schema.anyOf!, isOneOf: false);
  }

  /// Common implementation for oneOf/anyOf analysis.
  SchemaResult _analyzeComposite(
    String name,
    v31.Schema schema,
    List<v31.Schema> subSchemas, {
    required bool isOneOf,
  }) {
    final variants = <FlorvalSchema>[];
    final allInlineUnions = <FlorvalSchema>[];
    final allInlineObjects = <FlorvalSchema>[];
    final allInlineEnums = <FlorvalSchema>[];

    for (final subSchema in subSchemas) {
      final resolved = resolver.resolveSchema(subSchema);
      final subName = resolver.schemaName(subSchema);
      if (subName != null) {
        final fieldsResult = _extractFields(resolved, schemaName: subName);
        allInlineUnions.addAll(fieldsResult.inlineUnions);
        allInlineObjects.addAll(fieldsResult.inlineObjects);
        allInlineEnums.addAll(fieldsResult.inlineEnums);
        variants.add(FlorvalSchema(
          name: subName,
          fields: fieldsResult.fields,
          description: resolved.description,
        ));
      } else {
        // Inline schema — give it a generated name
        final variantName = '${name}Variant${variants.length}';
        final fieldsResult = _extractFields(resolved, schemaName: variantName);
        allInlineUnions.addAll(fieldsResult.inlineUnions);
        allInlineObjects.addAll(fieldsResult.inlineObjects);
        allInlineEnums.addAll(fieldsResult.inlineEnums);
        variants.add(FlorvalSchema(
          name: variantName,
          fields: fieldsResult.fields,
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

    return SchemaResult(
      schema: FlorvalSchema(
        name: name,
        fields: [],
        oneOf: isOneOf ? variants : null,
        anyOf: isOneOf ? null : variants,
        discriminator: discriminator,
        description: schema.description,
        title: schema.title,
        deprecated: schema.$deprecated == true,
      ),
      inlineUnionSchemas: allInlineUnions,
      inlineObjectSchemas: allInlineObjects,
      inlineEnumSchemas: allInlineEnums,
    );
  }

  /// Converts a schema to a TypeResult containing the type and any inline schemas.
  ///
  /// [contextName] is used to generate names for inline union types
  /// (e.g. 'TaskOwner' for field 'owner' in schema 'Task').
  TypeResult schemaToType(v31.Schema schema, {String? contextName}) {
    // Handle $ref
    if (schema.ref != null) {
      final name = resolver.schemaName(schema)!;
      final resolved = resolver.resolveSchema(schema);
      final isEnumType = _isEnumSchema(resolved);
      return TypeResult(
        type: FlorvalType(
          name: name,
          dartType: name,
          ref: schema.ref,
          isEnum: isEnumType,
        ),
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
        return TypeResult(
          type: FlorvalType(
            name: name,
            dartType: isNullable ? '$name?' : name,
            isNullable: isNullable,
            ref: refSchema.ref,
            isEnum: isEnumType,
          ),
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
          return TypeResult(
            type: FlorvalType(
              name: name,
              dartType: isNullable ? '$name?' : name,
              isNullable: isNullable,
              ref: refSchema.ref,
              isEnum: isEnumType,
            ),
          );
        } else if (nonNullSchemas.length >= 2) {
          // True union type — generate inline union schema
          final unionName = contextName ?? 'InlineUnion';

          // Build a synthetic schema with only non-null elements for analysis
          final syntheticSchema = compositeList == schema.anyOf
              ? v31.Schema(anyOf: nonNullSchemas,
                  discriminator: schema.discriminator)
              : v31.Schema(oneOf: nonNullSchemas,
                  discriminator: schema.discriminator);

          final unionResult = analyze(unionName, syntheticSchema);

          if (unionResult.schema.oneOf != null || unionResult.schema.anyOf != null) {
            // Collect the union schema itself plus any inline schemas it discovered
            final inlineUnions = <FlorvalSchema>[
              unionResult.schema,
              ...unionResult.inlineUnionSchemas,
            ];
            return TypeResult(
              type: FlorvalType(
                name: unionName,
                dartType: hasNullElement ? '$unionName?' : unionName,
                isNullable: hasNullElement,
                ref: '#/components/schemas/$unionName',
              ),
              inlineUnionSchemas: inlineUnions,
              inlineObjectSchemas: unionResult.inlineObjectSchemas,
              inlineEnumSchemas: unionResult.inlineEnumSchemas,
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
        if (_isEnumSchema(schema) && contextName != null) {
          final enumSchema = _analyzeEnum(contextName, schema);
          return TypeResult(
            type: FlorvalType(
              name: contextName,
              dartType: isNullable ? '$contextName?' : contextName,
              isNullable: isNullable,
              isEnum: true,
              ref: '#/components/schemas/$contextName',
            ),
            inlineEnumSchemas: [enumSchema],
          );
        }
        return TypeResult(type: _stringType(schema, isNullable));
      case 'integer':
        if (_isEnumSchema(schema) && contextName != null) {
          final enumSchema = _analyzeEnum(contextName, schema);
          return TypeResult(
            type: FlorvalType(
              name: contextName,
              dartType: isNullable ? '$contextName?' : contextName,
              isNullable: isNullable,
              isEnum: true,
              ref: '#/components/schemas/$contextName',
            ),
            inlineEnumSchemas: [enumSchema],
          );
        }
        return TypeResult(type: _intType(schema, isNullable));
      case 'number':
        return TypeResult(type: _numberType(schema, isNullable));
      case 'boolean':
        return TypeResult(
          type: FlorvalType(
            name: 'bool',
            dartType: isNullable ? 'bool?' : 'bool',
            isNullable: isNullable,
          ),
        );
      case 'array':
        return _arrayType(schema, isNullable);
      case 'object':
        return _objectType(schema, isNullable, contextName: contextName);
      default:
        return TypeResult(
          type: FlorvalType(
            name: 'dynamic',
            dartType: 'dynamic',
          ),
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

  TypeResult _arrayType(v31.Schema schema, bool isNullable) {
    final TypeResult itemResult;
    if (schema.items != null) {
      itemResult = schemaToType(schema.items!);
    } else {
      logger?.warn('Array schema missing "items" — using List<dynamic>. '
          'This is likely an error in the OpenAPI spec.');
      itemResult = const TypeResult(
        type: FlorvalType(name: 'dynamic', dartType: 'dynamic'),
      );
    }

    final dartType = 'List<${itemResult.type.dartType}>';
    return TypeResult(
      type: FlorvalType(
        name: dartType,
        dartType: isNullable ? '$dartType?' : dartType,
        isNullable: isNullable,
        isList: true,
        itemType: itemResult.type,
      ),
      inlineUnionSchemas: itemResult.inlineUnionSchemas,
      inlineObjectSchemas: itemResult.inlineObjectSchemas,
      inlineEnumSchemas: itemResult.inlineEnumSchemas,
    );
  }

  TypeResult _objectType(v31.Schema schema, bool isNullable,
      {String? contextName}) {
    // Object with no properties → check additionalProperties for typed Map
    if (schema.properties == null || schema.properties!.isEmpty) {
      final addProps = schema.additionalProperties;
      if (addProps != null && addProps is v31.Schema) {
        // additionalProperties is a Schema → Map<String, T>
        final valueResult = schemaToType(addProps);
        final dartType = 'Map<String, ${valueResult.type.dartType}>';
        return TypeResult(
          type: FlorvalType(
            name: dartType,
            dartType: isNullable ? '$dartType?' : dartType,
            isNullable: isNullable,
          ),
          inlineUnionSchemas: valueResult.inlineUnionSchemas,
          inlineObjectSchemas: valueResult.inlineObjectSchemas,
          inlineEnumSchemas: valueResult.inlineEnumSchemas,
        );
      }
      // additionalProperties is true, false, or absent → Map<String, dynamic>
      const dartType = 'Map<String, dynamic>';
      return TypeResult(
        type: FlorvalType(
          name: dartType,
          dartType: isNullable ? '$dartType?' : dartType,
          isNullable: isNullable,
        ),
      );
    }

    // Object with properties + contextName → generate inline object class
    if (contextName != null) {
      final inlineResult = analyze(contextName, schema);
      return TypeResult(
        type: FlorvalType(
          name: contextName,
          dartType: isNullable ? '$contextName?' : contextName,
          isNullable: isNullable,
          ref: '#/components/schemas/$contextName',
        ),
        inlineUnionSchemas: inlineResult.inlineUnionSchemas,
        inlineObjectSchemas: [
          inlineResult.schema,
          ...inlineResult.inlineObjectSchemas,
        ],
        inlineEnumSchemas: inlineResult.inlineEnumSchemas,
      );
    }

    // No contextName → safe fallback to Map
    const dartType = 'Map<String, dynamic>';
    return TypeResult(
      type: FlorvalType(
        name: dartType,
        dartType: isNullable ? '$dartType?' : dartType,
        isNullable: isNullable,
      ),
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

  /// Converts an OpenAPI default value to a Dart literal string.
  ///
  /// Returns null if the default is not set or unsupported.
  String? _convertDefaultValue(
    v31.Schema schema,
    FlorvalType type, {
    String? contextName,
  }) {
    final defaultValue = schema.$default;
    if (defaultValue == null) return null;

    // For $ref schemas, resolve to get the actual type
    var schemaType = _extractType(schema);
    var resolvedSchema = schema;
    if (schemaType == 'dynamic' && schema.ref != null) {
      resolvedSchema = resolver.resolveSchema(schema);
      schemaType = _extractType(resolvedSchema);
    }

    // string + date-time → not supported (DateTime.parse is not const)
    final format = schema.format ?? resolvedSchema.format;
    if (schemaType == 'string' && (format == 'date-time' || format == 'date')) {
      logger?.warn(
          "Default value for date-time/date field is not supported (DateTime.parse is not const). "
          "Ignoring default: $defaultValue");
      return null;
    }

    // Enum type — convert to EnumName.dartMemberName
    if (type.isEnum && type.ref != null) {
      final enumName = type.ref!.split('/').last;
      final dartMember = _enumDefaultToDartName(defaultValue.toString());
      return '$enumName.$dartMember';
    }

    // string
    if (schemaType == 'string') {
      return "'${defaultValue.toString()}'";
    }

    // integer / number
    if (schemaType == 'integer' || schemaType == 'number') {
      return defaultValue.toString();
    }

    // boolean
    if (schemaType == 'boolean') {
      return defaultValue.toString();
    }

    // array — only empty arrays are supported
    if (schemaType == 'array') {
      if (defaultValue is List && defaultValue.isEmpty) {
        return 'const []';
      }
      logger?.warn(
          "Non-empty array default values are not supported. "
          "Ignoring default: $defaultValue");
      return null;
    }

    // object / $ref → not supported
    logger?.warn(
        "Default value for object/\$ref type is not supported. "
        "Ignoring default: $defaultValue");
    return null;
  }

  /// Converts an OpenAPI enum default value string to a camelCase Dart identifier.
  String _enumDefaultToDartName(String value) {
    if (value.isEmpty) return 'empty';
    final sanitized = sanitizeToCamelCase(value);
    if (sanitized == null) return 'value0';
    if (RegExp(r'^[0-9]').hasMatch(sanitized)) return 'value$sanitized';
    return sanitized;
  }

  /// Gets the list of required field names from a schema.
  List<String> _requiredFields(v31.Schema schema) {
    return schema.$required ?? [];
  }

  /// Extracts the example value from a schema.
  ///
  /// Prefers `example` (singular). Falls back to the first entry in `examples`
  /// if `example` is not set.
  Object? _extractExample(v31.Schema schema) {
    if (schema.example != null) return schema.example;
    if (schema.examples != null && schema.examples!.isNotEmpty) {
      return schema.examples!.first;
    }
    return null;
  }
}
