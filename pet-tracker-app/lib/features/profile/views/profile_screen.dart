import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../home/controllers/app_data_controller.dart';

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
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: AppTheme.green.withValues(alpha: .16),
                    child: Text(
                      _initial(auth.backendUser.value?.displayName),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.green,
                      ),
                    ),
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
                        Text(auth.backendUser.value?.email ?? ''),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _MenuStat(
              icon: Icons.pets,
              title: 'My Pet',
              value: '${data.pets.length}',
            ),
            _MenuStat(
              icon: Icons.sensors,
              title: 'Collars',
              value: '${data.devices.length}',
            ),
            _MenuStat(
              icon: Icons.notifications_active,
              title: 'Unread alerts',
              value: '${data.unreadCount}',
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

String _initial(String? displayName) {
  final name = (displayName ?? '').trim();
  if (name.isEmpty) return 'P';
  return name.characters.first.toUpperCase();
}

class _MenuStat extends StatelessWidget {
  const _MenuStat({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) => SectionCard(
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
        Text(
          value,
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
