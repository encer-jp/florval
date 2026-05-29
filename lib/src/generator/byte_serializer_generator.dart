import '../config/template_config.dart';

/// Generates the `core/byte_serializer.dart` runtime file.
///
/// Provides `Base64Converter` — a `JsonConverter` that serializes byte data
/// as a base64 string for OpenAPI `format: byte` fields.
class ByteSerializerGenerator {
  final TemplateConfig? templateConfig;

  ByteSerializerGenerator({this.templateConfig});

  /// Returns the Dart source for `core/byte_serializer.dart`.
  String generate() {
    final buffer = StringBuffer();

    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
      buffer.writeln();
    }

    buffer.writeln("import 'dart:convert';");
    buffer.writeln();
    buffer.writeln("import 'package:json_annotation/json_annotation.dart';");
    buffer.writeln();
    buffer.writeln(
        '/// Serializes byte data as a base64 string for OpenAPI `format: byte` fields.');
    buffer.writeln(
        'class Base64Converter implements JsonConverter<List<int>, String> {');
    buffer.writeln('  const Base64Converter();');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  List<int> fromJson(String json) => base64Decode(json);');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  String toJson(List<int> object) => base64Encode(object);');
    buffer.writeln('}');

    return buffer.toString();
  }
}
