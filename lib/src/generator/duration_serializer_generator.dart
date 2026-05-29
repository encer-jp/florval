import '../config/template_config.dart';

/// Generates the `core/duration_serializer.dart` runtime file.
///
/// Provides `DurationConverter` — a `JsonConverter` that converts between
/// Dart [Duration] and ISO 8601 duration strings for OpenAPI
/// `format: duration` fields. Year/month components (`PnYnM`) cannot be
/// represented as a fixed [Duration] and raise a [FormatException].
class DurationSerializerGenerator {
  final TemplateConfig? templateConfig;

  DurationSerializerGenerator({this.templateConfig});

  /// Returns the Dart source for `core/duration_serializer.dart`.
  String generate() {
    final buffer = StringBuffer();

    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
      buffer.writeln();
    }

    buffer.writeln("import 'package:json_annotation/json_annotation.dart';");
    buffer.writeln();
    buffer.write(r'''/// Serializes [Duration] as an ISO 8601 duration string for OpenAPI
/// `format: duration` fields.
///
/// Supports the week/day/hour/minute/second subset (`PnWnDTnHnMnS`).
/// Year and month components cannot be represented as a fixed [Duration]
/// and raise a [FormatException].
class DurationConverter implements JsonConverter<Duration, String> {
  const DurationConverter();

  @override
  Duration fromJson(String json) => _parseIso8601Duration(json);

  @override
  String toJson(Duration object) => _formatIso8601Duration(object);

  static Duration _parseIso8601Duration(String value) {
    final match = RegExp(
      r'^(-)?P(?:(\d+)W)?(?:(\d+)D)?'
      r'(?:T(?:(\d+)H)?(?:(\d+)M)?(?:(\d+(?:\.\d+)?)S)?)?$',
    ).firstMatch(value);
    if (match == null) {
      throw FormatException(
        'Invalid or unsupported ISO 8601 duration: $value',
      );
    }
    final groups = [for (var i = 2; i <= 6; i++) match.group(i)];
    if (groups.every((g) => g == null)) {
      throw FormatException(
        'Invalid or unsupported ISO 8601 duration: $value',
      );
    }
    final weeks = int.tryParse(match.group(2) ?? '0') ?? 0;
    final days = int.tryParse(match.group(3) ?? '0') ?? 0;
    final hours = int.tryParse(match.group(4) ?? '0') ?? 0;
    final minutes = int.tryParse(match.group(5) ?? '0') ?? 0;
    final secondsPart = double.tryParse(match.group(6) ?? '0') ?? 0;
    final wholeSeconds = secondsPart.truncate();
    final microseconds = ((secondsPart - wholeSeconds) * 1000000).round();
    final result = Duration(
      days: weeks * 7 + days,
      hours: hours,
      minutes: minutes,
      seconds: wholeSeconds,
      microseconds: microseconds,
    );
    return match.group(1) != null ? -result : result;
  }

  static String _formatIso8601Duration(Duration duration) {
    if (duration == Duration.zero) return 'PT0S';
    final negative = duration.isNegative;
    final d = duration.abs();
    final days = d.inDays;
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    final micros = d.inMicroseconds % 1000000;
    final sb = StringBuffer(negative ? '-P' : 'P');
    if (days > 0) sb.write('${days}D');
    if (hours > 0 || minutes > 0 || seconds > 0 || micros > 0) {
      sb.write('T');
      if (hours > 0) sb.write('${hours}H');
      if (minutes > 0) sb.write('${minutes}M');
      if (seconds > 0 || micros > 0) {
        if (micros > 0) {
          final frac =
              micros.toString().padLeft(6, '0').replaceAll(RegExp(r'0+$'), '');
          sb.write('$seconds.${frac}S');
        } else {
          sb.write('${seconds}S');
        }
      }
    }
    return sb.toString();
  }
}
''');

    return buffer.toString();
  }
}
