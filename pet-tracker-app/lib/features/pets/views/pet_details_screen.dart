import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/utils/navigation_args.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/pet_avatar.dart';
import '../../../data/models/models.dart';
import '../../home/controllers/app_data_controller.dart';

class PetDetailsScreen extends StatelessWidget {
  const PetDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = Get.find<AppDataController>();
    final id = asIdString(Get.arguments);
    return Scaffold(
      appBar: AppBar(title: const Text('Pet Details')),
      body: Obx(() {
        final pet = data.pets.firstWhereOrNull((p) => p.id == id);
        if (pet == null) return const Center(child: Text('Pet not found.'));
        final device = data.deviceForPet(pet);
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _PetHeader(pet: pet),
            const SizedBox(height: 14),
            SectionCard(
              margin: EdgeInsets.zero,
              child: Row(
                children: [
                  SoftIcon(
                    icon: device == null ? Icons.sensors_off : Icons.sensors,
                    color: device?.status == 'online'
                        ? AppTheme.green
                        : AppTheme.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device == null
                              ? 'No collar assigned'
                              : 'Tracker ${device.deviceId}',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        Text(device?.status ?? 'Assign a tracker from Collars'),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => Get.toNamed(Routes.devices),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: pet.deviceId == null
                  ? null
                  : () => Get.toNamed(Routes.tracking, arguments: pet.deviceId),
              icon: const Icon(Icons.map),
              label: const Text('Open Map'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Get.toNamed(Routes.addPet, arguments: pet),
              icon: const Icon(Icons.edit),
              label: const Text('Edit Pet'),
            ),
            TextButton.icon(
              onPressed: () => _deletePet(data, pet),
              icon: const Icon(Icons.delete),
              label: const Text('Delete Pet'),
            ),
          ],
        );
      }),
    );
  }

  void _deletePet(AppDataController data, PetModel pet) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete pet?'),
        content: Text(
          pet.deviceId == null
              ? 'This cannot be undone.'
              : 'This pet has a tracker. The app will unassign it first.',
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              Get.back();
              try {
                if (pet.deviceId != null) {
                  await data.devicesRepo.unassign(pet.deviceId!);
                }
                await data.petsRepo.delete(pet.id);
                await data.refreshAll();
                Get.offNamed(Routes.pets);
              } catch (e) {
                Get.snackbar('Delete failed', e.toString());
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _PetHeader extends StatelessWidget {
  const _PetHeader({required this.pet});
  final PetModel pet;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
              : [const Color(0xFFE8F8F0), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .25 : .05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.green, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.green.withValues(alpha: .2),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: PetAvatar(
              photoUrl: pet.photoUrl,
              size: 88,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pet.name,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    pet.species,
                    style: const TextStyle(
                      color: AppTheme.green,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${pet.breed ?? 'No breed'}${pet.age == null ? '' : ' • ${pet.age} yrs old'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
