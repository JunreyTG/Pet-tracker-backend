import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../home/controllers/app_data_controller.dart';
import '../controllers/tracking_controller.dart';

class MapFocusScreen extends StatefulWidget {
  const MapFocusScreen({super.key});

  @override
  State<MapFocusScreen> createState() => _MapFocusScreenState();
}

class _MapFocusScreenState extends State<MapFocusScreen> {
  final _data = Get.find<AppDataController>();
  final _placesRepo = Get.find<PlaceRepository>();
  final _mapController = MapController();

  List<PlaceOptionModel> _countries = [];
  List<PlaceOptionModel> _provinces = [];
  List<PlaceOptionModel> _cities = [];
  List<PlaceOptionModel> _barangays = [];

  PlaceOptionModel? _country;
  PlaceOptionModel? _province;
  PlaceOptionModel? _city;
  PlaceOptionModel? _barangay;

  LatLng _focusCenter = const LatLng(14.5995, 120.9842);
  bool _placeLoading = false;
  bool _saving = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    final saved = _data.mapFocusLocation.value;
    if (saved != null) {
      _focusCenter = LatLng(saved.latitude, saved.longitude);
      _country = _data.mapFocusCountry.value;
      _province = _data.mapFocusProvince.value;
      _city = _data.mapFocusCity.value;
      _barangay = _data.mapFocusBarangay.value;
    }
    _loadCountries();
  }

  Future<void> _loadCountries() async {
    setState(() {
      _placeLoading = true;
      _error = '';
    });
    try {
      _countries = await _placesRepo.countries();
      _country = _matchingOption(_countries, _country) ?? (_countries.isNotEmpty ? _countries.first : null);
      if (_country != null) {
        _provinces = await _placesRepo.provinces(_country!.code);
        _province = _matchingOption(_provinces, _province);
      }
      if (_province != null) {
        _cities = await _placesRepo.cities(_province!.code);
        _city = _matchingOption(_cities, _city);
      }
      if (_city != null) {
        _barangays = await _placesRepo.barangays(_city!.code);
        _barangay = _matchingOption(_barangays, _barangay);
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _placeLoading = false);
    }
  }

  Future<void> _selectCountry(PlaceOptionModel? country) async {
    setState(() {
      _country = country;
      _province = null;
      _city = null;
      _barangay = null;
      _provinces = [];
      _cities = [];
      _barangays = [];
      _error = '';
    });
    if (country == null) return;
    await _loadOptions(() async {
      _provinces = await _placesRepo.provinces(country.code);
    });
  }

  Future<void> _selectProvince(PlaceOptionModel? province) async {
    setState(() {
      _province = province;
      _city = null;
      _barangay = null;
      _cities = [];
      _barangays = [];
      _error = '';
    });
    if (province == null) return;
    await _loadOptions(() async {
      _cities = await _placesRepo.cities(province.code);
    });
  }

  Future<void> _selectCity(PlaceOptionModel? city) async {
    setState(() {
      _city = city;
      _barangay = null;
      _barangays = [];
      _error = '';
    });
    if (city == null) return;
    await _loadOptions(() async {
      _barangays = await _placesRepo.barangays(city.code);
    });
  }

  Future<void> _selectBarangay(PlaceOptionModel? barangay) async {
    setState(() => _barangay = barangay);
    if (barangay != null) {
      await _previewPlace();
    }
  }

  Future<void> _loadOptions(Future<void> Function() loader) async {
    setState(() => _placeLoading = true);
    try {
      await loader();
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _placeLoading = false);
    }
  }

  Future<void> _previewPlace() async {
    if (_country == null || _province == null || _city == null || _barangay == null) {
      return;
    }
    setState(() {
      _placeLoading = true;
      _error = '';
    });
    try {
      final results = await _placesRepo.search(
        country: _country!.name,
        province: _province!.name,
        city: _city!.name,
        barangay: _barangay!.name,
        limit: 1,
      );
      if (results.isNotEmpty) {
        final loc = results.first.location;
        setState(() {
          _focusCenter = LatLng(loc.latitude, loc.longitude);
        });
        _mapController.move(_focusCenter, 15.5);
      }
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _placeLoading = false);
    }
  }

  Future<void> _saveFocus() async {
    if (_country == null || _province == null || _city == null || _barangay == null) {
      setState(() => _error = 'Please select Country, Province, City, and Barangay.');
      return;
    }

    setState(() {
      _saving = true;
      _error = '';
    });

    try {
      final loc = LocationModel(
        latitude: _focusCenter.latitude,
        longitude: _focusCenter.longitude,
      );
      await _data.saveMapFocus(
        location: loc,
        country: _country!,
        province: _province!,
        city: _city!,
        barangay: _barangay!,
      );

      if (Get.isRegistered<TrackingController>()) {
        final tc = Get.find<TrackingController>();
        tc.selectedCountry.value = _country;
        tc.selectedProvince.value = _province;
        tc.selectedCity.value = _city;
        tc.selectedBarangay.value = _barangay;
        tc.focusCenter.value = _focusCenter;
        tc.focusSet.value = true;
      }

      Get.back();
      Get.snackbar(
        'Map Focus Updated',
        'Tracking map focus is now set to ${_barangay?.name ?? ""}, ${_city?.name ?? ""}.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  PlaceOptionModel? _matchingOption(
    List<PlaceOptionModel> options,
    PlaceOptionModel? selected,
  ) {
    if (selected == null) return null;
    return options.firstWhereOrNull((option) => option.code == selected.code);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Setup Focus Map'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Map Preview Card
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .08),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: SizedBox(
                  height: 280,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _focusCenter,
                          initialZoom: 15.5,
                          onTap: (_, p) => setState(() => _focusCenter = p),
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'pet_tracker_app',
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _focusCenter,
                                width: 50,
                                height: 50,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: .3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.place,
                                    color: AppTheme.green,
                                    size: 38,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Top instruction chip
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .65),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.touch_app, size: 14, color: Colors.white),
                              SizedBox(width: 4),
                              Text(
                                'Tap to pin exact center',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Zoom controls
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'focus_zoom_in',
                              onPressed: () => _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom + 1,
                              ),
                              child: const Icon(Icons.add),
                            ),
                            const SizedBox(height: 6),
                            FloatingActionButton.small(
                              heroTag: 'focus_zoom_out',
                              onPressed: () => _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom - 1,
                              ),
                              child: const Icon(Icons.remove),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Form selection card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Focus Location Area',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    _FocusDropdown(
                      label: 'Country',
                      value: _country,
                      options: _countries,
                      onChanged: _placeLoading ? null : _selectCountry,
                    ),
                    const SizedBox(height: 10),
                    _FocusDropdown(
                      label: 'Province',
                      value: _province,
                      options: _provinces,
                      onChanged: _placeLoading || _country == null ? null : _selectProvince,
                    ),
                    const SizedBox(height: 10),
                    _FocusDropdown(
                      label: 'City / Municipality',
                      value: _city,
                      options: _cities,
                      onChanged: _placeLoading || _province == null ? null : _selectCity,
                    ),
                    const SizedBox(height: 10),
                    _FocusDropdown(
                      label: 'Barangay',
                      value: _barangay,
                      options: _barangays,
                      onChanged: _placeLoading || _city == null ? null : _selectBarangay,
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _placeLoading ? null : _previewPlace,
                      icon: _placeLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.travel_explore),
                      label: const Text('Move Map to Selected Barangay'),
                    ),
                    if (_error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error,
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save Map Focus Button
            FilledButton.icon(
              onPressed: _saving ? null : _saveFocus,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: AppTheme.green,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline),
              label: Text(
                _saving ? 'Saving...' : 'Apply & Save Map Focus',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FocusDropdown extends StatelessWidget {
  const _FocusDropdown({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final PlaceOptionModel? value;
  final List<PlaceOptionModel> options;
  final ValueChanged<PlaceOptionModel?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selectedValue = options.where((option) => option == value).length == 1 ? value : null;
    return DropdownButtonFormField<PlaceOptionModel>(
      key: ValueKey('$label-${selectedValue?.code}-${options.length}'),
      initialValue: selectedValue,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: options
          .map(
            (option) => DropdownMenuItem(
              value: option,
              child: Text(option.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: onChanged,
    );
  }
}
