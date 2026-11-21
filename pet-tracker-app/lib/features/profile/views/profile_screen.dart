import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/controllers/app_data_controller.dart';
import '../widgets/profile_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final data = Get.find<AppDataController>();
    return AppScaffold(
      title: 'Menu',
      currentIndex: 4,
      child: Obx(
        () => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          children: [
            SectionCard(
              margin: EdgeInsets.zero,
              onTap: () => Get.toNamed(Routes.accountProfile),
              child: Row(
                children: [
                  ProfileAvatar(
                    displayName: auth.backendUser.value?.displayName,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          auth.backendUser.value?.displayName ?? 'Pet Owner',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                        Text(
                          auth.backendUser.value?.email ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _MenuStat(
              icon: Icons.pets,
              title: 'My Pets',
              value: '${data.pets.length}',
              onTap: () => Get.toNamed(Routes.pets),
            ),
            _MenuStat(
              icon: Icons.sensors,
              title: 'Collars',
              value: '${data.devices.length}',
              onTap: () => Get.toNamed(Routes.devices),
            ),
            _MenuStat(
              icon: Icons.notifications_active,
              title: 'Unread alerts',
              value: '${data.unreadCount}',
              onTap: () => Get.toNamed(Routes.alerts, arguments: 'unread'),
            ),
            _MenuStat(
              icon: Icons.settings_outlined,
              title: 'Settings',
              onTap: () => Get.toNamed(Routes.settings),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: auth.logout,
              style: FilledButton.styleFrom(backgroundColor: AppTheme.orange),
              icon: const Icon(Icons.logout),
              label: const Text('Log Out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuStat extends StatelessWidget {
  const _MenuStat({
    required this.icon,
    required this.title,
    this.value,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SectionCard(
    onTap: onTap,
    child: Row(
      children: [
        SoftIcon(icon: icon),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        if (value != null)
          Text(
            value!,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        const SizedBox(width: 6),
        const Icon(Icons.chevron_right),
      ],
    ),
  );
}
