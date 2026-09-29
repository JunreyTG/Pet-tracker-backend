class UserModel {
  UserModel({
    required this.uid,
    required this.email,
    required this.displayName,
  });
  final String uid;
  final String email;
  final String displayName;
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
    uid: json['uid'] ?? '',
    email: json['email'] ?? '',
    displayName: json['display_name'] ?? 'Pet Owner',
  );
  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'display_name': displayName,
  };
}

DateTime? parseDate(dynamic value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;

double? parseDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

double parseDouble(dynamic value, String field) {
  final parsed = parseDoubleOrNull(value);
  if (parsed == null) {
    throw FormatException('Missing or invalid "$field" in backend data.');
  }
  return parsed;
}

int? parseIntOrNull(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

Map<String, dynamic>? parseMapOrNull(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

LocationModel? parseLocationOrNull(dynamic value) {
  final map = parseMapOrNull(value);
  if (map == null) return null;
  final latitude = parseDoubleOrNull(map['latitude']);
  final longitude = parseDoubleOrNull(map['longitude']);
  if (latitude == null || longitude == null) return null;
  return LocationModel(latitude: latitude, longitude: longitude);
}

class LocationModel {
  LocationModel({required this.latitude, required this.longitude});
  final double latitude;
  final double longitude;
  factory LocationModel.fromJson(Map<String, dynamic> json) => LocationModel(
    latitude: parseDouble(json['latitude'], 'latitude'),
    longitude: parseDouble(json['longitude'], 'longitude'),
  );
  Map<String, dynamic> toJson() => {
    'latitude': latitude,
    'longitude': longitude,
  };
}

class PlaceModel {
  PlaceModel({required this.displayName, required this.location});
  final String displayName;
  final LocationModel location;
  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    final locationMap = parseMapOrNull(json['location']);
    if (locationMap == null) {
      throw const FormatException('Missing "location" in place data.');
    }
    return PlaceModel(
      displayName: json['display_name'] ?? '',
      location: LocationModel.fromJson(locationMap),
    );
  }
}

class PlaceOptionModel {
  PlaceOptionModel({required this.code, required this.name});
  final String code;
  final String name;
  factory PlaceOptionModel.fromJson(Map<String, dynamic> json) =>
      PlaceOptionModel(code: json['code'] ?? '', name: json['name'] ?? '');
  Map<String, dynamic> toJson() => {'code': code, 'name': name};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PlaceOptionModel && other.code == code && other.name == name;

  @override
  int get hashCode => Object.hash(code, name);
}

class PetModel {
  PetModel({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.age,
    this.photoUrl,
    this.deviceId,
    this.createdAt,
    this.updatedAt,
  });
  final String id;
  final String name;
  final String species;
  final String? breed;
  final int? age;
  final String? photoUrl;
  final String? deviceId;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  factory PetModel.fromJson(Map<String, dynamic> json) => PetModel(
    id: json['id']?.toString() ?? '',
    name: json['name']?.toString() ?? '',
    species: json['species']?.toString() ?? '',
    breed: json['breed']?.toString(),
    age: parseIntOrNull(json['age']),
    photoUrl: json['photo_url']?.toString(),
    deviceId: json['device_id']?.toString(),
    createdAt: parseDate(json['created_at']),
    updatedAt: parseDate(json['updated_at']),
  );
}

class DeviceModel {
  DeviceModel({
    required this.id,
    required this.deviceId,
    this.petId,
    required this.status,
    this.batteryLevel,
    this.currentLocation,
    this.lastSeen,
    this.lastLocationUpdate,
    required this.lowBatteryAlertActive,
    this.deviceSecret,
  });
  final String id;
  final String deviceId;
  final String? petId;
  final String status;
  final int? batteryLevel;
  final LocationModel? currentLocation;
  final DateTime? lastSeen;
  final DateTime? lastLocationUpdate;
  final bool lowBatteryAlertActive;
  final String? deviceSecret;
  bool get hasLocation => currentLocation != null;
  factory DeviceModel.fromJson(Map<String, dynamic> json) => DeviceModel(
    id: json['id']?.toString() ?? json['device_id']?.toString() ?? '',
    deviceId: json['device_id']?.toString() ?? '',
    petId: json['pet_id']?.toString(),
    status: json['status']?.toString() ?? 'unregistered',
    batteryLevel: parseIntOrNull(json['battery_level']),
    currentLocation: parseLocationOrNull(json['current_location']),
    lastSeen: parseDate(json['last_seen']),
    lastLocationUpdate: parseDate(json['last_location_update']),
    lowBatteryAlertActive: json['low_battery_alert_active'] is bool
        ? json['low_battery_alert_active'] as bool
        : false,
    deviceSecret: json['device_secret']?.toString(),
  );
}

class DeviceProvisioningModel {
  DeviceProvisioningModel({
    required this.deviceId,
    required this.deviceSecret,
    required this.backendUrl,
    required this.telemetryUrl,
    required this.setupHotspotSsid,
  });
  final String deviceId;
  final String deviceSecret;
  final String backendUrl;
  final String telemetryUrl;
  final String setupHotspotSsid;
  factory DeviceProvisioningModel.fromJson(Map<String, dynamic> json) =>
      DeviceProvisioningModel(
        deviceId: json['device_id'] ?? '',
        deviceSecret: json['device_secret'] ?? '',
        backendUrl: json['backend_url'] ?? '',
        telemetryUrl: json['telemetry_url'] ?? '',
        setupHotspotSsid: json['setup_hotspot_ssid'] ?? '',
      );
}

class GeofenceModel {
  GeofenceModel({
    required this.id,
    required this.petId,
    required this.name,
    required this.center,
    required this.radiusMeters,
    required this.enabled,
    this.lastState,
    this.lastCheckedAt,
  });
  final String id;
  final String petId;
  final String name;
  final LocationModel center;
  final double radiusMeters;
  final bool enabled;
  final String? lastState;
  final DateTime? lastCheckedAt;
  factory GeofenceModel.fromJson(Map<String, dynamic> json) {
    final centerMap = parseMapOrNull(json['center']);
    if (centerMap == null) {
      throw const FormatException('Missing "center" in geofence data.');
    }
    return GeofenceModel(
      id: json['id']?.toString() ?? '',
      petId: json['pet_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      center: LocationModel.fromJson(centerMap),
      radiusMeters: parseDouble(json['radius_meters'], 'radius_meters'),
      enabled: json['enabled'] is bool ? json['enabled'] as bool : true,
      lastState: json['last_state']?.toString(),
      lastCheckedAt: parseDate(json['last_checked_at']),
    );
  }
}

class AlertModel {
  AlertModel({
    required this.id,
    this.petId,
    this.deviceId,
    required this.type,
    required this.title,
    required this.message,
    this.latitude,
    this.longitude,
    required this.read,
    this.createdAt,
  });
  final String id;
  final String? petId;
  final String? deviceId;
  final String type;
  final String title;
  final String message;
  final double? latitude;
  final double? longitude;
  final bool read;
  final DateTime? createdAt;
  factory AlertModel.fromJson(Map<String, dynamic> json) => AlertModel(
    id: json['id']?.toString() ?? '',
    petId: json['pet_id']?.toString(),
    deviceId: json['device_id']?.toString(),
    type: json['type']?.toString() ?? '',
    title: json['title']?.toString() ?? '',
    message: json['message']?.toString() ?? '',
    latitude: parseDoubleOrNull(json['latitude']),
    longitude: parseDoubleOrNull(json['longitude']),
    read: json['read'] is bool ? json['read'] as bool : false,
    createdAt: parseDate(json['created_at']),
  );
}

class NotificationTokenModel {
  NotificationTokenModel({
    required this.tokenId,
    required this.platform,
    this.deviceName,
    required this.active,
  });
  final String tokenId;
  final String platform;
  final String? deviceName;
  final bool active;
  factory NotificationTokenModel.fromJson(Map<String, dynamic> json) =>
      NotificationTokenModel(
        tokenId: json['token_id'] ?? json['id'] ?? '',
        platform: json['platform'] ?? '',
        deviceName: json['device_name'],
        active: json['active'] ?? false,
      );
}

class LocationHistoryModel {
  LocationHistoryModel({
    required this.id,
    required this.petId,
    required this.deviceId,
    required this.latitude,
    required this.longitude,
    this.batteryLevel,
    this.recordedAt,
  });
  final String id;
  final String petId;
  final String deviceId;
  final double latitude;
  final double longitude;
  final int? batteryLevel;
  final DateTime? recordedAt;
  factory LocationHistoryModel.fromJson(Map<String, dynamic> json) =>
      LocationHistoryModel(
        id: json['id']?.toString() ?? '',
        petId: json['pet_id']?.toString() ?? '',
        deviceId: json['device_id']?.toString() ?? '',
        latitude: parseDouble(json['latitude'], 'latitude'),
        longitude: parseDouble(json['longitude'], 'longitude'),
        batteryLevel: parseIntOrNull(json['battery_level']),
        recordedAt: parseDate(json['recorded_at']),
      );
}
