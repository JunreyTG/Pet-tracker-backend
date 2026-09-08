class ApiConfig {
  static const defaultBaseUrl = 'http://localhost:8000';

  final String baseUrl;

  const ApiConfig({
    this.baseUrl = const String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: defaultBaseUrl,
    ),
  });
}
