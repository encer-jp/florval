import 'package:florval/src/config/template_config.dart';
import 'package:florval/src/generator/time_serializer_generator.dart';
import 'package:test/test.dart';

void main() {
  group('TimeSerializerGenerator', () {
    test('generates LocalTime value type and converter', () {
      final generator = TimeSerializerGenerator();
      final code = generator.generate();

      expect(code, contains('class LocalTime'));
      expect(code, contains('factory LocalTime.parse(String value)'));
      expect(code, contains('class LocalTimeConverter'));
      expect(
        code,
        contains('implements JsonConverter<LocalTime, String>'),
      );
      expect(code, contains('LocalTime fromJson(String json)'));
      expect(code, contains('String toJson(LocalTime object)'));
      // No Flutter dependency.
      expect(code, isNot(contains('package:flutter')));
    });

    test('uses template header when provided', () {
      final generator = TimeSerializerGenerator(
        templateConfig: TemplateConfig(header: '// CUSTOM HEADER'),
      );
      final code = generator.generate();

      expect(code, contains('// CUSTOM HEADER'));
    });
  });
}
