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

  /// Original $ref path (e.g. '#/components/schemas/User').
  final String? ref;

  /// Whether this type is a Dart enum (generated from an OpenAPI enum schema).
  final bool isEnum;

  /// Whether this is a primitive Dart type (String, int, double, bool, DateTime).
  bool get isPrimitive =>
      !isList &&
      ref == null &&
      const {'String', 'int', 'double', 'bool', 'DateTime', 'dynamic'}
          .contains(dartType.replaceAll('?', ''));

  /// Whether this is a Map type.
  bool get isMap => dartType.startsWith('Map<');

  const FlorvalType({
    required this.name,
    required this.dartType,
    this.isNullable = false,
    this.isList = false,
    this.itemType,
    this.ref,
    this.isEnum = false,
  });

  /// Creates a nullable version of this type.
  FlorvalType asNullable() => FlorvalType(
        name: name,
        dartType: dartType.endsWith('?') ? dartType : '$dartType?',
        isNullable: true,
        isList: isList,
        itemType: itemType,
        ref: ref,
        isEnum: isEnum,
      );

  @override
  String toString() => 'FlorvalType($dartType)';
}
