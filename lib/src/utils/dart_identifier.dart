import 'package:recase/recase.dart';

/// Sanitizes [raw] into a valid camelCase Dart identifier.
///
/// Strips all non-ASCII characters and converts the remainder to camelCase.
/// Returns `null` if no ASCII content can be extracted, signaling
/// the caller should use a positional fallback name.
String? sanitizeToCamelCase(String raw) {
  if (raw.isEmpty) return null;

  // Keep only ASCII letters, digits, underscores, hyphens, spaces
  // (ReCase uses separators like _ - and spaces to split words)
  final asciiOnly = raw.replaceAll(RegExp(r'[^\x00-\x7F]'), '');
  final trimmed = asciiOnly.trim();

  if (trimmed.isEmpty) return null;

  final camel = ReCase(trimmed).camelCase;
  return camel.isEmpty ? null : camel;
}
