import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/pet_avatar.dart';
import '../../auth/controllers/auth_controller.dart';
import '../controllers/app_data_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = Get.find<AppDataController>();
    final auth = Get.find<AuthController>();
    return AppScaffold(
      title: 'Pet Tracker',
      currentIndex: 0,
      actions: [
        IconButton.filledTonal(
          onPressed: data.refreshAll,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 12),
      ],
      child: Obx(() {
        final pet = data.selectedPet.value;
        final device = pet == null ? null : data.deviceForPet(pet);
        return RefreshIndicator(
          onRefresh: data.refreshAll,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
            children: [
              Text(
                'Stay connected with\n${auth.backendUser.value?.displayName ?? 'your pet'}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                ),
              ),
              const SizedBox(height: 18),
              _PetHeroCard(
                petName: pet?.name,
                photoUrl: pet?.photoUrl,
                deviceStatus: device?.status,
                battery: device?.batteryLevel,
                onTrack: pet?.deviceId == null
                    ? null
                    : () => Get.toNamed(
                        Routes.tracking,
                        arguments: pet?.deviceId,
                      ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.pets,
                      label: 'Pets',
                      value: '${data.pets.length}',
                      color: AppTheme.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      icon: Icons.notifications,
                      label: 'Unread',
                      value: '${data.unreadCount}',
                      color: AppTheme.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                'Quick actions',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              GridView.count(
                crossAxisCount: MediaQuery.sizeOf(context).width > 720 ? 4 : 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
                children: const [
                  _Quick(
                    icon: Icons.pets,
                    label: 'My Pets',
                    route: Routes.pets,
                    color: AppTheme.green,
                  ),
                  _Quick(
                    icon: Icons.fence,
                    label: 'Geo-fencing',
                    route: Routes.geofences,
                    color: Color(0xFFE5B64A),
                  ),
                  _Quick(
                    icon: Icons.notifications_active,
                    label: 'Alerts',
                    route: Routes.alerts,
                    color: AppTheme.orange,
                  ),
                  _Quick(
                    icon: Icons.sensors,
                    label: 'Collars',
                    route: Routes.devices,
                    color: Color(0xFF168CFF),
                  ),
                ],
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _PetHeroCard extends StatelessWidget {
  const _PetHeroCard({
    required this.petName,
    this.photoUrl,
    required this.deviceStatus,
    required this.battery,
    required this.onTrack,
  });
  final String? petName;
  final String? photoUrl;
  final String? deviceStatus;
  final int? battery;
  final VoidCallback? onTrack;

  @override
  Widget build(BuildContext context) {
    final online = deviceStatus == 'online';
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF101312), Color(0xFF2F3C35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .2),
                    width: 2,
                  ),
                ),
                child: PetAvatar(
                  photoUrl: photoUrl,
                  size: 78,
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      petName ?? 'No pet selected',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      deviceStatus == null
                          ? 'No collar assigned'
                          : '${online ? 'Connected' : deviceStatus} • ${battery?.toString() ?? '--'}%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .78),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onTrack,
            style: FilledButton.styleFrom(backgroundColor: AppTheme.orange),
            icon: const Icon(Icons.near_me),
            label: const Text('Open Live Map'),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => SectionCard(
    margin: EdgeInsets.zero,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftIcon(icon: icon, color: color),
        const SizedBox(height: 14),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
        ),
        Text(label),
      ],
    ),
  );
}

class _Quick extends StatelessWidget {
  const _Quick({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String route;
  final Color color;

  @override
  Widget build(BuildContext context) => SectionCard(
    margin: EdgeInsets.zero,
    onTap: () => Get.toNamed(route),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        SoftIcon(icon: icon, color: color),
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ],
    ),
  );
}
