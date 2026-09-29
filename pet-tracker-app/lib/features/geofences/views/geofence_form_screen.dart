import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:get/get.dart';
import 'package:latlong2/latlong.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/pet_avatar.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/repositories.dart';
import '../../home/controllers/app_data_controller.dart';

class GeofenceFormScreen extends StatefulWidget {
  const GeofenceFormScreen({super.key});

  @override
  State<GeofenceFormScreen> createState() => _GeofenceFormScreenState();
}

class _GeofenceFormScreenState extends State<GeofenceFormScreen> {
  final _data = Get.find<AppDataController>();
  final _placesRepo = Get.find<PlaceRepository>();
  final _mapController = MapController();

  late final TextEditingController _nameController;
  late final TextEditingController _radiusController;

  GeofenceModel? _geofence;
  late String _petId;
  late LatLng _center;
  double _radiusMeters = 100.0;
  bool _enabled = true;

  List<PlaceOptionModel> _countries = [];
  List<PlaceOptionModel> _provinces = [];
  List<PlaceOptionModel> _cities = [];
  List<PlaceOptionModel> _barangays = [];
  PlaceOptionModel? _country;
  PlaceOptionModel? _province;
  PlaceOptionModel? _city;
  PlaceOptionModel? _barangay;

  bool _placeLoading = false;
  bool _saving = false;
  String _placeError = '';

  bool get _isNew => _geofence == null;

  @override
  void initState() {
    super.initState();
    _geofence = Get.arguments is GeofenceModel ? Get.arguments as GeofenceModel : null;
    final savedFocus = _data.mapFocusLocation.value;

    _nameController = TextEditingController(
      text: _geofence?.name ?? _data.mapFocusBarangay.value?.name ?? 'Home Safe Zone',
    );
    _radiusMeters = _geofence?.radiusMeters ?? 100.0;
    _radiusController = TextEditingController(
      text: _radiusMeters.toStringAsFixed(0),
    );
    _enabled = _geofence?.enabled ?? true;
    _petId = _initialPetId();

    if (_geofence != null) {
      _center = LatLng(_geofence!.center.latitude, _geofence!.center.longitude);
    } else if (savedFocus != null) {
      _center = LatLng(savedFocus.latitude, savedFocus.longitude);
    } else {
      _center = const LatLng(14.5995, 120.9842);
    }

    if (_isNew && _data.hasMapFocus) {
      _country = _data.mapFocusCountry.value;
      _province = _data.mapFocusProvince.value;
      _city = _data.mapFocusCity.value;
      _barangay = _data.mapFocusBarangay.value;
    }

    _loadCountries();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _radiusController.dispose();
    super.dispose();
  }

  String _initialPetId() {
    final geofencePetId = _geofence?.petId;
    if (geofencePetId != null && _data.pets.any((p) => p.id == geofencePetId)) {
      return geofencePetId;
    }
    final selectedPetId = _data.selectedPet.value?.id;
    if (selectedPetId != null && _data.pets.any((p) => p.id == selectedPetId)) {
      return selectedPetId;
    }
    return _data.pets.isNotEmpty ? _data.pets.first.id : '';
  }

  void _syncWithMapFocus() {
    final savedFocus = _data.mapFocusLocation.value;
    if (savedFocus != null) {
      setState(() {
        _center = LatLng(savedFocus.latitude, savedFocus.longitude);
        _country = _data.mapFocusCountry.value;
        _province = _data.mapFocusProvince.value;
        _city = _data.mapFocusCity.value;
        _barangay = _data.mapFocusBarangay.value;
      });
      _mapController.move(_center, 15.5);
      Get.snackbar(
        'Synced with Map Focus',
        'Center updated to ${_data.mapFocusLabel.isNotEmpty ? _data.mapFocusLabel : "Saved Map Focus"}',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    } else {
      Get.snackbar(
        'No Map Focus Set',
        'Setup a map focus first in tracking settings.',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  void _onRadiusSliderChanged(double value) {
    setState(() {
      _radiusMeters = value.roundToDouble();
      _radiusController.text = _radiusMeters.toStringAsFixed(0);
    });
  }

  void _onRadiusTextChanged(String text) {
    final val = double.tryParse(text);
    if (val != null && val >= 20 && val <= 5000) {
      setState(() {
        _radiusMeters = val;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final petValue = _data.pets.any((p) => p.id == _petId) ? _petId : null;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Create Safe Zone' : 'Edit Safe Zone'),
        actions: [
          if (!_isNew)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              tooltip: 'Delete Safe Zone',
              onPressed: _saving ? null : _confirmDelete,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Interactive Map with Dynamic Circle
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
                  height: 300,
                  child: Stack(
                    children: [
                      FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: _center,
                          initialZoom: 15,
                          onTap: (_, p) {
                            setState(() => _center = p);
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'pet_tracker_app',
                          ),
                          CircleLayer(
                            circles: [
                              CircleMarker(
                                point: _center,
                                radius: _radiusMeters,
                                useRadiusInMeter: true,
                                color: AppTheme.green.withValues(alpha: .2),
                                borderColor: AppTheme.green,
                                borderStrokeWidth: 2.5,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: _center,
                                width: 44,
                                height: 44,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: .25),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.location_on,
                                    color: AppTheme.green,
                                    size: 32,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      // Tap hint overlay
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
                                'Tap map to place zone center',
                                style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Zoom buttons
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FloatingActionButton.small(
                              heroTag: 'geofence_zoom_in',
                              onPressed: () => _mapController.move(
                                _mapController.camera.center,
                                _mapController.camera.zoom + 1,
                              ),
                              child: const Icon(Icons.add),
                            ),
                            const SizedBox(height: 6),
                            FloatingActionButton.small(
                              heroTag: 'geofence_zoom_out',
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

            const SizedBox(height: 12),

            // Sync with Map Focus Quick Button
            OutlinedButton.icon(
              onPressed: _syncWithMapFocus,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: const BorderSide(color: AppTheme.green, width: 1.5),
              ),
              icon: const Icon(Icons.sync_alt, color: AppTheme.green),
              label: Text(
                _data.hasMapFocus
                    ? 'Sync with Map Focus (${_data.mapFocusBarangay.value?.name ?? "Focus Area"})'
                    : 'Sync with Map Focus',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.green),
              ),
            ),

            const SizedBox(height: 16),

            // Basic Information Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Zone Settings',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Safe Zone Name',
                        hintText: 'e.g. Home, Backyard, Dog Park',
                        prefixIcon: Icon(Icons.label_outline),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      key: ValueKey('pet-$petValue-${_data.pets.length}'),
                      initialValue: petValue,
                      decoration: const InputDecoration(
                        labelText: 'Assigned Pet',
                        prefixIcon: Icon(Icons.pets),
                      ),
                      items: _data.pets.map((p) {
                        return DropdownMenuItem(
                          value: p.id,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              PetAvatar(photoUrl: p.photoUrl, size: 28),
                              const SizedBox(width: 10),
                              Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _petId = v);
                      },
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Zone Active', style: TextStyle(fontWeight: FontWeight.w700)),
                        Switch(
                          value: _enabled,
                          onChanged: (v) => setState(() => _enabled = v),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Dynamic Radius Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Zone Radius',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.green.withValues(alpha: .15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${_radiusMeters.toStringAsFixed(0)} meters',
                            style: const TextStyle(
                              color: AppTheme.green,
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Slider(
                      value: _radiusMeters.clamp(30.0, 1500.0),
                      min: 30.0,
                      max: 1500.0,
                      divisions: 147,
                      activeColor: AppTheme.green,
                      label: '${_radiusMeters.toStringAsFixed(0)}m',
                      onChanged: _onRadiusSliderChanged,
                    ),
                    TextField(
                      controller: _radiusController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Radius (meters)',
                        suffixText: 'm',
                        prefixIcon: Icon(Icons.radar),
                      ),
                      onChanged: _onRadiusTextChanged,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 14),

            // Place Selector Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Search Place / Barangay',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    _SafeZoneDropdown(
                      label: 'Country',
                      value: _country,
                      options: _countries,
                      onChanged: _placeLoading ? null : _selectCountry,
                    ),
                    const SizedBox(height: 10),
                    _SafeZoneDropdown(
                      label: 'Province',
                      value: _province,
                      options: _provinces,
                      onChanged: _placeLoading || _country == null ? null : _selectProvince,
                    ),
                    const SizedBox(height: 10),
                    _SafeZoneDropdown(
                      label: 'City / Municipality',
                      value: _city,
                      options: _cities,
                      onChanged: _placeLoading || _province == null ? null : _selectCity,
                    ),
                    const SizedBox(height: 10),
                    _SafeZoneDropdown(
                      label: 'Barangay',
                      value: _barangay,
                      options: _barangays,
                      onChanged: _placeLoading || _city == null ? null : (v) => setState(() => _barangay = v),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _placeLoading ? null : _useSelectedPlace,
                      icon: _placeLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.travel_explore),
                      label: const Text('Move Map to Selected Place'),
                    ),
                    if (_placeError.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _placeError,
                        style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Save Action
            FilledButton.icon(
              onPressed: _saving ? null : _save,
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
                _saving ? 'Saving...' : (_isNew ? 'Create Safe Zone' : 'Save Changes'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadCountries() async {
    setState(() {
      _placeLoading = true;
      _placeError = '';
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
      _placeError = e.toString().replaceFirst('Exception: ', '');
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
      _placeError = '';
    });
    if (country == null) return;
    await _loadPlaceOptions(() async {
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
      _placeError = '';
    });
    if (province == null) return;
    await _loadPlaceOptions(() async {
      _cities = await _placesRepo.cities(province.code);
    });
  }

  Future<void> _selectCity(PlaceOptionModel? city) async {
    setState(() {
      _city = city;
      _barangay = null;
      _barangays = [];
      _placeError = '';
    });
    if (city == null) return;
    await _loadPlaceOptions(() async {
      _barangays = await _placesRepo.barangays(city.code);
    });
  }

  Future<void> _loadPlaceOptions(Future<void> Function() loader) async {
    setState(() => _placeLoading = true);
    try {
      await loader();
    } catch (e) {
      _placeError = e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (mounted) setState(() => _placeLoading = false);
    }
  }

  Future<void> _useSelectedPlace() async {
    if (_country == null || _province == null || _city == null || _barangay == null) {
      setState(() {
        _placeError = 'Select country, province, city, and barangay first.';
      });
      return;
    }

    await _loadPlaceOptions(() async {
      final results = await _placesRepo.search(
        country: _country!.name,
        province: _province!.name,
        city: _city!.name,
        barangay: _barangay!.name,
        limit: 1,
      );
      if (results.isEmpty) {
        throw Exception('Selected place was not found.');
      }
      final location = results.first.location;
      setState(() {
        _center = LatLng(location.latitude, location.longitude);
      });
      _mapController.move(_center, 15);
    });
  }

  Future<void> _save() async {
    if (_petId.isEmpty) {
      Get.snackbar('Safe zone', 'Please select a pet for this safe zone.');
      return;
    }

    final name = _nameController.text.trim().isEmpty ? 'Safe Zone' : _nameController.text.trim();
    final body = {
      'pet_id': _petId,
      'name': name,
      'center': {'latitude': _center.latitude, 'longitude': _center.longitude},
      'radius_meters': _radiusMeters,
      'enabled': _enabled,
    };

    setState(() => _saving = true);
    try {
      if (_isNew) {
        await _data.geofencesRepo.create(body);
        Get.snackbar('Safe Zone Created', '$name has been created successfully.');
      } else {
        body.remove('pet_id');
        await _data.geofencesRepo.update(_geofence!.id, body);
        Get.snackbar('Safe Zone Updated', '$name has been updated.');
      }
      await _data.refreshAll();
      Get.back();
    } catch (e) {
      Get.snackbar('Safe zone error', e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _confirmDelete() {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete Safe Zone'),
        content: Text('Are you sure you want to delete "${_geofence?.name}"?'),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Get.back(); // close dialog
              setState(() => _saving = true);
              try {
                await _data.geofencesRepo.delete(_geofence!.id);
                await _data.refreshAll();
                Get.back(); // close form screen
                Get.snackbar('Safe Zone Deleted', 'The safe zone was deleted.');
              } catch (e) {
                Get.snackbar('Delete failed', e.toString());
              } finally {
                if (mounted) setState(() => _saving = false);
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  PlaceOptionModel? _matchingOption(
    List<PlaceOptionModel> options,
    PlaceOptionModel? selected,
  ) {
    if (selected == null) return null;
    return options.firstWhereOrNull((option) => option.code == selected.code);
  }
}

class _SafeZoneDropdown extends StatelessWidget {
  const _SafeZoneDropdown({
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
