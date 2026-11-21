import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/api/api_exception.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../auth/controllers/auth_controller.dart';

class AppDataController extends GetxController with WidgetsBindingObserver {
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
  final deviceNames = <String, String>{}.obs;
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
  Timer? _refreshTimer;
  Future<void>? _refreshInProgress;
  String? _sessionOwner;
  int _sessionGeneration = 0;
  Future<void>? _mapFocusLoadFuture;
  String? _mapFocusLoadedForUser;
  static const _fallbackMapFocusPrefsKey = 'map_focus_current_device';

  int get unreadCount => alerts.where((a) => !a.read).length;
  String deviceName(String id) {
    final saved = deviceNames[id];
    if (saved != null && saved.isNotEmpty) return saved;
    final device = devices.firstWhereOrNull((item) => item.deviceId == id);
    final pet = pets.firstWhereOrNull((item) => item.id == device?.petId);
    return pet == null ? 'Pet Tracker' : "${pet.name}'s Tracker";
  }

  Future<void> setDeviceName(String id, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final userId = Get.find<AuthController>().backendUser.value?.uid;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tracker_name_${userId}_$id', trimmed);
    deviceNames[id] = trimmed;
  }

  Future<void> _loadDeviceNames(List<DeviceModel> loaded) async {
    final userId = Get.find<AuthController>().backendUser.value?.uid;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final names = <String, String>{};
      for (final device in loaded) {
        final name = prefs.getString(
          'tracker_name_${userId}_${device.deviceId}',
        );
        if (name != null && name.isNotEmpty) names[device.deviceId] = name;
      }
      if (userId == _sessionOwner) deviceNames.assignAll(names);
    } catch (_) {}
  }

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
    WidgetsBinding.instance.addObserver(this);
    void sessionChanged(UserModel? user) {
      final eligibleOwner = user?.emailVerificationRequired == true
          ? null
          : user?.uid;
      if (_sessionOwner == eligibleOwner) return;
      _sessionOwner = eligibleOwner;
      _sessionGeneration++;
      _refreshInProgress = null;
      _clear();
      if (eligibleOwner == null) {
        _refreshTimer?.cancel();
      } else {
        unawaited(ensureMapFocusLoaded());
        _startAutoRefresh();
      }
    }

    _authWorker = ever(auth.backendUser, sessionChanged);
    sessionChanged(auth.backendUser.value);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startAutoRefresh();
    } else {
      _refreshTimer?.cancel();
    }
  }

  void _startAutoRefresh() {
    _refreshTimer?.cancel();
    final state = WidgetsBinding.instance.lifecycleState;
    if (_sessionOwner == null ||
        (state != null && state != AppLifecycleState.resumed)) {
      return;
    }
    unawaited(refreshAll(silent: true));
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(refreshAll(silent: true));
    });
  }

  @override
  void onClose() {
    _authWorker?.dispose();
    _refreshTimer?.cancel();
    _sessionGeneration++;
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  Future<void> refreshAll({bool silent = false}) async {
    final session = _sessionGeneration;
    if (_sessionOwner == null) return;
    final pending = _refreshInProgress;
    if (pending != null) {
      await pending;
      if (silent || session != _sessionGeneration) return;
      final next = _refreshInProgress;
      if (next != null) return next;
    }
    if (_sessionOwner == null || session != _sessionGeneration) return;
    final request = _refresh(session, silent);
    _refreshInProgress = request;
    try {
      await request;
    } finally {
      if (identical(request, _refreshInProgress)) _refreshInProgress = null;
    }
  }

  Future<void> _refresh(int session, bool silent) async {
    loading.value = true;
    error.value = '';
    var failed = false;
    Future<void> load<T>(
      Future<List<T>> Function() fetch,
      void Function(List<T>) apply,
    ) async {
      try {
        final result = await fetch();
        if (session == _sessionGeneration) apply(result);
      } catch (e) {
        failed = true;
        if (session == _sessionGeneration) {
          error.value = e is ApiException
              ? e.message
              : 'Could not refresh tracker data.';
        }
      }
    }

    try {
      await Future.wait([
        load(petsRepo.list, (result) {
          final priorId = selectedPet.value?.id;
          pets.assignAll(result);
          selectedPet.value =
              result.firstWhereOrNull((p) => p.id == priorId) ??
              result.firstOrNull;
        }),
        load(devicesRepo.list, (result) {
          devices.assignAll(result);
          unawaited(_loadDeviceNames(result));
        }),
        load(geofencesRepo.list, geofences.assignAll),
        load(alertsRepo.list, alerts.assignAll),
      ]);
      if (failed && !silent && session == _sessionGeneration) {
        Get.snackbar('Backend', error.value);
      }
    } finally {
      if (session == _sessionGeneration) loading.value = false;
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
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKey);
      if (storageKey != _currentMapFocusPrefsKey) return;
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
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKey);
    } finally {
      if (storageKey == _currentMapFocusPrefsKey) {
        _mapFocusLoadedForUser = storageKey;
        _mapFocusLoadFuture = null;
      }
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
    deviceNames.clear();
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
