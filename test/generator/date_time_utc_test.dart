import 'package:test/test.dart';
import 'package:florval/src/generator/date_serializer_generator.dart';
import 'package:florval/src/generator/model_generator.dart';
import 'package:florval/src/model/api_schema.dart';
import 'package:florval/src/model/api_type.dart';

void main() {
  group('DateSerializerGenerator', () {
    final generator = DateSerializerGenerator();

    test('emits DateTimeUtcConverter that normalizes to UTC', () {
      final code = generator.generate();

      expect(
        code,
        contains(
            'class DateTimeUtcConverter implements JsonConverter<DateTime, String>'),
      );
      // Serialization must go through UTC so the server receives a `Z`-suffixed
      // instant rather than a timezone-less local wall-clock time.
      expect(
        code,
        contains(
            'String toJson(DateTime object) => object.toUtc().toIso8601String();'),
      );
      expect(code, contains('DateTime fromJson(String json) => DateTime.parse(json);'));
    });

    test('still emits DateOnlyConverter alongside the UTC converter', () {
      final code = generator.generate();
      expect(
        code,
        contains(
            'class DateOnlyConverter implements JsonConverter<DateTime, String>'),
      );
    });
  });

  group('ModelGenerator date-time UTC serialization', () {
    final generator = ModelGenerator();

    test('annotates non-absentable date-time field with @DateTimeUtcConverter',
        () {
      final schema = FlorvalSchema(
        name: 'CreateEventDto',
        fields: [
          FlorvalField(
            name: 'startAt',
            jsonKey: 'startAt',
            type: FlorvalType(
              name: 'DateTime',
              dartType: 'DateTime?',
              isNullable: true,
              format: 'date-time',
            ),
            isRequired: false,
          ),
        ],
      );

      final code = generator.generate(schema);

      expect(code, contains('@DateTimeUtcConverter()'));
      expect(code, isNot(contains('@DateOnlyConverter()')));
      expect(code, contains("import '../core/date_serializer.dart';"));
    });

    test('keeps @DateOnlyConverter for date fields (no UTC converter)', () {
      final schema = FlorvalSchema(
        name: 'CreateEventDto',
        fields: [
          FlorvalField(
            name: 'birthDate',
            jsonKey: 'birthDate',
            type: FlorvalType(
              name: 'DateTime',
              dartType: 'DateTime?',
              isNullable: true,
              format: 'date',
            ),
            isRequired: false,
          ),
        ],
      );

      final code = generator.generate(schema);

      expect(code, contains('@DateOnlyConverter()'));
      expect(code, isNot(contains('@DateTimeUtcConverter()')));
    });

    test('absentable date-time field serializes via toUtc().toIso8601String()',
        () {
      final schema = FlorvalSchema(
        name: 'UpdateEventDto',
        fields: [
          FlorvalField(
            name: 'startAt',
            jsonKey: 'start_at',
            type: FlorvalType(
              name: 'DateTime',
              dartType: 'DateTime',
              format: 'date-time',
            ),
            isRequired: false,
            absentable: true,
          ),
        ],
      );

      final code = generator.generate(schema);

      // Absentable models use a custom toJson and therefore must NOT rely on the
      // converter annotation; UTC normalization is inlined instead.
      expect(code, isNot(contains('@DateTimeUtcConverter()')));
      expect(code, contains('.toUtc().toIso8601String()'));
    });
  });
}
