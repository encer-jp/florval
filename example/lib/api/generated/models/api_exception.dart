/// Exception wrapping a non-success API response.
class ApiException implements Exception {
  final dynamic response;
  const ApiException(this.response);

  @override
  String toString() => 'ApiException: $response';
}
