import '../config/template_config.dart';

/// Generates the `core/date_serializer.dart` runtime file.
///
/// Provides two `JsonConverter`s for OpenAPI date/time fields:
/// - `DateOnlyConverter` — serializes `DateTime` as `yyyy-MM-dd`
///   for `format: date` fields.
/// - `DateTimeUtcConverter` — serializes `DateTime` as a UTC ISO 8601
///   string (with a `Z` suffix) for `format: date-time` fields. This
///   normalizes the wall-clock time to UTC so the server receives an
///   unambiguous instant instead of a timezone-less local timestamp.
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
    buffer.writeln();
    buffer.writeln('/// Serializes [DateTime] as a UTC ISO 8601 string (with a `Z` suffix)');
    buffer.writeln('/// for OpenAPI `format: date-time` fields.');
    buffer.writeln('///');
    buffer.writeln('/// Normalizes the value to UTC on the way out so the server receives an');
    buffer.writeln('/// unambiguous instant rather than a timezone-less local wall-clock time.');
    buffer.writeln('class DateTimeUtcConverter implements JsonConverter<DateTime, String> {');
    buffer.writeln('  const DateTimeUtcConverter();');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  DateTime fromJson(String json) => DateTime.parse(json);');
    buffer.writeln();
    buffer.writeln('  @override');
    buffer.writeln('  String toJson(DateTime object) => object.toUtc().toIso8601String();');
    buffer.writeln('}');

    return buffer.toString();
  }
}
