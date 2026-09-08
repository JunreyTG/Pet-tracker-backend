part of '../main.dart';

enum DeviceStatus { online, offline, unregistered, disabled }

enum TrackerAlertType {
  geofenceExit,
  geofenceEnter,
  lowBattery,
  deviceOffline,
  deviceOnline,
}

enum GeofenceState { inside, outside }

enum NotificationPlatform { android, ios }

class LocationPoint {
  final double latitude;
  final double longitude;

  const LocationPoint(this.latitude, this.longitude);
}

class OwnerProfile {
  String uid;
  String email;
  String displayName;

  OwnerProfile({
    required this.uid,
    required this.email,
    required this.displayName,
  });
}

class Pet {
  String id;
  String name;
  String species;
  String? breed;
  int? age;
  String? photoUrl;
  String? deviceId;

  Pet({
    required this.id,
    required this.name,
    required this.species,
    this.breed,
    this.age,
    this.photoUrl,
    this.deviceId,
  });

  factory Pet.fromApi(ApiPet pet) {
    return Pet(
      id: pet.id,
      name: pet.name,
      species: pet.species,
      breed: pet.breed,
      age: pet.age,
      photoUrl: pet.photoUrl,
      deviceId: pet.deviceId,
    );
  }

  PetPayload toPayload() {
    return PetPayload(
      name: name,
      species: species,
      breed: breed,
      age: age,
      photoUrl: photoUrl,
    );
  }
}

class TrackerDevice {
  String id;
  String deviceId;
  String? petId;
  DeviceStatus status;
  int? batteryLevel;
  LocationPoint? currentLocation;
  DateTime? lastSeen;
  DateTime? lastLocationUpdate;
  bool lowBatteryAlertActive;
  String? deviceSecret;

  TrackerDevice({
    required this.id,
    required this.deviceId,
    this.petId,
    required this.status,
    this.batteryLevel,
    this.currentLocation,
    this.lastSeen,
    this.lastLocationUpdate,
    this.lowBatteryAlertActive = false,
    this.deviceSecret,
  });

  factory TrackerDevice.fromApi(ApiDevice device) {
    return TrackerDevice(
      id: device.id,
      deviceId: device.deviceId,
      petId: device.petId,
      status: parseDeviceStatus(device.status),
      batteryLevel: device.batteryLevel,
      currentLocation: device.currentLocation == null
          ? null
          : LocationPoint(
              device.currentLocation!.latitude,
              device.currentLocation!.longitude,
            ),
      lastSeen: device.lastSeen,
      lastLocationUpdate: device.lastLocationUpdate,
      lowBatteryAlertActive: device.lowBatteryAlertActive,
      deviceSecret: device.deviceSecret,
    );
  }
}

class SafeZone {
  String id;
  String petId;
  String name;
  LocationPoint center;
  double radiusMeters;
  bool enabled;
  GeofenceState? lastState;

  SafeZone({
    required this.id,
    required this.petId,
    required this.name,
    required this.center,
    required this.radiusMeters,
    this.enabled = true,
    this.lastState,
  });
}

class TrackerAlert {
  String id;
  String? petId;
  String? deviceId;
  TrackerAlertType type;
  String title;
  String message;
  LocationPoint? location;
  bool read;
  DateTime createdAt;

  TrackerAlert({
    required this.id,
    this.petId,
    this.deviceId,
    required this.type,
    required this.title,
    required this.message,
    this.location,
    this.read = false,
    required this.createdAt,
  });
}

class PushToken {
  String id;
  NotificationPlatform platform;
  String token;
  String? deviceName;
  bool active;

  PushToken({
    required this.id,
    required this.platform,
    required this.token,
    this.deviceName,
    this.active = true,
  });
}
