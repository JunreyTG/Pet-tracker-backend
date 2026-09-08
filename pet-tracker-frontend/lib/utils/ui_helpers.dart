part of '../main.dart';

InputDecoration inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
  );
}

IconData alertIcon(TrackerAlertType type) {
  switch (type) {
    case TrackerAlertType.geofenceExit:
      return Icons.logout_rounded;
    case TrackerAlertType.geofenceEnter:
      return Icons.login_rounded;
    case TrackerAlertType.lowBattery:
      return Icons.battery_alert_rounded;
    case TrackerAlertType.deviceOffline:
      return Icons.wifi_off_rounded;
    case TrackerAlertType.deviceOnline:
      return Icons.wifi_rounded;
  }
}

String relativeTime(DateTime? value) {
  if (value == null) return 'Unknown';
  final difference = DateTime.now().difference(value);
  if (difference.inMinutes < 1) return 'Just now';
  if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
  if (difference.inHours < 24) return '${difference.inHours} hr ago';
  return '${difference.inDays} days ago';
}

DeviceStatus parseDeviceStatus(String value) {
  for (final status in DeviceStatus.values) {
    if (status.name == value) return status;
  }
  return DeviceStatus.unregistered;
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
