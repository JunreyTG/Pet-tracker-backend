part of '../main.dart';

class DashboardPage extends StatelessWidget {
  final List<Pet> pets;
  final List<TrackerDevice> devices;
  final List<TrackerAlert> alerts;
  final TrackerDevice? Function(Pet pet) deviceForPet;
  final void Function(int index) openTab;
  final String backendStatus;
  final String backendMessage;
  final bool backendOnline;
  final bool isCheckingBackend;
  final VoidCallback onCheckBackend;
  final String authStatus;
  final String authMessage;
  final CurrentUser? backendUser;
  final bool isAuthenticating;
  final Future<void> Function(String email, String password) onSignIn;
  final Future<void> Function(String email, String password) onSignUp;
  final Future<void> Function() onSignOut;
  final Future<void> Function() onLoadCurrentUser;

  const DashboardPage({
    super.key,
    required this.pets,
    required this.devices,
    required this.alerts,
    required this.deviceForPet,
    required this.openTab,
    required this.backendStatus,
    required this.backendMessage,
    required this.backendOnline,
    required this.isCheckingBackend,
    required this.onCheckBackend,
    required this.authStatus,
    required this.authMessage,
    required this.backendUser,
    required this.isAuthenticating,
    required this.onSignIn,
    required this.onSignUp,
    required this.onSignOut,
    required this.onLoadCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final online = devices
        .where((item) => item.status == DeviceStatus.online)
        .length;
    final unread = alerts.where((item) => !item.read).length;
    return PageShell(
      title: 'Pet Tracker',
      subtitle: 'Frontend mock aligned with backend features',
      trailing: Badge.count(
        count: unread,
        isLabelVisible: unread > 0,
        child: _CircleButton(
          icon: Icons.notifications_none_rounded,
          onTap: () => openTab(3),
        ),
      ),
      children: [
        BackendStatusCard(
          status: backendStatus,
          message: backendMessage,
          online: backendOnline,
          loading: isCheckingBackend,
          onCheck: onCheckBackend,
        ),
        AuthStatusCard(
          status: authStatus,
          message: authMessage,
          backendUser: backendUser,
          loading: isAuthenticating,
          onSignIn: onSignIn,
          onSignUp: onSignUp,
          onSignOut: onSignOut,
          onLoadCurrentUser: onLoadCurrentUser,
        ),
        GradientPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'System Overview',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: MetricTile(value: '${pets.length}', label: 'Pets'),
                  ),
                  Expanded(
                    child: MetricTile(
                      value: '${devices.length}',
                      label: 'Trackers',
                    ),
                  ),
                  Expanded(
                    child: MetricTile(value: '$online', label: 'Online'),
                  ),
                  Expanded(
                    child: MetricTile(value: '$unread', label: 'Unread'),
                  ),
                ],
              ),
            ],
          ),
        ),
        SectionHeader(
          title: 'Your Pets',
          action: 'View all',
          onTap: () => openTab(1),
        ),
        ...pets.map(
          (pet) => PetCard(
            pet: pet,
            device: deviceForPet(pet),
            onTap: () => openTab(2),
          ),
        ),
        const SectionHeader(title: 'Quick Actions'),
        GridView.count(
          crossAxisCount: MediaQuery.sizeOf(context).width > 680 ? 4 : 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.35,
          children: [
            QuickAction(
              icon: Icons.location_on_rounded,
              title: 'Live Tracking',
              subtitle: 'Mock telemetry',
              onTap: () => openTab(2),
            ),
            QuickAction(
              icon: Icons.pets_rounded,
              title: 'Manage Pets',
              subtitle: 'Create and edit',
              onTap: () => openTab(1),
            ),
            QuickAction(
              icon: Icons.gps_fixed_rounded,
              title: 'Trackers',
              subtitle: 'Register and assign',
              onTap: () => openTab(4),
            ),
            QuickAction(
              icon: Icons.shield_rounded,
              title: 'Safe Zones',
              subtitle: 'Geofence setup',
              onTap: () => openTab(4),
            ),
          ],
        ),
      ],
    );
  }
}
