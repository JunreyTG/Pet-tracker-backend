part of '../main.dart';

class ProfilePage extends StatelessWidget {
  final OwnerProfile owner;
  final List<Pet> pets;
  final List<TrackerDevice> devices;
  final List<SafeZone> safeZones;
  final List<PushToken> pushTokens;
  final bool isSyncingDevices;
  final String devicesStatus;
  final String devicesMessage;
  final Future<void> Function() onLoadDevices;
  final Future<void> Function(String deviceId) onRegisterDevice;
  final Future<void> Function(TrackerDevice device, Pet? pet) onAssignDevice;
  final ValueChanged<SafeZone> onSaveSafeZone;
  final ValueChanged<PushToken> onSaveToken;

  const ProfilePage({
    super.key,
    required this.owner,
    required this.pets,
    required this.devices,
    required this.safeZones,
    required this.pushTokens,
    required this.isSyncingDevices,
    required this.devicesStatus,
    required this.devicesMessage,
    required this.onLoadDevices,
    required this.onRegisterDevice,
    required this.onAssignDevice,
    required this.onSaveSafeZone,
    required this.onSaveToken,
  });

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Profile',
      subtitle: 'Account and backend-ready setup',
      children: [
        GradientPanel(
          child: Column(
            children: [
              const Icon(Icons.person_rounded, color: Colors.white, size: 44),
              const SizedBox(height: 8),
              Text(
                owner.displayName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(owner.email, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 4),
              Text(
                'UID: ${owner.uid}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        ProfileOption(
          icon: Icons.gps_fixed_rounded,
          title: 'My Trackers',
          subtitle: '${devices.length} registered devices',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TrackersPage(
                pets: pets,
                devices: devices,
                isSyncingDevices: isSyncingDevices,
                devicesStatus: devicesStatus,
                devicesMessage: devicesMessage,
                onLoadDevices: onLoadDevices,
                onRegisterDevice: onRegisterDevice,
                onAssignDevice: onAssignDevice,
              ),
            ),
          ),
        ),
        ProfileOption(
          icon: Icons.shield_outlined,
          title: 'Safe Zones',
          subtitle: '${safeZones.length} geofences',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SafeZonesPage(
                pets: pets,
                safeZones: safeZones,
                onSave: onSaveSafeZone,
              ),
            ),
          ),
        ),
        ProfileOption(
          icon: Icons.notifications_active_outlined,
          title: 'Push Notifications',
          subtitle: '${pushTokens.length} local token records',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => NotificationSettingsPage(
                tokens: pushTokens,
                onSave: onSaveToken,
              ),
            ),
          ),
        ),
        const InfoPanel(
          icon: Icons.link_off_rounded,
          text:
              'Frontend is intentionally not connected to the backend. These flows are local mocks prepared for later API integration.',
        ),
      ],
    );
  }
}
