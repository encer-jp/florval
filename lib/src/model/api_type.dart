/// Type information for a field or response body.
class FlorvalType {
  /// Display name (e.g. 'User', 'String').
  final String name;

  /// Dart type string for code generation.
  final String dartType;

  /// Whether this type is nullable.
  final bool isNullable;

  /// Whether this type is a List.
  final bool isList;

  /// Element type when [isList] is true.
  final FlorvalType? itemType;

  /// Value type when this is a Map.
  final FlorvalType? mapValueType;

  /// Original $ref path (e.g. '#/components/schemas/User').
  final String? ref;

  /// Whether this type is a Dart enum (generated from an OpenAPI enum schema).
  final bool isEnum;

  /// Original OpenAPI format (e.g. 'date', 'date-time').
  final String? format;

  /// Whether this is a primitive Dart type (String, int, double, bool, DateTime).
  bool get isPrimitive =>
      !isList &&
      !isMap &&
      ref == null &&
      const {'String', 'int', 'double', 'bool', 'DateTime', 'dynamic'}
          .contains(dartType.replaceAll('?', ''));

  /// Whether this is a Map type.
  bool get isMap => mapValueType != null || dartType.startsWith('Map<');

  const FlorvalType({
    required this.name,
    required this.dartType,
    this.isNullable = false,
    this.isList = false,
    this.itemType,
    this.mapValueType,
    this.ref,
    this.isEnum = false,
    this.format,
  });

  /// Creates a nullable version of this type.
  FlorvalType asNullable() => FlorvalType(
        name: name,
        dartType: dartType.endsWith('?') ? dartType : '$dartType?',
        isNullable: true,
        isList: isList,
        itemType: itemType,
        mapValueType: mapValueType,
        ref: ref,
        isEnum: isEnum,
        format: format,
      );

  @override
  String toString() => 'FlorvalType($dartType)';
}
