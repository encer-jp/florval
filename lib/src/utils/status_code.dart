/// Maps HTTP status codes to factory constructor names for response Union types.
String statusCodeToFactoryName(int code) {
  return switch (code) {
    200 => 'success',
    201 => 'created',
    204 => 'noContent',
    400 => 'badRequest',
    401 => 'unauthorized',
    403 => 'forbidden',
    404 => 'notFound',
    409 => 'conflict',
    422 => 'unprocessableEntity',
    429 => 'tooManyRequests',
    500 => 'serverError',
    502 => 'badGateway',
    503 => 'serviceUnavailable',
    0 => 'defaultResponse',
    _ => 'status$code',
  };
}
