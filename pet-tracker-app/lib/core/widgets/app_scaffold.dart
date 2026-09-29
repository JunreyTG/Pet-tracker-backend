import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_theme.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.currentIndex = 0,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: Text(title), actions: actions, toolbarHeight: 70),
      body: child,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF334155)
                  : const Color(0xFFE2E8F0).withValues(alpha: .7),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: .35)
                    : Colors.black.withValues(alpha: .06),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: NavigationBar(
              selectedIndex: currentIndex,
              onDestinationSelected: (index) {
                final route = [
                  Routes.home,
                  Routes.tracking,
                  Routes.pets,
                  Routes.alerts,
                  Routes.profile,
                ][index];
                if (Get.currentRoute != route) Get.offNamed(route);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.location_on_outlined),
                  selectedIcon: Icon(Icons.location_on),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Map',
                ),
                NavigationDestination(
                  icon: Icon(Icons.pets_outlined),
                  selectedIcon: Icon(Icons.pets),
                  label: 'Pets',
                ),
                NavigationDestination(
                  icon: Icon(Icons.notifications_outlined),
                  selectedIcon: Icon(Icons.notifications),
                  label: 'Alerts',
                ),
                NavigationDestination(
                  icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view),
                  label: 'Menu',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.green.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Icon(icon, size: 38, color: AppTheme.green),
                ),
                const SizedBox(height: 16),
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (action != null) ...[const SizedBox(height: 20), action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({super.key, required this.child, this.onTap, this.margin});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? const Color(0xFF334155)
              : const Color(0xFFE2E8F0).withValues(alpha: .6),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: .25)
                : Colors.black.withValues(alpha: .04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(18), child: child),
        ),
      ),
    );
  }
}

class SoftIcon extends StatelessWidget {
  const SoftIcon({super.key, required this.icon, this.color = AppTheme.green});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: color.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, color: color),
  );
}
