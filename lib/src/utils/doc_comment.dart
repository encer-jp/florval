import 'dart:convert';

/// Writes `///` doc comment lines to [buffer] for the given [description],
/// [example], and optional [indent].
///
/// Does nothing if both [description] and [example] are null/empty.
void writeDocComment(
  StringBuffer buffer, {
  String? description,
  Object? example,
  String indent = '',
}) {
  final hasDescription = description != null && description.isNotEmpty;
  final hasExample = example != null;

  if (!hasDescription && !hasExample) return;

  if (hasDescription) {
    final lines = description.split('\n');
    for (final line in lines) {
      final escaped = _escapeDocComment(line);
      if (escaped.isEmpty) {
        buffer.writeln('$indent///');
      } else {
        buffer.writeln('$indent/// $escaped');
      }
    }
  }

  if (hasExample) {
    if (hasDescription) {
      // Blank doc comment line between description and example
      buffer.writeln('$indent///');
    }
    final exampleStr = _formatExample(example);
    buffer.writeln('$indent/// Example: $exampleStr');
  }
}

/// Escapes characters that could break doc comments.
String _escapeDocComment(String text) {
  // Strip leading `/// ` if the source text already contains it
  var result = text;
  if (result.startsWith('///')) {
    result = result.substring(3).trimLeft();
  }
  return result;
}

/// Formats an example value for doc comment output.
String _formatExample(Object example) {
  if (example is String) return '"$example"';
  if (example is Map || example is List) return jsonEncode(example);
  return example.toString();
}
