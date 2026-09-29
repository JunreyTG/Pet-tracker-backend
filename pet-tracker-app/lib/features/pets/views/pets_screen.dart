import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/pet_avatar.dart';
import '../../home/controllers/app_data_controller.dart';

class PetsScreen extends StatelessWidget {
  const PetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = Get.find<AppDataController>();
    return AppScaffold(
      title: 'My Pet',
      currentIndex: 2,
      actions: [
        IconButton.filled(
          onPressed: () => Get.toNamed(Routes.addPet),
          icon: const Icon(Icons.add),
        ),
        const SizedBox(width: 12),
      ],
      child: Obx(() {
        if (data.loading.value && data.pets.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (data.pets.isEmpty) {
          return EmptyState(
            icon: Icons.pets,
            title: 'No pets yet',
            message: 'Add your first pet to start tracking.',
            action: FilledButton(
              onPressed: () => Get.toNamed(Routes.addPet),
              child: const Text('Add Pet'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: data.refreshAll,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            itemCount: data.pets.length,
            itemBuilder: (_, i) {
              final pet = data.pets[i];
              final device = data.deviceForPet(pet);
              return SectionCard(
                margin: const EdgeInsets.only(bottom: 12),
                onTap: () => Get.toNamed(Routes.petDetails, arguments: pet.id),
                child: Row(
                  children: [
                    PetAvatar(
                      photoUrl: pet.photoUrl,
                      size: 74,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pet.name,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${pet.species}${pet.breed == null ? '' : ' • ${pet.breed}'}',
                          ),
                          const SizedBox(height: 8),
                          _StatusPill(
                            text: device == null
                                ? 'No collar'
                                : '${device.status} • ${device.batteryLevel?.toString() ?? '--'}%',
                            active: device?.status == 'online',
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
              );
            },
          ),
        );
      }),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.active});
  final String text;
  final bool active;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: (active ? AppTheme.green : AppTheme.orange).withValues(alpha: .12),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: active ? AppTheme.green : AppTheme.orange,
        fontWeight: FontWeight.w800,
        fontSize: 12,
      ),
    ),
  );
}
