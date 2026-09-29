import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_exception.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../auth/controllers/auth_controller.dart';

class AppDataController extends GetxController {
  AppDataController(
    this.petsRepo,
    this.devicesRepo,
    this.geofencesRepo,
    this.alertsRepo,
  );
  final PetRepository petsRepo;
  final DeviceRepository devicesRepo;
  final GeofenceRepository geofencesRepo;
  final AlertRepository alertsRepo;

  final pets = <PetModel>[].obs;
  final devices = <DeviceModel>[].obs;
  final geofences = <GeofenceModel>[].obs;
  final alerts = <AlertModel>[].obs;
  final selectedPet = Rxn<PetModel>();
  final mapFocusLocation = Rxn<LocationModel>();
  final mapFocusCountry = Rxn<PlaceOptionModel>();
  final mapFocusProvince = Rxn<PlaceOptionModel>();
  final mapFocusCity = Rxn<PlaceOptionModel>();
  final mapFocusBarangay = Rxn<PlaceOptionModel>();
  final loading = false.obs;
  final error = ''.obs;
  Worker? _authWorker;
  Future<void>? _mapFocusLoadFuture;
  String? _mapFocusLoadedForUser;
  static const _fallbackMapFocusPrefsKey = 'map_focus_current_device';

  int get unreadCount => alerts.where((a) => !a.read).length;
  bool get hasMapFocus =>
      mapFocusLocation.value != null &&
      mapFocusCountry.value != null &&
      mapFocusProvince.value != null &&
      mapFocusCity.value != null &&
      mapFocusBarangay.value != null;
  String get mapFocusLabel => [
    mapFocusBarangay.value?.name,
    mapFocusCity.value?.name,
    mapFocusProvince.value?.name,
    mapFocusCountry.value?.name,
  ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

  @override
  void onInit() {
    super.onInit();
    final auth = Get.find<AuthController>();
    _authWorker = ever(auth.backendUser, (user) async {
      if (user == null) {
        _clear();
      } else {
        await ensureMapFocusLoaded();
        refreshAll();
      }
    });
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    super.onClose();
  }

  Future<void> refreshAll() async {
    if (!Get.find<AuthController>().isAuthenticated) {
      _clear();
      return;
    }
    if (loading.value) return;
    loading.value = true;
    error.value = '';
    try {
      final results = await Future.wait([
        petsRepo.list(),
        devicesRepo.list(),
        geofencesRepo.list(),
        alertsRepo.list(),
      ]);
      pets.assignAll(results[0] as List<PetModel>);
      devices.assignAll(results[1] as List<DeviceModel>);
      geofences.assignAll(results[2] as List<GeofenceModel>);
      alerts.assignAll(results[3] as List<AlertModel>);
      if (pets.isNotEmpty &&
          (selectedPet.value == null ||
              !pets.any((p) => p.id == selectedPet.value!.id))) {
        selectedPet.value = pets.first;
      }
    } on ApiException catch (e) {
      error.value = e.message;
      Get.snackbar('Backend', e.message);
    } finally {
      loading.value = false;
    }
  }

  DeviceModel? deviceForPet(PetModel pet) {
    if (pet.deviceId == null) return null;
    return devices.firstWhereOrNull((d) => d.deviceId == pet.deviceId);
  }

  Future<void> ensureMapFocusLoaded() async {
    final storageKey = _currentMapFocusPrefsKey;
    if (_mapFocusLoadedForUser == storageKey) return;
    _mapFocusLoadFuture ??= _restoreSavedMapFocus(storageKey);
    await _mapFocusLoadFuture;
  }

  Future<void> saveMapFocus({
    required LocationModel location,
    required PlaceOptionModel country,
    required PlaceOptionModel province,
    required PlaceOptionModel city,
    required PlaceOptionModel barangay,
  }) async {
    mapFocusLocation.value = location;
    mapFocusCountry.value = country;
    mapFocusProvince.value = province;
    mapFocusCity.value = city;
    mapFocusBarangay.value = barangay;

    final encoded = jsonEncode({
      'location': location.toJson(),
      'country': country.toJson(),
      'province': province.toJson(),
      'city': city.toJson(),
      'barangay': barangay.toJson(),
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fallbackMapFocusPrefsKey, encoded);

    final userId = Get.find<AuthController>().backendUser.value?.uid;
    if (userId != null) {
      await prefs.setString(_mapFocusPrefsKey(userId), encoded);
    }
    _mapFocusLoadedForUser = _currentMapFocusPrefsKey;
  }

  Future<void> _restoreSavedMapFocus(String storageKey) async {
    String? restoredFromKey;
    try {
      final prefs = await SharedPreferences.getInstance();
      var saved = prefs.getString(storageKey);
      restoredFromKey = storageKey;
      if ((saved == null || saved.isEmpty) &&
          storageKey != _fallbackMapFocusPrefsKey) {
        saved = prefs.getString(_fallbackMapFocusPrefsKey);
        restoredFromKey = _fallbackMapFocusPrefsKey;
      }
      if (saved == null || saved.isEmpty) return;
      final json = Map<String, dynamic>.from(jsonDecode(saved) as Map);
      mapFocusLocation.value = LocationModel.fromJson(
        Map<String, dynamic>.from(json['location'] as Map),
      );
      mapFocusCountry.value = PlaceOptionModel.fromJson(
        Map<String, dynamic>.from(json['country'] as Map),
      );
      mapFocusProvince.value = PlaceOptionModel.fromJson(
        Map<String, dynamic>.from(json['province'] as Map),
      );
      mapFocusCity.value = PlaceOptionModel.fromJson(
        Map<String, dynamic>.from(json['city'] as Map),
      );
      mapFocusBarangay.value = PlaceOptionModel.fromJson(
        Map<String, dynamic>.from(json['barangay'] as Map),
      );
      if (storageKey != restoredFromKey) {
        await prefs.setString(storageKey, saved);
      }
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(restoredFromKey ?? storageKey);
    } finally {
      _mapFocusLoadedForUser = storageKey;
      _mapFocusLoadFuture = null;
    }
  }

  String get _currentMapFocusPrefsKey {
    final userId = Get.find<AuthController>().backendUser.value?.uid;
    return userId == null
        ? _fallbackMapFocusPrefsKey
        : _mapFocusPrefsKey(userId);
  }

  String _mapFocusPrefsKey(String userId) => 'map_focus_$userId';

  void _clear() {
    pets.clear();
    devices.clear();
    geofences.clear();
    alerts.clear();
    selectedPet.value = null;
    mapFocusLocation.value = null;
    mapFocusCountry.value = null;
    mapFocusProvince.value = null;
    mapFocusCity.value = null;
    mapFocusBarangay.value = null;
    _mapFocusLoadedForUser = null;
    _mapFocusLoadFuture = null;
    error.value = '';
    loading.value = false;
  }
}
