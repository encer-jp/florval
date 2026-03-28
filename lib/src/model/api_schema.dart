import 'api_type.dart';

/// Schema information for model generation.
class FlorvalSchema {
  /// Schema name (e.g. 'User', 'CreatePetRequest').
  final String name;

  /// Fields of this schema.
  final List<FlorvalField> fields;

  /// Discriminator for polymorphic types.
  final FlorvalDiscriminator? discriminator;

  /// oneOf schemas (exactly one must match).
  final List<FlorvalSchema>? oneOf;

  /// anyOf schemas (at least one must match).
  final List<FlorvalSchema>? anyOf;

  /// allOf schemas (all must match — used for inheritance/composition).
  final List<FlorvalSchema>? allOf;

  /// Description from the OpenAPI spec.
  final String? description;

  /// Title from the OpenAPI spec (used as doc comment fallback when description is absent).
  final String? title;

  /// Enum values for string/integer enum schemas.
  final List<String>? enumValues;

  /// Whether this schema is deprecated.
  final bool deprecated;

  /// Whether this schema represents a Dart enum.
  bool get isEnum => enumValues != null && enumValues!.isNotEmpty;

  const FlorvalSchema({
    required this.name,
    required this.fields,
    this.discriminator,
    this.oneOf,
    this.anyOf,
    this.allOf,
    this.description,
    this.title,
    this.enumValues,
    this.deprecated = false,
  });

  @override
  String toString() => 'FlorvalSchema($name, ${fields.length} fields)';
}

/// Field information within a schema.
class FlorvalField {
  /// Dart property name (camelCase).
  final String name;

  /// Original JSON key name.
  final String jsonKey;

  /// Type of this field.
  final FlorvalType type;

  /// Whether this field is required.
  final bool isRequired;

  /// Whether this field supports absent/null/value distinction (PATCH/PUT).
  ///
  /// When true, the generated code wraps this field in `JsonOptional<T>`
  /// so that "key not sent" and "key is null" are distinguishable.
  final bool absentable;

  /// Default value expression (Dart literal).
  final String? defaultValue;

  /// Whether this field is deprecated.
  final bool deprecated;

  /// Whether this field is read-only (excluded from toJson).
  final bool readOnly;

  /// Whether this field is write-only (excluded from fromJson).
  final bool writeOnly;

  /// Description from the OpenAPI spec.
  final String? description;

  /// Example value from the OpenAPI spec.
  final Object? example;

  const FlorvalField({
    required this.name,
    required this.jsonKey,
    required this.type,
    required this.isRequired,
    this.absentable = false,
    this.defaultValue,
    this.deprecated = false,
    this.readOnly = false,
    this.writeOnly = false,
    this.description,
    this.example,
  });

  @override
  String toString() => 'FlorvalField($name: ${type.dartType})';
}

/// Discriminator for polymorphic schemas.
class FlorvalDiscriminator {
  /// Property name used for discrimination.
  final String propertyName;

  /// Mapping from discriminator value to schema name.
  final Map<String, String>? mapping;

  const FlorvalDiscriminator({
    required this.propertyName,
    this.mapping,
  });
}
