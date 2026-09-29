import 'dart:async';
import 'dart:convert';

import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../../../app/routes/app_routes.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../home/controllers/app_data_controller.dart';

class TrackingController extends GetxController {
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
  final roadRoute = <LatLng>[].obs;
  final routeLoading = false.obs;
  final routeError = ''.obs;
  Timer? _timer;
  String? _lastRouteSignature;

  String? get deviceId => Get.arguments is String
      ? Get.arguments as String
      : data.selectedPet.value?.deviceId;
  PetModel? get pet => device.value?.petId == null
      ? data.selectedPet.value
      : data.pets.firstWhereOrNull((p) => p.id == device.value?.petId);
  LatLng? get liveLatLng {
    final loc = device.value?.currentLocation;
    return loc == null ? null : LatLng(loc.latitude, loc.longitude);
  }

  String get focusLabel => [
    selectedBarangay.value?.name,
    selectedCity.value?.name,
    selectedProvince.value?.name,
    selectedCountry.value?.name,
  ].whereType<String>().where((part) => part.isNotEmpty).join(', ');

  List<LatLng> get trackPoints {
    final points = history.map((h) => LatLng(h.latitude, h.longitude)).toList();
    final live = liveLatLng;
    if (live != null && (points.isEmpty || !_samePoint(points.last, live))) {
      points.add(live);
    }
    return _uniquePoints(points);
  }

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    focusLoading.value = true;
    try {
      await data.ensureMapFocusLoaded();
      _restoreSavedFocus();
    } finally {
      focusLoading.value = false;
    }
    await loadCountries();
    startLivePolling();
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
    fetchLive();
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mode.value == 'live') fetchLive(silent: true);
    });
  }

  Future<void> fetchLive({bool silent = false}) async {
    final id = deviceId;
    if (id == null || id.isEmpty) return;
    if (!silent) loading.value = true;
    error.value = '';
    try {
      device.value = await data.devicesRepo.get(id);
      await _loadRecentHistoryForRoute();
      await refreshRoadRoute();
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  Future<void> loadHistory({int hours = 24}) async {
    final p = pet;
    if (p == null) return;
    mode.value = 'history';
    loading.value = true;
    error.value = '';
    try {
      history.assignAll(
        await data.petsRepo.history(
          p.id,
          limit: 200,
          start: DateTime.now().subtract(Duration(hours: hours)),
        ),
      );
      await refreshRoadRoute();
    } catch (e) {
      error.value = e.toString();
    } finally {
      loading.value = false;
    }
  }

  void showLive() {
    mode.value = 'live';
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

  Future<void> refreshRoadRoute() async {
    final waypoints = _routeWaypoints(trackPoints);
    if (waypoints.length < 2) {
      roadRoute.clear();
      routeError.value = '';
      _lastRouteSignature = null;
      return;
    }

    final signature = waypoints
        .map(
          (p) =>
              '${p.latitude.toStringAsFixed(6)},${p.longitude.toStringAsFixed(6)}',
        )
        .join('|');
    if (signature == _lastRouteSignature) return;

    _lastRouteSignature = signature;
    routeLoading.value = true;
    routeError.value = '';
    try {
      final coordinates = waypoints
          .map((p) => '${p.longitude},${p.latitude}')
          .join(';');
      final uri = Uri.parse(
        'https://router.project-osrm.org/route/v1/driving/$coordinates?overview=full&geometries=geojson',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 20));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Road route is unavailable.');
      }
      final decodedBody = jsonDecode(response.body);
      if (decodedBody is! Map) {
        throw Exception('Road route is unavailable.');
      }
      final decoded = Map<String, dynamic>.from(decodedBody);
      final routes = decoded['routes'];
      if (routes is! List || routes.isEmpty) {
        throw Exception('Road route is unavailable.');
      }
      final route = routes.first;
      if (route is! Map) {
        throw Exception('Road route is unavailable.');
      }
      final routeMap = Map<String, dynamic>.from(route);
      final geometry = routeMap['geometry'];
      if (geometry is! Map) {
        throw Exception('Road route is unavailable.');
      }
      final coords = Map<String, dynamic>.from(geometry)['coordinates'];
      if (coords is! List) {
        throw Exception('Road route is unavailable.');
      }
      final points = <LatLng>[];
      for (final coord in coords) {
        if (coord is! List || coord.length < 2) continue;
        final lon = coord[0];
        final lat = coord[1];
        if (lon is! num || lat is! num) continue;
        points.add(LatLng(lat.toDouble(), lon.toDouble()));
      }
      if (points.length < 2) {
        throw Exception('Road route is unavailable.');
      }
      roadRoute.assignAll(points);
    } catch (_) {
      roadRoute.clear();
      routeError.value = 'Road route unavailable; showing direct track.';
    } finally {
      routeLoading.value = false;
    }
  }

  void recenter() {
    final point =
        liveLatLng ??
        focusCenter.value ??
        (history.isNotEmpty
            ? LatLng(history.last.latitude, history.last.longitude)
            : null);
    if (point != null) mapController.move(point, 16);
  }

  Future<void> _loadRecentHistoryForRoute() async {
    final p = pet;
    if (p == null) return;
    history.assignAll(
      await data.petsRepo.history(
        p.id,
        limit: 100,
        start: DateTime.now().subtract(const Duration(hours: 24)),
      ),
    );
  }

  List<LatLng> _routeWaypoints(List<LatLng> points) {
    if (points.length <= 25) return points;
    return points.sublist(points.length - 25);
  }

  List<LatLng> _uniquePoints(List<LatLng> points) {
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
    super.onClose();
  }
}
