import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/routes/app_routes.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../home/controllers/app_data_controller.dart';

class DevicesScreen extends StatelessWidget {
  const DevicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final data = Get.find<AppDataController>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collar Management'),
        actions: [
          IconButton.filled(
            icon: const Icon(Icons.add),
            tooltip: 'Add Device',
            onPressed: () => Get.toNamed(Routes.deviceWifiSetup),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Obx(() {
        if (data.devices.isEmpty) {
          return EmptyState(
            icon: Icons.sensors,
            title: 'No collars',
            message:
                'Add your tracker to connect it and start tracking your pet.',
            action: FilledButton(
              onPressed: () => Get.toNamed(Routes.deviceWifiSetup),
              child: const Text('Add Device'),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: data.refreshAll,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            itemCount: data.devices.length,
            itemBuilder: (_, i) {
              final d = data.devices[i];
              final online = d.status == 'online';
              return SectionCard(
                margin: const EdgeInsets.only(bottom: 12),
                onTap: () =>
                    Get.toNamed(Routes.deviceDetails, arguments: d.deviceId),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SoftIcon(
                          icon: online ? Icons.sensors : Icons.sensors_off,
                          color: online ? AppTheme.green : AppTheme.orange,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.deviceName(d.deviceId),
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w900),
                              ),
                              Text(
                                d.deviceId,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _Chip(
                          icon: Icons.wifi_tethering,
                          text: d.status,
                          color: online ? AppTheme.green : AppTheme.orange,
                        ),
                        const SizedBox(width: 8),
                        _Chip(
                          icon: Icons.battery_5_bar,
                          text: '${d.batteryLevel?.toString() ?? '--'}%',
                          color: const Color(0xFFE5B64A),
                        ),
                      ],
                    ),
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

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.text, required this.color});
  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .12),
      borderRadius: BorderRadius.circular(14),
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
