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

/// Names reserved by Riverpod's AsyncNotifier/Notifier that cannot be used
/// as build() parameter names in generated @riverpod classes.
///
/// These are properties and methods inherited from the base Notifier classes
/// that would cause getter/setter type conflicts if shadowed.
const riverpodReservedNames = {
  // Notifier / AsyncNotifier instance members
  'state', // AsyncValue<T> / T state property
  'ref', // Ref object
  'future', // Future<T> getter on AsyncNotifier
  'build', // lifecycle method
  'update', // state update helper on AsyncNotifier
  'updateShouldNotify', // notification control
  'stateOrNull', // Notifier property (null if uninitialized)
  'listenSelf', // self-listen method
  'runBuild', // internal build trigger
  // Generated provider constructor super parameters
  'name', // provider debug name (super.name)
  'from', // family instance reference (super.from)
  'dependencies', // provider dependencies (super.dependencies)
  'allTransitiveDependencies', // transitive deps
  'debugGetCreateSourceHash', // hot-reload hash
};

/// Returns a safe parameter name for use in Riverpod provider build() methods.
///
/// If [dartName] conflicts with a Riverpod reserved name or a Dart reserved
/// word, appends 'Param' suffix (e.g. `state` → `stateParam`,
/// `in` → `inParam`). Otherwise returns [dartName] as-is.
String safeProviderParamName(String dartName) {
  if (riverpodReservedNames.contains(dartName) ||
      dartReservedWords.contains(dartName)) {
    return '${dartName}Param';
  }
  return dartName;
}

/// Sanitizes a raw parameter name into a valid Dart identifier (camelCase).
///
/// Handles non-ASCII characters, Dart reserved words, and names that start
/// with a digit. Returns a positional fallback (`param0`, `param1`, etc.)
/// when the name cannot be meaningfully converted.
String sanitizeParamName(String raw, {int index = 0}) {
  final sanitized = sanitizeToCamelCase(raw);
  if (sanitized == null || sanitized.isEmpty) {
    // Entirely non-ASCII or empty: use index-based fallback
    return 'param$index';
  }
  if (RegExp(r'^[0-9]').hasMatch(sanitized)) {
    // Starts with a digit: prefix with 'param'
    return 'param$sanitized';
  }
  if (dartReservedWords.contains(sanitized)) {
    // Dart reserved word: append underscore suffix
    return '${sanitized}_';
  }
  return sanitized;
}

/// Dart language reserved words that cannot be used as identifiers.
const dartReservedWords = {
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue',
  'default', 'do', 'else', 'enum', 'extends', 'false', 'final',
  'finally', 'for', 'if', 'in', 'is', 'new', 'null', 'rethrow',
  'return', 'super', 'switch', 'this', 'throw', 'true', 'try',
  'var', 'void', 'while', 'with', 'yield',
};
