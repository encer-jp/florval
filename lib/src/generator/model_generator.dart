import 'package:recase/recase.dart';

import '../config/template_config.dart';
import '../model/api_schema.dart';
import '../model/api_type.dart';
import '../utils/dart_identifier.dart';
import '../utils/doc_comment.dart';
import '../utils/generated_header.dart';

/// Generates Dart model classes from FlorvalSchemas.
///
/// - Regular data classes → freezed 3.x (abstract class)
/// - Discriminator union types (oneOf/anyOf) → freezed 3.x sealed class (unionKey)
/// - Non-discriminator union types → plain Dart sealed class
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
    final hasAbsentable = schema.fields.any((f) => f.absentable);
    final buffer = StringBuffer();

    // Generated file header (lint suppression)
    buffer.writeln(generatedFileHeader);
    // Custom header
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
    }
    buffer.writeln();

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
    if (hasAbsentable) {
      imports.add('../core/json_optional');
    }
    for (final import_ in imports) {
      buffer.writeln("import '$import_.dart';");
    }
    if (imports.isNotEmpty) buffer.writeln();

    // Part directives
    buffer.writeln("part '$fileName.freezed.dart';");
    if (!hasAbsentable) {
      buffer.writeln("part '$fileName.g.dart';");
    }
    buffer.writeln();

    // Class definition
    writeDocComment(buffer, description: schema.description ?? schema.title);
    if (schema.deprecated) {
      buffer.writeln("@Deprecated('')");
    }
    if (hasAbsentable) {
      buffer.writeln('@Freezed(fromJson: false, toJson: false)');
    } else {
      buffer.writeln('@freezed');
    }
    buffer.writeln('abstract class ${schema.name} with _\$${schema.name} {');

    // Private constructor needed when adding methods to freezed class
    if (hasAbsentable) {
      buffer.writeln('  const ${schema.name}._();');
      buffer.writeln();
    }

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

    // fromJson / toJson
    if (hasAbsentable) {
      _writeCustomFromJson(buffer, schema);
      _writeCustomToJson(buffer, schema);
    } else {
      buffer.writeln(
          '  factory ${schema.name}.fromJson(Map<String, dynamic> json) => _\$${schema.name}FromJson(json);');
    }

    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates a Dart enum with @JsonValue annotations for JSON serialization.
  String _generateEnum(FlorvalSchema schema) {
    final buffer = StringBuffer();

    // Generated file header (lint suppression)
    buffer.writeln(generatedFileHeader);
    // Custom header
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
    }
    buffer.writeln();

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
    writeDocComment(buffer, description: schema.description ?? schema.title);
    if (schema.deprecated) {
      buffer.writeln("@Deprecated('')");
    }
    buffer.writeln('enum ${schema.name} {');

    // Collect dart names for later use in helper methods
    final usedNames = <String>{};
    final dartNames = <String>[];
    for (var i = 0; i < schema.enumValues!.length; i++) {
      final value = schema.enumValues![i];
      final dartName = _enumValueToDartName(value, i, usedNames);
      dartNames.add(dartName);
      final isLast = i == schema.enumValues!.length - 1;

      buffer.writeln("  @JsonValue('$value')");
      buffer.writeln('  $dartName${isLast ? ';' : ','}');
    }

    // jsonValue getter — returns the original JSON string for this member
    buffer.writeln();
    buffer.writeln('  String get jsonValue => switch (this) {');
    for (var i = 0; i < schema.enumValues!.length; i++) {
      buffer.writeln("    ${schema.name}.${dartNames[i]} => '${schema.enumValues![i]}',");
    }
    buffer.writeln('  };');

    // fromJsonValue static method — reverse lookup by JSON string
    buffer.writeln();
    buffer.writeln('  static ${schema.name} fromJsonValue(String value) =>');
    buffer.writeln('      values.firstWhere((e) => e.jsonValue == value);');

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

  /// Routes union type generation based on discriminator presence.
  String _generateSealedClass(FlorvalSchema schema) {
    if (schema.discriminator != null) {
      return _generateFreezedSealedClass(schema);
    }
    return _generatePlainSealedClass(schema);
  }

  /// Generates a freezed sealed class for discriminator-based union types.
  ///
  /// Uses `@Freezed(unionKey: ...)` and `@FreezedUnionValue(...)` so that
  /// freezed + json_serializable handle fromJson/toJson automatically,
  /// including the discriminator field.
  String _generateFreezedSealedClass(FlorvalSchema schema) {
    final disc = schema.discriminator!;
    final variants = schema.oneOf ?? schema.anyOf ?? [];
    final fileName = ReCase(schema.name).snakeCase;
    final buffer = StringBuffer();

    // Generated file header (lint suppression)
    buffer.writeln(generatedFileHeader);
    // Custom header
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
    }
    buffer.writeln();

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

    // Import referenced types from variant fields
    final imports = _collectUnionImports(schema);
    for (final import_ in imports) {
      buffer.writeln("import '$import_.dart';");
    }
    if (imports.isNotEmpty) buffer.writeln();

    // Part directives
    buffer.writeln("part '$fileName.freezed.dart';");
    buffer.writeln("part '$fileName.g.dart';");
    buffer.writeln();

    // Class definition with unionKey
    writeDocComment(buffer, description: schema.description ?? schema.title);
    buffer.writeln("@Freezed(unionKey: '${disc.propertyName}')");
    buffer.writeln(
        'sealed class ${schema.name} with _\$${schema.name} {');

    // Factory constructors for each variant with inlined fields
    for (final variant in variants) {
      // Determine discriminator value from mapping
      final discriminatorValue = disc.mapping?.entries
          .where((e) =>
              e.value == variant.name || e.value.endsWith('/${variant.name}'))
          .map((e) => e.key)
          .firstOrNull;
      final value = discriminatorValue ?? ReCase(variant.name).snakeCase;

      // Factory name from discriminator value (e.g., 'task_assigned' → 'taskAssigned')
      final factoryName = ReCase(value).camelCase;
      final subclassName = '${schema.name}${ReCase(value).pascalCase}';

      buffer.writeln("  @FreezedUnionValue('$value')");

      // Filter out the discriminator property from variant fields
      final fields = variant.fields
          .where((f) => f.jsonKey != disc.propertyName)
          .toList();

      if (fields.isEmpty) {
        buffer.writeln(
            '  const factory ${schema.name}.$factoryName() = $subclassName;');
      } else {
        buffer.writeln('  const factory ${schema.name}.$factoryName({');
        for (final field in fields) {
          _writeField(buffer, field);
        }
        buffer.writeln('  }) = $subclassName;');
      }
    }

    buffer.writeln();
    buffer.writeln(
        '  factory ${schema.name}.fromJson(Map<String, dynamic> json) => _\$${schema.name}FromJson(json);');
    buffer.writeln('}');

    return buffer.toString();
  }

  /// Generates a plain Dart sealed class for non-discriminator union types.
  ///
  /// No freezed dependency — without a discriminator, JSON serialization
  /// cannot be automated.
  String _generatePlainSealedClass(FlorvalSchema schema) {
    final variants = schema.oneOf ?? schema.anyOf ?? [];
    final buffer = StringBuffer();

    // Generated file header (lint suppression)
    buffer.writeln(generatedFileHeader);
    // Custom header
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
    }
    buffer.writeln();

    // Custom model imports
    if (templateConfig != null) {
      for (final import_ in templateConfig!.modelImports) {
        buffer.writeln(import_);
      }
    }

    // Import variant types
    final imports = <String>{};
    for (final variant in variants) {
      imports.add(ReCase(variant.name).snakeCase);
    }
    for (final import_ in imports) {
      buffer.writeln("import '$import_.dart';");
    }
    if (imports.isNotEmpty) buffer.writeln();

    // Sealed class definition
    writeDocComment(buffer, description: schema.description ?? schema.title);
    buffer.writeln('sealed class ${schema.name} {');
    buffer.writeln('  const ${schema.name}();');
    buffer.writeln();

    // Redirecting factory constructors for each variant
    for (final variant in variants) {
      final factoryName = ReCase(variant.name).camelCase;
      final subclassName = '${schema.name}${variant.name}';
      buffer.writeln(
          '  const factory ${schema.name}.$factoryName(${variant.name} data) = $subclassName;');
    }

    buffer.writeln();

    // fromJson: try each variant in order, return the first that succeeds
    buffer.writeln(
        '  factory ${schema.name}.fromJson(Map<String, dynamic> json) {');
    for (final variant in variants) {
      final factoryName = ReCase(variant.name).camelCase;
      buffer.writeln('    try {');
      buffer.writeln(
          '      return ${schema.name}.$factoryName(${variant.name}.fromJson(json));');
      buffer.writeln('    } catch (_) {}');
    }
    buffer.writeln('    throw FormatException(');
    buffer.writeln(
        "      'Could not deserialize ${schema.name} from JSON: none of the variants matched.',");
    buffer.writeln('    );');
    buffer.writeln('  }');

    buffer.writeln('}');
    buffer.writeln();

    // Subclasses with toJson
    for (final variant in variants) {
      final subclassName = '${schema.name}${variant.name}';
      buffer.writeln('class $subclassName extends ${schema.name} {');
      buffer.writeln('  final ${variant.name} data;');
      buffer.writeln('  const $subclassName(this.data);');
      buffer.writeln();
      buffer.writeln(
          '  Map<String, dynamic> toJson() => data.toJson();');
      buffer.writeln('}');
      buffer.writeln();
    }

    return buffer.toString();
  }

  bool _isUnionType(FlorvalSchema schema) {
    return (schema.oneOf != null && schema.oneOf!.isNotEmpty) ||
        (schema.anyOf != null && schema.anyOf!.isNotEmpty);
  }

  /// Returns the set of schema names that are inlined as variants
  /// in discriminator-based union types and should not be generated
  /// as standalone model files.
  ///
  /// For discriminator unions: collects both original variant names and
  /// generated subclass names (e.g., both `RoomInvitation` and
  /// `RequestDataRoomInvitation`).
  ///
  /// Only processes discriminator unions because their variant fields are
  /// inlined into the parent sealed class (the standalone file is redundant).
  /// Non-discriminator unions reference variant types externally, so their
  /// variant names must NOT be filtered.
  static Set<String> variantSchemaNames(List<FlorvalSchema> schemas) {
    final names = <String>{};
    for (final schema in schemas) {
      if (schema.discriminator == null) continue;
      final variants = schema.oneOf ?? schema.anyOf;
      if (variants == null || variants.isEmpty) continue;

      final disc = schema.discriminator!;
      for (final variant in variants) {
        names.add(variant.name);
        // Also add generated subclass name to prevent ambiguous exports
        // when the subclass name matches a component schema name.
        final subclassName = _computeSubclassName(schema.name, variant.name, disc);
        names.add(subclassName);
      }
    }
    return names;
  }

  /// Returns the set of subclass names that union types define inline.
  ///
  /// These names are exported from the parent union file (e.g.,
  /// `PostContentText` is defined inside `post_content.dart`). If a
  /// standalone model with the same name exists, exporting both from the
  /// barrel file would cause Dart's `ambiguous_export` error.
  ///
  /// Unlike [variantSchemaNames], this method:
  /// - Accepts ALL schemas (component + inline) as input
  /// - Only returns generated subclass names, NOT variant schema names
  /// - Covers both discriminator and non-discriminator unions
  static Set<String> unionSubclassNames(List<FlorvalSchema> schemas) {
    final names = <String>{};
    for (final schema in schemas) {
      final variants = schema.oneOf ?? schema.anyOf;
      if (variants == null || variants.isEmpty) continue;

      if (schema.discriminator != null) {
        final disc = schema.discriminator!;
        for (final variant in variants) {
          names.add(_computeSubclassName(schema.name, variant.name, disc));
        }
      } else {
        for (final variant in variants) {
          names.add('${schema.name}${variant.name}');
        }
      }
    }
    return names;
  }

  /// Computes the subclass name for a discriminator union variant.
  ///
  /// Mirrors the logic in [_generateFreezedSealedClass] to ensure
  /// the computed name matches the actually generated class name.
  static String _computeSubclassName(
    String parentName,
    String variantName,
    FlorvalDiscriminator disc,
  ) {
    final discriminatorValue = disc.mapping?.entries
        .where((e) =>
            e.value == variantName ||
            e.value.endsWith('/$variantName'))
        .map((e) => e.key)
        .firstOrNull;
    final value = discriminatorValue ?? ReCase(variantName).snakeCase;
    return '$parentName${ReCase(value).pascalCase}';
  }

  void _writeField(StringBuffer buffer, FlorvalField field) {
    // Add doc comment if description or example is present
    writeDocComment(
      buffer,
      description: field.description,
      example: field.example,
      indent: '    ',
    );

    // Add @Deprecated annotation if field is deprecated
    if (field.deprecated) {
      buffer.writeln("    @Deprecated('')");
    }

    // Build @JsonKey parameters list
    final jsonKeyParams = <String>[];
    if (field.name != field.jsonKey) {
      jsonKeyParams.add("name: '${field.jsonKey}'");
    }
    if (field.readOnly) {
      jsonKeyParams.add('includeToJson: false');
    }
    if (field.writeOnly) {
      jsonKeyParams.add('includeFromJson: false');
    }
    if (jsonKeyParams.isNotEmpty) {
      buffer.writeln('    @JsonKey(${jsonKeyParams.join(', ')})');
    }

    if (field.absentable) {
      // absentable takes priority over defaultValue
      final innerType = _absentableInnerType(field);
      buffer.writeln(
          '    @Default(JsonOptional<$innerType>.absent()) JsonOptional<$innerType> ${field.name},');
    } else if (field.defaultValue != null) {
      // defaultValue → @Default(...), no required prefix
      buffer.writeln(
          '    @Default(${field.defaultValue}) ${field.type.dartType} ${field.name},');
    } else {
      final prefix = field.isRequired ? 'required ' : '';
      buffer.writeln('    $prefix${field.type.dartType} ${field.name},');
    }
  }

  /// Extracts the inner (non-nullable) type name for wrapping in JsonOptional.
  String _absentableInnerType(FlorvalField field) {
    return field.type.dartType.replaceAll('?', '');
  }

  /// Generates a custom `fromJson` that uses `json.containsKey()` to distinguish
  /// absent keys from null values for absentable fields.
  void _writeCustomFromJson(StringBuffer buffer, FlorvalSchema schema) {
    buffer.writeln(
        '  factory ${schema.name}.fromJson(Map<String, dynamic> json) {');
    buffer.writeln('    return ${schema.name}(');
    for (final field in schema.fields) {
      // writeOnly fields are excluded from fromJson (use default value)
      if (field.writeOnly) {
        if (field.absentable) {
          // absentable writeOnly → leave as absent (the @Default handles it)
        } else {
          // non-absentable writeOnly → omit from constructor (uses default/nullable)
        }
        continue;
      }
      if (field.absentable) {
        final innerType = _absentableInnerType(field);
        final castExpr =
            _fromJsonCastExpression(field.type, "json['${field.jsonKey}']");
        buffer.writeln("      ${field.name}: json.containsKey('${field.jsonKey}')");
        buffer.writeln('          ? JsonOptional.value($castExpr)');
        buffer.writeln(
            '          : const JsonOptional<$innerType>.absent(),');
      } else {
        final castExpr =
            _fromJsonCastExpression(field.type, "json['${field.jsonKey}']");
        buffer.writeln('      ${field.name}: $castExpr,');
      }
    }
    buffer.writeln('    );');
    buffer.writeln('  }');
  }

  /// Returns a Dart expression that casts a JSON value to the target type.
  String _fromJsonCastExpression(FlorvalType type, String accessor) {
    final nullable = type.isNullable;
    final baseDartType = type.dartType.replaceAll('?', '');

    // DateTime
    if (baseDartType == 'DateTime') {
      if (nullable) {
        return '$accessor != null ? DateTime.parse($accessor as String) : null';
      }
      return 'DateTime.parse($accessor as String)';
    }

    // int (JSON numbers may be num)
    if (baseDartType == 'int') {
      if (nullable) {
        return '($accessor as num?)?.toInt()';
      }
      return '($accessor as num).toInt()';
    }

    // double
    if (baseDartType == 'double') {
      if (nullable) {
        return '($accessor as num?)?.toDouble()';
      }
      return '($accessor as num).toDouble()';
    }

    // List types
    if (type.isList && type.itemType != null) {
      final itemType = type.itemType!;
      final itemCast = _fromJsonListItemCast(itemType);
      if (nullable) {
        return '($accessor as List<dynamic>?)?.map((e) => $itemCast).toList()';
      }
      return '($accessor as List<dynamic>).map((e) => $itemCast).toList()';
    }

    // Reference types (model classes with fromJson)
    if (type.ref != null && !type.isEnum) {
      if (nullable) {
        return '$accessor != null ? $baseDartType.fromJson($accessor as Map<String, dynamic>) : null';
      }
      return '$baseDartType.fromJson($accessor as Map<String, dynamic>)';
    }

    // Enum types — use fromJsonValue for @JsonValue compatibility
    if (type.isEnum) {
      if (nullable) {
        return '$accessor != null ? $baseDartType.fromJsonValue($accessor as String) : null';
      }
      return '$baseDartType.fromJsonValue($accessor as String)';
    }

    // Primitives (String, bool, Map<String, dynamic>, dynamic)
    return '$accessor as ${type.dartType}';
  }

  /// Returns a cast expression for a single list item.
  String _fromJsonListItemCast(FlorvalType itemType) {
    if (itemType.ref != null && !itemType.isEnum) {
      return '${itemType.dartType}.fromJson(e as Map<String, dynamic>)';
    }
    if (itemType.isEnum) {
      return '${itemType.dartType}.fromJsonValue(e as String)';
    }
    if (itemType.dartType == 'int') {
      return '(e as num).toInt()';
    }
    if (itemType.dartType == 'double') {
      return '(e as num).toDouble()';
    }
    if (itemType.dartType == 'DateTime') {
      return 'DateTime.parse(e as String)';
    }
    return 'e as ${itemType.dartType}';
  }

  /// Generates a custom `toJson()` that excludes absent fields from the JSON map.
  void _writeCustomToJson(StringBuffer buffer, FlorvalSchema schema) {
    buffer.writeln();
    buffer.writeln('  Map<String, dynamic> toJson() {');
    buffer.writeln('    final json = <String, dynamic>{};');
    for (final field in schema.fields) {
      // readOnly fields are excluded from toJson
      if (field.readOnly) continue;
      if (field.absentable) {
        final innerType = _absentableInnerType(field);
        buffer.writeln(
            "    if (${field.name} is JsonOptionalValue<$innerType>) {");
        final valueExpr = '(${field.name} as JsonOptionalValue<$innerType>).value';
        final serialized = _toJsonValueExpression(field.type, valueExpr, nullable: true);
        buffer.writeln(
            "      json['${field.jsonKey}'] = $serialized;");
        buffer.writeln('    }');
      } else {
        _writeToJsonField(buffer, field);
      }
    }
    buffer.writeln('    return json;');
    buffer.writeln('  }');
  }

  /// Returns a Dart expression that converts a value to its JSON representation.
  String _toJsonValueExpression(FlorvalType type, String accessor, {bool nullable = false}) {
    final baseDartType = type.dartType.replaceAll('?', '');
    final q = nullable ? '?' : '';

    if (baseDartType == 'DateTime') {
      return '$accessor$q.toIso8601String()';
    }
    if (type.isEnum) {
      return '$accessor$q.jsonValue';
    }
    if (type.isList && type.itemType != null && !type.itemType!.isPrimitive && !type.itemType!.isMap) {
      if (type.itemType!.isEnum) {
        return '$accessor$q.map((e) => e.jsonValue).toList()';
      }
      return '$accessor$q.map((e) => e.toJson()).toList()';
    }
    if (type.ref != null && !type.isEnum && !type.isList) {
      return '$accessor$q.toJson()';
    }
    return accessor;
  }

  /// Writes a single required/regular field serialization in toJson.
  void _writeToJsonField(StringBuffer buffer, FlorvalField field) {
    final serialized = _toJsonValueExpression(field.type, field.name);
    buffer.writeln("    json['${field.jsonKey}'] = $serialized;");
  }

  /// Generates the `PaginatedData<T, P>` utility class.
  String generatePaginatedData() {
    final buffer = StringBuffer();

    // Generated file header (lint suppression)
    buffer.writeln(generatedFileHeader);
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
    }
    buffer.writeln();

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

    // Generated file header (lint suppression)
    buffer.writeln(generatedFileHeader);
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
    }
    buffer.writeln();

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

  /// Collects import paths for referenced types in a schema's fields.
  Set<String> _collectImports(FlorvalSchema schema) {
    final imports = <String>{};
    _addFieldImports(imports, schema.fields);
    return imports;
  }

  /// Collects import paths for referenced types across all variant fields
  /// in a discriminator union schema.
  Set<String> _collectUnionImports(FlorvalSchema schema) {
    final imports = <String>{};
    final variants = schema.oneOf ?? schema.anyOf ?? [];
    final discProperty = schema.discriminator?.propertyName;
    for (final variant in variants) {
      // Exclude the discriminator property field's type from imports
      final fields = discProperty != null
          ? variant.fields.where((f) => f.jsonKey != discProperty)
          : variant.fields;
      _addFieldImports(imports, fields);
    }
    return imports;
  }

  /// Adds import paths for referenced types in a list of fields.
  void _addFieldImports(Set<String> imports, Iterable<FlorvalField> fields) {
    for (final field in fields) {
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
  }
}
