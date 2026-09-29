import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/api/api_client.dart';
import '../models/models.dart';

/// Parses a backend list while skipping corrupt documents instead of
/// crashing the whole screen when a single Firestore record is malformed.
List<T> parseModelList<T>(
  dynamic data,
  T Function(Map<String, dynamic>) parse,
) {
  if (data is! List) return <T>[];
  final items = <T>[];
  for (final entry in data) {
    try {
      final map = entry is Map<String, dynamic>
          ? entry
          : Map<String, dynamic>.from(entry as Map);
      items.add(parse(map));
    } catch (_) {
      continue;
    }
  }
  return items;
}

class BackendAuthRepository {
  BackendAuthRepository(this._api);
  final ApiClient _api;
  static const _userStorageKey = 'pet_tracker_cached_user';

  Future<UserModel> login(String email, String password) async {
    final response = Map<String, dynamic>.from(
      await _api.post(
        '/auth/login',
        body: {'email': email, 'password': password},
      ),
    );
    _api.setAuthToken(response['access_token'] ?? '');
    final user = UserModel.fromJson(Map<String, dynamic>.from(response['user']));
    _saveCachedUser(user);
    return user;
  }

  Future<UserModel> register(String email, String password, String name) async {
    final response = Map<String, dynamic>.from(
      await _api.post(
        '/auth/register',
        body: {'email': email, 'password': password, 'name': name},
      ),
    );
    _api.setAuthToken(response['access_token'] ?? '');
    final user = UserModel.fromJson(Map<String, dynamic>.from(response['user']));
    _saveCachedUser(user);
    return user;
  }

  Future<UserModel> me() async {
    final user = UserModel.fromJson(Map<String, dynamic>.from(await _api.get('/auth/me')));
    _saveCachedUser(user);
    return user;
  }

  void logout() {
    _api.clearAuthToken();
    _clearCachedUser();
  }

  Future<UserModel?> getCachedUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString(_userStorageKey);
      if (str != null && str.isNotEmpty) {
        return UserModel.fromJson(Map<String, dynamic>.from(jsonDecode(str)));
      }
    } catch (_) {}
    return null;
  }

  void _saveCachedUser(UserModel user) {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString(_userStorageKey, jsonEncode(user.toJson()));
    }).catchError((_) {});
  }

  void _clearCachedUser() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.remove(_userStorageKey);
    }).catchError((_) {});
  }
}

class PetRepository {
  PetRepository(this._api);
  final ApiClient _api;
  Future<List<PetModel>> list() async =>
      parseModelList(await _api.get('/pets'), PetModel.fromJson);
  Future<PetModel> get(String id) async =>
      PetModel.fromJson(Map<String, dynamic>.from(await _api.get('/pets/$id')));
  Future<PetModel> create(Map<String, dynamic> data) async => PetModel.fromJson(
    Map<String, dynamic>.from(await _api.post('/pets', body: data)),
  );
  Future<PetModel> update(String id, Map<String, dynamic> data) async =>
      PetModel.fromJson(
        Map<String, dynamic>.from(await _api.patch('/pets/$id', body: data)),
      );
  Future<void> delete(String id) async => _api.delete('/pets/$id');
  Future<List<LocationHistoryModel>> history(
    String petId, {
    int limit = 100,
    DateTime? start,
    DateTime? end,
  }) async {
    final list =
        await _api.get(
              '/pets/$petId/location-history',
              query: {
                'limit': '$limit',
                'start_time': start?.toUtc().toIso8601String(),
                'end_time': end?.toUtc().toIso8601String(),
              },
            )
            as List;
    return parseModelList(list, LocationHistoryModel.fromJson);
  }
}

class DeviceRepository {
  DeviceRepository(this._api);
  final ApiClient _api;
  Future<List<DeviceModel>> list() async =>
      parseModelList(await _api.get('/devices'), DeviceModel.fromJson);
  Future<DeviceModel> get(String id) async => DeviceModel.fromJson(
    Map<String, dynamic>.from(await _api.get('/devices/$id')),
  );
  Future<DeviceModel> register(String id) async => DeviceModel.fromJson(
    Map<String, dynamic>.from(
      await _api.post('/devices', body: {'device_id': id}),
    ),
  );
  Future<DeviceProvisioningModel> provision(
    String id, {
    required String backendUrl,
  }) async => DeviceProvisioningModel.fromJson(
    Map<String, dynamic>.from(
      await _api.post(
        '/devices/setup',
        body: {'device_id': id, 'backend_url': backendUrl},
      ),
    ),
  );
  Future<DeviceModel> assign(String deviceId, String petId) async =>
      DeviceModel.fromJson(
        Map<String, dynamic>.from(
          await _api.post('/devices/$deviceId/assign', body: {'pet_id': petId}),
        ),
      );
  Future<DeviceModel> unassign(String deviceId) async => DeviceModel.fromJson(
    Map<String, dynamic>.from(
      await _api.delete('/devices/$deviceId/assignment'),
    ),
  );
}

class GeofenceRepository {
  GeofenceRepository(this._api);
  final ApiClient _api;
  Future<List<GeofenceModel>> list() async =>
      parseModelList(await _api.get('/geofences'), GeofenceModel.fromJson);
  Future<GeofenceModel> create(Map<String, dynamic> data) async =>
      GeofenceModel.fromJson(
        Map<String, dynamic>.from(await _api.post('/geofences', body: data)),
      );
  Future<GeofenceModel> update(String id, Map<String, dynamic> data) async =>
      GeofenceModel.fromJson(
        Map<String, dynamic>.from(
          await _api.patch('/geofences/$id', body: data),
        ),
      );
  Future<void> delete(String id) async => _api.delete('/geofences/$id');
}

class PlaceRepository {
  PlaceRepository(this._api);
  final ApiClient _api;
  Future<List<PlaceOptionModel>> countries() async => parseModelList(
    await _api.get('/places/countries'),
    PlaceOptionModel.fromJson,
  );
  Future<List<PlaceOptionModel>> provinces(String countryCode) async =>
      parseModelList(
        await _api.get(
          '/places/provinces',
          query: {'country_code': countryCode},
        ),
        PlaceOptionModel.fromJson,
      );
  Future<List<PlaceOptionModel>> cities(String provinceCode) async =>
      parseModelList(
        await _api.get(
          '/places/cities',
          query: {'province_code': provinceCode},
        ),
        PlaceOptionModel.fromJson,
      );
  Future<List<PlaceOptionModel>> barangays(String cityCode) async =>
      parseModelList(
        await _api.get('/places/barangays', query: {'city_code': cityCode}),
        PlaceOptionModel.fromJson,
      );
  Future<List<PlaceModel>> search({
    required String country,
    required String province,
    required String city,
    required String barangay,
    int limit = 5,
  }) async => parseModelList(
    await _api.get(
      '/places/search',
      query: {
        'country': country,
        'province': province,
        'city': city,
        'barangay': barangay,
        'limit': '$limit',
      },
    ),
    PlaceModel.fromJson,
  );
}

class AlertRepository {
  AlertRepository(this._api);
  final ApiClient _api;
  Future<List<AlertModel>> list({
    String? petId,
    String? type,
    bool? read,
  }) async => parseModelList(
    await _api.get(
      '/alerts',
      query: {'pet_id': petId, 'type': type, 'read': read?.toString()},
    ),
    AlertModel.fromJson,
  );
  Future<AlertModel> updateRead(String id, bool read) async =>
      AlertModel.fromJson(
        Map<String, dynamic>.from(
          await _api.patch('/alerts/$id', body: {'read': read}),
        ),
      );
  Future<void> delete(String id) async => _api.delete('/alerts/$id');
}

class NotificationRepository {
  NotificationRepository(this._api);
  final ApiClient _api;
  Future<String> register(
    String token,
    String platform,
    String? deviceName,
  ) async {
    final result = Map<String, dynamic>.from(
      await _api.post(
        '/notifications/tokens',
        body: {'token': token, 'platform': platform, 'device_name': deviceName},
      ),
    );
    return result['token_id'] ?? '';
  }

  Future<void> delete(String tokenId) async =>
      _api.delete('/notifications/tokens/$tokenId');
}
