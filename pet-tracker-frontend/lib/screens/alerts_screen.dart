part of '../main.dart';

class AlertsPage extends StatelessWidget {
  final List<TrackerAlert> alerts;
  final ValueChanged<TrackerAlert> onRead;
  final ValueChanged<TrackerAlert> onDelete;

  const AlertsPage({
    super.key,
    required this.alerts,
    required this.onRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Alerts',
      subtitle: 'Review, mark read, or delete tracker alerts',
      children: alerts.isEmpty
          ? [const EmptyState(text: 'No alerts yet')]
          : alerts
                .map(
                  (alert) => AlertCard(
                    alert: alert,
                    onRead: () => onRead(alert),
                    onDelete: () => onDelete(alert),
                  ),
                )
                .toList(),
    );
  }
}
