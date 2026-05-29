import '../config/template_config.dart';

/// Generates the `core/time_serializer.dart` runtime file.
///
/// Provides `LocalTime` — a Flutter-independent value type for a time of day
/// without a date — and `LocalTimeConverter` for OpenAPI `format: time`
/// (RFC 3339 full-time / partial-time) fields.
class TimeSerializerGenerator {
  final TemplateConfig? templateConfig;

  TimeSerializerGenerator({this.templateConfig});

  /// Returns the Dart source for `core/time_serializer.dart`.
  String generate() {
    final buffer = StringBuffer();

    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
      buffer.writeln();
    }

    buffer.writeln("import 'package:json_annotation/json_annotation.dart';");
    buffer.writeln();
    buffer.write(r'''/// A time of day (hour, minute, second, fractional second) without a date,
/// for OpenAPI `format: time` (RFC 3339 full-time / partial-time).
class LocalTime {
  final int hour;
  final int minute;
  final int second;

  /// Fractional seconds expressed in microseconds (0-999999).
  final int microsecond;

  const LocalTime(
    this.hour,
    this.minute, [
    this.second = 0,
    this.microsecond = 0,
  ]);

  /// Parses `HH:mm`, `HH:mm:ss`, or `HH:mm:ss.SSSSSS`. A trailing timezone
  /// designator (`Z` or `+/-HH:mm`) is accepted and ignored.
  factory LocalTime.parse(String value) {
    final match = RegExp(
      r'^(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d+))?)?(?:Z|[+-]\d{2}:?\d{2})?$',
    ).firstMatch(value);
    if (match == null) {
      throw FormatException('Invalid time: $value');
    }
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    final second = match.group(3) != null ? int.parse(match.group(3)!) : 0;
    var microsecond = 0;
    final frac = match.group(4);
    if (frac != null) {
      final padded = frac.padRight(6, '0').substring(0, 6);
      microsecond = int.parse(padded);
    }
    return LocalTime(hour, minute, second, microsecond);
  }

  @override
  String toString() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    final s = second.toString().padLeft(2, '0');
    if (microsecond == 0) return '$h:$m:$s';
    final frac =
        microsecond.toString().padLeft(6, '0').replaceAll(RegExp(r'0+$'), '');
    return '$h:$m:$s.$frac';
  }

  @override
  bool operator ==(Object other) =>
      other is LocalTime &&
      other.hour == hour &&
      other.minute == minute &&
      other.second == second &&
      other.microsecond == microsecond;

  @override
  int get hashCode => Object.hash(hour, minute, second, microsecond);
}

/// Serializes [LocalTime] as a string for OpenAPI `format: time` fields.
class LocalTimeConverter implements JsonConverter<LocalTime, String> {
  const LocalTimeConverter();

  @override
  LocalTime fromJson(String json) => LocalTime.parse(json);

  @override
  String toJson(LocalTime object) => object.toString();
}
''');

    return buffer.toString();
  }
}
