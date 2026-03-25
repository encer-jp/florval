import 'api_type.dart';

/// Response information for a specific status code.
class FlorvalResponse {
  /// HTTP status code.
  final int statusCode;

  /// Description from the OpenAPI spec.
  final String? description;

  /// Response body type (null if no body).
  final FlorvalType? type;

  const FlorvalResponse({
    required this.statusCode,
    this.description,
    this.type,
  });

  /// Whether this response has a body.
  bool get hasBody => type != null;

  @override
  String toString() =>
      'FlorvalResponse($statusCode, ${type?.dartType ?? 'no body'})';
}
