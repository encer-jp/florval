import 'api_response.dart';
import 'api_type.dart';

/// Endpoint information extracted from an OpenAPI path + operation.
class FlorvalEndpoint {
  /// URL path (e.g. '/users/{id}').
  final String path;

  /// HTTP method in uppercase (e.g. 'GET', 'POST').
  final String method;

  /// Operation ID (e.g. 'getUser').
  final String operationId;

  /// Parameters (path, query, header).
  final List<FlorvalParam> parameters;

  /// Request body (for POST/PUT/PATCH).
  final FlorvalRequestBody? requestBody;

  /// Responses keyed by status code.
  final Map<int, FlorvalResponse> responses;

  /// Tags for grouping endpoints.
  final List<String> tags;

  /// Summary from the OpenAPI spec.
  final String? summary;

  const FlorvalEndpoint({
    required this.path,
    required this.method,
    required this.operationId,
    required this.parameters,
    this.requestBody,
    required this.responses,
    required this.tags,
    this.summary,
  });

  /// The primary tag for grouping (first tag, or 'default').
  String get primaryTag => tags.isNotEmpty ? tags.first : 'default';

  /// Path parameters only.
  List<FlorvalParam> get pathParameters =>
      parameters.where((p) => p.location == ParamLocation.path).toList();

  /// Query parameters only.
  List<FlorvalParam> get queryParameters =>
      parameters.where((p) => p.location == ParamLocation.query).toList();

  @override
  String toString() => 'FlorvalEndpoint($method $path)';
}

/// Parameter information.
class FlorvalParam {
  /// Parameter name.
  final String name;

  /// Dart-safe parameter name (camelCase).
  final String dartName;

  /// Parameter location.
  final ParamLocation location;

  /// Parameter type.
  final FlorvalType type;

  /// Whether this parameter is required.
  final bool isRequired;

  /// Description from the OpenAPI spec.
  final String? description;

  const FlorvalParam({
    required this.name,
    required this.dartName,
    required this.location,
    required this.type,
    required this.isRequired,
    this.description,
  });

  @override
  String toString() => 'FlorvalParam($name: ${type.dartType})';
}

/// Parameter location.
enum ParamLocation {
  path,
  query,
  header,
  cookie,
}

/// Request body information.
class FlorvalRequestBody {
  /// Body type.
  final FlorvalType type;

  /// Whether the body is required.
  final bool isRequired;

  /// Description from the OpenAPI spec.
  final String? description;

  const FlorvalRequestBody({
    required this.type,
    required this.isRequired,
    this.description,
  });

  @override
  String toString() => 'FlorvalRequestBody(${type.dartType})';
}
