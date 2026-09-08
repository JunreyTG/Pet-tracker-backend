import 'api_client.dart';

class HealthStatus {
  final String status;
  final String message;

  const HealthStatus({required this.status, required this.message});

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    return HealthStatus(
      status: json['status'] as String? ?? 'unknown',
      message: json['message'] as String? ?? '',
    );
  }
}

class HealthApi {
  final ApiClient _client;

  const HealthApi(this._client);

  Future<HealthStatus> check() async {
    final json = await _client.getJson('/health');
    return HealthStatus.fromJson(json);
  }
}
