import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/pet_avatar.dart';
import '../../../data/models/models.dart';
import '../../home/controllers/app_data_controller.dart';

class GeofencesScreen extends StatelessWidget {
  const GeofencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = Get.find<AppDataController>();
    return AppScaffold(
      title: 'Geo-fencing',
      currentIndex: 1,
      actions: [
        IconButton.filled(
          icon: const Icon(Icons.add),
          tooltip: 'Add Safe Zone',
          onPressed: () => _edit(context, data),
        ),
        const SizedBox(width: 12),
      ],
      child: Obx(() {
        if (data.geofences.isEmpty) {
          return EmptyState(
            icon: Icons.radar,
            title: 'No safe zones',
            message:
                'Create a safe zone around home, school, or favorite places with real-time alerts.',
            action: FilledButton.icon(
              onPressed: () => _edit(context, data),
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Create Safe Zone'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: data.refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              for (final g in data.geofences)
                Builder(
                  builder: (context) {
                    final pet = data.pets.firstWhereOrNull(
                      (p) => p.id == g.petId,
                    );
                    final stateColor = !g.enabled
                        ? Colors.grey
                        : g.lastState == 'outside'
                        ? AppTheme.orange
                        : g.lastState == 'inside'
                        ? AppTheme.green
                        : const Color(0xFFE5B64A);
                    return SectionCard(
                      margin: const EdgeInsets.only(bottom: 12),
                      onTap: () => _edit(context, data, g),
                      child: Row(
                        children: [
                          if (pet?.photoUrl != null && pet!.photoUrl!.isNotEmpty)
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: stateColor, width: 2),
                              ),
                              child: PetAvatar(
                                photoUrl: pet.photoUrl,
                                size: 48,
                                borderRadius: BorderRadius.circular(24),
                              ),
                            )
                          else
                            SoftIcon(icon: Icons.fence, color: stateColor),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.name,
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${pet?.name ?? 'Pet'} • ${g.radiusMeters.toStringAsFixed(0)}m radius • ${g.lastState ?? 'active'}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: g.enabled,
                            activeThumbColor: AppTheme.green,
                            onChanged: (v) async {
                              await data.geofencesRepo.update(g.id, {
                                'enabled': v,
                              });
                              await data.refreshAll();
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => _edit(context, data),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: const Icon(Icons.add_location_alt),
                label: const Text('Add New Geo-Fencing'),
              ),
            ],
          ),
        );
      }),
    );
  }

  void _edit(BuildContext context, AppDataController data, [GeofenceModel? g]) {
    if (data.pets.isEmpty) {
      Get.snackbar('Add a pet first', 'Safe zones must be assigned to a pet.');
      return;
    }
    Get.toNamed(Routes.geofenceForm, arguments: g);
  }
}
