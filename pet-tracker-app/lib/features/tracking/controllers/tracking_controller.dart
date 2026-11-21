import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/routes/app_routes.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../home/controllers/app_data_controller.dart';

class TrackingController extends GetxController with WidgetsBindingObserver {
  final data = Get.find<AppDataController>();
  final placesRepo = Get.find<PlaceRepository>();
  final mapController = MapController();
  final mode = 'live'.obs;
  final loading = false.obs;
  final error = ''.obs;
  final device = Rxn<DeviceModel>();
  final history = <LocationHistoryModel>[].obs;
  final countries = <PlaceOptionModel>[].obs;
  final provinces = <PlaceOptionModel>[].obs;
  final cities = <PlaceOptionModel>[].obs;
  final barangays = <PlaceOptionModel>[].obs;
  final selectedCountry = Rxn<PlaceOptionModel>();
  final selectedProvince = Rxn<PlaceOptionModel>();
  final selectedCity = Rxn<PlaceOptionModel>();
  final selectedBarangay = Rxn<PlaceOptionModel>();
  final placeOptionsLoading = false.obs;
  final placeOptionsError = ''.obs;
  final focusSet = false.obs;
  final focusLoading = false.obs;
  final focusError = ''.obs;
  final focusCenter = Rxn<LatLng>();
  final historyLoading = false.obs;
  final historyError = ''.obs;
  Timer? _timer;
  bool mapReady = false;
  bool _livePending = false;
  int _historyGeneration = 0;
  final String? _requestedDevice = Get.arguments is String
      ? Get.arguments as String
      : null;

  String? get deviceId => _requestedDevice ?? data.selectedPet.value?.deviceId;
  DeviceModel? get currentDevice =>
      device.value?.deviceId == deviceId ? device.value : null;
  String? get _petId {
    final collar = currentDevice;
    if (collar != null) return collar.petId;
    return _requestedDevice == null ? data.selectedPet.value?.id : null;
  }

  PetModel? get pet =>
      data.pets.firstWhereOrNull((p) => p.id == _petId) ??
      (data.selectedPet.value?.id == _petId ? data.selectedPet.value : null);
  LatLng? get liveLatLng {
    final loc = currentDevice?.currentLocation;
    return loc == null ? null : LatLng(loc.latitude, loc.longitude);
  }

  String get focusLabel => [
    selectedBarangay.value?.name,
    selectedCity.value?.name,
    selectedProvince.value?.name,
    selectedCountry.value?.name,
  ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

  List<LatLng> get trackPoints => _uniquePoints(
    history
        .where((h) => h.petId == _petId)
        .map((h) => LatLng(h.latitude, h.longitude)),
  );

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      startLivePolling();
    } else {
      _timer?.cancel();
    }
  }

  Future<void> _initialize() async {
    focusLoading.value = true;
    try {
      await data.ensureMapFocusLoaded();
      _restoreSavedFocus();
    } finally {
      focusLoading.value = false;
    }
    if (!isClosed) {
      startLivePolling();
      await loadCountries();
    }
  }

  void _restoreSavedFocus() {
    final savedLocation = data.mapFocusLocation.value;
    if (!data.hasMapFocus || savedLocation == null) return;

    selectedCountry.value = data.mapFocusCountry.value;
    selectedProvince.value = data.mapFocusProvince.value;
    selectedCity.value = data.mapFocusCity.value;
    selectedBarangay.value = data.mapFocusBarangay.value;
    focusCenter.value = LatLng(savedLocation.latitude, savedLocation.longitude);
    focusSet.value = true;
  }

  Future<void> loadCountries() async {
    placeOptionsLoading.value = true;
    placeOptionsError.value = '';
    try {
      countries.assignAll(await placesRepo.countries());
      final country =
          _matchingOption(countries, selectedCountry.value) ??
          (countries.isNotEmpty ? countries.first : null);
      selectedCountry.value = country;
      if (country == null) return;

      provinces.assignAll(await placesRepo.provinces(country.code));
      final province = _matchingOption(provinces, selectedProvince.value);
      selectedProvince.value = province;
      if (province == null) return;

      cities.assignAll(await placesRepo.cities(province.code));
      final city = _matchingOption(cities, selectedCity.value);
      selectedCity.value = city;
      if (city == null) return;

      barangays.assignAll(await placesRepo.barangays(city.code));
      selectedBarangay.value = _matchingOption(
        barangays,
        selectedBarangay.value,
      );
    } catch (e) {
      placeOptionsError.value = e.toString();
    } finally {
      placeOptionsLoading.value = false;
    }
  }

  Future<void> selectCountry(PlaceOptionModel? country) async {
    selectedCountry.value = country;
    selectedProvince.value = null;
    selectedCity.value = null;
    selectedBarangay.value = null;
    provinces.clear();
    cities.clear();
    barangays.clear();
    if (country == null) return;

    placeOptionsLoading.value = true;
    placeOptionsError.value = '';
    try {
      provinces.assignAll(await placesRepo.provinces(country.code));
    } catch (e) {
      placeOptionsError.value = e.toString();
    } finally {
      placeOptionsLoading.value = false;
    }
  }

  Future<void> selectProvince(PlaceOptionModel? province) async {
    selectedProvince.value = province;
    selectedCity.value = null;
    selectedBarangay.value = null;
    cities.clear();
    barangays.clear();
    if (province == null) return;

    placeOptionsLoading.value = true;
    placeOptionsError.value = '';
    try {
      cities.assignAll(await placesRepo.cities(province.code));
    } catch (e) {
      placeOptionsError.value = e.toString();
    } finally {
      placeOptionsLoading.value = false;
    }
  }

  Future<void> selectCity(PlaceOptionModel? city) async {
    selectedCity.value = city;
    selectedBarangay.value = null;
    barangays.clear();
    if (city == null) return;

    placeOptionsLoading.value = true;
    placeOptionsError.value = '';
    try {
      barangays.assignAll(await placesRepo.barangays(city.code));
    } catch (e) {
      placeOptionsError.value = e.toString();
    } finally {
      placeOptionsLoading.value = false;
    }
  }

  void selectBarangay(PlaceOptionModel? barangay) {
    selectedBarangay.value = barangay;
  }

  void startLivePolling() {
    _timer?.cancel();
    final state = WidgetsBinding.instance.lifecycleState;
    if (state != null && state != AppLifecycleState.resumed) return;
    fetchLive();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      final route = Get.currentRoute;
      if (mode.value == 'live' &&
          (route == Routes.tracking || route.isEmpty || route == '/')) {
        fetchLive(silent: true);
      }
    });
  }

  Future<void> fetchLive({bool silent = false}) async {
    final id = deviceId;
    if (id == null || id.isEmpty || _livePending || mode.value != 'live') {
      return;
    }
    _livePending = true;
    if (!silent) loading.value = true;
    error.value = '';
    try {
      final collar = await data.devicesRepo.get(id);
      if (!isClosed && id == deviceId) device.value = collar;
    } catch (e) {
      if (!isClosed && id == deviceId) error.value = e.toString();
    } finally {
      _livePending = false;
      if (!isClosed) loading.value = false;
    }
  }

  Future<void> loadHistory({int hours = 24}) async {
    mode.value = 'history';
    final id = deviceId;
    final generation = ++_historyGeneration;
    history.clear();
    historyLoading.value = true;
    historyError.value = '';
    bool stillCurrent() =>
        !isClosed &&
        generation == _historyGeneration &&
        id == deviceId &&
        mode.value == 'history';
    try {
      if (_petId == null && id != null && currentDevice == null) {
        final collar = await data.devicesRepo.get(id);
        if (!stillCurrent()) return;
        device.value = collar;
      }
      final petId = _petId;
      if (petId == null) {
        historyError.value = 'Assign this tracker to a pet to see its trail.';
        return;
      }
      final now = DateTime.now();
      final points = await data.petsRepo.history(
        petId,
        limit: 200,
        start: now.subtract(Duration(hours: hours)),
        end: now,
      );
      if (!stillCurrent() || petId != _petId) return;
      history.assignAll(points);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (stillCurrent()) fitHistory();
      });
    } catch (_) {
      if (stillCurrent()) {
        historyError.value = 'Could not load the pet’s trail.';
      }
    } finally {
      if (!isClosed && generation == _historyGeneration) {
        historyLoading.value = false;
      }
    }
  }

  void showLive() {
    _historyGeneration++;
    historyLoading.value = false;
    mode.value = 'live';
    recenter();
    fetchLive();
  }

  void editMapFocus() {
    Get.toNamed(Routes.mapFocus);
  }

  void cancelMapFocusEdit() {
    focusError.value = '';
    placeOptionsError.value = '';
    _restoreSavedFocus();
    if (focusCenter.value != null) focusSet.value = true;
  }

  Future<void> applyMapFocus() async {
    if (selectedCountry.value == null ||
        selectedProvince.value == null ||
        selectedCity.value == null ||
        selectedBarangay.value == null) {
      focusError.value =
          'Select country, province, city, and barangay before tracking.';
      return;
    }

    focusLoading.value = true;
    focusError.value = '';
    try {
      final results = await placesRepo.search(
        country: selectedCountry.value!.name,
        province: selectedProvince.value!.name,
        city: selectedCity.value!.name,
        barangay: selectedBarangay.value!.name,
        limit: 1,
      );
      if (results.isEmpty) {
        throw Exception(
          'Address was not found. Check the barangay, city, province, and country.',
        );
      }
      final first = results.first.location;
      focusCenter.value = LatLng(first.latitude, first.longitude);
      await data.saveMapFocus(
        location: first,
        country: selectedCountry.value!,
        province: selectedProvince.value!,
        city: selectedCity.value!,
        barangay: selectedBarangay.value!,
      );
      focusSet.value = true;
    } catch (e) {
      focusError.value = e.toString().replaceFirst('Exception: ', '');
    } finally {
      focusLoading.value = false;
    }
  }

  void fitHistory() {
    if (!mapReady) return;
    final points = trackPoints;
    if (points.length == 1) {
      mapController.move(points.single, 16);
    } else if (points.length > 1) {
      final height = mapController.camera.nonRotatedSize.height;
      final topPadding = (height * .32).clamp(32.0, 200.0).toDouble();
      final bottomPadding = (height * .24).clamp(24.0, 130.0).toDouble();
      mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(points),
          maxZoom: 17,
          padding: EdgeInsets.fromLTRB(30, topPadding, 62, bottomPadding),
        ),
      );
    }
  }

  void recenter() {
    if (!mapReady) return;
    if (mode.value == 'history' && trackPoints.isNotEmpty) {
      fitHistory();
      return;
    }
    final point = liveLatLng ?? focusCenter.value;
    if (point != null) mapController.move(point, 16);
  }

  List<LatLng> _uniquePoints(Iterable<LatLng> points) {
    final unique = <LatLng>[];
    for (final point in points) {
      if (unique.isEmpty || !_samePoint(unique.last, point)) unique.add(point);
    }
    return unique;
  }

  bool _samePoint(LatLng a, LatLng b) =>
      a.latitude.toStringAsFixed(6) == b.latitude.toStringAsFixed(6) &&
      a.longitude.toStringAsFixed(6) == b.longitude.toStringAsFixed(6);

  PlaceOptionModel? _matchingOption(
    List<PlaceOptionModel> options,
    PlaceOptionModel? selected,
  ) {
    if (selected == null) return null;
    return options.firstWhereOrNull((option) => option.code == selected.code);
  }

  @override
  void onClose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
