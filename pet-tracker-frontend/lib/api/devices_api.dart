import 'api_client.dart';

class ApiLocation {
  final double latitude;
  final double longitude;

  const ApiLocation({required this.latitude, required this.longitude});

  factory ApiLocation.fromJson(Map<String, dynamic> json) {
    return ApiLocation(
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ApiDevice {
  final String id;
  final String deviceId;
  final String? petId;
  final String status;
  final int? batteryLevel;
  final ApiLocation? currentLocation;
  final DateTime? lastSeen;
  final DateTime? lastLocationUpdate;
  final bool lowBatteryAlertActive;
  final String? deviceSecret;

  const ApiDevice({
    required this.id,
    required this.deviceId,
    required this.petId,
    required this.status,
    required this.batteryLevel,
    required this.currentLocation,
    required this.lastSeen,
    required this.lastLocationUpdate,
    required this.lowBatteryAlertActive,
    this.deviceSecret,
  });

  factory ApiDevice.fromJson(Map<String, dynamic> json) {
    final location = json['current_location'];
    return ApiDevice(
      id: json['id'] as String? ?? '',
      deviceId: json['device_id'] as String? ?? '',
      petId: json['pet_id'] as String?,
      status: json['status'] as String? ?? 'unregistered',
      batteryLevel: json['battery_level'] as int?,
      currentLocation: location is Map<String, dynamic>
          ? ApiLocation.fromJson(location)
          : null,
      lastSeen: DateTime.tryParse(json['last_seen'] as String? ?? ''),
      lastLocationUpdate: DateTime.tryParse(
        json['last_location_update'] as String? ?? '',
      ),
      lowBatteryAlertActive: json['low_battery_alert_active'] as bool? ?? false,
      deviceSecret: json['device_secret'] as String?,
    );
  }
}

class DevicesApi {
  final ApiClient _client;

  const DevicesApi(this._client);

  Future<List<ApiDevice>> listDevices() async {
    final json = await _client.getList('/api/v1/devices');
    return json
        .whereType<Map<String, dynamic>>()
        .map(ApiDevice.fromJson)
        .toList();
  }

  Future<ApiDevice> registerDevice(String deviceId) async {
    final json = await _client.postJson(
      '/api/v1/devices',
      body: {'device_id': deviceId},
    );
    return ApiDevice.fromJson(json);
  }

  Future<ApiDevice> assignDevice({
    required String deviceId,
    required String petId,
  }) async {
    final json = await _client.postJson(
      '/api/v1/devices/$deviceId/assign',
      body: {'pet_id': petId},
    );
    return ApiDevice.fromJson(json);
  }

  Future<ApiDevice> unassignDevice(String deviceId) async {
    final json = await _client.deleteJson(
      '/api/v1/devices/$deviceId/assignment',
    );
    return ApiDevice.fromJson(json);
  }
}
