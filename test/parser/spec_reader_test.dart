import 'package:test/test.dart';
import 'package:florval/src/parser/spec_reader.dart';

void main() {
  group('SpecReader', () {
    final reader = SpecReader();

    test('reads petstore.yaml fixture', () {
      final spec = reader.readFile('test/fixtures/petstore.yaml');

      expect(spec.info.title, 'Petstore');
      expect(spec.info.version, '1.0.0');
      expect(spec.paths, isNotEmpty);
      expect(spec.components?.schemas, isNotEmpty);
    });

    test('parses paths correctly', () {
      final spec = reader.readFile('test/fixtures/petstore.yaml');

      expect(spec.paths.containsKey('/pets'), isTrue);
      expect(spec.paths.containsKey('/pets/{petId}'), isTrue);
      expect(spec.paths['/pets']?.get, isNotNull);
      expect(spec.paths['/pets']?.post, isNotNull);
      expect(spec.paths['/pets/{petId}']?.get, isNotNull);
      expect(spec.paths['/pets/{petId}']?.put, isNotNull);
      expect(spec.paths['/pets/{petId}']?.delete, isNotNull);
    });

    test('parses schemas correctly', () {
      final spec = reader.readFile('test/fixtures/petstore.yaml');
      final schemas = spec.components!.schemas!;

      expect(schemas.containsKey('Pet'), isTrue);
      expect(schemas.containsKey('Category'), isTrue);
      expect(schemas.containsKey('Error'), isTrue);

      final pet = schemas['Pet']!;
      expect(pet.properties, isNotNull);
      expect(pet.properties!.containsKey('id'), isTrue);
      expect(pet.properties!.containsKey('name'), isTrue);
    });

    test('parses operation responses', () {
      final spec = reader.readFile('test/fixtures/petstore.yaml');
      final listPets = spec.paths['/pets']!.get!;

      expect(listPets.operationId, 'listPets');
      expect(listPets.responses.containsKey('200'), isTrue);
      expect(listPets.responses.containsKey('400'), isTrue);
      expect(listPets.responses.containsKey('500'), isTrue);
    });

    test('throws on nonexistent file', () {
      expect(
        () => reader.readFile('nonexistent.yaml'),
        throwsA(isA<SpecReaderException>()),
      );
    });
  });
}
