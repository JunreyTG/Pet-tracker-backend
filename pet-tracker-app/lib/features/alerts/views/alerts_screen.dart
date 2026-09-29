import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../home/controllers/app_data_controller.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final data = Get.find<AppDataController>();
    return AppScaffold(
      title: 'Activity status',
      currentIndex: 3,
      actions: [
        IconButton.filledTonal(
          onPressed: data.refreshAll,
          icon: const Icon(Icons.refresh),
        ),
        const SizedBox(width: 12),
      ],
      child: Obx(() {
        final items = data.alerts
            .where(
              (a) =>
                  filter == 'all' ||
                  (filter == 'unread' && !a.read) ||
                  (filter == 'read' && a.read) ||
                  a.type == filter,
            )
            .toList();
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.notifications_none,
            title: 'No alerts',
            message: 'Tracker events and safe-zone alerts appear here.',
          );
        }
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children:
                    [
                          'all',
                          'unread',
                          'read',
                          'device_offline',
                          'device_online',
                          'geofence_exit',
                          'geofence_enter',
                          'low_battery',
                        ]
                        .map(
                          (f) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(f.replaceAll('_', ' ')),
                              selected: filter == f,
                              selectedColor: AppTheme.green,
                              labelStyle: TextStyle(
                                color: filter == f
                                    ? Colors.white
                                    : Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w800,
                              ),
                              onSelected: (_) => setState(() => filter = f),
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: data.refreshAll,
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 110),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final a = items[i];
                    return Dismissible(
                      key: ValueKey(a.id),
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.orange,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(Icons.delete, color: Colors.white),
                      ),
                      onDismissed: (_) async {
                        await data.alertsRepo.delete(a.id);
                        await data.refreshAll();
                      },
                      child: SectionCard(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          children: [
                            SoftIcon(
                              icon: _icon(a.type),
                              color: a.read ? Colors.grey : AppTheme.green,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    a.title,
                                    style: TextStyle(
                                      fontWeight: a.read
                                          ? FontWeight.w700
                                          : FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(a.message),
                                  if (a.createdAt != null)
                                    Text(
                                      DateFormat.yMMMd().add_jm().format(
                                        a.createdAt!,
                                      ),
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                a.read ? Icons.mark_email_unread : Icons.done,
                              ),
                              onPressed: () async {
                                await data.alertsRepo.updateRead(a.id, !a.read);
                                await data.refreshAll();
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  IconData _icon(String type) => switch (type) {
    'device_offline' => Icons.sensors_off,
    'device_online' => Icons.sensors,
    'geofence_exit' => Icons.exit_to_app,
    'geofence_enter' => Icons.home,
    'low_battery' => Icons.battery_alert,
    _ => Icons.notifications,
  };
}
