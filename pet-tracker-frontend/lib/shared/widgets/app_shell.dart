import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/app_colors.dart';
import '../../core/responsive/breakpoints.dart';

class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (context.isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            const _DesktopSidebar(),
            Expanded(child: child),
          ],
        ),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: const _MobileNavigationBar(),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 260,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(right: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _BrandHeader(),
              const SizedBox(height: 28),
              ..._primaryDestinations.map(
                (destination) => _SidebarDestination(destination: destination),
              ),
              const Spacer(),
              const Divider(),
              _SidebarDestination(destination: _profileDestination),
              _SidebarDestination(destination: _settingsDestination),
            ],
          ),
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.pets_rounded, color: Colors.white),
        ),
        const SizedBox(width: 12),
        const Text(
          'Pet Tracker',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ],
    );
  }
}

class _SidebarDestination extends StatelessWidget {
  final _ShellDestination destination;

  const _SidebarDestination({required this.destination});

  @override
  Widget build(BuildContext context) {
    final selected = _isSelected(context, destination.path);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? AppColors.primarySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.go(destination.path),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(
              children: [
                Icon(
                  destination.icon,
                  color: selected ? AppColors.primary : AppColors.mutedText,
                ),
                const SizedBox(width: 12),
                Text(
                  destination.label,
                  style: TextStyle(
                    color: selected ? AppColors.primary : AppColors.text,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavigationBar extends StatelessWidget {
  const _MobileNavigationBar();

  @override
  Widget build(BuildContext context) {
    final currentIndex = _mobileDestinations.indexWhere(
      (destination) => _isSelected(context, destination.path),
    );

    return NavigationBar(
      selectedIndex: currentIndex == -1 ? 0 : currentIndex,
      onDestinationSelected: (index) =>
          context.go(_mobileDestinations[index].path),
      destinations: _mobileDestinations
          .map(
            (destination) => NavigationDestination(
              icon: Icon(destination.icon),
              label: destination.label,
            ),
          )
          .toList(),
    );
  }
}

bool _isSelected(BuildContext context, String path) {
  return GoRouterState.of(context).uri.path == path;
}

class _ShellDestination {
  final String label;
  final String path;
  final IconData icon;

  const _ShellDestination({
    required this.label,
    required this.path,
    required this.icon,
  });
}

const _dashboardDestination = _ShellDestination(
  label: 'Dashboard',
  path: '/dashboard',
  icon: Icons.dashboard_outlined,
);
const _profileDestination = _ShellDestination(
  label: 'Profile',
  path: '/profile',
  icon: Icons.person_outline,
);
const _settingsDestination = _ShellDestination(
  label: 'Settings',
  path: '/settings',
  icon: Icons.settings_outlined,
);

const _primaryDestinations = [
  _dashboardDestination,
  _ShellDestination(label: 'My Pets', path: '/pets', icon: Icons.pets_outlined),
  _ShellDestination(
    label: 'Trackers',
    path: '/devices',
    icon: Icons.gps_fixed_outlined,
  ),
  _ShellDestination(
    label: 'Live Map',
    path: '/tracking',
    icon: Icons.map_outlined,
  ),
  _ShellDestination(
    label: 'Safe Zones',
    path: '/geofences',
    icon: Icons.shield_outlined,
  ),
  _ShellDestination(
    label: 'Alerts',
    path: '/alerts',
    icon: Icons.notifications_none_outlined,
  ),
];

const _mobileDestinations = [
  _dashboardDestination,
  _ShellDestination(label: 'Pets', path: '/pets', icon: Icons.pets_outlined),
  _ShellDestination(label: 'Map', path: '/tracking', icon: Icons.map_outlined),
  _ShellDestination(
    label: 'Alerts',
    path: '/alerts',
    icon: Icons.notifications_none_outlined,
  ),
  _profileDestination,
];
