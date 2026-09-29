class AppConfig {
  static const apiPrefix = '/api/v1';
  static const defaultBaseUrl = String.fromEnvironment(
    'PET_TRACKER_API_URL',
    defaultValue: 'https://pet-tracker-backend-gamma.vercel.app',
  );

  // Web/desktop local dev: http://127.0.0.1:8000
  // Android emulator: http://10.0.2.2:8000
  // Physical phone: use --dart-define=PET_TRACKER_API_URL=http://<computer-lan-ip>:8000
  static String baseUrl = defaultBaseUrl;
  static Uri apiUri(String path, [Map<String, String?> query = const {}]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final filtered = <String, String>{};
    query.forEach((key, value) {
      if (value != null && value.isNotEmpty) filtered[key] = value;
    });
    return Uri.parse(
      '$baseUrl$apiPrefix$cleanPath',
    ).replace(queryParameters: filtered.isEmpty ? null : filtered);
  }
}
