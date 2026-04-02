import '../config/template_config.dart';
import '../utils/generated_header.dart';

/// Generates the `core/json_optional.dart` runtime type file.
///
/// This file is emitted as a generated artifact alongside models,
/// providing `JsonOptional<T>` — a sentinel type that distinguishes
/// "key absent" from "key is null" in PATCH/PUT partial update bodies.
class JsonOptionalGenerator {
  final TemplateConfig? templateConfig;

  JsonOptionalGenerator({this.templateConfig});

  /// Returns the Dart source for `core/json_optional.dart`.
  String generate() {
    final buffer = StringBuffer();

    // Generated file header (lint suppression)
    buffer.writeln(generatedFileHeader);
    // Custom header
    if (templateConfig?.header != null) {
      buffer.writeln(templateConfig!.header);
    }
    buffer.writeln();

    buffer.writeln("import 'package:freezed_annotation/freezed_annotation.dart';");
    buffer.writeln();
    buffer.writeln("part 'json_optional.freezed.dart';");
    buffer.writeln();
    buffer.writeln('/// Sentinel type for PATCH/PUT partial updates.');
    buffer.writeln('///');
    buffer.writeln('/// Distinguishes three states:');
    buffer.writeln('/// - `JsonOptional.absent()` — key not sent (server keeps current value)');
    buffer.writeln('/// - `JsonOptional.value(null)` — key sent with null (server clears value)');
    buffer.writeln('/// - `JsonOptional.value(v)` — key sent with value (server updates)');
    buffer.writeln('@Freezed(genericArgumentFactories: true)');
    buffer.writeln('sealed class JsonOptional<T> with _\$JsonOptional<T> {');
    buffer.writeln('  const factory JsonOptional.absent() = JsonOptionalAbsent<T>;');
    buffer.writeln('  const factory JsonOptional.value(T? value) = JsonOptionalValue<T>;');
    buffer.writeln('}');

    return buffer.toString();
  }
}
