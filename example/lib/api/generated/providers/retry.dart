// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint

/// Retry function for Riverpod GET providers (linear backoff).
Duration? retry(int retryCount, Object error) {
  if (retryCount >= 3) return null;
  return Duration(milliseconds: 1000 * (retryCount + 1));
}
