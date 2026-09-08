class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final Object? cause;

  const ApiException(this.message, {this.statusCode, this.cause});

  bool get isUnauthorized => statusCode == 401;

  @override
  String toString() {
    final code = statusCode == null ? '' : ' ($statusCode)';
    return 'ApiException$code: $message';
  }
}
