import 'package:test/test.dart';
import 'package:florval/src/utils/doc_comment.dart';

void main() {
  group('writeDocComment', () {
    test('writes nothing when both description and example are null', () {
      final buffer = StringBuffer();
      writeDocComment(buffer);
      expect(buffer.toString(), isEmpty);
    });

    test('writes single-line description', () {
      final buffer = StringBuffer();
      writeDocComment(buffer, description: 'The user name');
      expect(buffer.toString(), '/// The user name\n');
    });

    test('writes multi-line description', () {
      final buffer = StringBuffer();
      writeDocComment(buffer, description: 'Line one\nLine two');
      expect(buffer.toString(), '/// Line one\n/// Line two\n');
    });

    test('writes description with indent', () {
      final buffer = StringBuffer();
      writeDocComment(buffer, description: 'A field', indent: '    ');
      expect(buffer.toString(), '    /// A field\n');
    });

    test('writes example for string value', () {
      final buffer = StringBuffer();
      writeDocComment(buffer, example: 'user@example.com');
      expect(buffer.toString(), '/// Example: "user@example.com"\n');
    });

    test('writes example for numeric value', () {
      final buffer = StringBuffer();
      writeDocComment(buffer, example: 42);
      expect(buffer.toString(), '/// Example: 42\n');
    });

    test('writes example for map value as JSON', () {
      final buffer = StringBuffer();
      writeDocComment(buffer, example: {'key': 'value'});
      expect(buffer.toString(), '/// Example: {"key":"value"}\n');
    });

    test('writes example for list value as JSON', () {
      final buffer = StringBuffer();
      writeDocComment(buffer, example: [1, 2, 3]);
      expect(buffer.toString(), '/// Example: [1,2,3]\n');
    });

    test('writes description and example with blank line separator', () {
      final buffer = StringBuffer();
      writeDocComment(
        buffer,
        description: 'The email address',
        example: 'user@example.com',
      );
      expect(
        buffer.toString(),
        '/// The email address\n///\n/// Example: "user@example.com"\n',
      );
    });

    test('writes description and example with indent', () {
      final buffer = StringBuffer();
      writeDocComment(
        buffer,
        description: 'User ID',
        example: 123,
        indent: '    ',
      );
      expect(
        buffer.toString(),
        '    /// User ID\n    ///\n    /// Example: 123\n',
      );
    });

    test('handles empty description string', () {
      final buffer = StringBuffer();
      writeDocComment(buffer, description: '');
      expect(buffer.toString(), isEmpty);
    });

    test('handles description with special characters', () {
      final buffer = StringBuffer();
      writeDocComment(buffer, description: 'Value <T> & stuff');
      expect(buffer.toString(), '/// Value <T> & stuff\n');
    });

    test('strips existing /// prefix from description', () {
      final buffer = StringBuffer();
      writeDocComment(buffer, description: '/// Already prefixed');
      expect(buffer.toString(), '/// Already prefixed\n');
    });

    test('handles multi-line description with empty lines', () {
      final buffer = StringBuffer();
      writeDocComment(buffer, description: 'First\n\nThird');
      expect(buffer.toString(), '/// First\n///\n/// Third\n');
    });

    test('writes boolean example', () {
      final buffer = StringBuffer();
      writeDocComment(buffer, example: true);
      expect(buffer.toString(), '/// Example: true\n');
    });
  });
}
