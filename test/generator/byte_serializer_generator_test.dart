import 'package:florval/src/config/template_config.dart';
import 'package:florval/src/generator/byte_serializer_generator.dart';
import 'package:test/test.dart';

void main() {
  group('ByteSerializerGenerator', () {
    test('generates Base64Converter class', () {
      final generator = ByteSerializerGenerator();
      final code = generator.generate();

      expect(code, contains("import 'dart:convert';"));
      expect(code, contains('class Base64Converter'));
      expect(
        code,
        contains('implements JsonConverter<List<int>, String>'),
      );
      expect(code, contains('List<int> fromJson(String json) => base64Decode(json)'));
      expect(
        code,
        contains('String toJson(List<int> object) => base64Encode(object)'),
      );
    });

    test('uses template header when provided', () {
      final generator = ByteSerializerGenerator(
        templateConfig: TemplateConfig(header: '// CUSTOM HEADER'),
      );
      final code = generator.generate();

      expect(code, contains('// CUSTOM HEADER'));
    });
  });
}
