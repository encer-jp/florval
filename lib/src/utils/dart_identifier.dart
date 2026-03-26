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
  'state', // AsyncValue<T> state property
  'ref', // Ref object
  'future', // Future<T> getter on AsyncNotifier
  'build', // lifecycle method
  'update', // state update helper
  'updateShouldNotify', // notification control
};

/// Returns a safe parameter name for use in Riverpod provider build() methods.
///
/// If [dartName] conflicts with a Riverpod reserved name, appends 'Param'
/// suffix (e.g. `state` → `stateParam`). Otherwise returns [dartName] as-is.
String safeProviderParamName(String dartName) {
  if (riverpodReservedNames.contains(dartName)) {
    return '${dartName}Param';
  }
  return dartName;
}
