// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

import 'package:freezed_annotation/freezed_annotation.dart';

part 'json_optional.freezed.dart';

/// Sentinel type for PATCH/PUT partial updates.
///
/// Distinguishes three states:
/// - `JsonOptional.absent()` — key not sent (server keeps current value)
/// - `JsonOptional.value(null)` — key sent with null (server clears value)
/// - `JsonOptional.value(v)` — key sent with value (server updates)
@Freezed(genericArgumentFactories: true)
sealed class JsonOptional<T> with _$JsonOptional<T> {
  const factory JsonOptional.absent() = JsonOptionalAbsent<T>;
  const factory JsonOptional.value(T? value) = JsonOptionalValue<T>;
}
