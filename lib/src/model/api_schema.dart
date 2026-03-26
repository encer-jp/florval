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

  /// Enum values for string/integer enum schemas.
  final List<String>? enumValues;

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
    this.enumValues,
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

  /// Default value expression (Dart literal).
  final String? defaultValue;

  /// Description from the OpenAPI spec.
  final String? description;

  const FlorvalField({
    required this.name,
    required this.jsonKey,
    required this.type,
    required this.isRequired,
    this.defaultValue,
    this.description,
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
