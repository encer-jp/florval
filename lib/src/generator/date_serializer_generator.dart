import '../config/template_config.dart';

/// Generates the `core/date_serializer.dart` runtime file.
///
/// Provides `DateOnlyConverter` — a `JsonConverter` that serializes
/// `DateTime` as `yyyy-MM-dd` for OpenAPI `format: date` fields.
class DateSerializerGenerator {
  final TemplateConfig? templateConfig;

  DateSerializerGenerator({this.templateConfig});

  /// Returns the Dart source for `core/date_serializer.dart`.
  String generate() {
    final buffer = StringBuffer();

    // Custom header
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
      buffer.writeln();
    }

    buffer.writeln(
        "import 'package:json_annotation/json_annotation.dart';");
    buffer.writeln();
    buffer.writeln('/// Serializes [DateTime] as `yyyy-MM-dd` for OpenAPI `format: date` fields.');
    buffer.writeln('class DateOnlyConverter implements JsonConverter<DateTime, String> {');
    buffer.writeln('  const DateOnlyConverter();');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  DateTime fromJson(String json) => DateTime.parse(json);');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  String toJson(DateTime object) =>');
    buffer.writeln(
        "      '\${object.year.toString().padLeft(4, '0')}-'");
    buffer.writeln(
        "      '\${object.month.toString().padLeft(2, '0')}-'");
    buffer.writeln(
        "      '\${object.day.toString().padLeft(2, '0')}';");
    buffer.writeln('}');

    return buffer.toString();
  }
}
