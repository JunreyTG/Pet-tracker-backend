import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/utils/navigation_args.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/pet_avatar.dart';
import '../../../data/models/models.dart';
import '../../home/controllers/app_data_controller.dart';

class DeviceDetailsScreen extends StatelessWidget {
  const DeviceDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = Get.find<AppDataController>();
    final id = asIdString(Get.arguments);

    return Scaffold(
      appBar: AppBar(title: const Text('Tracker Details')),
      body: Obx(() {
        final d = data.devices.firstWhereOrNull((x) => x.deviceId == id);
        if (d == null) return const Center(child: Text('Tracker not found.'));
        final pet = d.petId == null
            ? null
            : data.pets.firstWhereOrNull((p) => p.id == d.petId);
        final online = d.status == 'online';
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // Status Header
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppTheme.green.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SoftIcon(
                    icon: online ? Icons.sensors : Icons.sensors_off,
                    color: online ? AppTheme.green : AppTheme.orange,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'GPS Tracker Hardware',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    d.deviceId,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _DetailChip(
                        icon: Icons.wifi_tethering,
                        text: d.status,
                        color: online ? AppTheme.green : AppTheme.orange,
                      ),
                      const SizedBox(width: 8),
                      _DetailChip(
                        icon: Icons.battery_5_bar,
                        text: '${d.batteryLevel?.toString() ?? '--'}%',
                        color: const Color(0xFFE5B64A),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Telemetry Metadata Card
            SectionCard(
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Last seen: ${d.lastSeen?.toString() ?? 'Never'}'),
                  const SizedBox(height: 4),
                  Text('Last location update: ${d.lastLocationUpdate?.toString() ?? 'None'}'),
                  const SizedBox(height: 4),
                  Text('Coordinates: ${_coordinates(d.currentLocation)}'),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Assigned Pet Container
            if (pet != null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: AppTheme.green.withValues(alpha: .45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.green, width: 2),
                          ),
                          child: PetAvatar(
                            photoUrl: pet.photoUrl,
                            size: 54,
                            borderRadius: BorderRadius.circular(27),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.green.withValues(alpha: .12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'ASSIGNED PET',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.green,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                pet.name,
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              Text(
                                '${pet.species}${pet.breed != null && pet.breed!.isNotEmpty ? " • ${pet.breed}" : ""}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _assign(context, data, d.deviceId, currentPetId: pet.id),
                            icon: const Icon(Icons.sync_alt, size: 18),
                            label: const Text('Change Pet'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => _unassign(data, d.deviceId),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                          ),
                          icon: const Icon(Icons.link_off, size: 18),
                          label: const Text('Unassign'),
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: AppTheme.orange.withValues(alpha: .15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.pets, color: AppTheme.orange, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'No Pet Assigned',
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Connect this tracker to a pet to begin live tracking.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _assign(context, data, d.deviceId),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.green,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        icon: const Icon(Icons.add_link),
                        label: const Text(
                          'Assign Tracker to Pet',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 14),

            // Tracker Actions
            OutlinedButton.icon(
              onPressed: () => Get.toNamed(Routes.deviceWifiSetup, arguments: d.deviceId),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Setup Tracker WiFi'),
            ),

            const SizedBox(height: 10),

            FilledButton.icon(
              onPressed: () => Get.toNamed(Routes.tracking, arguments: d.deviceId),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.ink,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.map),
              label: const Text('Track Location'),
            ),
          ],
        );
      }),
    );
  }

  static String _coordinates(LocationModel? location) {
    if (location == null) return 'None';
    return '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
  }

  void _assign(BuildContext context, AppDataController data, String deviceId, {String? currentPetId}) {
    final pets = data.pets;
    if (pets.isEmpty) {
      Get.dialog(
        AlertDialog(
          title: const Text('No Pets Found'),
          content: const Text('Please create a pet profile first before assigning this tracker.'),
          actions: [
            TextButton(onPressed: Get.back, child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                Get.back();
                Get.toNamed(Routes.addPet);
              },
              child: const Text('Add Pet'),
            ),
          ],
        ),
      );
      return;
    }

    String selectedPetId = currentPetId ?? pets.first.id;

    Get.dialog(
      StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: const Text('Select Pet to Assign'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: pets.length,
                itemBuilder: (context, i) {
                  final p = pets[i];
                  final isSelected = p.id == selectedPetId;
                  return ListTile(
                    selected: isSelected,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    leading: PetAvatar(photoUrl: p.photoUrl, size: 40),
                    title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(p.species),
                    trailing: Icon(
                      isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: isSelected ? AppTheme.green : Colors.grey,
                    ),
                    onTap: () => setState(() => selectedPetId = p.id),
                  );
                },
              ),
            ),
            actions: [
              TextButton(onPressed: Get.back, child: const Text('Cancel')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppTheme.green),
                onPressed: () => _saveAssignment(data, deviceId, selectedPetId),
                child: const Text('Assign Pet'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _saveAssignment(
    AppDataController data,
    String deviceId,
    String? petId,
  ) async {
    if (petId == null) {
      Get.snackbar('Assignment failed', 'Select a pet first.');
      return;
    }

    try {
      await data.devicesRepo.assign(deviceId, petId);
      await data.refreshAll();
      if (Get.isDialogOpen ?? false) Get.back();
      Get.snackbar(
        'Tracker Assigned',
        'Tracker was successfully assigned to pet.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on ApiException catch (e) {
      Get.snackbar('Assignment failed', e.message);
    } catch (e) {
      Get.snackbar('Assignment failed', e.toString());
    }
  }

  Future<void> _unassign(AppDataController data, String deviceId) async {
    try {
      await data.devicesRepo.unassign(deviceId);
      await data.refreshAll();
      Get.snackbar(
        'Tracker Unassigned',
        'Tracker assignment was removed.',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on ApiException catch (e) {
      Get.snackbar('Unassign failed', e.message);
    } catch (e) {
      Get.snackbar('Unassign failed', e.toString());
    }
  }
}

class _DetailChip extends StatelessWidget {
  const _DetailChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              text,
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      );
}
