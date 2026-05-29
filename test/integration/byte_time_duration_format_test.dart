import 'package:florval/src/analyzer/schema_analyzer.dart';
import 'package:florval/src/generator/model_generator.dart';
import 'package:florval/src/model/api_schema.dart';
import 'package:florval/src/model/api_type.dart';
import 'package:florval/src/parser/ref_resolver.dart';
import 'package:florval/src/parser/spec_reader.dart';
import 'package:test/test.dart';

void main() {
  group('byte/time/duration format integration', () {
    FlorvalSchema analyzeSchema(String yaml, String name) {
      final spec = SpecReader().parse(yaml);
      final analyzer = SchemaAnalyzer(RefResolver(spec));
      return analyzer.analyze(name, spec.components!.schemas![name]!).schema;
    }

    group('analyzer type mapping', () {
      const yaml = '''
openapi: "3.1.0"
info:
  title: Test
  version: 1.0.0
paths: {}
components:
  schemas:
    Sample:
      type: object
      properties:
        avatar:
          type: string
          format: byte
        startTime:
          type: string
          format: time
        ttl:
          type: string
          format: duration
      required:
        - avatar
        - startTime
        - ttl
''';

      test('maps byte to List<int>, time to LocalTime, duration to Duration',
          () {
        final schema = analyzeSchema(yaml, 'Sample');
        final byField = {for (final f in schema.fields) f.name: f};

        expect(byField['avatar']!.type.dartType, 'List<int>');
        expect(byField['avatar']!.type.format, 'byte');
        expect(byField['startTime']!.type.dartType, 'LocalTime');
        expect(byField['startTime']!.type.format, 'time');
        expect(byField['ttl']!.type.dartType, 'Duration');
        expect(byField['ttl']!.type.format, 'duration');
      });
    });

    group('non-absentable model (json_serializable + annotations)', () {
      const yaml = '''
openapi: "3.1.0"
info:
  title: Test
  version: 1.0.0
paths: {}
components:
  schemas:
    Sample:
      type: object
      properties:
        avatar:
          type: string
          format: byte
        startTime:
          type: string
          format: time
        ttl:
          type: string
          format: duration
      required:
        - avatar
        - startTime
        - ttl
''';

      test('adds converter annotations', () {
        final model = ModelGenerator().generate(analyzeSchema(yaml, 'Sample'));
        expect(model, contains('@Base64Converter()'));
        expect(model, contains('@LocalTimeConverter()'));
        expect(model, contains('@DurationConverter()'));
      });

      test('adds core imports', () {
        final model = ModelGenerator().generate(analyzeSchema(yaml, 'Sample'));
        expect(model, contains("import '../core/byte_serializer.dart';"));
        expect(model, contains("import '../core/time_serializer.dart';"));
        expect(model, contains("import '../core/duration_serializer.dart';"));
      });

      test('uses correct Dart field types', () {
        final model = ModelGenerator().generate(analyzeSchema(yaml, 'Sample'));
        expect(model, contains('List<int> avatar'));
        expect(model, contains('LocalTime startTime'));
        expect(model, contains('Duration ttl'));
      });
    });

    group('absentable model (custom from/toJson)', () {
      FlorvalSchema absentableSchema() => FlorvalSchema(
            name: 'UpdateSample',
            fields: [
              FlorvalField(
                name: 'avatar',
                jsonKey: 'avatar',
                type: const FlorvalType(
                  name: 'List<int>',
                  dartType: 'List<int>?',
                  isNullable: true,
                  format: 'byte',
                ),
                isRequired: false,
                absentable: true,
              ),
              FlorvalField(
                name: 'startTime',
                jsonKey: 'start_time',
                type: const FlorvalType(
                  name: 'LocalTime',
                  dartType: 'LocalTime?',
                  isNullable: true,
                  format: 'time',
                ),
                isRequired: false,
                absentable: true,
              ),
              FlorvalField(
                name: 'ttl',
                jsonKey: 'ttl',
                type: const FlorvalType(
                  name: 'Duration',
                  dartType: 'Duration?',
                  isNullable: true,
                  format: 'duration',
                ),
                isRequired: false,
                absentable: true,
              ),
            ],
          );

      test('imports converters even for absentable fields', () {
        final model = ModelGenerator().generate(absentableSchema());
        expect(model, contains("import '../core/byte_serializer.dart';"));
        expect(model, contains("import '../core/time_serializer.dart';"));
        expect(model, contains("import '../core/duration_serializer.dart';"));
      });

      test('does not annotate absentable fields', () {
        final model = ModelGenerator().generate(absentableSchema());
        // Annotations are only for the json_serializable (non-absentable) path.
        expect(model, isNot(contains('@Base64Converter()')));
        expect(model, isNot(contains('@LocalTimeConverter()')));
        expect(model, isNot(contains('@DurationConverter()')));
      });

      test('custom fromJson uses converters via containsKey guard', () {
        final model = ModelGenerator().generate(absentableSchema());
        expect(
          model,
          contains('const Base64Converter().fromJson('),
        );
        expect(
          model,
          contains('const LocalTimeConverter().fromJson('),
        );
        expect(
          model,
          contains('const DurationConverter().fromJson('),
        );
      });

      test('custom toJson uses converters', () {
        final model = ModelGenerator().generate(absentableSchema());
        expect(model, contains('const Base64Converter().toJson('));
        expect(model, contains('const LocalTimeConverter().toJson('));
        expect(model, contains('const DurationConverter().toJson('));
      });
    });
  });
}
