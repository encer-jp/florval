import 'package:florval/src/config/template_config.dart';
import 'package:florval/src/generator/duration_serializer_generator.dart';
import 'package:test/test.dart';

void main() {
  group('DurationSerializerGenerator', () {
    test('generates DurationConverter class', () {
      final generator = DurationSerializerGenerator();
      final code = generator.generate();

      expect(code, contains('class DurationConverter'));
      expect(
        code,
        contains('implements JsonConverter<Duration, String>'),
      );
      expect(code, contains('Duration fromJson(String json)'));
      expect(code, contains('String toJson(Duration object)'));
      // ISO 8601 parsing helpers present.
      expect(code, contains('_parseIso8601Duration'));
      expect(code, contains('_formatIso8601Duration'));
      // Year/month components are rejected.
      expect(code, contains('FormatException'));
    });

    test('uses template header when provided', () {
      final generator = DurationSerializerGenerator(
        templateConfig: TemplateConfig(header: '// CUSTOM HEADER'),
      );
      final code = generator.generate();

      expect(code, contains('// CUSTOM HEADER'));
    });
  });
}
