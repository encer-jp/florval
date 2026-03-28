import 'package:test/test.dart';
import 'package:florval/src/generator/json_optional_generator.dart';

void main() {
  group('JsonOptionalGenerator', () {
    final generator = JsonOptionalGenerator();

    test('generates freezed sealed class with absent and value variants', () {
      final code = generator.generate();

      expect(
        code,
        contains(
            "import 'package:freezed_annotation/freezed_annotation.dart';"),
      );
      expect(code, contains("part 'json_optional.freezed.dart';"));
      expect(code, contains('@Freezed(genericArgumentFactories: true)'));
      expect(
        code,
        contains('sealed class JsonOptional<T> with _\$JsonOptional<T>'),
      );
      expect(
        code,
        contains(
            'const factory JsonOptional.absent() = JsonOptionalAbsent<T>;'),
      );
      expect(
        code,
        contains(
            'const factory JsonOptional.value(T? value) = JsonOptionalValue<T>;'),
      );
    });

    test('includes doc comments', () {
      final code = generator.generate();

      expect(code, contains('Sentinel type for PATCH/PUT partial updates.'));
      expect(code, contains('JsonOptional.absent()'));
      expect(code, contains('JsonOptional.value(null)'));
      expect(code, contains('JsonOptional.value(v)'));
    });
  });
}
