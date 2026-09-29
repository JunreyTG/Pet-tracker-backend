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
          IconButton.filledTonal(
            icon: const Icon(Icons.wifi_tethering),
            tooltip: 'Setup Tracker WiFi',
            onPressed: () => Get.toNamed(Routes.deviceWifiSetup),
          ),
          IconButton.filled(
            icon: const Icon(Icons.add),
            onPressed: () => _register(data),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Obx(() {
        if (data.devices.isEmpty) {
          return EmptyState(
            icon: Icons.sensors,
            title: 'No collars',
            message: 'Register an ESP32 tracker to assign it to a pet.',
            action: FilledButton(
              onPressed: () => Get.toNamed(Routes.deviceWifiSetup),
              child: const Text('Setup Tracker WiFi'),
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
                          child: Text(
                            d.deviceId,
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w900),
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

  void _register(AppDataController data) {
    final id = TextEditingController();
    Get.dialog(
      AlertDialog(
        title: const Text('Register tracker'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: TextField(
            controller: id,
            decoration: const InputDecoration(
              labelText: 'Device ID (e.g. ESP32_xxx)',
              prefixIcon: Icon(Icons.sensors),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                final device = await data.devicesRepo.register(id.text.trim());
                await data.refreshAll();
                Get.back();
                _showSecret(device.deviceSecret ?? '');
              } catch (e) {
                Get.snackbar('Registration failed', e.toString());
              }
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  void _showSecret(String secret) {
    Get.dialog(
      AlertDialog(
        title: const Text('Device Secret'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SelectableText(
            'Save this now. It is shown only once and is needed by the ESP32 collar.\n\n$secret',
          ),
        ),
        actions: [
          FilledButton(onPressed: Get.back, child: const Text('I saved it')),
        ],
      ),
      barrierDismissible: false,
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
